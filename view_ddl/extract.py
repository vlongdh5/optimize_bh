import json, re, csv, os, sys
import sqlglot
from sqlglot import exp

HERE = os.path.dirname(os.path.abspath(__file__))
m = json.load(open(os.path.join(HERE, "all_tables.json")))
m = {k.replace("3000550035.", ""): v for k, v in m.items()}
def body(ddl):
    ddl = ddl.replace("`3000550035.", "`")
    # skip column list: find matching paren after view name, then ' AS '
    i = ddl.find("(")
    j = ddl.find(" AS ")
    if i != -1 and i < j:
        depth = 0
        for k in range(i, len(ddl)):
            if ddl[k] == "(": depth += 1
            elif ddl[k] == ")":
                depth -= 1
                if depth == 0: break
        j = ddl.find(" AS ", k)
    return re.sub(r"(?<=[ ,(])from, to,", "`from`, `to`,", ddl[j + 4:])

def fq(t, default_db="datamart_v2"):
    if not t.name:  # table function, e.g. numbers(...)
        return f"{t.this.sql(dialect='clickhouse')} [table function]"
    db = t.args.get("db")
    return f"{db.name if db else default_db}.{t.name}"

def sql(e):
    return e.sql(dialect="clickhouse") if e is not None else ""

def conjuncts(e):
    if e is None: return []
    if isinstance(e, (exp.Where, exp.PreWhere, exp.Having)): e = e.this
    while isinstance(e, exp.Paren): e = e.this
    if isinstance(e, exp.And):
        return [c for x in e.flatten() for c in conjuncts(x)]
    return [e]

def qualifiers(e):
    return {c.table for c in e.find_all(exp.Column) if c.table}

_phys_cache = {}
def physical(t, seen=()):
    """Resolve a datamart view reference to its underlying physical tables."""
    if t in _phys_cache: return _phys_cache[t]
    meta = m.get(t)
    if not meta or "View" not in meta["engine"] or t in seen:
        return {t}
    try:
        tree = sqlglot.parse_one(body(meta["ddl"]), dialect="clickhouse")
    except Exception:
        return {t}
    ctes = {c.alias for c in tree.find_all(exp.CTE)}
    out = set()
    for tb in tree.find_all(exp.Table):
        if not tb.args.get("db") and tb.name in ctes: continue
        out |= physical(fq(tb), seen + (t,))
    _phys_cache[t] = out
    return out

COLS = {k: set(v) for k, v in json.load(open(os.path.join(HERE, "columns.json"))).items()}

def output_columns(src, ctes, seen=()):
    """Column names a FROM/JOIN source exposes, or None if unknown."""
    if isinstance(src, exp.Table) and not src.args.get("db") and src.name in ctes and src.name not in seen:
        q = ctes[src.name]
    elif isinstance(src, exp.Table):
        return COLS.get(fq(src))
    else:
        q = src.this if isinstance(src, exp.Subquery) else src
    sels = [q] if isinstance(q, exp.Select) else list(q.find_all(exp.Select))[:1]
    if not sels: return None
    q = sels[0]
    out = set()
    for e in q.expressions:
        if isinstance(e, exp.Star) or (isinstance(e, exp.Column) and isinstance(e.this, exp.Star)):
            inner = []
            f = q.args.get("from_") or q.args.get("from")
            if f: inner.append(f.this)
            inner += [j.this for j in q.args.get("joins") or []]
            for i in inner:
                oc = output_columns(i, ctes, seen + ((src.name,) if isinstance(src, exp.Table) else ()))
                if oc is None: return None
                out |= oc
        elif e.alias_or_name:
            out.add(e.alias_or_name)
    return out

def cte_map(tree):
    return {c.alias: c.this for c in tree.find_all(exp.CTE)}

def base_tables(node, ctes, seen=()):
    """Physical/view tables referenced (transitively through CTEs) by node."""
    out = []
    for tb in node.find_all(exp.Table):
        if not tb.args.get("db") and tb.name in ctes:
            if tb.name in seen: continue
            out += base_tables(ctes[tb.name], ctes, seen + (tb.name,))
        else:
            out.append(fq(tb))
    return list(dict.fromkeys(out))

def context_of(sel, ctes_nodes):
    p = sel
    while p is not None:
        if isinstance(p, exp.CTE): return f"CTE {p.alias}"
        if isinstance(p, exp.Subquery) and p.alias: return f"subquery {p.alias}"
        p = p.parent
    return "main query"
def analyze(v, text):
    """Rows describing every FROM/JOIN source (table, join condition, filters) in one SQL statement."""
    rows = []
    tree = sqlglot.parse_one(text, dialect="clickhouse")
    ctes = cte_map(tree)
    for sel in tree.find_all(exp.Select):
        srcs = []
        f = sel.args.get("from_") or sel.args.get("from")
        if f: srcs.append((f.this, "FROM", None))
        for j in sel.args.get("joins") or []:
            kind = " ".join(x for x in [j.side, j.kind, "JOIN"] if x).upper()
            cond = j.args.get("on")
            if cond is None and j.args.get("using"):
                cond = exp.Tuple(expressions=j.args["using"]); kind += " USING"
            srcs.append((j.this, kind, cond))
        if not srcs: continue
        where = [c for c in conjuncts(sel.args.get("where")) + conjuncts(sel.args.get("prewhere"))
                 if c.find(exp.Column)]  # drop constant predicates like 1 = 1
        having = conjuncts(sel.args.get("having"))
        ctx = context_of(sel, ctes)
        src_cols = {s_.alias_or_name: output_columns(s_, ctes) for s_, _, _ in srcs}
        owner = {}
        for c_ in where:
            if qualifiers(c_) or len(srcs) == 1: continue
            names_ = {col.name for col in c_.find_all(exp.Column)}
            hits = [a for a, cs in src_cols.items() if cs is not None and names_ and names_ <= cs]
            if len(hits) == 1: owner[id(c_)] = hits[0]
        for src, kind, cond in srcs:
            alias = src.alias_or_name
            if isinstance(src, exp.Table) and not src.args.get("db") and src.name in ctes:
                ref, tables = f"CTE {src.name}", base_tables(ctes[src.name], ctes, (src.name,))
            elif isinstance(src, exp.Table):
                ref, tables = "direct", [fq(src)]
            else:
                ref, tables = f"subquery {alias}", base_tables(src, ctes)
            flt = [c for c in where if alias in qualifiers(c) or (not qualifiers(c) and len(srcs) == 1)
                   or owner.get(id(c)) == alias]
            amb = [c for c in where if not qualifiers(c) and len(srcs) > 1 and id(c) not in owner]
            flt_s = " AND ".join(sql(c) for c in flt)
            if amb: flt_s += (" AND " if flt_s else "") + "[unqualified] " + " AND ".join(sql(c) for c in amb)
            if having and len(srcs) == 1: flt_s += (" | HAVING " + " AND ".join(sql(c) for c in having))
            for t in tables:
                meta = m.get(t, {})
                eng = meta.get("engine", "TableFunction" if t.endswith("[table function]") else "UNKNOWN")
                phys = ";".join(sorted(physical(t))) if "View" in eng else ""
                rows.append({
                    "view_name": v, "context": ctx, "alias": alias, "source_ref": ref,
                    "table": t, "table_engine": eng, "underlying_tables_if_view": phys,
                    "usage": kind, "join_condition": sql(cond), "filter_condition": flt_s,
                })
    return rows

if __name__ == "__main__":
    names = [l.strip() for l in open("datamart_v2_views.txt") if l.strip()]
    rows, errors = [], []
    for v in names:
        try:
            rows += analyze(v, body(m[f"datamart_v2.{v}"]["ddl"]))
        except Exception as ex:
            errors.append((v, str(ex)[:200]))

    cols = list(rows[0].keys())
    with open("view_table_relations.csv", "w", newline="", encoding="utf-8-sig") as fh:
        w = csv.DictWriter(fh, cols); w.writeheader(); w.writerows(rows)
    print("rows", len(rows), "views", len({r['view_name'] for r in rows}), "errors", errors)

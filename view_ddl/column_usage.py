"""Tổng hợp cột dùng để filter / JOIN cho từng bảng mục tiêu, gộp view datamart_v2 và report Jasper."""
import csv, json, re, collections, os
HERE = os.path.dirname(os.path.abspath(__file__))
COLS = json.load(open(os.path.join(HERE, "columns.json")))
T = json.load(open(os.path.join(HERE, "target_tables.json")))
norm = lambda s: re.sub(r"[^a-z0-9]", "", s.lower())

def load(path, key):
    return [dict(r, src=r[key], kind=key) for r in csv.DictReader(open(path, encoding="utf-8-sig"))]
R = load("view_table_relations.csv", "view_name") + load("jasper_table_relations.csv", "report_name")

out = {}
for t in T:
    cols = COLS.get(t, [])
    by_norm = {norm(c): c for c in cols}
    f_cnt, j_cnt, wrapped = collections.Counter(), collections.Counter(), collections.Counter()
    f_src, j_src = collections.defaultdict(set), collections.defaultdict(set)
    for r in R:
        if r["table"] != t: continue
        a = re.escape(r["alias"])
        if r["source_ref"] == "direct":
            # filters directly on the physical table: bare or alias-qualified columns
            for tok in set(re.findall(r"(?<![\w.'])(\w+)(?![\w(])", r["filter_condition"])) | set(re.findall(rf"\b{a}\.(\w+)", r["filter_condition"])):
                if tok in cols:
                    f_cnt[tok] += 1; f_src[tok].add(r["src"])
            for w in re.findall(r"(excludeProperty\(\s*(?:binToString\()?\s*\w+\)?\s*\)|binToString\(\w+\)\s+IN|lower\(\w+\)|toYear\(\w+\)|date\(\w+\)|DATE\([^)]*\))", r["filter_condition"]):
                wrapped[w.split('(')[0] if 'excludeProperty' not in w else 'excludeProperty(...)'] += 1
        else:
            # filters applied on the CTE/subquery alias in outer query -> map renamed column back to base
            for tok in set(re.findall(rf"\b{a}\.(\w+)", r["filter_condition"])):
                c = by_norm.get(norm(tok))
                if c: f_cnt[c] += 1; f_src[c].add(r["src"])
        if r["join_condition"]:
            for tok in set(re.findall(rf"\b{a}\.(\w+)", r["join_condition"])):
                c = tok if tok in cols else by_norm.get(norm(tok))
                if c: j_cnt[c] += 1; j_src[c].add(r["src"])
    out[t] = dict(
        filters=[(c, n, len(f_src[c])) for c, n in f_cnt.most_common()],
        joins=[(c, n, len(j_src[c])) for c, n in j_cnt.most_common()],
        wrapped=dict(wrapped))
json.dump(out, open(os.path.join(HERE, "column_usage.json"), "w"), indent=1, ensure_ascii=False)
for t, u in out.items():
    print(f"\n{t}\n  FILTER: {u['filters'][:8]}\n  JOIN:   {u['joins'][:6]}\n  WRAP:   {u['wrapped']}")

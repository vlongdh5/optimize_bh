"""Trích bảng/JOIN/filter từ SQL trong các report Jasper contingency, dùng lại parser của view_ddl/extract.py."""
import csv, glob, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "view_ddl"))
from extract import analyze

def x_param(m):
    parts = [p.strip() for p in m.group(1).split(",")]
    op, expr, param = parts[0].upper(), ",".join(parts[1:-1]), parts[-1]
    sqlop = {"IN": "IN", "NOTIN": "NOT IN"}.get(op)
    if sqlop:
        return f"{expr} {sqlop} ('${param}')"
    return f"{expr} = '${param}'"

def to_sql(raw):
    s = re.sub(r"\$X\{([^}]*)\}", x_param, raw)
    s = re.sub(r"\$P!\{(\w+)\}", lambda m: "ASC" if "sort" in m.group(1).lower() else "1", s)
    s = re.sub(r"\$P\{(\w+)\}", lambda m: f"'${m.group(1)}'", s)
    return s.rstrip().rstrip(";")

rows, errors = [], []
for f in sorted(glob.glob(os.path.join(HERE, "*.raw.sql"))):
    name = os.path.basename(f)[:-8]
    sql = to_sql(open(f).read())
    open(os.path.join(HERE, f"{name}.sql"), "w").write(sql + "\n")
    try:
        for r in analyze(name, sql):
            r["report_name"] = r.pop("view_name")
            rows.append(r)
    except Exception as ex:
        errors.append((name, str(ex)[:300]))

cols = ["report_name"] + [c for c in rows[0] if c != "report_name"]
with open(os.path.join(HERE, "..", "jasper_table_relations.csv"), "w", newline="", encoding="utf-8-sig") as fh:
    w = csv.DictWriter(fh, cols); w.writeheader(); w.writerows(rows)
print("rows", len(rows), "reports", len({r['report_name'] for r in rows}), "errors", errors)

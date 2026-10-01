import json, sys, time
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(Path(__file__).resolve().parent.parent / ".env")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import bh_client
c = bh_client.get_client(max_execution_time=240)
T = json.load(open("view_ddl/target_tables.json"))
U = json.load(open("view_ddl/column_usage.json"))
out = open("view_ddl/key_stats.jsonl", "a")
for t in T:
    d, n = t.split('.')
    types = dict(c.execute(f"SELECT name,type FROM system.columns WHERE database='{d}' AND table='{n}'"))
    pcol = next((x for x in types if x.lower() in ('propertyid', 'property_id', 'hotelid')), None)
    cand = [x[0] for x in U[t]['filters'][:4]] + [x[0] for x in U[t]['joins'][:3]]
    cand = list(dict.fromkeys(([pcol] if pcol else []) + cand))
    rec = dict(table=t, pcol=pcol, types={k: types.get(k) for k in cand})
    t0 = time.time()
    try:
        exprs = [f"uniqCombined(`{k}`)" for k in cand]
        if pcol:
            ex = f"excludeProperty(binToString(`{pcol}`))" if 'FixedString' in (types[pcol] or '') else f"excludeProperty(toString(`{pcol}`))"
            exprs.append(f"countIf({ex} = 0)")
        rec["stats"] = list(c.execute(f"SELECT count(), {', '.join(exprs)} FROM `{d}`.`{n}`")[0])
    except Exception as e:
        rec["error"] = str(e)[:200]
    rec["sec"] = round(time.time() - t0, 1)
    out.write(json.dumps(rec, default=str) + "\n"); out.flush()
    print(t, rec.get("sec"), rec.get("stats") or rec.get("error"), flush=True)

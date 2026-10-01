"""Benchmark các phiên bản query ARInvoice aging trên ByteHouse.

Chạy: ../.venv/bin/python benchmark.py [số_lần_lặp] [file.sql ...]
Mỗi file được chạy xen kẽ (round-robin) để giảm sai lệch do cache/tải VW,
đo wall time phía client và so checksum kết quả với file đầu tiên.
"""
import hashlib
import statistics
import sys
import time
from pathlib import Path

from bh_client import get_client

HERE = Path(__file__).resolve().parent
DEFAULT_FILES = ["sql_bh.sql"]


def checksum(rows):
    # Kết quả sort theo account_name có thể hòa -> so sánh không phụ thuộc thứ tự
    h = hashlib.md5()
    for line in sorted(repr(r) for r in rows):
        h.update(line.encode())
    return h.hexdigest()


def main():
    args = sys.argv[1:]
    n = int(args.pop(0)) if args and args[0].isdigit() else 5
    files = args or DEFAULT_FILES
    queries = {f: (HERE / f).read_text() for f in files}
    client = get_client()

    times = {f: [] for f in files}
    meta = {}
    for i in range(n):
        for f, sql in queries.items():
            t = time.perf_counter()
            rows = client.execute(sql)
            times[f].append(time.perf_counter() - t)
            meta.setdefault(f, (len(rows), checksum(rows)))
        print(f"round {i + 1}/{n}: " + ", ".join(f"{f}={times[f][-1]:.2f}s" for f in files), flush=True)

    base_rows, base_sum = meta[files[0]]
    base_med = statistics.median(times[files[0]])
    print(f"\n{'file':32} {'rows':>6} {'min':>6} {'median':>7} {'max':>6} {'speedup':>8} same_result")
    for f in files:
        rows, s = meta[f]
        t = times[f]
        med = statistics.median(t)
        print(f"{f:32} {rows:>6} {min(t):>6.2f} {med:>7.2f} {max(t):>6.2f} {base_med / med:>7.2f}x {s == base_sum and rows == base_rows}")


if __name__ == "__main__":
    main()

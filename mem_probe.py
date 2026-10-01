"""Ước lượng RAM đỉnh mỗi node của query bằng dò nhị phân max_memory_usage.

Tài khoản không đọc được system.query_log, nên thay vào đó: chạy query với giới hạn
bộ nhớ X; lỗi Code 241 (Memory limit exceeded) nghĩa là cần > X. Mức thấp nhất chạy
được ≈ RAM đỉnh trên worker nặng nhất (setting áp dụng theo từng node, không phải tổng).

Chạy: ../.venv/bin/python mem_probe.py file.sql [file.sql ...]
"""
import sys
from pathlib import Path

from bh_client import get_client

HERE = Path(__file__).resolve().parent
MiB = 1024 * 1024


def fits(client, sql, limit):
    for _ in range(3):  # thử lại khi VW lỗi tạm thời (không phải lỗi bộ nhớ)
        try:
            client.execute(sql, settings={"max_memory_usage": limit})
            return True
        except Exception as e:
            if "Memory limit" in str(e):
                return False
            client = get_client()
    raise RuntimeError(f"lỗi lặp lại ở limit={limit}")


def peak_mib(sql, lo=1 * MiB, hi=16 * 1024 * MiB, precision=1.1):
    client = get_client()
    if not fits(client, sql, hi):
        return None
    while hi / lo > precision:
        mid = int((lo * hi) ** 0.5)
        if fits(client, sql, mid):
            hi = mid
        else:
            lo = mid
    return lo / MiB, hi / MiB


if __name__ == "__main__":
    for f in sys.argv[1:]:
        r = peak_mib((HERE / f).read_text())
        print(f"{f:48} " + ("> 16 GiB" if r is None else f"{r[0]:8.1f} – {r[1]:8.1f} MiB"), flush=True)

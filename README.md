# Tối ưu query AR aging (sql_bh.sql) trên ByteHouse

## Cấu trúc thư mục

| File | Nội dung |
|---|---|
| `sql_bh.sql` | Query gốc |
| `bh_client.py` | Kết nối ByteHouse (đọc `../.env`) |
| `benchmark.py` | Chạy xen kẽ các query N vòng, đo thời gian, so checksum kết quả với file đầu |
| `variants/v1_rewrite.sql` | **Query đề xuất** (cấp query, dùng ngay được) |
| `variants/v2_no_optimizer.sql`, `v3_orig_no_optimizer.sql` | Thử tắt optimizer (không hiệu quả) |
| `variants/v4_by_property.sql` | Query v1 chạy trên bảng sắp theo PropertyId |
| `structural/01..03, 99` | SQL tạo, nạp, kiểm tra, xóa bảng thử `test_data.ARInvoice_by_property` |

Chạy benchmark: `../.venv/bin/python benchmark.py 12 sql_bh.sql variants/v1_rewrite.sql`

## 1. Phân tích query gốc

**Dữ liệu**

- `ARInvoice`: 7,25 triệu dòng, 2,66 GiB, 11 part, `ORDER BY Id` + `UNIQUE KEY Id`, 72 property.
- Property `9f474bc1…`: 209 nghìn dòng; sau lọc `Type IN (0,1,4)` còn ~186 nghìn; kết quả cuối ~3.3 nghìn dòng.
- `AccountsReceivable` (2,8 nghìn dòng) và `ARCreditLimit` (6,7 nghìn dòng) không có khóa trùng, nên join không nhân dòng.

**Kế hoạch thực thi** (`EXPLAIN ANALYZE`)

- Optimizer đã đẩy toàn bộ điều kiện lọc xuống `TableScan ARInvoice`.
- Bảng không có thống kê (`Est. ?`).
- Hai bảng nhỏ được broadcast hash join.

**Phân rã thời gian** (median, cache ấm; lần chạy nguội đầu tiên ~5,4 s)

| Bước | Thời gian |
|---|---|
| Độ trễ nền (`SELECT 1`, mạng + lập lịch) | 0,32 s |
| Quét 7,2 triệu dòng + lọc (chỉ `count`) | 0,43 s |
| + đọc 15 cột kết quả | 0,68 s |
| + `ORDER BY` | ~0,84 s |
| **Query gốc** (thêm 2 join, CTE lồng, sort 2 tầng) | **1,37 – 1,47 s** |

**Nguyên nhân gốc:** `ARInvoice` sắp xếp vật lý theo `Id` (UUID ngẫu nhiên).

- Mỗi granule 8192 dòng chứa ~240 dòng của property này.
- Vì vậy lọc theo `PropertyId` không cắt được granule nào: luôn phải quét toàn bảng.
- PREWHERE và skip index (bloom/set trên `PropertyId`, `Status`) cũng vô dụng với cách phân bố này.

## 2. Giải pháp cấp query: `variants/v1_rewrite.sql`

Các thay đổi (kết quả giữ nguyên 100%, đã so checksum):

1. Bỏ 3 CTE và `select * from (...)` bọc ngoài. Plan gọn hơn, ít projection/exchange.
2. Tính `biz_date` một lần bằng `WITH`, dùng lại cho `age`.
3. Lọc `ARCreditLimit` theo `PropertyId` trước khi join (6,7 nghìn → vài trăm dòng).
4. Viết gọn điều kiện `status`: `toDate(InvoiceDate) <= biz_date AND (Status = 0 OR (Status = 1 AND toDate(DateBalance) > biz_date))`.

Kết quả (12 vòng xen kẽ, VW dùng chung nên có nhiễu):

| Query | min | median | max | Kết quả |
|---|---|---|---|---|
| `sql_bh.sql` (gốc) | 1,25 s | 1,47 s | 2,19 s | 3321 dòng |
| `v1_rewrite.sql` | 1,00 s | **1,10 s** | 2,38 s | giống hệt |

→ **Nhanh hơn ~1,3 lần.**

Tắt optimizer (`enable_optimizer = 0`) không có lợi: v2 mất 1,23 s, còn query gốc tắt optimizer còn chậm hơn (1,64 s).

Giới hạn: query vẫn quét toàn bảng 7,2 triệu dòng, nên sàn khoảng 0,7–0,8 s.

## 3. Giải pháp cấu trúc: sắp xếp dữ liệu theo PropertyId

Tạo bảng có `ORDER BY (PropertyId, Type, Status)`, giữ `UNIQUE KEY Id` để upsert từ CDC vẫn đúng. Query lọc 1 property khi đó chỉ đọc khoảng 26/885 granule (~3%) thay vì toàn bảng.

Các bước thử (bạn tự chạy):

1. `structural/01_create_table.sql`: tạo bảng.
2. `structural/02_insert.sql`: nạp dữ liệu (~7,2 triệu dòng).
3. `structural/03_verify.sql`: so số dòng.
4. `../.venv/bin/python benchmark.py 12 sql_bh.sql variants/v1_rewrite.sql variants/v4_by_property.sql`
5. `structural/99_drop.sql`: xóa sau khi đo.

### Kết quả đo trên bảng thử (29/09/2026)

Bảng thử có 7.249.979 dòng, 9 part, 1,00 GiB (chỉ các cột cần dùng).

**Đúng đắn**

- So với v1 trên bảng nguồn, v4 chỉ thiếu 2 dòng. Cả hai là hóa đơn ngày 29/09 do CDC ghi sau lúc snapshot.
- Không có dòng nào khác giá trị.

**`EXPLAIN ANALYZE`**

| | Bảng gốc | Bảng mới |
|---|---|---|
| TableScan ARInvoice | 225 ms, đọc 7,2 triệu dòng | **18 ms, đọc 3,5 nghìn dòng** |
| Tổng phần thực thi | ~240 ms | ~30 ms |

**Wall time đầy đủ** (12 vòng xen kẽ, VW lúc đo tải nặng hơn lần trước)

| Query | min | median | max | Tăng tốc |
|---|---|---|---|---|
| `sql_bh.sql` | 1,57 s | 1,95 s | 3,27 s | 1,00x |
| `v1_rewrite.sql` | 1,22 s | 1,52 s | 4,77 s | 1,29x |
| `v4_by_property.sql` | 0,87 s | **1,26 s** | 1,95 s | **1,55x** |

**Server-side, không tính truyền kết quả** (bọc `select count(), sum(cityHash64(*)) from (...)`, 10 vòng)

| Query | median | Phần vượt độ trễ nền 0,40 s |
|---|---|---|
| `sql_bh.sql` | 1,33 s | 0,93 s |
| `v1_rewrite.sql` | 0,98 s | 0,58 s |
| `v4_by_property.sql` | 0,71 s | **0,31 s (giảm 3x)** |

**Nhận xét**

- Với bảng mới, phần tính toán gần như bằng 0 (~30 ms). Thời gian còn lại là chi phí cố định:
  - độ trễ mạng và lập lịch VW: ~0,4 s;
  - lập kế hoạch và lấy metadata/part cho 3 bảng: ~0,3 s;
  - truyền và giải mã ~1,4 MB kết quả về client Python: ~0,5 s.
- Tăng tốc sẽ rõ hơn khi:
  - chạy nhiều property hoặc chạy đồng thời, vì không còn quét 7,2 triệu dòng mỗi lần;
  - VW bận, vì query nhẹ hơn nhiều nên ít bị tranh tài nguyên;
  - query không có cache ấm (lần chạy nguội của bản gốc mất ~5,4 s).

### Kết quả trên bảng đủ cột (sát production)

Bảng `test_data.ARInvoice_by_property_full`:

- 55 cột, kiểu, `Nullable` và `DEFAULT` y hệt bảng gốc; chỉ khác `ORDER BY (PropertyId, Type, Status)`.
- 7.250.047 dòng, 2,14 GiB, **33 part** (chưa merge xong; bảng gốc có 11 part).

**Đúng đắn**

- So với v1, v5 chỉ thiếu 10 dòng. Tất cả là hóa đơn ngày 29/09 do CDC ghi sau lúc snapshot.
- Không có dòng nào khác giá trị.

**`EXPLAIN ANALYZE`:** TableScan mất **19,6 ms**, đọc 3,4 nghìn dòng (bảng gốc: 225 ms, 7,2 triệu dòng).

**Kết quả đo** (10 vòng xen kẽ; bỏ một lượt khác bị nhiễu VW, max 36 s)

| Query | Median đầy đủ | Tăng tốc | Median server-side | Tăng tốc |
|---|---|---|---|---|
| `sql_bh.sql` | 1,40 s | 1,00x | 1,26 s | 1,00x |
| `v1_rewrite.sql` | 1,08 s | 1,29x | 0,93 s | 1,36x |
| `v4_by_property.sql` (17 cột, key non-Nullable) | 0,82 s | 1,71x | 0,67 s | 1,88x |
| `v5_by_property_full.sql` (55 cột, giữ Nullable) | **0,99 s** | **1,42x** | **0,74 s** | **1,71x** |

**v5 chậm hơn v4 khoảng 0,07–0,17 s**, dù scan gần như bằng nhau (19,6 ms so với 18 ms). Phần chênh nằm ở chi phí cố định. Nguyên nhân khả dĩ:

1. 33 part so với 9: nhiều metadata và task phải lập lịch hơn. Phần này sẽ tự giảm khi ByteHouse merge xong.
2. Khóa sắp xếp `Nullable` và `String` thường, so với `LowCardinality` non-Nullable.

→ Nếu tạo lại bảng production:

- Nên cân nhắc đổi `PropertyId` sang `LowCardinality(String)` và bỏ `Nullable` ở 3 cột khóa. Nguồn MySQL không có NULL ở các cột này; cần kiểm tra pipeline CDC chấp nhận kiểu mới.
- Nếu không đổi kiểu được, chỉ đổi `ORDER BY` vẫn nhanh hơn ~1,7x ở phía server.

### Có cần partition / index không?

- **ORDER BY là đủ, và là thay đổi quyết định.**
  - `PropertyId` đứng đầu để primary index cắt granule.
  - `Type` và `Status` đứng sau giúp cắt thêm các type 2/5/6 (~11%).
  - Kiểu `LowCardinality(String)` và bỏ `Nullable` (nguồn không có NULL) giúp khóa gọn và so sánh nhanh hơn.
- **Không partition.**
  - 2,66 GiB là nhỏ.
  - Partition theo `PropertyId` tạo 72 partition với nhiều part vụn, merge kém, mà không lợi hơn ORDER BY.
  - Partition theo tháng `InvoiceDate` vô dụng, vì query aging lấy toàn bộ lịch sử (hóa đơn mở cũ tới ~7 năm).
- **Không cần skip index.** Khi dữ liệu đã sắp theo `PropertyId`, primary index làm hết việc. Một minmax index trên `InvoiceDate` cũng không giúp, vì điều kiện là `<= today` (gần như mọi dòng).
- `index_granularity = 8192` giữ mặc định. Mỗi property ~200 nghìn dòng tương đương ~26 granule, đủ mịn.

### Áp dụng production

Chọn một trong hai cách:

- **(A) Tạo lại chính bảng `ARInvoice` với ORDER BY mới** (khuyến nghị, nếu pipeline CDC cho phép tạo lại bảng đích). Mọi query lọc theo property trên bảng này đều hưởng lợi, không phải duy trì thêm gì.
- **(B) Bảng phụ + Materialized View** từ `ARInvoice`. Upsert vẫn đúng nhờ `UNIQUE KEY Id`. Cần lưu ý:
  - Nếu CDC có xóa dòng, lệnh xóa không truyền qua MV.
  - Tốn thêm dung lượng lưu trữ.

## 4. Lỗi logic cần xác nhận với nghiệp vụ

`age = dateDiff('day', today, invoice_date) + 1`

Vì `invoice_date <= today`, `age` luôn ≤ 1. Thực tế đo được khoảng -2608 … 1. Hệ quả:

- **Mọi hóa đơn đều rơi vào `age_1_30`.**
- Các cột `age_31_60 … age_180` luôn bằng 0.

Nhiều khả năng cần đảo thứ tự tham số:

```sql
dateDiff('day', toDate(InvoiceDate), biz_date) + 1 as age
```

Các file tối ưu hiện giữ nguyên logic cũ để so kết quả; hãy sửa sau khi nghiệp vụ xác nhận.

---

# Báo cáo 2: `sql2.sql` (số dư theo reservation/folio, Reservation × PostTransaction × Folio)

## Dữ liệu

Tất cả thuộc `vp_prod_ops_transaction_account`:

| Bảng | Số dòng | Dung lượng | Sắp xếp / partition | Dòng của property |
|---|---|---|---|---|
| `PostTransaction` | 214,3 triệu | 88,3 GiB, 110 part | `PARTITION BY toYYYYMM(CreatedAt)` (80 tháng, 02/2020–09/2026), `ORDER BY (Id, PropertyId)` | 9,43 triệu |
| `Folio` | 10,6 triệu | 2,48 GiB | `ORDER BY Id` | 482 nghìn |
| `Reservation` | 6,2 triệu | 2,16 GiB | `ORDER BY Id` | 345 nghìn |

- Tập reservation cần dùng chỉ có **130 dòng** (129 `Inhouse`, 1 `Canceled` + `GL`).
- 130 reservation này có **17.963 giao dịch**, trong đó 12.551 dòng thỏa `State = 1` và `IncludeExclude & 1`.
- Kết quả cuối: ~120 dòng.

## Phân tích query gốc

**Thời gian đo được** (VW dùng chung, nhiễu rất lớn)

| Lần chạy | Thời gian |
|---|---|
| Cache nguội | **509,6 s** |
| Các lần khác | 96 s, 48,8 s (`EXPLAIN ANALYZE`), 34,6 s, 19,0 s, 10,1 s |

**Điểm nghẽn** (`EXPLAIN ANALYZE`)

1. **Quét toàn bảng `PostTransaction`** (41,6 s trong lần đo này):
   - `Id` đứng đầu khóa sắp xếp nên lọc `PropertyId` không cắt được granule nào.
   - Không có điều kiện `CreatedAt` nên không cắt được partition nào.
   - Lọc xong còn 6,6 triệu dòng (1,1 GB).
2. **Join 6,6 triệu dòng với `Folio`** (482 nghìn dòng), trong khi chỉ cần giao dịch của 130 reservation.
3. **Optimizer broadcast nhầm phía lớn** (6,6 triệu dòng, 1,1 GB) sang join với `Reservation`. Nguyên nhân: không có thống kê (`Est. ?`).
4. **`Reservation` bị quét 2 lần** (2 nhánh `UNION ALL`), và **`Folio` quét toàn bảng** (~5–6 s mỗi bảng).

## Giải pháp cấp query: `sql2_variants/s1_rewrite.sql`

Kết quả giống hệt query gốc (cùng checksum, 120 dòng).

**Các thay đổi**

1. Gộp 2 nhánh `UNION ALL` thành 1 điều kiện: `Status IS NOT NULL AND (lower(Status) = 'inhouse' OR CurrentLedger = 'GL')`.
2. Lọc `PostTransaction` bằng `ReservationId IN (reservation)`, rồi gộp theo `(ReservationId, FolioId, ConfirmationNumber)` ngay sau khi quét: 6,6 triệu → 12,6 nghìn → 120 dòng.
3. Join `Reservation` và `Folio` sau khi gộp.
4. `LEFT JOIN` + `WHERE` trên bảng phải được viết thẳng thành `INNER JOIN`.

**Kết quả `EXPLAIN ANALYZE`**

- Plan đúng hướng: semi join + gộp sớm; không còn broadcast 1,1 GB và join 6,6 triệu dòng với `Folio`.
- **Nhưng quét `PostTransaction` vẫn phải đọc đủ 214 triệu dòng** (16–42 s tùy tải). Phần tiết kiệm được (~1–2 s) nhỏ hơn nhiều so với độ nhiễu của VW.
- 3 vòng xen kẽ: query gốc median 19,0 s (10–35 s), s1 median 19,9 s (18–45 s). **Không đo được khác biệt tin cậy.**

**Đã thử và loại bỏ:** cắt partition bằng `CreatedAt >= min(Reservation.CreatedAt)`.

- Nếu an toàn, cách này giảm được 51% dữ liệu phải quét.
- Nhưng có giao dịch được tạo **trước** reservation của nó: giao dịch cũ nhất 01/05/2024, reservation cũ nhất 21/08/2024. Áp dụng sẽ mất dữ liệu.

→ Với cấu trúc bảng hiện tại, query **luôn phải quét toàn bộ 214 triệu dòng**. Chỉ đổi cách sắp xếp dữ liệu mới giảm được đáng kể.

## Giải pháp cấu trúc: `sql2_structural/`

Mỗi bảng giữ đủ cột, kiểu, Nullable, DEFAULT, `PARTITION BY`, `UNIQUE KEY` như bảng gốc; chỉ đổi `ORDER BY`.

| Bảng | ORDER BY mới | Lý do |
|---|---|---|
| `PostTransaction` | `(PropertyId, ReservationId, Id)` | Lọc property + 130 reservation chỉ đọc vài granule trong mỗi partition, thay vì ~26 nghìn granule |
| `Reservation` | `(PropertyId, Id)` | Chỉ đọc ~5% bảng (1 property / 84) |
| `Folio` | `(PropertyId, Id)` | idem |

- Giữ `PARTITION BY toYYYYMM(CreatedAt)` cho `PostTransaction`, như bảng gốc. Partition không giúp query này, nhưng giữ để bảng thử sát production và phục vụ các báo cáo lọc theo thời gian.
- `Id` đứng cuối khóa để phân bố ổn định. `UNIQUE KEY (Id, PropertyId)` và `partition_level_unique_keys = 1` giữ nguyên.
- Không cần skip index: primary index trên `(PropertyId, ReservationId)` làm hết việc.

**Các bước (bạn tự chạy)**

1. `01..03_create_*.sql`: tạo 3 bảng.
2. `04_insert_PostTransaction.sql`: 8 lệnh insert theo năm (88 GiB, nên chạy ngoài giờ cao điểm).
3. `05_insert_Reservation_Folio.sql`.
4. `06_verify.sql`: so số dòng.
5. `../.venv/bin/python benchmark.py 3 sql2.sql sql2_variants/s1_rewrite.sql sql2_variants/s2_by_property.sql`
6. `99_drop.sql`: xóa 3 bảng thử.

### Kết quả trên 3 bảng thử (29/09/2026)

**Bảng thử**

| Bảng | Số dòng | Dung lượng | Part |
|---|---|---|---|
| `PostTransaction_by_property` | 214,3 triệu | **44,1 GiB** (bảng gốc 88,3 GiB: sắp theo property/reservation nén tốt gấp đôi) | 311 (chưa merge xong; gốc 110), 80 partition |
| `Reservation_by_property` | 6,2 triệu | 1,66 GiB | 1 |
| `Folio_by_property` | 10,6 triệu | 2,35 GiB | 1 |

**Đúng đắn**

- s2 thiếu 7 dòng so với s1 trên bảng nguồn; không có dòng nào khác giá trị.
- Cả 7 đều thuộc folio có giao dịch được tạo hoặc cập nhật sáng 29/09 (08:20–09:38), sau lúc snapshot.
- Có thêm 1 reservation mới chuyển `Inhouse` lúc 08:19.

**`EXPLAIN ANALYZE` s2: 3,2 s** (query gốc 30–49 s trong các lần đo trước)

| TableScan | Bảng gốc | Bảng mới |
|---|---|---|
| `PostTransaction` | 16–42 s, đọc 214 triệu dòng | **2,1 s, đọc 11,6 triệu dòng (5,4%)** |
| `Reservation` (×2) | ~6 s | **~30 ms** |
| `Folio` | ~6 s | **~24 ms** |

**Wall time** (3 vòng xen kẽ; lúc đo VW rảnh và cache ấm nên query gốc nhanh bất thường)

| Query | min | median | max | Tăng tốc |
|---|---|---|---|---|
| `sql2.sql` | 3,80 s | 3,94 s | 5,20 s | 1,00x |
| `s1_rewrite.sql` | 3,52 s | 3,76 s | 6,92 s | 1,05x |
| `s2_by_property.sql` | 1,18 s | **1,21 s** | 2,12 s | **3,26x** |
| `s3_by_property_no_optimizer.sql` | 1,24 s | 1,24 s | 1,32 s | 3,17x |

**Nhận xét**

- **Con số 3,3x là trường hợp tốt nhất cho query gốc** (cache ấm, VW rảnh).
  - Khi cache nguội hoặc VW bận, query gốc mất 10–510 s, vì phải đọc toàn bộ 214 triệu dòng từ HDFS.
  - s2 chỉ đọc ~5% dữ liệu, trên bảng nhỏ bằng một nửa, nên chênh lệch thực tế lớn hơn nhiều.
  - Chỉ số ổn định nhất là **lượng dữ liệu đọc: giảm ~95%**.
- **s3 (tắt optimizer) không nhanh hơn s2.**
  - `ReservationId IN (...)` vẫn chưa cắt thêm được granule trong phạm vi property. Scan vẫn đọc toàn bộ ~11,6 triệu dòng của property.
  - Muốn cắt tiếp theo reservation phải truyền danh sách `ReservationId` hằng vào query. Không thực tế cho báo cáo; phần còn lại chỉ khoảng 1 s.
- **Khuyến nghị:** đổi `ORDER BY` cho cả 3 bảng như `sql2_structural/`, dùng query `s2` (bỏ `test_data.` và hậu tố `_by_property` khi áp dụng lên bảng thật).
  - Các báo cáo khác lọc theo `PropertyId` trên 3 bảng này cũng hưởng lợi tương tự.
  - Riêng `PostTransaction` còn giảm một nửa dung lượng lưu trữ.

---

# Tổng kết: thời gian và RAM

**Cách đo RAM:** dò nhị phân `max_memory_usage` bằng `mem_probe.py`, vì tài khoản không có quyền đọc `system.query_log`.

- Con số là **RAM đỉnh trên node nặng nhất** (setting áp dụng theo từng worker), sai số khoảng ±7%.
- Đây không phải tổng RAM của cả VW.

## Báo cáo 1: `sql_bh.sql` (AR aging)

| Phiên bản | Wall time (median, cache ấm) | Dòng đọc từ ARInvoice | RAM đỉnh / node |
|---|---|---|---|
| Gốc | 1,40 s (nguội 5,4 s) | 7,2 triệu | ~195 MiB |
| v1: viết lại query | 1,08 s (−23%) | 7,2 triệu | ~195 MiB |
| v5: bảng sắp theo PropertyId | **0,99 s (−29%)** | **3,4 nghìn** | **~14 MiB (−93%)** |

Server-side (không tính truyền kết quả): 1,26 s → 0,74 s (−41%). Trong đó ~0,4 s là độ trễ nền cố định.

## Báo cáo 2: `sql2.sql` (Reservation × PostTransaction × Folio)

| Phiên bản | Wall time (median, cache ấm, VW rảnh) | Dòng đọc từ PostTransaction | RAM đỉnh / node |
|---|---|---|---|
| Gốc | 3,94 s (VW bận 10–96 s; nguội 509 s) | 214 triệu | ~820 MiB |
| s1: viết lại query | 3,76 s (−5%) | 214 triệu | ~285 MiB (−65%) |
| s2: 3 bảng sắp theo PropertyId | **1,21 s (−69%)** | **11,6 triệu (−95%)** | **~210 MiB (−75%)** |

# Đề xuất tối ưu bảng ByteHouse

Sep 30, 2026 · Long Đặng Hải

> Bản lưu trong repo của tài liệu [Đề xuất tối ưu bảng ByteHouse](https://claude.ai/code/artifact/229c315c-419c-4634-a351-e173651482e5) (bản online, rev 11). Khi hai bản lệch nhau, bản online là bản mới nhất.
>
> Dữ liệu phân tích đi kèm: [view_table_relations.csv](view_table_relations.csv), [jasper_table_relations.csv](jasper_table_relations.csv), [vp_tables_size.csv](vp_tables_size.csv), [vp_tables_usage.csv](vp_tables_usage.csv), [jasper_tables_usage.csv](jasper_tables_usage.csv), [view_ddl/column_usage.json](view_ddl/column_usage.json), SQL báo cáo trong [jasper_sql/](jasper_sql/).

## Tổng quan

30 bảng (tổng 273 GB) chia 3 mức: 9 bảng P1 (147 GB) làm trước vì nặng nhất hoặc được nhiều view/báo cáo dùng nhất; 12 bảng P2 làm đợt sau; 9 bảng P3 để cuối hoặc giữ nguyên.

Nguồn: 28 bảng từ 111 view của `datamart_v2` (giữ bảng ≥ 1 triệu dòng hoặc ≥ 1 GB, rồi rút gọn thủ công), cộng 2 bảng từ 19 báo cáo Jasper contingency (`hk_v2_group_room`, `task`). Tên bảng bỏ tiền tố `vp_prod_ops_` / `vp_prod_`. Cột View / Báo cáo = số view, số báo cáo đọc bảng đó.

| # | Bảng | GB | Triệu dòng | View | Báo cáo | Ưu tiên | Hướng xử lý |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | transaction_account.PostTransaction | 88,4 | 214,4 | 14 | 5 | P1 | Đổi ORDER BY + sửa SQL |
| 2 | transaction_account.EInvoiceTransactionParty | 33,9 | 141,2 | 1 | 0 | P1 | Đổi ORDER BY |
| 3 | pms_rate.AllotmentInventoryRecord | 6,1 | 34,4 | 15 | 0 | P1 | Đổi ORDER BY |
| 4 | front_office.PmsProfile | 4,6 | 26,7 | 30 | 12 | P1 | Đổi ORDER BY + sửa SQL |
| 5 | front_office.ReservationRoomRate | 4,1 | 14,7 | 10 | 3 | P1 | Đổi ORDER BY + sửa SQL |
| 6 | pms_house_keeping.hk_v2_group_room | 3,1 | 16,3 | 0 | 1 | P1 | Đổi ORDER BY + sửa SQL |
| 7 | front_office.Reservation | 2,6 | 6,2 | 36 | 12 | P1 | Đổi ORDER BY + sửa SQL |
| 8 | pms_profile.Profile | 2,1 | 10,0 | 26 | 11 | P1 | Sửa SQL |
| 9 | aux_task_management.task | 1,7 | 8,6 | 1 | 1 | P1 | Đổi ORDER BY |
| 10 | activity_log.activity_log | 44,9 | 163,8 | 4 | 0 | P2 | Đổi ORDER BY |
| 11 | front_office.ReservationSnapshot | 13,1 | 19,2 | 6 | 0 | P2 | Đổi ORDER BY + thêm PARTITION |
| 12 | front_office.StayingSnapshot | 11,7 | 43,1 | 4 | 0 | P2 | Đổi ORDER BY + thêm PARTITION |
| 13 | transaction_account.AutomationPostingActivity | 8,2 | 38,0 | 4 | 0 | P2 | Đổi ORDER BY |
| 14 | pms_fnb.OrderDetails | 6,6 | 33,7 | 1 | 0 | P2 | Đổi ORDER BY + sửa SQL |
| 15 | pms_rate.RoomInventoryRecord | 5,4 | 31,4 | 1 | 0 | P2 | Sửa SQL + đổi ORDER BY |
| 16 | pms_fnb.Orders | 2,9 | 16,8 | 6 | 0 | P2 | Đổi ORDER BY |
| 17 | accounts_receivable.ARInvoice | 2,7 | 7,3 | 1 | 1 | P2 | Đổi ORDER BY + sửa SQL |
| 18 | front_office.Staying | 2,6 | 13,4 | 7 | 2 | P2 | Đổi ORDER BY |
| 19 | transaction_account.Folio | 2,5 | 10,6 | 4 | 2 | P2 | Đổi ORDER BY |
| 20 | transaction_account.Reservation | 2,2 | 6,2 | 2 | 2 | P2 | Đổi ORDER BY |
| 21 | front_office.CheckIn | 0,5 | 4,9 | 7 | 3 | P2 | Đổi ORDER BY |
| 22 | transaction_account.post_transaction_gross_info | 6,2 | 60,1 | 1 | 0 | P3 | Giữ nguyên |
| 23 | transaction_account.PostTransactionInhouseInfo | 3,4 | 25,9 | 1 | 0 | P3 | Sửa SQL |
| 24 | pms_fnb.OrderPayments | 2,9 | 21,0 | 4 | 0 | P3 | Đổi ORDER BY |
| 25 | res_booking.ReservationRoomRate | 2,6 | 18,1 | 3 | 0 | P3 | Đổi ORDER BY |
| 26 | front_office.reservation_package_update_log | 2,3 | 2,9 | 1 | 0 | P3 | Sửa SQL |
| 27 | res_booking.Reservation | 2,0 | 8,3 | 3 | 0 | P3 | Đổi ORDER BY |
| 28 | transaction_account.PostTransactionForecast | 2,0 | 6,0 | 2 | 0 | P3 | Đổi ORDER BY |
| 29 | transaction_account.EInvoiceSummary | 1,1 | 3,5 | 2 | 0 | P3 | Đổi ORDER BY |
| 30 | front_office.RoomAssignment | 0,7 | 7,5 | 4 | 1 | P3 | Đổi ORDER BY |

## Nguyên tắc thiết kế

Hầu hết 30 bảng đang `ORDER BY Id`, nên mọi filter theo khách sạn, ngày hay trạng thái đều phải quét toàn bảng. Đề xuất chỉ đổi ORDER BY (và PARTITION BY ở 2 bảng), giữ nguyên UNIQUE KEY để không ảnh hưởng cơ chế upsert của pipeline nạp dữ liệu.

1. **ORDER BY độc lập với UNIQUE KEY.** Trên CnchMergeTree, UNIQUE KEY lo khử trùng, ORDER BY lo sắp xếp và index; hai khóa có thể khác nhau ([ByteHouse](https://docs.byteplus.com/en/docs/bytehouse/bytehouse-best-practice-for-unique-key-tables), [ByConity](https://byconity.github.io/docs/table-design/unique-key)).
2. **Cột đầu ORDER BY = `PropertyId`.** Bảng có khoảng 70–80 khách sạn; 19/19 báo cáo contingency và phần lớn view đều lọc theo khách sạn. Đặt `PropertyId` đầu tiên thì mỗi báo cáo chỉ đọc khoảng 1–2% bảng.
3. **Cột thứ hai = cột ngày hay bị lọc theo khoảng** (`BusinessDate`, `ArrivalDate`, `StayingDate`, `date`…), cột cuối = khóa JOIN hoặc `Id`. Hàm đơn điệu như `toYear(col)`, `date(col)` vẫn dùng được index.
4. **PARTITION chỉ theo cột không bao giờ đổi.** Các bảng có partition đang `partition_level_unique_keys = 1`: UNIQUE KEY chỉ khử trùng trong một partition. Nếu partition theo cột có thể đổi (ví dụ `ArrivalDate`), bản ghi cũ và mới nằm hai partition → trùng dòng. Chỉ dùng `CreatedAt` hoặc ngày snapshot.
5. **Filter phải áp thẳng lên cột.** `binToString(PropertyId) IN (…)` không dùng được index dù `PropertyId` nằm trong ORDER BY. Đổi khóa mà không sửa SQL tương ứng thì không có tác dụng (xem phần Tối ưu SQL).
6. **JOIN không tự hưởng lợi từ ORDER BY.** Hash join đọc toàn bộ bảng bên phải. Muốn cắt bớt phải đẩy điều kiện xuống dạng `col IN (SELECT …)` — khi đó `col` đứng đầu ORDER BY mới có ích.
7. **Không đổi kiểu cột, không đổi `index_granularity` (8192).** Các cột khóa Nullable vẫn dùng được vì bảng đã có `allow_nullable_key = 1`.

## Re-structure từng bảng

26/30 bảng đổi ORDER BY (trong đó 2 bảng snapshot thêm PARTITION), 4 bảng giữ khóa và chỉ sửa SQL. UNIQUE KEY và các SETTINGS khác giữ nguyên ở cả 30 bảng. Số trong cột Căn cứ = số lần cột xuất hiện trong filter/JOIN của view và báo cáo.

| # | Bảng | ORDER BY hiện tại | ORDER BY đề xuất | PARTITION BY | Căn cứ |
| --- | --- | --- | --- | --- | --- |
| 1 | PostTransaction | (Id, PropertyId) | (PropertyId, BusinessDate, Id) | Giữ toYYYYMM(CreatedAt) | Lọc PropertyId 13, BusinessDate 11; 5 báo cáo ledger/journal lọc PropertyId IN |
| 2 | EInvoiceTransactionParty | Id | (PostTransactionId, Id) | Giữ toYYYYMM(CreatedAt) | Filter duy nhất có ích: PostTransactionId IN (SELECT id FROM post_transaction) |
| 3 | AllotmentInventoryRecord | id | (date, allotmentId, id) | — | Lọc date ở 7 view; JOIN theo (allotmentId, date) 12 lần |
| 4 | PmsProfile | Id | (PropertyId, ReservationId, Id) | — | Lọc ProfileType 16, PropertyId 9; JOIN ReservationId 32 lần |
| 5 | front_office.ReservationRoomRate | Id | (PropertyId, StayingDate, ReservationId) | — | Báo cáo lọc StayingDate = hôm nay hoặc 180 ngày tới; JOIN ReservationId 11 |
| 6 | hk_v2_group_room | id | (groupId, id) | — | Chỉ JOIN theo groupId; cần SQL đẩy groupId IN (…) xuống |
| 7 | front_office.Reservation | Id | (PropertyId, ArrivalDate, Id) | — | Lọc Status 23, PropertyId 22, ArrivalDate 8, DepartureDate 4 |
| 8 | Profile | Id | Giữ Id | — | 20/24 lần đọc không filter, JOIN theo Id 52 lần → sửa SQL, Id đã đúng khóa |
| 9 | task | tmCode | (hotelId, dueDate, tmCode) | — | task_list lọc hotelId + dueDate ≥ hôm nay: giữ 12,4 nghìn / 8,55 triệu dòng (0,14%) |
| 10 | activity_log | id | (property_id, created_at, id) | Giữ toYYYYMM(created_at) | Lọc created_at 3, property_id; JOIN id |
| 11 | ReservationSnapshot | Id | (PropertyId, BizDateSnapshotAt, ReservationId) | Thêm toYYYYMM(BizDateSnapshotAt) | JOIN theo (ReservationId, BizDateSnapshotAt); ngày snapshot không đổi |
| 12 | StayingSnapshot | Id | (PropertyId, BizDateSnapshotAt, ReservationId) | Thêm toYYYYMM(BizDateSnapshotAt) | Như ReservationSnapshot |
| 13 | AutomationPostingActivity | Id | (PropertyId, ReservationId, Id) | — | Lọc PropertyId 3, State 2; JOIN ReservationId |
| 14 | OrderDetails | Id | (OrderId, Id) | — | JOIN theo OrderId; kèm SQL OrderId IN (SELECT id FROM orders) |
| 15 | RoomInventoryRecord | id | (propertyId, date, roomTypeId, id) | — | View đọc toàn bảng; phải thêm filter date vào view trước |
| 16 | Orders | Id | (PropertyId, BusinessDate, Id) | — | Lọc OrderStatus 3, BusinessDate, CreatedDate |
| 17 | ARInvoice | Id | (PropertyId, Type, Id) | — | aging_summary lọc PropertyId IN + Type |
| 18 | Staying | Id | (PropertyId, ReservationId, Id) | — | JOIN ProfileId 3, ReservationId 2 |
| 19 | Folio | Id | (PropertyId, Id) | — | guest_ledger lọc PropertyId IN; JOIN Id 6 |
| 20 | transaction_account.Reservation | Id | (PropertyId, Status, Id) | — | guest_ledger lọc PropertyId IN + Status IN |
| 21 | CheckIn | Id | (PropertyId, ReservationId, Id) | — | JOIN ReservationId 10 |
| 22 | post_transaction_gross_info | post_id | Giữ | — | Đã khớp filter post_id IN (…) |
| 23 | PostTransactionInhouseInfo | PostTransactionId | Giữ | — | Đã khớp khóa JOIN; chỉ cần SQL đẩy PostTransactionId IN (…) |
| 24 | OrderPayments | Id | (OrderId, Id) | — | JOIN OrderId 2 |
| 25 | res_booking.ReservationRoomRate | ID | (ReservationID, StayDate, ID) | — | JOIN ReservationID 3 |
| 26 | reservation_package_update_log | id | Giữ | — | Chỉ lọc bằng UDF; view đọc bảng 4 lần → sửa view |
| 27 | res_booking.Reservation | ID | (PropertyID, ID) | — | Lọc PropertyID |
| 28 | PostTransactionForecast | Id | (PropertyId, BusinessDate, Id) | — | Lọc BusinessDate, State |
| 29 | EInvoiceSummary | Id | (PropertyId, Id) | — | Lọc PropertyId 2, Status 2 |
| 30 | RoomAssignment | Id | (PropertyId, FromDate, ReservationId) | — | Lọc State 4, FromDate; JOIN ReservationId |

Ví dụ DDL cho PostTransaction — danh sách cột lấy nguyên từ `SHOW CREATE TABLE`, chỉ thay ORDER BY:

```sql
CREATE TABLE vp_prod_ops_transaction_account.PostTransaction_v2
(
    -- ... toàn bộ cột giữ nguyên như bảng cũ ...
)
ENGINE = CnchMergeTree
PARTITION BY toYYYYMM(CreatedAt)
ORDER BY (PropertyId, BusinessDate, Id)   -- cũ: (Id, PropertyId)
UNIQUE KEY (Id, PropertyId)                -- giữ nguyên
SETTINGS partition_level_unique_keys = 1, allow_nullable_key = 1,
         storage_dialect_type = 'MYSQL', index_granularity = 8192;
```

Với 2 bảng snapshot, chỉ đặt `partition_level_unique_keys = 1` khi xác nhận một `Id` không bao giờ đổi `BizDateSnapshotAt`; nếu chưa chắc thì giữ `0` (khử trùng toàn bảng, ghi chậm hơn).

## Tối ưu SQL

Có 5 lỗi lặp lại trong view và báo cáo. Lỗi 1 và 2 phải sửa cùng lúc với đổi ORDER BY, nếu không khóa mới không có tác dụng. Lỗi 3–5 sửa được ngay, không cần đổi bảng.

| # | Lỗi | Số chỗ | Cách sửa |
| --- | --- | --- | --- |
| 1 | `binToString(PropertyId) IN (…)` bọc cột trong hàm | 11 báo cáo, 1 view | So sánh thẳng trên cột nhị phân bằng `UUIDStringToNum` |
| 2 | `excludeProperty(binToString(PropertyId))` | 16 view | UDF mới nhận cột nhị phân, không bọc hàm |
| 3 | Filter ngày đặt ở query ngoài thay vì trong CTE | 9 báo cáo, 3 view | Chuyển điều kiện vào CTE đọc bảng gốc |
| 4 | Bảng bên phải JOIN bị đọc toàn bộ | hk_v2_group_room, Profile, OrderDetails, PostTransactionInhouseInfo, RoomInventoryRecord | Đẩy điều kiện xuống dạng `key IN (SELECT …)` |
| 5 | Cùng một bảng bị đọc nhiều lần trong một query | v_package_log (4 lần), v_ar_netoff, v_group_pickup(_test), guest_ledger(_detail) (2 lần) | Đọc một lần, tách nhánh bằng điều kiện trong SELECT |

### 1. Bỏ binToString trên PropertyId

`binToString(x)` cho kết quả giống hệt `UUIDNumToString(x)` (đã kiểm tra 6.224.487 dòng Reservation, 0 dòng lệch; cùng 418.290 dòng cho một khách sạn). Vì vậy có thể đổi chiều so sánh sang cột gốc. Trong Jasper, thêm một tham số phụ ghép danh sách `propertyId` thành chuỗi:

```xml
<parameter name="propertyIdCsv" class="java.lang.String" isForPrompting="false">
    <defaultValueExpression><![CDATA[String.join(",", $P{propertyId})]]></defaultValueExpression>
</parameter>
```

```sql
-- trước: không dùng được index
AND $X{IN, binToString(PropertyId), propertyId}
-- sau: PropertyId là cột đầu ORDER BY → chỉ đọc dữ liệu của khách sạn được chọn
AND PropertyId IN (SELECT UUIDStringToNum(arrayJoin(splitByChar(',', $P{propertyIdCsv}))))
```

### 2. excludeProperty trên cột nhị phân

`excludeProperty` là UDF `Property NOT IN (41 PropertyId)`, loại khách sạn test/ngừng hoạt động. 24 view gọi trên cột String trơn — ổn. 16 view gọi `excludeProperty(binToString(PropertyId))`, nên đọc toàn bảng rồi mới loại. Đề xuất tạo `excludePropertyBin` với cùng 41 giá trị đã đổi sang nhị phân:

```sql
CREATE FUNCTION excludePropertyBin AS p -> (p NOT IN (
    UUIDStringToNum('a0435f53-3c45-400b-0cd4-13a4759f6294'),
    -- ... 40 giá trị còn lại, cùng danh sách với excludeProperty ...
));
-- trong view: excludeProperty(binToString(PropertyId)) = 1  →  excludePropertyBin(PropertyId) = 1
```

Lợi ích phụ thuộc tỷ lệ dòng thuộc 41 khách sạn này, chưa đo được (xem Rủi ro). Hai danh sách phải cập nhật cùng nhau.

### 3. Đưa filter ngày vào CTE

Ví dụ `arrival_list_today`: CTE `reservation` chỉ lọc trạng thái + khách sạn, còn `arrival_date = hôm nay` nằm ở query ngoài sau 7 JOIN. ClickHouse 21.8 (bản server hiện tại) không luôn đẩy điều kiện qua JOIN, nên CTE mang toàn bộ booking của khách sạn vào JOIN.

```sql
reservation as (
    select ...
    from vp_prod_ops_front_office.Reservation
    where PropertyId IN (SELECT UUIDStringToNum(arrayJoin(splitByChar(',', $P{propertyIdCsv}))))
      and ArrivalDate = toDate(now('Asia/Bangkok'))        -- chuyển từ query ngoài vào
      and lower(Status) not in ('canceled', 'noshow')
)
```

Cùng cách cho: arrival_list_7days, departure_list_today/7days, cancellation, alerts (ArrivalDate/DepartureDate); guest_inhouse_rate_check (StayingDate); journal_full, journal_payment (BusinessDate); v_gih_rate_check, v_stg__nationality_country_stat_forecast/history.

### 4. Đẩy điều kiện xuống bảng bên phải JOIN

Ví dụ `house_keeping_list_with_room_status`: đọc toàn bộ 16,3 triệu dòng `hk_v2_group_room` rồi INNER JOIN với vài group của hôm nay (trung bình 36 phòng/group).

```sql
hk_v2_group_room as (
    select groupId as group_id, roomId as room_id, status
    from vp_prod_pms_house_keeping.hk_v2_group_room
    where groupId IN (select id from hk_v2_group
                      where date = toDate(now('Asia/Bangkok')))   -- mới thêm
)
```

Áp dụng tương tự: CTE `profile` trong 11 báo cáo (`Id IN (SELECT ReferenceId FROM PmsProfile WHERE ReservationId IN (SELECT reservation_id FROM reservation))`), OrderDetails trong v_cirrus_fnb_transaction, PostTransactionInhouseInfo trong v_stg__post_transaction. View `v_trx_with_invoice` đã làm đúng mẫu này cho EInvoiceTransactionParty. Riêng `v_detailed_availability` đọc toàn bộ RoomInventoryRecord, cần thêm khoảng `date` giới hạn.

Lưu ý: tập trong `IN (SELECT …)` phải nhỏ. CTE `profile_guest` ở phần lớn báo cáo không có filter, nên không dùng thẳng nó làm tập — phải giới hạn theo các reservation của báo cáo.

### 5. Đọc mỗi bảng một lần

ClickHouse 21.8 chạy lại CTE ở mỗi lần tham chiếu. `v_package_log` dùng CTE `package_update_log` 4 lần (1 cho `log_info`, 3 nhánh UNION cho deleted/added/modified) → đọc bảng 2,3 GB bốn lần. Gộp 3 nhánh thành một lần đọc bằng `arrayJoin` trên mảng [deleted, added, modified]. Với `guest_ledger(_detail)` (2 nhánh inhouse / không inhouse) và `v_ar_netoff` (Type IN (0,1,4) và Type = 2): một lần đọc với điều kiện hợp, tách nhánh bằng `if()` / `countIf()` trong SELECT.

## Kế hoạch triển khai

Làm 4 đợt, bắt đầu bằng PoC trên một bảng nhỏ nhưng được dùng nhiều nhất; chỉ sang đợt sau khi đợt trước đo được lượng dữ liệu đọc giảm rõ rệt và kết quả không đổi.

1. **Đợt 0 — PoC:** tạo bản sao `front_office.Reservation` (2,6 GB, 36 view, 12 báo cáo) và `task` (1,7 GB) với khóa mới trong một database thử. Chạy 5 báo cáo + 5 view trên cả hai bản, so số dòng/byte đọc, thời gian và kết quả. Xác nhận bằng `EXPLAIN` rằng `PropertyId IN (SELECT UUIDStringToNum(…))` dùng được index.
2. **Đợt 1 — sửa SQL không cần đổi bảng:** lỗi 3, 4, 5 (đưa filter vào CTE, đẩy điều kiện JOIN, đọc mỗi bảng một lần). Rủi ro thấp, có ích ngay cả với khóa cũ.
3. **Đợt 2 — 9 bảng P1 + lỗi 1, 2:** đổi ORDER BY và sửa `binToString` / `excludeProperty` trong cùng một lần phát hành.
4. **Đợt 3 — 12 bảng P2, sau đó P3.**

Cách đổi khóa cho mỗi bảng (ByteHouse không đổi được ORDER BY tại chỗ, phải tạo bảng mới):

1. Tạo `<bảng>_v2` với khóa mới (DDL mẫu ở phần Re-structure).
2. Tạm dừng job nạp dữ liệu của bảng đó, ghi lại mốc thời gian.
3. `INSERT INTO <bảng>_v2 SELECT * FROM <bảng>` — bảng có partition thì chạy từng tháng; chạy ngoài giờ cao điểm, nên dùng virtual warehouse riêng.
4. Đối soát: `count()` và `sum(cityHash64(*))` theo tháng trên hai bảng phải bằng nhau.
5. `RENAME TABLE <bảng> TO <bảng>_old, <bảng>_v2 TO <bảng>` — view và báo cáo gọi theo tên nên tự dùng bảng mới.
6. Bật lại job nạp từ mốc ở bước 2; giữ `<bảng>_old` 1 tuần rồi mới DROP.

Đo trước/sau: vì tài khoản hiện tại không đọc được `system.query_log`, tạm dùng số dòng/byte đọc mà client trả về (`client.last_query.progress` trong `clickhouse-driver`) cho một bộ query chuẩn cố định; khi được cấp quyền thì chuyển sang `read_rows`, `read_bytes`, `query_duration_ms` trong query_log.

## Rủi ro và câu hỏi mở

Rủi ro lớn nhất là pipeline nạp dữ liệu và bộ nhớ của warehouse, không phải bản thân khóa mới.

- **Warehouse đang sát giới hạn bộ nhớ.** Trong lúc phân tích, 3 truy vấn thống kê (`uniq` trên PostTransaction, activity_log, EInvoiceTransactionParty) lỗi `Memory limit (total) exceeded` trên `vw-3000550035-vinhms`. `INSERT … SELECT` 88 GB có thể làm lỗi các báo cáo đang chạy → chạy từng tháng, ngoài giờ cao điểm, trên warehouse riêng.
- **Pipeline có thể tạo lại bảng.** Các bảng có `storage_dialect_type = 'MYSQL'`, nhiều khả năng được nạp tự động từ MySQL. Nếu job tự tạo lại bảng khi schema nguồn đổi, khóa mới sẽ mất.
- **Chưa có số liệu tần suất chạy thật.** Ưu tiên đang dựa trên cấu trúc view/báo cáo và dung lượng bảng; tài khoản `bytehouse` không có quyền đọc `system.query_log`.
- **Server ClickHouse 21.8.** Bản cũ: không materialize CTE, đẩy điều kiện qua JOIN hạn chế — vì vậy lỗi 3–5 phải sửa thủ công.
- **Phạm vi.** Chưa xét các view theo năm (`_2023`, `_2024`), view `master_data`, và các báo cáo Jasper ngoài thư mục contingency.

Câu hỏi cần trả lời trước Đợt 0:

- [ ] Ai quản lý pipeline nạp các bảng `vp_prod_*`, có tạm dừng/chạy lại từ mốc thời gian được không?
- [ ] Có database/warehouse thử để chạy PoC không?
- [ ] Cấp quyền `SELECT` trên `system.query_log` cho tài khoản phân tích.
- [ ] Khung giờ thấp điểm nào được phép chạy migrate?
- [ ] Tỷ lệ dòng thuộc 41 khách sạn trong `excludeProperty` là bao nhiêu (quyết định có làm lỗi 2 không)?
- [ ] Một `Id` trong 2 bảng snapshot có bao giờ đổi `BizDateSnapshotAt` không?

## Nguồn

- [ByteHouse — best practices for Unique Key tables](https://docs.byteplus.com/en/docs/bytehouse/bytehouse-best-practice-for-unique-key-tables)
- [ByConity — Unique Key](https://byconity.github.io/docs/table-design/unique-key)
- Dữ liệu phân tích: DDL và metadata từ `system.tables`, `system.columns`, `system.cnch_parts_info`; SQL của 111 view `datamart_v2` và 19 báo cáo trong `hms.data.jasper-reports/reports/CiHMS - v2/contingency`.

-- Bảng thử: cùng dữ liệu ARInvoice nhưng sắp xếp vật lý theo PropertyId
-- để query lọc 1 property chỉ đọc ~3% granule thay vì quét toàn bảng.
-- Chỉ chứa các cột query aging cần; với lưu trữ cột, các cột khác không ảnh hưởng tốc độ đọc.
CREATE TABLE test_data.ARInvoice_by_property
(
    `Id` String,
    `ARId` Nullable(String),
    `Type` Int8,                          -- không có NULL trong nguồn -> bỏ Nullable để làm khóa sort
    `Status` Int8,                        -- idem
    `PropertyId` LowCardinality(String),  -- 72 giá trị -> LowCardinality, không Nullable
    `FolioNo` Nullable(String),
    `InvoiceNo` Nullable(String),
    `Amount` Nullable(Decimal(24, 4)),
    `InvoiceDate` Nullable(DateTime64(3)),
    `PaymentNote` Nullable(String),
    `GuestName` Nullable(String),
    `CardNumber` Nullable(String),
    `TARecLoc` Nullable(String),
    `TransactionCode` Nullable(String),
    `ConfirmationNo` Nullable(String),
    `InvoiceNote` Nullable(String),
    `DateBalance` Nullable(DateTime64(3))
)
ENGINE = CnchMergeTree
ORDER BY (PropertyId, Type, Status)
UNIQUE KEY Id
SETTINGS partition_level_unique_keys = 0, index_granularity = 8192;

-- Bảng thử: đủ cột, kiểu, Nullable, DEFAULT, PARTITION BY, UNIQUE KEY như vp_prod_ops_transaction_account.Folio;
-- chỉ đổi ORDER BY thành (PropertyId, Id).
CREATE TABLE test_data.Folio_by_property
(
    `Id` String,
    `PropertyId` Nullable(String) DEFAULT NULL,
    `SeqNo` Nullable(Int32) DEFAULT NULL,
    `ReservationId` Nullable(String) DEFAULT NULL,
    `Name` Nullable(String) DEFAULT NULL,
    `CreatedAt` Nullable(DateTime64(3)) DEFAULT NULL,
    `ModifiedAt` Nullable(DateTime64(3)) DEFAULT NULL,
    `CreatedBy` Nullable(String) DEFAULT NULL,
    `State` Nullable(Int32) DEFAULT NULL,
    `ProfileId` Nullable(String) DEFAULT NULL,
    `Balance` Nullable(Decimal(17, 2)) DEFAULT NULL,
    `InvoiceNo` Nullable(String) DEFAULT NULL,
    `OrganizationId` Nullable(String) DEFAULT NULL,
    `Itn` Nullable(String) DEFAULT NULL,
    `ProfileType` Nullable(Int32) DEFAULT NULL,
    `CustomerId` Nullable(String) DEFAULT NULL,
    `FolioNo` Nullable(Int64) DEFAULT NULL,
    `ConfirmationNo` Nullable(String) DEFAULT NULL,
    `ProfileReferenceId` Nullable(String) DEFAULT NULL,
    `ProfileFirstName` Nullable(String) DEFAULT NULL,
    `ProfileLastName` Nullable(String) DEFAULT NULL,
    `ServiceAmount` Nullable(Decimal(19, 2)) DEFAULT NULL,
    `PaymentAmount` Nullable(Decimal(19, 2)) DEFAULT NULL,
    `ProgressState` Nullable(String) DEFAULT NULL
)
ENGINE = CnchMergeTree
ORDER BY (PropertyId, Id)
UNIQUE KEY tuple(Id)
SETTINGS partition_level_unique_keys = 0, allow_nullable_key = 1, storage_dialect_type = 'MYSQL', index_granularity = 8192;

INSERT INTO test_data.ARInvoice_by_property
SELECT
    Id, ARId,
    assumeNotNull(Type), assumeNotNull(Status), assumeNotNull(PropertyId),
    FolioNo, InvoiceNo, Amount, InvoiceDate, PaymentNote, GuestName, CardNumber,
    TARecLoc, TransactionCode, ConfirmationNo, InvoiceNote, DateBalance
FROM vp_prod_ops_accounts_receivable.ARInvoice;

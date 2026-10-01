-- Cùng thứ tự cột với bảng nguồn nên dùng SELECT *
INSERT INTO test_data.ARInvoice_by_property_full
SELECT * FROM vp_prod_ops_accounts_receivable.ARInvoice;

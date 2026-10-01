-- Số dòng phải bằng nhau (có thể lệch vài dòng nếu CDC vừa ghi thêm vào bảng nguồn)
SELECT 'source' AS t, count() FROM vp_prod_ops_accounts_receivable.ARInvoice
UNION ALL
SELECT 'by_property_full', count() FROM test_data.ARInvoice_by_property_full;

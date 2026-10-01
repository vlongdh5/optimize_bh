-- Từng cặp phải xấp xỉ bằng nhau (có thể lệch ít dòng do CDC ghi thêm vào bảng nguồn)
SELECT 'PostTransaction' AS t, (SELECT count() FROM vp_prod_ops_transaction_account.PostTransaction) AS source, (SELECT count() FROM test_data.PostTransaction_by_property) AS by_property
UNION ALL
SELECT 'Reservation', (SELECT count() FROM vp_prod_ops_transaction_account.Reservation), (SELECT count() FROM test_data.Reservation_by_property)
UNION ALL
SELECT 'Folio', (SELECT count() FROM vp_prod_ops_transaction_account.Folio), (SELECT count() FROM test_data.Folio_by_property);

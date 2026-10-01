-- PostTransaction ~214 triệu dòng / 88 GiB: chạy lần lượt từng lệnh (theo năm của CreatedAt).
-- Lệnh nào lỗi/timeout thì chỉ chạy lại lệnh đó (UNIQUE KEY sẽ upsert, không nhân dòng).
INSERT INTO test_data.PostTransaction_by_property SELECT * FROM vp_prod_ops_transaction_account.PostTransaction WHERE toYear(CreatedAt) = 2020;
INSERT INTO test_data.PostTransaction_by_property SELECT * FROM vp_prod_ops_transaction_account.PostTransaction WHERE toYear(CreatedAt) = 2021;
INSERT INTO test_data.PostTransaction_by_property SELECT * FROM vp_prod_ops_transaction_account.PostTransaction WHERE toYear(CreatedAt) = 2022;
INSERT INTO test_data.PostTransaction_by_property SELECT * FROM vp_prod_ops_transaction_account.PostTransaction WHERE toYear(CreatedAt) = 2023;
INSERT INTO test_data.PostTransaction_by_property SELECT * FROM vp_prod_ops_transaction_account.PostTransaction WHERE toYear(CreatedAt) = 2024;
INSERT INTO test_data.PostTransaction_by_property SELECT * FROM vp_prod_ops_transaction_account.PostTransaction WHERE toYear(CreatedAt) = 2025;
INSERT INTO test_data.PostTransaction_by_property SELECT * FROM vp_prod_ops_transaction_account.PostTransaction WHERE toYear(CreatedAt) = 2026;
INSERT INTO test_data.PostTransaction_by_property SELECT * FROM vp_prod_ops_transaction_account.PostTransaction WHERE CreatedAt IS NULL OR toYear(CreatedAt) NOT BETWEEN 2020 AND 2026;



tạo bảng mới
stop cdc
migrate dữ liệu sang bảng mới : 10h bắt đầu
swap 2 bảng cũ mới
restart cdc (lùi thời gian lại để cover dc phần dữ liệu bị hụt trong lúc migrate) restart lại tại thời điểm 9h:


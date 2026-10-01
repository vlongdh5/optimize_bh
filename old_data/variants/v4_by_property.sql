-- v4: giống v1 nhưng đọc từ bảng sắp theo PropertyId (structural/01_create_table.sql)
with toDate(now('Asia/Bangkok')) as biz_date
select
    i.Id as id,
    biz_date,
    ar.AccountName as account_name,
    ar.AccountNumber as account_number,
    ar.ARType as ar_type,
    i.FolioNo as folio_no,
    i.InvoiceNo as invoice_no,
    i.Amount as amount,
    i.InvoiceDate as invoice_date,
    i.PaymentNote as payment_note,
    i.Status as status,
    i.GuestName as guest_name,
    i.CardNumber as card_number,
    i.TARecLoc as ta_rec_loc,
    i.TransactionCode as transaction_code,
    i.ConfirmationNo as confirmation_no,
    i.InvoiceNote as invoice_note,
    cl.CreditLimit as credit_limit,
    dateDiff('day', biz_date, toDate(i.InvoiceDate)) + 1 as age,
    i.PropertyId as property_id,
    if(age <= 30, i.Amount, 0) as age_1_30,
    if(age > 30 and age <= 60, i.Amount, 0) as age_31_60,
    if(age > 60 and age <= 90, i.Amount, 0) as age_61_90,
    if(age > 90 and age <= 180, i.Amount, 0) as age_91_180,
    if(age > 180, i.Amount, 0) as age_180
from test_data.ARInvoice_by_property i
left join vp_prod_ops_accounts_receivable.AccountsReceivable ar on i.ARId = ar.Id
left join (
    select ARId, PropertyId, CreditLimit
    from vp_prod_ops_accounts_receivable.ARCreditLimit
    where PropertyId = '9f474bc1-62f4-666b-1c63-7e7330412cfd'
) cl on i.ARId = cl.ARId and i.PropertyId = cl.PropertyId
where i.PropertyId = '9f474bc1-62f4-666b-1c63-7e7330412cfd'
  and i.Type in (0, 1, 4)
  and toDate(i.InvoiceDate) <= biz_date
  and (i.Status = 0 or (i.Status = 1 and toDate(i.DateBalance) > biz_date))
order by account_name

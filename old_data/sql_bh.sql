select * from (with ar_invoice as (
    select 
        Id as id,
        ARId as ar_id,
        Type as type,
        FolioNo as folio_no,
        InvoiceNo as invoice_no,
        Amount as amount,
        InvoiceDate as invoice_date,
        PaymentNote as payment_note,
        Status as status,
        GuestName as guest_name,
        CardNumber as card_number,
        TARecLoc as ta_rec_loc,
        TransactionCode as transaction_code,
        ConfirmationNo as confirmation_no,
        InvoiceNote as invoice_note,
        PropertyId as property_id,
        DateBalance as date_balance
    from vp_prod_ops_accounts_receivable.ARInvoice
    where Type in (0, 1, 4)
    and PropertyId = '9f474bc1-62f4-666b-1c63-7e7330412cfd'
),
accounts_receivable as (
    select 
        Id as id,
        AccountName as account_name,
        AccountNumber as account_number,
        ARType as ar_type
    from vp_prod_ops_accounts_receivable.AccountsReceivable
),
ar_credit_limit as (
    select 
        ARId as ar_id,
        PropertyId as property_id,
        CreditLimit as credit_limit
    from vp_prod_ops_accounts_receivable.ARCreditLimit
),
final as (
    select
        ar_invoice.id as id,
        toDate(now('Asia/Bangkok')) as biz_date,
        accounts_receivable.account_name as account_name,
        accounts_receivable.account_number as account_number,
        accounts_receivable.ar_type as ar_type,
        ar_invoice.folio_no as folio_no,
        ar_invoice.invoice_no as invoice_no,
        ar_invoice.amount as amount,
        ar_invoice.invoice_date as invoice_date,
        ar_invoice.payment_note as payment_note,
        ar_invoice.status as status,
        ar_invoice.guest_name as guest_name,
        ar_invoice.card_number as card_number,
        ar_invoice.ta_rec_loc as ta_rec_loc,
        ar_invoice.transaction_code as transaction_code,
        ar_invoice.confirmation_no as confirmation_no,
        ar_invoice.invoice_note as invoice_note,
        ar_credit_limit.credit_limit as credit_limit,
        dateDiff('day', toDate(now('Asia/Bangkok')), toDate(ar_invoice.invoice_date)) + 1 as age,
        ar_invoice.property_id as property_id
    from ar_invoice
    left join accounts_receivable on ar_invoice.ar_id = accounts_receivable.id
    left join ar_credit_limit on ar_invoice.ar_id = ar_credit_limit.ar_id
        and ar_invoice.property_id = ar_credit_limit.property_id
    where ((ar_invoice.status = 0 and date(ar_invoice.invoice_date) <= toDate(now('Asia/Bangkok')))
        or (ar_invoice.status = 1 and date(ar_invoice.invoice_date) <= toDate(now('Asia/Bangkok')) and date(ar_invoice.date_balance) > toDate(now('Asia/Bangkok'))))
)
select
    final.id,
    final.biz_date,
    final.account_name,
    final.account_number,
    final.ar_type,
    final.folio_no,
    final.invoice_no,
    final.amount,
    final.invoice_date,
    final.payment_note,
    final.status,
    final.guest_name,
    final.card_number,
    final.ta_rec_loc,
    final.transaction_code,
    final.confirmation_no,
    final.invoice_note,
    final.credit_limit,
    final.age,
    final.property_id,
    case when final.age <= 30 then final.amount else 0 end as age_1_30,
    case when final.age <= 60 and final.age > 30 then final.amount else 0 end as age_31_60,
    case when final.age <= 90 and final.age > 60 then final.amount else 0 end as age_61_90,
    case when final.age <= 180 and final.age > 90 then final.amount else 0 end as age_91_180,
    case when final.age > 180 then final.amount else 0 end as age_180
from final
where true
order by account_name)
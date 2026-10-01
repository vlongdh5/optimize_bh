select * from (with post_transaction as (
    select 
        Id as id,
        BusinessDate as business_date,
        CreatedAt as created_at,
        RoomNumber as room_number,
        ReferenceText as reference_text,
        TransactionAccountCode as transaction_account_code,
        PostingText as posting_text,
        CheckNo as check_no,
        Currency as currency,
        ReceiptNo as receipt_no,
        CategoryType as category_type,
        Amount as amount,
        CashierCode as cashier_code,
        CashierName as cashier_name,
        OriginalConfirmationNumber as original_confirmation_number,
        ConfirmationNumber as confirmation_number,
        CardNumber as card_number,
        PropertyId as property_id,
        OrganizationId as organization_id,
        PostTransactionNo as post_transaction_no,
        IncludeExclude as include_exclude,
        State as state,
        TransactionReferenceType as transaction_reference_type
    from vp_prod_ops_transaction_account.PostTransaction
    where true
    and PropertyId IN ('$propertyId')
    and CashierCode IN ('$cashierCodes')
    and TransactionAccountCode IN ('$transactionCodes') 
    and RoomNumber IN ('$roomNumbers')
)

select
    post_transaction.id as id,
    post_transaction.business_date as business_date,
    post_transaction.created_at as created_at,
    post_transaction.room_number as room_number,
    post_transaction.reference_text as reference_text,
    post_transaction.transaction_account_code as transaction_account_code,
    post_transaction.posting_text as posting_text,
    post_transaction.check_no as check_no,
    post_transaction.currency as currency,
    post_transaction.receipt_no as receipt_no,
    case
        when post_transaction.category_type = 'SERVICE'
            then post_transaction.amount
        else 0 end
    as debit,
    case
        when post_transaction.category_type = 'PAYMENT'
            then - post_transaction.amount
        else 0 end
    as credit,
    post_transaction.cashier_code as cashier_code,
    post_transaction.cashier_name as cashier_name,
    post_transaction.original_confirmation_number as original_confirmation_number,
    post_transaction.confirmation_number as confirmation_number,
    post_transaction.card_number as card_number,
    post_transaction.property_id as property_id,
    post_transaction.organization_id as organization_id,
    post_transaction.post_transaction_no as post_transaction_no,
    formatDateTime(post_transaction.created_at, '%H:%M', 'Asia/Bangkok') as created_time

from post_transaction

where bitAnd(post_transaction.include_exclude,1) = 1
    and ((post_transaction.state = 1 and post_transaction.transaction_account_code != '9980')
        or (post_transaction.state = 5 and post_transaction.transaction_reference_type = 'ORIGINAL_DP'))
    and post_transaction.business_date = toDate(now('Asia/Bangkok'))
    and debit != 0
order by
	(case when '$groupByType' = 'TRANSACTION_CODE' then transaction_account_code end),
	(case when '$groupByType' = 'ROOM' then room_number end),
	(case when '$groupByType' = 'CASHIER' then cashier_name end),
	(case when '$sortByType' = 'POST_NUMBER' then post_transaction_no end),
	(case when '$sortByType' = 'CHRONOLOGICAL' then created_at end ),
	(case when '$sortByType' = 'CASHIER' then cashier_code end),
	(case when '$sortByType' = 'ROOM_NUMBER' then room_number end),
	(case when '$sortByType' = 'TRANSACTION_CODE' then transaction_account_code end))

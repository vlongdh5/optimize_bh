select * from (with reservation as (
    select 
        Id as id,
        Status as status,
        CurrentLedger as current_ledger,
        RoomNumber as room_number,
        PropertyId as property_id
    from vp_prod_ops_transaction_account.Reservation
    where lower(Status) != 'inhouse' and CurrentLedger = 'GL'
    and $X{IN, Status, reservationStatuses}
    and $X{IN, PropertyId, propertyId}
    union all
    select 
        Id as id,
        Status as status,
        CurrentLedger as current_ledger,
        RoomNumber as room_number,
        PropertyId as property_id
    from vp_prod_ops_transaction_account.Reservation
    where lower(Status) = 'inhouse'
    and $X{IN, Status, reservationStatuses}
    and $X{IN, PropertyId, propertyId}
),

folio as (
    select 
        Id as id,
        getFullName(ProfileLastName, ProfileFirstName) as profile_full_name
    from vp_prod_ops_transaction_account.Folio
    where true
    and $X{IN, PropertyId, propertyId}
),

post_transaction as (
    select 
        Id as id,
        FolioId as folio_id,
        ReservationId as reservation_id,
        ConfirmationNumber as confirmation_number,
        Amount as amount,
        State as state,
        IncludeExclude as include_exclude,
        TransactionAccountCode as transaction_account_code,
        PostingText as posting_text
    from vp_prod_ops_transaction_account.PostTransaction
    where true
    and $X{IN, PropertyId, propertyId}
),

post_transaction_folio as (
    select
        post_transaction.id,
        post_transaction.folio_id,
        post_transaction.reservation_id,
        post_transaction.confirmation_number,
        post_transaction.amount,
        post_transaction.state,
        post_transaction.include_exclude,
        folio.profile_full_name as name,
        post_transaction.transaction_account_code as transaction_account_code,
        post_transaction.posting_text as posting_text
    from post_transaction
    left join folio on folio.id = post_transaction.folio_id
)

select
    post_transaction_folio.folio_id as id,
    reservation.status as status,
    post_transaction_folio.name as name,
    post_transaction_folio.confirmation_number as confirmation_number,
    reservation.room_number as room_number,
    post_transaction_folio.transaction_account_code as transaction_code,
    post_transaction_folio.posting_text as description,
    sum(post_transaction_folio.amount) as amount,
    reservation.property_id as property_id

from reservation
left join post_transaction_folio on post_transaction_folio.reservation_id = reservation.id

where post_transaction_folio.state = 1
    and bitAnd(post_transaction_folio.include_exclude, 1) = 1
    and post_transaction_folio.amount != 0
group by 1, 2, 3, 4, 5, 6, 7, 9
order by reservation.status, reservation.room_number, post_transaction_folio.confirmation_number)
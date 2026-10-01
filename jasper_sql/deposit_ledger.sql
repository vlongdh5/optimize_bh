select * from (
with post_transaction as (
    select 
        ReservationId as reservation_id,
        ConfirmationNumber as confirmation_number,
        BusinessDate as business_date,
        Amount as amount,
        PropertyId as property_id,
        IsDeposit as is_deposit,
        State as state
    from vp_prod_ops_transaction_account.PostTransaction
    where IsDeposit = 1 and State = 1
    and PropertyId IN ('$propertyId')
),

reservation as (
    select 
        ReservationId as reservation_id,
        ArrivalDate as arrival_date,
        DepartureDate as departure_date,
        AssignedRoomNumber as assigned_room_number,
        Status as status,
        mainGuestProfileId as main_guest_profile_id
    from vp_prod_ops_front_office.Reservation
    where true
    and binToString(PropertyId) IN ('$propertyId')
),

profile_guest as (
    select 
        Id as id,
        ReferenceId as reference_id,
        getFullName(LastName, FirstName) as full_name,
        ProfileType as profile_type
    from vp_prod_ops_front_office.PmsProfile
    where true
    and PropertyId IN ('$propertyId')
),

profile as (
    select 
        Id as id,
        FullName as full_name
    from vp_prod_ops_pms_profile.Profile
    where true
    and PropertyId IN ('$propertyId')
)

select
    case
        when profile_guest.reference_id is not null and profile.id is not null
            then profile.full_name
        else profile_guest.full_name end
    as name,
    post_transaction.confirmation_number as confirmation_number,
    reservation.arrival_date as arrival_date,
    reservation.departure_date as departure_date,
    reservation.assigned_room_number as assigned_room_number,
    reservation.status as status,
    max(post_transaction.business_date) as business_date,
    sum(post_transaction.amount) as amount,
    post_transaction.property_id as property_id

from post_transaction
left join reservation on post_transaction.reservation_id = binToString(reservation.reservation_id)
left join profile_guest on profile_guest.id = reservation.main_guest_profile_id
left join profile on profile_guest.reference_id = profile.id

where lower(profile_type) = 'mainguest'

group by 1, 2, 3, 4, 5, 6, 9
order by assigned_room_number
)

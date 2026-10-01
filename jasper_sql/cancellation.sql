select * from (with reservation as (
    select 
        Id as id,
        ReservationId as reservation_id,
        ConfirmationNumber as confirmation_number,
        ItineraryNumber as itinerary_number,
        Status as status,
        mainGuestProfileId as main_guest_profile_id,
        TravelAgentProfileId as travel_agent_profile_id,
        CompanyProfileId as company_profile_id,
        RoomTypeCode as room_type_code,
        ArrivalDate as arrival_date,
        DepartureDate as departure_date,
        RateCode as rate_code,
        Total as total,
        PropertyId as property_id
    from vp_prod_ops_front_office.Reservation
    where lower(Status) = 'canceled'
    and binToString(PropertyId) IN ('$propertyId')
),

cancellation as (
    select 
        ReservationId as reservation_id,
        CancellationConfigId as cancellation_config_id,
        CancelledAt as cancelled_at,
        Reference as reference,
        CancelledBy as cancelled_by
    from vp_prod_ops_front_office.Cancellation
),

cancellation_config as (
    select 
        Id as id,
        Code as code,
        Description as description
    from vp_prod_ops_front_office.CancellationConfig
),

profile_guest as (
    select 
        Id as id,
        ReferenceId as reference_id,
        getFullName(LastName, FirstName) as full_name,
        ProfileType as profile_type
    from vp_prod_ops_front_office.PmsProfile
),

profile as (
    select 
        Id as id,
        FullName as full_name
    from vp_prod_ops_pms_profile.Profile
),

profile_agent as (
    select 
        id,
        full_name,
        reservation_id
    from datamart_v2.stg__profile_alias
),

profile_company as (
    select 
        id,
        full_name,
        reservation_id
    from profile_agent
),

reservation_room_rate as (
    select 
        ReservationId as reservation_id,
        StayingDate as staying_date,
        EffectiveRateAmount as effective_rate_amount,
        IsDeleted as is_deleted
    from vp_prod_ops_front_office.ReservationRoomRate
    where is_deleted = 0
)

select
    binToString(reservation.id) as id,
    reservation.confirmation_number as confirmation_number,
    reservation.itinerary_number as itinerary_number,
    case
        when profile_guest.reference_id is not null and profile.id is not null
            then profile.full_name
        else profile_guest.full_name end
    as name,
    profile_company.full_name as company,
    profile_agent.full_name as agent,
    reservation.room_type_code as room_type_code,
    reservation.arrival_date as arrival_date,
    dateDiff('day', reservation.arrival_date, reservation.departure_date) as nights,
    cancellation_config.code as cancelled_reason,
    cancellation_config.description as cancelled_description,
    cancellation.cancelled_at as cancelled_at,
    cancellation.reference as descriptions,
    cancellation.cancelled_by as cancelled_by,
    reservation.rate_code as rate_code,
    reservation_room_rate.effective_rate_amount as rate_amount,
    toInt64(0) as deposit_paid,
    reservation.total as total_rate,
    reservation.total as revenue_loss,
    '' as reserved_by,
    binToString(reservation.property_id) as property_id
    , formatDateTime(toDateTime(cancellation.cancelled_at, 'Asia/Bangkok'), '%Y-%m-%d') as cancelled_date
    , formatDateTime(toDateTime(cancellation.cancelled_at, 'Asia/Bangkok'), '%H:%M:%S') as cancelled_time

from reservation
left join cancellation on reservation.reservation_id = cancellation.reservation_id
left join cancellation_config on cancellation.cancellation_config_id = cancellation_config.id
left join profile_guest on profile_guest.id = reservation.main_guest_profile_id
left join profile on profile_guest.reference_id = profile.id
left join profile_agent on profile_agent.id = binToString(reservation.travel_agent_profile_id)
    and binToString(reservation.reservation_id) = profile_agent.reservation_id
left join profile_company on profile_company.id = binToString(reservation.company_profile_id)
    and binToString(reservation.reservation_id) = profile_company.reservation_id
left join reservation_room_rate on reservation.reservation_id = reservation_room_rate.reservation_id and reservation.arrival_date = reservation_room_rate.staying_date

where lower(profile_guest.profile_type) = 'mainguest'
    and reservation.arrival_date = toDate(now('Asia/Bangkok')))

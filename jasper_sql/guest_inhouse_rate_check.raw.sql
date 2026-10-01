select * from (with reservation as (
    select 
        ReservationId as reservation_id,
        AssignedRoomNumber as assigned_room_number,
        ItineraryNumber as itinerary_number,
        numberOfAdult as number_of_adult,
        numberOfChild as number_of_child,
        numberOfInfant as number_of_infant,
        BlockBookingCode as block_booking_code,
        RateCode as rate_code,
        ArrivalDate as arrival_date,
        DepartureDate as departure_date,
        MarketCode as market_code,
        SourceCode as source_code,
        Comment as comment,
        internalComment as internal_comment,
        PropertyId as property_id,
        RoomTypeId as room_type_id,
        Status as status
    from vp_prod_ops_front_office.Reservation
    where lower(Status) in ('inhouse', 'checkout')
    and $X{IN, binToString(PropertyId), propertyId}
),

room_type as (
    select 
        id,
        isDeleted as is_deleted,
        isPseudo as is_pseudo
    from vp_prod_pms_property.pro_room_type
),

reservation_room_rate as (
    select 
        Id as id,
        ReservationId as reservation_id,
        RoomTypeAmount as room_type_amount,
        EffectiveRateOriginalAmount as effective_rate_original_amount,
        EffectiveRateAmount as effective_rate_amount,
        RoomTypeCode as room_type_code,
        RoomTypeToCharge as room_type_to_charge,
        StayingDate as staying_date,
        IsDeleted as is_deleted
    from vp_prod_ops_front_office.ReservationRoomRate
    where IsDeleted = 0
    and $X{IN, binToString(PropertyId), propertyId}
),

fixed_charge as (
    select
        ReservationId as reservation_id,
        sum(Price * Quantity) as fixed_charges
    from vp_prod_ops_transaction_account.FixedCharge
    group by 1
),

profile_guest as (
    select 
        Id as id,
        ReservationId as reservation_id,
        ReferenceId as reference_id,
        getFullName(LastName,FirstName) as full_name,
        ProfileType as profile_type
    from vp_prod_ops_front_office.PmsProfile
),

profile as (
    select 
        Id as id,
        getFullName(LastName,FirstName) as full_name
    from vp_prod_ops_pms_profile.Profile
),

staying as (
    select 
        ReservationId as reservation_id,
        ProfileId as profile_id,
        Status as status
    from vp_prod_ops_front_office.Staying
)

select
    binToString(reservation_room_rate.id) as id,
    reservation.assigned_room_number as assigned_room_number,
    reservation.itinerary_number as itinerary_number,
    case
        when profile_guest.reference_id is not null and profile.id is not null
            then profile.full_name
        else profile_guest.full_name end
    as name,
    case
        when lower(profile_guest.profile_type) = 'mainguest'
            then (((case when lower(profile_guest.profile_type) = 'mainguest' then coalesce(reservation.number_of_adult, 0) else 0 end)
                    + (case when lower(profile_guest.profile_type) = 'mainguest' then coalesce(reservation.number_of_child, 0) else 0 end))
                + (case when lower(profile_guest.profile_type) = 'mainguest' then coalesce(reservation.number_of_infant, 0) else 0 end))
        else 0 end
    as person,
    case
        when lower(profile_guest.profile_type) = 'mainguest'
            then coalesce(reservation.number_of_adult, 0)
        else 0 end
    as number_of_adult,
    case
        when lower(profile_guest.profile_type) = 'mainguest'
            then coalesce(reservation.number_of_child, 0)
        else 0 end
    as number_of_child,
    reservation.block_booking_code as block_booking_code,
    reservation.rate_code as rate_code,
    case
        when lower(profile_guest.profile_type) = 'mainguest'
            then reservation_room_rate.room_type_amount
        else 0 end
    as room_type_amount,
    case
        when lower(profile_guest.profile_type) = 'mainguest'
            then reservation_room_rate.effective_rate_original_amount
        else 0 end
    as effective_rate_original_amount,
    case
        when lower(profile_guest.profile_type) = 'mainguest'
            then reservation_room_rate.effective_rate_amount
        else 0 end
    as effective_rate_amount,
    case
        when lower(profile_guest.profile_type) = 'mainguest'
            then (reservation_room_rate.effective_rate_original_amount - reservation_room_rate.effective_rate_amount)
        else 0 end
    as rate_amount_variance,
    reservation.arrival_date as arrival_date,
    reservation.departure_date as departure_date,
    reservation_room_rate.room_type_code as room_type_code,
    reservation_room_rate.room_type_to_charge as room_type_to_charge,
    staying.status as status,
    fixed_charge.fixed_charges as fixed_charges,
    reservation.market_code as market_code,
    reservation.source_code as source_code,
    reservation.comment as comment,
    reservation.internal_comment as internal_comment,
    binToString(reservation.property_id) as property_id

from reservation
left join room_type
    on binToString(reservation.room_type_id) = room_type.id
left join reservation_room_rate
    on reservation_room_rate.reservation_id = reservation.reservation_id
left join fixed_charge
    on binToString(reservation.reservation_id) = fixed_charge.reservation_id
left join staying
    on staying.reservation_id = reservation.reservation_id
left join profile_guest
    on profile_guest.reservation_id = staying.reservation_id
        and profile_guest.id = staying.profile_id
left join profile
    on profile_guest.reference_id = profile.id

where lower(profile_guest.profile_type) = 'mainguest'
    and room_type.is_deleted = 0 and room_type.is_pseudo = 0
    and reservation_room_rate.staying_date = toDate(now('Asia/Bangkok'))
order by reservation.assigned_room_number)
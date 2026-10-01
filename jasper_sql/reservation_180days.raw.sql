select * from (with reservation as (
    select 
        Id as id,
        ReservationId as reservation_id,
        ConfirmationNumber as confirmation_number,
        ItineraryNumber as itinerary_number,
        ArrivalDate as arrival_date,
        DepartureDate as departure_date,
        AssignedRoomNumber as assigned_room_number,
        numberOfAdult as number_of_adult,
        numberOfChild as number_of_child,
        Status as status,
        PropertyId as property_id,
        mainGuestProfileId as main_guest_profile_id,
        TravelAgentProfileId as travel_agent_profile_id,
        CompanyProfileId as company_profile_id,
        BookerProfileId as booker_profile_id
    from vp_prod_ops_front_office.Reservation
    where $X{IN, binToString(PropertyId), propertyId}
),

reservation_room_rate as (
    select 
        ReservationId as reservation_id,
        StayingDate as staying_date,
        RoomTypeCode as room_type_code,
        EffectiveRatePlanCode as effective_rate_plan_code,
        EffectiveRateAmount as effective_rate_amount
    from vp_prod_ops_front_office.ReservationRoomRate
    where IsDeleted = 0
),

profile_guest as (
    select 
        Id as id,
        ReferenceId as reference_id,
        getFullName(LastName, FirstName) as full_name,
        Nationality as nationality,
        VipCode as vip_code
    from vp_prod_ops_front_office.PmsProfile
),

profile_booker as (
    select 
        id
    from profile_guest
),

check_in as (
    select 
        ReservationId as reservation_id,
        ActualCheckInDate as actual_check_in_date,
        ActualCheckoutDate as actual_checkout_date
    from vp_prod_ops_front_office.CheckIn
),

profile as (
    select 
        Id as id,
        FullName as full_name,
        NationalityCode as nationality_code
    from vp_prod_ops_pms_profile.Profile
),

profile_agent as (
    select 
        id,
        reservation_id,
        full_name
    from datamart_v2.v_stg__profile_alias
),

profile_company as (
    select 
        id,
        reservation_id,
        full_name
    from profile_agent
),

final as (
    select
        binToString(reservation.id) as id,
        reservation.confirmation_number as confirmation_number,
        reservation.itinerary_number as itinerary_number,
        reservation_room_rate.staying_date as staying_date,
        case
            when profile_guest.reference_id is not null and profile.id is not null
                then profile.full_name
            else profile_guest.full_name end
        as name,
        case
            when profile_guest.reference_id is not null and profile.nationality_code is not null
                then profile.nationality_code
            else profile_guest.nationality end
        as nationality,
        profile_guest.vip_code as vip_code,
        profile_agent.full_name as travel_agent,
        profile_company.full_name as company,
        case
            when reservation.status in ('Inhouse', 'Checkout')
                then date(check_in.actual_check_in_date)
            else date(reservation.arrival_date) end
        as check_in,
        case
            when reservation.status = 'Checkout' then date(check_in.actual_checkout_date)
            else date(reservation.departure_date) end
        as check_out,
        reservation.assigned_room_number as assigned_room_number,
        reservation_room_rate.room_type_code as room_type_code,
        reservation.number_of_adult as number_of_adult,
        reservation.number_of_child as number_of_child,
        reservation_room_rate.effective_rate_plan_code as rate_code,
        reservation_room_rate.effective_rate_amount as rate_amount,
        reservation.status as status,
        binToString(reservation.property_id) as property_id

    from reservation
    left join reservation_room_rate
        on reservation_room_rate.reservation_id = reservation.reservation_id
    left join profile_guest
        on profile_guest.id = reservation.main_guest_profile_id
    left join profile on profile_guest.reference_id = profile.id
    left join profile_agent on profile_agent.id = binToString(reservation.travel_agent_profile_id)
        and binToString(reservation.reservation_id) = profile_agent.reservation_id
    left join profile_company on profile_company.id = binToString(reservation.company_profile_id)
        and binToString(reservation.reservation_id) = profile_company.reservation_id
    left join profile_booker
        on profile_booker.id = reservation.booker_profile_id
    left join check_in on check_in.reservation_id = reservation.reservation_id
)

select distinct on (id)
    id,
    confirmation_number,
    itinerary_number,
    staying_date,
    name,
    nationality,
    vip_code,
    travel_agent,
    company,
    check_in,
    check_out,
    assigned_room_number,
    room_type_code,
    number_of_adult,
    number_of_child,
    rate_code,
    rate_amount,
    status,
    property_id
from final
where staying_date >= toDate(now('Asia/Bangkok'))
    and staying_date <= dateAdd(toDate(now('Asia/Bangkok')), interval 180 day)
order by assigned_room_number)
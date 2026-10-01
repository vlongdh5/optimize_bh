select *, formatDateTime(actual_check_out_date, '%H:%M', 'Asia/Bangkok') as check_out 
from (with reservation as (
    select 
        Id as id,
        ReservationId as reservation_id,
        ItineraryNumber as itinerary_number,
        ConfirmationNumber as confirmation_number,
        AssignedRoomNumber as assigned_room_number,
        RoomTypeCode as room_type_code,
        RoomTypeId as room_type_id,
        ArrivalDate as arrival_date,
        DepartureDate as departure_date,
        numberOfAdult as number_of_adult,
        numberOfChild as number_of_child,
        numberOfInfant as number_of_infant,
        Status as status,
        RateCode as rate_code,
        BlockBookingCode as block_booking_code,
        Comment as comment,
        internalComment as internal_comment,
        PropertyId as property_id,
        TravelAgentProfileId as travel_agent_profile_id,
        CompanyProfileId as company_profile_id
    from vp_prod_ops_front_office.Reservation
    where lower(Status) not in ('canceled', 'noshow')
    and binToString(PropertyId) IN ('$propertyId')
),

room_type as (
    select 
        id,
        isPseudo as is_pseudo
    from vp_prod_pms_property.pro_room_type
),

check_in as (
    select 
        ReservationId as reservation_id,
        ActualCheckoutDate as actual_checkout_date
    from vp_prod_ops_front_office.CheckIn
),

profile_guest as (
    select 
        ReservationId as reservation_id,
        ReferenceId as reference_id,
        getFullName(LastName,FirstName) as full_name,
        VipCode as vip_code,
        Nationality as nationality,
        ProfileType as profile_type
    from vp_prod_ops_front_office.PmsProfile
    where (case when '$isMainGuestOnly' then ProfileType = 'MainGuest'
        else true end)
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
)

select
    binToString(reservation.id) as id,
    reservation.itinerary_number as itinerary_number,
    reservation.confirmation_number as confirmation_number,
    reservation.assigned_room_number as assigned_room_number,
    reservation.room_type_code as room_type_code,
    arrayStringConcat(
        groupArray(
            multiIf(
                isNotNull(profile_guest.reference_id) AND isNotNull(profile.id),
                profile.full_name,
                profile_guest.full_name
            )
        ),
        '\n'
    ) as name,
    profile_company.full_name as company,
    profile_agent.full_name as agent,
    arrayStringConcat(groupArray(profile_guest.vip_code), '\n') as vip_code,
    arrayStringConcat(
        groupArray(
            multiIf(
                isNotNull(profile_guest.reference_id) AND isNotNull(profile.nationality_code),
                profile.nationality_code,
                profile_guest.nationality
            )
        ),
        '\n'
    ) as nationality,
    reservation.arrival_date as arrival_date,
    reservation.departure_date as departure_date,
    check_in.actual_checkout_date as actual_check_out_date,
    reservation.number_of_adult as number_of_adult,
    reservation.number_of_child as number_of_child,
    reservation.number_of_infant as number_of_infant,
    reservation.status as status,
    reservation.rate_code as rate_code,
    reservation.block_booking_code as block_booking_code,
    '' as payment,
    arrayStringConcat(groupArray(profile_guest.profile_type), '\n') as profile_type,
    reservation.comment as comment,
    reservation.internal_comment as internal_comment,
    binToString(reservation.property_id) as property_id
from reservation
left join room_type on binToString(reservation.room_type_id) = room_type.id
left join check_in on reservation.reservation_id = check_in.reservation_id
left join profile_guest on reservation.reservation_id = profile_guest.reservation_id
left join profile on profile_guest.reference_id = profile.id
left join profile_agent
    on
        binToString(reservation.travel_agent_profile_id) = profile_agent.id
        and binToString(reservation.reservation_id) = profile_agent.reservation_id
left join profile_company
    on
        binToString(reservation.company_profile_id) = profile_company.id
        and binToString(reservation.reservation_id) = profile_company.reservation_id

where
    lower(profile_guest.profile_type) in ('mainguest', 'accompanyguest')
    and (room_type.is_pseudo = 0 or room_type.is_pseudo is null)
    and reservation.departure_date >= dateAdd(toDate(now('Asia/Bangkok')), interval 1 day)
    and reservation.departure_date <= dateAdd(toDate(now('Asia/Bangkok')), interval 7 day)
group by 1, 2, 3, 4, 5, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 22, 23, 24
) 
order by
	(case when '$groupBy' = 'itineraryNumber' then itinerary_number end),
	(case when '$groupBy' = 'departureDate' then departure_date end),
	(case when '$groupBy' = 'blockCode' then block_booking_code end)

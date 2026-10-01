select * from(with reservation as (
    select 
        ReservationId as reservation_id,
        ItineraryNumber as itinerary_number,
        ConfirmationNumber as confirmation_number,
        TaRecLoc as ta_rec_loc,
        ArrivalDate as arrival_date,
        DepartureDate as departure_date,
        AssignedRoomNumber as assigned_room_number,
        Status as status,
        numberOfAdult as number_of_adult,
        numberOfChild as number_of_child,
        numberOfInfant as number_of_infant,
        RateCode as rate_code,
        Total as total,
        Balance as balance,
        MarketCode as market_code,
        SourceCode as source_code,
        Comment as comment,
        internalComment as internal_comment,
        PropertyId as property_id,
        RoomTypeId as room_type_id,
        TravelAgentProfileId as travel_agent_profile_id,
        CompanyProfileId as company_profile_id,
        AssignedRoomId as assigned_room_id,
        BlockBookingCode as block_booking_code,
        Eta as eta,
        Etd as etd,
        RoomTypeCode as room_type_code
    from vp_prod_ops_front_office.Reservation
    where lower(Status) not in ('canceled', 'noshow')
    and binToString(PropertyId) IN ('$propertyId')
),

room_type as (
    select 
        id,
        isDeleted as is_deleted,
        isPseudo as is_pseudo
    from vp_prod_pms_property.pro_room_type
),

profile_guest as (
    select 
        Id as id,
        ReservationId as reservation_id,
        ReferenceId as reference_id,
        getFullName(LastName, FirstName) as full_name,
        Nationality as nationality,
        VipCode as vip_code,
        ProfileType as profile_type
    from vp_prod_ops_front_office.PmsProfile
),

profile as (
    select 
        Id as id,
        FullName as full_name,
        NationalityCode as nationality_code
    from vp_prod_ops_pms_profile.Profile
),

special_request as (
    select
        ReservationId as reservation_id,
        arrayStringConcat(groupArray(distinct Name),',') as spec
    from vp_prod_ops_front_office.SpecialRequest
    group by 1
),

room as (
    select 
        Id as id,
        ReserveStatus as reserve_status,
        IsDeleted as is_deleted,
        IsPsuedo as is_psuedo
    from vp_prod_ops_front_office.Room
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

select distinct on (id)
    binToString(profile_guest.id) as id,
    reservation.itinerary_number as itinerary_number,
    reservation.confirmation_number as confirmation_number,
    reservation.ta_rec_loc as ta_rec_loc,
    reservation.arrival_date as arrival_date,
    reservation.departure_date as departure_date,
    reservation.assigned_room_number as assigned_room_number,
    reservation.status as status,
    room.reserve_status as room_status,
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
    profile_company.full_name as company,
    profile_agent.full_name as travel_agent,
    reservation.block_booking_code as block_booking_code,
    reservation.eta as eta,
    reservation.etd as etd,
    reservation.room_type_code as room_type_code,
    case when lower(profile_guest.profile_type) = 'mainguest' then reservation.number_of_adult else 0 end as adults,
    case when lower(profile_guest.profile_type) = 'mainguest' then reservation.number_of_child else 0 end as children,
    case when lower(profile_guest.profile_type) = 'mainguest' then reservation.number_of_infant else 0 end as infant,
    toInt64(case when lower(profile_guest.profile_type) = 'mainguest' then 1 else 0 end) as room,
    reservation.rate_code as rate_code,
    reservation.total as amount,
    reservation.balance as balance,
    '' as payment_method,
    reservation.market_code as market_code,
    reservation.source_code as source_code,
    special_request.spec as special_request,
    '' as preference,
    reservation.comment as comment,
    reservation.internal_comment as internal_comment,
    '' as transportation,
    profile_guest.profile_type as profile_type,
    binToString(reservation.property_id) as property_id

from reservation
left join room_type on room_type.id = binToString(reservation.room_type_id)
left join profile_guest on profile_guest.reservation_id = reservation.reservation_id
left join profile on profile_guest.reference_id = profile.id
left join profile_agent on profile_agent.id = binToString(reservation.travel_agent_profile_id)
    and binToString(reservation.reservation_id) = profile_agent.reservation_id
left join profile_company on profile_company.id = binToString(reservation.company_profile_id)
    and binToString(reservation.reservation_id) = profile_company.reservation_id
left join special_request on special_request.reservation_id = reservation.reservation_id
left join room on room.id = reservation.assigned_room_id

where lower(profile_guest.profile_type) in ('mainguest', 'accompanyguest')
    and ((room.is_deleted = 0 and room.is_psuedo = 0) or reservation.assigned_room_number is null)
    and room_type.is_deleted = 0 and room_type.is_pseudo = 0
    and reservation.arrival_date = toDate(now('Asia/Bangkok'))
    and (
        case 
            when '$etaFrom' is null and '$etaTo' is null then true 
            when '$etaFrom' is null and '$etaTo' is not null then cast(coalesce(eta,'1970-01-01') as time) <= cast(coalesce('$etaTo','1970-01-01') as time)
            when '$etaFrom' is not null and '$etaTo' is null then cast(coalesce(eta,'1970-01-01') as time) >= cast(coalesce('$etaFrom', '1970-01-01') as time)
            else cast(coalesce(eta,'1970-01-01') as time) BETWEEN cast(coalesce('$etaFrom', '1970-01-01') as time) and cast(coalesce('$etaTo','1970-01-01') as time)
        end)
    and (
        case
            when '$isVipOnly' then vip_code <> ''
            else true
        end)
    and (
        case
            when '$isCheckedInToday' then true
            else room_status in ('Precheckin', 'Reserved')
        end)
    and (
        case
            when '$isMainGuestOnly' then profile_type = 'MainGuest'
            else true
        end)
order by
	(case when '$groupBy' = 'arrivalDate' then arrival_date end),
	(case when '$groupBy' = 'itineraryNumber' then itinerary_number end),
	(case when '$groupBy' = 'groupCode' then block_booking_code end),
	(case when '$sortOrder' = 'ArrivalDate' then arrival_date end) ASC,
	(case when '$sortOrder' = 'itineraryNumber' then itinerary_number else assigned_room_number end) ASC)

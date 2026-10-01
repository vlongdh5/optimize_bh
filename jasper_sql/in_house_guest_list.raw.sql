select * from (with reservation as (
    select 
        ReservationId as reservation_id,
        Status as status,
        ConfirmationNumber as confirmation_number,
        AssignedRoomNumber as assigned_room_number,
        BlockBookingCode as block_booking_code,
        ArrivalDate as arrival_date,
        DepartureDate as departure_date,
        Etd as etd,
        RoomTypeCode as room_type_code,
        RoomTypeId as room_type_id,
        numberOfAdult as number_of_adult,
        numberOfChild as number_of_child,
        RateCode as rate_code,
        MarketCode as market_code,
        Comment as comment,
        internalComment as internal_comment,
        PropertyId as property_id,
        TravelAgentProfileId as travel_agent_profile_id,
        CompanyProfileId as company_profile_id
    from vp_prod_ops_front_office.Reservation
    where lower(Status) = 'inhouse'
    and $X{IN, binToString(PropertyId), propertyId}
),

room_type as (
    select 
        id,
        isDeleted as is_deleted,
        isPseudo as is_pseudo
    from vp_prod_pms_property.pro_room_type
),

staying as (
    select 
        Id as id,
        ReservationId as reservation_id,
        ProfileId as profile_id,
        Status as status
    from vp_prod_ops_front_office.Staying
),

profile_guest as (
    select 
        Id as id,
        ReservationId as reservation_id,
        ReferenceId as reference_id,
        getFullName(LastName,FirstName) as full_name,
        VipCode as vip_code,
        Nationality as nationality,
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
        groupArray(distinct Name) as spec
    from vp_prod_ops_front_office.SpecialRequest
    group by 1
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

select distinct on (staying.id)
    binToString(staying.id) as id,
    reservation.confirmation_number as confirmation_number,
    reservation.assigned_room_number as assigned_room_number,
    case
        when profile_guest.reference_id is not null and profile.id is not null
            then profile.full_name
        else profile_guest.full_name end
    as name,
    profile_guest.vip_code as vip_code,
    case
        when profile_guest.reference_id is not null and profile.nationality_code is not null
            then profile.nationality_code
        else profile_guest.nationality end
    as nationality,
    reservation.block_booking_code as block_booking_code,
    profile_company.full_name as company,
    profile_agent.full_name as travel_agent,
    reservation.arrival_date as arrival_date,
    reservation.departure_date as departure_date,
    reservation.etd as etd,
    reservation.room_type_code as room_type_code,
    case when lower(profile_guest.profile_type) = 'mainguest' then reservation.number_of_adult else 0 end as number_of_adult,
    case when lower(profile_guest.profile_type) = 'mainguest' then reservation.number_of_child else 0 end as number_of_child,
    '' as payment_method,
    reservation.rate_code as rate_code,
    reservation.market_code as market_code,
    arrayStringConcat(special_request.spec, ',') as special_request,
    reservation.comment as comment,
    reservation.internal_comment as internal_comment,
    binToString(reservation.property_id) as property_id

from reservation
left join room_type on binToString(reservation.room_type_id) = room_type.id
left join staying on reservation.reservation_id = staying.reservation_id
left join profile_guest
    on
        staying.reservation_id = profile_guest.reservation_id
        and staying.profile_id = profile_guest.id
left join profile on profile_guest.reference_id = profile.id
left join profile_agent
    on
        binToString(reservation.travel_agent_profile_id) = profile_agent.id
        and binToString(reservation.reservation_id) = profile_agent.reservation_id
left join profile_company
    on
        binToString(reservation.company_profile_id) = profile_company.id
        and binToString(reservation.reservation_id) = profile_company.reservation_id
left join special_request on reservation.reservation_id = special_request.reservation_id

where
    lower(profile_guest.profile_type) in ('mainguest', 'accompanyguest')
    and lower(staying.status) = 'inhouse'
    and room_type.is_deleted = 0 and room_type.is_pseudo = 0)
order by assigned_room_number, name
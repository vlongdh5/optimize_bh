select * from (
with reservation as (
    select 
        Id as id,
        ReservationId as reservation_id,
        Status as status,
        AssignedRoomId as assigned_room_id,
        AssignedRoomNumber as assigned_room_number,
        ConfirmationNumber as confirmation_number,
        ItineraryNumber as itinerary_number,
        ArrivalDate as arrival_date,
        DepartureDate as departure_date,
        RoomTypeCode as room_type_code,
        RoomTypeId as room_type_id,
        numberOfAdult as number_of_adult,
        Balance as balance,
        PropertyId as property_id,
        TravelAgentProfileId as travel_agent_profile_id,
        CompanyProfileId as company_profile_id
    from vp_prod_ops_front_office.Reservation
    where lower(Status) = 'inhouse'
    and $X{IN, binToString(PropertyId), propertyId}
    and $X{IN, RoomTypeId, roomTypeIds}
),

room as (
    select 
        Id as id,
        IsDeleted as is_deleted,
        IsPsuedo as is_psuedo
    from vp_prod_ops_front_office.Room
),

profile_guest as (
    select 
        ReservationId as reservation_id,
        ReferenceId as reference_id,
        getFullName(LastName, FirstName) as full_name,
        Title as title,
        VipCode as vip_code,
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
    reservation.assigned_room_number as assigned_room_number,
    case
        when profile_guest.reference_id is not null and profile.id is not null
            then profile.full_name
        else profile_guest.full_name end
    as name,
    reservation.confirmation_number as confirmation_number,
    reservation.itinerary_number as itinerary_number,
    profile_guest.title as title,
    profile_guest.vip_code as vip_code,
    profile_company.full_name as company,
    profile_agent.full_name as travel_agent,
    reservation.arrival_date as arrival_date,
    reservation.departure_date as departure_date,
    reservation.room_type_code as room_type_code,
    reservation.number_of_adult as number_of_adult,
    reservation.balance as balance,
    binToString(reservation.room_type_id) as room_type_id,
    binToString(reservation.property_id) as property_id

from reservation
inner join room on room.id = reservation.assigned_room_id
left join profile_guest on profile_guest.reservation_id = reservation.reservation_id
left join profile on profile_guest.reference_id = profile.id
left join profile_agent on profile_agent.id = binToString(reservation.travel_agent_profile_id)
    and binToString(reservation.reservation_id) = profile_agent.reservation_id
left join profile_company on profile_company.id = binToString(reservation.company_profile_id)
    and binToString(reservation.reservation_id) = profile_company.reservation_id

where lower(profile_guest.profile_type) = 'mainguest'
    and room.is_deleted = 0 and room.is_psuedo = 1
ORDER BY
	case $P{sortBy} when 'ROOM_NO' then reservation.assigned_room_number end $P!{sortDirection},
	case $P{sortBy} when 'BALANCE' then reservation.balance end $P!{sortDirection},
	case $P{sortBy} when 'DEPARTURE_DATE' then reservation.departure_date end $P!{sortDirection}
)
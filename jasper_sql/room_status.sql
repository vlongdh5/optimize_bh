select * from (with room as (
    select 
        id,
        roomNumber as room_number,
        roomTypeId as room_type_id,
        roomStatus as room_status,
        foStatus as fo_status,
        reservationStatus as reservation_status,
        hkStatus as hk_status,
        discrepancy,
        propertyId as property_id,
        isPseudo as is_pseudo,
        isDeleted as is_deleted
    from vp_prod_pms_room_management.pro_room_status
    where propertyId IN ('$propertyId')
),

room_type as (
    select 
        id,
        code,
        isPseudo as is_pseudo,
        isDeleted as is_deleted
    from vp_prod_pms_property.pro_room_type
),

room_assignment as (
    select 
        RoomId as room_id,
        ReservationId as reservation_id,
        FromDate as from_date,
        State as state
    from vp_prod_ops_front_office.RoomAssignment
),

reservation as (
    select 
        ReservationId as reservation_id,
        mainGuestProfileId as main_guest_profile_id,
        ArrivalDate as arrival_date,
        DepartureDate as departure_date
    from vp_prod_ops_front_office.Reservation
),

profile_guest as (
    select 
        Id as id,
        ReferenceId as reference_id,
        getFullName(LastName,FirstName) as full_name,
        VipCode as vip_code,
        Nationality as nationality
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

room_info as (
select
    room.id as id,
    room.room_number as room_number,
    room_type.code as code,
    case
        when room.reservation_status = 'NOT_RESERVED'
            then ''
        else arrayStringConcat(
            groupArray(
                coalesce(
                    case
                        when profile_guest.reference_id is not null and profile.id is not null
                            then profile.full_name
                        else profile_guest.full_name
                    end,
                    ''
                )
            ),
            '\n'
        )
    end as name,
    case
        when room.reservation_status = 'NOT_RESERVED'
            then ''
        else arrayStringConcat(groupArray(coalesce(profile_guest.vip_code, '')), '\n')
    end as vip_code,
    case
        when room.reservation_status = 'NOT_RESERVED'
            then ''
        else arrayStringConcat(
            groupArray(
                coalesce(
                    case
                        when profile_guest.reference_id is not null and profile.nationality_code is not null
                            then profile.nationality_code
                        else profile_guest.nationality
                    end,
                    ''
                )
            ),
            '\n'
        )
    end as nationality,
    room.room_status as status,
    room.fo_status as fo_status,
    room.reservation_status as reserve_status,
    room.hk_status as hk_status,
    room.discrepancy as discrepancy,
    case
        when room.reservation_status = 'NOT_RESERVED'
            then ''
        else case
            when room.reservation_status = 'ARRIVED'
                then arrayStringConcat(groupArray(coalesce(formatDateTime(room_assignment.from_date, '%d/%m/%Y'), '')), '\n')
            else arrayStringConcat(groupArray(coalesce(formatDateTime(reservation.arrival_date, '%d/%m/%Y'), '')), '\n')
            end
    end as arrival_date,
    case
        when room.reservation_status = 'NOT_RESERVED'
            then ''
        else arrayStringConcat(groupArray(coalesce(formatDateTime(reservation.departure_date, '%d/%m/%Y'), '')), '\n')
    end as departure_date,
    case
        when room.reservation_status = 'NOT_RESERVED'
            then ''
        else arrayStringConcat(groupArray(coalesce(arrayStringConcat(special_request.spec, '\n'), '')), '\n')
    end as special_request,
    room.property_id as property_id
from room
left join room_type on room.room_type_id = room_type.id
left join room_assignment on room.id = binToString(room_assignment.room_id)
left join reservation on room_assignment.reservation_id = reservation.reservation_id
left join profile_guest on reservation.main_guest_profile_id = profile_guest.id
left join profile on profile_guest.reference_id = profile.id
left join special_request on reservation.reservation_id = special_request.reservation_id
where
    room_type.is_pseudo = 0 and room_type.is_deleted = 0
    and room.is_pseudo = 0 and room.is_deleted = 0
    and (case
        when room.reservation_status != 'NOT_RESERVED'
            then room_assignment.state not in ('INACTIVE', 'MOVE')
        else true
        end)
    and (
        (room.reservation_status = 'ARRIVED' and room_assignment.from_date = toDate(now('Asia/Bangkok')))
        or
        (room.reservation_status in ('ARRIVAL', 'DEPARTED_ARRIVAL', 'DUE_OUT_ARRIVAL') and reservation.arrival_date = toDate(now('Asia/Bangkok')))
        or
        (room.reservation_status in ('DEPARTED', 'DEPARTED_ARRIVAL', 'DUE_OUT', 'DUE_OUT_ARRIVAL') and reservation.departure_date = toDate(now('Asia/Bangkok')))
        or
        (room.reservation_status = 'STAY_OVER' and (reservation.arrival_date <= toDate(now('Asia/Bangkok')) and reservation.departure_date >= toDate(now('Asia/Bangkok'))))
        or
        (room.reservation_status = 'NOT_RESERVED')
    )
group by 1, 2, 3, 7, 8, 9, 10, 11, 15
)

select
    room.id as id,
    room.room_number as room_number,
    room_type.code as code,
    coalesce(room_info.name, '') as name,
    coalesce(room_info.vip_code, '') as vip_code,
    coalesce(room_info.nationality, '') as nationality,
    room.room_status as status,
    room.fo_status as fo_status,
    room.reservation_status as reserve_status,
    room.hk_status as hk_status,
    room.discrepancy as discrepancy,
    coalesce(room_info.arrival_date, '') as arrival_date,
    coalesce(room_info.departure_date, '') as departure_date,
    coalesce(room_info.special_request, '') as special_request,
    room.property_id as property_id
from room
left join room_type on room.room_type_id = room_type.id
left join room_info on room.id = room_info.id
where room_type.is_pseudo = 0 and room_type.is_deleted = 0
    and room.is_pseudo = 0 and room.is_deleted = 0
    and vip_code != ''
order by room.room_number)

select * from (with hk_v2_group as (
    select 
        id,
        shiftId as shift_id,
        propertyId as property_id,
        date,
        status
    from vp_prod_pms_house_keeping.hk_v2_group
    where status = 'COMMIT'
    and $X{IN, propertyId, propertyId}
),

hk_shift as (
    select 
        id,
        name
    from vp_prod_pms_house_keeping.hk_shift
),

hk_v2_group_user_task as (
    select 
        groupId as group_id,
        userId as user_id
    from vp_prod_pms_house_keeping.hk_v2_group_user_task
),

hk_user as (
    select 
        id,
        name
    from vp_prod_pms_house_keeping.hk_user
),

hk_v2_group_room as (
    select 
        groupId as group_id,
        roomId as room_id,
        status
    from vp_prod_pms_house_keeping.hk_v2_group_room
),

hk_v2_room as (
    select 
        id,
        roomNumber as room_number,
        roomStatus as room_status,
        foStatus as fo_status,
        hkStatus as hk_status,
        reservationStatus as reservation_status,
        roomTypeCode as room_type_code
    from vp_prod_pms_house_keeping.hk_v2_room
),

hk_v2_room_reservation as (
    select 
        id,
        arrivalDate as arrival_date,
        departureDate as departure_date,
        confirmationNumber as confirmation_number,
        confirmationStatus as confirmation_status,
        guestName as guest_name,
        guestNationality as guest_nationality,
        guestVipLevel as guest_vip_level
    from vp_prod_pms_house_keeping.hk_v2_room_reservation
),

assigned as (
    select
        hk_v2_group_user_task.group_id as group_id,
        arrayStringConcat(groupArray(hk_user.name), '\n') as user_name

    from hk_v2_group_user_task
    inner join hk_user on hk_user.id = hk_v2_group_user_task.user_id

    group by 1
),

room as (
    select
        hk_v2_group_room.group_id as group_id,
        hk_v2_group_room.room_id as room_id,
        hk_v2_group_room.status as status,
        hk_v2_room.room_number as room_number,
        hk_v2_room.room_status as room_status,
        hk_v2_room.fo_status as fo_status,
        hk_v2_room.hk_status as hk_status,
        hk_v2_room.reservation_status as reservation_status,
        hk_v2_room.room_type_code as room_type_code,
        hk_v2_room_reservation.arrival_date as arrival_date,
        hk_v2_room_reservation.departure_date as departure_date,
        hk_v2_room_reservation.confirmation_number as confirmation_number,
        hk_v2_room_reservation.confirmation_status as confirmation_status,
        hk_v2_room_reservation.guest_name as guest_name,
        hk_v2_room_reservation.guest_nationality as guest_nationality,
        hk_v2_room_reservation.guest_vip_level as guest_vip_level

    from hk_v2_group_room
    left join hk_v2_room on hk_v2_room.id = hk_v2_group_room.room_id
    left join hk_v2_room_reservation on hk_v2_room_reservation.id = hk_v2_room.id
)

select
    hk_shift.name as name,
    assigned.user_name as user_name,
    room.group_id AS group_id,
    room.room_id AS room_id,
    room.status AS status,
    room.room_number AS room_number,
    room.room_status AS room_status,
    room.fo_status AS fo_status,
    room.hk_status AS hk_status,
    room.reservation_status AS reservation_status,
    room.room_type_code AS room_type_code,
    room.arrival_date AS arrival_date,
    room.departure_date AS departure_date,
    room.confirmation_number AS confirmation_number,
    room.confirmation_status AS confirmation_status,
    room.guest_name AS guest_name,
    room.guest_nationality AS guest_nationality,
    room.guest_vip_level AS guest_vip_level,
    hk_v2_group.property_id as property_id

from hk_v2_group
left join hk_shift on hk_shift.id = hk_v2_group.shift_id
left join assigned on assigned.group_id = hk_v2_group.id
inner join room on room.group_id = hk_v2_group.id

where hk_v2_group.date = toDate(now('Asia/Bangkok'))
order by hk_shift.name, room.room_number)
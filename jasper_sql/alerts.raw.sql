select * from (with reservation_alert as (
    select 
        Id as id,
        ReservationId as reservation_id,
        CodeId as code_id,
        Area as area,
        Description as description,
        CreatedAt as created_at,
        CreatedBy as created_by,
        ModifiedAt as modified_at,
        ModifiedBy as modified_by
    from vp_prod_ops_front_office.ReservationAlert
    where true
    and $X{IN, binToString(PropertyId), propertyId}
),

alert_config as (
    select 
        Id as id,
        Code as code
    from vp_prod_ops_front_office.AlertConfig
),

reservation as (
    select 
        ReservationId as reservation_id,
        ConfirmationNumber as confirmation_number,
        AssignedRoomNumber as assigned_room_number,
        mainGuestProfileId as main_guest_profile_id,
        ArrivalDate as arrival_date,
        DepartureDate as departure_date,
        RoomTypeCode as room_type_code,
        Status as status,
        PropertyId as property_id
    from vp_prod_ops_front_office.Reservation
    where lower(Status) != 'canceled'
),

pms_profile as (
    select 
        Id as id,
        getFullName(LastName,FirstName) as full_name
    from vp_prod_ops_front_office.PmsProfile
),

cts_user as (
    select 
        id,
        getFullName(lastname,firstname) as full_name
    from vp_prod_cts_customer.user
)

select
    binToString(reservation_alert.id) as id,
    reservation.confirmation_number as confirmation_number,
    reservation.assigned_room_number as assigned_room_number,
    pms_profile.full_name as name,
    reservation.arrival_date as arrival_date,
    reservation.departure_date as departure_date,
    reservation.room_type_code as room_type_code,
    reservation_alert.area as area,
    alert_config.code as code,
    reservation_alert.description as description,
    reservation_alert.created_at as created_at,
    user1.full_name as created_by,
    reservation_alert.modified_at as modified_at,
    user2.full_name as modified_by,
    reservation.status as status,
    binToString(reservation.property_id) as property_id

from reservation_alert
left join alert_config on reservation_alert.code_id = alert_config.id
left join reservation on reservation_alert.reservation_id = reservation.reservation_id
left join pms_profile on pms_profile.id = reservation.main_guest_profile_id
left join cts_user as user1 on binToString(reservation_alert.created_by) = user1.id
left join cts_user as user2 on binToString(reservation_alert.modified_by) = user2.id

where true
    and (reservation.arrival_date = toDate(now('Asia/Bangkok')) or reservation.status = 'Inhouse')
order by 
	(case $P{sortByType} when 'CONFIRMATION_NO' then reservation.confirmation_number end),
	(case $P{sortByType} when 'ARRIVAL_DATE' then reservation.arrival_date end),
	(case $P{sortByType} when 'ROOM_NO' then reservation.assigned_room_number end)
)
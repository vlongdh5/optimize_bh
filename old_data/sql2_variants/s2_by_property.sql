-- s2: giống s1 nhưng đọc từ 3 bảng sắp theo PropertyId (sql2_structural/01..03)
with reservation as (
    select Id, Status, RoomNumber, PropertyId
    from test_data.Reservation_by_property
    where PropertyId = '9f474bc1-62f4-666b-1c63-7e7330412cfd'
      and Status is not null
      and (lower(Status) = 'inhouse' or CurrentLedger = 'GL')
),
post_transaction as (
    select ReservationId, FolioId, ConfirmationNumber, sum(Amount) as amount
    from test_data.PostTransaction_by_property
    where PropertyId = '9f474bc1-62f4-666b-1c63-7e7330412cfd'
      and State = 1
      and bitAnd(IncludeExclude, 1) = 1
      and ReservationId in (select Id from reservation)
    group by ReservationId, FolioId, ConfirmationNumber
)
select
    pt.FolioId as id,
    r.Status as status,
    f.name as name,
    pt.ConfirmationNumber as confirmation_number,
    r.RoomNumber as room_number,
    sum(pt.amount) as amount,
    r.PropertyId as property_id
from post_transaction pt
inner join reservation r on pt.ReservationId = r.Id
left join (
    select Id, getFullName(ProfileLastName, ProfileFirstName) as name
    from test_data.Folio_by_property
    where PropertyId = '9f474bc1-62f4-666b-1c63-7e7330412cfd'
) f on f.Id = pt.FolioId
group by id, status, name, confirmation_number, room_number, property_id
order by status, room_number

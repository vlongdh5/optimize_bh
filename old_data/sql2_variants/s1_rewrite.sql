-- s1: viết lại sql2.sql, kết quả giữ nguyên
--  * gộp 2 nhánh UNION ALL của Reservation thành 1 lần quét
--    (lower(Status) != 'inhouse' AND GL) OR lower(Status) = 'inhouse'
--    <=> Status IS NOT NULL AND (lower(Status) = 'inhouse' OR CurrentLedger = 'GL')
--  * lọc PostTransaction theo tập reservation cần dùng rồi gộp ngay sau khi quét
--    (6,6 triệu dòng -> vài nghìn dòng trước khi join)
--  * join Folio sau khi gộp; LEFT JOIN + WHERE trên bảng phải vốn là INNER JOIN
with reservation as (
    select Id, Status, RoomNumber, PropertyId
    from vp_prod_ops_transaction_account.Reservation
    where PropertyId = '9f474bc1-62f4-666b-1c63-7e7330412cfd'
      and Status is not null
      and (lower(Status) = 'inhouse' or CurrentLedger = 'GL')
),
post_transaction as (
    select ReservationId, FolioId, ConfirmationNumber, sum(Amount) as amount
    from vp_prod_ops_transaction_account.PostTransaction
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
    from vp_prod_ops_transaction_account.Folio
    where PropertyId = '9f474bc1-62f4-666b-1c63-7e7330412cfd'
) f on f.Id = pt.FolioId
group by id, status, name, confirmation_number, room_number, property_id
order by status, room_number

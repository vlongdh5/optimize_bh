select * from (with department as (
    select 
        code as code,
        name as name,
        hotelId as hotel_id
    from vp_prod_aux_task_management.department
    where isDeleted = 0
),

task as (
    select 
        id as id,
        tmType as tm_type,
        code as code,
        name as name,
        state as state,
        areaName as area_name,
        confirmationNumber as confirmation_number,
        guestName as guest_name,
        assigneedName as assigneed_name,
        dueDate as due_date,
        note as note,
        comment as comment,
        hotelId as hotel_id,
        organizationId as organization_id
    from vp_prod_aux_task_management.task
    where date(dueDate) >= toDate(now('Asia/Bangkok'))
    and $X{IN, hotelId, propertyId}
)

select
    task.id as id,
    concat(task.tm_type, '-', task.code) as tm_number,
    department.name as department_name,
    task.name as tm_name,
    task.state as state,
    task.area_name as area_name,
    task.confirmation_number as confirmation_number,
    task.guest_name as guest_name,
    task.assigneed_name as assigneed_name,
    task.due_date as due_date,
    task.note as tm_note,
    task.comment as comment,
    task.hotel_id as property_id,
    task.organization_id as organization_id

from task
inner join department on task.tm_type = department.code and task.hotel_id = department.hotel_id)
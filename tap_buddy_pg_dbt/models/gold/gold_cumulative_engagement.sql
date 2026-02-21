{{ config(materialized='table') }}

with ae as (
    select
        student_id,
        activity_id,
        coalesce(video_max_progress, 0) as video_watch_percent,
        coalesce(quiz_is_completed, 0) as quiz_completed,
        coalesce(project_is_completed, 0) as project_submitted
    from {{ ref('gold_activity_engagement') }}
),

per_student as (
    select
        student_id,

        -- counts of activities matching each condition
        sum(case when video_watch_percent >= 80 then 1 else 0 end) as activities_video_80_plus,
        sum(case when quiz_completed = 1 then 1 else 0 end) as activities_quiz_completed,
        sum(case when project_submitted = 1 then 1 else 0 end) as activities_project_submitted

    from ae
    group by 1
),

grade7 as (
    select
        student_id
    from {{ ref('bronze_crm_students') }}
    where grade = 7
)

select
    s.student_id,
    p.activities_video_80_plus,
    p.activities_quiz_completed,
    p.activities_project_submitted
from grade7 s
left join per_student p
    on s.student_id = p.student_id
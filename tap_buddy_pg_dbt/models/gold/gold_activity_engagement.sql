{{ config(materialized='table') }}

with spine as (
    select student_id, activity_id
    from {{ ref('silver_activity_spine') }}
),

msg as (
    select
        student_id,
        activity_id,
        is_reached,
        first_outbound_ts,
        has_any_inbound,
        last_message_ts
    from {{ ref('silver_activity_message_signals') }}
),

vid as (
    select
        student_id,
        activity_id,
        video_max_progress,
        has_video_completed,
        video_completed_ts,
        video_started_ts
    from {{ ref('silver_activity_video_signals') }}
),

assess as (
    select
        student_id,
        activity_id,
        quiz_is_completed,
        project_is_completed,
        quiz_completed_ts,
        project_completed_ts,
        quiz_started_ts,
        project_started_ts
    from {{ ref('silver_activity_assessment_signals') }}
),

final as (
    select
        s.student_id,
        s.activity_id,

        coalesce(m.is_reached, 0) as is_reached,
        m.first_outbound_ts,
        coalesce(m.has_any_inbound, 0) as has_any_inbound,

        v.video_max_progress,
        coalesce(v.has_video_completed, 0) as has_video_completed,

        coalesce(a.quiz_is_completed, 0) as quiz_is_completed,
        coalesce(a.project_is_completed, 0) as project_is_completed,

        -- last engagement across messages + video + assessments
        greatest(
            coalesce(m.last_message_ts, timestamp '1900-01-01'),
            coalesce(v.video_completed_ts, timestamp '1900-01-01'),
            coalesce(v.video_started_ts, timestamp '1900-01-01'),
            coalesce(a.quiz_completed_ts, timestamp '1900-01-01'),
            coalesce(a.quiz_started_ts, timestamp '1900-01-01'),
            coalesce(a.project_completed_ts, timestamp '1900-01-01'),
            coalesce(a.project_started_ts, timestamp '1900-01-01')
        ) as activity_last_engagement_ts

    from spine s
    left join msg m
        on s.student_id = m.student_id
       and s.activity_id = m.activity_id
    left join vid v
        on s.student_id = v.student_id
       and s.activity_id = v.activity_id
    left join assess a
        on s.student_id = a.student_id
       and s.activity_id = a.activity_id
)

select
    student_id,
    activity_id,
    is_reached,
    first_outbound_ts,
    has_any_inbound,
    video_max_progress,
    has_video_completed,
    quiz_is_completed,
    project_is_completed,
    nullif(activity_last_engagement_ts, timestamp '1900-01-01') as activity_last_engagement_ts
from final

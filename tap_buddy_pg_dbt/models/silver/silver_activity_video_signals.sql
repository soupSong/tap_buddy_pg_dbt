-- models/silver/silver_activity_video_signals.sql
-- Video component signals at grain (student_id, activity_id)

{{ config(materialized='view') }}

with base as (
    select
        student_id,
        activity_id,
        event_ts::timestamp as event_ts,
        event_type,
        progress_percent
    from {{ ref('silver_video_events') }}
),

ordered as (
    select
        *,
        lag(progress_percent) over (
            partition by student_id, activity_id
            order by event_ts
        ) as previous_progress
    from base
),

session_flags as (
    select
        *,
        case
            when previous_progress is null then 1
            when progress_percent < previous_progress then 1
            else 0
        end as is_new_session
    from ordered
),

sessions as (
    select
        *,
        sum(is_new_session) over (
            partition by student_id, activity_id
            order by event_ts
            rows between unbounded preceding and current row
        ) as session_number
    from session_flags
),

session_stats as (
    select
        student_id,
        activity_id,
        session_number,
        max(progress_percent) as session_max_progress,
        count(*) as session_event_count
    from sessions
    group by 1,2,3
),

best_session as (
    select
        *,
        row_number() over (
            partition by student_id, activity_id
            order by session_event_count desc, session_max_progress desc
        ) as rn
    from session_stats
),

session_counts as (
    select
        student_id,
        activity_id,
        max(session_number) as video_session_count
    from sessions
    group by 1,2
),

agg as (
    select
        student_id,
        activity_id,

        min(case when event_type = 'video_started' then event_ts end) as video_started_ts,
        max(case when event_type = 'video_completed' then event_ts end) as video_completed_ts,

        max(progress_percent) as video_max_progress,

        case when max(case when event_type = 'video_started' then 1 else 0 end) = 1 then 1 else 0 end
            as has_video_started,

        case when max(case when event_type = 'video_completed' then 1 else 0 end) = 1 then 1 else 0 end
            as has_video_completed

    from base
    group by 1,2
)

select
    a.student_id,
    a.activity_id,

    a.video_started_ts,
    a.video_completed_ts,

    a.video_max_progress,

    coalesce(sc.video_session_count, 0) as video_session_count,

    -- "best session" max progress
    bs.session_max_progress as best_session_max_progress,

    a.has_video_started,
    a.has_video_completed

from agg a
left join session_counts sc
    on a.student_id = sc.student_id
   and a.activity_id = sc.activity_id
left join best_session bs
    on a.student_id = bs.student_id
   and a.activity_id = bs.activity_id
   and bs.rn = 1



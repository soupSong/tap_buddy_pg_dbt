{{ config(materialized='view') }}

with e as (
    select
        student_id,
        activity_id as raw_activity_id,
        event_ts::timestamp as event_ts,
        event_type,
        progress_percent::float as progress_percent
    from {{ ref('bronze_bq_video_events') }}
),

w as (
    select
        student_id,
        activity_id as attributed_activity_id,
        window_start_ts,
        window_end_ts
    from {{ ref('silver_activity_windows') }}
),

matched as (
    select
        e.student_id,
        e.raw_activity_id,
        w.attributed_activity_id as activity_id,
        e.event_ts,
        e.event_type,
        e.progress_percent,
        row_number() over (
            partition by e.student_id, e.event_ts, e.event_type, coalesce(e.progress_percent, -1)
            order by w.window_start_ts desc
        ) as rn
    from e
    join w
      on e.student_id = w.student_id
     and e.event_ts >= w.window_start_ts
     and e.event_ts <  w.window_end_ts
)

select
    student_id,
    activity_id,
    event_ts,
    event_type,
    progress_percent
from matched
where rn = 1
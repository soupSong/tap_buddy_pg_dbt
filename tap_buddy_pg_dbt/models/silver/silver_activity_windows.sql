{{ config(materialized='view') }}

with anchors as (
    select
        student_id,
        activity_id,
        min(message_ts::timestamp) as anchor_ts
    from {{ ref('bronze_bq_messages') }}
    where direction = 'outbound'
      and message_type in ('video_link', 'quiz_start_prompt', 'project_prompt')
    group by student_id, activity_id
),

ordered as (
    select
        *,
        lead(anchor_ts) over (
            partition by student_id
            order by anchor_ts
        ) as next_anchor_ts
    from anchors
)

select
    student_id,
    activity_id,
    anchor_ts as window_start_ts,
    coalesce(next_anchor_ts, anchor_ts + interval '7 days') as window_end_ts
from ordered
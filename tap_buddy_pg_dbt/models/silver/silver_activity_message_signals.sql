
{{ config(materialized='view') }}

with base as (
    select
        student_id,
        activity_id,
        message_ts::timestamp as message_ts,
        direction,     -- 'inbound'/'outbound'
        message_type,
        payload
    from {{ ref('bronze_bq_messages') }}
),

agg as (
    select
        student_id,
        activity_id,

        -- counts
        count(*) as total_messages,
        sum(case when direction = 'outbound' then 1 else 0 end) as outbound_message_count,
        sum(case when direction = 'inbound' then 1 else 0 end)  as inbound_message_count,

        -- flags
        case when sum(case when direction = 'outbound' then 1 else 0 end) > 0 then 1 else 0 end as is_reached,
        case when sum(case when direction = 'inbound' then 1 else 0 end) > 0 then 1 else 0 end  as has_any_inbound,

        -- timestamps
        min(case when direction = 'outbound' then message_ts end) as first_outbound_ts,
        min(message_ts) as first_message_ts,
        max(message_ts) as last_message_ts,

        -- type-level counts
        sum(case when message_type = 'video_link' then 1 else 0 end) as video_link_count,
        sum(case when message_type = 'quiz_start_prompt' then 1 else 0 end) as quiz_prompt_count,
        sum(case when message_type = 'project_prompt' then 1 else 0 end) as project_prompt_count,
        sum(case when message_type = 'help' then 1 else 0 end) as help_message_count,
        sum(case when message_type = 'text' then 1 else 0 end) as text_message_count

    from base
    group by 1,2
)

select * from agg

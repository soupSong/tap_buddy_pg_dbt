-- models/silver/silver_activity_spine.sql
-- One row per (student_id, activity_id) across all event/message sources

{{ config(materialized='view') }}

with pairs as (

    select distinct student_id, activity_id
    from {{ ref('bronze_bq_messages') }}

    union
    select distinct student_id, activity_id
    from {{ ref('bronze_bq_video_events') }}

    union
    select distinct student_id, activity_id
    from {{ ref('bronze_bq_assessment_events') }}

)

select
    student_id,
    activity_id
from pairs

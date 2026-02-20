{{
  config(
    materialized = 'view',
    )
}}

SELECT
    *
FROM
    {{source('source', 'bq_video_events')}}
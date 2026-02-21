{# {{
  config(
    materialized = 'table',
    )
}} #}

SELECT
    *
FROM
    {{source('source', 'bq_video_events')}}
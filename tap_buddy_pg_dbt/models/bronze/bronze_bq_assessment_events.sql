{{
  config(
    materialized = 'view',
    )
}}

SELECT
    *
FROM
    {{source('source', 'bq_assessment_events')}}
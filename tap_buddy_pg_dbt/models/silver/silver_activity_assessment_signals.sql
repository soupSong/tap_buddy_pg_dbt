

{{ config(materialized='view') }}

with base as (
    select
        student_id,
        activity_id,
        event_ts::timestamp as event_ts,
        assessment_type,      -- 'quiz' or 'project'
        event_type,           -- 'started', 'completed', 'scored'
        score,
        max_score
    from {{ ref('silver_assessment_events') }}
),

per_type as (
    select
        student_id,
        activity_id,
        assessment_type,

        min(case when event_type = 'started' then event_ts end)   as started_ts,
        max(case when event_type = 'completed' then event_ts end) as completed_ts,

        max(case when event_type = 'started' then 1 else 0 end)   as is_started,
        max(case when event_type = 'completed' then 1 else 0 end) as is_completed,

        -- take latest scored row (if any)
        max(case when event_type = 'scored' then event_ts end) as latest_scored_ts
    from base
    group by 1,2,3
),

latest_scores as (
    select
        b.student_id,
        b.activity_id,
        b.assessment_type,
        b.score,
        b.max_score,
        row_number() over (
            partition by b.student_id, b.activity_id, b.assessment_type
            order by b.event_ts desc
        ) as rn
    from base b
    where b.event_type = 'scored'
),

scores as (
    select
        student_id,
        activity_id,
        assessment_type,
        score,
        max_score
    from latest_scores
    where rn = 1
),

joined as (
    select
        p.student_id,
        p.activity_id,
        p.assessment_type,
        p.started_ts,
        p.completed_ts,
        p.is_started,
        p.is_completed,
        s.score,
        s.max_score
    from per_type p
    left join scores s
        on p.student_id = s.student_id
       and p.activity_id = s.activity_id
       and p.assessment_type = s.assessment_type
)

select
    student_id,
    activity_id,

    -- QUIZ
    max(case when assessment_type = 'quiz' then started_ts end)    as quiz_started_ts,
    max(case when assessment_type = 'quiz' then completed_ts end)  as quiz_completed_ts,
    max(case when assessment_type = 'quiz' then is_started end)    as quiz_is_started,
    max(case when assessment_type = 'quiz' then is_completed end)  as quiz_is_completed,
    max(case when assessment_type = 'quiz' then score end)         as quiz_score,
    max(case when assessment_type = 'quiz' then max_score end)     as quiz_max_score,

    -- PROJECT
    max(case when assessment_type = 'project' then started_ts end)   as project_started_ts,
    max(case when assessment_type = 'project' then completed_ts end) as project_completed_ts,
    max(case when assessment_type = 'project' then is_started end)   as project_is_started,
    max(case when assessment_type = 'project' then is_completed end) as project_is_completed,
    max(case when assessment_type = 'project' then score end)        as project_score,
    max(case when assessment_type = 'project' then max_score end)    as project_max_score

from joined
group by 1,2

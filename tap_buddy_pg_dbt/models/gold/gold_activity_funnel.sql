{{ config(materialized='table') }}

with ae as (
    select
        student_id,
        activity_id,

        coalesce(is_reached, 0) as is_reached_i,

        case when coalesce(video_max_progress, 0) > 0 then 1 else 0 end as watched_video_i,

        -- attempted ~= completed
        coalesce(quiz_is_completed, 0) as quiz_attempted_i,
        coalesce(quiz_is_completed, 0) as quiz_completed_i,

        -- submitted ~= completed
        coalesce(project_is_completed, 0) as project_submitted_i

    from {{ ref('gold_activity_engagement') }}
),

agg as (
    select
        activity_id,

        sum(is_reached_i) as students_reached,
        sum(watched_video_i) as students_watched_video,
        sum(quiz_attempted_i) as students_quiz_attempted,
        sum(quiz_completed_i) as students_quiz_completed,
        sum(project_submitted_i) as students_project_submitted

    from ae
    group by activity_id
)

select
    activity_id,

    students_reached,
    students_watched_video,
    students_quiz_attempted,
    students_quiz_completed,
    students_project_submitted,

    -- conversion rates (as decimals)
    case when students_reached > 0
        then students_watched_video::float / students_reached
        else null end as cr_reached_to_video,

    case when students_watched_video > 0
        then students_quiz_attempted::float / students_watched_video
        else null end as cr_video_to_quiz_attempt,

    case when students_quiz_attempted > 0
        then students_quiz_completed::float / students_quiz_attempted
        else null end as cr_quiz_attempt_to_complete,

    case when students_quiz_completed > 0
        then students_project_submitted::float / students_quiz_completed
        else null end as cr_quiz_complete_to_project

from agg
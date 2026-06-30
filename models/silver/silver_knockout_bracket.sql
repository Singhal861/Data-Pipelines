{{config(
    materialized='table',
    tags=['dimension', 'bracket']
)}}

-- Pure bracket structure only — no match facts here
-- Used exclusively for drawing the tournament tree visualization
-- Join to silver_matches on match_id to get scores and team names

SELECT
    match_id,
    round,
    bracket_position,
    feeds_into_position,
    bracket_side,
    is_finished,
    ingested_at
    
FROM {{ source('bronze', 'knockout_bracket') }}
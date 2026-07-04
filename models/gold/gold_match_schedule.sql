{{config(
    materialized='table',
    tags=['gold', 'dashboard', 'live']
)}}

-- gold_match_schedule: Upcoming and Live Matches (Requirements #3, #4)
-- Uses goal_events for MATCH-LEVEL top scorers (not tournament-level player_stats)
-- Shows BOTH UTC and local time

WITH timezone_ref AS (
    SELECT * FROM {{ source('silver', 'ref_stadium_enriched') }}
),

parsed_matches AS (
    SELECT
        m.match_id,
        m.home_team_id,
        m.away_team_id,
        m.home_team_name,
        m.away_team_name,
        m.home_score,
        m.away_score,
        m.stage,
        m.group_name,
        m.is_finished,
        m.match_date_local,
        m.stadium_id,
        s.name AS stadium_name,
        tz.city AS stadium_city,
        tz.actual_country,
        tz.utc_offset_hours,
        TO_TIMESTAMP(
            REGEXP_REPLACE(m.match_date_local, ' [A-Z]{3,4}$', ''),
            'MM/dd/yyyy HH:mm'
        ) + MAKE_DT_INTERVAL(0, tz.utc_offset_hours, 0, 0) AS match_datetime_utc
    FROM {{ ref('silver_matches') }} m
    JOIN {{ ref('silver_stadiums') }} s ON m.stadium_id = s.stadium_id
    JOIN timezone_ref tz ON m.stadium_id = tz.stadium_id
),

with_team_logos AS (
    SELECT
        pm.*,
        ht.team_logo AS home_team_logo,
        at.team_logo AS away_team_logo
    FROM parsed_matches pm
    LEFT JOIN {{ ref('silver_teams') }} ht ON pm.home_team_name = ht.team_name
    LEFT JOIN {{ ref('silver_teams') }} at ON pm.away_team_name = at.team_name
),

-- Get MATCH-LEVEL top scorers from goal_events (who scored most in THIS match)
match_scorers AS (
    SELECT
        ge.match_id,
        ge.team_id,
        ge.scorer_name,
        COUNT(*) AS goals_in_match,
        ROW_NUMBER() OVER (
            PARTITION BY ge.match_id, ge.team_id 
            ORDER BY COUNT(*) DESC, MAX(ge.minute) DESC
        ) AS scorer_rank
    FROM {{ ref('silver_goal_events') }} ge
    GROUP BY ge.match_id, ge.team_id, ge.scorer_name
),

with_top_scorers AS (
    SELECT
        wtl.*,
        home_scorer.scorer_name AS home_top_scorer_name,
        home_scorer.goals_in_match AS home_top_scorer_goals,
        away_scorer.scorer_name AS away_top_scorer_name,
        away_scorer.goals_in_match AS away_top_scorer_goals
    FROM with_team_logos wtl
    LEFT JOIN match_scorers home_scorer 
        ON wtl.match_id = home_scorer.match_id 
        AND wtl.home_team_id = home_scorer.team_id 
        AND home_scorer.scorer_rank = 1
    LEFT JOIN match_scorers away_scorer 
        ON wtl.match_id = away_scorer.match_id 
        AND wtl.away_team_id = away_scorer.team_id 
        AND away_scorer.scorer_rank = 1
)

SELECT
    match_id,
    CASE
        WHEN is_finished = TRUE THEN 'Finished'
        WHEN is_finished = FALSE 
            AND match_datetime_utc <= CURRENT_TIMESTAMP() 
            AND match_datetime_utc >= CURRENT_TIMESTAMP() - INTERVAL 3 HOURS
            THEN 'Live'
        WHEN is_finished = FALSE 
            AND match_datetime_utc > CURRENT_TIMESTAMP()
            THEN 'Upcoming'
        ELSE 'Finished'
    END AS match_status,
    match_datetime_utc,  -- UTC time for standardized display
    match_date_local,    -- Local time where match is played
    home_team_id,
    home_team_name,
    home_team_logo,
    home_top_scorer_name,
    home_top_scorer_goals,
    home_score,
    away_team_id,
    away_team_name,
    away_team_logo,
    away_top_scorer_name,
    away_top_scorer_goals,
    away_score,
    stage,
    group_name,
    stadium_name,
    stadium_city,
    actual_country,
    CASE 
        WHEN match_datetime_utc > CURRENT_TIMESTAMP() 
        THEN ROUND((UNIX_TIMESTAMP(match_datetime_utc) - UNIX_TIMESTAMP(CURRENT_TIMESTAMP())) / 3600.0, 1)
        ELSE NULL
    END AS hours_until_kickoff,
    is_finished,
    CASE WHEN stage != 'Group Stage' THEN TRUE ELSE FALSE END AS is_knockout,
    CASE 
        WHEN is_finished = FALSE 
            AND match_datetime_utc <= CURRENT_TIMESTAMP() 
            AND match_datetime_utc >= CURRENT_TIMESTAMP() - INTERVAL 3 HOURS
        THEN TRUE
        ELSE FALSE
    END AS is_live,
    CASE
        WHEN is_finished = FALSE 
            AND match_datetime_utc <= CURRENT_TIMESTAMP()
        THEN ROUND((UNIX_TIMESTAMP(CURRENT_TIMESTAMP()) - UNIX_TIMESTAMP(match_datetime_utc)) / 60.0, 0)
        ELSE NULL
    END AS minutes_elapsed
FROM with_top_scorers
WHERE 
    match_datetime_utc >= CURRENT_TIMESTAMP() - INTERVAL 2 HOURS
    OR is_finished = FALSE
ORDER BY match_datetime_utc ASC

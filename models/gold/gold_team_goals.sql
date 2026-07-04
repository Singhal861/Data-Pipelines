{{config(
    materialized='table',
    tags=['gold', 'dashboard', 'team', 'goals']
)}}

-- gold_team_goals: Match-by-match goal details for each team
-- Shows WHO scored WHEN without aggregating scorer_name (avoids name inconsistencies)
-- Used for team detail view: "Show all goals scored by this team"

WITH timezone_ref AS (
    SELECT * FROM {{ source('silver', 'ref_stadium_enriched') }}
),

goal_details AS (
    SELECT
        ge.match_id,
        ge.team_id,
        ge.team_name,
        ge.scorer_name,
        ge.minute,
        ge.is_penalty,
        ge.is_home_goal,
        m.home_team_name,
        m.away_team_name,
        m.home_score,
        m.away_score,
        m.stage,
        m.match_date_local,
        m.stadium_id,
        s.name AS stadium_name,
        tz.city AS stadium_city,
        tz.actual_country,
        TO_TIMESTAMP(
            REGEXP_REPLACE(m.match_date_local, ' [A-Z]{3,4}$', ''),
            'MM/dd/yyyy HH:mm'
        ) + MAKE_DT_INTERVAL(0, tz.utc_offset_hours, 0, 0) AS match_datetime_utc,
        CASE
            WHEN ge.team_id = m.home_team_id THEN m.away_team_name
            ELSE m.home_team_name
        END AS opponent_team_name,
        CASE
            WHEN m.home_score > m.away_score AND ge.team_id = m.home_team_id THEN 'Win'
            WHEN m.away_score > m.home_score AND ge.team_id = m.away_team_id THEN 'Win'
            WHEN m.home_score = m.away_score THEN 'Draw'
            ELSE 'Loss'
        END AS match_result
    FROM {{ ref('silver_goal_events') }} ge
    JOIN {{ ref('silver_matches') }} m ON ge.match_id = m.match_id
    JOIN {{ ref('silver_stadiums') }} s ON m.stadium_id = s.stadium_id
    JOIN timezone_ref tz ON m.stadium_id = tz.stadium_id
    WHERE m.is_finished = TRUE
),

with_team_logo AS (
    SELECT
        gd.*,
        t.team_logo,
        -- Goal sequence within match for this team
        ROW_NUMBER() OVER (
            PARTITION BY gd.match_id, gd.team_id 
            ORDER BY gd.minute
        ) AS goal_number_in_match,
        -- Overall goal sequence for this team in tournament
        ROW_NUMBER() OVER (
            PARTITION BY gd.team_id 
            ORDER BY gd.match_datetime_utc, gd.minute
        ) AS goal_number_in_tournament
    FROM goal_details gd
    LEFT JOIN {{ ref('silver_teams') }} t ON gd.team_id = t.team_id
)

SELECT
    team_id,
    team_name,
    team_logo,
    match_id,
    match_datetime_utc,
    match_date_local,
    stage,
    opponent_team_name,
    match_result,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    scorer_name,
    minute,
    is_penalty,
    is_home_goal,
    goal_number_in_match,
    goal_number_in_tournament,
    stadium_name,
    stadium_city,
    actual_country,
    CASE 
        WHEN is_penalty THEN '⚽ (PEN)'
        ELSE '⚽'
    END AS goal_icon,
    CURRENT_TIMESTAMP() AS last_updated
FROM with_team_logo
ORDER BY team_name, match_datetime_utc, minute

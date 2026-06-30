{{config(
    materialized='table',
    tags=['fact', 'events', 'goals']
)}}

-- Parse goal events from scorer strings into normalized event records
-- Enables match timelines, top scorer leaderboards, goal analysis
-- Uses EXPLODE to turn arrays into rows, regex to parse player/minute

WITH home_goals AS (
    SELECT
        match_id,
        home_team_id AS team_id,
        home_team_name AS team_name,
        'home' AS team_location,
        EXPLODE(FROM_JSON(home_scorers, 'ARRAY<STRING>')) AS goal_string
    FROM {{ source('bronze', 'matches') }}
    WHERE home_scorers IS NOT NULL 
      AND home_scorers != '[]'
      AND home_scorers != 'null'
),

away_goals AS (
    SELECT
        match_id,
        away_team_id AS team_id,
        away_team_name AS team_name,
        'away' AS team_location,
        EXPLODE(FROM_JSON(away_scorers, 'ARRAY<STRING>')) AS goal_string
    FROM {{ source('bronze', 'matches') }}
    WHERE away_scorers IS NOT NULL 
      AND away_scorers != '[]'
      AND away_scorers != 'null'
),

all_goals AS (
    SELECT * FROM home_goals
    UNION ALL
    SELECT * FROM away_goals
),

parsed_goals AS (
    SELECT
        match_id,
        team_id,
        team_name,
        team_location,
        goal_string,
        
        -- Parse player name (everything before the minute marker)
        TRIM(REGEXP_EXTRACT(goal_string, '^([^0-9]+)', 1)) AS scorer_name,
        
        -- Parse minute (digits before the apostrophe)
        CAST(REGEXP_EXTRACT(goal_string, "([0-9]+)'", 1) AS INT) AS minute,
        
        -- Detect penalty goals (indicated by (p) suffix)
        CASE 
            WHEN goal_string LIKE '%(p)%' THEN TRUE 
            ELSE FALSE 
        END AS is_penalty,
        
        -- Determine if home or away goal
        CASE 
            WHEN team_location = 'home' THEN TRUE 
            ELSE FALSE 
        END AS is_home_goal
        
    FROM all_goals
    WHERE goal_string IS NOT NULL
      AND TRIM(goal_string) != ''
)

SELECT
    -- Generate unique goal event ID
    MD5(CONCAT(match_id, team_id, minute, scorer_name)) AS goal_event_id,
    
    match_id,
    team_id,
    team_name,
    scorer_name,
    minute,
    is_penalty,
    is_home_goal,
    
    -- Original string for debugging/reference
    goal_string AS goal_string_raw,
    
    CURRENT_TIMESTAMP() AS ingested_at
    
FROM parsed_goals
ORDER BY match_id, minute
{{config(
    materialized='table',
    tags=['fact', 'events', 'goals']
)}}

-- Parse goal events from scorer strings into normalized event records

WITH home_goals AS (
    SELECT
        match_id,
        home_team_id AS team_id,
        home_team_name AS team_name,
        EXPLODE(
            FROM_JSON(
                REGEXP_REPLACE(REGEXP_REPLACE(home_scorers, '\\{', '['), '\\}', ']'),
                'ARRAY<STRING>'
            )
        ) AS goal_string
    FROM {{ source('bronze', 'matches') }}
    WHERE home_scorers IS NOT NULL 
      AND home_scorers != 'null'
      AND LENGTH(home_scorers) > 5
),

away_goals AS (
    SELECT
        match_id,
        away_team_id AS team_id,
        away_team_name AS team_name,
        EXPLODE(
            FROM_JSON(
                REGEXP_REPLACE(REGEXP_REPLACE(away_scorers, '\\{', '['), '\\}', ']'),
                'ARRAY<STRING>'
            )
        ) AS goal_string
    FROM {{ source('bronze', 'matches') }}
    WHERE away_scorers IS NOT NULL 
      AND away_scorers != 'null'
      AND LENGTH(away_scorers) > 5
),

all_goals AS (
    SELECT * FROM home_goals
    UNION ALL
    SELECT * FROM away_goals
)

SELECT
    MD5(CONCAT(match_id, team_id, goal_string)) AS goal_event_id,
    match_id,
    team_id,
    team_name,
    
    -- Parse player name
    TRIM(REGEXP_EXTRACT(goal_string, '^([^0-9]+)', 1)) AS scorer_name,
    
    -- Parse minute
    CAST(REGEXP_EXTRACT(goal_string, "([0-9]+)'", 1) AS INT) AS minute,
    
    -- Detect penalty
    CASE WHEN goal_string LIKE '%(p)%' THEN TRUE ELSE FALSE END AS is_penalty,
    
    goal_string AS goal_string_raw,
    CURRENT_TIMESTAMP() AS ingested_at
    
FROM all_goals
WHERE goal_string IS NOT NULL
  AND TRIM(goal_string) != ''
ORDER BY match_id, minute
{{config(
    materialized='table',
    tags=['silver','fact', 'events', 'goals']
)}}

-- Parse goal events from scorer strings into normalized event records
-- IMPORTANT: Join by team_name to get correct team_id from silver_teams
-- because bronze.matches (worldcup26.ir) and bronze.teams (SportScore)
-- use different team_id numbering schemes!

WITH home_goals AS (
    SELECT
        match_id,
        home_team_name AS team_name,
        TRUE AS is_home_goal,
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
        away_team_name AS team_name,
        FALSE AS is_home_goal,
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
),

-- Team name normalization mapping (case-insensitive)
-- worldcup26.ir API uses different names than SportScore API
team_name_mapping AS (
    SELECT UPPER('Cape Verde') AS source_name, UPPER('Cabo Verde') AS target_name UNION ALL
    SELECT UPPER('Curaçao'), UPPER('Curacao') UNION ALL
    SELECT UPPER('Czech Republic'), UPPER('Czechia') UNION ALL
    SELECT UPPER('Iran'), UPPER('IR Iran') UNION ALL
    SELECT UPPER('Ivory Coast'), UPPER("Cote d'Ivoire") UNION ALL
    SELECT UPPER('Turkey'), UPPER('Turkiye') UNION ALL
    SELECT UPPER('United States'), UPPER('USA')
),

all_goals_normalized AS (
    SELECT 
        ag.match_id,
        COALESCE(tnm.target_name, UPPER(ag.team_name)) AS team_name_upper,  -- Normalized uppercase name
        ag.team_name AS team_name_original,  -- Keep original for display
        ag.is_home_goal,
        ag.goal_string
    FROM all_goals ag
    LEFT JOIN team_name_mapping tnm ON UPPER(ag.team_name) = tnm.source_name
)

SELECT
    MD5(CONCAT(ag.match_id, COALESCE(t.team_id, 'UNKNOWN'), ag.goal_string)) AS goal_event_id,
    ag.match_id,
    t.team_id,  -- Correct team_id from silver_teams
    ag.team_name_original AS team_name,  -- Use original case for display
    
    -- Parse player name (everything before the minute)
    TRIM(REGEXP_EXTRACT(ag.goal_string, '^([^0-9]+)', 1)) AS scorer_name,
    
    -- Parse full minute string (extract numbers+plus, then append apostrophe)
    CONCAT(REGEXP_EXTRACT(ag.goal_string, '([0-9]+(?:\\+[0-9]+)?)', 1), '''') AS minute,
    
    -- Parse base minute as integer (for sorting/filtering)
    TRY_CAST(NULLIF(REGEXP_EXTRACT(ag.goal_string, '([0-9]+)', 1), '') AS INT) AS minute_base,
    
    -- Parse injury time minutes (NULL if no injury time)
    TRY_CAST(NULLIF(REGEXP_EXTRACT(ag.goal_string, '\\+([0-9]+)', 1), '') AS INT) AS injury_time_minutes,
    
    -- Detect penalty
    CASE WHEN ag.goal_string LIKE '%(p)%' THEN TRUE ELSE FALSE END AS is_penalty,
    
    -- Home/Away flag (already set in CTEs above)
    ag.is_home_goal,
    
    ag.goal_string AS goal_string_raw,
    CURRENT_TIMESTAMP() AS ingested_at
    
FROM all_goals_normalized ag
-- Join to silver_teams by UPPERCASE team_name (case-insensitive)
-- (bronze.matches and bronze.teams use different ID schemes)
LEFT JOIN {{ ref('silver_teams') }} t
    ON ag.team_name_upper = UPPER(t.team_name)
WHERE ag.goal_string IS NOT NULL
  AND TRIM(ag.goal_string) != ''
ORDER BY ag.match_id, minute_base, injury_time_minutes

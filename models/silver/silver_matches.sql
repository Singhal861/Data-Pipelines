{{config(
    materialized='table',
    tags=['silver','fact', 'matches']
)}}

-- All 104 World Cup matches unified: group stage + knockout stage
-- Single source of truth for match facts

WITH group_matches AS (
    SELECT
        match_id,
        home_team_id,
        away_team_id,
        
        -- Normalize team names to match silver_teams
        CASE 
            WHEN home_team_name = 'United States' THEN 'USA'
            WHEN home_team_name = "Ivory Coast" THEN "Cote d'Ivoire"
            When home_team_name = 'Cape Verde' THEN 'Cabo Verde'    
            ELSE home_team_name
        END AS home_team_name,
        
        CASE 
            WHEN away_team_name = 'United States' THEN 'USA'
            WHEN away_team_name = "Ivory Coast" THEN "Cote d'Ivoire"
            When away_team_name = 'Cape Verde' THEN 'Cabo Verde'
            ELSE away_team_name
        END AS away_team_name,
        
        CAST(home_score AS INT) AS home_score,
        CAST(away_score AS INT) AS away_score,
        home_scorers,
        away_scorers,
        `group` AS group_name,
        matchday,
        'Group Stage' AS stage,
        local_date AS match_date_local,
        stadium_id,
        
        -- finished is STRING "TRUE"/"FALSE" in bronze.matches
        CASE 
            WHEN UPPER(finished) = 'TRUE' THEN TRUE
            ELSE FALSE
        END AS is_finished,
        
        -- Calculate winner for group matches (no penalties here, only knockouts)
        CASE
            WHEN UPPER(finished) = 'TRUE' AND home_score > away_score THEN 
                CASE 
                    WHEN home_team_name = 'United States' THEN 'USA'
                    WHEN home_team_name = "Ivory Coast" THEN "Cote d'Ivoire"
                    When home_team_name = 'Cape Verde' THEN 'Cabo Verde'    
                    ELSE home_team_name
                END
            WHEN UPPER(finished) = 'TRUE' AND away_score > home_score THEN 
                CASE 
                    WHEN away_team_name = 'United States' THEN 'USA'
                    WHEN away_team_name = "Ivory Coast" THEN "Cote d'Ivoire"
                    When away_team_name = 'Cape Verde' THEN 'Cabo Verde'
                    ELSE away_team_name
                END
            WHEN UPPER(finished) = 'TRUE' AND home_score = away_score THEN 'Draw'
            ELSE NULL
        END AS winner_team,
        
        CASE
            WHEN UPPER(finished) = 'TRUE' AND home_score > away_score THEN home_team_id
            WHEN UPPER(finished) = 'TRUE' AND away_score > home_score THEN away_team_id
            ELSE NULL
        END AS winner_team_id,
        
        NULL AS loser_team,
        NULL AS bracket_position,
        ingested_at
        
    FROM {{ source('bronze', 'matches') }}
    WHERE match_type = 'group'
),

knockout_matches AS (
    SELECT
        match_id,
        home_team_id,
        away_team_id,
        
        -- Normalize team names to match silver_teams
        CASE 
            WHEN home_team = 'United States' THEN 'USA'
            WHEN home_team = "Ivory Coast" THEN "Cote d'Ivoire"
            When home_team = 'Cape Verde' THEN 'Cabo Verde'
            ELSE home_team
        END AS home_team_name,
        
        CASE 
            WHEN away_team = 'United States' THEN 'USA'
            WHEN away_team = "Ivory Coast" THEN "Cote d'Ivoire"
            When away_team = 'Cape Verde' THEN 'Cabo Verde'
            ELSE away_team
        END AS away_team_name,
        
        home_score,
        away_score,
        home_scorers,
        away_scorers,
        NULL AS group_name,
        NULL AS matchday,
        
        -- Normalize round codes to readable stage names
        CASE
            WHEN UPPER(round) = 'R32' THEN 'Round of 32'
            WHEN UPPER(round) = 'R16' THEN 'Round of 16'
            WHEN UPPER(round) = 'QF' THEN 'Quarter Final'
            WHEN UPPER(round) = 'SF' THEN 'Semi Final'
            WHEN UPPER(round) = 'FINAL' THEN 'Final'
            WHEN UPPER(round) = '3RD' THEN 'Third Place'
            ELSE round
        END AS stage,
        
        match_date_local,
        stadium_id,
        is_finished,  -- Already boolean in bronze.knockout_bracket
        
        -- Normalize winner/loser team names
        CASE 
            WHEN winner_team = 'United States' THEN 'USA'
            WHEN winner_team = "Ivory Coast" THEN "Cote d'Ivoire"
            WHEN winner_team = 'Cape Verde' THEN 'Cabo Verde'
            ELSE winner_team
        END AS winner_team,
        
        winner_team_id,
        
        CASE 
            WHEN loser_team = 'United States' THEN 'USA'
            WHEN loser_team = "Ivory Coast" THEN "Cote d'Ivoire"
            WHEN loser_team = 'Cape Verde' THEN 'Cabo Verde'
            ELSE loser_team
        END AS loser_team,
        
        bracket_position,
        ingested_at
        
    FROM {{ source('bronze', 'knockout_bracket') }}
)

SELECT * FROM group_matches
UNION ALL
SELECT * FROM knockout_matches
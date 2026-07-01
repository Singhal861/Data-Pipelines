-- Test: Current stats should match bronze source
-- Validates the transformation logic

WITH silver_current AS (
    SELECT 
        player_id,
        goals_scored,
        assists,
        matches_played,
        rating_cumulative
    FROM {{ ref('silver_player_stats_history') }}
    WHERE is_current = TRUE
),

bronze_latest AS (
    SELECT 
        CAST(player_id AS STRING) AS player_id,
        CAST(goals_scored AS INT) AS goals_scored,
        CAST(assists AS INT) AS assists,
        CAST(matches_played AS INT) AS matches_played,
        CAST(rating AS BIGINT) AS rating_cumulative
    FROM {{ source('bronze', 'players') }}
    WHERE player_id IS NOT NULL 
      AND TRIM(player_id) != ''
    QUALIFY ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY ingested_at DESC) = 1
)

SELECT 
    s.player_id,
    s.goals_scored AS silver_goals,
    b.goals_scored AS bronze_goals,
    s.assists AS silver_assists,
    b.assists AS bronze_assists,
    s.matches_played AS silver_matches,
    b.matches_played AS bronze_matches,
    'Silver stats do not match bronze source' AS error_message
FROM silver_current s
JOIN bronze_latest b ON s.player_id = b.player_id
WHERE s.goals_scored != b.goals_scored
   OR s.assists != b.assists
   OR s.matches_played != b.matches_played
   OR s.rating_cumulative != b.rating_cumulative
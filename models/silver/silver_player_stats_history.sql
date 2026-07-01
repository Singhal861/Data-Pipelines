{{config(
    materialized='incremental',
    unique_key=['player_id', 'valid_from'],
    tags=['scd_type_2', 'history']
)}}

-- Player stats history with CHANGE DETECTION
-- Only inserts new snapshots when stats actually change
-- Prevents duplicate rows from hourly API refreshes with no matches

WITH latest_bronze AS (
    SELECT
        CAST(player_id AS STRING) AS player_id,
        CAST(goals_scored AS INT) AS goals_scored,
        CAST(assists AS INT) AS assists,
        CAST(matches_played AS INT) AS matches_played,
        CAST(minutes_played AS INT) AS minutes_played,
        CAST(rating AS BIGINT) AS rating_cumulative,
        
        -- Normalize rating to 0-10 scale
        -- Formula: (cumulative_rating / matches_played) / 100
        CASE 
            WHEN matches_played > 0 THEN ROUND((rating / matches_played) / 100.0, 2)
            ELSE NULL
        END AS rating_0_to_10,
        
        ingested_at AS valid_from
        
    FROM {{ source('bronze', 'players') }}
    WHERE player_id IS NOT NULL           -- ← ADD THESE 3 LINES
      AND TRIM(player_id) != ''
      AND player_id != 'null'
    -- Always get latest snapshot from bronze
    QUALIFY ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY ingested_at DESC) = 1
)

{% if is_incremental() %}

, latest_history AS (
    SELECT 
        player_id,
        goals_scored,
        assists,
        matches_played,
        minutes_played,
        rating_cumulative,
        rating_0_to_10
    FROM {{ this }}
    WHERE is_current = TRUE
),

changed_records AS (
    -- Only keep records where stats CHANGED
    SELECT b.*
    FROM latest_bronze b
    LEFT JOIN latest_history h ON b.player_id = h.player_id
    WHERE h.player_id IS NULL  -- New player
       OR b.goals_scored != h.goals_scored
       OR b.assists != h.assists
       OR b.matches_played != h.matches_played
       OR b.rating_cumulative != h.rating_cumulative
)

SELECT
    player_id,
    goals_scored,
    assists,
    matches_played,
    minutes_played,
    rating_cumulative,
    rating_0_to_10,
    valid_from,
    NULL AS valid_to,
    TRUE AS is_current
FROM changed_records

{% else %}

-- First run: load all players
SELECT
    player_id,
    goals_scored,
    assists,
    matches_played,
    minutes_played,
    rating_cumulative,
    rating_0_to_10,
    valid_from,
    CAST(NULL AS TIMESTAMP) AS valid_to,
    TRUE AS is_current
FROM latest_bronze

{% endif %}
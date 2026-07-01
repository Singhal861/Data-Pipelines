{{config(
    materialized='table',
    tags=['dimension', 'scd_type_1']
)}}

-- Player dimension - static attributes only
-- SCD Type 1: overwrites on each run (latest snapshot only)
-- For stats progression, see silver_player_stats_history

SELECT
    CAST(player_id AS STRING) AS player_id,
    CAST(player_name AS STRING) AS player_name,
    CAST(team_id AS STRING) AS team_id,
    CAST(team_name AS STRING) AS team_name,
    CURRENT_TIMESTAMP() AS last_updated
    
FROM {{ source('bronze', 'players') }}
WHERE player_id IS NOT NULL           
  AND TRIM(player_id) != ''
  AND player_id != 'null'
  AND LENGTH(TRIM(player_id)) > 5
-- Deduplicate: keep latest record per player
QUALIFY ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY ingested_at DESC) = 1
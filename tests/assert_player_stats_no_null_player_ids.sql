-- Test: No NULL or empty player_ids should exist
-- Catches the "Unknown" player issue

SELECT 
    player_id,
    goals_scored,
    matches_played,
    valid_from,
    'NULL or empty player_id found' AS error_message
FROM {{ ref('silver_player_stats_history') }}
WHERE player_id IS NULL 
   OR TRIM(player_id) = ''
   OR player_id = 'null'
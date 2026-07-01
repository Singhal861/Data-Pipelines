-- Test: No duplicate current snapshots per player
-- Each player should have exactly ONE row where is_current = TRUE

WITH current_snapshots AS (
    SELECT 
        player_id,
        COUNT(*) AS current_count
    FROM {{ ref('silver_player_stats_history') }}
    WHERE is_current = TRUE
    GROUP BY player_id
    HAVING COUNT(*) > 1
)

SELECT 
    player_id,
    current_count,
    'Player has multiple current snapshots' AS error_message
FROM current_snapshots
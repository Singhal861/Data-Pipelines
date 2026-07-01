-- Test: Minutes played should be reasonable
-- Can't play more than 120 minutes per match (90 + 30 extra time)

SELECT 
    player_id,
    matches_played,
    minutes_played,
    ROUND(minutes_played / NULLIF(matches_played, 0), 1) AS avg_minutes_per_match,
    'Average minutes per match exceeds 120' AS error_message
FROM {{ ref('silver_player_stats_history') }}
WHERE is_current = TRUE
  AND matches_played > 0
  AND (minutes_played / matches_played) > 120
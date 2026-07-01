-- Test: Goals shouldn't be impossibly high
-- Max 5 goals per match is extreme (hat-trick+ every game)

SELECT 
    player_id,
    matches_played,
    goals_scored,
    ROUND(CAST(goals_scored AS DOUBLE) / NULLIF(matches_played, 0), 2) AS goals_per_match,
    'Goals per match ratio is unrealistic' AS error_message
FROM {{ ref('silver_player_stats_history') }}
WHERE is_current = TRUE
  AND matches_played > 0
  AND (CAST(goals_scored AS DOUBLE) / matches_played) > 5
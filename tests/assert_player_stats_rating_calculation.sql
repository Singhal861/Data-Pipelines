-- Test: rating_0_to_10 should be correctly calculated
-- Formula: (rating_cumulative / matches_played) / 100

WITH calculated_ratings AS (
    SELECT 
        player_id,
        rating_cumulative,
        matches_played,
        rating_0_to_10 AS stored_rating,
        CASE 
            WHEN matches_played > 0 
            THEN ROUND((rating_cumulative / matches_played) / 100.0, 2)
            ELSE NULL
        END AS expected_rating
    FROM {{ ref('silver_player_stats_history') }}
    WHERE is_current = TRUE
)

SELECT 
    player_id,
    rating_cumulative,
    matches_played,
    stored_rating,
    expected_rating,
    ABS(COALESCE(stored_rating, 0) - COALESCE(expected_rating, 0)) AS difference
FROM calculated_ratings
WHERE ABS(COALESCE(stored_rating, 0) - COALESCE(expected_rating, 0)) > 0.01
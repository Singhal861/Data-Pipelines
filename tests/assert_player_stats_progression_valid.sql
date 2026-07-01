-- Test: Stats should only increase over time (never decrease)
-- Goals/assists/matches can't go backwards

WITH player_snapshots AS (
    SELECT 
        player_id,
        goals_scored,
        assists,
        matches_played,
        valid_from,
        LAG(goals_scored) OVER (PARTITION BY player_id ORDER BY valid_from) AS prev_goals,
        LAG(assists) OVER (PARTITION BY player_id ORDER BY valid_from) AS prev_assists,
        LAG(matches_played) OVER (PARTITION BY player_id ORDER BY valid_from) AS prev_matches
    FROM {{ ref('silver_player_stats_history') }}
)

SELECT 
    player_id,
    valid_from,
    goals_scored,
    prev_goals,
    assists,
    prev_assists,
    matches_played,
    prev_matches,
    CASE
        WHEN goals_scored < prev_goals THEN 'Goals decreased'
        WHEN assists < prev_assists THEN 'Assists decreased'
        WHEN matches_played < prev_matches THEN 'Matches decreased'
    END AS error_type
FROM player_snapshots
WHERE (goals_scored < prev_goals 
    OR assists < prev_assists 
    OR matches_played < prev_matches)
  AND prev_goals IS NOT NULL
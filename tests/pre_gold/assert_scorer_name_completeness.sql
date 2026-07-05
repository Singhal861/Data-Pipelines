-- Pre-Gold Test: Scorer name completeness in goal_events
-- Fails if: Any finished match has goals with NULL or blank scorer_name
-- Purpose: Ensures gold layer can properly attribute goals to players
-- Critical for: gold_fact_match_schedule, gold_fact_team_performance (match-level top scorers)

SELECT 
    ge.match_id,
    m.home_team_name,
    m.away_team_name,
    m.stage,
    ge.team_name,
    ge.minute,
    ge.scorer_name,
    'Scorer name is NULL or empty in finished match' AS error_reason
FROM {{ ref('silver_goal_events') }} ge
JOIN {{ ref('silver_matches') }} m ON ge.match_id = m.match_id
WHERE m.is_finished = TRUE
  AND (ge.scorer_name IS NULL OR TRIM(ge.scorer_name) = '')

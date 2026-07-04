{{config(
    materialized='table',
    tags=['gold', 'dashboard', 'summary']
)}}

-- gold_tournament_summary: Tournament Header KPIs (Dashboard Header)

WITH match_stats AS (
    SELECT
        COUNT(*) AS total_matches,
        SUM(CASE WHEN is_finished = TRUE THEN 1 ELSE 0 END) AS completed_matches,
        SUM(CASE WHEN is_finished = FALSE THEN 1 ELSE 0 END) AS remaining_matches
    FROM {{ ref('silver_matches') }}
),

goal_stats AS (
    SELECT
        COUNT(*) AS total_goals,
        COUNT(CASE WHEN is_penalty = TRUE THEN 1 END) AS penalties_awarded
    FROM {{ ref('silver_goal_events') }}
),

top_scorer AS (
    SELECT
        p.player_name,
        psh.goals_scored,
        ROW_NUMBER() OVER (ORDER BY psh.goals_scored DESC) AS rn
    FROM {{ ref('silver_player_stats_history') }} psh
    JOIN {{ ref('silver_players') }} p ON psh.player_id = p.player_id
    WHERE psh.is_current = TRUE
),

current_round AS (
    SELECT
        stage AS current_round,
        ROW_NUMBER() OVER (ORDER BY 
            CASE stage
                WHEN 'Group Stage' THEN 1
                WHEN 'Round of 32' THEN 2
                WHEN 'Round of 16' THEN 3
                WHEN 'Quarter Final' THEN 4
                WHEN 'Semi Final' THEN 5
                WHEN 'Third Place' THEN 6
                WHEN 'Final' THEN 7
            END DESC
        ) AS rn
    FROM {{ ref('silver_matches') }}
    WHERE is_finished = FALSE
),

teams_remaining AS (
    SELECT
        COUNT(DISTINCT team_id) AS teams_remaining
    FROM (
        SELECT home_team_id AS team_id FROM {{ ref('silver_matches') }} WHERE is_finished = FALSE
        UNION
        SELECT away_team_id AS team_id FROM {{ ref('silver_matches') }} WHERE is_finished = FALSE
    )
)

SELECT
    'FIFA World Cup 2026' AS tournament_name,
    ms.total_matches,
    ms.completed_matches,
    ms.remaining_matches,
    gs.total_goals,
    ROUND(gs.total_goals / NULLIF(ms.completed_matches, 0), 2) AS avg_goals_per_match,
    cr.current_round,
    tr.teams_remaining,
    ts.player_name AS top_scorer_name,
    ts.goals_scored AS top_scorer_goals,
    gs.penalties_awarded,
    CURRENT_TIMESTAMP() AS last_updated
FROM match_stats ms
CROSS JOIN goal_stats gs
CROSS JOIN teams_remaining tr
LEFT JOIN top_scorer ts ON ts.rn = 1
LEFT JOIN current_round cr ON cr.rn = 1

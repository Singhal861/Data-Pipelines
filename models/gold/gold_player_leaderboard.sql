{{config(
    materialized='table',
    tags=['gold', 'dashboard', 'player']
)}}

-- gold_player_leaderboard: Top 10 Scorers with Spider Chart Data (Requirement #2)
-- Uses player + player_stats_history for ALL main stats (goals, assists, rating, matches, minutes)
-- Uses goal_events ONLY for "highest goals against team" stat (with fuzzy name matching)

WITH current_stats AS (
    SELECT
        ps.player_id,
        p.player_name,
        p.player_logo,  -- ✅ Player image URL
        p.team_id,
        p.team_name,
        ps.goals_scored,
        ps.assists,
        ps.matches_played,
        ps.minutes_played,
        ps.rating_0_to_10
    FROM {{ ref('silver_player_stats_history') }} ps
    JOIN {{ ref('silver_players') }} p ON ps.player_id = p.player_id
    WHERE ps.is_current = TRUE
      AND ps.goals_scored > 0  -- Only players who have scored
),

-- Get highest goals against a specific opponent from goal_events
-- Handle name inconsistencies with normalized matching
goals_by_opponent AS (
    SELECT
        ge.scorer_name,
        ge.team_name AS scorer_team,
        CASE 
            WHEN ge.is_home_goal THEN m.away_team_name
            ELSE m.home_team_name
        END AS opponent_team_name,
        COUNT(*) AS goals_against_team
    FROM {{ ref('silver_goal_events') }} ge
    JOIN {{ ref('silver_matches') }} m ON ge.match_id = m.match_id
    GROUP BY ge.scorer_name, ge.team_name, opponent_team_name
),

most_goals_against AS (
    SELECT
        scorer_name,
        scorer_team,
        opponent_team_name AS most_goals_against_team_name,
        goals_against_team AS most_goals_against_team_count,
        ROW_NUMBER() OVER (
            PARTITION BY scorer_name, scorer_team 
            ORDER BY goals_against_team DESC
        ) AS rn
    FROM goals_by_opponent
),

percentiles AS (
    SELECT
        player_id,
        goals_scored,
        assists,
        minutes_played,
        matches_played,
        PERCENT_RANK() OVER (ORDER BY goals_scored) * 100 AS goals_percentile,
        PERCENT_RANK() OVER (ORDER BY assists) * 100 AS assists_percentile,
        PERCENT_RANK() OVER (ORDER BY minutes_played) * 100 AS minutes_percentile,
        PERCENT_RANK() OVER (ORDER BY matches_played) * 100 AS matches_percentile
    FROM current_stats
),

base_leaderboard AS (
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY cs.goals_scored DESC, 
                     cs.assists DESC, 
                     cs.minutes_played ASC
        ) AS rank,
        cs.player_id,
        cs.player_name,
        cs.player_logo,  -- ✅ Player image URL
        cs.team_id,
        cs.team_name,
        t.team_logo,
        cs.goals_scored,
        cs.assists,
        cs.matches_played,
        cs.minutes_played,
        cs.rating_0_to_10,
        ROUND(p.goals_percentile, 0) AS goals_percentile,
        ROUND(p.assists_percentile, 0) AS assists_percentile,
        ROUND(p.minutes_percentile, 0) AS minutes_percentile,
        ROUND(p.matches_percentile, 0) AS matches_percentile,
        mga.most_goals_against_team_name,
        mga.most_goals_against_team_count,
        -- FIFA Golden Boot ranking with tiebreakers
        DENSE_RANK() OVER (
            ORDER BY 
                cs.goals_scored DESC,      -- Primary: Most goals
                cs.assists DESC,           -- Tiebreaker 1: Most assists
                cs.minutes_played ASC      -- Tiebreaker 2: Fewer minutes
        ) AS golden_boot_rank
    FROM current_stats cs
    LEFT JOIN {{ ref('silver_teams') }} t ON cs.team_id = t.team_id
    LEFT JOIN percentiles p ON cs.player_id = p.player_id
    LEFT JOIN most_goals_against mga 
        ON LOWER(TRIM(cs.player_name)) = LOWER(TRIM(mga.scorer_name))
        AND cs.team_name = mga.scorer_team
        AND mga.rn = 1
),

leader_goals AS (
    SELECT MAX(goals_scored) AS max_goals
    FROM base_leaderboard
)

SELECT
    bl.rank,
    bl.player_id,
    bl.player_name,
    bl.player_logo,  -- ✅ Player image URL
    bl.team_id,
    bl.team_name,
    bl.team_logo,
    bl.goals_scored,
    bl.assists,
    bl.matches_played,
    bl.minutes_played,
    bl.rating_0_to_10,
    bl.goals_percentile,
    bl.assists_percentile,
    bl.minutes_percentile,
    bl.matches_percentile,
    bl.most_goals_against_team_name,
    bl.most_goals_against_team_count,
    bl.golden_boot_rank,
    CASE WHEN bl.golden_boot_rank <= 3 THEN TRUE ELSE FALSE END AS is_top_3,
    lg.max_goals - bl.goals_scored AS goals_behind_leader,
    CURRENT_TIMESTAMP() AS last_updated
FROM base_leaderboard bl
CROSS JOIN leader_goals lg
WHERE bl.rank <= 10  -- Top 10 scorers only
ORDER BY rank

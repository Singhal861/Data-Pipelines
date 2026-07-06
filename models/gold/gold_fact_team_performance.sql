{{config(
    materialized='table',
    tags=['gold', 'dashboard', 'team', 'standings']
)}}

-- gold_fact_team_performance: Unified Team Performance & Standings (Requirements #5 + Flag Click)
-- Replaces: gold_points_table + gold_team_summary
-- Single source of truth for all team statistics

WITH all_matches AS (
    -- Aggregate match statistics per team (home + away)
    SELECT
        team_name,
        SUM(matches_played) AS total_matches,
        SUM(wins) AS total_wins,
        SUM(losses) AS total_losses,
        SUM(draws) AS total_draws,
        SUM(goals_for) AS goals_for,
        SUM(goals_against) AS goals_against
    FROM (
        -- Home matches
        SELECT
            home_team_name AS team_name,
            COUNT(*) AS matches_played,
            SUM(CASE WHEN home_score > away_score THEN 1 ELSE 0 END) AS wins,
            SUM(CASE WHEN home_score < away_score THEN 1 ELSE 0 END) AS losses,
            SUM(CASE WHEN home_score = away_score THEN 1 ELSE 0 END) AS draws,
            SUM(home_score) AS goals_for,
            SUM(away_score) AS goals_against
        FROM {{ ref('silver_matches') }}
        WHERE is_finished = TRUE
        GROUP BY home_team_name
        
        UNION ALL
        
        -- Away matches
        SELECT
            away_team_name AS team_name,
            COUNT(*) AS matches_played,
            SUM(CASE WHEN away_score > home_score THEN 1 ELSE 0 END) AS wins,
            SUM(CASE WHEN away_score < home_score THEN 1 ELSE 0 END) AS losses,
            SUM(CASE WHEN away_score = home_score THEN 1 ELSE 0 END) AS draws,
            SUM(away_score) AS goals_for,
            SUM(home_score) AS goals_against
        FROM {{ ref('silver_matches') }}
        WHERE is_finished = TRUE
        GROUP BY away_team_name
    )
    GROUP BY team_name
),

group_stage_stats AS (
    -- Group stage specific statistics from silver_group_standings
    SELECT
        t.team_name,
        gs.group_name,
        gs.rank AS rank_in_group,
        gs.matches_played AS group_matches_played,
        gs.wins AS group_wins,
        gs.draws AS group_draws,
        gs.losses AS group_losses,
        gs.goals_for AS group_goals_for,
        gs.goals_against AS group_goals_against,
        gs.goal_difference AS group_goal_difference,
        gs.points AS group_points
    FROM {{ ref('silver_group_standings') }} gs
    JOIN {{ ref('silver_teams') }} t ON gs.team_name = t.team_name
),

current_stage AS (
    -- ✅ FIXED: Get actual stage from latest match (not estimated by counting)
    SELECT
        team_name,
        stage
    FROM (
        SELECT 
            team_name,
            stage,
            match_date_local,
            ROW_NUMBER() OVER (PARTITION BY team_name ORDER BY match_date_local DESC) as rn
        FROM (
            SELECT home_team_name as team_name, stage, match_date_local
            FROM {{ ref('silver_matches') }}
            WHERE is_finished = TRUE
            UNION ALL
            SELECT away_team_name as team_name, stage, match_date_local
            FROM {{ ref('silver_matches') }}
            WHERE is_finished = TRUE
        )
    )
    WHERE rn = 1
),

top_scorers AS (
    -- ✅ NEW: Top goal scorer per team with goal count
    SELECT
        t.team_name,
        p.player_name AS top_scorer_name,
        COUNT(ge.goal_event_id) AS top_scorer_goals,
        ROW_NUMBER() OVER (PARTITION BY t.team_name ORDER BY COUNT(ge.goal_event_id) DESC) AS scorer_rank
    FROM {{ ref('silver_goal_events') }} ge
    JOIN {{ ref('silver_players') }} p ON ge.scorer_name = p.player_name
    JOIN {{ ref('silver_teams') }} t ON p.team_name = t.team_name
    GROUP BY t.team_name, p.player_name
),

top_assisters AS (
    -- Top assist provider per team
    SELECT
        t.team_name,
        p.player_name AS assist_provider,
        psh.assists AS assist_count,
        ROW_NUMBER() OVER (PARTITION BY t.team_name ORDER BY psh.assists DESC) AS assist_rank
    FROM {{ ref('silver_player_stats_history') }} psh
    JOIN {{ ref('silver_players') }} p ON psh.player_id = p.player_id
    JOIN {{ ref('silver_teams') }} t ON p.team_name = t.team_name
    WHERE psh.is_current = TRUE
),

clean_sheets_calc AS (
    -- ✅ NEW: Matches with 0 goals conceded
    SELECT
        team_name,
        SUM(CASE WHEN goals_against_in_match = 0 THEN 1 ELSE 0 END) AS clean_sheets
    FROM (
        SELECT home_team_name AS team_name, away_score AS goals_against_in_match
        FROM {{ ref('silver_matches') }}
        WHERE is_finished = TRUE
        UNION ALL
        SELECT away_team_name AS team_name, home_score AS goals_against_in_match
        FROM {{ ref('silver_matches') }}
        WHERE is_finished = TRUE
    )
    GROUP BY team_name
)

SELECT
    -- Team identity
    t.team_name,
    t.team_logo,
    COALESCE(gss.group_name, t.group_name) AS group_name,
    
    -- ✅ Group stage rankings (from silver_group_standings)
    ROW_NUMBER() OVER (ORDER BY COALESCE(gss.group_points, 0) DESC, 
                               COALESCE(am.goals_for, 0) - COALESCE(am.goals_against, 0) DESC,
                               COALESCE(am.goals_for, 0) DESC) AS rank_overall,
    gss.rank_in_group,
    
    -- Match statistics (tournament-wide from all_matches)
    COALESCE(am.total_matches, 0) AS total_matches,
    COALESCE(am.total_wins, 0) AS total_wins,
    COALESCE(am.total_losses, 0) AS total_losses,
    COALESCE(am.total_draws, 0) AS total_draws,
    
    -- Group stage specific stats (for points table display)
    COALESCE(gss.group_matches_played, 0) AS group_matches_played,
    COALESCE(gss.group_wins, 0) AS group_wins,
    COALESCE(gss.group_draws, 0) AS group_draws,
    COALESCE(gss.group_losses, 0) AS group_losses,
    
    -- Goals
    COALESCE(am.goals_for, 0) AS goals_for,
    COALESCE(am.goals_against, 0) AS goals_against,
    COALESCE(am.goals_for, 0) - COALESCE(am.goals_against, 0) AS goal_difference,
    
    -- Group stage specific goals (for points table)
    COALESCE(gss.group_goals_for, 0) AS group_goals_for,
    COALESCE(gss.group_goals_against, 0) AS group_goals_against,
    COALESCE(gss.group_goal_difference, 0) AS group_goal_difference,
    
    -- Points (from group stage)
    COALESCE(gss.group_points, 0) AS total_points,
    
    -- ✅ FIXED: Current stage (from actual match data, not estimated)
    COALESCE(cs.stage, 'Group Stage') AS current_stage,
    
    -- Qualification status (based on group rank)
    CASE
        WHEN gss.rank_in_group <= 2 THEN 'Qualified'
        WHEN gss.rank_in_group > 2 AND gss.group_matches_played = 3 THEN 'Disqualified'
        WHEN am.total_matches > 3 THEN 'Qualified'
        WHEN am.total_matches IS NULL THEN 'Not Started'
        ELSE 'In Progress'
    END AS qualification_status,
    
    -- ✅ Performance metrics
    CASE 
        WHEN am.total_matches > 0 
        THEN ROUND((am.total_wins * 100.0) / am.total_matches, 1)
        ELSE 0 
    END AS win_percentage,
    
    COALESCE(cs_calc.clean_sheets, 0) AS clean_sheets,
    
    CASE 
        WHEN am.total_matches > 0 
        THEN ROUND(am.goals_for * 1.0 / am.total_matches, 2)
        ELSE 0 
    END AS avg_goals_per_match,
    
    -- ✅ NEW: Top performers
    ts.top_scorer_name,
    ts.top_scorer_goals,
    ta.assist_provider AS top_assist_provider,
    ta.assist_count AS top_assist_count,
    
    CURRENT_TIMESTAMP() AS last_updated
    
FROM {{ ref('silver_teams') }} t
LEFT JOIN all_matches am ON t.team_name = am.team_name
LEFT JOIN group_stage_stats gss ON t.team_name = gss.team_name
LEFT JOIN current_stage cs ON t.team_name = cs.team_name
LEFT JOIN top_scorers ts ON t.team_name = ts.team_name AND ts.scorer_rank = 1
LEFT JOIN top_assisters ta ON t.team_name = ta.team_name AND ta.assist_rank = 1
LEFT JOIN clean_sheets_calc cs_calc ON t.team_name = cs_calc.team_name
ORDER BY rank_overall

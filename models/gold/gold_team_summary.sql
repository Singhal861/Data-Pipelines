{{config(
    materialized='table',
    tags=['gold', 'dashboard', 'team']
)}}

-- gold_team_summary: Team Stats for Flag Click Drill-down (Requirements #1, #5)
-- Use gold_team_goals for match-level goal details instead

WITH all_matches AS (
    SELECT
        team_id,
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
            home_team_id AS team_id,
            home_team_name AS team_name,
            COUNT(*) AS matches_played,
            SUM(CASE WHEN home_score > away_score THEN 1 ELSE 0 END) AS wins,
            SUM(CASE WHEN home_score < away_score THEN 1 ELSE 0 END) AS losses,
            SUM(CASE WHEN home_score = away_score THEN 1 ELSE 0 END) AS draws,
            SUM(home_score) AS goals_for,
            SUM(away_score) AS goals_against
        FROM {{ ref('silver_matches') }}
        WHERE is_finished = TRUE
        GROUP BY home_team_id, home_team_name
        
        UNION ALL
        
        -- Away matches
        SELECT
            away_team_id AS team_id,
            away_team_name AS team_name,
            COUNT(*) AS matches_played,
            SUM(CASE WHEN away_score > home_score THEN 1 ELSE 0 END) AS wins,
            SUM(CASE WHEN away_score < home_score THEN 1 ELSE 0 END) AS losses,
            SUM(CASE WHEN away_score = home_score THEN 1 ELSE 0 END) AS draws,
            SUM(away_score) AS goals_for,
            SUM(home_score) AS goals_against
        FROM {{ ref('silver_matches') }}
        WHERE is_finished = TRUE
        GROUP BY away_team_id, away_team_name
    )
    GROUP BY team_id, team_name
),

group_stage_points AS (
    SELECT
        team_id,
        points AS total_points
    FROM {{ ref('silver_group_standings') }}
),

top_assisters AS (
    SELECT
        p.team_id,
        p.player_name AS assist_provider,
        psh.assists,
        ROW_NUMBER() OVER (PARTITION BY p.team_id ORDER BY psh.assists DESC) AS assist_rank
    FROM {{ ref('silver_player_stats_history') }} psh
    JOIN {{ ref('silver_players') }} p ON psh.player_id = p.player_id
    WHERE psh.is_current = TRUE
),

clean_sheets_calc AS (
    SELECT
        team_id,
        SUM(CASE WHEN goals_against_in_match = 0 THEN 1 ELSE 0 END) AS clean_sheets
    FROM (
        SELECT home_team_id AS team_id, away_score AS goals_against_in_match
        FROM {{ ref('silver_matches') }}
        WHERE is_finished = TRUE
        UNION ALL
        SELECT away_team_id AS team_id, home_score AS goals_against_in_match
        FROM {{ ref('silver_matches') }}
        WHERE is_finished = TRUE
    )
    GROUP BY team_id
)

SELECT
    t.team_id,
    t.team_name,
    t.team_logo,
    t.group_name,
    COALESCE(am.total_matches, 0) AS total_matches,
    COALESCE(am.total_wins, 0) AS total_wins,
    COALESCE(am.total_losses, 0) AS total_losses,
    COALESCE(am.total_draws, 0) AS total_draws,
    COALESCE(am.goals_for, 0) AS goals_for,
    COALESCE(am.goals_against, 0) AS goals_against,
    COALESCE(am.goals_for, 0) - COALESCE(am.goals_against, 0) AS goal_difference,
    COALESCE(gsp.total_points, 0) AS total_points,
    
    -- Win percentage
    CASE 
        WHEN am.total_matches > 0 
        THEN ROUND((am.total_wins * 100.0) / am.total_matches, 1)
        ELSE 0 
    END AS win_percentage,
    
    -- Qualification status
    CASE
        WHEN am.total_matches > 3 THEN 'Qualified'
        WHEN am.total_matches = 3 AND am.total_wins + am.total_draws < 2 THEN 'Disqualified'
        WHEN am.total_matches IS NULL THEN 'Not Started'
        ELSE 'In Progress'
    END AS qualification_status,
    
    -- Current stage
    CASE
        WHEN am.total_matches >= 7 THEN 'Final'
        WHEN am.total_matches >= 6 THEN 'Semi Final'
        WHEN am.total_matches >= 5 THEN 'Quarter Final'
        WHEN am.total_matches >= 4 THEN 'Round of 16'
        WHEN am.total_matches > 3 THEN 'Round of 32'
        WHEN am.total_matches IS NULL THEN 'Not Started'
        ELSE 'Group Stage'
    END AS current_stage,
    
    -- Top assist provider (from player_stats_history joined with players for name)
    ta.assist_provider AS top_assist_provider,
    ta.assists AS top_assist_count,
    
    -- Clean sheets
    COALESCE(cs.clean_sheets, 0) AS clean_sheets,
    
    -- Average goals per match
    CASE 
        WHEN am.total_matches > 0 
        THEN ROUND(am.goals_for * 1.0 / am.total_matches, 2)
        ELSE 0 
    END AS avg_goals_per_match,
    
    CURRENT_TIMESTAMP() AS last_updated
    
FROM {{ ref('silver_teams') }} t
LEFT JOIN all_matches am ON t.team_id = am.team_id
LEFT JOIN group_stage_points gsp ON t.team_id = gsp.team_id
LEFT JOIN top_assisters ta ON t.team_id = ta.team_id AND ta.assist_rank = 1
LEFT JOIN clean_sheets_calc cs ON t.team_id = cs.team_id
ORDER BY total_points DESC, goal_difference DESC, goals_for DESC

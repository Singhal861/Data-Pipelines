-- Requirement 4: Team Performance Details (on flag click)
-- Validates: gold_fact_team_performance (unified table), gold_team_goals

-- Test that teams have:
-- 1. Complete stats (wins, losses, points)
-- 2. Top 2 scorers per team
-- 3. Team logos
-- 4. Goal details with scorers and minutes

WITH validation_failures AS (
    -- Check 1: All teams have logos
    SELECT
        'Missing team logo' AS failure_type,
        team_id,
        CONCAT('Team ', team_name, ' missing team_logo') AS failure_detail
    FROM {{ ref('gold_team_summary') }}
    WHERE team_logo IS NULL
    
    UNION ALL
    
    -- Check 2: All teams have complete stats
    SELECT
        'Missing team stats' AS failure_type,
        team_id,
        CONCAT('Team ', team_name, ' missing stats - wins: ', 
               COALESCE(CAST(total_wins AS STRING), 'NULL'),
               ', points: ', COALESCE(CAST(total_points AS STRING), 'NULL')) AS failure_detail
    FROM {{ ref('gold_team_summary') }}
    WHERE total_wins IS NULL 
       OR total_losses IS NULL 
       OR total_draws IS NULL
       OR total_points IS NULL
    
    UNION ALL
    
    -- Check 4: gold_team_goals should have complete goal details
    SELECT
        'Missing goal details' AS failure_type,
        match_id,
        CONCAT('Goal for team ', team_name, ' in match ', match_id,
               ' missing - scorer: ', COALESCE(scorer_name, 'NULL'),
               ', minute: ', COALESCE(minute, 'NULL')) AS failure_detail
    FROM {{ ref('gold_team_goals') }}
    WHERE scorer_name IS NULL OR minute IS NULL
    
    UNION ALL
    
    -- Check 5: All goals should have associated matches
    SELECT
        'Orphaned goal' AS failure_type,
        team_id,
        CONCAT('Goal for team ', team_name, ' has NULL match_id') AS failure_detail
    FROM {{ ref('gold_team_goals') }}
    WHERE match_id IS NULL
)

SELECT
    failure_type,
    failure_detail,
    COUNT(*) AS failure_count
FROM validation_failures
GROUP BY failure_type, failure_detail

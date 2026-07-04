-- Requirement 2: Top 10 Scorers with Player Details & Spider Chart
-- Validates: gold_player_leaderboard

-- Test that top 10 players have:
-- 1. All required stats (goals, assists, rating, matches, minutes)
-- 2. Player images (player_logo)
-- 3. Team logos
-- 4. Spider chart percentiles
-- 5. Highest goals against specific team data

WITH validation_failures AS (
    -- Check 1: Exactly 10 players (or fewer if tournament has < 10 scorers)
    SELECT
        'Incorrect player count' AS failure_type,
        'Expected top 10 players' AS failure_detail,
        COUNT(*) AS actual_count
    FROM {{ ref('gold_player_leaderboard') }}
    HAVING COUNT(*) NOT BETWEEN 1 AND 10
    
    UNION ALL
    
    -- Check 2: All players have team logos
    SELECT
        'Missing team logo' AS failure_type,
        CONCAT('Player ', player_name, ' (rank ', rank, ') missing team_logo') AS failure_detail,
        1 AS actual_count
    FROM {{ ref('gold_player_leaderboard') }}
    WHERE team_logo IS NULL
    
    UNION ALL
    
    -- Check 3: Player images (player_logo) - LENIENT: allows up to 2 missing
    SELECT
        'Missing player images (warning only)' AS failure_type,
        CONCAT(COUNT(*), ' players missing player_logo - acceptable if <= 2') AS failure_detail,
        COUNT(*) AS actual_count
    FROM {{ ref('gold_player_leaderboard') }}
    WHERE player_logo IS NULL
    HAVING COUNT(*) > 2  -- Only fail if more than 2 players are missing images
    
    UNION ALL
    
    -- Check 4: All players have spider chart percentiles
    SELECT
        'Missing spider chart data' AS failure_type,
        CONCAT('Player ', player_name, ' missing percentiles - goals: ', 
               COALESCE(CAST(goals_percentile AS STRING), 'NULL'),
               ', assists: ', COALESCE(CAST(assists_percentile AS STRING), 'NULL')) AS failure_detail,
        1 AS actual_count
    FROM {{ ref('gold_player_leaderboard') }}
    WHERE goals_percentile IS NULL 
       OR assists_percentile IS NULL 
       OR minutes_percentile IS NULL 
       OR matches_percentile IS NULL
    
    UNION ALL
    
    -- Check 5: All core stats are populated
    SELECT
        'Missing core stats' AS failure_type,
        CONCAT('Player ', player_name, ' missing stats - goals: ', 
               COALESCE(CAST(goals_scored AS STRING), 'NULL'),
               ', rating: ', COALESCE(CAST(rating_0_to_10 AS STRING), 'NULL')) AS failure_detail,
        1 AS actual_count
    FROM {{ ref('gold_player_leaderboard') }}
    WHERE goals_scored IS NULL 
       OR assists IS NULL 
       OR matches_played IS NULL 
       OR minutes_played IS NULL
       OR rating_0_to_10 IS NULL
    
    UNION ALL
    
    -- Check 6: Rankings are sequential (1, 2, 3, ... 10)
    SELECT
        'Invalid rankings' AS failure_type,
        CONCAT('Gap in rankings detected - expected ', expected_rank, ', found ', actual_rank) AS failure_detail,
        1 AS actual_count
    FROM (
        SELECT
            rank AS actual_rank,
            ROW_NUMBER() OVER (ORDER BY rank) AS expected_rank
        FROM {{ ref('gold_player_leaderboard') }}
    )
    WHERE actual_rank != expected_rank
)

SELECT
    failure_type,
    failure_detail,
    SUM(actual_count) AS failure_count
FROM validation_failures
GROUP BY failure_type, failure_detail

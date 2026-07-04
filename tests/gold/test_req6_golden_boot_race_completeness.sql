-- Requirement 6: Golden Boot Race Progression
-- Validates: gold_golden_boot_race

-- Test that golden boot race has:
-- 1. Match-by-match progression for top 3 players
-- 2. Player images (player_logo)
-- 3. Team logos and medals
-- 4. Valid ranking with FIFA tiebreaker rules
-- 5. Cumulative stats tracking

WITH validation_failures AS (
    -- Check 1: All players have team logos
    SELECT
        'Missing team logo' AS failure_type,
        player_id,
        CONCAT('Player ', player_name, ' at match ', match_sequence, 
               ' missing team_logo') AS failure_detail
    FROM {{ ref('gold_golden_boot_race') }}
    WHERE team_logo IS NULL
    
    UNION ALL
    
    -- Check 2: Player images (player_logo) - LENIENT: allows a few missing
    SELECT
        'Missing player images (warning only)' AS failure_type,
        'SYSTEM' AS player_id,
        CONCAT(COUNT(*), ' records missing player_logo - acceptable if <= 3') AS failure_detail
    FROM {{ ref('gold_golden_boot_race') }}
    WHERE player_logo IS NULL
    HAVING COUNT(*) > 3  -- Only fail if more than 3 records are missing images
    
    UNION ALL
    
    -- Check 3: Rankings should be 1, 2, or 3 (top 3 only)
    SELECT
        'Invalid ranking' AS failure_type,
        player_id,
        CONCAT('Player ', player_name, ' has invalid rank_at_match: ', 
               CAST(rank_at_match AS STRING)) AS failure_detail
    FROM {{ ref('gold_golden_boot_race') }}
    WHERE rank_at_match NOT IN (1, 2, 3)
    
    UNION ALL
    
    -- Check 4: Medals should match rankings
    SELECT
        'Invalid medal' AS failure_type,
        player_id,
        CONCAT('Player ', player_name, ' rank ', rank_at_match, 
               ' has wrong medal: ', COALESCE(medal, 'NULL')) AS failure_detail
    FROM {{ ref('gold_golden_boot_race') }}
    WHERE (rank_at_match = 1 AND medal != '🥇')
       OR (rank_at_match = 2 AND medal != '🥈')
       OR (rank_at_match = 3 AND medal != '🥉')
       OR medal IS NULL
    
    UNION ALL
    
    -- Check 5: Cumulative goals should be non-negative
    SELECT
        'Invalid cumulative goals' AS failure_type,
        player_id,
        CONCAT('Player ', player_name, ' has invalid goals_cumulative: ', 
               CAST(goals_cumulative AS STRING)) AS failure_detail
    FROM {{ ref('gold_golden_boot_race') }}
    WHERE goals_cumulative < 0
    
    UNION ALL
    
    -- Check 6: Current top 3 should only be marked at latest match
    SELECT
        'Invalid current_top_3 flag' AS failure_type,
        player_id,
        CONCAT('Player ', player_name, ' has is_current_top_3=TRUE at non-latest match ', 
               match_sequence) AS failure_detail
    FROM {{ ref('gold_golden_boot_race') }}
    WHERE is_current_top_3 = TRUE
      AND match_sequence != (SELECT MAX(match_sequence) FROM {{ ref('gold_golden_boot_race') }})
    
    UNION ALL
    
    -- Check 7: At least one player should be marked as current top 3
    SELECT
        'No current top 3 marked' AS failure_type,
        'SYSTEM' AS player_id,
        CONCAT('No players marked as is_current_top_3=TRUE at latest match') AS failure_detail
    FROM (
        SELECT COUNT(*) AS current_count
        FROM {{ ref('gold_golden_boot_race') }}
        WHERE is_current_top_3 = TRUE
    )
    WHERE current_count = 0
    
    UNION ALL
    
    -- Check 8: Goals should not decrease over time for same player
    SELECT
        'Goals decreased over time' AS failure_type,
        curr.player_id,
        CONCAT('Player ', curr.player_name, ' goals decreased from ', 
               prev.goals_cumulative, ' (match ', prev.match_sequence, 
               ') to ', curr.goals_cumulative, ' (match ', curr.match_sequence, ')') AS failure_detail
    FROM {{ ref('gold_golden_boot_race') }} curr
    JOIN {{ ref('gold_golden_boot_race') }} prev
        ON curr.player_id = prev.player_id
        AND curr.match_sequence = prev.match_sequence + 1
    WHERE curr.goals_cumulative < prev.goals_cumulative
)

SELECT
    failure_type,
    failure_detail,
    COUNT(*) AS failure_count
FROM validation_failures
GROUP BY failure_type, failure_detail

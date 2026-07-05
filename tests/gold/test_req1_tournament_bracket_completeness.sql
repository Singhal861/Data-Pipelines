-- Requirement 1: Tournament Bracket / Fixture Graphics
-- Validates: gold_fact_match_schedule (knockout matches), gold_fact_team_performance

-- Test that all knockout matches have complete bracket structure with:
-- 1. Team logos and names populated
-- 2. Match times in UTC
-- 3. Stadium and country information
-- 4. Winner tracking for completed matches

WITH validation_failures AS (
    -- Check 1: Matches with assigned teams must have team logos
    SELECT
        'Missing team logo' AS failure_type,
        match_id,
        CONCAT('Match ', match_id, ' missing logos - home: ', 
               CASE WHEN home_team_logo IS NULL THEN 'NULL' ELSE 'OK' END,
               ', away: ', CASE WHEN away_team_logo IS NULL THEN 'NULL' ELSE 'OK' END) AS failure_detail
    FROM {{ ref('gold_fact_match_schedule') }}
    WHERE is_knockout = TRUE  -- Only check knockout matches
      AND (home_team_logo IS NULL OR away_team_logo IS NULL)
      AND home_team_name IS NOT NULL  -- Only check matches with assigned teams
    
    UNION ALL
    
    -- Check 2: Matches with assigned teams must have valid UTC timestamps (skip TBD matches)
    SELECT
        'Invalid match datetime' AS failure_type,
        match_id,
        CONCAT('Match ', match_id, ' has NULL match_datetime_utc') AS failure_detail
    FROM {{ ref('gold_fact_match_schedule') }}
    WHERE is_knockout = TRUE  -- Only check knockout matches
      AND match_datetime_utc IS NULL
      AND home_team_name IS NOT NULL  -- Only check matches with assigned teams
    
    UNION ALL
    
    -- Check 3: Matches with assigned teams must have stadium and country (skip TBD matches)
    SELECT
        'Missing stadium info' AS failure_type,
        match_id,
        CONCAT('Match ', match_id, ' missing - stadium: ', 
               COALESCE(stadium_name, 'NULL'), ', country: ', COALESCE(actual_country, 'NULL')) AS failure_detail
    FROM {{ ref('gold_fact_match_schedule') }}
    WHERE is_knockout = TRUE  -- Only check knockout matches
      AND (stadium_name IS NULL OR actual_country IS NULL)
      AND home_team_name IS NOT NULL  -- Only check matches with assigned teams
    
    UNION ALL
    
    -- Check 4: All completed knockout matches must have winner_team_id (includes penalty shootouts)
    SELECT
        'Missing winner for completed match' AS failure_type,
        match_id,
        CONCAT('Match ', match_id, ' is finished (score: ', home_score, '-', away_score, ') but winner_team_id is NULL - check penalty shootout data') AS failure_detail
    FROM {{ ref('gold_fact_match_schedule') }}
    WHERE is_knockout = TRUE  -- Only check knockout matches
      AND is_finished = TRUE 
      AND winner_team_id IS NULL
      AND home_team_name IS NOT NULL  -- Only check matches with assigned teams
    
    UNION ALL
    
    -- Check 5: gold_team_summary has all teams with top scorers
    SELECT
        'Missing team stats' AS failure_type,
        team_id,
        CONCAT('Team ', team_name, ' missing stats - wins: ', 
               COALESCE(CAST(total_wins AS STRING), 'NULL'),
               ', logo: ', CASE WHEN team_logo IS NULL THEN 'NULL' ELSE 'OK' END) AS failure_detail
    FROM {{ ref('gold_team_summary') }}
    WHERE total_wins IS NULL OR team_logo IS NULL
)

SELECT
    failure_type,
    failure_detail,
    COUNT(*) AS failure_count
FROM validation_failures
GROUP BY failure_type, failure_detail

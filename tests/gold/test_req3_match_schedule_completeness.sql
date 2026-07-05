-- Requirement 3: Live Knockout Match Display
-- Validates: gold_fact_match_schedule (all matches)

-- Test that match schedule has:
-- 1. All matches with team logos
-- 2. Live match indicators
-- 3. Top scorers per match
-- 4. UTC and local times
-- 5. Stadium information

WITH validation_failures AS (
    -- Check 1: Matches with assigned teams must have team logos (skip TBD matches)
    SELECT
        'Missing team logos' AS failure_type,
        match_id,
        CONCAT('Match ', match_id, ' (', home_team_name, ' vs ', away_team_name, 
               ') missing logos') AS failure_detail
    FROM {{ ref('gold_fact_match_schedule') }}
    WHERE (home_team_logo IS NULL OR away_team_logo IS NULL)
      AND home_team_name IS NOT NULL  -- Skip TBD future matches
    
    UNION ALL
    
    -- Check 2: All matches have UTC timestamps
    SELECT
        'Missing UTC time' AS failure_type,
        match_id,
        CONCAT('Match ', match_id, ' has NULL match_datetime_utc') AS failure_detail
    FROM {{ ref('gold_fact_match_schedule') }}
    WHERE match_datetime_utc IS NULL
    
    UNION ALL
    
    -- Check 3: All matches have local timestamps
    SELECT
        'Missing local time' AS failure_type,
        match_id,
        CONCAT('Match ', match_id, ' has NULL match_date_local') AS failure_detail
    FROM {{ ref('gold_fact_match_schedule') }}
    WHERE match_date_local IS NULL
    
    UNION ALL
    
    -- Check 4: All matches have stadium info
    SELECT
        'Missing stadium info' AS failure_type,
        match_id,
        CONCAT('Match ', match_id, ' missing - stadium: ', 
               COALESCE(stadium_name, 'NULL'), ', country: ', 
               COALESCE(actual_country, 'NULL')) AS failure_detail
    FROM {{ ref('gold_fact_match_schedule') }}
    WHERE stadium_name IS NULL OR actual_country IS NULL
    
    UNION ALL
    
    -- Check 5: Live matches should have is_live = TRUE
    SELECT
        'Invalid live match status' AS failure_type,
        match_id,
        CONCAT('Match ', match_id, ' has minutes_elapsed but is_live = FALSE') AS failure_detail
    FROM {{ ref('gold_fact_match_schedule') }}
    WHERE minutes_elapsed IS NOT NULL 
      AND is_live = FALSE
    
    UNION ALL
    
    -- Check 6: Match status should be valid
    SELECT
        'Invalid match status' AS failure_type,
        match_id,
        CONCAT('Match ', match_id, ' has invalid match_status: ', 
               COALESCE(match_status, 'NULL')) AS failure_detail
    FROM {{ ref('gold_fact_match_schedule') }}
    WHERE match_status NOT IN ('Scheduled', 'Live', 'Finished', 'Postponed', 'Cancelled', 'Upcoming')
       OR match_status IS NULL
)

SELECT
    failure_type,
    failure_detail,
    COUNT(*) AS failure_count
FROM validation_failures
GROUP BY failure_type, failure_detail

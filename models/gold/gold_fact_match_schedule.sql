{{config(
    materialized='table',
    tags=['gold', 'fact', 'dashboard', 'matches']
)}}

-- gold_fact_match_schedule: Unified match fact table (Requirements #1, #3, #4)
-- Combines tournament bracket structure + match schedule + top scorers
-- Includes ALL matches: group stage + knockout
-- Replaces: gold_tournament_bracket + gold_match_schedule

WITH timezone_ref AS (
    SELECT * FROM {{ source('silver', 'ref_stadium_enriched') }}
),

-- Get bracket structure for knockout matches only
bracket_structure AS (
    SELECT 
        match_id,
        bracket_position,
        feeds_into_position
    FROM {{ ref('silver_knockout_bracket') }}
),

-- Calculate bracket progression sources (for "Winner of X" display)
match_sources AS (
    SELECT 
        feeds_into_position AS target_position,
        COLLECT_LIST(bracket_position) AS source_positions
    FROM bracket_structure
    WHERE feeds_into_position IS NOT NULL
    GROUP BY feeds_into_position
),

-- Parse all matches (group + knockout) with UTC timestamps
parsed_matches AS (
    SELECT
        m.match_id,
        m.home_team_id,
        m.away_team_id,
        m.home_team_name,
        m.away_team_name,
        m.home_score,
        m.away_score,
        m.stage,
        m.group_name,
        m.is_finished,
        m.match_date_local,
        m.stadium_id,
        m.winner_team_id,
        m.winner_team AS winner_team_name,
        m.bracket_position,
        s.name AS stadium_name,
        tz.city AS stadium_city,
        tz.actual_country,
        tz.utc_offset_hours,
        TO_TIMESTAMP(
            REGEXP_REPLACE(m.match_date_local, ' [A-Z]{3,4}$', ''),
            'MM/dd/yyyy HH:mm'
        ) + MAKE_DT_INTERVAL(0, tz.utc_offset_hours, 0, 0) AS match_datetime_utc
    FROM {{ ref('silver_matches') }} m
    JOIN {{ ref('silver_stadiums') }} s ON m.stadium_id = s.stadium_id
    JOIN timezone_ref tz ON m.stadium_id = tz.stadium_id
),

-- Add bracket progression logic for knockout matches
with_bracket_logic AS (
    SELECT
        pm.*,
        bs.feeds_into_position,
        
        -- Display names with TBD/Winner progression logic (knockout only)
        CASE 
            WHEN pm.home_team_name IS NOT NULL THEN pm.home_team_name
            WHEN ms.source_positions IS NOT NULL AND SIZE(ms.source_positions) >= 1 
                THEN CONCAT('Winner of ', ms.source_positions[0])
            WHEN pm.bracket_position IS NOT NULL THEN 'TBD'
            ELSE pm.home_team_name
        END AS home_display_name,
        
        CASE 
            WHEN pm.away_team_name IS NOT NULL THEN pm.away_team_name
            WHEN ms.source_positions IS NOT NULL AND SIZE(ms.source_positions) >= 2 
                THEN CONCAT('Winner of ', ms.source_positions[1])
            WHEN pm.bracket_position IS NOT NULL THEN 'TBD'
            ELSE pm.away_team_name
        END AS away_display_name,
        
        -- Bracket half for visual positioning (knockout only)
        CASE 
            WHEN pm.bracket_position LIKE '%1' OR pm.bracket_position LIKE '%3' THEN 'Top'
            WHEN pm.bracket_position LIKE '%2' OR pm.bracket_position LIKE '%4' THEN 'Bottom'
            ELSE NULL
        END AS bracket_half
        
    FROM parsed_matches pm
    LEFT JOIN bracket_structure bs ON pm.match_id = bs.match_id
    LEFT JOIN match_sources ms ON pm.bracket_position = ms.target_position
),

-- Add team logos
with_team_logos AS (
    SELECT
        wbl.*,
        ht.team_logo AS home_team_logo,
        at.team_logo AS away_team_logo,
        wt.team_logo AS winner_team_logo
    FROM with_bracket_logic wbl
    LEFT JOIN {{ ref('silver_teams') }} ht ON wbl.home_team_name = ht.team_name
    LEFT JOIN {{ ref('silver_teams') }} at ON wbl.away_team_name = at.team_name
    LEFT JOIN {{ ref('silver_teams') }} wt ON wbl.winner_team_name = wt.team_name
),

-- Get MATCH-LEVEL top scorers from goal_events (who scored most in THIS match)
match_scorers AS (
    SELECT
        ge.match_id,
        ge.team_name,
        ge.scorer_name,
        COUNT(*) AS goals_in_match,
        ROW_NUMBER() OVER (
            PARTITION BY ge.match_id, ge.team_name 
            ORDER BY COUNT(*) DESC, MAX(ge.minute) DESC
        ) AS scorer_rank
    FROM {{ ref('silver_goal_events') }} ge
    GROUP BY ge.match_id, ge.team_name, ge.scorer_name
),

-- Combine everything
final AS (
    SELECT
        wtl.*,
        home_scorer.scorer_name AS home_top_scorer_name,
        home_scorer.goals_in_match AS home_top_scorer_goals,
        away_scorer.scorer_name AS away_top_scorer_name,
        away_scorer.goals_in_match AS away_top_scorer_goals
    FROM with_team_logos wtl
    LEFT JOIN match_scorers home_scorer 
        ON wtl.match_id = home_scorer.match_id 
        AND wtl.home_team_name = home_scorer.team_name 
        AND home_scorer.scorer_rank = 1
    LEFT JOIN match_scorers away_scorer 
        ON wtl.match_id = away_scorer.match_id 
        AND wtl.away_team_name = away_scorer.team_name 
        AND away_scorer.scorer_rank = 1
)

SELECT
    -- Match identifiers
    match_id,
    
    -- Match status (calculated)
    CASE
        WHEN is_finished = TRUE THEN 'Finished'
        WHEN is_finished = FALSE 
            AND match_datetime_utc <= CURRENT_TIMESTAMP() 
            AND match_datetime_utc >= CURRENT_TIMESTAMP() - INTERVAL 3 HOURS
            THEN 'Live'
        WHEN is_finished = FALSE 
            AND match_datetime_utc > CURRENT_TIMESTAMP()
            THEN 'Upcoming'
        ELSE 'Finished'
    END AS match_status,
    
    -- Time dimensions
    match_datetime_utc,
    match_date_local,
    
    -- Home team
    home_team_id,
    home_team_name,
    home_display_name,  -- "Argentina" or "Winner of QF1" or "TBD"
    home_team_logo,
    home_top_scorer_name,
    home_top_scorer_goals,
    home_score,
    
    -- Away team
    away_team_id,
    away_team_name,
    away_display_name,  -- "France" or "Winner of QF3" or "TBD"
    away_team_logo,
    away_top_scorer_name,
    away_top_scorer_goals,
    away_score,
    
    -- Match outcome
    winner_team_id,
    winner_team_name,
    winner_team_logo,
    
    -- Stage/competition context
    stage,
    group_name,  -- NULL for knockout
    CASE WHEN stage != 'Group Stage' THEN TRUE ELSE FALSE END AS is_knockout,
    
    -- Bracket structure (NULL for group stage)
    bracket_position,      -- e.g., "QF1", "SF1", "FIN"
    feeds_into_position,   -- e.g., QF1 feeds into SF1
    bracket_half,          -- "Top" or "Bottom" (visual positioning)
    
    -- Location
    stadium_name,
    stadium_city,
    actual_country,
    
    -- Time calculations
    CASE 
        WHEN match_datetime_utc > CURRENT_TIMESTAMP() 
        THEN ROUND((UNIX_TIMESTAMP(match_datetime_utc) - UNIX_TIMESTAMP(CURRENT_TIMESTAMP())) / 3600.0, 1)
        ELSE NULL
    END AS hours_until_kickoff,
    
    CASE
        WHEN is_finished = FALSE 
            AND match_datetime_utc <= CURRENT_TIMESTAMP()
        THEN ROUND((UNIX_TIMESTAMP(CURRENT_TIMESTAMP()) - UNIX_TIMESTAMP(match_datetime_utc)) / 60.0, 0)
        ELSE NULL
    END AS minutes_elapsed,
    
    -- Status flags
    is_finished,
    CASE 
        WHEN is_finished = FALSE 
            AND match_datetime_utc <= CURRENT_TIMESTAMP() 
            AND match_datetime_utc >= CURRENT_TIMESTAMP() - INTERVAL 3 HOURS
        THEN TRUE
        ELSE FALSE
    END AS is_live
    
FROM final
ORDER BY match_datetime_utc ASC

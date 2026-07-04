{{config(
    materialized='table',
    tags=['gold', 'dashboard', 'bracket']
)}}

-- gold_tournament_bracket: Tournament bracket view with all progression logic
-- Shows TBD placeholders for future matches based on bracket structure

WITH timezone_ref AS (
    SELECT * FROM {{ source('silver', 'ref_stadium_enriched') }}
),

bracket_structure AS (
    SELECT 
        match_id,
        bracket_position,
        feeds_into_position
    FROM {{ ref('silver_knockout_bracket') }}
),

match_sources AS (
    SELECT 
        feeds_into_position AS target_position,
        COLLECT_LIST(bracket_position) AS source_positions
    FROM bracket_structure
    WHERE feeds_into_position IS NOT NULL
    GROUP BY feeds_into_position
),

knockout_matches AS (
    SELECT
        m.match_id,
        bs.bracket_position,
        bs.feeds_into_position,
        m.stage,
        m.is_finished,
        m.match_date_local,
        m.stadium_id,
        
        -- Original team IDs and names
        m.home_team_id,
        m.away_team_id,
        m.home_team_name,
        m.away_team_name,
        m.home_score,
        m.away_score,
        
        -- Display names with TBD logic
        CASE 
            WHEN m.home_team_name IS NOT NULL THEN m.home_team_name
            WHEN ms.source_positions IS NOT NULL AND SIZE(ms.source_positions) >= 1 
                THEN CONCAT('Winner of ', ms.source_positions[0])
            ELSE 'TBD'
        END AS home_display_name,
        
        CASE 
            WHEN m.away_team_name IS NOT NULL THEN m.away_team_name
            WHEN ms.source_positions IS NOT NULL AND SIZE(ms.source_positions) >= 2 
                THEN CONCAT('Winner of ', ms.source_positions[1])
            ELSE 'TBD'
        END AS away_display_name,
        
        -- Stadium details
        s.name AS stadium_name,
        tz.city AS stadium_city,
        tz.actual_country,
        tz.utc_offset_hours,
        
        -- UTC timestamp
        TO_TIMESTAMP(
            REGEXP_REPLACE(m.match_date_local, ' [A-Z]{3,4}$', ''),
            'MM/dd/yyyy HH:mm'
        ) + MAKE_DT_INTERVAL(0, tz.utc_offset_hours, 0, 0) AS match_datetime_utc,
        
        -- Winner tracking (trust silver's calculation which handles penalties)
        m.winner_team_id AS winner_team_id,
        m.winner_team AS winner_team_name
    FROM {{ ref('silver_matches') }} m
    JOIN bracket_structure bs ON m.match_id = bs.match_id
    LEFT JOIN match_sources ms ON bs.bracket_position = ms.target_position
    JOIN {{ ref('silver_stadiums') }} s ON m.stadium_id = s.stadium_id
    JOIN timezone_ref tz ON m.stadium_id = tz.stadium_id
    WHERE m.stage != 'Group Stage'
),

with_team_logos AS (
    SELECT
        km.*,
        ht.team_logo AS home_team_logo,
        at.team_logo AS away_team_logo,
        wt.team_logo AS winner_team_logo
    FROM knockout_matches km
    LEFT JOIN {{ ref('silver_teams') }} ht ON km.home_team_name = ht.team_name
    LEFT JOIN {{ ref('silver_teams') }} at ON km.away_team_name = at.team_name
    LEFT JOIN {{ ref('silver_teams') }} wt ON km.winner_team_name = wt.team_name
)

SELECT
    match_id,
    stage AS round,
    bracket_position,
    feeds_into_position,
    CASE 
        WHEN bracket_position LIKE '%1' OR bracket_position LIKE '%3' THEN 'Top'
        ELSE 'Bottom'
    END AS bracket_half,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_display_name,
    away_display_name,
    home_team_logo,
    away_team_logo,
    home_score,
    away_score,
    winner_team_id,
    winner_team_name,
    winner_team_logo,
    is_finished,
    match_datetime_utc,
    match_date_local,
    stadium_name,
    stadium_city,
    actual_country,
    CASE 
        WHEN match_datetime_utc > CURRENT_TIMESTAMP() 
        THEN ROUND((UNIX_TIMESTAMP(match_datetime_utc) - UNIX_TIMESTAMP(CURRENT_TIMESTAMP())) / 3600.0, 1)
        ELSE NULL
    END AS hours_until_kickoff,
    CASE 
        WHEN is_finished = FALSE 
            AND match_datetime_utc <= CURRENT_TIMESTAMP() 
            AND match_datetime_utc >= CURRENT_TIMESTAMP() - INTERVAL 3 HOURS
        THEN TRUE
        ELSE FALSE
    END AS is_live
FROM with_team_logos
ORDER BY 
    CASE 
        WHEN round = 'Round of 32' THEN 1
        WHEN round = 'Round of 16' THEN 2
        WHEN round = 'Quarter Final' THEN 3
        WHEN round = 'Semi Final' THEN 4
        WHEN round = 'Third Place' THEN 5
        WHEN round = 'Final' THEN 6
        ELSE 99
    END,
    CAST(NULLIF(REGEXP_EXTRACT(bracket_position, '\\d+', 0), '') AS INT)

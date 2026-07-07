from flask import jsonify
from api.common import execute_query
# 4 req
def app(request):
    data = execute_query("""WITH match_bracket AS (
    -- Get all knockout matches with bracket structure
    SELECT 
        match_id,
        stage,
        bracket_position,
        feeds_into_position,
        bracket_half,
        
        -- Home team (handles TBD logic)
        home_team_name,
        COALESCE(home_display_name, home_team_name, 'TBD') AS home_display_name,
        home_team_logo,
        home_score,
        
        -- Away team (handles TBD logic)
        away_team_name,
        COALESCE(away_display_name, away_team_name, 'TBD') AS away_display_name,
        away_team_logo,
        away_score,
        
        -- Match outcome
        winner_team_name,
        winner_team_logo,
        
        -- Match metadata
        match_status,
        match_datetime_utc,
        match_date_local,
        stadium_name,
        stadium_city,
        actual_country,
        is_finished,
        is_live
        
    FROM singhal.fifa_worldcup_gold.gold_fact_match_schedule
    WHERE is_knockout = TRUE
),

home_goals AS (
    -- Get goals scored by home team in each match
    SELECT
        g.match_id,
        COLLECT_LIST(
            STRUCT(
                g.scorer_name,
                g.minute,
                g.is_penalty,
                g.goal_number_in_match
            )
        ) AS goals
    FROM singhal.fifa_worldcup_gold.gold_team_goals g
    INNER JOIN match_bracket mb ON g.match_id = mb.match_id AND g.team_name = mb.home_team_name
    GROUP BY g.match_id
),

away_goals AS (
    -- Get goals scored by away team in each match
    SELECT
        g.match_id,
        COLLECT_LIST(
            STRUCT(
                g.scorer_name,
                g.minute,
                g.is_penalty,
                g.goal_number_in_match
            )
        ) AS goals
    FROM singhal.fifa_worldcup_gold.gold_team_goals g
    INNER JOIN match_bracket mb ON g.match_id = mb.match_id AND g.team_name = mb.away_team_name
    GROUP BY g.match_id
)

-- Final comprehensive query
SELECT
    -- Bracket structure
    mb.match_id,
    mb.stage,
    mb.bracket_position,              -- e.g., "QF1", "SF1", "FIN"
    mb.feeds_into_position,           -- e.g., QF1 → SF1
    mb.bracket_half,                  -- "Top" or "Bottom"
    
    -- Home team
    mb.home_team_name,
    mb.home_display_name,             -- Shows "Winner of QF1" or "TBD" for unfilled
    mb.home_team_logo,                -- 🇦🇷 Team flag
    mb.home_score,
    
    -- Home team goals (formatted with timing)
    CASE 
        WHEN mb.is_finished = TRUE AND hg.goals IS NOT NULL
        THEN TRANSFORM(
            hg.goals,
            g -> CONCAT(
                g.scorer_name, ' (', g.minute, ')',
                CASE WHEN g.is_penalty THEN ' (PEN)' ELSE '' END
            )
        )
        ELSE ARRAY('NA')  -- Match not completed yet
    END AS home_goals_detail,
    
    -- Away team
    mb.away_team_name,
    mb.away_display_name,             -- Shows "Winner of QF3" or "TBD" for unfilled
    mb.away_team_logo,                -- 🇫🇷 Team flag
    mb.away_score,
    
    -- Away team goals (formatted with timing)
    CASE 
        WHEN mb.is_finished = TRUE AND ag.goals IS NOT NULL
        THEN TRANSFORM(
            ag.goals,
            g -> CONCAT(
                g.scorer_name, ' (', g.minute, ')',
                CASE WHEN g.is_penalty THEN ' (PEN)' ELSE '' END
            )
        )
        ELSE ARRAY('NA')  -- Match not completed yet
    END AS away_goals_detail,
    
    -- Match outcome
    mb.winner_team_name,
    mb.winner_team_logo,
    
    -- Match info
    mb.match_status,                  -- 'Finished', 'Live', 'Upcoming'
    mb.match_datetime_utc,            -- UTC time
    mb.match_date_local,              -- Local timezone display
    mb.stadium_name,                  -- MetLife Stadium
    mb.stadium_city,                  -- New Jersey
    mb.actual_country,                -- United States
    mb.is_finished,
    mb.is_live

FROM match_bracket mb
LEFT JOIN home_goals hg ON mb.match_id = hg.match_id
LEFT JOIN away_goals ag ON mb.match_id = ag.match_id

ORDER BY 
    CASE mb.stage
        WHEN 'Round of 32' THEN 1
        WHEN 'Round of 16' THEN 2
        WHEN 'Quarter Final' THEN 3
        WHEN 'Semi Final' THEN 4
        WHEN 'Third Place' THEN 5
        WHEN 'Final' THEN 6
    END,
    mb.bracket_position;""")
    return jsonify(data)
from flask import jsonify
from api.common import execute_query
# 4 req
def app(request):
    data = execute_query("""SELECT 
    m.match_id,
    
    -- Team information
    m.home_team_name AS team_a_name,
    m.home_team_logo AS team_a_logo,
    m.away_team_name AS team_b_name,
    m.away_team_logo AS team_b_logo,
    
    -- Score information
    m.home_score,
    m.away_score,
    
    -- Winner information
    m.winner_team_name,
    m.winner_team_logo,
    
    -- Penalty shootout detection
    -- If knockout match ended in a draw but has a winner, it was decided by penalties
    CASE 
        WHEN m.is_knockout = TRUE 
         AND m.home_score = m.away_score 
         AND m.winner_team_name IS NOT NULL 
        THEN TRUE 
        ELSE FALSE 
    END AS is_penalty_shootout,
    
    -- Match timing
    m.match_datetime_utc,
    m.match_date_local,
    
    -- Location
    m.stadium_city,
    m.stadium_name,
    m.actual_country,
    
    -- Tournament context
    m.stage,
    m.group_name,  -- NULL for knockout matches
    m.is_knockout
    
FROM singhal.fifa_worldcup_gold.gold_fact_match_schedule m
WHERE m.is_finished = TRUE
ORDER BY m.match_datetime_utc DESC;
        """)
    return jsonify(data)
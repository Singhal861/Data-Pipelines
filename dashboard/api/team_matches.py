from flask import jsonify
from api.common import execute_query
# 4 req
def app(request):
    data = execute_query("""
            SELECT 
    m.match_id,
    m.match_datetime_utc,
    m.match_date_local,
    m.stage,
    
    -- Home team info
    m.home_team_name,
    m.home_team_logo,
    m.home_score,
    
    -- Away team info
    m.away_team_name,
    m.away_team_logo,
    m.away_score,
    
    -- Winner info
    m.winner_team_name,
    m.winner_team_logo,
    
    -- Penalty shootout detection
    CASE 
        WHEN m.is_knockout = TRUE 
         AND m.home_score = m.away_score 
         AND m.winner_team_name IS NOT NULL 
        THEN TRUE 
        ELSE FALSE 
    END AS is_penalty_shootout,
    
    m.stadium_name,
    m.stadium_city
    
FROM singhal.fifa_worldcup_gold.gold_fact_match_schedule m
WHERE m.is_finished = TRUE
ORDER BY m.match_datetime_utc ASC;
        """)
    return jsonify(data)
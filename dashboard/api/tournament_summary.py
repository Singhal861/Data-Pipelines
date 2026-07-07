from flask import jsonify
from api.common import execute_query
# 4 req
def app(request):
    data = execute_query("""
            SELECT 
    tournament_name,        -- e.g., "FIFA World Cup 2026"
    total_matches,          -- Total matches in tournament
    completed_matches,      -- Matches finished
    remaining_matches,      -- Matches yet to be played
    total_goals,            -- Total goals scored
    avg_goals_per_match,    -- Average goals per completed match
    current_round,          -- e.g., "Group Stage", "Quarter Finals", "Semi Finals"
    teams_remaining,        -- Number of teams still in competition
    top_scorer_name,        -- Current leading scorer
    top_scorer_goals        -- Goals by top scorer
FROM singhal.fifa_worldcup_gold.gold_tournament_summary;
        """)
    return jsonify(data)
from flask import jsonify
from api.common import execute_query
# 4 req
def app(request):
    data = execute_query("""
            SELECT 
    team_name,
    team_logo,
    total_points,
    total_wins,
    total_losses,
    total_draws,
    goals_for,
    goals_against,
    goal_difference,
    clean_sheets,
    group_name,  -- e.g., "A", "B", "C" or NULL for knockout stage
    current_stage,  -- e.g., "Group Stage", "Quarter Final", "Semi Final"
    qualification_status,  -- 'Qualified', 'Disqualified', 'In Progress'
    rank_overall  -- Overall tournament ranking
FROM singhal.fifa_worldcup_gold.gold_fact_team_performance
ORDER BY total_points DESC, goal_difference DESC, goals_for DESC;""")

    return jsonify(data)
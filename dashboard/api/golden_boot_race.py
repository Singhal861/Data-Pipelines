from flask import jsonify
from api.common import execute_query
# 4 req
def app(request):
    data = execute_query("""
            SELECT 
    match_sequence,  -- X-axis: Match number (1, 2, 3...)
    player_id,
    player_name,
    player_logo,  -- Player headshot for legend
    team_id,
    team_name,
    team_logo,
    goals_cumulative,  -- Y-axis: Cumulative goals
    assists_cumulative,
    minutes_cumulative,
    rank_at_match,  -- 1, 2, or 3
    medal,  -- 🥇, 🥈, or 🥉
    is_current_top_3  -- TRUE only for latest match (filter for current standings)
FROM singhal.fifa_worldcup_gold.gold_golden_boot_race
WHERE rank_at_match <= 3  -- Only top 3 players
ORDER BY match_sequence, rank_at_match;
        """)
    return jsonify(data)
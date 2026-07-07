from flask import jsonify
from api.common import execute_query
# 4 req
def app(request):
    data = execute_query("""SELECT 
    rank,
    player_id,
    player_name,
    player_logo,
    team_id,
    team_name,
    team_logo,
    goals_scored,
    assists,
    matches_played,
    minutes_played,
    rating_0_to_10,
    goals_percentile,      -- For spider chart
    assists_percentile,    -- For spider chart
    minutes_percentile,    -- For spider chart
    matches_percentile,    -- For spider chart
    most_goals_against_team_name,
    most_goals_against_team_count,
    golden_boot_rank,
    is_top_3,
    goals_behind_leader
FROM singhal.fifa_worldcup_gold.gold_player_leaderboard
ORDER BY rank
LIMIT 10;
        """)

    return jsonify(data)
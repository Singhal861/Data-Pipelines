from flask import jsonify
from api.common import execute_query
# 4 req
def app(request):
    data = execute_query("""
            SELECT 
    match_id,
    match_status,  -- 'Live' or 'Upcoming'
    match_datetime_utc,
    match_date_local,
    home_team_id,
    home_team_name,
    home_team_logo,
    home_top_scorer_name,
    home_top_scorer_goals,
    home_score,
    away_team_id,
    away_team_name,
    away_team_logo,
    away_top_scorer_name,
    away_top_scorer_goals,
    away_score,
    stage,
    group_name,  -- NULL for knockout matches
    is_knockout,
    stadium_name,
    stadium_city,
    actual_country,
    is_live,
    minutes_elapsed,  -- For live matches
    hours_until_kickoff  -- For upcoming matches
FROM singhal.fifa_worldcup_gold.gold_fact_match_schedule
WHERE match_status IN ('Live', 'Upcoming')
  AND is_finished = FALSE
  AND home_team_name IS NOT NULL  -- Exclude TBD matches
  AND away_team_name IS NOT NULL  -- Exclude "Winner of X" matches
ORDER BY match_datetime_utc ASC;
        """)
    return jsonify(data)
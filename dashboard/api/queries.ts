export const queries = {
  tournament_summary: `
    SELECT 
        tournament_name,
        total_matches,
        completed_matches,
        remaining_matches,
        total_goals,
        avg_goals_per_match,
        current_round,
        teams_remaining,
        top_scorer_name,
        top_scorer_goals
    FROM singhal.fifa_worldcup_gold.gold_tournament_summary;
  `,

  fixture: `
    WITH match_bracket AS (
        SELECT 
            match_id,
            stage,
            bracket_position,
            feeds_into_position,
            bracket_half,
            home_team_name,
            COALESCE(home_display_name, home_team_name, 'TBD') AS home_display_name,
            home_team_logo,
            home_score,
            away_team_name,
            COALESCE(away_display_name, away_team_name, 'TBD') AS away_display_name,
            away_team_logo,
            away_score,
            winner_team_name,
            winner_team_logo,
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

    SELECT
        mb.match_id,
        mb.stage,
        mb.bracket_position,
        mb.feeds_into_position,
        mb.bracket_half,
        mb.home_team_name,
        mb.home_display_name,
        mb.home_team_logo,
        mb.home_score,
        CASE 
            WHEN mb.is_finished = TRUE AND hg.goals IS NOT NULL
            THEN TRANSFORM(
                hg.goals,
                g -> CONCAT(
                    g.scorer_name, ' (', g.minute, ')',
                    CASE WHEN g.is_penalty THEN ' (PEN)' ELSE '' END
                )
            )
            ELSE ARRAY('NA')
        END AS home_goals_detail,
        mb.away_team_name,
        mb.away_display_name,
        mb.away_team_logo,
        mb.away_score,
        CASE 
            WHEN mb.is_finished = TRUE AND ag.goals IS NOT NULL
            THEN TRANSFORM(
                ag.goals,
                g -> CONCAT(
                    g.scorer_name, ' (', g.minute, ')',
                    CASE WHEN g.is_penalty THEN ' (PEN)' ELSE '' END
                )
            )
            ELSE ARRAY('NA')
        END AS away_goals_detail,
        mb.winner_team_name,
        mb.winner_team_logo,
        mb.match_status,
        mb.match_datetime_utc,
        mb.match_date_local,
        mb.stadium_name,
        mb.stadium_city,
        mb.actual_country,
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
        mb.bracket_position;
  `,

  top_scorers: `
    SELECT 
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
        goals_percentile,
        assists_percentile,
        minutes_percentile,
        matches_percentile,
        most_goals_against_team_name,
        most_goals_against_team_count,
        golden_boot_rank,
        is_top_3,
        goals_behind_leader
    FROM singhal.fifa_worldcup_gold.gold_player_leaderboard
    ORDER BY rank
    LIMIT 10;
  `,

  upcoming_matches: `
    SELECT 
        match_id,
        match_status,
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
        group_name,
        is_knockout,
        stadium_name,
        stadium_city,
        actual_country,
        is_live,
        minutes_elapsed,
        hours_until_kickoff
    FROM singhal.fifa_worldcup_gold.gold_fact_match_schedule
    WHERE match_status IN ('Live', 'Upcoming')
      AND is_finished = FALSE
      AND home_team_name IS NOT NULL
      AND away_team_name IS NOT NULL
    ORDER BY match_datetime_utc ASC;
  `,

  finished_matches: `
    SELECT 
        m.match_id,
        m.home_team_name AS team_a_name,
        m.home_team_logo AS team_a_logo,
        m.away_team_name AS team_b_name,
        m.away_team_logo AS team_b_logo,
        m.home_score,
        m.away_score,
        m.winner_team_name,
        m.winner_team_logo,
        CASE 
            WHEN m.is_knockout = TRUE 
             AND m.home_score = m.away_score 
             AND m.winner_team_name IS NOT NULL 
            THEN TRUE 
            ELSE FALSE 
        END AS is_penalty_shootout,
        m.match_datetime_utc,
        m.match_date_local,
        m.stadium_city,
        m.stadium_name,
        m.actual_country,
        m.stage,
        m.group_name,
        m.is_knockout
        
    FROM singhal.fifa_worldcup_gold.gold_fact_match_schedule m
    WHERE m.is_finished = TRUE
    ORDER BY m.match_datetime_utc DESC;
  `,

  team_performance: `
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
        group_name,
        current_stage,
        qualification_status,
        rank_overall
    FROM singhal.fifa_worldcup_gold.gold_fact_team_performance
    ORDER BY total_points DESC, goal_difference DESC, goals_for DESC;
  `,

  team_matches_history: `
    SELECT 
        m.match_id,
        m.match_datetime_utc,
        m.match_date_local,
        m.stage,
        m.home_team_name,
        m.home_team_logo,
        m.home_score,
        m.away_team_name,
        m.away_team_logo,
        m.away_score,
        m.winner_team_name,
        m.winner_team_logo,
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
  `,

  golden_boot_race: `
    SELECT 
        match_sequence,
        player_id,
        player_name,
        player_logo,
        team_id,
        team_name,
        team_logo,
        goals_cumulative,
        assists_cumulative,
        minutes_cumulative,
        rank_at_match,
        medal,
        is_current_top_3
    FROM singhal.fifa_worldcup_gold.gold_golden_boot_race
    WHERE rank_at_match <= 3
    ORDER BY match_sequence, rank_at_match;
  `,
};
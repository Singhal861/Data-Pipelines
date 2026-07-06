{{config(
    materialized='table',
    tags=['gold', 'dashboard', 'golden_boot', 'line_graph']
)}}

-- gold_golden_boot_race: Match-by-match Golden Boot race progression (Requirement #6)
-- FIX: For each match, use the LATEST snapshot available for each player up to that match
-- This ensures eliminated players' stats freeze but remain in rankings
-- Uses clean silver_player_stats_history (no name inconsistencies)

WITH timezone_ref AS (
    SELECT * FROM {{ source('silver', 'ref_stadium_enriched') }}
),

-- Get match sequence based on UTC time
matches_with_sequence AS (
    SELECT
        m.match_id,
        TO_TIMESTAMP(
            REGEXP_REPLACE(m.match_date_local, ' [A-Z]{3,4}$', ''),
            'MM/dd/yyyy HH:mm'
        ) + MAKE_DT_INTERVAL(0, tz.utc_offset_hours, 0, 0) AS match_datetime_utc,
        ROW_NUMBER() OVER (ORDER BY 
            TO_TIMESTAMP(
                REGEXP_REPLACE(m.match_date_local, ' [A-Z]{3,4}$', ''),
                'MM/dd/yyyy HH:mm'
            ) + MAKE_DT_INTERVAL(0, tz.utc_offset_hours, 0, 0)
        ) AS match_sequence
    FROM {{ ref('silver_matches') }} m
    JOIN timezone_ref tz ON m.stadium_id = tz.stadium_id
    WHERE m.is_finished = TRUE
),

-- For EACH match, get the LATEST snapshot available for EACH player up to that match
-- Key insight: Eliminated players' last snapshot carries forward through all future matches
player_stats_at_each_match AS (
    SELECT
        mws.match_sequence,
        ps.player_id,
        ps.goals_scored,
        ps.assists,
        ps.minutes_played,
        ps.valid_from,
        ROW_NUMBER() OVER (
            PARTITION BY mws.match_sequence, ps.player_id
            ORDER BY ps.valid_from DESC
        ) AS rn
    FROM matches_with_sequence mws
    CROSS JOIN {{ ref('silver_player_stats_history') }} ps
    WHERE ps.valid_from <= mws.match_datetime_utc  -- Only snapshots before or at this match
        AND ps.goals_scored > 0  -- Only players who have scored
),

-- Keep only the latest snapshot per player per match
latest_snapshot_per_match AS (
    SELECT
        match_sequence,
        player_id,
        goals_scored AS goals_cumulative,
        assists AS assists_cumulative,
        minutes_played AS minutes_cumulative
    FROM player_stats_at_each_match
    WHERE rn = 1  -- Latest snapshot for this player at this match
),

-- Join with player metadata for names, logos, team info
player_stats_enriched AS (
    SELECT
        lspm.match_sequence,
        lspm.player_id,
        p.player_name,
        p.player_logo,
        p.team_id,
        lspm.goals_cumulative,
        lspm.assists_cumulative,
        lspm.minutes_cumulative
    FROM latest_snapshot_per_match lspm
    LEFT JOIN {{ ref('silver_players') }} p ON lspm.player_id = p.player_id
),

-- Rank players at each match sequence with FIFA Golden Boot tiebreaker
with_ranking AS (
    SELECT
        pse.*,
        DENSE_RANK() OVER (
            PARTITION BY pse.match_sequence
            ORDER BY 
                pse.goals_cumulative DESC,      -- Primary: Most goals
                pse.assists_cumulative DESC,    -- Tiebreaker 1: Most assists
                pse.minutes_cumulative ASC      -- Tiebreaker 2: Fewer minutes
        ) AS rank_at_match
    FROM player_stats_enriched pse
),

-- Filter to top 3 ranks at each match
top_3_at_each_match AS (
    SELECT
        wr.*,
        t.team_name,
        t.team_logo
    FROM with_ranking wr
    LEFT JOIN {{ ref('silver_teams') }} t ON wr.team_id = t.team_id
    WHERE wr.rank_at_match <= 3
)

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
    CASE 
        WHEN rank_at_match = 1 THEN '🥇'
        WHEN rank_at_match = 2 THEN '🥈'
        WHEN rank_at_match = 3 THEN '🥉'
    END AS medal,
    CASE 
        WHEN match_sequence = (SELECT MAX(match_sequence) FROM matches_with_sequence)
        THEN TRUE 
        ELSE FALSE 
    END AS is_current_top_3,
    CURRENT_TIMESTAMP() AS last_updated
FROM top_3_at_each_match
ORDER BY match_sequence, rank_at_match, player_name

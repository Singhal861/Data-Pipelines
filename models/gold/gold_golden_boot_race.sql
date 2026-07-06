{{config(
    materialized='table',
    tags=['gold', 'dashboard', 'golden_boot', 'line_graph']
)}}

-- gold_golden_boot_race: Match-by-match Golden Boot race progression (Requirement #6)
-- Shows FULL history of whoever is CURRENTLY in top 3 (for line graph visualization)
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

-- Get the latest match sequence
latest_match AS (
    SELECT MAX(match_sequence) AS max_sequence
    FROM matches_with_sequence
),

-- For each player, get their latest snapshot (as of latest match)
player_latest_stats AS (
    SELECT
        ps.player_id,
        ps.goals_scored,
        ps.assists,
        ps.minutes_played,
        ROW_NUMBER() OVER (
            PARTITION BY ps.player_id
            ORDER BY ps.valid_from DESC
        ) AS rn
    FROM {{ ref('silver_player_stats_history') }} ps
    CROSS JOIN latest_match lm
    CROSS JOIN matches_with_sequence mws
    WHERE mws.match_sequence = lm.max_sequence
        AND ps.valid_from <= mws.match_datetime_utc
        AND ps.goals_scored > 0
),

-- Identify CURRENT top 3 players (at latest match)
current_top_3_players AS (
    SELECT
        player_id,
        goals_scored,
        assists,
        minutes_played,
        DENSE_RANK() OVER (
            ORDER BY 
                goals_scored DESC,
                assists DESC,
                minutes_played ASC
        ) AS rank_current
    FROM player_latest_stats
    WHERE rn = 1
    QUALIFY rank_current <= 3  -- Only keep top 3
),

-- For these top 3 players, get their stats at EVERY match sequence
top_3_full_history AS (
    SELECT
        mws.match_sequence,
        ct3.player_id,
        ps.goals_scored,
        ps.assists,
        ps.minutes_played,
        ps.valid_from,
        ROW_NUMBER() OVER (
            PARTITION BY mws.match_sequence, ct3.player_id
            ORDER BY ps.valid_from DESC
        ) AS rn
    FROM matches_with_sequence mws
    CROSS JOIN current_top_3_players ct3
    INNER JOIN {{ ref('silver_player_stats_history') }} ps 
        ON ps.player_id = ct3.player_id
    WHERE ps.valid_from <= mws.match_datetime_utc
),

-- Keep only latest snapshot per player per match
latest_snapshot_per_match AS (
    SELECT
        match_sequence,
        player_id,
        goals_scored AS goals_cumulative,
        assists AS assists_cumulative,
        minutes_played AS minutes_cumulative
    FROM top_3_full_history
    WHERE rn = 1
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

-- Rank these 3 players at each match (among themselves)
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

-- Add team info
enriched AS (
    SELECT
        wr.match_sequence,
        wr.player_id,
        wr.player_name,
        wr.player_logo,
        wr.team_id,
        t.team_name,
        t.team_logo,
        wr.goals_cumulative,
        wr.assists_cumulative,
        wr.minutes_cumulative,
        wr.rank_at_match
    FROM with_ranking wr
    LEFT JOIN {{ ref('silver_teams') }} t ON wr.team_id = t.team_id
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
FROM enriched
ORDER BY match_sequence, rank_at_match, player_name

{{config(
    materialized='table',
    tags=['gold', 'dashboard', 'golden_boot', 'line_graph']
)}}

-- gold_golden_boot_race: Match-by-match Golden Boot race progression (Requirement #6)
-- Uses player_stats_history snapshots to track cumulative goals over time
-- Dynamic top 3 with FIFA tiebreaker rules and tie handling (1,1,2 or 1,2,2 or 1,2,3,3)

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

-- Get all player stats snapshots with match sequence
player_stats_timeline AS (
    SELECT
        ps.player_id,
        p.player_name,
        p.player_logo,  -- ✅ Player image URL
        p.team_id,
        ps.goals_scored,
        ps.assists,
        ps.minutes_played,
        ps.valid_from,
        -- Find the match sequence that corresponds to this snapshot
        (
            SELECT MAX(match_sequence) 
            FROM matches_with_sequence mws
            WHERE mws.match_datetime_utc <= ps.valid_from
        ) AS match_sequence
    FROM {{ ref('silver_player_stats_history') }} ps
    JOIN {{ ref('silver_players') }} p ON ps.player_id = p.player_id
    WHERE ps.goals_scored > 0
),

-- Get latest stats per player per match sequence
player_stats_per_match AS (
    SELECT
        player_id,
        player_name,
        player_logo,  -- ✅ Player image URL
        team_id,
        match_sequence,
        goals_scored,
        assists,
        minutes_played,
        ROW_NUMBER() OVER (
            PARTITION BY player_id, match_sequence 
            ORDER BY valid_from DESC
        ) AS rn
    FROM player_stats_timeline
    WHERE match_sequence IS NOT NULL
),

-- Deduplicate to one record per player per match
deduplicated_stats AS (
    SELECT
        player_id,
        player_name,
        player_logo,  -- ✅ FIX: Added player_logo here
        team_id,
        match_sequence,
        goals_scored,
        assists,
        minutes_played
    FROM player_stats_per_match
    WHERE rn = 1
),

-- Rank players at each match sequence with FIFA Golden Boot tiebreaker rules
with_ranking AS (
    SELECT
        ds.*,
        DENSE_RANK() OVER (
            PARTITION BY ds.match_sequence
            ORDER BY 
                ds.goals_scored DESC,      -- Primary: Most goals
                ds.assists DESC,           -- Tiebreaker 1: Most assists
                ds.minutes_played ASC      -- Tiebreaker 2: Fewer minutes
        ) AS rank_at_match
    FROM deduplicated_stats ds
),

-- Filter to top 3 ranks (handles ties: 1,1,2 or 1,2,2 or 1,2,3,3)
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
    player_logo,  -- ✅ Player image URL
    team_id,
    team_name,
    team_logo,
    goals_scored AS goals_cumulative,
    assists AS assists_cumulative,
    minutes_played AS minutes_cumulative,
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

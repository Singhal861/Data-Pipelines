{{config(
    materialized='table',
    tags=['gold', 'dashboard', 'golden_boot', 'line_graph']
)}}

-- gold_golden_boot_race: Match-by-match Golden Boot race progression (Requirement #6)
-- Shows FULL history of ONLY the CURRENT top 3 players
-- Dynamic: updates to show whoever is top 3 right now

WITH timezone_ref AS (
    SELECT * FROM {{ source('silver', 'ref_stadium_enriched') }}
),

-- Get match sequence based on UTC time with smart boundaries
matches_with_sequence AS (
    SELECT
        m.match_id,
        TO_TIMESTAMP(
            REGEXP_REPLACE(m.match_date_local, ' [A-Z]{3,4}$', ''),
            'MM/dd/yyyy HH:mm'
        ) - MAKE_DT_INTERVAL(0, tz.utc_offset_hours, 0, 0) AS match_datetime_utc,
        ROW_NUMBER() OVER (ORDER BY 
            TO_TIMESTAMP(
                REGEXP_REPLACE(m.match_date_local, ' [A-Z]{3,4}$', ''),
                'MM/dd/yyyy HH:mm'
            ) - MAKE_DT_INTERVAL(0, tz.utc_offset_hours, 0, 0)
        ) AS match_sequence,
        -- Get next match datetime to prevent back-to-back overlap
        LEAD(TO_TIMESTAMP(
            REGEXP_REPLACE(m.match_date_local, ' [A-Z]{3,4}$', ''),
            'MM/dd/yyyy HH:mm'
        ) - MAKE_DT_INTERVAL(0, tz.utc_offset_hours, 0, 0)) OVER (ORDER BY 
            TO_TIMESTAMP(
                REGEXP_REPLACE(m.match_date_local, ' [A-Z]{3,4}$', ''),
                'MM/dd/yyyy HH:mm'
            ) - MAKE_DT_INTERVAL(0, tz.utc_offset_hours, 0, 0)
        ) AS next_match_datetime_utc
    FROM {{ ref('silver_matches') }} m
    JOIN timezone_ref tz ON m.stadium_id = tz.stadium_id
    WHERE m.is_finished = TRUE
),

-- For each player, get their LATEST snapshot (as of NOW, not as of latest match)
player_current_stats AS (
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
    WHERE ps.valid_to IS NULL  -- Current snapshot (not closed yet)
        AND ps.goals_scored > 0
),

-- Identify CURRENT top 3 players (as of latest match)
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
        ) AS current_rank
    FROM player_current_stats
    WHERE rn = 1
    QUALIFY current_rank <= 3
),

-- For ONLY these 3 players, get their stats at EVERY match point
top_3_history_at_each_match AS (
    SELECT
        mws.match_sequence,
        mws.match_datetime_utc,
        ct3.player_id,
        ps.goals_scored AS goals_cumulative,
        ps.assists AS assists_cumulative,
        ps.minutes_played AS minutes_cumulative,
        ROW_NUMBER() OVER (
            PARTITION BY mws.match_sequence, ct3.player_id
            ORDER BY ps.valid_from DESC
        ) AS rn
    FROM matches_with_sequence mws
    CROSS JOIN current_top_3_players ct3
    INNER JOIN {{ ref('silver_player_stats_history') }} ps 
        ON ps.player_id = ct3.player_id
    WHERE ps.valid_from <= COALESCE(
        mws.next_match_datetime_utc,  -- Use next match if exists (prevents overlap)
        mws.match_datetime_utc + INTERVAL 24 HOURS  -- Else fall back to 24h for last match
    )
),

-- Keep only latest snapshot per player per match
player_snapshot_per_match AS (
    SELECT
        match_sequence,
        match_datetime_utc,
        player_id,
        goals_cumulative,
        assists_cumulative,
        minutes_cumulative
    FROM top_3_history_at_each_match
    WHERE rn = 1
),

-- Rank these 3 players at each match (among themselves)
ranked_at_each_match AS (
    SELECT
        match_sequence,
        match_datetime_utc,
        player_id,
        goals_cumulative,
        assists_cumulative,
        minutes_cumulative,
        DENSE_RANK() OVER (
            PARTITION BY match_sequence
            ORDER BY 
                goals_cumulative DESC,
                assists_cumulative DESC,
                minutes_cumulative ASC
        ) AS rank_at_match
    FROM player_snapshot_per_match
),

-- Enrich with player metadata
player_stats_enriched AS (
    SELECT
        ram.match_sequence,
        ram.player_id,
        p.player_name,
        p.player_logo,
        p.team_id,
        ram.goals_cumulative,
        ram.assists_cumulative,
        ram.minutes_cumulative,
        ram.rank_at_match
    FROM ranked_at_each_match ram
    LEFT JOIN {{ ref('silver_players') }} p ON ram.player_id = p.player_id
),

-- Add team info
enriched AS (
    SELECT
        pse.match_sequence,
        pse.player_id,
        pse.player_name,
        pse.player_logo,
        pse.team_id,
        t.team_name,
        t.team_logo,
        pse.goals_cumulative,
        pse.assists_cumulative,
        pse.minutes_cumulative,
        pse.rank_at_match
    FROM player_stats_enriched pse
    LEFT JOIN {{ ref('silver_teams') }} t ON pse.team_id = t.team_id
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

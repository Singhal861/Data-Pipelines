{{config(
    materialized='incremental',
    unique_key=['team_id', 'valid_from'],
    tags=['scd_type_2', 'history']
)}}

-- Group standings history with CHANGE DETECTION
-- Only inserts new snapshots when standings actually change
-- Prevents duplicate rows from hourly API refreshes with no matches

WITH latest_bronze AS (
    SELECT
        CAST(team_id AS STRING) AS team_id,
        CAST(team_name AS STRING) AS team_name,
        CAST(group_name AS STRING) AS group_name,
        CAST(matches_played AS INT) AS matches_played,
        CAST(wins AS INT) AS wins,
        CAST(draws AS INT) AS draws,
        CAST(losses AS INT) AS losses,
        CAST(goals_for AS INT) AS goals_for,
        CAST(goals_against AS INT) AS goals_against,
        CAST(goal_difference AS INT) AS goal_difference,
        CAST(points AS INT) AS points,
        ingested_at AS valid_from
        
    FROM {{ source('bronze', 'group_standings') }}
    
    -- Always get latest snapshot from bronze per team
    QUALIFY ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY ingested_at DESC) = 1
),

with_rank AS (
    SELECT
        *,
        -- Compute FIFA tiebreak rank within each group
        DENSE_RANK() OVER (
            PARTITION BY group_name
            ORDER BY 
                points DESC,
                goal_difference DESC,
                goals_for DESC
        ) AS rank
    FROM latest_bronze
)

{% if is_incremental() %}

, latest_history AS (
    SELECT 
        team_id,
        matches_played,
        wins,
        draws,
        losses,
        goals_for,
        goals_against,
        goal_difference,
        points,
        rank
    FROM {{ this }}
    WHERE is_current = TRUE
),

changed_records AS (
    -- Only keep records where standings CHANGED
    SELECT b.*
    FROM with_rank b
    LEFT JOIN latest_history h ON b.team_id = h.team_id
    WHERE h.team_id IS NULL  -- New team
       OR b.points != h.points
       OR b.wins != h.wins
       OR b.draws != h.draws
       OR b.losses != h.losses
       OR b.goals_for != h.goals_for
       OR b.goals_against != h.goals_against
       OR b.matches_played != h.matches_played
)

SELECT
    team_id,
    team_name,
    group_name,
    matches_played,
    wins,
    draws,
    losses,
    goals_for,
    goals_against,
    goal_difference,
    points,
    rank,
    valid_from,
    CAST(NULL AS TIMESTAMP) AS valid_to,
    TRUE AS is_current
FROM changed_records

{% else %}

-- First run: load all teams
SELECT
    team_id,
    team_name,
    group_name,
    matches_played,
    wins,
    draws,
    losses,
    goals_for,
    goals_against,
    goal_difference,
    points,
    rank,
    valid_from,
    CAST(NULL AS TIMESTAMP) AS valid_to,
    TRUE AS is_current
FROM with_rank

{% endif %}
{{config(
    materialized='incremental',
    unique_key=['team_id', 'valid_from'],
    tags=['scd_type_2', 'history'],
    pre_hook=[
        "{% if is_incremental() %}
         MERGE INTO {{ this }} AS target
         USING (
             WITH latest_bronze AS (
                 SELECT
                     CAST(team_id AS STRING) AS team_id,
                     CAST(matches_played AS INT) AS matches_played,
                     CAST(wins AS INT) AS wins,
                     CAST(draws AS INT) AS draws,
                     CAST(losses AS INT) AS losses,
                     CAST(goals_for AS INT) AS goals_for,
                     CAST(goals_against AS INT) AS goals_against,
                     CAST(points AS INT) AS points
                 FROM {{ source('bronze', 'group_standings') }}
                 QUALIFY ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY ingested_at DESC) = 1
             ),
             current_history AS (
                 SELECT
                     team_id,
                     matches_played,
                     wins,
                     draws,
                     losses,
                     goals_for,
                     goals_against,
                     points
                 FROM {{ this }}
                 WHERE is_current = TRUE
             )
             SELECT DISTINCT b.team_id
             FROM latest_bronze b
             INNER JOIN current_history h ON b.team_id = h.team_id
             WHERE (b.points != h.points
                OR b.wins != h.wins
                OR b.draws != h.draws
                OR b.losses != h.losses
                OR b.goals_for != h.goals_for
                OR b.goals_against != h.goals_against
                OR b.matches_played != h.matches_played)
               AND b.matches_played >= h.matches_played
               AND b.wins >= h.wins
               AND b.draws >= h.draws
               AND b.losses >= h.losses
               AND b.goals_for >= h.goals_for
               AND b.goals_against >= h.goals_against
               AND b.points >= h.points
         ) AS changed_teams
         ON target.team_id = changed_teams.team_id
            AND target.is_current = TRUE
         WHEN MATCHED THEN
           UPDATE SET
             is_current = FALSE,
             valid_to = CURRENT_TIMESTAMP()
         {% endif %}"
    ]
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
    -- Only keep records where standings CHANGED AND are valid
    SELECT b.*
    FROM with_rank b
    LEFT JOIN latest_history h ON b.team_id = h.team_id
    WHERE h.team_id IS NULL  -- New team
       OR (
           -- Standings changed
           (b.points != h.points
            OR b.wins != h.wins
            OR b.draws != h.draws
            OR b.losses != h.losses
            OR b.goals_for != h.goals_for
            OR b.goals_against != h.goals_against
            OR b.matches_played != h.matches_played)
           AND
           -- Data quality: ALL cumulative stats validated (World Cup context)
           b.matches_played >= h.matches_played
           AND b.wins >= h.wins
           AND b.draws >= h.draws
           AND b.losses >= h.losses
           AND b.goals_for >= h.goals_for
           AND b.goals_against >= h.goals_against
           AND b.points >= h.points
       )
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
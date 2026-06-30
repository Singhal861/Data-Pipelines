{{config(
    materialized='table',
    tags=['dimension', 'scd_type_1', 'current']
)}}

-- Current group standings with FIFA ranking logic
-- Feeds live dashboard

WITH latest_standings AS (
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
        CAST(points AS INT) AS points
    FROM {{ source('bronze', 'group_standings') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY ingested_at DESC) = 1
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
    
    -- FIFA tiebreak: points > goal_diff > goals_for
    DENSE_RANK() OVER (
        PARTITION BY group_name 
        ORDER BY 
            points DESC,
            goal_difference DESC,
            goals_for DESC
    ) AS rank,
    
    CURRENT_TIMESTAMP() AS last_updated
    
FROM latest_standings
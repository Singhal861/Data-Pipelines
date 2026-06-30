{{config(
    materialized='table',
    tags=['dimension', 'scd_type_1']
)}}

-- Silver Teams - Clean team dimension (SCD Type 1)

SELECT
    CAST(team_id AS STRING) AS team_id,
    CAST(team_name AS STRING) AS team_name,
    CAST(group_name AS STRING) AS group_name,
    CAST(team_logo AS STRING) AS team_logo,
    CURRENT_TIMESTAMP() AS last_updated
    
FROM {{ source('bronze', 'teams') }}

-- Deduplicate
QUALIFY ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY ingested_at DESC) = 1
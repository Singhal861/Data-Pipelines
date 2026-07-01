{{config(
    materialized='table',
    tags=['dimension', 'scd_type_1']
)}}

-- Silver Stadiums - Clean venue dimension (SCD Type 1)

SELECT
    CAST(stadium_id AS STRING) AS stadium_id,
    CAST(fifa_name AS STRING) AS name,
    CAST(city_en AS STRING) AS city,
    'USA/Mexico/Canada' AS country,
    CAST(NULL AS INT) AS capacity,
    CURRENT_TIMESTAMP() AS last_updated
    
FROM {{ source('bronze', 'stadiums') }}

-- Deduplicate
QUALIFY ROW_NUMBER() OVER (PARTITION BY stadium_id ORDER BY ingested_at DESC) = 1
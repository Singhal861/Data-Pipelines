-- Test: All matches must have timezone mapping in ref_stadium_enriched
-- Fails if: Any match has a stadium without timezone data

SELECT 
    m.match_id,
    m.stadium_id,
    s.name AS stadium_name,
    'Missing timezone mapping' AS error_reason
FROM {{ ref('silver_matches') }} m
JOIN {{ ref('silver_stadiums') }} s ON m.stadium_id = s.stadium_id
LEFT JOIN {{ source('silver', 'ref_stadium_enriched') }} tz 
    ON m.stadium_id = tz.stadium_id
WHERE tz.stadium_id IS NULL
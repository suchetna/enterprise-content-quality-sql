/*
02_invalid_taxonomy.sql
Validates asset metadata against the approved controlled vocabulary.
SQLite compatible.
*/

WITH taxonomy_checks AS (
    SELECT asset_id, asset_title, 'Region' AS taxonomy_type, region AS asset_value
    FROM content_assets
    UNION ALL
    SELECT asset_id, asset_title, 'Campaign', campaign FROM content_assets
    UNION ALL
    SELECT asset_id, asset_title, 'Programme', programme FROM content_assets
    UNION ALL
    SELECT asset_id, asset_title, 'Product', product_name FROM content_assets
    UNION ALL
    SELECT asset_id, asset_title, 'Asset Class', asset_class FROM content_assets
    UNION ALL
    SELECT asset_id, asset_title, 'Audience', audience FROM content_assets
    UNION ALL
    SELECT asset_id, asset_title, 'Content Type', content_type FROM content_assets
    UNION ALL
    SELECT asset_id, asset_title, 'Channel', primary_channel FROM content_assets
)
SELECT
    tc.asset_id,
    tc.asset_title,
    tc.taxonomy_type,
    tc.asset_value,
    CASE
        WHEN tc.asset_value IS NULL OR TRIM(tc.asset_value) = '' THEN 'Missing value'
        WHEN t.taxonomy_id IS NULL THEN 'Unapproved value'
        WHEN t.approved_status = 0 THEN 'Retired or unapproved value'
        ELSE 'Valid'
    END AS validation_result
FROM taxonomy_checks tc
LEFT JOIN taxonomy t
    ON t.taxonomy_type = tc.taxonomy_type
   AND LOWER(TRIM(t.taxonomy_value)) = LOWER(TRIM(tc.asset_value))
WHERE tc.asset_value IS NULL
   OR TRIM(tc.asset_value) = ''
   OR t.taxonomy_id IS NULL
   OR t.approved_status = 0
ORDER BY tc.asset_id, tc.taxonomy_type;

-- Summary by taxonomy dimension
WITH taxonomy_checks AS (
    SELECT 'Region' AS taxonomy_type, region AS asset_value FROM content_assets
    UNION ALL SELECT 'Campaign', campaign FROM content_assets
    UNION ALL SELECT 'Programme', programme FROM content_assets
    UNION ALL SELECT 'Product', product_name FROM content_assets
    UNION ALL SELECT 'Asset Class', asset_class FROM content_assets
    UNION ALL SELECT 'Audience', audience FROM content_assets
    UNION ALL SELECT 'Content Type', content_type FROM content_assets
    UNION ALL SELECT 'Channel', primary_channel FROM content_assets
)
SELECT
    tc.taxonomy_type,
    COUNT(*) AS values_checked,
    SUM(CASE
        WHEN tc.asset_value IS NULL OR TRIM(tc.asset_value) = ''
          OR t.taxonomy_id IS NULL OR t.approved_status = 0
        THEN 1 ELSE 0 END) AS invalid_or_missing_values,
    ROUND(100.0 * SUM(CASE
        WHEN tc.asset_value IS NULL OR TRIM(tc.asset_value) = ''
          OR t.taxonomy_id IS NULL OR t.approved_status = 0
        THEN 1 ELSE 0 END) / COUNT(*), 1) AS exception_rate_pct
FROM taxonomy_checks tc
LEFT JOIN taxonomy t
    ON t.taxonomy_type = tc.taxonomy_type
   AND LOWER(TRIM(t.taxonomy_value)) = LOWER(TRIM(tc.asset_value))
GROUP BY tc.taxonomy_type
ORDER BY exception_rate_pct DESC, tc.taxonomy_type;

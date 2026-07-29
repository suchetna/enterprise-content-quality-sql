/*
01_metadata_completeness.sql
Identifies incomplete mandatory metadata and calculates completeness rates.
SQLite compatible.
*/

-- Asset-level metadata audit
SELECT
    ca.asset_id,
    ca.asset_title,
    co.owner_name,
    ca.region,
    ca.content_type,
    ca.content_status,
    ca.metadata_complete,
    TRIM(
        CASE WHEN ca.content_type IS NULL OR ca.content_type = '' THEN 'content_type; ' ELSE '' END ||
        CASE WHEN ca.region IS NULL OR ca.region = '' THEN 'region; ' ELSE '' END ||
        CASE WHEN ca.campaign IS NULL OR ca.campaign = '' THEN 'campaign; ' ELSE '' END ||
        CASE WHEN ca.programme IS NULL OR ca.programme = '' THEN 'programme; ' ELSE '' END ||
        CASE WHEN ca.product_name IS NULL OR ca.product_name = '' THEN 'product_name; ' ELSE '' END ||
        CASE WHEN ca.asset_class IS NULL OR ca.asset_class = '' THEN 'asset_class; ' ELSE '' END ||
        CASE WHEN ca.audience IS NULL OR ca.audience = '' THEN 'audience; ' ELSE '' END ||
        CASE WHEN ca.primary_channel IS NULL OR ca.primary_channel = '' THEN 'primary_channel; ' ELSE '' END ||
        CASE WHEN ca.owner_id IS NULL THEN 'owner_id; ' ELSE '' END ||
        CASE WHEN ca.review_date IS NULL THEN 'review_date; ' ELSE '' END ||
        CASE WHEN ca.expiry_date IS NULL THEN 'expiry_date; ' ELSE '' END ||
        CASE WHEN ca.source_url IS NULL OR ca.source_url = '' THEN 'source_url; ' ELSE '' END,
        '; '
    ) AS missing_fields
FROM content_assets ca
LEFT JOIN content_owners co ON ca.owner_id = co.owner_id
WHERE ca.metadata_complete = 0
   OR ca.content_type IS NULL OR ca.content_type = ''
   OR ca.region IS NULL OR ca.region = ''
   OR ca.campaign IS NULL OR ca.campaign = ''
   OR ca.programme IS NULL OR ca.programme = ''
   OR ca.product_name IS NULL OR ca.product_name = ''
   OR ca.asset_class IS NULL OR ca.asset_class = ''
   OR ca.audience IS NULL OR ca.audience = ''
   OR ca.primary_channel IS NULL OR ca.primary_channel = ''
   OR ca.owner_id IS NULL
   OR ca.review_date IS NULL
   OR ca.expiry_date IS NULL
   OR ca.source_url IS NULL OR ca.source_url = ''
ORDER BY co.owner_name, ca.asset_id;

-- Portfolio-level completeness KPI
SELECT
    COUNT(*) AS total_assets,
    SUM(CASE WHEN metadata_complete = 1 THEN 1 ELSE 0 END) AS complete_assets,
    SUM(CASE WHEN metadata_complete = 0 THEN 1 ELSE 0 END) AS incomplete_assets,
    ROUND(100.0 * SUM(CASE WHEN metadata_complete = 1 THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS metadata_completeness_rate_pct
FROM content_assets;

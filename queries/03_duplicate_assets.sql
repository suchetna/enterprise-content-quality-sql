/*
03_duplicate_assets.sql
Flags explicit duplicate groups and likely title duplicates.
SQLite compatible.
*/

-- Explicitly tagged duplicate groups
SELECT
    duplicate_group_id,
    COUNT(*) AS asset_count,
    GROUP_CONCAT(asset_id) AS asset_ids,
    GROUP_CONCAT(asset_title, ' | ') AS asset_titles
FROM content_assets
WHERE duplicate_group_id IS NOT NULL
GROUP BY duplicate_group_id
HAVING COUNT(*) > 1
ORDER BY asset_count DESC, duplicate_group_id;

-- Likely duplicates based on normalised title
WITH normalised_titles AS (
    SELECT
        asset_id,
        asset_title,
        owner_id,
        content_status,
        publication_date,
        LOWER(
            REPLACE(
                REPLACE(
                    REPLACE(TRIM(asset_title), '-', ' '),
                    ':', ''
                ),
                ',', ''
            )
        ) AS normalised_title
    FROM content_assets
)
SELECT
    normalised_title,
    COUNT(*) AS possible_duplicate_count,
    GROUP_CONCAT(asset_id) AS asset_ids,
    GROUP_CONCAT(asset_title, ' | ') AS asset_titles,
    MIN(publication_date) AS earliest_publication_date,
    MAX(publication_date) AS latest_publication_date
FROM normalised_titles
GROUP BY normalised_title
HAVING COUNT(*) > 1
ORDER BY possible_duplicate_count DESC, normalised_title;

-- Assets already recorded with duplicate-content issues
SELECT
    ca.asset_id,
    ca.asset_title,
    co.owner_name,
    ci.severity,
    ci.issue_status,
    ci.identified_date,
    ci.resolution_date
FROM content_issues ci
JOIN content_assets ca ON ci.asset_id = ca.asset_id
LEFT JOIN content_owners co ON ca.owner_id = co.owner_id
WHERE ci.issue_type = 'Duplicate Content'
ORDER BY
    CASE ci.issue_status
        WHEN 'Open' THEN 1
        WHEN 'In Progress' THEN 2
        WHEN 'Escalated' THEN 3
        ELSE 4
    END,
    ci.severity DESC;

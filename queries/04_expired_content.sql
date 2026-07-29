/*
04_expired_content.sql
Identifies expired, overdue-for-review, and soon-to-expire assets.
Reference date: 2026-07-29.
SQLite compatible.
*/

WITH governed_assets AS (
    SELECT
        ca.*,
        co.owner_name,
        CAST(julianday('2026-07-29') - julianday(ca.expiry_date) AS INTEGER) AS days_past_expiry,
        CAST(julianday(ca.expiry_date) - julianday('2026-07-29') AS INTEGER) AS days_until_expiry,
        CAST(julianday('2026-07-29') - julianday(ca.review_date) AS INTEGER) AS days_review_overdue
    FROM content_assets ca
    LEFT JOIN content_owners co ON ca.owner_id = co.owner_id
)
SELECT
    asset_id,
    asset_title,
    owner_name,
    region,
    content_type,
    content_status,
    review_date,
    expiry_date,
    CASE
        WHEN expiry_date < '2026-07-29'
             AND content_status NOT IN ('Archived', 'Expired') THEN 'Expired but still active'
        WHEN expiry_date < '2026-07-29' THEN 'Expired and labelled'
        WHEN review_date < '2026-07-29' THEN 'Review overdue'
        WHEN expiry_date BETWEEN '2026-07-29' AND date('2026-07-29', '+90 days') THEN 'Expiring within 90 days'
        ELSE 'Current'
    END AS governance_status,
    days_past_expiry,
    days_until_expiry,
    days_review_overdue
FROM governed_assets
WHERE expiry_date < '2026-07-29'
   OR review_date < '2026-07-29'
   OR expiry_date BETWEEN '2026-07-29' AND date('2026-07-29', '+90 days')
ORDER BY
    CASE
        WHEN expiry_date < '2026-07-29' AND content_status NOT IN ('Archived', 'Expired') THEN 1
        WHEN expiry_date < '2026-07-29' THEN 2
        WHEN review_date < '2026-07-29' THEN 3
        ELSE 4
    END,
    expiry_date;

-- Expiry-risk summary
SELECT
    SUM(CASE WHEN expiry_date < '2026-07-29' THEN 1 ELSE 0 END) AS expired_assets,
    SUM(CASE WHEN expiry_date < '2026-07-29'
              AND content_status NOT IN ('Archived', 'Expired') THEN 1 ELSE 0 END) AS expired_but_active,
    SUM(CASE WHEN review_date < '2026-07-29' THEN 1 ELSE 0 END) AS overdue_reviews,
    SUM(CASE WHEN expiry_date BETWEEN '2026-07-29' AND date('2026-07-29', '+90 days')
             THEN 1 ELSE 0 END) AS expiring_next_90_days
FROM content_assets;

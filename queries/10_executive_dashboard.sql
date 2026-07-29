/*
10_executive_dashboard.sql
Produces executive-level content governance KPIs in a single result set.
Reference date: 2026-07-29.
SQLite compatible.
*/

WITH
asset_kpis AS (
    SELECT
        COUNT(*) AS total_assets,
        SUM(CASE WHEN metadata_complete = 1 THEN 1 ELSE 0 END) AS metadata_complete_assets,
        SUM(CASE WHEN accessibility_status = 'Compliant' THEN 1 ELSE 0 END) AS accessible_assets,
        SUM(CASE WHEN expiry_date < '2026-07-29' THEN 1 ELSE 0 END) AS expired_assets,
        SUM(CASE WHEN expiry_date < '2026-07-29'
                  AND content_status NOT IN ('Archived', 'Expired') THEN 1 ELSE 0 END) AS expired_active_assets,
        SUM(CASE WHEN review_date < '2026-07-29' THEN 1 ELSE 0 END) AS overdue_reviews
    FROM content_assets
),
issue_kpis AS (
    SELECT
        COUNT(*) AS total_issues,
        SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed') THEN 1 ELSE 0 END) AS open_issues,
        SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed')
                  AND severity = 'Critical' THEN 1 ELSE 0 END) AS open_critical_issues,
        SUM(CASE WHEN issue_status IN ('Resolved', 'Closed') THEN 1 ELSE 0 END) AS resolved_issues,
        ROUND(AVG(CASE WHEN resolution_date IS NOT NULL
                       THEN julianday(resolution_date) - julianday(identified_date) END), 1)
            AS average_resolution_days,
        SUM(recurrence_flag) AS recurring_issues
    FROM content_issues
),
distribution_kpis AS (
    SELECT
        COUNT(*) AS total_distribution_events,
        SUM(CASE WHEN distribution_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_events,
        SUM(CASE WHEN distribution_status = 'Failed' THEN 1 ELSE 0 END) AS failed_events,
        SUM(CASE WHEN distribution_status = 'Partially Delivered' THEN 1 ELSE 0 END) AS partial_events,
        ROUND(AVG(CASE WHEN delivery_time_seconds > 0 THEN delivery_time_seconds END), 1)
            AS average_delivery_seconds
    FROM distribution_events
),
engagement_kpis AS (
    SELECT
        SUM(impressions) AS impressions,
        SUM(views) AS views,
        SUM(clicks) AS clicks,
        SUM(downloads) AS downloads,
        SUM(conversions) AS conversions,
        ROUND(100.0 * SUM(clicks) / NULLIF(SUM(impressions), 0), 2) AS ctr_pct,
        ROUND(100.0 * SUM(conversions) / NULLIF(SUM(clicks), 0), 2) AS conversion_rate_pct,
        ROUND(AVG(average_time_seconds), 1) AS average_engagement_seconds,
        ROUND(AVG(bounce_rate), 1) AS average_bounce_rate_pct
    FROM engagement_metrics
)
SELECT 'Content portfolio' AS dashboard_section, 'Total assets' AS metric,
       CAST(total_assets AS TEXT) AS metric_value
FROM asset_kpis
UNION ALL
SELECT 'Content portfolio', 'Metadata completeness rate',
       printf('%.1f%%', 100.0 * metadata_complete_assets / NULLIF(total_assets, 0))
FROM asset_kpis
UNION ALL
SELECT 'Content portfolio', 'Accessibility compliance rate',
       printf('%.1f%%', 100.0 * accessible_assets / NULLIF(total_assets, 0))
FROM asset_kpis
UNION ALL
SELECT 'Content portfolio', 'Expired assets', CAST(expired_assets AS TEXT)
FROM asset_kpis
UNION ALL
SELECT 'Content portfolio', 'Expired but still active', CAST(expired_active_assets AS TEXT)
FROM asset_kpis
UNION ALL
SELECT 'Content portfolio', 'Overdue reviews', CAST(overdue_reviews AS TEXT)
FROM asset_kpis
UNION ALL
SELECT 'Issue management', 'Total issues', CAST(total_issues AS TEXT)
FROM issue_kpis
UNION ALL
SELECT 'Issue management', 'Open issues', CAST(open_issues AS TEXT)
FROM issue_kpis
UNION ALL
SELECT 'Issue management', 'Open critical issues', CAST(open_critical_issues AS TEXT)
FROM issue_kpis
UNION ALL
SELECT 'Issue management', 'Issue closure rate',
       printf('%.1f%%', 100.0 * resolved_issues / NULLIF(total_issues, 0))
FROM issue_kpis
UNION ALL
SELECT 'Issue management', 'Average resolution time',
       printf('%.1f days', average_resolution_days)
FROM issue_kpis
UNION ALL
SELECT 'Issue management', 'Recurring issues', CAST(recurring_issues AS TEXT)
FROM issue_kpis
UNION ALL
SELECT 'Distribution', 'Total distribution events', CAST(total_distribution_events AS TEXT)
FROM distribution_kpis
UNION ALL
SELECT 'Distribution', 'Delivery success rate',
       printf('%.1f%%', 100.0 * delivered_events / NULLIF(total_distribution_events, 0))
FROM distribution_kpis
UNION ALL
SELECT 'Distribution', 'Failed deliveries', CAST(failed_events AS TEXT)
FROM distribution_kpis
UNION ALL
SELECT 'Distribution', 'Partial deliveries', CAST(partial_events AS TEXT)
FROM distribution_kpis
UNION ALL
SELECT 'Distribution', 'Average delivery time',
       printf('%.1f seconds', average_delivery_seconds)
FROM distribution_kpis
UNION ALL
SELECT 'Engagement', 'Total impressions', CAST(impressions AS TEXT)
FROM engagement_kpis
UNION ALL
SELECT 'Engagement', 'Total views', CAST(views AS TEXT)
FROM engagement_kpis
UNION ALL
SELECT 'Engagement', 'Total downloads', CAST(downloads AS TEXT)
FROM engagement_kpis
UNION ALL
SELECT 'Engagement', 'Total conversions', CAST(conversions AS TEXT)
FROM engagement_kpis
UNION ALL
SELECT 'Engagement', 'Click-through rate', printf('%.2f%%', ctr_pct)
FROM engagement_kpis
UNION ALL
SELECT 'Engagement', 'Click-to-conversion rate', printf('%.2f%%', conversion_rate_pct)
FROM engagement_kpis
UNION ALL
SELECT 'Engagement', 'Average engagement time',
       printf('%.1f seconds', average_engagement_seconds)
FROM engagement_kpis
UNION ALL
SELECT 'Engagement', 'Average bounce rate', printf('%.1f%%', average_bounce_rate_pct)
FROM engagement_kpis;

-- Top five assets requiring executive attention
WITH issue_summary AS (
    SELECT
        asset_id,
        SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed') THEN 1 ELSE 0 END) AS open_issues,
        SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed') AND severity = 'Critical' THEN 1 ELSE 0 END) AS open_critical,
        SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed') AND severity = 'High' THEN 1 ELSE 0 END) AS open_high
    FROM content_issues
    GROUP BY asset_id
),
distribution_summary AS (
    SELECT
        asset_id,
        COUNT(*) AS total_events,
        SUM(CASE WHEN distribution_status IN ('Failed', 'Partially Delivered') THEN 1 ELSE 0 END)
            AS impaired_events
    FROM distribution_events
    GROUP BY asset_id
)
SELECT
    ca.asset_id,
    ca.asset_title,
    co.owner_name,
    ca.content_status,
    COALESCE(i.open_issues, 0) AS open_issues,
    COALESCE(i.open_critical, 0) AS open_critical,
    COALESCE(i.open_high, 0) AS open_high,
    COALESCE(d.impaired_events, 0) AS impaired_distribution_events,
    (
        COALESCE(i.open_critical, 0) * 12
        + COALESCE(i.open_high, 0) * 6
        + COALESCE(i.open_issues, 0) * 2
        + CASE WHEN ca.metadata_complete = 0 THEN 4 ELSE 0 END
        + CASE WHEN ca.accessibility_status = 'Non-Compliant' THEN 5
               WHEN ca.accessibility_status = 'Partially Compliant' THEN 2 ELSE 0 END
        + CASE WHEN ca.expiry_date < '2026-07-29' THEN 6 ELSE 0 END
        + COALESCE(d.impaired_events, 0) * 2
    ) AS executive_risk_score
FROM content_assets ca
LEFT JOIN content_owners co ON ca.owner_id = co.owner_id
LEFT JOIN issue_summary i ON ca.asset_id = i.asset_id
LEFT JOIN distribution_summary d ON ca.asset_id = d.asset_id
ORDER BY executive_risk_score DESC, ca.asset_id
LIMIT 5;

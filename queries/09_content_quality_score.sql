/*
09_content_quality_score.sql
Creates a transparent 100-point content quality score.
Reference date: 2026-07-29.
SQLite compatible.

Scoring model:
- Metadata completeness: 25 points
- Accessibility: 20 points
- Lifecycle currency: 20 points
- Issue health: 20 points
- Distribution reliability: 15 points
*/

WITH issue_summary AS (
    SELECT
        asset_id,
        SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed') THEN 1 ELSE 0 END) AS open_issues,
        SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed')
                  AND severity = 'Critical' THEN 1 ELSE 0 END) AS open_critical,
        SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed')
                  AND severity = 'High' THEN 1 ELSE 0 END) AS open_high
    FROM content_issues
    GROUP BY asset_id
),
distribution_summary AS (
    SELECT
        asset_id,
        COUNT(*) AS distribution_events,
        SUM(CASE WHEN distribution_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_events
    FROM distribution_events
    GROUP BY asset_id
),
scored AS (
    SELECT
        ca.asset_id,
        ca.asset_title,
        ca.content_type,
        ca.region,
        co.owner_name,
        CASE WHEN ca.metadata_complete = 1 THEN 25 ELSE 0 END AS metadata_points,
        CASE ca.accessibility_status
            WHEN 'Compliant' THEN 20
            WHEN 'Partially Compliant' THEN 12
            WHEN 'Not Assessed' THEN 5
            WHEN 'Non-Compliant' THEN 0
            ELSE 0
        END AS accessibility_points,
        CASE
            WHEN ca.content_status IN ('Archived', 'Expired') THEN 0
            WHEN ca.expiry_date < '2026-07-29' THEN 0
            WHEN ca.review_date < '2026-07-29' THEN 8
            WHEN ca.expiry_date <= date('2026-07-29', '+90 days') THEN 12
            ELSE 20
        END AS lifecycle_points,
        CASE
            WHEN COALESCE(i.open_critical, 0) > 0 THEN 0
            WHEN COALESCE(i.open_high, 0) > 0 THEN 8
            WHEN COALESCE(i.open_issues, 0) > 0 THEN 14
            ELSE 20
        END AS issue_points,
        CASE
            WHEN COALESCE(d.distribution_events, 0) = 0 THEN 5
            ELSE ROUND(15.0 * d.delivered_events / d.distribution_events, 1)
        END AS distribution_points,
        COALESCE(i.open_issues, 0) AS open_issues,
        COALESCE(d.distribution_events, 0) AS distribution_events,
        COALESCE(d.delivered_events, 0) AS delivered_events
    FROM content_assets ca
    LEFT JOIN content_owners co ON ca.owner_id = co.owner_id
    LEFT JOIN issue_summary i ON ca.asset_id = i.asset_id
    LEFT JOIN distribution_summary d ON ca.asset_id = d.asset_id
)
SELECT
    asset_id,
    asset_title,
    content_type,
    region,
    owner_name,
    metadata_points,
    accessibility_points,
    lifecycle_points,
    issue_points,
    distribution_points,
    ROUND(
        metadata_points + accessibility_points + lifecycle_points
        + issue_points + distribution_points,
        1
    ) AS content_quality_score,
    CASE
        WHEN metadata_points + accessibility_points + lifecycle_points
             + issue_points + distribution_points >= 85 THEN 'Excellent'
        WHEN metadata_points + accessibility_points + lifecycle_points
             + issue_points + distribution_points >= 70 THEN 'Good'
        WHEN metadata_points + accessibility_points + lifecycle_points
             + issue_points + distribution_points >= 50 THEN 'Needs attention'
        ELSE 'High risk'
    END AS quality_band,
    open_issues,
    distribution_events,
    delivered_events,
    DENSE_RANK() OVER (
        ORDER BY metadata_points + accessibility_points + lifecycle_points
                 + issue_points + distribution_points ASC
    ) AS remediation_priority_rank
FROM scored
ORDER BY remediation_priority_rank, asset_id;

-- Portfolio quality summary
WITH issue_summary AS (
    SELECT asset_id,
           SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed') THEN 1 ELSE 0 END) AS open_issues,
           SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed') AND severity = 'Critical' THEN 1 ELSE 0 END) AS open_critical,
           SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed') AND severity = 'High' THEN 1 ELSE 0 END) AS open_high
    FROM content_issues GROUP BY asset_id
), distribution_summary AS (
    SELECT asset_id, COUNT(*) AS events,
           SUM(CASE WHEN distribution_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered
    FROM distribution_events GROUP BY asset_id
), scores AS (
    SELECT ca.asset_id,
        CASE WHEN ca.metadata_complete = 1 THEN 25 ELSE 0 END
        + CASE ca.accessibility_status WHEN 'Compliant' THEN 20 WHEN 'Partially Compliant' THEN 12 WHEN 'Not Assessed' THEN 5 ELSE 0 END
        + CASE WHEN ca.content_status IN ('Archived', 'Expired') OR ca.expiry_date < '2026-07-29' THEN 0 WHEN ca.review_date < '2026-07-29' THEN 8 WHEN ca.expiry_date <= date('2026-07-29', '+90 days') THEN 12 ELSE 20 END
        + CASE WHEN COALESCE(i.open_critical,0) > 0 THEN 0 WHEN COALESCE(i.open_high,0) > 0 THEN 8 WHEN COALESCE(i.open_issues,0) > 0 THEN 14 ELSE 20 END
        + CASE WHEN COALESCE(d.events,0)=0 THEN 5 ELSE 15.0*d.delivered/d.events END AS score
    FROM content_assets ca
    LEFT JOIN issue_summary i ON ca.asset_id=i.asset_id
    LEFT JOIN distribution_summary d ON ca.asset_id=d.asset_id
)
SELECT
    ROUND(AVG(score),1) AS average_quality_score,
    SUM(CASE WHEN score >= 85 THEN 1 ELSE 0 END) AS excellent_assets,
    SUM(CASE WHEN score >= 70 AND score < 85 THEN 1 ELSE 0 END) AS good_assets,
    SUM(CASE WHEN score >= 50 AND score < 70 THEN 1 ELSE 0 END) AS needs_attention_assets,
    SUM(CASE WHEN score < 50 THEN 1 ELSE 0 END) AS high_risk_assets
FROM scores;

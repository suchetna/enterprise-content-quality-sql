/*
07_content_owner_backlog.sql
Ranks owners by unresolved workload and governance risk.
Reference date: 2026-07-29.
SQLite compatible.
*/

WITH owner_issue_backlog AS (
    SELECT
        co.owner_id,
        co.owner_name,
        co.owner_team,
        co.owner_region,
        COUNT(ci.issue_id) AS assigned_issues,
        SUM(CASE WHEN ci.issue_status NOT IN ('Resolved', 'Closed') THEN 1 ELSE 0 END) AS open_issues,
        SUM(CASE WHEN ci.issue_status NOT IN ('Resolved', 'Closed')
                  AND ci.severity = 'Critical' THEN 1 ELSE 0 END) AS open_critical,
        SUM(CASE WHEN ci.issue_status NOT IN ('Resolved', 'Closed')
                  AND ci.severity = 'High' THEN 1 ELSE 0 END) AS open_high,
        SUM(CASE WHEN ci.recurrence_flag = 1 THEN 1 ELSE 0 END) AS recurring_issues,
        ROUND(AVG(CASE WHEN ci.issue_status NOT IN ('Resolved', 'Closed')
                       THEN julianday('2026-07-29') - julianday(ci.identified_date) END), 1)
            AS average_open_age_days
    FROM content_owners co
    LEFT JOIN content_issues ci ON co.owner_id = ci.assigned_owner_id
    GROUP BY co.owner_id, co.owner_name, co.owner_team, co.owner_region
),
owner_assets AS (
    SELECT
        owner_id,
        COUNT(*) AS owned_assets,
        SUM(CASE WHEN metadata_complete = 0 THEN 1 ELSE 0 END) AS incomplete_assets,
        SUM(CASE WHEN expiry_date < '2026-07-29'
                  AND content_status NOT IN ('Archived', 'Expired') THEN 1 ELSE 0 END) AS expired_active_assets
    FROM content_assets
    GROUP BY owner_id
)
SELECT
    oib.owner_id,
    oib.owner_name,
    oib.owner_team,
    oib.owner_region,
    COALESCE(oa.owned_assets, 0) AS owned_assets,
    COALESCE(oa.incomplete_assets, 0) AS incomplete_assets,
    COALESCE(oa.expired_active_assets, 0) AS expired_active_assets,
    oib.open_issues,
    oib.open_critical,
    oib.open_high,
    oib.recurring_issues,
    oib.average_open_age_days,
    (
        oib.open_critical * 10
        + oib.open_high * 5
        + oib.open_issues * 2
        + oib.recurring_issues * 3
        + COALESCE(oa.incomplete_assets, 0) * 2
        + COALESCE(oa.expired_active_assets, 0) * 4
    ) AS backlog_risk_score,
    DENSE_RANK() OVER (
        ORDER BY (
            oib.open_critical * 10
            + oib.open_high * 5
            + oib.open_issues * 2
            + oib.recurring_issues * 3
            + COALESCE(oa.incomplete_assets, 0) * 2
            + COALESCE(oa.expired_active_assets, 0) * 4
        ) DESC
    ) AS remediation_priority_rank
FROM owner_issue_backlog oib
LEFT JOIN owner_assets oa ON oib.owner_id = oa.owner_id
ORDER BY remediation_priority_rank, oib.owner_name;

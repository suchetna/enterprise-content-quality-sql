/*
06_issue_resolution_time.sql
Measures resolution speed, ageing, recurrence, and SLA performance.
Reference date: 2026-07-29.
SQLite compatible.
*/

WITH issue_age AS (
    SELECT
        ci.*,
        ca.asset_title,
        co.owner_name,
        CAST(
            julianday(COALESCE(ci.resolution_date, '2026-07-29'))
            - julianday(ci.identified_date)
            AS INTEGER
        ) AS issue_age_days,
        CASE ci.severity
            WHEN 'Critical' THEN 2
            WHEN 'High' THEN 5
            WHEN 'Medium' THEN 10
            WHEN 'Low' THEN 20
        END AS sla_days
    FROM content_issues ci
    JOIN content_assets ca ON ci.asset_id = ca.asset_id
    LEFT JOIN content_owners co ON ci.assigned_owner_id = co.owner_id
)
SELECT
    issue_id,
    asset_title,
    owner_name,
    issue_type,
    severity,
    issue_status,
    identified_date,
    resolution_date,
    issue_age_days,
    sla_days,
    CASE
        WHEN issue_status IN ('Resolved', 'Closed') AND issue_age_days <= sla_days THEN 'Resolved within SLA'
        WHEN issue_status IN ('Resolved', 'Closed') THEN 'Resolved outside SLA'
        WHEN issue_age_days > sla_days THEN 'Open and overdue'
        ELSE 'Open within SLA'
    END AS sla_status,
    recurrence_flag
FROM issue_age
ORDER BY
    CASE
        WHEN issue_status NOT IN ('Resolved', 'Closed') AND issue_age_days > sla_days THEN 1
        WHEN issue_status NOT IN ('Resolved', 'Closed') THEN 2
        ELSE 3
    END,
    issue_age_days DESC;

-- Resolution performance by issue type
SELECT
    issue_type,
    COUNT(*) AS total_issues,
    SUM(CASE WHEN issue_status IN ('Resolved', 'Closed') THEN 1 ELSE 0 END) AS resolved_issues,
    SUM(CASE WHEN issue_status NOT IN ('Resolved', 'Closed') THEN 1 ELSE 0 END) AS open_issues,
    ROUND(AVG(CASE WHEN resolution_date IS NOT NULL
                   THEN julianday(resolution_date) - julianday(identified_date) END), 1)
        AS average_resolution_days,
    SUM(recurrence_flag) AS recurring_issues
FROM content_issues
GROUP BY issue_type
ORDER BY open_issues DESC, average_resolution_days DESC;

-- Overall SLA and closure KPIs
WITH measured AS (
    SELECT
        issue_status,
        severity,
        CAST(julianday(COALESCE(resolution_date, '2026-07-29')) - julianday(identified_date) AS INTEGER)
            AS age_days,
        CASE severity
            WHEN 'Critical' THEN 2
            WHEN 'High' THEN 5
            WHEN 'Medium' THEN 10
            WHEN 'Low' THEN 20
        END AS sla_days
    FROM content_issues
)
SELECT
    COUNT(*) AS total_issues,
    SUM(CASE WHEN issue_status IN ('Resolved', 'Closed') THEN 1 ELSE 0 END) AS closed_issues,
    ROUND(100.0 * SUM(CASE WHEN issue_status IN ('Resolved', 'Closed') THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS closure_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN issue_status IN ('Resolved', 'Closed') AND age_days <= sla_days
                           THEN 1 ELSE 0 END)
          / NULLIF(SUM(CASE WHEN issue_status IN ('Resolved', 'Closed') THEN 1 ELSE 0 END), 0), 1)
        AS resolved_within_sla_pct
FROM measured;

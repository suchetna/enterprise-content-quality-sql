/*
05_distribution_failures.sql
Analyses delivery reliability, error patterns, retries, and channel performance.
SQLite compatible.
*/

-- Failure and partial-delivery detail
SELECT
    de.distribution_id,
    de.distribution_date,
    ca.asset_title,
    de.region,
    de.channel,
    de.destination_system,
    de.distribution_status,
    de.error_code,
    de.error_description,
    de.retry_count,
    de.delivery_time_seconds
FROM distribution_events de
JOIN content_assets ca ON de.asset_id = ca.asset_id
WHERE de.distribution_status IN ('Failed', 'Partially Delivered')
ORDER BY de.distribution_date DESC, de.retry_count DESC;

-- Reliability by channel
SELECT
    channel,
    COUNT(*) AS total_events,
    SUM(CASE WHEN distribution_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_events,
    SUM(CASE WHEN distribution_status = 'Failed' THEN 1 ELSE 0 END) AS failed_events,
    SUM(CASE WHEN distribution_status = 'Partially Delivered' THEN 1 ELSE 0 END) AS partial_events,
    ROUND(100.0 * SUM(CASE WHEN distribution_status = 'Delivered' THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS success_rate_pct,
    ROUND(AVG(CASE WHEN delivery_time_seconds > 0 THEN delivery_time_seconds END), 1)
        AS average_delivery_seconds,
    ROUND(AVG(retry_count), 2) AS average_retries
FROM distribution_events
GROUP BY channel
ORDER BY success_rate_pct ASC, total_events DESC;

-- Most common error codes
SELECT
    error_code,
    error_description,
    COUNT(*) AS occurrence_count,
    COUNT(DISTINCT asset_id) AS affected_assets,
    SUM(retry_count) AS total_retries
FROM distribution_events
WHERE error_code IS NOT NULL
GROUP BY error_code, error_description
ORDER BY occurrence_count DESC, total_retries DESC;

-- Failure rate by region
SELECT
    region,
    COUNT(*) AS total_events,
    SUM(CASE WHEN distribution_status IN ('Failed', 'Partially Delivered') THEN 1 ELSE 0 END)
        AS impaired_events,
    ROUND(100.0 * SUM(CASE WHEN distribution_status IN ('Failed', 'Partially Delivered')
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS impairment_rate_pct
FROM distribution_events
GROUP BY region
ORDER BY impairment_rate_pct DESC;

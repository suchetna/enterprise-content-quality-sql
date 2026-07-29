/*
08_engagement_analysis.sql
Evaluates content performance by asset, channel, region, and month.
SQLite compatible.
*/

-- Asset-level engagement performance
SELECT
    ca.asset_id,
    ca.asset_title,
    ca.content_type,
    ca.region,
    ca.primary_channel,
    SUM(em.impressions) AS impressions,
    SUM(em.views) AS views,
    SUM(em.unique_users) AS unique_users,
    SUM(em.downloads) AS downloads,
    SUM(em.clicks) AS clicks,
    SUM(em.conversions) AS conversions,
    ROUND(100.0 * SUM(em.clicks) / NULLIF(SUM(em.impressions), 0), 2) AS click_through_rate_pct,
    ROUND(100.0 * SUM(em.conversions) / NULLIF(SUM(em.clicks), 0), 2) AS click_to_conversion_rate_pct,
    ROUND(AVG(em.average_time_seconds), 1) AS average_engagement_seconds,
    ROUND(AVG(em.bounce_rate), 1) AS average_bounce_rate_pct,
    DENSE_RANK() OVER (
        ORDER BY SUM(em.conversions) DESC, SUM(em.views) DESC
    ) AS performance_rank
FROM engagement_metrics em
JOIN content_assets ca ON em.asset_id = ca.asset_id
GROUP BY
    ca.asset_id,
    ca.asset_title,
    ca.content_type,
    ca.region,
    ca.primary_channel
ORDER BY performance_rank, ca.asset_id;

-- Channel and region performance
SELECT
    em.region,
    em.channel,
    COUNT(DISTINCT em.asset_id) AS active_assets,
    SUM(em.impressions) AS impressions,
    SUM(em.views) AS views,
    SUM(em.clicks) AS clicks,
    SUM(em.conversions) AS conversions,
    ROUND(100.0 * SUM(em.clicks) / NULLIF(SUM(em.impressions), 0), 2) AS ctr_pct,
    ROUND(100.0 * SUM(em.conversions) / NULLIF(SUM(em.clicks), 0), 2) AS conversion_rate_pct,
    ROUND(AVG(em.average_time_seconds), 1) AS average_engagement_seconds,
    ROUND(AVG(em.bounce_rate), 1) AS average_bounce_rate_pct
FROM engagement_metrics em
GROUP BY em.region, em.channel
ORDER BY conversions DESC, ctr_pct DESC;

-- Monthly trend
SELECT
    reporting_month,
    SUM(impressions) AS impressions,
    SUM(views) AS views,
    SUM(clicks) AS clicks,
    SUM(conversions) AS conversions,
    ROUND(100.0 * SUM(clicks) / NULLIF(SUM(impressions), 0), 2) AS ctr_pct,
    ROUND(100.0 * SUM(conversions) / NULLIF(SUM(clicks), 0), 2) AS conversion_rate_pct
FROM engagement_metrics
GROUP BY reporting_month
ORDER BY reporting_month;

-- =============================================================================
-- LISTINGS PUBLISHED PER MONTH BY TYPE
-- =============================================================================
-- Purpose: Track new inventory listings published on the platform
-- Owner: Ian Hong (Supply)
-- Refresh: Daily
--
-- Data Source: mongodb.audience_listings (synced via Fivetran)
-- =============================================================================

SELECT
    DATE_TRUNC(published_at, MONTH) AS month,
    primary_type AS event_type,
    COUNT(DISTINCT _id) AS listings_published,

    -- Month-over-month change
    LAG(COUNT(DISTINCT _id)) OVER (
        PARTITION BY primary_type
        ORDER BY DATE_TRUNC(published_at, MONTH)
    ) AS prev_month_count,

    COUNT(DISTINCT _id) - LAG(COUNT(DISTINCT _id)) OVER (
        PARTITION BY primary_type
        ORDER BY DATE_TRUNC(published_at, MONTH)
    ) AS mom_change,

    -- Percentage change
    ROUND(
        (COUNT(DISTINCT _id) - LAG(COUNT(DISTINCT _id)) OVER (
            PARTITION BY primary_type
            ORDER BY DATE_TRUNC(published_at, MONTH)
        )) * 100.0 / NULLIF(LAG(COUNT(DISTINCT _id)) OVER (
            PARTITION BY primary_type
            ORDER BY DATE_TRUNC(published_at, MONTH)
        ), 0),
        1
    ) AS mom_change_pct

FROM `stitchdata-384118.mongodb.audience_listings`
WHERE published_state = 'published'
  AND is_omnichannel = FALSE
  AND published_at IS NOT NULL
  AND EXTRACT(YEAR FROM published_at) >= 2024
GROUP BY DATE_TRUNC(published_at, MONTH), primary_type
ORDER BY month DESC, listings_published DESC;


-- =============================================================================
-- SUMMARY: Total by month (all types)
-- =============================================================================
/*
SELECT
    DATE_TRUNC(published_at, MONTH) AS month,
    COUNT(DISTINCT _id) AS total_listings_published,
    COUNT(DISTINCT primary_type) AS event_types_count
FROM `stitchdata-384118.mongodb.audience_listings`
WHERE published_state = 'published'
  AND is_omnichannel = FALSE
  AND published_at IS NOT NULL
  AND EXTRACT(YEAR FROM published_at) = EXTRACT(YEAR FROM CURRENT_DATE())
GROUP BY DATE_TRUNC(published_at, MONTH)
ORDER BY month;
*/


-- =============================================================================
-- TOP EVENT TYPES (Current Year)
-- =============================================================================
/*
SELECT
    primary_type AS event_type,
    COUNT(DISTINCT _id) AS total_listings,
    ROUND(COUNT(DISTINCT _id) * 100.0 / SUM(COUNT(DISTINCT _id)) OVER (), 1) AS pct_of_total
FROM `stitchdata-384118.mongodb.audience_listings`
WHERE published_state = 'published'
  AND is_omnichannel = FALSE
  AND EXTRACT(YEAR FROM published_at) = EXTRACT(YEAR FROM CURRENT_DATE())
GROUP BY primary_type
ORDER BY total_listings DESC
LIMIT 20;
*/

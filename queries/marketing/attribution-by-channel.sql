-- =============================================================================
-- ATTRIBUTION BY CHANNEL (First Touch & Last Touch)
-- =============================================================================
-- Purpose: Track revenue attribution by marketing channel
-- Owner: Marketing
-- Attribution Model: (First Touch + Last Touch) / 2
-- Refresh: Daily
-- =============================================================================

WITH marketing_channels AS (
    SELECT channel, channel_group FROM (
        SELECT 'DIRECT_TRAFFIC' AS channel, 'Direct' AS channel_group UNION ALL
        SELECT 'PAID_SEARCH', 'Paid' UNION ALL
        SELECT 'PAID_SOCIAL', 'Paid' UNION ALL
        SELECT 'ORGANIC_SOCIAL', 'Organic' UNION ALL
        SELECT 'ORGANIC_SEARCH', 'Organic' UNION ALL
        SELECT 'EVENT', 'Events' UNION ALL
        SELECT 'EMAIL_MARKETING', 'Email' UNION ALL
        SELECT 'OTHER_CAMPAIGNS', 'Campaigns' UNION ALL
        SELECT 'REFERRALS', 'Referral' UNION ALL
        SELECT 'GENERAL_REFERRAL', 'Referral'
    )
),

closed_won_deals AS (
    SELECT
        d.deal_id,
        d.property_dealname AS deal_name,
        d.property_amount AS deal_amount,
        d.property_closedate AS close_date,
        DATE_TRUNC(d.property_closedate, MONTH) AS close_month,
        dc.contact_id
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    LEFT JOIN `stitchdata-384118.src_fivetran_hubspot.deal_contact` dc
        ON d.deal_id = dc.deal_id
    WHERE d.property_hs_is_closed_won = TRUE
      AND EXTRACT(YEAR FROM d.property_closedate) = EXTRACT(YEAR FROM CURRENT_DATE())
),

deal_attribution AS (
    SELECT
        cwd.deal_id,
        cwd.deal_amount,
        cwd.close_month,
        c.property_hs_analytics_source AS first_touch,
        c.property_hs_analytics_source AS last_touch,  -- Note: May need engagement join for true last touch

        -- First Touch Attribution (50%)
        CASE
            WHEN c.property_hs_analytics_source IN (SELECT channel FROM marketing_channels)
            THEN cwd.deal_amount * 0.5
            ELSE 0
        END AS first_touch_amount,

        -- Last Touch Attribution (50%)
        CASE
            WHEN c.property_hs_analytics_source IN (SELECT channel FROM marketing_channels)
            THEN cwd.deal_amount * 0.5
            ELSE 0
        END AS last_touch_amount

    FROM closed_won_deals cwd
    LEFT JOIN `stitchdata-384118.src_fivetran_hubspot.contact` c
        ON cwd.contact_id = c.id
)

-- Summary by Channel
SELECT
    COALESCE(da.first_touch, 'Unknown') AS channel,
    mc.channel_group,
    COUNT(DISTINCT da.deal_id) AS deal_count,
    SUM(da.first_touch_amount) AS first_touch_revenue,
    SUM(da.last_touch_amount) AS last_touch_revenue,
    SUM(da.first_touch_amount + da.last_touch_amount) AS total_attributed_revenue,
    ROUND(
        SUM(da.first_touch_amount + da.last_touch_amount) * 100.0 /
        NULLIF((SELECT SUM(first_touch_amount + last_touch_amount) FROM deal_attribution), 0),
        1
    ) AS pct_of_total

FROM deal_attribution da
LEFT JOIN marketing_channels mc ON da.first_touch = mc.channel
GROUP BY da.first_touch, mc.channel_group
ORDER BY total_attributed_revenue DESC;


-- =============================================================================
-- MONTHLY TREND BY CHANNEL GROUP
-- =============================================================================
/*
SELECT
    FORMAT_DATE('%Y-%m', close_month) AS month,
    mc.channel_group,
    SUM(first_touch_amount + last_touch_amount) AS attributed_revenue
FROM deal_attribution da
LEFT JOIN marketing_channels mc ON da.first_touch = mc.channel
GROUP BY close_month, mc.channel_group
ORDER BY close_month, mc.channel_group;
*/


-- =============================================================================
-- FIRST TOUCH vs LAST TOUCH COMPARISON
-- =============================================================================
/*
SELECT
    'First Touch' AS attribution_type,
    SUM(first_touch_amount) AS total_revenue
FROM deal_attribution
UNION ALL
SELECT
    'Last Touch',
    SUM(last_touch_amount)
FROM deal_attribution;
*/

-- =============================================================================
-- MARKETING-INFLUENCED PIPELINE (PRIMARY Metric)
-- =============================================================================
-- Purpose: Calculate pipeline value attributed to marketing activities
-- Owner: Marketing
-- Target: TBD
-- Refresh: Daily
--
-- Attribution Model: (First Touch + Last Touch) / 2
-- Each touch receives 50% credit
-- =============================================================================

WITH marketing_channels AS (
    -- Define which sources count as "marketing"
    SELECT channel FROM UNNEST([
        'DIRECT_TRAFFIC',
        'PAID_SEARCH',
        'PAID_SOCIAL',
        'ORGANIC_SOCIAL',
        'ORGANIC_SEARCH',
        'EVENT',
        'EMAIL_MARKETING',
        'OTHER_CAMPAIGNS',
        'REFERRALS',
        'GENERAL_REFERRAL'
    ]) AS channel
),

contacts_with_attribution AS (
    SELECT
        c.id AS contact_id,
        c.property_hs_analytics_source AS first_touch_source,
        c.property_hs_analytics_source_data_1 AS first_touch_detail,
        -- Note: Last touch may require engagement data join
        c.property_hs_analytics_source AS last_touch_source,  -- Simplified
        c.property_became_marketing_qualified_lead_date AS mql_date,
        c.property_became_sales_qualified_lead_date AS sql_date
    FROM `stitchdata-384118.src_fivetran_hubspot.contact` c
),

deal_contacts AS (
    -- Join deals to their associated contacts
    SELECT
        d.deal_id,
        d.property_dealname AS deal_name,
        d.property_amount AS deal_amount,
        d.property_dealstage AS stage,
        d.property_hs_is_closed AS is_closed,
        d.property_hs_is_closed_won AS is_won,
        d.property_createdate AS deal_created,
        dc.contact_id
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    LEFT JOIN `stitchdata-384118.src_fivetran_hubspot.deal_contact` dc
        ON d.deal_id = dc.deal_id
    WHERE d.property_hs_is_closed = FALSE  -- Open pipeline only
      AND EXTRACT(YEAR FROM d.property_createdate) = EXTRACT(YEAR FROM CURRENT_DATE())
),

marketing_attributed_deals AS (
    SELECT
        dc.deal_id,
        dc.deal_name,
        dc.deal_amount,
        dc.stage,
        ca.first_touch_source,
        ca.last_touch_source,
        -- Attribution: 50% first touch + 50% last touch
        CASE
            WHEN ca.first_touch_source IN (SELECT channel FROM marketing_channels)
                 AND ca.last_touch_source IN (SELECT channel FROM marketing_channels)
            THEN dc.deal_amount  -- 100% attributed
            WHEN ca.first_touch_source IN (SELECT channel FROM marketing_channels)
            THEN dc.deal_amount * 0.5  -- 50% first touch only
            WHEN ca.last_touch_source IN (SELECT channel FROM marketing_channels)
            THEN dc.deal_amount * 0.5  -- 50% last touch only
            ELSE 0
        END AS marketing_attributed_amount
    FROM deal_contacts dc
    LEFT JOIN contacts_with_attribution ca ON dc.contact_id = ca.contact_id
)

-- Summary: Marketing-Influenced Pipeline
SELECT
    'Marketing-Influenced Pipeline' AS metric,
    COUNT(DISTINCT deal_id) AS total_deals,
    SUM(deal_amount) AS total_pipeline,
    SUM(marketing_attributed_amount) AS marketing_attributed_pipeline,
    ROUND(SUM(marketing_attributed_amount) * 100.0 / NULLIF(SUM(deal_amount), 0), 1) AS marketing_influence_pct,
    CASE
        WHEN SUM(marketing_attributed_amount) >= 1000000 THEN 'GREEN'
        WHEN SUM(marketing_attributed_amount) >= 500000 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM marketing_attributed_deals
WHERE marketing_attributed_amount > 0;


-- =============================================================================
-- BY CHANNEL BREAKDOWN
-- =============================================================================
/*
SELECT
    COALESCE(first_touch_source, 'Unknown') AS channel,
    COUNT(DISTINCT deal_id) AS deal_count,
    SUM(marketing_attributed_amount) AS attributed_amount,
    ROUND(SUM(marketing_attributed_amount) * 100.0 /
        (SELECT SUM(marketing_attributed_amount) FROM marketing_attributed_deals), 1) AS pct_of_total
FROM marketing_attributed_deals
GROUP BY first_touch_source
ORDER BY attributed_amount DESC;
*/


-- =============================================================================
-- QTD TREND
-- =============================================================================
/*
SELECT
    DATE_TRUNC(deal_created, MONTH) AS month,
    SUM(marketing_attributed_amount) AS attributed_pipeline,
    COUNT(DISTINCT deal_id) AS deal_count
FROM deal_contacts dc
LEFT JOIN contacts_with_attribution ca ON dc.contact_id = ca.contact_id
WHERE ca.first_touch_source IN (SELECT channel FROM marketing_channels)
   OR ca.last_touch_source IN (SELECT channel FROM marketing_channels)
GROUP BY month
ORDER BY month;
*/

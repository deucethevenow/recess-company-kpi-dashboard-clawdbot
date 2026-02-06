-- =============================================================================
-- MARKETING LEADS FUNNEL (ML → MQL → SQL)
-- =============================================================================
-- Purpose: Track marketing lead progression through funnel stages
-- Owner: Marketing
-- Refresh: Daily
--
-- Funnel Stages:
-- 1. Marketing Lead (ML) - Contact with marketing source
-- 2. Marketing Qualified Lead (MQL) - Met qualification criteria
-- 3. Sales Qualified Lead (SQL) - Accepted by sales
-- =============================================================================

WITH lead_stages AS (
    SELECT
        c.id AS contact_id,
        c.property_lifecyclestage AS current_stage,
        c.property_hs_analytics_source AS source,
        c.property_createdate AS contact_created,

        -- Stage timestamps
        c.property_became_marketing_qualified_lead_date AS mql_date,
        c.property_became_sales_qualified_lead_date AS sql_date,

        -- Determine funnel position
        CASE
            WHEN c.property_became_sales_qualified_lead_date IS NOT NULL THEN 'SQL'
            WHEN c.property_became_marketing_qualified_lead_date IS NOT NULL THEN 'MQL'
            WHEN c.property_hs_analytics_source IN (
                'DIRECT_TRAFFIC', 'PAID_SEARCH', 'PAID_SOCIAL', 'ORGANIC_SOCIAL',
                'ORGANIC_SEARCH', 'EVENT', 'EMAIL_MARKETING', 'OTHER_CAMPAIGNS',
                'REFERRALS', 'GENERAL_REFERRAL'
            ) THEN 'ML'
            ELSE 'Non-Marketing'
        END AS funnel_stage

    FROM `stitchdata-384118.src_fivetran_hubspot.contact` c
    WHERE EXTRACT(YEAR FROM c.property_createdate) = EXTRACT(YEAR FROM CURRENT_DATE())
)

-- Funnel Summary (Current Year)
SELECT
    funnel_stage,
    COUNT(*) AS contact_count,
    CASE funnel_stage
        WHEN 'ML' THEN 100.0
        WHEN 'MQL' THEN ROUND(COUNT(*) * 100.0 /
            (SELECT COUNT(*) FROM lead_stages WHERE funnel_stage IN ('ML', 'MQL', 'SQL')), 1)
        WHEN 'SQL' THEN ROUND(COUNT(*) * 100.0 /
            (SELECT COUNT(*) FROM lead_stages WHERE funnel_stage IN ('ML', 'MQL', 'SQL')), 1)
    END AS pct_of_top_funnel,

    CASE
        WHEN funnel_stage = 'ML' THEN
            (SELECT COUNT(*) FROM lead_stages WHERE funnel_stage = 'MQL')
        WHEN funnel_stage = 'MQL' THEN
            (SELECT COUNT(*) FROM lead_stages WHERE funnel_stage = 'SQL')
        ELSE NULL
    END AS converts_to_count,

    CASE
        WHEN funnel_stage = 'ML' THEN
            ROUND((SELECT COUNT(*) FROM lead_stages WHERE funnel_stage = 'MQL') * 100.0 /
                  NULLIF(COUNT(*), 0), 1)
        WHEN funnel_stage = 'MQL' THEN
            ROUND((SELECT COUNT(*) FROM lead_stages WHERE funnel_stage = 'SQL') * 100.0 /
                  NULLIF(COUNT(*), 0), 1)
        ELSE NULL
    END AS stage_conversion_rate

FROM lead_stages
WHERE funnel_stage != 'Non-Marketing'
GROUP BY funnel_stage
ORDER BY
    CASE funnel_stage
        WHEN 'ML' THEN 1
        WHEN 'MQL' THEN 2
        WHEN 'SQL' THEN 3
    END;


-- =============================================================================
-- MONTHLY FUNNEL (MTD)
-- =============================================================================
/*
SELECT
    DATE_TRUNC(contact_created, MONTH) AS month,
    COUNTIF(funnel_stage IN ('ML', 'MQL', 'SQL')) AS marketing_leads,
    COUNTIF(funnel_stage IN ('MQL', 'SQL')) AS mqls,
    COUNTIF(funnel_stage = 'SQL') AS sqls,

    -- Conversion rates
    ROUND(COUNTIF(funnel_stage IN ('MQL', 'SQL')) * 100.0 /
          NULLIF(COUNTIF(funnel_stage IN ('ML', 'MQL', 'SQL')), 0), 1) AS ml_to_mql_rate,
    ROUND(COUNTIF(funnel_stage = 'SQL') * 100.0 /
          NULLIF(COUNTIF(funnel_stage IN ('MQL', 'SQL')), 0), 1) AS mql_to_sql_rate

FROM lead_stages
WHERE funnel_stage != 'Non-Marketing'
GROUP BY month
ORDER BY month DESC;
*/


-- =============================================================================
-- BY SOURCE
-- =============================================================================
/*
SELECT
    COALESCE(source, 'Unknown') AS source,
    COUNTIF(funnel_stage IN ('ML', 'MQL', 'SQL')) AS marketing_leads,
    COUNTIF(funnel_stage IN ('MQL', 'SQL')) AS mqls,
    COUNTIF(funnel_stage = 'SQL') AS sqls,
    ROUND(COUNTIF(funnel_stage = 'SQL') * 100.0 /
          NULLIF(COUNTIF(funnel_stage IN ('ML', 'MQL', 'SQL')), 0), 1) AS full_funnel_conversion
FROM lead_stages
WHERE funnel_stage != 'Non-Marketing'
GROUP BY source
ORDER BY marketing_leads DESC;
*/

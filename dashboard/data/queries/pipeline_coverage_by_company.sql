-- =============================================================================
-- Pipeline Coverage by Quota Type - Company Level View
-- =============================================================================
--
-- Purpose: Track pipeline coverage by quota type at the individual company level
--          with 2025 reference data for the Demand Sales Dashboard
--
-- Created: 2026-02-03
-- View Name: App_KPI_Dashboard.pipeline_coverage_by_company
--
-- Columns:
--   - company_id, company_name, owner_name
--   - quarter: Q1, Q2, Q3, Q4
--   - *_annual_quota: Full year quota by type
--   - *_quarterly_quota: Quarter quota (annual/4)
--   - *_unweighted: Raw pipeline value
--   - *_hs_weighted: HubSpot stage-weighted pipeline
--   - *_ai_weighted: AI quality-weighted pipeline
--   - *_hs_coverage: HS weighted / quarterly quota
--   - *_ai_coverage: AI weighted / quarterly quota
--   - *_2025_won: 2025 closed won for reference
--   - *_2025_close_rate: 2025 win rate (won / (won + lost))
-- =============================================================================

WITH company_quotas AS (
    SELECT
        c.id as company_id,
        c.property_name as company_name,
        COALESCE(o.first_name || ' ' || o.last_name, 'Unassigned') as owner_name,
        COALESCE(SAFE_CAST(c.property_x_2026_new_customer_quota AS FLOAT64), 0) as new_customer_quota,
        COALESCE(SAFE_CAST(c.property_x_2026_renewal_quota AS FLOAT64), 0) as renewal_quota,
        COALESCE(SAFE_CAST(c.property_x_2026_land_expand_quota AS FLOAT64), 0) as land_expand_quota
    FROM `stitchdata-384118.src_fivetran_hubspot.company` c
    LEFT JOIN `stitchdata-384118.src_fivetran_hubspot.owner` o
        ON SAFE_CAST(c.property_hubspot_owner_id AS INT64) = o.owner_id
    WHERE c.property_name IS NOT NULL
      AND (
        SAFE_CAST(c.property_x_2026_new_customer_quota AS FLOAT64) > 0 OR
        SAFE_CAST(c.property_x_2026_renewal_quota AS FLOAT64) > 0 OR
        SAFE_CAST(c.property_x_2026_land_expand_quota AS FLOAT64) > 0
      )
),

-- Open pipeline deals with deduplication (assign to company with highest quota)
deal_to_company AS (
    SELECT
        d.deal_id,
        dc.company_id,
        SAFE_CAST(d.property_amount AS FLOAT64) as deal_amount,
        SAFE_CAST(d.property_hs_forecast_amount AS FLOAT64) as hs_weighted,
        SAFE_CAST(d.property_ai_weighted_forecast AS FLOAT64) as ai_weighted,
        CASE
            WHEN d.property_dealtype = 'newbusiness' THEN 'new_customer'
            WHEN d.property_dealtype IN ('existingbusiness', 'Renewal 2', 'Campaign - Existing') THEN 'renewal'
            WHEN d.property_dealtype = 'Land and Expand' THEN 'land_expand'
            ELSE 'other'
        END as quota_category,
        CONCAT('Q', CAST(EXTRACT(QUARTER FROM d.property_closedate) AS STRING)) as close_quarter,
        ROW_NUMBER() OVER (
            PARTITION BY d.deal_id
            ORDER BY (cq.new_customer_quota + cq.renewal_quota + cq.land_expand_quota) DESC
        ) as rn
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    JOIN `stitchdata-384118.src_fivetran_hubspot.deal_company` dc ON d.deal_id = dc.deal_id
    JOIN company_quotas cq ON dc.company_id = cq.company_id
    WHERE d.deal_pipeline_id = 'default'
      AND d.is_deleted = false
      AND d.property_hs_is_closed = false
      AND EXTRACT(YEAR FROM d.property_closedate) = 2026
),

-- Pipeline by company and quarter (deduplicated)
company_pipeline_by_quarter AS (
    SELECT
        company_id,
        close_quarter,
        -- Unweighted
        SUM(CASE WHEN quota_category = 'new_customer' THEN deal_amount ELSE 0 END) as new_cust_unweighted,
        SUM(CASE WHEN quota_category = 'renewal' THEN deal_amount ELSE 0 END) as renewal_unweighted,
        SUM(CASE WHEN quota_category = 'land_expand' THEN deal_amount ELSE 0 END) as land_exp_unweighted,
        -- HS Weighted
        SUM(CASE WHEN quota_category = 'new_customer' THEN hs_weighted ELSE 0 END) as new_cust_hs_weighted,
        SUM(CASE WHEN quota_category = 'renewal' THEN hs_weighted ELSE 0 END) as renewal_hs_weighted,
        SUM(CASE WHEN quota_category = 'land_expand' THEN hs_weighted ELSE 0 END) as land_exp_hs_weighted,
        -- AI Weighted
        SUM(CASE WHEN quota_category = 'new_customer' THEN ai_weighted ELSE 0 END) as new_cust_ai_weighted,
        SUM(CASE WHEN quota_category = 'renewal' THEN ai_weighted ELSE 0 END) as renewal_ai_weighted,
        SUM(CASE WHEN quota_category = 'land_expand' THEN ai_weighted ELSE 0 END) as land_exp_ai_weighted,
        -- Deal counts
        COUNT(CASE WHEN quota_category = 'new_customer' THEN 1 END) as new_cust_deal_count,
        COUNT(CASE WHEN quota_category = 'renewal' THEN 1 END) as renewal_deal_count,
        COUNT(CASE WHEN quota_category = 'land_expand' THEN 1 END) as land_exp_deal_count
    FROM deal_to_company
    WHERE rn = 1
    GROUP BY company_id, close_quarter
),

-- 2025 Reference: Closed deals by company (deduplicated)
deals_2025 AS (
    SELECT
        d.deal_id,
        dc.company_id,
        SAFE_CAST(d.property_amount AS FLOAT64) as deal_amount,
        d.property_hs_is_closed_won as is_won,
        CASE
            WHEN d.property_dealtype = 'newbusiness' THEN 'new_customer'
            WHEN d.property_dealtype IN ('existingbusiness', 'Renewal 2', 'Campaign - Existing') THEN 'renewal'
            WHEN d.property_dealtype = 'Land and Expand' THEN 'land_expand'
            ELSE 'other'
        END as quota_category,
        ROW_NUMBER() OVER (
            PARTITION BY d.deal_id
            ORDER BY (cq.new_customer_quota + cq.renewal_quota + cq.land_expand_quota) DESC
        ) as rn
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    JOIN `stitchdata-384118.src_fivetran_hubspot.deal_company` dc ON d.deal_id = dc.deal_id
    JOIN company_quotas cq ON dc.company_id = cq.company_id
    WHERE d.deal_pipeline_id = 'default'
      AND d.is_deleted = false
      AND d.property_hs_is_closed = true
      AND EXTRACT(YEAR FROM d.property_closedate) = 2025
),

company_2025_stats AS (
    SELECT
        company_id,
        -- Won by type
        SUM(CASE WHEN is_won AND quota_category = 'new_customer' THEN deal_amount ELSE 0 END) as new_cust_2025_won,
        SUM(CASE WHEN is_won AND quota_category = 'renewal' THEN deal_amount ELSE 0 END) as renewal_2025_won,
        SUM(CASE WHEN is_won AND quota_category = 'land_expand' THEN deal_amount ELSE 0 END) as land_exp_2025_won,
        -- Deal counts for close rate
        COUNT(CASE WHEN is_won AND quota_category = 'new_customer' THEN 1 END) as new_cust_won_count,
        COUNT(CASE WHEN NOT is_won AND quota_category = 'new_customer' THEN 1 END) as new_cust_lost_count,
        COUNT(CASE WHEN is_won AND quota_category = 'renewal' THEN 1 END) as renewal_won_count,
        COUNT(CASE WHEN NOT is_won AND quota_category = 'renewal' THEN 1 END) as renewal_lost_count,
        COUNT(CASE WHEN is_won AND quota_category = 'land_expand' THEN 1 END) as land_exp_won_count,
        COUNT(CASE WHEN NOT is_won AND quota_category = 'land_expand' THEN 1 END) as land_exp_lost_count
    FROM deals_2025
    WHERE rn = 1
    GROUP BY company_id
),

-- Generate all quarters
quarters AS (
    SELECT quarter FROM UNNEST(['Q1', 'Q2', 'Q3', 'Q4']) as quarter
)

-- Final output: All companies x all quarters with metrics
SELECT
    cq.company_id,
    cq.company_name,
    cq.owner_name,
    qtr.quarter,

    -- Annual Quotas
    ROUND(cq.new_customer_quota, 0) as new_cust_annual_quota,
    ROUND(cq.renewal_quota, 0) as renewal_annual_quota,
    ROUND(cq.land_expand_quota, 0) as land_exp_annual_quota,

    -- Quarterly Quotas
    ROUND(cq.new_customer_quota/4, 0) as new_cust_quarterly_quota,
    ROUND(cq.renewal_quota/4, 0) as renewal_quarterly_quota,
    ROUND(cq.land_expand_quota/4, 0) as land_exp_quarterly_quota,

    -- Pipeline Unweighted
    ROUND(COALESCE(p.new_cust_unweighted, 0), 0) as new_cust_unweighted,
    ROUND(COALESCE(p.renewal_unweighted, 0), 0) as renewal_unweighted,
    ROUND(COALESCE(p.land_exp_unweighted, 0), 0) as land_exp_unweighted,

    -- Pipeline HS Weighted
    ROUND(COALESCE(p.new_cust_hs_weighted, 0), 0) as new_cust_hs_weighted,
    ROUND(COALESCE(p.renewal_hs_weighted, 0), 0) as renewal_hs_weighted,
    ROUND(COALESCE(p.land_exp_hs_weighted, 0), 0) as land_exp_hs_weighted,

    -- Pipeline AI Weighted
    ROUND(COALESCE(p.new_cust_ai_weighted, 0), 0) as new_cust_ai_weighted,
    ROUND(COALESCE(p.renewal_ai_weighted, 0), 0) as renewal_ai_weighted,
    ROUND(COALESCE(p.land_exp_ai_weighted, 0), 0) as land_exp_ai_weighted,

    -- Deal Counts
    COALESCE(p.new_cust_deal_count, 0) as new_cust_deal_count,
    COALESCE(p.renewal_deal_count, 0) as renewal_deal_count,
    COALESCE(p.land_exp_deal_count, 0) as land_exp_deal_count,

    -- Coverage (HS Weighted)
    ROUND(COALESCE(p.new_cust_hs_weighted, 0) / NULLIF(cq.new_customer_quota/4, 0), 2) as new_cust_hs_coverage,
    ROUND(COALESCE(p.renewal_hs_weighted, 0) / NULLIF(cq.renewal_quota/4, 0), 2) as renewal_hs_coverage,
    ROUND(COALESCE(p.land_exp_hs_weighted, 0) / NULLIF(cq.land_expand_quota/4, 0), 2) as land_exp_hs_coverage,

    -- Coverage (AI Weighted)
    ROUND(COALESCE(p.new_cust_ai_weighted, 0) / NULLIF(cq.new_customer_quota/4, 0), 2) as new_cust_ai_coverage,
    ROUND(COALESCE(p.renewal_ai_weighted, 0) / NULLIF(cq.renewal_quota/4, 0), 2) as renewal_ai_coverage,
    ROUND(COALESCE(p.land_exp_ai_weighted, 0) / NULLIF(cq.land_expand_quota/4, 0), 2) as land_exp_ai_coverage,

    -- 2025 Reference: Closed Won
    ROUND(COALESCE(r.new_cust_2025_won, 0), 0) as new_cust_2025_won,
    ROUND(COALESCE(r.renewal_2025_won, 0), 0) as renewal_2025_won,
    ROUND(COALESCE(r.land_exp_2025_won, 0), 0) as land_exp_2025_won,

    -- 2025 Reference: Close Rate (won / (won + lost))
    ROUND(SAFE_DIVIDE(r.new_cust_won_count, r.new_cust_won_count + r.new_cust_lost_count), 3) as new_cust_2025_close_rate,
    ROUND(SAFE_DIVIDE(r.renewal_won_count, r.renewal_won_count + r.renewal_lost_count), 3) as renewal_2025_close_rate,
    ROUND(SAFE_DIVIDE(r.land_exp_won_count, r.land_exp_won_count + r.land_exp_lost_count), 3) as land_exp_2025_close_rate,

    -- Metadata
    CURRENT_TIMESTAMP() as updated_at

FROM company_quotas cq
CROSS JOIN quarters qtr
LEFT JOIN company_pipeline_by_quarter p ON cq.company_id = p.company_id AND qtr.quarter = p.close_quarter
LEFT JOIN company_2025_stats r ON cq.company_id = r.company_id
ORDER BY cq.owner_name, cq.company_name, qtr.quarter

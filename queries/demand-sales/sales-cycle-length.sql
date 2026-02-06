-- =============================================================================
-- SALES CYCLE LENGTH (YTD)
-- =============================================================================
-- Purpose: Calculate average days from deal creation to close by rep
-- Owner: Demand Sales Team
-- Target: ≤60 days
-- Refresh: Daily
-- =============================================================================

WITH deal_owners AS (
    SELECT
        owner_id,
        CONCAT(first_name, ' ', last_name) AS owner_name,
        email
    FROM `stitchdata-384118.src_fivetran_hubspot.owner`
),

closed_won_ytd AS (
    SELECT
        d.owner_id,
        d.deal_id,
        d.property_dealname AS deal_name,
        d.property_amount AS amount,
        d.property_createdate AS create_date,
        d.property_closedate AS close_date,
        DATE_DIFF(d.property_closedate, DATE(d.property_createdate), DAY) AS cycle_days
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.property_hs_is_closed = TRUE
      AND d.property_hs_is_closed_won = TRUE
      AND d.deal_pipeline_id = 'default'
      AND EXTRACT(YEAR FROM d.property_closedate) = EXTRACT(YEAR FROM CURRENT_DATE())
      AND d.property_amount > 0
)

SELECT
    do.owner_name,
    do.email,

    -- Deal counts
    COUNT(cw.deal_id) AS deals_closed,

    -- Cycle time metrics
    ROUND(AVG(cw.cycle_days), 1) AS avg_cycle_days,
    APPROX_QUANTILES(cw.cycle_days, 2)[OFFSET(1)] AS median_cycle_days,
    MIN(cw.cycle_days) AS fastest_deal_days,
    MAX(cw.cycle_days) AS slowest_deal_days,

    -- Variance to target
    ROUND(AVG(cw.cycle_days) - 60, 1) AS variance_to_60d_target,

    -- Deals by cycle bucket
    COUNTIF(cw.cycle_days <= 30) AS deals_under_30d,
    COUNTIF(cw.cycle_days > 30 AND cw.cycle_days <= 60) AS deals_30_to_60d,
    COUNTIF(cw.cycle_days > 60 AND cw.cycle_days <= 90) AS deals_60_to_90d,
    COUNTIF(cw.cycle_days > 90) AS deals_over_90d,

    -- Status indicator (target: ≤60 days)
    CASE
        WHEN AVG(cw.cycle_days) <= 60 THEN 'GREEN'
        WHEN AVG(cw.cycle_days) <= 90 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM deal_owners do
LEFT JOIN closed_won_ytd cw ON do.owner_id = cw.owner_id
WHERE do.email IN ('danny@recess.is', 'katie@recess.is', 'andy@recess.is', 'char@recess.is', 'jack@recess.is')
GROUP BY do.owner_name, do.email
HAVING COUNT(cw.deal_id) > 0
ORDER BY avg_cycle_days ASC;

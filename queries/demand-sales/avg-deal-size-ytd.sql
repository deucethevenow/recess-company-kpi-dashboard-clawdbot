-- =============================================================================
-- AVERAGE DEAL SIZE (YTD)
-- =============================================================================
-- Purpose: Calculate average deal size for closed won deals YTD by rep
-- Owner: Demand Sales Team
-- Target: $150K
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
        d.property_closedate AS close_date
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

    -- Deal counts and totals
    COUNT(cw.deal_id) AS deals_closed,
    SUM(cw.amount) AS total_revenue,

    -- Average deal size
    ROUND(AVG(cw.amount), 2) AS avg_deal_size,

    -- Comparison to target
    ROUND(AVG(cw.amount) - 150000, 2) AS variance_to_150k_target,

    -- Min/Max for context
    MIN(cw.amount) AS smallest_deal,
    MAX(cw.amount) AS largest_deal,

    -- Status indicator (target: $150K)
    CASE
        WHEN AVG(cw.amount) >= 150000 THEN 'GREEN'
        WHEN AVG(cw.amount) >= 100000 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM deal_owners do
LEFT JOIN closed_won_ytd cw ON do.owner_id = cw.owner_id
WHERE do.email IN ('danny@recess.is', 'katie@recess.is', 'andy@recess.is', 'char@recess.is', 'jack@recess.is')
GROUP BY do.owner_name, do.email
HAVING COUNT(cw.deal_id) > 0
ORDER BY avg_deal_size DESC;

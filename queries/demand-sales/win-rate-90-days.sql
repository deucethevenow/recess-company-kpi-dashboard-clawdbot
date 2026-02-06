-- =============================================================================
-- WIN RATE (90 DAYS)
-- =============================================================================
-- Purpose: Calculate win rate over rolling 90-day window by rep
-- Owner: Demand Sales Team
-- Target: 30%
-- Refresh: Daily
-- =============================================================================

WITH deal_owners AS (
    SELECT
        owner_id,
        CONCAT(first_name, ' ', last_name) AS owner_name,
        email
    FROM `stitchdata-384118.src_fivetran_hubspot.owner`
),

closed_deals_90d AS (
    SELECT
        d.owner_id,
        d.deal_id,
        d.property_dealname AS deal_name,
        d.property_amount AS amount,
        d.property_closedate AS close_date,
        d.property_hs_is_closed_won AS is_won
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.property_hs_is_closed = TRUE
      AND d.deal_pipeline_id = 'default'
      AND d.property_closedate >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
)

SELECT
    do.owner_name,
    do.email,

    -- Deal counts
    COUNT(cd.deal_id) AS total_closed_deals,
    COUNTIF(cd.is_won = TRUE) AS won_deals,
    COUNTIF(cd.is_won = FALSE) AS lost_deals,

    -- Win rate
    SAFE_DIVIDE(COUNTIF(cd.is_won = TRUE), COUNT(cd.deal_id)) * 100 AS win_rate_pct,

    -- Revenue won
    SUM(CASE WHEN cd.is_won = TRUE THEN cd.amount ELSE 0 END) AS revenue_won,
    SUM(CASE WHEN cd.is_won = FALSE THEN cd.amount ELSE 0 END) AS revenue_lost,

    -- Status indicator (target: 30%)
    CASE
        WHEN SAFE_DIVIDE(COUNTIF(cd.is_won = TRUE), COUNT(cd.deal_id)) * 100 >= 30 THEN 'GREEN'
        WHEN SAFE_DIVIDE(COUNTIF(cd.is_won = TRUE), COUNT(cd.deal_id)) * 100 >= 20 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM deal_owners do
LEFT JOIN closed_deals_90d cd ON do.owner_id = cd.owner_id
WHERE do.email IN ('danny@recess.is', 'katie@recess.is', 'andy@recess.is', 'char@recess.is', 'jack@recess.is')
GROUP BY do.owner_name, do.email
HAVING COUNT(cd.deal_id) > 0
ORDER BY win_rate_pct DESC;

-- =============================================================================
-- DEALS BY STAGE (FUNNEL)
-- =============================================================================
-- Purpose: Show current deal distribution across pipeline stages
-- Owner: Demand Sales Team
-- Monthly Targets: Meeting Booked (45), SQL (36), Opportunity (23),
--                  Proposal Sent (22), Contract Sent (9), Won ($500K/7 deals)
-- Refresh: Daily
--
-- HubSpot Dashboard Reference:
--   - https://app.hubspot.com/reports-dashboard/6699636/view/3551608
-- =============================================================================

WITH stage_order AS (
    SELECT
        stage_id,
        label AS stage_name,
        display_order,
        probability
    FROM `stitchdata-384118.src_fivetran_hubspot.deal_pipeline_stage`
    WHERE pipeline_id = 'default'
),

monthly_targets AS (
    SELECT 'Meeting Booked' AS stage_name, 45 AS monthly_target UNION ALL
    SELECT 'Sales Qualified Lead', 36 UNION ALL
    SELECT 'Opportunity', 23 UNION ALL
    SELECT 'Proposal Sent', 22 UNION ALL
    SELECT 'Active Negotiation', 15 UNION ALL
    SELECT 'Contract Sent', 9 UNION ALL
    SELECT 'Closed Won', 7
),

open_deals AS (
    SELECT
        d.deal_id,
        d.property_dealname AS deal_name,
        d.property_amount AS amount,
        d.property_dealstage AS stage_id,
        d.property_createdate AS create_date,
        d.owner_id
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.property_hs_is_closed = FALSE
      AND d.deal_pipeline_id = 'default'
),

closed_won_mtd AS (
    SELECT
        d.deal_id,
        d.property_amount AS amount
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.property_hs_is_closed = TRUE
      AND d.property_hs_is_closed_won = TRUE
      AND d.deal_pipeline_id = 'default'
      AND DATE_TRUNC(d.property_closedate, MONTH) = DATE_TRUNC(CURRENT_DATE(), MONTH)
)

-- Open deals by stage
SELECT
    so.display_order,
    so.stage_name,
    so.probability AS stage_probability,
    COUNT(od.deal_id) AS deal_count,
    SUM(od.amount) AS total_amount,
    SUM(od.amount * so.probability / 100) AS weighted_amount,
    mt.monthly_target,
    COUNT(od.deal_id) - mt.monthly_target AS variance_to_target,
    CASE
        WHEN COUNT(od.deal_id) >= mt.monthly_target THEN 'GREEN'
        WHEN COUNT(od.deal_id) >= mt.monthly_target * 0.75 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM stage_order so
LEFT JOIN open_deals od ON so.stage_id = od.stage_id
LEFT JOIN monthly_targets mt ON so.stage_name = mt.stage_name
GROUP BY so.display_order, so.stage_name, so.probability, mt.monthly_target

UNION ALL

-- Add Closed Won MTD as final row
SELECT
    999 AS display_order,
    'Closed Won (MTD)' AS stage_name,
    100 AS stage_probability,
    COUNT(cw.deal_id) AS deal_count,
    SUM(cw.amount) AS total_amount,
    SUM(cw.amount) AS weighted_amount,
    7 AS monthly_target,  -- 7 deals / $500K target
    COUNT(cw.deal_id) - 7 AS variance_to_target,
    CASE
        WHEN COUNT(cw.deal_id) >= 7 THEN 'GREEN'
        WHEN COUNT(cw.deal_id) >= 5 THEN 'YELLOW'
        ELSE 'RED'
    END AS status
FROM closed_won_mtd cw

ORDER BY display_order;

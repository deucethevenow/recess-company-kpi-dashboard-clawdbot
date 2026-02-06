-- =============================================================================
-- SUPPLY FUNNEL (Meeting → SQL → Proposal → Won)
-- =============================================================================
-- Purpose: Track Supply pipeline funnel conversion rates
-- Owner: Ian Hong (Supply)
-- Monthly Targets: Attempted (60), Connected (60), Meeting (24),
--                  Proposal (16), Onboarded (16), Won (4)
-- Refresh: Daily
--
-- HubSpot Property Names (from Supply Dashboard):
-- - date_attempted_to_contact: When first contact attempt was made
-- - date_converted_meeting_booked: When meeting was booked
-- - date_converted_sql: When became SQL (Sales Qualified Lead)
-- - date_converted_sal: When became SAL (Sales Accepted Lead)
-- - date_converted_onboarded: When onboarding completed
-- - onboarded_at: Final onboard timestamp
-- - closedate: Deal close date
-- =============================================================================

WITH funnel_targets AS (
    SELECT 'Attempted to Contact' AS stage, 60 AS monthly_target, 1 AS stage_order UNION ALL
    SELECT 'Connected', 60, 2 UNION ALL
    SELECT 'Meeting Booked', 24, 3 UNION ALL
    SELECT 'Proposal Sent', 16, 4 UNION ALL
    SELECT 'Onboarding', 16, 5 UNION ALL
    SELECT 'Won', 4, 6
),

supply_stages AS (
    SELECT
        stage_id,
        label AS stage_name,
        display_order
    FROM `stitchdata-384118.src_fivetran_hubspot.deal_pipeline_stage`
    WHERE pipeline_id = 'supply'  -- TODO: Verify supply pipeline ID
),

supply_deals_by_stage AS (
    SELECT
        d.property_dealstage AS stage_id,
        COUNT(d.deal_id) AS deal_count,
        SUM(d.property_amount) AS total_amount
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.deal_pipeline_id = 'supply'
      AND d.property_hs_is_closed = FALSE
    GROUP BY d.property_dealstage
),

closed_won_mtd AS (
    SELECT
        COUNT(d.deal_id) AS won_count,
        SUM(d.property_amount) AS won_amount
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.deal_pipeline_id = 'supply'
      AND d.property_hs_is_closed_won = TRUE
      AND DATE_TRUNC(d.property_closedate, MONTH) = DATE_TRUNC(CURRENT_DATE(), MONTH)
)

SELECT
    ss.display_order,
    ss.stage_name,
    COALESCE(sds.deal_count, 0) AS current_count,
    COALESCE(sds.total_amount, 0) AS total_amount,
    ft.monthly_target,
    COALESCE(sds.deal_count, 0) - ft.monthly_target AS variance,
    ROUND(COALESCE(sds.deal_count, 0) * 100.0 / NULLIF(ft.monthly_target, 0), 1) AS pct_of_target,
    CASE
        WHEN COALESCE(sds.deal_count, 0) >= ft.monthly_target THEN 'GREEN'
        WHEN COALESCE(sds.deal_count, 0) >= ft.monthly_target * 0.75 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM supply_stages ss
LEFT JOIN supply_deals_by_stage sds ON ss.stage_id = sds.stage_id
LEFT JOIN funnel_targets ft ON ss.stage_name = ft.stage
ORDER BY ss.display_order;


-- =============================================================================
-- CONVERSION RATES BETWEEN STAGES
-- =============================================================================
/*
WITH stage_counts AS (
    SELECT
        stage_name,
        stage_order,
        deal_count
    FROM (
        SELECT 'Attempted' AS stage_name, 1 AS stage_order, 120 AS deal_count UNION ALL
        SELECT 'Connected', 2, 80 UNION ALL
        SELECT 'Meeting', 3, 40 UNION ALL
        SELECT 'Proposal', 4, 25 UNION ALL
        SELECT 'Won', 5, 8
    )
)

SELECT
    s1.stage_name AS from_stage,
    s2.stage_name AS to_stage,
    s1.deal_count AS from_count,
    s2.deal_count AS to_count,
    ROUND(s2.deal_count * 100.0 / s1.deal_count, 1) AS conversion_rate_pct
FROM stage_counts s1
JOIN stage_counts s2 ON s2.stage_order = s1.stage_order + 1
ORDER BY s1.stage_order;
*/

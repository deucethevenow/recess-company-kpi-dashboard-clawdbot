-- =============================================================================
-- PIPELINE COVERAGE BY REP
-- =============================================================================
-- Purpose: Calculate weighted pipeline coverage for each sales rep
-- Owner: Demand Sales (Danny, Katie, Andy)
-- Target: 6.0x (based on 17.5% historical win rate)
-- Refresh: Daily
--
-- HubSpot Dashboard Reference:
--   - https://app.hubspot.com/reports-dashboard/6699636/view/3551608
--   - https://app.hubspot.com/reports-dashboard/6699636/view/16787401
-- =============================================================================

WITH deal_owners AS (
    SELECT
        owner_id,
        CONCAT(first_name, ' ', last_name) AS owner_name,
        email
    FROM `stitchdata-384118.src_fivetran_hubspot.owner`
    WHERE email IN ('danny@recess.is', 'katie@recess.is', 'andy@recess.is')
),

-- Get quarterly quota from company properties (or use hardcoded values)
quotas AS (
    SELECT
        'danny@recess.is' AS email, 800000 AS quarterly_quota
    UNION ALL
    SELECT 'katie@recess.is', 600000
    UNION ALL
    SELECT 'andy@recess.is', 700000
    -- TODO: Pull from HubSpot company properties when available
),

open_deals AS (
    SELECT
        d.deal_id,
        d.property_dealname AS deal_name,
        d.property_amount AS amount,
        d.property_hs_forecast_amount AS weighted_amount,  -- Sales rep confidence weighting
        d.property_closedate AS close_date,
        d.property_dealstage AS stage_id,
        d.owner_id,
        dps.label AS stage_name,
        dps.probability AS stage_probability
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    LEFT JOIN `stitchdata-384118.src_fivetran_hubspot.deal_pipeline_stage` dps
        ON d.property_dealstage = dps.stage_id
    WHERE d.property_hs_is_closed = FALSE
      AND d.deal_pipeline_id = 'default'  -- Purchase (Manual) pipeline only
      AND d.property_amount > 0
),

-- Calculate closed won revenue YTD by rep
closed_won_ytd AS (
    SELECT
        d.owner_id,
        SUM(d.property_amount) AS closed_won_amount
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.property_hs_is_closed = TRUE
      AND d.property_hs_is_closed_won = TRUE
      AND d.deal_pipeline_id = 'default'
      AND EXTRACT(YEAR FROM d.property_closedate) = EXTRACT(YEAR FROM CURRENT_DATE())
    GROUP BY d.owner_id
)

SELECT
    do.owner_name,
    do.email,
    q.quarterly_quota,
    COALESCE(cw.closed_won_amount, 0) AS closed_won_ytd,

    -- Raw pipeline
    COUNT(od.deal_id) AS open_deal_count,
    SUM(od.amount) AS total_pipeline_unweighted,

    -- Weighted pipeline (using sales rep forecast)
    SUM(COALESCE(od.weighted_amount, od.amount * od.stage_probability / 100)) AS total_pipeline_weighted,

    -- Remaining quota
    q.quarterly_quota - COALESCE(cw.closed_won_amount, 0) AS remaining_quota,

    -- Pipeline Coverage Ratios
    SAFE_DIVIDE(
        SUM(COALESCE(od.weighted_amount, od.amount * od.stage_probability / 100)),
        q.quarterly_quota - COALESCE(cw.closed_won_amount, 0)
    ) AS pipeline_coverage_ratio,

    -- Gap to 6x target
    (6.0 * (q.quarterly_quota - COALESCE(cw.closed_won_amount, 0))) -
        SUM(COALESCE(od.weighted_amount, od.amount * od.stage_probability / 100)) AS gap_to_6x_target,

    -- Status indicator
    CASE
        WHEN SAFE_DIVIDE(
            SUM(COALESCE(od.weighted_amount, od.amount * od.stage_probability / 100)),
            q.quarterly_quota - COALESCE(cw.closed_won_amount, 0)
        ) >= 6.0 THEN 'GREEN'
        WHEN SAFE_DIVIDE(
            SUM(COALESCE(od.weighted_amount, od.amount * od.stage_probability / 100)),
            q.quarterly_quota - COALESCE(cw.closed_won_amount, 0)
        ) >= 4.0 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM deal_owners do
LEFT JOIN quotas q ON do.email = q.email
LEFT JOIN open_deals od ON do.owner_id = od.owner_id
LEFT JOIN closed_won_ytd cw ON do.owner_id = cw.owner_id
GROUP BY do.owner_name, do.email, q.quarterly_quota, cw.closed_won_amount
ORDER BY do.owner_name;

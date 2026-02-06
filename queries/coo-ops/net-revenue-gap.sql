-- =============================================================================
-- NET REVENUE GAP
-- =============================================================================
-- Purpose: Calculate gap between unspent contracts and revenue goal
-- Owner: Deuce (COO)
-- Target: Positive (more unspent than needed)
-- Refresh: Daily
--
-- Formula: Net Revenue Gap = Total Unspent Contract $ - Remaining Goal
-- Remaining Goal = Annual Target - YTD Revenue
-- =============================================================================

WITH annual_target AS (
    -- Configurable annual revenue target
    SELECT 10000000 AS target  -- $10M
),

ytd_revenue AS (
    -- YTD revenue from QBO invoices
    SELECT
        SUM(inv.total_amount) AS ytd_revenue
    FROM `stitchdata-384118.src_fivetran_qbo.invoice` inv
    WHERE inv._fivetran_deleted = FALSE
      AND EXTRACT(YEAR FROM inv.transaction_date) = EXTRACT(YEAR FROM CURRENT_DATE())
),

unspent_contracts AS (
    -- Use the GMV Waterfall view for unspent contract value
    SELECT
        SUM(CASE
            WHEN contract_status IN ('Active', 'Pending')
            THEN contract_value - COALESCE(spent_value, 0)
            ELSE 0
        END) AS total_unspent
    FROM `stitchdata-384118.App_KPI_Dashboard.HS_QBO_GMV_Waterfall`
)

SELECT
    'Net Revenue Gap' AS metric,
    at.target AS annual_target,
    yr.ytd_revenue,
    at.target - yr.ytd_revenue AS remaining_goal,
    uc.total_unspent AS unspent_contracts,
    uc.total_unspent - (at.target - yr.ytd_revenue) AS net_revenue_gap,

    -- Days remaining in year
    DATE_DIFF(DATE(EXTRACT(YEAR FROM CURRENT_DATE()), 12, 31), CURRENT_DATE(), DAY) AS days_remaining,

    -- Required daily run rate to hit target
    ROUND((at.target - yr.ytd_revenue) /
          NULLIF(DATE_DIFF(DATE(EXTRACT(YEAR FROM CURRENT_DATE()), 12, 31), CURRENT_DATE(), DAY), 0), 0)
        AS required_daily_revenue,

    CASE
        WHEN uc.total_unspent >= (at.target - yr.ytd_revenue) * 1.2 THEN 'GREEN'  -- 20% buffer
        WHEN uc.total_unspent >= (at.target - yr.ytd_revenue) THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM annual_target at
CROSS JOIN ytd_revenue yr
CROSS JOIN unspent_contracts uc;


-- =============================================================================
-- GAP BY QUARTER
-- =============================================================================
/*
SELECT
    FORMAT_DATE('%Y-Q%Q', DATE_TRUNC(CURRENT_DATE(), QUARTER)) AS current_quarter,
    at.target / 4 AS quarterly_target,
    SUM(inv.total_amount) AS qtd_revenue,
    at.target / 4 - SUM(inv.total_amount) AS quarterly_gap
FROM `stitchdata-384118.src_fivetran_qbo.invoice` inv
CROSS JOIN annual_target at
WHERE inv._fivetran_deleted = FALSE
  AND DATE_TRUNC(inv.transaction_date, QUARTER) = DATE_TRUNC(CURRENT_DATE(), QUARTER)
GROUP BY at.target;
*/

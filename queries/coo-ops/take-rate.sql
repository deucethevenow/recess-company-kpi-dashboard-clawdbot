-- =============================================================================
-- TAKE RATE % (PRIMARY Metric - Deuce / Company Health)
-- =============================================================================
-- Purpose: Calculate marketplace take rate (what % Recess keeps)
-- Owner: Deuce (COO)
-- Target: 45%
-- Refresh: Daily
--
-- Formula: Take Rate % = (Revenue - Payouts) / Revenue × 100
--   OR equivalently: Take Rate % = Gross Profit / Revenue × 100
--
-- Where:
--   Revenue = What brands pay Recess (QBO accounts 4110, 4120, 4130)
--   Payouts = What Recess pays suppliers (from Supplier_Metrics or bills)
--   Gross Profit = Revenue - Payouts = What Recess keeps
--
-- Example: Brand pays $100K, Recess pays supplier $55K → Take Rate = 45%
-- =============================================================================

-- Option 1: Using Supplier_Metrics view (RECOMMENDED - authoritative source)
WITH revenue_and_payouts AS (
    SELECT
        SUM(GMV) AS total_gmv,
        SUM(Payouts) AS total_payouts,
        SUM(GMV) - SUM(Payouts) AS gross_profit
    FROM `stitchdata-384118.App_KPI_Dashboard.Supplier_Metrics`
    -- Add date filter if needed
)

SELECT
    'Take Rate (from Supplier_Metrics)' AS metric,
    total_gmv AS revenue,
    total_payouts AS payouts,
    gross_profit,
    ROUND(gross_profit * 100.0 / NULLIF(total_gmv, 0), 1) AS take_rate_pct,
    -- Target from dashboard/data/targets.json: take_rate_target = 0.50 (50%)
    50.0 AS target_pct,
    ROUND(gross_profit * 100.0 / NULLIF(total_gmv, 0), 1) - 50.0 AS variance,
    CASE
        WHEN gross_profit * 100.0 / NULLIF(total_gmv, 0) >= 50 THEN 'GREEN'
        WHEN gross_profit * 100.0 / NULLIF(total_gmv, 0) >= 45 THEN 'YELLOW'
        ELSE 'RED'
    END AS status
FROM revenue_and_payouts;


-- =============================================================================
-- Option 2: Using QBO data directly (if Supplier_Metrics not available)
-- =============================================================================
/*
WITH revenue AS (
    -- Revenue from brands (accounts 4110, 4120, 4130)
    SELECT
        DATE_TRUNC(inv.transaction_date, MONTH) AS period,
        SUM(inv.total_amount) AS total_revenue
    FROM `stitchdata-384118.src_fivetran_qbo.invoice` inv
    WHERE inv._fivetran_deleted = FALSE
      AND EXTRACT(YEAR FROM inv.transaction_date) = EXTRACT(YEAR FROM CURRENT_DATE())
    GROUP BY period
),

payouts AS (
    -- Payouts to suppliers (bills to vendors)
    SELECT
        DATE_TRUNC(bill.transaction_date, MONTH) AS period,
        SUM(bill.total_amount) AS total_payouts
    FROM `stitchdata-384118.src_fivetran_qbo.bill` bill
    WHERE bill._fivetran_deleted = FALSE
      AND EXTRACT(YEAR FROM bill.transaction_date) = EXTRACT(YEAR FROM CURRENT_DATE())
      -- Filter to supplier payouts only (may need vendor type filter)
    GROUP BY period
)

SELECT
    FORMAT_DATE('%Y-%m', r.period) AS month,
    r.total_revenue AS revenue,
    COALESCE(p.total_payouts, 0) AS payouts,
    r.total_revenue - COALESCE(p.total_payouts, 0) AS gross_profit,
    ROUND((r.total_revenue - COALESCE(p.total_payouts, 0)) * 100.0 /
          NULLIF(r.total_revenue, 0), 1) AS take_rate_pct
FROM revenue r
LEFT JOIN payouts p ON r.period = p.period
ORDER BY r.period DESC;
*/


-- =============================================================================
-- MONTHLY TREND
-- =============================================================================
/*
-- If Supplier_Metrics has monthly granularity, use this:
SELECT
    month,
    SUM(GMV) AS revenue,
    SUM(Payouts) AS payouts,
    SUM(GMV) - SUM(Payouts) AS gross_profit,
    ROUND((SUM(GMV) - SUM(Payouts)) * 100.0 / NULLIF(SUM(GMV), 0), 1) AS take_rate_pct
FROM `stitchdata-384118.App_KPI_Dashboard.Supplier_Metrics`
GROUP BY month
ORDER BY month DESC;
*/

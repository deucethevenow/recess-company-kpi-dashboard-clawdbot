-- =============================================================================
-- OPERATING BURN (Metric #6b - COO/CFO + CEO Dashboard)
-- =============================================================================
-- Purpose: Track operating cash burn (= total cash burn in this context)
-- Owner: Deuce (COO), Jack (CEO)
-- Target: TBD in settings (based on 2025 baseline)
-- Refresh: Daily
-- Direction: Higher is better (positive = generating cash)
--
-- Formula: Operating Burn = Net Increase (Decrease) in Cash
--          = Operating Activities + Investing Activities + Financing Activities
--          = Cash End of Period - Cash Begin of Period
--
-- Note: In this model, "Operating Burn" = total cash flow, matching the
--       Recess Forecast spreadsheet CFS (Roll Forward) definition.
-- =============================================================================

WITH monthly_cash AS (
  -- Cash Position from Balance Sheet
  SELECT
    period_last_day,
    FORMAT_DATE('%Y-%m', period_last_day) AS month,
    EXTRACT(YEAR FROM period_last_day) AS year,
    ROUND(SUM(amount), 0) AS cash_end_of_period
  FROM `stitchdata-384118.src_fivetran_qbo_quickbooks.quickbooks__balance_sheet`
  WHERE account_type = 'Bank'
    AND account_number IS NOT NULL
  GROUP BY 1, 2, 3
),

monthly_net_income AS (
  -- Net Income from P&L
  SELECT
    period_last_day,
    FORMAT_DATE('%Y-%m', period_last_day) AS month,
    ROUND(SUM(
      amount * CASE
        WHEN LEFT(account_number, 1) IN ('4','7') THEN 1   -- Revenue
        WHEN LEFT(account_number, 1) IN ('5','6') THEN -1  -- Expenses
        ELSE 0
      END
    ), 0) AS net_income
  FROM `stitchdata-384118.src_fivetran_qbo_quickbooks.quickbooks__profit_and_loss`
  WHERE account_number IS NOT NULL
  GROUP BY 1, 2
),

cash_flow AS (
  SELECT
    c.period_last_day,
    c.month,
    c.year,
    c.cash_end_of_period,
    LAG(c.cash_end_of_period) OVER (ORDER BY c.period_last_day) AS cash_begin_of_period,
    c.cash_end_of_period - LAG(c.cash_end_of_period) OVER (ORDER BY c.period_last_day) AS operating_burn,
    ni.net_income
  FROM monthly_cash c
  LEFT JOIN monthly_net_income ni ON c.month = ni.month
)

-- =============================================================================
-- SUMMARY: Operating Burn with Averages
-- =============================================================================
SELECT
  'Operating Burn Analysis' AS metric,

  -- Current period
  MAX(CASE WHEN period_last_day = (SELECT MAX(period_last_day) FROM cash_flow WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE()))
      THEN month END) AS current_month,
  MAX(CASE WHEN period_last_day = (SELECT MAX(period_last_day) FROM cash_flow WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE()))
      THEN operating_burn END) AS current_operating_burn,
  MAX(CASE WHEN period_last_day = (SELECT MAX(period_last_day) FROM cash_flow WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE()))
      THEN net_income END) AS current_net_income,

  -- Averages (for Runway calculation)
  ROUND(AVG(CASE WHEN period_last_day >= DATE_SUB((SELECT MAX(period_last_day) FROM cash_flow WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE())), INTERVAL 2 MONTH)
                  AND year <= EXTRACT(YEAR FROM CURRENT_DATE())
            THEN operating_burn END), 0) AS avg_3mo_burn,

  ROUND(AVG(CASE WHEN period_last_day >= DATE_SUB((SELECT MAX(period_last_day) FROM cash_flow WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE())), INTERVAL 5 MONTH)
                  AND year <= EXTRACT(YEAR FROM CURRENT_DATE())
            THEN operating_burn END), 0) AS avg_6mo_burn,

  ROUND(AVG(CASE WHEN period_last_day >= DATE_SUB((SELECT MAX(period_last_day) FROM cash_flow WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE())), INTERVAL 11 MONTH)
                  AND year <= EXTRACT(YEAR FROM CURRENT_DATE())
            THEN operating_burn END), 0) AS avg_12mo_burn,

  -- 2025 Baseline (for year-over-year comparison)
  ROUND(AVG(CASE WHEN year = 2025 THEN operating_burn END), 0) AS baseline_2025_avg,

  CURRENT_TIMESTAMP() AS as_of

FROM cash_flow
WHERE operating_burn IS NOT NULL;


-- =============================================================================
-- DETAIL: Monthly Operating Burn Trend
-- =============================================================================
/*
SELECT
  month,
  cash_begin_of_period,
  cash_end_of_period,
  operating_burn,
  net_income,
  operating_burn - net_income AS working_capital_changes
FROM cash_flow
WHERE period_last_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 24 MONTH)
  AND operating_burn IS NOT NULL
ORDER BY period_last_day DESC;
*/


-- =============================================================================
-- DETAIL: Year-over-Year Operating Burn
-- =============================================================================
/*
SELECT
  year,
  COUNT(*) AS months,
  ROUND(SUM(operating_burn), 0) AS total_operating_burn,
  ROUND(AVG(operating_burn), 0) AS avg_monthly_burn,
  ROUND(SUM(net_income), 0) AS total_net_income
FROM cash_flow
WHERE year IN (2025, 2026)
  AND operating_burn IS NOT NULL
GROUP BY year
ORDER BY year;
*/

-- =============================================================================
-- CASH BURN (Metric #6a - COO/CFO + CEO Dashboard)
-- =============================================================================
-- Purpose: Track monthly change in cash position
-- Owner: Deuce (COO), Jack (CEO)
-- Target: N/A (reporting metric, used to calculate Runway)
-- Refresh: Daily
--
-- Formula: Cash Burn = Cash End of Period - Cash Begin of Period
-- Source: QBO Balance Sheet (Bank accounts)
-- Note: Positive = cash generated, Negative = cash burned
-- =============================================================================

WITH monthly_cash AS (
  -- Cash Position (end of period) from Balance Sheet
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

cash_with_changes AS (
  SELECT
    period_last_day,
    month,
    year,
    cash_end_of_period,
    LAG(cash_end_of_period) OVER (ORDER BY period_last_day) AS cash_begin_of_period,
    cash_end_of_period - LAG(cash_end_of_period) OVER (ORDER BY period_last_day) AS cash_burn
  FROM monthly_cash
)

-- =============================================================================
-- SUMMARY: Monthly Cash Burn with 3/6/12 Month Averages
-- =============================================================================
SELECT
  'Cash Burn Analysis' AS metric,

  -- Current month
  MAX(CASE WHEN period_last_day = (SELECT MAX(period_last_day) FROM cash_with_changes WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE()))
      THEN month END) AS current_month,
  MAX(CASE WHEN period_last_day = (SELECT MAX(period_last_day) FROM cash_with_changes WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE()))
      THEN cash_end_of_period END) AS current_cash_position,
  MAX(CASE WHEN period_last_day = (SELECT MAX(period_last_day) FROM cash_with_changes WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE()))
      THEN cash_burn END) AS current_month_burn,

  -- 3-month average (most recent 3 months)
  ROUND(AVG(CASE WHEN period_last_day >= DATE_SUB((SELECT MAX(period_last_day) FROM cash_with_changes WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE())), INTERVAL 2 MONTH)
                  AND year <= EXTRACT(YEAR FROM CURRENT_DATE())
            THEN cash_burn END), 0) AS avg_3mo_burn,

  -- 6-month average
  ROUND(AVG(CASE WHEN period_last_day >= DATE_SUB((SELECT MAX(period_last_day) FROM cash_with_changes WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE())), INTERVAL 5 MONTH)
                  AND year <= EXTRACT(YEAR FROM CURRENT_DATE())
            THEN cash_burn END), 0) AS avg_6mo_burn,

  -- 12-month average
  ROUND(AVG(CASE WHEN period_last_day >= DATE_SUB((SELECT MAX(period_last_day) FROM cash_with_changes WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE())), INTERVAL 11 MONTH)
                  AND year <= EXTRACT(YEAR FROM CURRENT_DATE())
            THEN cash_burn END), 0) AS avg_12mo_burn,

  CURRENT_TIMESTAMP() AS as_of

FROM cash_with_changes
WHERE cash_burn IS NOT NULL;


-- =============================================================================
-- DETAIL: Monthly Cash Position & Burn Trend
-- =============================================================================
/*
SELECT
  month,
  cash_begin_of_period,
  cash_end_of_period,
  cash_burn,
  CASE
    WHEN cash_burn >= 0 THEN 'POSITIVE'
    ELSE 'NEGATIVE'
  END AS burn_status
FROM cash_with_changes
WHERE period_last_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 24 MONTH)
  AND cash_burn IS NOT NULL
ORDER BY period_last_day DESC;
*/


-- =============================================================================
-- DETAIL: Year-over-Year Comparison (2025 vs 2026)
-- =============================================================================
/*
SELECT
  year,
  COUNT(*) AS months,
  ROUND(SUM(cash_burn), 0) AS total_cash_burn,
  ROUND(AVG(cash_burn), 0) AS avg_monthly_burn,
  MIN(cash_burn) AS worst_month,
  MAX(cash_burn) AS best_month
FROM cash_with_changes
WHERE year IN (2025, 2026)
  AND cash_burn IS NOT NULL
GROUP BY year
ORDER BY year;
*/

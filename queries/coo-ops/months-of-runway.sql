-- =============================================================================
-- MONTHS OF RUNWAY (Metric #6 - COO/CFO + CEO Dashboard)
-- =============================================================================
-- Purpose: Calculate how many months of cash runway remain
-- Owner: Deuce (COO), Jack (CEO)
-- Target: TBD in settings (e.g., >12 months)
-- Refresh: Daily
-- Direction: Higher is better
--
-- Formula: Runway = Cash Position / |Avg Monthly Operating Burn|
-- Note: Only calculated when burning cash (negative avg burn)
--       If generating cash (positive avg), runway = infinite
--
-- Source: QBO Balance Sheet (cash) + Operating Burn (from CFS)
-- =============================================================================

WITH monthly_cash AS (
  -- Cash Position from Balance Sheet
  SELECT
    period_last_day,
    FORMAT_DATE('%Y-%m', period_last_day) AS month,
    EXTRACT(YEAR FROM period_last_day) AS year,
    ROUND(SUM(amount), 0) AS cash_position
  FROM `stitchdata-384118.src_fivetran_qbo_quickbooks.quickbooks__balance_sheet`
  WHERE account_type = 'Bank'
    AND account_number IS NOT NULL
  GROUP BY 1, 2, 3
),

operating_burn AS (
  SELECT
    period_last_day,
    month,
    year,
    cash_position,
    cash_position - LAG(cash_position) OVER (ORDER BY period_last_day) AS monthly_burn
  FROM monthly_cash
),

current_state AS (
  SELECT
    -- Current cash position
    (SELECT cash_position
     FROM operating_burn
     WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE())
     ORDER BY period_last_day DESC LIMIT 1) AS current_cash,

    (SELECT month
     FROM operating_burn
     WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE())
     ORDER BY period_last_day DESC LIMIT 1) AS current_month,

    -- Average burns
    (SELECT ROUND(AVG(monthly_burn), 0)
     FROM operating_burn
     WHERE period_last_day >= DATE_SUB(
       (SELECT MAX(period_last_day) FROM operating_burn WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE())),
       INTERVAL 2 MONTH)
       AND year <= EXTRACT(YEAR FROM CURRENT_DATE())
       AND monthly_burn IS NOT NULL) AS avg_3mo_burn,

    (SELECT ROUND(AVG(monthly_burn), 0)
     FROM operating_burn
     WHERE period_last_day >= DATE_SUB(
       (SELECT MAX(period_last_day) FROM operating_burn WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE())),
       INTERVAL 5 MONTH)
       AND year <= EXTRACT(YEAR FROM CURRENT_DATE())
       AND monthly_burn IS NOT NULL) AS avg_6mo_burn,

    (SELECT ROUND(AVG(monthly_burn), 0)
     FROM operating_burn
     WHERE period_last_day >= DATE_SUB(
       (SELECT MAX(period_last_day) FROM operating_burn WHERE year <= EXTRACT(YEAR FROM CURRENT_DATE())),
       INTERVAL 11 MONTH)
       AND year <= EXTRACT(YEAR FROM CURRENT_DATE())
       AND monthly_burn IS NOT NULL) AS avg_12mo_burn
)

-- =============================================================================
-- SUMMARY: Runway Calculation
-- =============================================================================
SELECT
  'Months of Runway' AS metric,
  current_month,
  current_cash AS cash_position,

  -- Average burns
  avg_3mo_burn,
  avg_6mo_burn,
  avg_12mo_burn,

  -- Runway calculations (only if burning cash)
  CASE
    WHEN avg_3mo_burn >= 0 THEN NULL  -- Generating cash, infinite runway
    ELSE ROUND(current_cash / ABS(avg_3mo_burn), 1)
  END AS runway_3mo_basis,

  CASE
    WHEN avg_6mo_burn >= 0 THEN NULL
    ELSE ROUND(current_cash / ABS(avg_6mo_burn), 1)
  END AS runway_6mo_basis,

  CASE
    WHEN avg_12mo_burn >= 0 THEN NULL
    ELSE ROUND(current_cash / ABS(avg_12mo_burn), 1)
  END AS runway_12mo_basis,

  -- Primary runway metric (use 12mo average, fallback to 6mo, then 3mo)
  COALESCE(
    CASE WHEN avg_12mo_burn < 0 THEN ROUND(current_cash / ABS(avg_12mo_burn), 1) END,
    CASE WHEN avg_6mo_burn < 0 THEN ROUND(current_cash / ABS(avg_6mo_burn), 1) END,
    CASE WHEN avg_3mo_burn < 0 THEN ROUND(current_cash / ABS(avg_3mo_burn), 1) END
  ) AS runway_months,

  -- Status (based on 12mo runway)
  CASE
    WHEN avg_12mo_burn >= 0 THEN 'GREEN'  -- Generating cash
    WHEN current_cash / ABS(avg_12mo_burn) >= 12 THEN 'GREEN'
    WHEN current_cash / ABS(avg_12mo_burn) >= 6 THEN 'YELLOW'
    ELSE 'RED'
  END AS status,

  -- Interpretation
  CASE
    WHEN avg_12mo_burn >= 0 THEN 'Cash positive - generating cash'
    WHEN avg_12mo_burn < 0 AND avg_3mo_burn >= 0 THEN 'Recent trend positive - monitor closely'
    ELSE 'Burning cash - monitor runway'
  END AS interpretation,

  CURRENT_TIMESTAMP() AS as_of

FROM current_state;


-- =============================================================================
-- DETAIL: Monthly Runway Trend
-- =============================================================================
/*
WITH monthly_data AS (
  SELECT
    period_last_day,
    month,
    cash_position,
    monthly_burn,
    AVG(monthly_burn) OVER (ORDER BY period_last_day ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS rolling_12mo_avg
  FROM operating_burn
  WHERE monthly_burn IS NOT NULL
)
SELECT
  month,
  cash_position,
  monthly_burn,
  ROUND(rolling_12mo_avg, 0) AS avg_12mo_burn,
  CASE
    WHEN rolling_12mo_avg >= 0 THEN NULL
    ELSE ROUND(cash_position / ABS(rolling_12mo_avg), 1)
  END AS runway_months
FROM monthly_data
WHERE period_last_day >= DATE_SUB(CURRENT_DATE(), INTERVAL 24 MONTH)
ORDER BY period_last_day DESC;
*/

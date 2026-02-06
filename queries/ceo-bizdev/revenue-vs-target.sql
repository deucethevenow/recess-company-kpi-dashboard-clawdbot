-- =============================================================================
-- REVENUE VS TARGET (PRIMARY Metric - Jack/CEO)
-- =============================================================================
-- Purpose: Track YTD revenue against annual target
-- Owner: Jack (CEO)
-- Target: $10M annual
-- Refresh: Daily
--
-- Note: This is the NORTH STAR metric. All other metrics ladder to this.
-- =============================================================================

WITH annual_target AS (
    SELECT 10000000 AS target  -- $10M annual target
),

revenue_by_month AS (
    -- YTD revenue from QBO invoices (revenue accounts only)
    SELECT
        DATE_TRUNC(inv.transaction_date, MONTH) AS month,
        SUM(inv.total_amount) AS monthly_revenue
    FROM `stitchdata-384118.src_fivetran_qbo.invoice` inv
    WHERE inv._fivetran_deleted = FALSE
      AND EXTRACT(YEAR FROM inv.transaction_date) = EXTRACT(YEAR FROM CURRENT_DATE())
    GROUP BY month
),

ytd_summary AS (
    SELECT
        SUM(monthly_revenue) AS ytd_revenue,
        COUNT(DISTINCT month) AS months_completed
    FROM revenue_by_month
)

SELECT
    'Revenue vs Target' AS metric,
    at.target AS annual_target,
    ys.ytd_revenue,
    at.target - ys.ytd_revenue AS remaining_to_target,
    ROUND(ys.ytd_revenue * 100.0 / at.target, 1) AS pct_of_target,

    -- Pacing calculations
    ys.months_completed,
    ROUND(ys.ytd_revenue / NULLIF(ys.months_completed, 0), 0) AS avg_monthly_revenue,
    ROUND(at.target / 12.0, 0) AS required_monthly_avg,

    -- Projected annual (based on current run rate)
    ROUND(ys.ytd_revenue / NULLIF(ys.months_completed, 0) * 12, 0) AS projected_annual,

    -- Days into year
    EXTRACT(DAYOFYEAR FROM CURRENT_DATE()) AS day_of_year,
    ROUND(EXTRACT(DAYOFYEAR FROM CURRENT_DATE()) * 100.0 / 365, 1) AS pct_year_elapsed,

    -- Expected pace
    ROUND(at.target * EXTRACT(DAYOFYEAR FROM CURRENT_DATE()) / 365, 0) AS expected_ytd_at_pace,
    ys.ytd_revenue - ROUND(at.target * EXTRACT(DAYOFYEAR FROM CURRENT_DATE()) / 365, 0) AS ahead_behind_pace,

    CASE
        WHEN ys.ytd_revenue >= at.target * EXTRACT(DAYOFYEAR FROM CURRENT_DATE()) / 365 THEN 'GREEN'
        WHEN ys.ytd_revenue >= at.target * EXTRACT(DAYOFYEAR FROM CURRENT_DATE()) / 365 * 0.8 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM annual_target at
CROSS JOIN ytd_summary ys;


-- =============================================================================
-- MONTHLY TREND
-- =============================================================================
/*
SELECT
    FORMAT_DATE('%Y-%m', month) AS month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (ORDER BY month) AS cumulative_revenue,
    ROUND(at.target / 12.0, 0) AS monthly_target,
    monthly_revenue - ROUND(at.target / 12.0, 0) AS variance
FROM revenue_by_month
CROSS JOIN annual_target at
ORDER BY month;
*/


-- =============================================================================
-- QUARTERLY SUMMARY
-- =============================================================================
/*
SELECT
    FORMAT_DATE('%Y-Q%Q', DATE_TRUNC(month, QUARTER)) AS quarter,
    SUM(monthly_revenue) AS quarterly_revenue,
    at.target / 4 AS quarterly_target,
    ROUND(SUM(monthly_revenue) * 100.0 / (at.target / 4), 1) AS pct_of_quarterly_target
FROM revenue_by_month
CROSS JOIN annual_target at
GROUP BY DATE_TRUNC(month, QUARTER), at.target
ORDER BY quarter;
*/

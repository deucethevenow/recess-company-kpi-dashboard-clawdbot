-- =============================================================================
-- AVG INVOICE COLLECTION TIME (Metric #2a)
-- =============================================================================
-- Purpose: Track average days from invoice created to payment received
-- Owner: Deuce (COO) / Accounting
-- Target: TBD (set baseline from 2025, improve in 2026)
-- Refresh: Daily
-- Direction: Lower is better
--
-- Formula: AVG(payment_date - invoice_created_date) in days
-- Grouped by: due_date year (2025 baseline vs 2026 current)
-- =============================================================================

WITH paid_invoices AS (
    SELECT
        inv.id AS invoice_id,
        inv.doc_number,
        inv.transaction_date AS invoice_created,
        inv.due_date,
        inv.total_amount,
        pmt.transaction_date AS payment_date,
        EXTRACT(YEAR FROM inv.due_date) AS due_date_year,

        -- Days to collect (from invoice created to payment)
        DATE_DIFF(pmt.transaction_date, inv.transaction_date, DAY) AS days_to_collect,

        -- Days from due date (negative = early, positive = late)
        DATE_DIFF(pmt.transaction_date, inv.due_date, DAY) AS days_from_due_date

    FROM `stitchdata-384118.src_fivetran_qbo.invoice` inv
    JOIN `stitchdata-384118.src_fivetran_qbo.payment_line` pl
        ON inv.id = pl.invoice_id
    JOIN `stitchdata-384118.src_fivetran_qbo.payment` pmt
        ON pl.payment_id = pmt.id
    WHERE inv._fivetran_deleted = FALSE
      AND pmt._fivetran_deleted = FALSE
      AND inv.balance = 0  -- Fully paid invoices only
      AND EXTRACT(YEAR FROM inv.due_date) IN (2025, 2026)  -- 2025 baseline + 2026 current
)

-- =============================================================================
-- SUMMARY BY YEAR (2025 Baseline vs 2026 Current)
-- =============================================================================
SELECT
    'Avg Invoice Collection Time' AS metric,
    due_date_year,
    COUNT(*) AS invoices_paid,

    -- Average days to collect
    ROUND(AVG(days_to_collect), 1) AS avg_days_to_collect,

    -- Median (approximate using APPROX_QUANTILES)
    ROUND(APPROX_QUANTILES(days_to_collect, 100)[OFFSET(50)], 1) AS median_days_to_collect,

    -- Range
    MIN(days_to_collect) AS min_days,
    MAX(days_to_collect) AS max_days,

    -- Percentiles
    ROUND(APPROX_QUANTILES(days_to_collect, 100)[OFFSET(25)], 1) AS p25_days,
    ROUND(APPROX_QUANTILES(days_to_collect, 100)[OFFSET(75)], 1) AS p75_days,
    ROUND(APPROX_QUANTILES(days_to_collect, 100)[OFFSET(90)], 1) AS p90_days,

    -- Total amount collected
    SUM(total_amount) AS total_collected_amount

FROM paid_invoices
GROUP BY due_date_year
ORDER BY due_date_year;


-- =============================================================================
-- DETAIL: MONTHLY TREND
-- =============================================================================
/*
SELECT
    FORMAT_DATE('%Y-%m', DATE_TRUNC(due_date, MONTH)) AS due_month,
    COUNT(*) AS invoices_paid,
    ROUND(AVG(days_to_collect), 1) AS avg_days_to_collect,
    ROUND(APPROX_QUANTILES(days_to_collect, 100)[OFFSET(50)], 1) AS median_days
FROM paid_invoices
GROUP BY DATE_TRUNC(due_date, MONTH)
ORDER BY due_month DESC
LIMIT 24;
*/


-- =============================================================================
-- DETAIL: OUTLIERS (>90 days to collect)
-- =============================================================================
/*
SELECT
    doc_number,
    invoice_created,
    due_date,
    payment_date,
    days_to_collect,
    total_amount
FROM paid_invoices
WHERE days_to_collect > 90
ORDER BY days_to_collect DESC
LIMIT 20;
*/

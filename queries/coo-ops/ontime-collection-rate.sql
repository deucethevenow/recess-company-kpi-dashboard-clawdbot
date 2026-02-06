-- =============================================================================
-- ON-TIME COLLECTION RATE (Metric #2b)
-- =============================================================================
-- Purpose: Track % of invoices paid within 14 days of due date
-- Owner: Deuce (COO) / Accounting
-- Target: 95% (from targets.json)
-- Refresh: Daily
-- Direction: Higher is better
--
-- Formula: % of paid invoices where payment_date <= due_date + 14 days
-- Grouped by: due_date year (2025 baseline vs 2026 current)
-- Note: Includes early payments (paid before due date counts as on-time)
-- =============================================================================

WITH invoice_payments AS (
    SELECT
        inv.id AS invoice_id,
        inv.doc_number,
        inv.transaction_date AS invoice_created,
        inv.due_date,
        inv.total_amount,
        inv.balance,
        pmt.transaction_date AS payment_date,
        EXTRACT(YEAR FROM inv.due_date) AS due_date_year,

        -- On-time = paid within 7 days of due date (includes early payments)
        CASE
            WHEN pmt.transaction_date <= DATE_ADD(inv.due_date, INTERVAL 14 DAY) THEN TRUE
            ELSE FALSE
        END AS is_ontime,

        -- Days from due date (negative = early, positive = late)
        DATE_DIFF(pmt.transaction_date, inv.due_date, DAY) AS days_from_due_date

    FROM `stitchdata-384118.src_fivetran_qbo.invoice` inv
    LEFT JOIN `stitchdata-384118.src_fivetran_qbo.payment_line` pl
        ON inv.id = pl.invoice_id
    LEFT JOIN `stitchdata-384118.src_fivetran_qbo.payment` pmt
        ON pl.payment_id = pmt.id
        AND pmt._fivetran_deleted = FALSE
    WHERE inv._fivetran_deleted = FALSE
      AND EXTRACT(YEAR FROM inv.due_date) IN (2025, 2026)
      AND inv.due_date <= CURRENT_DATE()  -- Only count invoices that are due
)

-- =============================================================================
-- SUMMARY BY YEAR (2025 Baseline vs 2026 Current)
-- =============================================================================
SELECT
    'On-Time Collection Rate' AS metric,
    due_date_year,

    -- Total invoices due
    COUNT(DISTINCT invoice_id) AS total_invoices_due,

    -- Paid invoices
    COUNT(DISTINCT CASE WHEN balance = 0 THEN invoice_id END) AS paid_invoices,

    -- On-time paid (within 7 days of due date)
    COUNT(DISTINCT CASE WHEN balance = 0 AND is_ontime THEN invoice_id END) AS ontime_paid,

    -- Late paid (more than 7 days after due date)
    COUNT(DISTINCT CASE WHEN balance = 0 AND NOT is_ontime THEN invoice_id END) AS late_paid,

    -- Still unpaid
    COUNT(DISTINCT CASE WHEN balance > 0 THEN invoice_id END) AS unpaid,

    -- ON-TIME COLLECTION RATE (% of due invoices paid on time)
    ROUND(
        COUNT(DISTINCT CASE WHEN balance = 0 AND is_ontime THEN invoice_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT invoice_id), 0),
    1) AS ontime_rate_pct,

    -- Target from settings
    95.0 AS target_pct,

    -- Status
    CASE
        WHEN COUNT(DISTINCT CASE WHEN balance = 0 AND is_ontime THEN invoice_id END) * 100.0 /
             NULLIF(COUNT(DISTINCT invoice_id), 0) >= 95 THEN 'GREEN'
        WHEN COUNT(DISTINCT CASE WHEN balance = 0 AND is_ontime THEN invoice_id END) * 100.0 /
             NULLIF(COUNT(DISTINCT invoice_id), 0) >= 90 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM invoice_payments
GROUP BY due_date_year
ORDER BY due_date_year;


-- =============================================================================
-- DETAIL: MONTHLY TREND
-- =============================================================================
/*
SELECT
    FORMAT_DATE('%Y-%m', DATE_TRUNC(due_date, MONTH)) AS due_month,
    COUNT(DISTINCT invoice_id) AS total_due,
    COUNT(DISTINCT CASE WHEN balance = 0 AND is_ontime THEN invoice_id END) AS ontime_paid,
    ROUND(
        COUNT(DISTINCT CASE WHEN balance = 0 AND is_ontime THEN invoice_id END) * 100.0 /
        NULLIF(COUNT(DISTINCT invoice_id), 0),
    1) AS ontime_rate_pct
FROM invoice_payments
GROUP BY DATE_TRUNC(due_date, MONTH)
ORDER BY due_month DESC
LIMIT 24;
*/


-- =============================================================================
-- DETAIL: LATE PAYMENTS (paid >14 days after due)
-- =============================================================================
/*
SELECT
    doc_number,
    due_date,
    payment_date,
    days_from_due_date,
    total_amount
FROM invoice_payments
WHERE balance = 0
  AND NOT is_ontime
ORDER BY days_from_due_date DESC
LIMIT 20;
*/

-- =============================================================================
-- INVOICE COLLECTION RATE (PRIMARY Metric - Deuce)
-- =============================================================================
-- Purpose: Track percentage of invoices collected on time
-- Owner: Deuce (COO)
-- Target: 95%
-- Refresh: Daily
--
-- Formula: Collection Rate = Invoices Paid / Total Invoices Due
-- "On time" = paid within terms (typically Net 30)
-- =============================================================================

WITH invoices AS (
    SELECT
        inv.id AS invoice_id,
        inv.doc_number,
        inv.transaction_date,
        inv.due_date,
        inv.total_amount,
        inv.balance AS outstanding_balance,

        -- Determine if paid
        CASE
            WHEN inv.balance = 0 THEN TRUE
            ELSE FALSE
        END AS is_paid,

        -- Calculate days to pay (for paid invoices, estimate from payment date)
        DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) AS days_past_due,

        -- Age buckets
        CASE
            WHEN inv.balance = 0 THEN 'Paid'
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) <= 0 THEN 'Current'
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 1 AND 30 THEN '1-30 Days'
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 31 AND 60 THEN '31-60 Days'
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 61 AND 90 THEN '61-90 Days'
            ELSE '90+ Days'
        END AS aging_bucket

    FROM `stitchdata-384118.src_fivetran_qbo.invoice` inv
    WHERE inv._fivetran_deleted = FALSE
      AND EXTRACT(YEAR FROM inv.transaction_date) >= EXTRACT(YEAR FROM CURRENT_DATE()) - 1
)

-- Collection Rate Summary
SELECT
    'Invoice Collection Rate' AS metric,
    COUNT(*) AS total_invoices,
    COUNTIF(is_paid) AS paid_invoices,
    COUNTIF(NOT is_paid AND aging_bucket = 'Current') AS current_unpaid,
    COUNTIF(NOT is_paid AND aging_bucket != 'Current') AS overdue_invoices,

    SUM(total_amount) AS total_invoiced,
    SUM(CASE WHEN is_paid THEN total_amount ELSE 0 END) AS total_collected,
    SUM(outstanding_balance) AS total_outstanding,

    ROUND(COUNTIF(is_paid) * 100.0 / COUNT(*), 1) AS collection_rate_by_count,
    ROUND(SUM(CASE WHEN is_paid THEN total_amount ELSE 0 END) * 100.0 /
          NULLIF(SUM(total_amount), 0), 1) AS collection_rate_by_amount,

    95.0 AS target_pct,

    CASE
        WHEN COUNTIF(is_paid) * 100.0 / COUNT(*) >= 95 THEN 'GREEN'
        WHEN COUNTIF(is_paid) * 100.0 / COUNT(*) >= 90 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM invoices
WHERE due_date <= CURRENT_DATE();  -- Only count invoices that are due


-- =============================================================================
-- AR AGING BREAKDOWN
-- =============================================================================
/*
SELECT
    aging_bucket,
    COUNT(*) AS invoice_count,
    SUM(outstanding_balance) AS outstanding_amount,
    ROUND(SUM(outstanding_balance) * 100.0 /
          (SELECT SUM(outstanding_balance) FROM invoices WHERE NOT is_paid), 1) AS pct_of_ar
FROM invoices
WHERE NOT is_paid
GROUP BY aging_bucket
ORDER BY
    CASE aging_bucket
        WHEN 'Current' THEN 1
        WHEN '1-30 Days' THEN 2
        WHEN '31-60 Days' THEN 3
        WHEN '61-90 Days' THEN 4
        WHEN '90+ Days' THEN 5
    END;
*/


-- =============================================================================
-- MONTHLY TREND
-- =============================================================================
/*
SELECT
    FORMAT_DATE('%Y-%m', DATE_TRUNC(due_date, MONTH)) AS month,
    COUNT(*) AS invoices_due,
    COUNTIF(is_paid) AS invoices_collected,
    ROUND(COUNTIF(is_paid) * 100.0 / COUNT(*), 1) AS collection_rate
FROM invoices
WHERE due_date <= CURRENT_DATE()
GROUP BY DATE_TRUNC(due_date, MONTH)
ORDER BY month DESC
LIMIT 12;
*/

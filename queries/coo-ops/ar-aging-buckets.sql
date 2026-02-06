-- =============================================================================
-- AR AGING BUCKETS (Metric #4)
-- =============================================================================
-- Purpose: Break down outstanding AR by age buckets
-- Owner: Deuce (COO) / Accounting
-- Target: N/A (Reporting Only - no goal)
-- Refresh: Daily
--
-- Buckets: 1-30, 31-60, 61-90, 91-120, 120+ days past due
-- Note: Only includes invoices with balance > 0 that are past due
-- =============================================================================

WITH overdue_invoices AS (
    SELECT
        inv.id AS invoice_id,
        inv.doc_number,
        cust.display_name AS customer_name,
        inv.due_date,
        inv.total_amount,
        inv.balance AS outstanding_balance,
        DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) AS days_overdue,

        -- Aging bucket
        CASE
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 1 AND 30 THEN '1-30 Days'
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 31 AND 60 THEN '31-60 Days'
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 61 AND 90 THEN '61-90 Days'
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 91 AND 120 THEN '91-120 Days'
            ELSE '120+ Days'
        END AS aging_bucket,

        -- Bucket sort order
        CASE
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 1 AND 30 THEN 1
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 31 AND 60 THEN 2
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 61 AND 90 THEN 3
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 91 AND 120 THEN 4
            ELSE 5
        END AS bucket_order

    FROM `stitchdata-384118.src_fivetran_qbo.invoice` inv
    LEFT JOIN `stitchdata-384118.src_fivetran_qbo.customer` cust
        ON inv.customer_ref_id = cust.id
        AND cust._fivetran_deleted = FALSE
    WHERE inv._fivetran_deleted = FALSE
      AND inv.balance > 0  -- Has outstanding balance
      AND inv.due_date < CURRENT_DATE()  -- Past due
)

-- =============================================================================
-- SUMMARY BY AGING BUCKET
-- =============================================================================
SELECT
    'AR Aging Buckets' AS metric,
    aging_bucket,

    -- Count of invoices
    COUNT(*) AS invoice_count,

    -- Dollar amounts
    SUM(outstanding_balance) AS bucket_total,
    ROUND(AVG(outstanding_balance), 2) AS avg_invoice_amount,

    -- Percentage of total AR
    ROUND(
        SUM(outstanding_balance) * 100.0 /
        SUM(SUM(outstanding_balance)) OVER (),
    1) AS pct_of_total_ar,

    -- Age stats within bucket
    MIN(days_overdue) AS min_days,
    MAX(days_overdue) AS max_days,

    -- Snapshot timestamp
    CURRENT_TIMESTAMP() AS as_of

FROM overdue_invoices
GROUP BY aging_bucket, bucket_order
ORDER BY bucket_order;


-- =============================================================================
-- TOTAL AR SUMMARY
-- =============================================================================
/*
SELECT
    'Total Overdue AR' AS metric,
    COUNT(*) AS total_invoices,
    SUM(outstanding_balance) AS total_ar,
    ROUND(AVG(outstanding_balance), 2) AS avg_invoice,
    MIN(days_overdue) AS min_days,
    MAX(days_overdue) AS max_days,
    ROUND(AVG(days_overdue), 0) AS avg_days
FROM overdue_invoices;
*/


-- =============================================================================
-- DETAIL: INVOICES IN 120+ BUCKET (Highest Risk)
-- =============================================================================
/*
SELECT
    doc_number,
    customer_name,
    due_date,
    days_overdue,
    outstanding_balance
FROM overdue_invoices
WHERE aging_bucket = '120+ Days'
ORDER BY outstanding_balance DESC
LIMIT 20;
*/


-- =============================================================================
-- DETAIL: CUSTOMER BREAKDOWN WITHIN EACH BUCKET
-- =============================================================================
/*
SELECT
    aging_bucket,
    customer_name,
    COUNT(*) AS invoices,
    SUM(outstanding_balance) AS total_owed
FROM overdue_invoices
GROUP BY aging_bucket, bucket_order, customer_name
ORDER BY bucket_order, total_owed DESC;
*/

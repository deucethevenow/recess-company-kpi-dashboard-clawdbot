-- =============================================================================
-- OVERDUE INVOICES - Count & $ Amount (Metric #3)
-- =============================================================================
-- Purpose: Track invoices past due date with outstanding balance
-- Owner: Deuce (COO) / Accounting
-- Target: 0 overdue (TBD in settings)
-- Refresh: Daily
-- Direction: Lower is better
--
-- Formula: Count + $ where balance > 0 AND due_date < today
-- =============================================================================

WITH overdue AS (
    SELECT
        inv.id AS invoice_id,
        inv.doc_number,
        cust.display_name AS customer_name,
        inv.transaction_date AS invoice_created,
        inv.due_date,
        inv.total_amount,
        inv.balance AS outstanding_balance,
        DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) AS days_overdue,

        -- Aging bucket for detail view
        CASE
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 1 AND 30 THEN '1-30 Days'
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 31 AND 60 THEN '31-60 Days'
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 61 AND 90 THEN '61-90 Days'
            WHEN DATE_DIFF(CURRENT_DATE(), inv.due_date, DAY) BETWEEN 91 AND 120 THEN '91-120 Days'
            ELSE '120+ Days'
        END AS aging_bucket

    FROM `stitchdata-384118.src_fivetran_qbo.invoice` inv
    LEFT JOIN `stitchdata-384118.src_fivetran_qbo.customer` cust
        ON inv.customer_ref_id = cust.id
        AND cust._fivetran_deleted = FALSE
    WHERE inv._fivetran_deleted = FALSE
      AND inv.balance > 0  -- Has outstanding balance
      AND inv.due_date < CURRENT_DATE()  -- Past due
)

-- =============================================================================
-- SUMMARY (Current Snapshot)
-- =============================================================================
SELECT
    'Overdue Invoices' AS metric,

    -- Count
    COUNT(*) AS overdue_count,

    -- Dollar amount
    SUM(outstanding_balance) AS overdue_amount,

    -- Age stats
    MIN(days_overdue) AS min_days_overdue,
    MAX(days_overdue) AS max_days_overdue,
    ROUND(AVG(days_overdue), 0) AS avg_days_overdue,

    -- Target
    0 AS target_count,

    -- Status
    CASE
        WHEN COUNT(*) = 0 THEN 'GREEN'
        WHEN COUNT(*) <= 3 THEN 'YELLOW'
        ELSE 'RED'
    END AS status,

    -- Snapshot timestamp
    CURRENT_TIMESTAMP() AS as_of

FROM overdue;


-- =============================================================================
-- DETAIL: BY AGING BUCKET
-- =============================================================================
/*
SELECT
    aging_bucket,
    COUNT(*) AS invoice_count,
    SUM(outstanding_balance) AS total_overdue,
    ROUND(AVG(outstanding_balance), 2) AS avg_invoice_amount,
    MAX(days_overdue) AS max_days_overdue
FROM overdue
GROUP BY aging_bucket
ORDER BY
    CASE aging_bucket
        WHEN '1-30 Days' THEN 1
        WHEN '31-60 Days' THEN 2
        WHEN '61-90 Days' THEN 3
        WHEN '91-120 Days' THEN 4
        WHEN '120+ Days' THEN 5
    END;
*/


-- =============================================================================
-- DETAIL: TOP OVERDUE CUSTOMERS
-- =============================================================================
/*
SELECT
    customer_name,
    COUNT(*) AS overdue_invoices,
    SUM(outstanding_balance) AS total_overdue,
    MAX(days_overdue) AS max_days_overdue
FROM overdue
GROUP BY customer_name
ORDER BY total_overdue DESC
LIMIT 10;
*/


-- =============================================================================
-- DETAIL: OVERDUE INVOICE LIST (Action Items)
-- =============================================================================
/*
SELECT
    doc_number,
    customer_name,
    invoice_created,
    due_date,
    days_overdue,
    outstanding_balance,
    aging_bucket
FROM overdue
ORDER BY days_overdue DESC, outstanding_balance DESC
LIMIT 50;
*/

-- =============================================================================
-- AVAILABLE FACTORING CAPACITY
-- =============================================================================
-- Purpose: Track available capacity for invoice factoring/financing
-- Owner: Deuce (COO)
-- Target: >$400K available
-- Refresh: Daily
--
-- Factoring: Sell AR invoices at discount for immediate cash
-- Capacity = Total Eligible AR - Already Factored
-- Eligible = Invoices from creditworthy customers, <90 days old
-- =============================================================================

WITH eligible_ar AS (
    -- AR invoices eligible for factoring
    SELECT
        inv.id AS invoice_id,
        inv.doc_number,
        cust.display_name AS customer_name,
        inv.transaction_date,
        inv.due_date,
        inv.total_amount,
        inv.balance AS outstanding_balance,
        DATE_DIFF(CURRENT_DATE(), inv.transaction_date, DAY) AS invoice_age,

        -- Eligibility criteria
        CASE
            WHEN inv.balance <= 0 THEN FALSE  -- Already paid
            WHEN DATE_DIFF(CURRENT_DATE(), inv.transaction_date, DAY) > 90 THEN FALSE  -- Too old
            -- Add customer creditworthiness check if available
            ELSE TRUE
        END AS is_eligible

    FROM `stitchdata-384118.src_fivetran_qbo.invoice` inv
    LEFT JOIN `stitchdata-384118.src_fivetran_qbo.customer` cust
        ON inv.customer_ref_id = cust.id
    WHERE inv._fivetran_deleted = FALSE
      AND cust._fivetran_deleted = FALSE
      AND inv.balance > 0  -- Has outstanding balance
),

factoring_summary AS (
    SELECT
        SUM(outstanding_balance) AS total_ar,
        SUM(CASE WHEN is_eligible THEN outstanding_balance ELSE 0 END) AS eligible_ar,
        SUM(CASE WHEN NOT is_eligible THEN outstanding_balance ELSE 0 END) AS ineligible_ar,
        COUNT(CASE WHEN is_eligible THEN 1 END) AS eligible_invoice_count,
        AVG(CASE WHEN is_eligible THEN invoice_age END) AS avg_eligible_invoice_age
    FROM eligible_ar
)

-- Factoring Capacity
SELECT
    'Available Factoring Capacity' AS metric,
    fs.total_ar,
    fs.eligible_ar,
    fs.ineligible_ar,

    -- Typical factoring advance rate is 80-90%
    ROUND(fs.eligible_ar * 0.85, 2) AS factoring_capacity_at_85pct,
    ROUND(fs.eligible_ar * 0.80, 2) AS factoring_capacity_at_80pct,

    -- Assuming nothing currently factored (adjust if tracking factored invoices)
    0 AS currently_factored,
    ROUND(fs.eligible_ar * 0.85, 2) AS available_capacity,

    400000 AS target,

    fs.eligible_invoice_count,
    ROUND(fs.avg_eligible_invoice_age, 0) AS avg_invoice_age_days,

    CASE
        WHEN fs.eligible_ar * 0.85 >= 400000 THEN 'GREEN'
        WHEN fs.eligible_ar * 0.85 >= 200000 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM factoring_summary fs;


-- =============================================================================
-- ELIGIBLE AR BY CUSTOMER
-- =============================================================================
/*
SELECT
    customer_name,
    COUNT(*) AS invoice_count,
    SUM(outstanding_balance) AS total_ar,
    ROUND(AVG(invoice_age), 0) AS avg_age_days
FROM eligible_ar
WHERE is_eligible
GROUP BY customer_name
ORDER BY total_ar DESC
LIMIT 20;
*/


-- =============================================================================
-- INELIGIBLE AR BREAKDOWN (why not eligible?)
-- =============================================================================
/*
SELECT
    CASE
        WHEN balance <= 0 THEN 'Already Paid'
        WHEN invoice_age > 90 THEN 'Too Old (>90 days)'
        ELSE 'Other'
    END AS ineligibility_reason,
    COUNT(*) AS invoice_count,
    SUM(outstanding_balance) AS total_amount
FROM eligible_ar
WHERE NOT is_eligible
GROUP BY 1
ORDER BY total_amount DESC;
*/

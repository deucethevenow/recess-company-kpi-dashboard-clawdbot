/*
============================================================================
GROSS GMV BY TYPE - DETAILED BREAKDOWN
Shows GMV by customer, cohort, and GMV type (Sampling, Sponsorship, Activation)
Includes invoice/credit memo counts by period
============================================================================

Use this query for:
1. GMV breakdown by type (Sampling vs Sponsorship vs Activation)
2. Transaction volume metrics (invoice/credit memo counts)
3. Customer-level detail with cohort assignment

For the cohort retention matrix view, use: 2026-02-02-gross-gmv-retention-cohort.sql
============================================================================
*/

WITH manual_customer_mapping AS (
    SELECT '6660' AS from_id, '7069' AS to_id
),

/* ============================================================================
   INVOICE GMV (Accounts 4110, 4120, 4130)
   ============================================================================ */
invoice_gmv AS (
    SELECT
        inv.id AS invoice_id,
        inv.doc_number,
        COALESCE(mcm.to_id, cust.parent_customer_id, CAST(inv.customer_id AS STRING)) AS qbo_customer_id,
        cust.display_name AS customer_name,
        inv.transaction_date,
        EXTRACT(YEAR FROM inv.transaction_date) AS gmv_year,
        EXTRACT(MONTH FROM inv.transaction_date) AS gmv_month,
        FORMAT_DATE('%Y-%m', inv.transaction_date) AS period,
        act.account_number,
        act.name AS account_name,
        CASE
            WHEN SAFE_CAST(act.account_number AS INT64) = 4110 THEN 'Sampling GMV'
            WHEN SAFE_CAST(act.account_number AS INT64) = 4120 THEN 'Sponsorship GMV'
            WHEN SAFE_CAST(act.account_number AS INT64) = 4130 THEN 'Activation GMV'
        END AS gmv_type,
        'INVOICE' AS doc_type,
        SUM(CASE WHEN item.name = 'Discount' THEN 0 ELSE l.amount END) AS line_amount,
        SUM(CASE WHEN item.name = 'Discount' THEN l.amount ELSE 0 END) AS discount_amount
    FROM src_fivetran_qbo.invoice AS inv
    JOIN src_fivetran_qbo.invoice_line AS l ON inv.id = l.invoice_id
    JOIN src_fivetran_qbo.customer AS cust ON inv.customer_id = cust.id AND cust._fivetran_deleted = FALSE
    LEFT JOIN manual_customer_mapping AS mcm ON CAST(inv.customer_id AS STRING) = mcm.from_id
    LEFT JOIN src_fivetran_qbo.item AS item ON item.id = l.sales_item_item_id
    LEFT JOIN src_fivetran_qbo.account AS act ON item.income_account_id = act.id
    WHERE inv._fivetran_deleted = FALSE
      AND l.sales_item_unit_price IS NOT NULL
      AND SAFE_CAST(act.account_number AS INT64) IN (4110, 4120, 4130)
      AND EXTRACT(YEAR FROM inv.transaction_date) BETWEEN 2020 AND 2026
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
),

/* ============================================================================
   CREDIT MEMOS for GMV (Accounts 4110, 4120, 4130)
   ============================================================================ */
credit_memo_gmv AS (
    SELECT
        cm.id AS credit_memo_id,
        cm.doc_number,
        COALESCE(mcm.to_id, cust.parent_customer_id, CAST(cm.customer_id AS STRING)) AS qbo_customer_id,
        cust.display_name AS customer_name,
        cm.transaction_date,
        EXTRACT(YEAR FROM cm.transaction_date) AS gmv_year,
        EXTRACT(MONTH FROM cm.transaction_date) AS gmv_month,
        FORMAT_DATE('%Y-%m', cm.transaction_date) AS period,
        act.account_number,
        act.name AS account_name,
        CASE
            WHEN SAFE_CAST(act.account_number AS INT64) = 4110 THEN 'Sampling GMV'
            WHEN SAFE_CAST(act.account_number AS INT64) = 4120 THEN 'Sponsorship GMV'
            WHEN SAFE_CAST(act.account_number AS INT64) = 4130 THEN 'Activation GMV'
        END AS gmv_type,
        'CREDIT_MEMO' AS doc_type,
        -SUM(CASE WHEN item.name = 'Discount' THEN 0 ELSE cl.amount END) AS line_amount,
        -SUM(CASE WHEN item.name = 'Discount' THEN cl.amount ELSE 0 END) AS discount_amount
    FROM src_fivetran_qbo.credit_memo AS cm
    JOIN src_fivetran_qbo.credit_memo_line AS cl ON cm.id = cl.credit_memo_id
    JOIN src_fivetran_qbo.customer AS cust ON cm.customer_id = cust.id AND cust._fivetran_deleted = FALSE
    LEFT JOIN manual_customer_mapping AS mcm ON CAST(cm.customer_id AS STRING) = mcm.from_id
    LEFT JOIN src_fivetran_qbo.item AS item ON item.id = cl.sales_item_item_id
    LEFT JOIN src_fivetran_qbo.account AS act ON item.income_account_id = act.id
    WHERE cm._fivetran_deleted = FALSE
      AND SAFE_CAST(act.account_number AS INT64) IN (4110, 4120, 4130)
      AND EXTRACT(YEAR FROM cm.transaction_date) BETWEEN 2020 AND 2026
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
),

/* ============================================================================
   COMBINED TRANSACTIONS
   ============================================================================ */
all_transactions AS (
    SELECT invoice_id AS doc_id, * EXCEPT(invoice_id) FROM invoice_gmv
    UNION ALL
    SELECT credit_memo_id AS doc_id, * EXCEPT(credit_memo_id) FROM credit_memo_gmv
),

/* ============================================================================
   FIRST GMV YEAR (COHORT ASSIGNMENT)
   ============================================================================ */
first_gmv_year AS (
    SELECT
        qbo_customer_id,
        MIN(gmv_year) AS cohort_year
    FROM invoice_gmv
    WHERE line_amount > 0
    GROUP BY 1
)

/* ============================================================================
   OUTPUT 1: COHORT RETENTION BY GMV TYPE
   Shows dollar retention broken down by Sampling/Sponsorship/Activation
   ============================================================================ */
SELECT
    fgy.cohort_year,
    t.gmv_year,
    t.gmv_type,
    COUNT(DISTINCT t.qbo_customer_id) AS customer_count,
    COUNT(DISTINCT CASE WHEN t.doc_type = 'INVOICE' THEN t.doc_number END) AS invoice_count,
    COUNT(DISTINCT CASE WHEN t.doc_type = 'CREDIT_MEMO' THEN t.doc_number END) AS credit_memo_count,
    ROUND(SUM(t.line_amount + t.discount_amount), 2) AS gross_gmv
FROM all_transactions t
JOIN first_gmv_year fgy ON t.qbo_customer_id = fgy.qbo_customer_id
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

/* ============================================================================
   To get the cohort matrix by GMV type, uncomment the query below
   ============================================================================ */

/*
-- SAMPLING GMV COHORT MATRIX
SELECT
    fgy.cohort_year,
    SUM(CASE WHEN t.gmv_year = 2020 AND t.gmv_type = 'Sampling GMV' THEN t.line_amount + t.discount_amount END) AS sampling_2020,
    SUM(CASE WHEN t.gmv_year = 2021 AND t.gmv_type = 'Sampling GMV' THEN t.line_amount + t.discount_amount END) AS sampling_2021,
    SUM(CASE WHEN t.gmv_year = 2022 AND t.gmv_type = 'Sampling GMV' THEN t.line_amount + t.discount_amount END) AS sampling_2022,
    SUM(CASE WHEN t.gmv_year = 2023 AND t.gmv_type = 'Sampling GMV' THEN t.line_amount + t.discount_amount END) AS sampling_2023,
    SUM(CASE WHEN t.gmv_year = 2024 AND t.gmv_type = 'Sampling GMV' THEN t.line_amount + t.discount_amount END) AS sampling_2024,
    SUM(CASE WHEN t.gmv_year = 2025 AND t.gmv_type = 'Sampling GMV' THEN t.line_amount + t.discount_amount END) AS sampling_2025,
    SUM(CASE WHEN t.gmv_year = 2026 AND t.gmv_type = 'Sampling GMV' THEN t.line_amount + t.discount_amount END) AS sampling_2026
FROM all_transactions t
JOIN first_gmv_year fgy ON t.qbo_customer_id = fgy.qbo_customer_id
GROUP BY 1
ORDER BY 1;
*/

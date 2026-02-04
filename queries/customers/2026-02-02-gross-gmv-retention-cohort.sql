/*
============================================================================
GROSS GMV RETENTION COHORT ANALYSIS BY CUSTOMER
Gross Merchandise Value by First Year Cohort
Shows dollar retention as % of cohort's first year GMV (base = 100%)
============================================================================

GROSS GMV FORMULA:
  Invoice Line Amount (accounts 4110, 4120, 4130)
  + Credit Memos (negative, same accounts)
  = GROSS GMV

GMV ACCOUNTS:
  4110 - 1.1 Sampling GMV
  4120 - 1.2 Sponsorship GMV
  4130 - 1.3 Activation GMV

NOTE: This measures GROSS contract value before organizer fees/COGS deductions.
For net revenue after costs, use cohort_retention_matrix_by_customer.

============================================================================
CUSTOMER ATTRIBUTION STRATEGY:
============================================================================
Uses customer_id from invoice/credit_memo with parent_customer_id rollup
for consolidated customer view.
============================================================================
*/

WITH manual_customer_mapping AS (
    SELECT '6660' AS from_id, '7069' AS to_id
),

/* ============================================================================
   GMV ACCOUNT DEFINITIONS
   ============================================================================ */
gmv_accounts AS (
    SELECT account_number FROM UNNEST([4110, 4120, 4130]) AS account_number
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
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
),

/* ============================================================================
   CREDIT MEMOS for GMV (Accounts 4110, 4120, 4130) - Reduces GMV
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
        act.account_number,
        act.name AS account_name,
        CASE
            WHEN SAFE_CAST(act.account_number AS INT64) = 4110 THEN 'Sampling GMV'
            WHEN SAFE_CAST(act.account_number AS INT64) = 4120 THEN 'Sponsorship GMV'
            WHEN SAFE_CAST(act.account_number AS INT64) = 4130 THEN 'Activation GMV'
        END AS gmv_type,
        'CREDIT_MEMO' AS doc_type,
        -- Credit memos reduce GMV, so negate
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
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
),

/* ============================================================================
   COMBINED TRANSACTION DETAIL
   Useful for drilling into specific invoices/credit memos
   ============================================================================ */
transaction_detail AS (
    SELECT * FROM invoice_gmv
    UNION ALL
    SELECT * FROM credit_memo_gmv
),

/* ============================================================================
   AGGREGATE TO CUSTOMER/YEAR LEVEL
   ============================================================================ */
gmv_by_customer_year AS (
    SELECT
        qbo_customer_id,
        gmv_year,
        SUM(CASE WHEN gmv_type = 'Sampling GMV' THEN line_amount + discount_amount ELSE 0 END) AS sampling_gmv,
        SUM(CASE WHEN gmv_type = 'Sponsorship GMV' THEN line_amount + discount_amount ELSE 0 END) AS sponsorship_gmv,
        SUM(CASE WHEN gmv_type = 'Activation GMV' THEN line_amount + discount_amount ELSE 0 END) AS activation_gmv,
        SUM(line_amount + discount_amount) AS total_gross_gmv,
        COUNT(DISTINCT CASE WHEN doc_type = 'INVOICE' THEN doc_number END) AS invoice_count,
        COUNT(DISTINCT CASE WHEN doc_type = 'CREDIT_MEMO' THEN doc_number END) AS credit_memo_count
    FROM transaction_detail
    GROUP BY 1, 2
),

/* ============================================================================
   COHORT YEAR = First year customer had any GMV invoice
   ============================================================================ */
first_gmv_year AS (
    SELECT
        qbo_customer_id,
        MIN(gmv_year) AS cohort_year
    FROM invoice_gmv
    WHERE line_amount > 0  -- Only count positive invoices for cohort assignment
    GROUP BY 1
),

/* ============================================================================
   CUSTOMER MASTER (for display names)
   ============================================================================ */
customer_master AS (
    SELECT DISTINCT
        td.qbo_customer_id,
        FIRST_VALUE(td.customer_name) OVER (
            PARTITION BY td.qbo_customer_id
            ORDER BY td.transaction_date DESC
        ) AS customer_name
    FROM transaction_detail td
),

/* ============================================================================
   GMV BY CUSTOMER AND COHORT YEAR
   ============================================================================ */
gmv_with_cohort AS (
    SELECT
        gcyear.qbo_customer_id,
        cm.customer_name,
        fgy.cohort_year,
        gcyear.gmv_year,
        gcyear.sampling_gmv,
        gcyear.sponsorship_gmv,
        gcyear.activation_gmv,
        gcyear.total_gross_gmv,
        gcyear.invoice_count,
        gcyear.credit_memo_count
    FROM gmv_by_customer_year gcyear
    JOIN first_gmv_year fgy ON gcyear.qbo_customer_id = fgy.qbo_customer_id
    LEFT JOIN customer_master cm ON gcyear.qbo_customer_id = cm.qbo_customer_id
),

/* ============================================================================
   COHORT TOTALS BY YEAR
   ============================================================================ */
cohort_totals AS (
    SELECT
        cohort_year,
        gmv_year,
        SUM(sampling_gmv) AS total_sampling_gmv,
        SUM(sponsorship_gmv) AS total_sponsorship_gmv,
        SUM(activation_gmv) AS total_activation_gmv,
        SUM(total_gross_gmv) AS total_gross_gmv,
        SUM(invoice_count) AS total_invoices,
        SUM(credit_memo_count) AS total_credit_memos
    FROM gmv_with_cohort
    GROUP BY 1, 2
),

/* ============================================================================
   PIVOT COHORT DATA BY YEAR
   ============================================================================ */
cohort_pivoted AS (
    SELECT
        cohort_year,
        SUM(CASE WHEN gmv_year = 2020 THEN total_gross_gmv ELSE 0 END) AS gmv_2020,
        SUM(CASE WHEN gmv_year = 2021 THEN total_gross_gmv ELSE 0 END) AS gmv_2021,
        SUM(CASE WHEN gmv_year = 2022 THEN total_gross_gmv ELSE 0 END) AS gmv_2022,
        SUM(CASE WHEN gmv_year = 2023 THEN total_gross_gmv ELSE 0 END) AS gmv_2023,
        SUM(CASE WHEN gmv_year = 2024 THEN total_gross_gmv ELSE 0 END) AS gmv_2024,
        SUM(CASE WHEN gmv_year = 2025 THEN total_gross_gmv ELSE 0 END) AS gmv_2025,
        SUM(CASE WHEN gmv_year = 2026 THEN total_gross_gmv ELSE 0 END) AS gmv_2026
    FROM cohort_totals
    GROUP BY cohort_year
),

/* ============================================================================
   BASE YEAR GMV FOR EACH COHORT (for percentage calculations)
   ============================================================================ */
base_gmv AS (
    SELECT
        cohort_year,
        CASE cohort_year
            WHEN 2020 THEN gmv_2020
            WHEN 2021 THEN gmv_2021
            WHEN 2022 THEN gmv_2022
            WHEN 2023 THEN gmv_2023
            WHEN 2024 THEN gmv_2024
            WHEN 2025 THEN gmv_2025
            WHEN 2026 THEN gmv_2026
        END AS base_year_gmv
    FROM cohort_pivoted
)

/* ============================================================================
   FINAL OUTPUT: COHORT RETENTION MATRIX
   Chart 1: Dollar totals
   Chart 2: Grand total
   Chart 3: Percentage retention (base year = 100%)
   ============================================================================ */

-- CHART 1: DOLLAR TOTALS BY COHORT YEAR
SELECT
    'GROSS_GMV_DOLLARS' AS chart,
    cohort_year AS first_year,
    CASE WHEN gmv_2020 > 0 THEN ROUND(gmv_2020, 0) END AS y2020,
    CASE WHEN gmv_2021 > 0 THEN ROUND(gmv_2021, 0) END AS y2021,
    CASE WHEN gmv_2022 > 0 THEN ROUND(gmv_2022, 0) END AS y2022,
    CASE WHEN gmv_2023 > 0 THEN ROUND(gmv_2023, 0) END AS y2023,
    CASE WHEN gmv_2024 > 0 THEN ROUND(gmv_2024, 0) END AS y2024,
    CASE WHEN gmv_2025 > 0 THEN ROUND(gmv_2025, 0) END AS y2025,
    CASE WHEN gmv_2026 > 0 THEN ROUND(gmv_2026, 0) END AS y2026
FROM cohort_pivoted
WHERE cohort_year BETWEEN 2020 AND 2026

UNION ALL

-- GRAND TOTAL ROW
SELECT
    'GROSS_GMV_TOTAL' AS chart,
    NULL AS first_year,
    ROUND(SUM(gmv_2020), 0),
    ROUND(SUM(gmv_2021), 0),
    ROUND(SUM(gmv_2022), 0),
    ROUND(SUM(gmv_2023), 0),
    ROUND(SUM(gmv_2024), 0),
    ROUND(SUM(gmv_2025), 0),
    ROUND(SUM(gmv_2026), 0)
FROM cohort_pivoted
WHERE cohort_year BETWEEN 2020 AND 2026

UNION ALL

-- CHART 2: PERCENTAGE RETENTION (Base Year = 100%)
SELECT
    'GROSS_GMV_PERCENT' AS chart,
    cp.cohort_year AS first_year,
    CASE WHEN cp.cohort_year = 2020 THEN ROUND(cp.gmv_2020 / bg.base_year_gmv * 100, 0) END AS y2020,
    CASE WHEN cp.cohort_year <= 2021 AND cp.gmv_2021 > 0 THEN ROUND(cp.gmv_2021 / bg.base_year_gmv * 100, 0) END AS y2021,
    CASE WHEN cp.cohort_year <= 2022 AND cp.gmv_2022 > 0 THEN ROUND(cp.gmv_2022 / bg.base_year_gmv * 100, 0) END AS y2022,
    CASE WHEN cp.cohort_year <= 2023 AND cp.gmv_2023 > 0 THEN ROUND(cp.gmv_2023 / bg.base_year_gmv * 100, 0) END AS y2023,
    CASE WHEN cp.cohort_year <= 2024 AND cp.gmv_2024 > 0 THEN ROUND(cp.gmv_2024 / bg.base_year_gmv * 100, 0) END AS y2024,
    CASE WHEN cp.cohort_year <= 2025 AND cp.gmv_2025 > 0 THEN ROUND(cp.gmv_2025 / bg.base_year_gmv * 100, 0) END AS y2025,
    CASE WHEN cp.cohort_year <= 2026 AND cp.gmv_2026 > 0 THEN ROUND(cp.gmv_2026 / bg.base_year_gmv * 100, 0) END AS y2026
FROM cohort_pivoted cp
JOIN base_gmv bg ON cp.cohort_year = bg.cohort_year
WHERE cp.cohort_year BETWEEN 2020 AND 2026

ORDER BY
    CASE chart
        WHEN 'GROSS_GMV_DOLLARS' THEN 1
        WHEN 'GROSS_GMV_TOTAL' THEN 2
        WHEN 'GROSS_GMV_PERCENT' THEN 3
    END,
    first_year NULLS LAST;

/*
============================================================================
DEPLOY GROSS GMV VIEWS TO App_KPI_Dashboard
Run this script in BigQuery console to create the views
============================================================================
*/

-- ============================================================================
-- VIEW 1: gross_gmv_retention_cohort
-- Cohort retention matrix for Gross GMV (accounts 4110, 4120, 4130)
-- ============================================================================
CREATE OR REPLACE VIEW `App_KPI_Dashboard.gross_gmv_retention_cohort` AS
WITH manual_customer_mapping AS (
    SELECT '6660' AS from_id, '7069' AS to_id
),

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

transaction_detail AS (
    SELECT * FROM invoice_gmv
    UNION ALL
    SELECT * FROM credit_memo_gmv
),

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

first_gmv_year AS (
    SELECT
        qbo_customer_id,
        MIN(gmv_year) AS cohort_year
    FROM invoice_gmv
    WHERE line_amount > 0
    GROUP BY 1
),

customer_master AS (
    SELECT DISTINCT
        td.qbo_customer_id,
        FIRST_VALUE(td.customer_name) OVER (
            PARTITION BY td.qbo_customer_id
            ORDER BY td.transaction_date DESC
        ) AS customer_name
    FROM transaction_detail td
),

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
WHERE cp.cohort_year BETWEEN 2020 AND 2026;


-- ============================================================================
-- VIEW 2: gross_gmv_by_type_detail
-- GMV breakdown by type (Sampling, Sponsorship, Activation) with transaction counts
-- ============================================================================
CREATE OR REPLACE VIEW `App_KPI_Dashboard.gross_gmv_by_type_detail` AS
WITH manual_customer_mapping AS (
    SELECT '6660' AS from_id, '7069' AS to_id
),

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

all_transactions AS (
    SELECT invoice_id AS doc_id, * EXCEPT(invoice_id) FROM invoice_gmv
    UNION ALL
    SELECT credit_memo_id AS doc_id, * EXCEPT(credit_memo_id) FROM credit_memo_gmv
),

first_gmv_year AS (
    SELECT
        qbo_customer_id,
        MIN(gmv_year) AS cohort_year
    FROM invoice_gmv
    WHERE line_amount > 0
    GROUP BY 1
)

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
GROUP BY 1, 2, 3;

/*
============================================================================
COHORT PAYOUT RETENTION MATRIX BY SUPPLIER
Net Payouts by First Year Cohort - Supplier Payout Waterfall
============================================================================

Purpose: Show supplier payout retention by cohort year
- How much is each supplier cohort getting paid over time?
- NPR % shows payout retention vs their base year

Output Format (3 stacked result sets):
1. PAYOUT_DOLLARS: Dollar totals by cohort and year
2. TOTAL: Grand total row for P&L validation
3. NPR_PERCENT: Net Payout Retention % (base year = 100%)

Color Coding for Dashboard:
- Green: >= 100% (supplier payouts growing)
- Yellow: 50-99% (moderate decline)
- Red: < 50% (significant decline)

Deploy to: App_KPI_Dashboard.cohort_payout_retention_matrix_by_supplier
============================================================================
*/

-- Step 1: Define payout accounts (supplier payments only)
WITH payout_accounts AS (
  SELECT id as account_id, account_number
  FROM `stitchdata-384118.src_fivetran_qbo.account`
  WHERE _fivetran_deleted = FALSE
    AND account_number IN ('4200', '4210', '4220', '4230')
),

-- Step 2: Get supplier org name from MongoDB remittance_line_items
remittance_supplier_map AS (
  SELECT DISTINCT
    rli.bill_number,
    rli.ctx.supplier.org.name as supplier_org_name
  FROM `stitchdata-384118.mongodb.remittance_line_items` rli
  WHERE rli.bill_number IS NOT NULL
    AND rli.ctx.supplier.org.name IS NOT NULL
),

-- Step 3: Get QBO bills with supplier attribution
qbo_payout_bills AS (
  SELECT
    REGEXP_REPLACE(b.doc_number, r'_\d+$', '') as base_bill_number,
    EXTRACT(YEAR FROM b.transaction_date) as txn_year,
    SUM(CAST(bl.amount AS FLOAT64)) as bill_amount
  FROM `stitchdata-384118.src_fivetran_qbo.bill` b
  JOIN `stitchdata-384118.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
  JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
  WHERE b._fivetran_deleted = FALSE
    AND b.transaction_date >= '2022-01-01'
  GROUP BY 1, 2
),

-- Step 4: Get QBO vendor credits linked to bills
qbo_payout_credits AS (
  SELECT
    REGEXP_REPLACE(vc.doc_number, r'(_credit|c\d+)$', '') as bill_number,
    EXTRACT(YEAR FROM vc.transaction_date) as credit_year,
    SUM(CAST(vcl.amount AS FLOAT64)) as credit_amount
  FROM `stitchdata-384118.src_fivetran_qbo.vendor_credit` vc
  JOIN `stitchdata-384118.src_fivetran_qbo.vendor_credit_line` vcl ON vc.id = vcl.vendor_credit_id
  JOIN payout_accounts pa ON vcl.account_expense_account_id = pa.account_id
  WHERE vc._fivetran_deleted = FALSE
    AND REGEXP_CONTAINS(vc.doc_number, r'(_credit|c\d+)$')
    AND vc.transaction_date >= '2022-01-01'
  GROUP BY 1, 2
),

-- Step 5: Combine bills with supplier attribution
bills_with_supplier AS (
  SELECT
    COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name,
    b.txn_year,
    b.bill_amount,
    0.0 as credit_amount
  FROM qbo_payout_bills b
  LEFT JOIN remittance_supplier_map rsm ON b.base_bill_number = rsm.bill_number
),

-- Step 6: Combine credits with supplier attribution
credits_with_supplier AS (
  SELECT
    COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name,
    c.credit_year as txn_year,
    0.0 as bill_amount,
    c.credit_amount
  FROM qbo_payout_credits c
  LEFT JOIN remittance_supplier_map rsm ON c.bill_number = rsm.bill_number
),

-- Step 7: Union all transactions
all_transactions AS (
  SELECT * FROM bills_with_supplier
  UNION ALL
  SELECT * FROM credits_with_supplier
),

-- Step 8: Aggregate payouts by supplier and year
supplier_yearly_payouts AS (
  SELECT
    supplier_org_name,
    txn_year,
    SUM(bill_amount) - SUM(credit_amount) as net_payouts
  FROM all_transactions
  GROUP BY supplier_org_name, txn_year
),

-- Step 9: First payout year (cohort assignment)
first_payout_year AS (
  SELECT
    supplier_org_name,
    MIN(txn_year) as cohort_year
  FROM supplier_yearly_payouts
  WHERE net_payouts > 0
  GROUP BY supplier_org_name
),

-- Step 10: Join payouts with cohort year
cohort_payouts AS (
  SELECT
    fpy.cohort_year,
    syp.txn_year as payout_year,
    SUM(syp.net_payouts) as total_payouts
  FROM supplier_yearly_payouts syp
  JOIN first_payout_year fpy ON syp.supplier_org_name = fpy.supplier_org_name
  WHERE syp.net_payouts > 0
  GROUP BY 1, 2
),

-- Step 11: Pivot by year
cohort_pivoted AS (
  SELECT
    cohort_year,
    SUM(CASE WHEN payout_year = 2022 THEN total_payouts ELSE 0 END) as payout_2022,
    SUM(CASE WHEN payout_year = 2023 THEN total_payouts ELSE 0 END) as payout_2023,
    SUM(CASE WHEN payout_year = 2024 THEN total_payouts ELSE 0 END) as payout_2024,
    SUM(CASE WHEN payout_year = 2025 THEN total_payouts ELSE 0 END) as payout_2025,
    SUM(CASE WHEN payout_year = 2026 THEN total_payouts ELSE 0 END) as payout_2026
  FROM cohort_payouts
  GROUP BY cohort_year
),

-- Step 12: Get base year payout for each cohort
base_payouts AS (
  SELECT
    cohort_year,
    CASE cohort_year
      WHEN 2022 THEN payout_2022
      WHEN 2023 THEN payout_2023
      WHEN 2024 THEN payout_2024
      WHEN 2025 THEN payout_2025
      WHEN 2026 THEN payout_2026
    END AS base_year_payout
  FROM cohort_pivoted
)

/* ============================================================================
   CHART 1: PAYOUT_DOLLARS - Dollar totals by cohort year
   ============================================================================ */
SELECT
  'PAYOUT_DOLLARS' AS chart,
  cohort_year AS first_year,
  CASE WHEN payout_2022 > 0 THEN ROUND(payout_2022, 0) END AS y2022,
  CASE WHEN payout_2023 > 0 THEN ROUND(payout_2023, 0) END AS y2023,
  CASE WHEN payout_2024 > 0 THEN ROUND(payout_2024, 0) END AS y2024,
  CASE WHEN payout_2025 > 0 THEN ROUND(payout_2025, 0) END AS y2025,
  CASE WHEN payout_2026 > 0 THEN ROUND(payout_2026, 0) END AS y2026
FROM cohort_pivoted
WHERE cohort_year BETWEEN 2022 AND 2026

UNION ALL

/* ============================================================================
   CHART 2: TOTAL - Grand total row for P&L validation
   ============================================================================ */
SELECT
  'TOTAL' AS chart,
  NULL AS first_year,
  ROUND(SUM(payout_2022), 0) AS y2022,
  ROUND(SUM(payout_2023), 0) AS y2023,
  ROUND(SUM(payout_2024), 0) AS y2024,
  ROUND(SUM(payout_2025), 0) AS y2025,
  ROUND(SUM(payout_2026), 0) AS y2026
FROM cohort_pivoted
WHERE cohort_year BETWEEN 2022 AND 2026

UNION ALL

/* ============================================================================
   CHART 3: NPR_PERCENT - Net Payout Retention % (base year = 100%)
   ============================================================================ */
SELECT
  'NPR_PERCENT' AS chart,
  cp.cohort_year AS first_year,
  CASE WHEN cp.cohort_year = 2022 THEN ROUND(cp.payout_2022 / bp.base_year_payout * 100, 0) END AS y2022,
  CASE WHEN cp.cohort_year <= 2023 AND cp.payout_2023 > 0 THEN ROUND(cp.payout_2023 / bp.base_year_payout * 100, 0) END AS y2023,
  CASE WHEN cp.cohort_year <= 2024 AND cp.payout_2024 > 0 THEN ROUND(cp.payout_2024 / bp.base_year_payout * 100, 0) END AS y2024,
  CASE WHEN cp.cohort_year <= 2025 AND cp.payout_2025 > 0 THEN ROUND(cp.payout_2025 / bp.base_year_payout * 100, 0) END AS y2025,
  CASE WHEN cp.cohort_year <= 2026 AND cp.payout_2026 > 0 THEN ROUND(cp.payout_2026 / bp.base_year_payout * 100, 0) END AS y2026
FROM cohort_pivoted cp
JOIN base_payouts bp ON cp.cohort_year = bp.cohort_year
WHERE cp.cohort_year BETWEEN 2022 AND 2026

ORDER BY
  CASE chart WHEN 'PAYOUT_DOLLARS' THEN 1 WHEN 'TOTAL' THEN 2 WHEN 'NPR_PERCENT' THEN 3 END,
  first_year NULLS LAST;

-- NRR for Top Supply Users (Financial-Based)
-- Owner: Ashton
-- Target: 110%
-- Purpose: Track revenue retention from top supply partners using ACTUAL financial transaction dates
--
-- Key Difference from nrr-top-supply-users.sql:
-- - Uses QBO bill/credit transaction dates (when money moved) instead of offer acceptance dates
-- - Links QBO bills to MongoDB remittances via bill_number for proper supplier org attribution
-- - Handles WeWork-style scenarios: 200+ QBO vendor accounts → 1 supplier org in MongoDB
-- - Includes vendor credits (adjustments, refunds) properly attributed to base bill
--
-- Linkage Quality (as of 2026-02-05):
-- - 2026: 100% linkage (39/39)
-- - 2025: 98.8% linkage (4,856/4,917)
-- - 2024: 81.3% linkage (3,537/4,351)
-- - 2023: 64.8% linkage (3,797/5,864)
-- - Earlier years have lower linkage rates
--
-- NRR Formula: (Current Year Revenue from Prior Year Suppliers) / (Prior Year Revenue) * 100
-- Revenue = Bills - Vendor Credits (both attributed by transaction_date)

-- Step 1: Define payout accounts (supplier payments only)
WITH payout_accounts AS (
  SELECT id as account_id, account_number, name as account_name
  FROM `stitchdata-384118.src_fivetran_qbo.account`
  WHERE _fivetran_deleted = FALSE
    AND account_number IN ('4200', '4210', '4220', '4230')
    -- 4200: Event Organizer Fee
    -- 4210: Sampling Payouts
    -- 4220: Sponsorship Payouts
    -- 4230: Activation Payouts
),

-- Step 2: Get supplier org name from MongoDB remittance_line_items
-- This provides the top-level org (e.g., "WeWork" not "WeWork - 123 Main St")
remittance_supplier_map AS (
  SELECT DISTINCT
    rli.bill_number,
    rli.ctx.supplier.org.name as supplier_org_name
  FROM `stitchdata-384118.mongodb.remittance_line_items` rli
  WHERE rli.bill_number IS NOT NULL
    AND rli.ctx.supplier.org.name IS NOT NULL
),

-- Step 3: Get QBO bills in payout accounts with transaction dates
qbo_payout_bills AS (
  SELECT
    b.doc_number as bill_number,
    b.transaction_date,
    EXTRACT(YEAR FROM b.transaction_date) as txn_year,
    SUM(CAST(bl.amount AS FLOAT64)) as bill_amount
  FROM `stitchdata-384118.src_fivetran_qbo.bill` b
  JOIN `stitchdata-384118.src_fivetran_qbo.bill_line` bl
    ON b.id = bl.bill_id
  JOIN payout_accounts pa
    ON bl.account_expense_account_id = pa.account_id
  WHERE b._fivetran_deleted = FALSE
    AND b.transaction_date >= '2022-01-01'
  GROUP BY b.doc_number, b.transaction_date
),

-- Step 4: Get QBO vendor credits (refunds/adjustments) linked to bills
-- Credit doc_numbers follow pattern: {bill_number}c1, {bill_number}c2, or {bill_number}_credit
qbo_payout_credits AS (
  SELECT
    -- Extract base bill number from credit doc_number
    REGEXP_REPLACE(vc.doc_number, r'(_credit|c\d+)$', '') as bill_number,
    vc.transaction_date as credit_date,
    EXTRACT(YEAR FROM vc.transaction_date) as credit_year,
    SUM(CAST(vcl.amount AS FLOAT64)) as credit_amount
  FROM `stitchdata-384118.src_fivetran_qbo.vendor_credit` vc
  JOIN `stitchdata-384118.src_fivetran_qbo.vendor_credit_line` vcl
    ON vc.id = vcl.vendor_credit_id
  JOIN payout_accounts pa
    ON vcl.account_expense_account_id = pa.account_id
  WHERE vc._fivetran_deleted = FALSE
    AND REGEXP_CONTAINS(vc.doc_number, r'(_credit|c\d+)$')
    AND vc.transaction_date >= '2022-01-01'
  GROUP BY vc.doc_number, vc.transaction_date
),

-- Step 5: Combine bills with supplier attribution
bills_with_supplier AS (
  SELECT
    COALESCE(rsm.supplier_org_name, 'UNLINKED') as supplier_org_name,
    b.txn_year,
    b.bill_amount,
    0.0 as credit_amount
  FROM qbo_payout_bills b
  LEFT JOIN remittance_supplier_map rsm
    ON b.bill_number = rsm.bill_number
),

-- Step 6: Combine credits with supplier attribution (via linked bill)
credits_with_supplier AS (
  SELECT
    COALESCE(rsm.supplier_org_name, 'UNLINKED') as supplier_org_name,
    c.credit_year as txn_year,
    0.0 as bill_amount,
    c.credit_amount
  FROM qbo_payout_credits c
  LEFT JOIN remittance_supplier_map rsm
    ON c.bill_number = rsm.bill_number
),

-- Step 7: Union all transactions
all_transactions AS (
  SELECT * FROM bills_with_supplier
  UNION ALL
  SELECT * FROM credits_with_supplier
),

-- Step 8: Aggregate by supplier and year (Net Revenue = Bills - Credits)
supplier_yearly_revenue AS (
  SELECT
    supplier_org_name,
    txn_year,
    SUM(bill_amount) as gross_revenue,
    SUM(credit_amount) as credits,
    SUM(bill_amount) - SUM(credit_amount) as net_revenue
  FROM all_transactions
  WHERE supplier_org_name != 'UNLINKED'  -- Exclude unlinked records
  GROUP BY supplier_org_name, txn_year
),

-- Step 9: Pivot to get year-over-year comparison
supplier_pivot AS (
  SELECT
    supplier_org_name,
    SUM(CASE WHEN txn_year = 2022 THEN net_revenue ELSE 0 END) as rev_2022,
    SUM(CASE WHEN txn_year = 2023 THEN net_revenue ELSE 0 END) as rev_2023,
    SUM(CASE WHEN txn_year = 2024 THEN net_revenue ELSE 0 END) as rev_2024,
    SUM(CASE WHEN txn_year = 2025 THEN net_revenue ELSE 0 END) as rev_2025,
    SUM(CASE WHEN txn_year = 2026 THEN net_revenue ELSE 0 END) as rev_2026,
    SUM(net_revenue) as total_ltv
  FROM supplier_yearly_revenue
  GROUP BY supplier_org_name
),

-- Step 10: Calculate NRR for each year
nrr_calculation AS (
  SELECT
    supplier_org_name,
    rev_2022,
    rev_2023,
    rev_2024,
    rev_2025,
    rev_2026,
    total_ltv,

    -- NRR 2023: Revenue from 2022 suppliers in 2023 / Revenue in 2022
    CASE
      WHEN rev_2022 > 0 THEN ROUND(rev_2023 / rev_2022 * 100, 1)
      ELSE NULL
    END as nrr_2023,

    -- NRR 2024: Revenue from 2023 suppliers in 2024 / Revenue in 2023
    CASE
      WHEN rev_2023 > 0 THEN ROUND(rev_2024 / rev_2023 * 100, 1)
      ELSE NULL
    END as nrr_2024,

    -- NRR 2025: Revenue from 2024 suppliers in 2025 / Revenue in 2024
    CASE
      WHEN rev_2024 > 0 THEN ROUND(rev_2025 / rev_2024 * 100, 1)
      ELSE NULL
    END as nrr_2025,

    -- NRR 2026 (YTD): Revenue from 2025 suppliers in 2026 / Revenue in 2025
    CASE
      WHEN rev_2025 > 0 THEN ROUND(rev_2026 / rev_2025 * 100, 1)
      ELSE NULL
    END as nrr_2026_ytd

  FROM supplier_pivot
)

-- Main output: NRR by supplier org (top suppliers only)
SELECT
  supplier_org_name,
  ROUND(rev_2022, 2) as rev_2022,
  ROUND(rev_2023, 2) as rev_2023,
  ROUND(rev_2024, 2) as rev_2024,
  ROUND(rev_2025, 2) as rev_2025,
  ROUND(rev_2026, 2) as rev_2026_ytd,
  nrr_2023,
  nrr_2024,
  nrr_2025,
  nrr_2026_ytd,
  ROUND(total_ltv, 2) as total_ltv
FROM nrr_calculation
WHERE total_ltv >= 10000  -- Focus on suppliers with meaningful volume
ORDER BY total_ltv DESC;


-- ============================================================
-- SUMMARY VIEW: Aggregate NRR across all top suppliers
-- ============================================================
/*
WITH payout_accounts AS (
  SELECT id as account_id
  FROM `stitchdata-384118.src_fivetran_qbo.account`
  WHERE _fivetran_deleted = FALSE
    AND account_number IN ('4200', '4210', '4220', '4230')
),
remittance_supplier_map AS (
  SELECT DISTINCT rli.bill_number, rli.ctx.supplier.org.name as supplier_org_name
  FROM `stitchdata-384118.mongodb.remittance_line_items` rli
  WHERE rli.bill_number IS NOT NULL AND rli.ctx.supplier.org.name IS NOT NULL
),
qbo_payout_bills AS (
  SELECT b.doc_number as bill_number, b.transaction_date, EXTRACT(YEAR FROM b.transaction_date) as txn_year,
    SUM(CAST(bl.amount AS FLOAT64)) as bill_amount
  FROM `stitchdata-384118.src_fivetran_qbo.bill` b
  JOIN `stitchdata-384118.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
  JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
  WHERE b._fivetran_deleted = FALSE AND b.transaction_date >= '2022-01-01'
  GROUP BY b.doc_number, b.transaction_date
),
qbo_payout_credits AS (
  SELECT REGEXP_REPLACE(vc.doc_number, r'(_credit|c\d+)$', '') as bill_number,
    EXTRACT(YEAR FROM vc.transaction_date) as credit_year, SUM(CAST(vcl.amount AS FLOAT64)) as credit_amount
  FROM `stitchdata-384118.src_fivetran_qbo.vendor_credit` vc
  JOIN `stitchdata-384118.src_fivetran_qbo.vendor_credit_line` vcl ON vc.id = vcl.vendor_credit_id
  JOIN payout_accounts pa ON vcl.account_expense_account_id = pa.account_id
  WHERE vc._fivetran_deleted = FALSE AND REGEXP_CONTAINS(vc.doc_number, r'(_credit|c\d+)$') AND vc.transaction_date >= '2022-01-01'
  GROUP BY vc.doc_number, vc.transaction_date
),
bills_with_supplier AS (
  SELECT COALESCE(rsm.supplier_org_name, 'UNLINKED') as supplier_org_name, b.txn_year, b.bill_amount, 0.0 as credit_amount
  FROM qbo_payout_bills b LEFT JOIN remittance_supplier_map rsm ON b.bill_number = rsm.bill_number
),
credits_with_supplier AS (
  SELECT COALESCE(rsm.supplier_org_name, 'UNLINKED') as supplier_org_name, c.credit_year as txn_year, 0.0 as bill_amount, c.credit_amount
  FROM qbo_payout_credits c LEFT JOIN remittance_supplier_map rsm ON c.bill_number = rsm.bill_number
),
all_transactions AS (
  SELECT * FROM bills_with_supplier UNION ALL SELECT * FROM credits_with_supplier
),
supplier_yearly_revenue AS (
  SELECT supplier_org_name, txn_year, SUM(bill_amount) - SUM(credit_amount) as net_revenue
  FROM all_transactions WHERE supplier_org_name != 'UNLINKED'
  GROUP BY supplier_org_name, txn_year
),
supplier_pivot AS (
  SELECT supplier_org_name,
    SUM(CASE WHEN txn_year = 2022 THEN net_revenue ELSE 0 END) as rev_2022,
    SUM(CASE WHEN txn_year = 2023 THEN net_revenue ELSE 0 END) as rev_2023,
    SUM(CASE WHEN txn_year = 2024 THEN net_revenue ELSE 0 END) as rev_2024,
    SUM(CASE WHEN txn_year = 2025 THEN net_revenue ELSE 0 END) as rev_2025,
    SUM(CASE WHEN txn_year = 2026 THEN net_revenue ELSE 0 END) as rev_2026,
    SUM(net_revenue) as total_ltv
  FROM supplier_yearly_revenue GROUP BY supplier_org_name
)
SELECT
  'All Top Suppliers (Financial)' as segment,
  COUNT(*) as supplier_count,
  ROUND(SUM(rev_2022), 2) as rev_2022,
  ROUND(SUM(rev_2023), 2) as rev_2023,
  ROUND(SUM(rev_2024), 2) as rev_2024,
  ROUND(SUM(rev_2025), 2) as rev_2025,
  ROUND(SUM(rev_2026), 2) as rev_2026_ytd,
  ROUND(SUM(rev_2023) / NULLIF(SUM(rev_2022), 0) * 100, 1) as nrr_2023,
  ROUND(SUM(rev_2024) / NULLIF(SUM(rev_2023), 0) * 100, 1) as nrr_2024,
  ROUND(SUM(rev_2025) / NULLIF(SUM(rev_2024), 0) * 100, 1) as nrr_2025,
  ROUND(SUM(rev_2026) / NULLIF(SUM(rev_2025), 0) * 100, 1) as nrr_2026_ytd
FROM supplier_pivot
WHERE total_ltv >= 10000;
*/


-- ============================================================
-- LINKAGE DIAGNOSTICS: Check bill number linkage rates by year
-- ============================================================
/*
WITH payout_accounts AS (
  SELECT id as account_id
  FROM `stitchdata-384118.src_fivetran_qbo.account`
  WHERE _fivetran_deleted = FALSE
    AND account_number IN ('4200', '4210', '4220', '4230')
),
platform_bills AS (
  SELECT DISTINCT rli.bill_number
  FROM `stitchdata-384118.mongodb.remittance_line_items` rli
  WHERE rli.bill_number IS NOT NULL
),
qbo_payout_bills AS (
  SELECT DISTINCT b.doc_number as bill_number, EXTRACT(YEAR FROM b.transaction_date) as txn_year
  FROM `stitchdata-384118.src_fivetran_qbo.bill` b
  JOIN `stitchdata-384118.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
  JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
  WHERE b._fivetran_deleted = FALSE
)
SELECT
  q.txn_year,
  COUNT(q.bill_number) as qbo_bills,
  COUNT(p.bill_number) as linked_to_platform,
  ROUND(COUNT(p.bill_number) * 100.0 / COUNT(q.bill_number), 1) as linkage_pct
FROM qbo_payout_bills q
LEFT JOIN platform_bills p ON q.bill_number = p.bill_number
GROUP BY q.txn_year
ORDER BY q.txn_year DESC;
*/

-- Supply NPR (Net Payout Retention) by Supplier
-- Owner: Supply AM Team
-- Purpose: Track individual supplier payouts with NPR calculations
--
-- Key Features:
-- - Groups unlinked bills as "Unlinked (Not in Platform)" row
-- - Includes TOTAL row for P&L validation
-- - Shows NPR (Net Payout Retention) for each supplier
-- - Totals match QBO P&L exactly (accounts 4200-4230)
--
-- Key Difference from nrr-top-supply-users-financial.sql:
-- - INCLUDES unlinked records (doesn't exclude them)
-- - Uses NPR terminology instead of NRR
-- - Adds TOTAL row for P&L tie-out
--
-- NPR Formula: (Current Year Net Payouts) / (Prior Year Net Payouts) * 100
-- Net Payouts = Bills - Vendor Credits (both attributed by transaction_date)

-- Step 1: Define payout accounts (supplier payments only)
WITH payout_accounts AS (
  SELECT id as account_id, account_number, name as account_name
  FROM `stitchdata-384118.src_fivetran_qbo.account`
  WHERE _fivetran_deleted = FALSE
    AND account_number IN ('4200', '4210', '4220', '4230')
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
-- Strip _2, _3, _4 suffixes to get base bill number for linking split bills to primary
qbo_payout_bills AS (
  SELECT
    b.doc_number as bill_number,
    -- Extract base bill number by removing _2, _3, _4 etc. suffixes
    REGEXP_REPLACE(b.doc_number, r'_\d+$', '') as base_bill_number,
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
-- Use base_bill_number for joining so split bills (_2, _3) link to primary's supplier
-- IMPORTANT: Use "Unlinked (Not in Platform)" for unattributed bills
bills_with_supplier AS (
  SELECT
    COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name,
    b.txn_year,
    b.bill_amount,
    0.0 as credit_amount
  FROM qbo_payout_bills b
  LEFT JOIN remittance_supplier_map rsm
    ON b.base_bill_number = rsm.bill_number  -- Use base bill for split bill linking
),

-- Step 6: Combine credits with supplier attribution (via linked bill)
credits_with_supplier AS (
  SELECT
    COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name,
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

-- Step 8: Aggregate by supplier and year (Net Payouts = Bills - Credits)
-- NO EXCLUSION: Include ALL records including Unlinked
supplier_yearly_payouts AS (
  SELECT
    supplier_org_name,
    txn_year,
    SUM(bill_amount) as gross_bills,
    SUM(credit_amount) as credits,
    SUM(bill_amount) - SUM(credit_amount) as net_payouts
  FROM all_transactions
  -- NO WHERE clause - include Unlinked records for P&L match
  GROUP BY supplier_org_name, txn_year
),

-- Step 9: Pivot to get year-over-year comparison
supplier_pivot AS (
  SELECT
    supplier_org_name,
    SUM(CASE WHEN txn_year = 2022 THEN net_payouts ELSE 0 END) as payout_2022,
    SUM(CASE WHEN txn_year = 2023 THEN net_payouts ELSE 0 END) as payout_2023,
    SUM(CASE WHEN txn_year = 2024 THEN net_payouts ELSE 0 END) as payout_2024,
    SUM(CASE WHEN txn_year = 2025 THEN net_payouts ELSE 0 END) as payout_2025,
    SUM(CASE WHEN txn_year = 2026 THEN net_payouts ELSE 0 END) as payout_2026,
    SUM(net_payouts) as total_ltv
  FROM supplier_yearly_payouts
  GROUP BY supplier_org_name
),

-- Step 10: Calculate NPR for each year
npr_calculation AS (
  SELECT
    supplier_org_name,
    payout_2022,
    payout_2023,
    payout_2024,
    payout_2025,
    payout_2026,
    total_ltv,

    -- NPR 2023: Payouts in 2023 / Payouts in 2022
    CASE
      WHEN payout_2022 > 0 THEN ROUND(payout_2023 / payout_2022 * 100, 1)
      ELSE NULL
    END as npr_2023,

    -- NPR 2024: Payouts in 2024 / Payouts in 2023
    CASE
      WHEN payout_2023 > 0 THEN ROUND(payout_2024 / payout_2023 * 100, 1)
      ELSE NULL
    END as npr_2024,

    -- NPR 2025: Payouts in 2025 / Payouts in 2024
    CASE
      WHEN payout_2024 > 0 THEN ROUND(payout_2025 / payout_2024 * 100, 1)
      ELSE NULL
    END as npr_2025,

    -- NPR 2026 (YTD): Payouts in 2026 / Payouts in 2025
    CASE
      WHEN payout_2025 > 0 THEN ROUND(payout_2026 / payout_2025 * 100, 1)
      ELSE NULL
    END as npr_2026_ytd

  FROM supplier_pivot
)

-- Main output: NPR by supplier org (with meaningful volume OR Unlinked)
SELECT
  supplier_org_name,
  ROUND(payout_2022, 2) as payout_2022,
  ROUND(payout_2023, 2) as payout_2023,
  ROUND(payout_2024, 2) as payout_2024,
  ROUND(payout_2025, 2) as payout_2025,
  ROUND(payout_2026, 2) as payout_2026_ytd,
  npr_2023,
  npr_2024,
  npr_2025,
  npr_2026_ytd,
  ROUND(total_ltv, 2) as total_ltv
FROM npr_calculation
WHERE total_ltv >= 10000 OR supplier_org_name = 'Unlinked (Not in Platform)'

UNION ALL

-- Add TOTAL row for P&L validation
SELECT
  'TOTAL (P&L Match)' as supplier_org_name,
  ROUND(SUM(payout_2022), 2) as payout_2022,
  ROUND(SUM(payout_2023), 2) as payout_2023,
  ROUND(SUM(payout_2024), 2) as payout_2024,
  ROUND(SUM(payout_2025), 2) as payout_2025,
  ROUND(SUM(payout_2026), 2) as payout_2026_ytd,
  ROUND(SUM(payout_2023) / NULLIF(SUM(payout_2022), 0) * 100, 1) as npr_2023,
  ROUND(SUM(payout_2024) / NULLIF(SUM(payout_2023), 0) * 100, 1) as npr_2024,
  ROUND(SUM(payout_2025) / NULLIF(SUM(payout_2024), 0) * 100, 1) as npr_2025,
  ROUND(SUM(payout_2026) / NULLIF(SUM(payout_2025), 0) * 100, 1) as npr_2026_ytd,
  ROUND(SUM(total_ltv), 2) as total_ltv
FROM npr_calculation

ORDER BY
  CASE
    WHEN supplier_org_name = 'TOTAL (P&L Match)' THEN 1
    WHEN supplier_org_name = 'Unlinked (Not in Platform)' THEN 2
    ELSE 3
  END,
  total_ltv DESC;


-- ============================================================
-- LINKAGE DIAGNOSTICS: Check unlinked $ by year
-- ============================================================
/*
WITH payout_accounts AS (
  SELECT id as account_id
  FROM `stitchdata-384118.src_fivetran_qbo.account`
  WHERE _fivetran_deleted = FALSE
    AND account_number IN ('4200', '4210', '4220', '4230')
),
remittance_supplier_map AS (
  SELECT DISTINCT rli.bill_number
  FROM `stitchdata-384118.mongodb.remittance_line_items` rli
  WHERE rli.bill_number IS NOT NULL
),
qbo_payout_bills AS (
  SELECT
    REGEXP_REPLACE(b.doc_number, r'_\d+$', '') as base_bill_number,
    EXTRACT(YEAR FROM b.transaction_date) as txn_year,
    SUM(CAST(bl.amount AS FLOAT64)) as bill_amount
  FROM `stitchdata-384118.src_fivetran_qbo.bill` b
  JOIN `stitchdata-384118.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
  JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
  WHERE b._fivetran_deleted = FALSE
  GROUP BY 1, 2
)
SELECT
  txn_year,
  SUM(CASE WHEN rsm.bill_number IS NULL THEN bill_amount ELSE 0 END) as unlinked_amount,
  SUM(CASE WHEN rsm.bill_number IS NOT NULL THEN bill_amount ELSE 0 END) as linked_amount,
  SUM(bill_amount) as total_amount,
  ROUND(SUM(CASE WHEN rsm.bill_number IS NULL THEN bill_amount ELSE 0 END) * 100.0 / SUM(bill_amount), 2) as unlinked_pct
FROM qbo_payout_bills qb
LEFT JOIN remittance_supplier_map rsm ON qb.base_bill_number = rsm.bill_number
GROUP BY 1
ORDER BY 1 DESC;
*/

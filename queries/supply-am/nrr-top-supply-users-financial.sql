-- NPR (Net Payout Retention) for Top Supply Users (Financial-Based)
-- Owner: Ashton / Supply AM Team
-- Target: 110%
-- Purpose: Track payout retention from top supply partners using ACTUAL financial transaction dates
--
-- TERMINOLOGY CHANGE (2026-02-05):
-- - "NPR" (Net Payout Retention) for suppliers - did they get paid more?
-- - "NRR" (Net Revenue Retention) for customers - did they spend more?
--
-- Key Difference from nrr-top-supply-users.sql:
-- - Uses QBO bill/credit transaction dates (when money moved) instead of offer acceptance dates
-- - Links QBO bills to MongoDB remittances via bill_number for proper supplier org attribution
-- - Handles WeWork-style scenarios: 200+ QBO vendor accounts → 1 supplier org in MongoDB
-- - Includes vendor credits (adjustments, refunds) properly attributed to base bill
-- - Handles split bills (_2, _3 suffix) by linking to primary bill's supplier
-- - INCLUDES unlinked bills as "Unlinked (Not in Platform)" row for P&L tie-out
--
-- Linkage Quality (as of 2026-02-05, after split bill handling):
-- - 2026: ~100% linkage
-- - 2025: ~99.6% linkage (after split bill fix)
-- - 2024: ~98% linkage (after split bill fix)
-- - Earlier years have lower linkage rates
--
-- NPR Formula: (Current Year Payouts from Prior Year Suppliers) / (Prior Year Payouts) * 100
-- Payouts = Bills - Vendor Credits (both attributed by transaction_date)

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
-- CHANGED: Use "Unlinked (Not in Platform)" instead of "UNLINKED"
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
-- CHANGED: Include ALL records including Unlinked for P&L tie-out
supplier_yearly_revenue AS (
  SELECT
    supplier_org_name,
    txn_year,
    SUM(bill_amount) as gross_revenue,
    SUM(credit_amount) as credits,
    SUM(bill_amount) - SUM(credit_amount) as net_revenue
  FROM all_transactions
  -- NO EXCLUSION: Include Unlinked for P&L matching
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

-- Step 10: Calculate NPR (Net Payout Retention) for each year
npr_calculation AS (
  SELECT
    supplier_org_name,
    rev_2022,
    rev_2023,
    rev_2024,
    rev_2025,
    rev_2026,
    total_ltv,

    -- NPR 2023: Payouts in 2023 / Payouts in 2022
    CASE
      WHEN rev_2022 > 0 THEN ROUND(rev_2023 / rev_2022 * 100, 1)
      ELSE NULL
    END as npr_2023,

    -- NPR 2024: Payouts in 2024 / Payouts in 2023
    CASE
      WHEN rev_2023 > 0 THEN ROUND(rev_2024 / rev_2023 * 100, 1)
      ELSE NULL
    END as npr_2024,

    -- NPR 2025: Payouts in 2025 / Payouts in 2024
    CASE
      WHEN rev_2024 > 0 THEN ROUND(rev_2025 / rev_2024 * 100, 1)
      ELSE NULL
    END as npr_2025,

    -- NPR 2026 (YTD): Payouts in 2026 / Payouts in 2025
    CASE
      WHEN rev_2025 > 0 THEN ROUND(rev_2026 / rev_2025 * 100, 1)
      ELSE NULL
    END as npr_2026_ytd

  FROM supplier_pivot
)

-- Main output: NPR by supplier org (top suppliers + Unlinked row)
SELECT
  supplier_org_name,
  ROUND(rev_2022, 2) as payout_2022,
  ROUND(rev_2023, 2) as payout_2023,
  ROUND(rev_2024, 2) as payout_2024,
  ROUND(rev_2025, 2) as payout_2025,
  ROUND(rev_2026, 2) as payout_2026_ytd,
  npr_2023,
  npr_2024,
  npr_2025,
  npr_2026_ytd,
  ROUND(total_ltv, 2) as total_ltv
FROM npr_calculation
WHERE total_ltv >= 10000 OR supplier_org_name = 'Unlinked (Not in Platform)'
ORDER BY
  CASE WHEN supplier_org_name = 'Unlinked (Not in Platform)' THEN 1 ELSE 0 END,
  total_ltv DESC;


-- ============================================================
-- SUMMARY VIEW: Aggregate NPR across all suppliers (P&L Matched)
-- NOTE: Use supply-npr-summary-by-year.sql for P&L tie-out
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
  SELECT COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name, b.txn_year, b.bill_amount, 0.0 as credit_amount
  FROM qbo_payout_bills b LEFT JOIN remittance_supplier_map rsm ON b.bill_number = rsm.bill_number
),
credits_with_supplier AS (
  SELECT COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name, c.credit_year as txn_year, 0.0 as bill_amount, c.credit_amount
  FROM qbo_payout_credits c LEFT JOIN remittance_supplier_map rsm ON c.bill_number = rsm.bill_number
),
all_transactions AS (
  SELECT * FROM bills_with_supplier UNION ALL SELECT * FROM credits_with_supplier
),
supplier_yearly_revenue AS (
  SELECT supplier_org_name, txn_year, SUM(bill_amount) - SUM(credit_amount) as net_revenue
  FROM all_transactions
  -- NO EXCLUSION: Include all for P&L tie-out
  GROUP BY supplier_org_name, txn_year
),
supplier_pivot AS (
  SELECT supplier_org_name,
    SUM(CASE WHEN txn_year = 2022 THEN net_revenue ELSE 0 END) as payout_2022,
    SUM(CASE WHEN txn_year = 2023 THEN net_revenue ELSE 0 END) as payout_2023,
    SUM(CASE WHEN txn_year = 2024 THEN net_revenue ELSE 0 END) as payout_2024,
    SUM(CASE WHEN txn_year = 2025 THEN net_revenue ELSE 0 END) as payout_2025,
    SUM(CASE WHEN txn_year = 2026 THEN net_revenue ELSE 0 END) as payout_2026,
    SUM(net_revenue) as total_ltv
  FROM supplier_yearly_revenue GROUP BY supplier_org_name
)
SELECT
  'All Suppliers (P&L Match)' as segment,
  COUNT(*) as supplier_count,
  ROUND(SUM(payout_2022), 2) as payout_2022,
  ROUND(SUM(payout_2023), 2) as payout_2023,
  ROUND(SUM(payout_2024), 2) as payout_2024,
  ROUND(SUM(payout_2025), 2) as payout_2025,
  ROUND(SUM(payout_2026), 2) as payout_2026_ytd,
  ROUND(SUM(payout_2023) / NULLIF(SUM(payout_2022), 0) * 100, 1) as npr_2023,
  ROUND(SUM(payout_2024) / NULLIF(SUM(payout_2023), 0) * 100, 1) as npr_2024,
  ROUND(SUM(payout_2025) / NULLIF(SUM(payout_2024), 0) * 100, 1) as npr_2025,
  ROUND(SUM(payout_2026) / NULLIF(SUM(payout_2025), 0) * 100, 1) as npr_2026_ytd
FROM supplier_pivot;
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

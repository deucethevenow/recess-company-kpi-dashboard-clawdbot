-- Supply NPR (Net Payout Retention) Summary by Year
-- Owner: Supply AM Team
-- Purpose: Track aggregate supplier payouts year-over-year, matching QBO P&L exactly
--
-- Key Features:
-- - Matches QBO accounts 4200, 4210, 4220, 4230 exactly (P&L tie-out)
-- - Shows Gross Bills, Vendor Credits, Net Payouts by year
-- - Calculates NPR (Net Payout Retention) as % change vs prior year
--
-- Account Mapping:
-- - 4200: Event Organizer Fee
-- - 4210: Sampling Payouts
-- - 4220: Sponsorship Payouts
-- - 4230: Activation Payouts
--
-- NPR Formula: (Current Year Net Payouts) / (Prior Year Net Payouts) * 100
-- Net Payouts = Gross Bills - Vendor Credits
--
-- P&L Validation: 2025 Net Payouts should equal $4,045,628

-- Step 1: Define payout accounts (supplier payments only)
WITH payout_accounts AS (
  SELECT id as account_id, account_number, name as account_name
  FROM `stitchdata-384118.src_fivetran_qbo.account`
  WHERE _fivetran_deleted = FALSE
    AND account_number IN ('4200', '4210', '4220', '4230')
),

-- Step 2: All QBO bills in payout accounts
all_bills AS (
  SELECT
    EXTRACT(YEAR FROM b.transaction_date) as txn_year,
    SUM(CAST(bl.amount AS FLOAT64)) as gross_bills
  FROM `stitchdata-384118.src_fivetran_qbo.bill` b
  JOIN `stitchdata-384118.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
  JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
  WHERE b._fivetran_deleted = FALSE
  GROUP BY 1
),

-- Step 3: All QBO vendor credits in payout accounts
all_credits AS (
  SELECT
    EXTRACT(YEAR FROM vc.transaction_date) as txn_year,
    SUM(CAST(vcl.amount AS FLOAT64)) as vendor_credits
  FROM `stitchdata-384118.src_fivetran_qbo.vendor_credit` vc
  JOIN `stitchdata-384118.src_fivetran_qbo.vendor_credit_line` vcl ON vc.id = vcl.vendor_credit_id
  JOIN payout_accounts pa ON vcl.account_expense_account_id = pa.account_id
  WHERE vc._fivetran_deleted = FALSE
  GROUP BY 1
),

-- Step 4: Combine by year (FULL OUTER JOIN to capture all years)
yearly_totals AS (
  SELECT
    COALESCE(b.txn_year, c.txn_year) as year,
    COALESCE(b.gross_bills, 0) as gross_bills,
    COALESCE(c.vendor_credits, 0) as vendor_credits,
    COALESCE(b.gross_bills, 0) - COALESCE(c.vendor_credits, 0) as net_payouts
  FROM all_bills b
  FULL OUTER JOIN all_credits c ON b.txn_year = c.txn_year
)

-- Main output: NPR summary by year
SELECT
  year,
  ROUND(gross_bills, 2) as gross_bills,
  ROUND(vendor_credits, 2) as vendor_credits,
  ROUND(net_payouts, 2) as net_payouts,
  ROUND(net_payouts / NULLIF(LAG(net_payouts) OVER (ORDER BY year), 0) * 100, 1) as npr_vs_prior_year
FROM yearly_totals
WHERE year >= 2022
ORDER BY year;


-- ============================================================
-- DIAGNOSTIC: Check individual account totals for P&L validation
-- ============================================================
/*
WITH payout_accounts AS (
  SELECT id as account_id, account_number, name as account_name
  FROM `stitchdata-384118.src_fivetran_qbo.account`
  WHERE _fivetran_deleted = FALSE
    AND account_number IN ('4200', '4210', '4220', '4230')
)
SELECT
  pa.account_number,
  pa.account_name,
  EXTRACT(YEAR FROM b.transaction_date) as year,
  SUM(CAST(bl.amount AS FLOAT64)) as bills,
  0 as vendor_credits
FROM `stitchdata-384118.src_fivetran_qbo.bill` b
JOIN `stitchdata-384118.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
WHERE b._fivetran_deleted = FALSE
  AND EXTRACT(YEAR FROM b.transaction_date) = 2025
GROUP BY 1, 2, 3
UNION ALL
SELECT
  pa.account_number,
  pa.account_name,
  EXTRACT(YEAR FROM vc.transaction_date) as year,
  0 as bills,
  SUM(CAST(vcl.amount AS FLOAT64)) as vendor_credits
FROM `stitchdata-384118.src_fivetran_qbo.vendor_credit` vc
JOIN `stitchdata-384118.src_fivetran_qbo.vendor_credit_line` vcl ON vc.id = vcl.vendor_credit_id
JOIN payout_accounts pa ON vcl.account_expense_account_id = pa.account_id
WHERE vc._fivetran_deleted = FALSE
  AND EXTRACT(YEAR FROM vc.transaction_date) = 2025
GROUP BY 1, 2, 3
ORDER BY account_number, year;
*/

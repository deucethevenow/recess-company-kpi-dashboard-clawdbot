/*
============================================================================
SUPPLIER DEVELOPMENT VIEW
Mirrors customer_development for supply-side analysis
============================================================================

Purpose: Track supplier health with 3 key metrics per supplier:
  1. Net Revenue (what Recess keeps)
  2. GMV (total marketplace value)
  3. Organizer Payout (what supplier gets paid)

Core Action State Logic:
  - Active: Has payouts in current period, stable or growing
  - Loosing: Has payouts but declining >50% YoY
  - Lost: Had payouts last year, none this year
  - Inactive: No recent payouts (dormant relationship)

Data Sources:
  - QBO Bills (4200-4230): Supplier payouts
  - QBO Vendor Credits (4200-4230): Reduces payouts
  - MongoDB remittance_line_items: Maps bills to supplier org
  - Supplier_Metrics view: GMV by supplier (if available)

Deploy to: App_KPI_Dashboard.Supplier_Development
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
-- Strip _2, _3, _4 suffixes for split bill handling
qbo_payout_bills AS (
  SELECT
    b.doc_number as bill_number,
    REGEXP_REPLACE(b.doc_number, r'_\d+$', '') as base_bill_number,
    b.transaction_date,
    EXTRACT(YEAR FROM b.transaction_date) as txn_year,
    SUM(CAST(bl.amount AS FLOAT64)) as bill_amount
  FROM `stitchdata-384118.src_fivetran_qbo.bill` b
  JOIN `stitchdata-384118.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
  JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
  WHERE b._fivetran_deleted = FALSE
    AND b.transaction_date >= '2022-01-01'
  GROUP BY b.doc_number, b.transaction_date
),

-- Step 4: Get QBO vendor credits linked to bills
qbo_payout_credits AS (
  SELECT
    REGEXP_REPLACE(vc.doc_number, r'(_credit|c\d+)$', '') as bill_number,
    vc.transaction_date as credit_date,
    EXTRACT(YEAR FROM vc.transaction_date) as credit_year,
    SUM(CAST(vcl.amount AS FLOAT64)) as credit_amount
  FROM `stitchdata-384118.src_fivetran_qbo.vendor_credit` vc
  JOIN `stitchdata-384118.src_fivetran_qbo.vendor_credit_line` vcl ON vc.id = vcl.vendor_credit_id
  JOIN payout_accounts pa ON vcl.account_expense_account_id = pa.account_id
  WHERE vc._fivetran_deleted = FALSE
    AND REGEXP_CONTAINS(vc.doc_number, r'(_credit|c\d+)$')
    AND vc.transaction_date >= '2022-01-01'
  GROUP BY vc.doc_number, vc.transaction_date
),

-- Step 5: Combine bills with supplier attribution
bills_with_supplier AS (
  SELECT
    COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name,
    b.txn_year,
    b.transaction_date,
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
    c.credit_date as transaction_date,
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
    MAX(transaction_date) as last_payout_date,
    SUM(bill_amount) as gross_bills,
    SUM(credit_amount) as vendor_credits,
    SUM(bill_amount) - SUM(credit_amount) as net_payouts
  FROM all_transactions
  GROUP BY supplier_org_name, txn_year
),

-- Step 9: First payout year (cohort assignment)
first_payout_year AS (
  SELECT
    supplier_org_name,
    MIN(txn_year) as first_year
  FROM supplier_yearly_payouts
  WHERE net_payouts > 0
  GROUP BY supplier_org_name
),

-- Step 10: Last payout date
last_payout AS (
  SELECT
    supplier_org_name,
    MAX(last_payout_date) as last_payout_date
  FROM supplier_yearly_payouts
  GROUP BY supplier_org_name
),

-- Step 11: Pivot payouts by year
supplier_pivot AS (
  SELECT
    supplier_org_name,
    SUM(CASE WHEN txn_year = 2022 THEN net_payouts ELSE 0 END) as payout_2022,
    SUM(CASE WHEN txn_year = 2023 THEN net_payouts ELSE 0 END) as payout_2023,
    SUM(CASE WHEN txn_year = 2024 THEN net_payouts ELSE 0 END) as payout_2024,
    SUM(CASE WHEN txn_year = 2025 THEN net_payouts ELSE 0 END) as payout_2025,
    SUM(CASE WHEN txn_year = 2026 THEN net_payouts ELSE 0 END) as payout_2026,
    SUM(net_payouts) as total_payout
  FROM supplier_yearly_payouts
  GROUP BY supplier_org_name
)

-- Main output: Supplier Development View
SELECT
  sp.supplier_org_name,
  fpy.first_year,
  lp.last_payout_date,

  -- Core Action State (based on 2024/2025 payout activity)
  CASE
    WHEN sp.payout_2025 > 0 AND sp.payout_2024 > 0 THEN
      CASE
        WHEN (sp.payout_2024 - sp.payout_2025) / NULLIF(sp.payout_2024, 0) > 0.50
        THEN 'loosing'
        ELSE 'active'
      END
    WHEN sp.payout_2025 > 0 THEN 'active'  -- New or reactivated in 2025
    WHEN sp.payout_2024 > 0 THEN 'lost'    -- Had 2024, none in 2025
    ELSE 'inactive'                         -- No recent activity
  END as core_action_state,

  -- Payouts by Year (what supplier gets paid)
  ROUND(sp.payout_2022, 2) as payout_2022,
  ROUND(sp.payout_2023, 2) as payout_2023,
  ROUND(sp.payout_2024, 2) as payout_2024,
  ROUND(sp.payout_2025, 2) as payout_2025,
  ROUND(sp.payout_2026, 2) as payout_2026,
  ROUND(sp.total_payout, 2) as total_payout,

  -- NPR (Net Payout Retention) by Year
  CASE WHEN sp.payout_2022 > 0 THEN ROUND(sp.payout_2023 / sp.payout_2022 * 100, 1) END as npr_2023,
  CASE WHEN sp.payout_2023 > 0 THEN ROUND(sp.payout_2024 / sp.payout_2023 * 100, 1) END as npr_2024,
  CASE WHEN sp.payout_2024 > 0 THEN ROUND(sp.payout_2025 / sp.payout_2024 * 100, 1) END as npr_2025,
  CASE WHEN sp.payout_2025 > 0 THEN ROUND(sp.payout_2026 / sp.payout_2025 * 100, 1) END as npr_2026

FROM supplier_pivot sp
LEFT JOIN first_payout_year fpy ON sp.supplier_org_name = fpy.supplier_org_name
LEFT JOIN last_payout lp ON sp.supplier_org_name = lp.supplier_org_name
WHERE sp.total_payout > 0  -- Only include suppliers with actual payouts
ORDER BY sp.total_payout DESC;

-- Core Action State Counts for Supply (Suppliers)
-- Owner: Supply AM Team
-- Purpose: Dashboard metrics for Active/Loosing/Lost supplier counts
--
-- Core Action States:
-- - Active: Has payouts in 2025, stable or growing vs 2024
-- - Loosing: Has payouts in 2025 but declining >50% vs 2024
-- - Lost: Had payouts in 2024, none in 2025
-- - Inactive: No payouts in 2024 or 2025 (dormant)
--
-- Output: Counts and $ totals for each state

WITH payout_accounts AS (
  SELECT id as account_id
  FROM `stitchdata-384118.src_fivetran_qbo.account`
  WHERE _fivetran_deleted = FALSE
    AND account_number IN ('4200', '4210', '4220', '4230')
),

remittance_supplier_map AS (
  SELECT DISTINCT
    rli.bill_number,
    rli.ctx.supplier.org.name as supplier_org_name
  FROM `stitchdata-384118.mongodb.remittance_line_items` rli
  WHERE rli.bill_number IS NOT NULL
    AND rli.ctx.supplier.org.name IS NOT NULL
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
    AND EXTRACT(YEAR FROM b.transaction_date) IN (2024, 2025)
  GROUP BY 1, 2
),

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
    AND EXTRACT(YEAR FROM vc.transaction_date) IN (2024, 2025)
  GROUP BY 1, 2
),

bills_with_supplier AS (
  SELECT
    COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name,
    b.txn_year,
    b.bill_amount,
    0.0 as credit_amount
  FROM qbo_payout_bills b
  LEFT JOIN remittance_supplier_map rsm ON b.base_bill_number = rsm.bill_number
),

credits_with_supplier AS (
  SELECT
    COALESCE(rsm.supplier_org_name, 'Unlinked (Not in Platform)') as supplier_org_name,
    c.credit_year as txn_year,
    0.0 as bill_amount,
    c.credit_amount
  FROM qbo_payout_credits c
  LEFT JOIN remittance_supplier_map rsm ON c.bill_number = rsm.bill_number
),

all_transactions AS (
  SELECT * FROM bills_with_supplier
  UNION ALL
  SELECT * FROM credits_with_supplier
),

supplier_yearly_payouts AS (
  SELECT
    supplier_org_name,
    txn_year,
    SUM(bill_amount) - SUM(credit_amount) as net_payouts
  FROM all_transactions
  GROUP BY supplier_org_name, txn_year
),

supplier_pivot AS (
  SELECT
    supplier_org_name,
    SUM(CASE WHEN txn_year = 2024 THEN net_payouts ELSE 0 END) as payout_2024,
    SUM(CASE WHEN txn_year = 2025 THEN net_payouts ELSE 0 END) as payout_2025
  FROM supplier_yearly_payouts
  GROUP BY supplier_org_name
),

supplier_states AS (
  SELECT
    supplier_org_name,
    payout_2024,
    payout_2025,
    CASE
      WHEN payout_2025 > 0 AND payout_2024 > 0 THEN
        CASE
          WHEN (payout_2024 - payout_2025) / NULLIF(payout_2024, 0) > 0.50
          THEN 'loosing'
          ELSE 'active'
        END
      WHEN payout_2025 > 0 THEN 'active'  -- New or reactivated in 2025
      WHEN payout_2024 > 0 THEN 'lost'    -- Had 2024, none in 2025
      ELSE 'inactive'                      -- No recent activity
    END as core_action_state
  FROM supplier_pivot
  WHERE payout_2024 > 0 OR payout_2025 > 0  -- Exclude inactive (no activity at all)
)

-- Main output: State counts and totals
SELECT
  core_action_state,
  COUNT(*) as supplier_count,
  ROUND(SUM(payout_2024), 2) as total_payout_2024,
  ROUND(SUM(payout_2025), 2) as total_payout_2025,
  ROUND(SUM(payout_2025) / NULLIF(SUM(payout_2024), 0) * 100, 1) as npr_2025
FROM supplier_states
GROUP BY core_action_state

UNION ALL

-- Total row
SELECT
  'TOTAL' as core_action_state,
  COUNT(*) as supplier_count,
  ROUND(SUM(payout_2024), 2) as total_payout_2024,
  ROUND(SUM(payout_2025), 2) as total_payout_2025,
  ROUND(SUM(payout_2025) / NULLIF(SUM(payout_2024), 0) * 100, 1) as npr_2025
FROM supplier_states

ORDER BY
  CASE core_action_state
    WHEN 'active' THEN 1
    WHEN 'loosing' THEN 2
    WHEN 'lost' THEN 3
    WHEN 'inactive' THEN 4
    WHEN 'TOTAL' THEN 5
  END;

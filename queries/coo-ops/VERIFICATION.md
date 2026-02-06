# COO/Ops Query Verification

> **Last Verified:** 2026-02-04
> **Status:** ⚠️ Needs BigQuery validation

## Query Audit Summary

| Query | Data Source | `_fivetran_deleted` | Status | Notes |
|-------|-------------|:-------------------:|:------:|-------|
| `gross-margin.sql` | QBO invoice_line, bill_line, account | ✅ | ⚠️ Verify | Check account_number format |
| `invoice-collection-rate.sql` | QBO invoice | ✅ | ✅ OK | |
| `overdue-invoices.sql` | QBO invoice, customer | ✅ | ✅ OK | |
| `working-capital.sql` | QBO account | ✅ | ✅ OK | |
| `months-of-runway.sql` | QBO account, bill, bill_line | ✅ | ⚠️ Verify | Bills may not capture all expenses |
| `top-customer-concentration.sql` | `net_revenue_retention_all_customers` | N/A | ✅ OK | Uses authoritative view |
| `net-revenue-gap.sql` | QBO invoice + `HS_QBO_GMV_Waterfall` | ✅ | ⚠️ Verify | Check GMV Waterfall column names |
| `factoring-capacity.sql` | QBO invoice, customer | ✅ | ✅ OK | |

## Items to Verify in BigQuery

### 1. Gross Margin - Account Numbers
```sql
-- Verify account numbers are strings and match expected format
SELECT account_number, name, account_type
FROM `stitchdata-384118.src_fivetran_qbo.account`
WHERE account_number IN ('4110', '4120', '4130')
   OR CAST(account_number AS STRING) LIKE '41%';
```

### 2. Gross Margin - COGS Account Range
```sql
-- Verify COGS accounts exist in 5000-5999 range
SELECT account_number, name, account_type
FROM `stitchdata-384118.src_fivetran_qbo.account`
WHERE SAFE_CAST(account_number AS INT64) BETWEEN 5000 AND 5999;
```

### 3. Net Revenue Gap - GMV Waterfall Columns
```sql
-- Verify column names in HS_QBO_GMV_Waterfall
SELECT column_name
FROM `stitchdata-384118.App_KPI_Dashboard.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'HS_QBO_GMV_Waterfall';
```

### 4. Months of Runway - Expense Coverage
```sql
-- Check if bills capture majority of expenses
-- Compare to P&L if available
SELECT
    DATE_TRUNC(transaction_date, MONTH) AS month,
    SUM(ABS(total_amount)) AS total_bills
FROM `stitchdata-384118.src_fivetran_qbo.bill`
WHERE _fivetran_deleted = FALSE
  AND transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH)
GROUP BY month
ORDER BY month DESC;
```

## Known Gotchas Applied

| Gotcha | Applied In |
|--------|------------|
| `_fivetran_deleted = FALSE` on QBO tables | All queries ✅ |
| Revenue accounts 4110, 4120, 4130 only | gross-margin.sql ✅ |
| Use authoritative views for NRR/concentration | top-customer-concentration.sql ✅ |
| AR aging from `due_date` not `transaction_date` | invoice-collection-rate.sql, overdue-invoices.sql ✅ |

## Potential Improvements

1. **Gross Margin**: Consider using `journal_entry` for more comprehensive revenue/expense capture
2. **Runway**: Add payroll data source if bills don't include payroll expenses
3. **Factoring**: Add customer creditworthiness criteria if available
4. **All queries**: Add date range parameters for flexibility

## Validation Steps

Before deploying to production:

1. [ ] Run each query in BigQuery console
2. [ ] Verify row counts are reasonable
3. [ ] Spot-check values against QBO reports
4. [ ] Test traffic light thresholds with known values
5. [ ] Confirm GMV Waterfall view column names

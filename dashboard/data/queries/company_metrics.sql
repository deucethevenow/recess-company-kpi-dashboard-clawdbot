/*
============================================================================
COMPANY METRICS - ALL IN ONE QUERY
============================================================================

This query returns all company-level KPIs for the Overview page.
Used for both direct queries and as the basis for scheduled refresh.

Metrics:
- revenue_ytd: Total YTD revenue (accounts 4000-4190)
- take_rate: Services Revenue / GMV
- nrr: Net Revenue Retention (from view)
- customer_count: Active customers
- logo_retention: Customer retention rate

============================================================================
*/

-- Revenue YTD
SELECT
    'revenue_ytd' as metric_key,
    SUM(il.amount) as metric_value,
    'currency' as metric_format,
    2026 as fiscal_year,
    CURRENT_TIMESTAMP() as updated_at
FROM `stitchdata-384118.src_fivetran_qbo.invoice_line` il
JOIN `stitchdata-384118.src_fivetran_qbo.invoice` i
    ON il.invoice_id = i.id
JOIN `stitchdata-384118.src_fivetran_qbo.account` a
    ON il.sales_item_account_ref_value = CAST(a.id AS STRING)
WHERE EXTRACT(YEAR FROM i.txn_date) = 2026
    AND CAST(a.acct_num AS INT64) BETWEEN 4000 AND 4190
    AND CAST(a.acct_num AS INT64) NOT IN (4250, 4260, 4300, 4310)

UNION ALL

-- Take Rate
SELECT
    'take_rate' as metric_key,
    SAFE_DIVIDE(
        SUM(CASE WHEN CAST(a.acct_num AS INT64) BETWEEN 4000 AND 4099 THEN il.amount ELSE 0 END),
        SUM(CASE WHEN CAST(a.acct_num AS INT64) BETWEEN 4100 AND 4199 THEN il.amount ELSE 0 END)
    ) as metric_value,
    'percent' as metric_format,
    2026 as fiscal_year,
    CURRENT_TIMESTAMP() as updated_at
FROM `stitchdata-384118.src_fivetran_qbo.invoice_line` il
JOIN `stitchdata-384118.src_fivetran_qbo.invoice` i
    ON il.invoice_id = i.id
JOIN `stitchdata-384118.src_fivetran_qbo.account` a
    ON il.sales_item_account_ref_value = CAST(a.id AS STRING)
WHERE EXTRACT(YEAR FROM i.txn_date) = 2026

UNION ALL

-- NRR (from existing view)
SELECT
    'nrr' as metric_key,
    SAFE_DIVIDE(SUM(net_revenue_2026), SUM(net_revenue_2025)) as metric_value,
    'percent' as metric_format,
    2026 as fiscal_year,
    CURRENT_TIMESTAMP() as updated_at
FROM `stitchdata-384118.App_KPI_Dashboard.net_revenue_retention_all_customers`
WHERE qbo_customer_id != 'UNKNOWN'
    AND net_revenue_2025 > 0

UNION ALL

-- Customer Count (active in current year)
SELECT
    'customer_count' as metric_key,
    COUNT(DISTINCT qbo_customer_id) as metric_value,
    'number' as metric_format,
    2026 as fiscal_year,
    CURRENT_TIMESTAMP() as updated_at
FROM `stitchdata-384118.App_KPI_Dashboard.customer_development`
WHERE revenue_2026 > 0

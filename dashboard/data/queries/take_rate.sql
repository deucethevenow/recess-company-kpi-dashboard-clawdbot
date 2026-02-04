/*
============================================================================
TAKE RATE CALCULATION
============================================================================

Formula: (4000 Services Revenue) / (4100 GMV)

This measures what percentage of Gross Merchandise Value (GMV) the platform
keeps as service revenue. A key marketplace metric.

Accounts:
- 4000-4099: Services Revenue (numerator)
- 4100-4199: Marketplace Revenue / GMV (denominator)

============================================================================
*/

WITH revenue_data AS (
    SELECT
        EXTRACT(YEAR FROM i.txn_date) as fiscal_year,
        SUM(CASE
            WHEN CAST(a.acct_num AS INT64) BETWEEN 4000 AND 4099
            THEN il.amount
            ELSE 0
        END) as services_revenue,
        SUM(CASE
            WHEN CAST(a.acct_num AS INT64) BETWEEN 4100 AND 4199
            THEN il.amount
            ELSE 0
        END) as gmv
    FROM `stitchdata-384118.src_fivetran_qbo.invoice_line` il
    JOIN `stitchdata-384118.src_fivetran_qbo.invoice` i
        ON il.invoice_id = i.id
    JOIN `stitchdata-384118.src_fivetran_qbo.account` a
        ON il.sales_item_account_ref_value = CAST(a.id AS STRING)
    WHERE EXTRACT(YEAR FROM i.txn_date) >= 2024
    GROUP BY 1
)
SELECT
    fiscal_year,
    services_revenue,
    gmv,
    SAFE_DIVIDE(services_revenue, gmv) as take_rate,
    CURRENT_TIMESTAMP() as calculated_at
FROM revenue_data
ORDER BY fiscal_year DESC

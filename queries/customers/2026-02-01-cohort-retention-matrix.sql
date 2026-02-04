/*
============================================================================
COHORT RETENTION MATRIX BY CUSTOMER
Net Revenue by First Year Cohort - Customer-Attributed Version (v3)
Shows dollar retention as % of cohort's first year revenue (base = 100%)
============================================================================

NET REVENUE FORMULA (Direct GL Approach):
  Invoice Line Amount (accounts 4000-4190)
  + Credit Memos (negative)
  + Organizer Fees/Bills (accounts 4200-4240, negative)
  + Vendor Credits (accounts 4200-4240, positive)
  = NET REVENUE

NOTE: Excludes accounts 4250, 4260, 4300, 4310 (Shipping, Digital Media,
      Activation Services, Platform Subscription) per business decision.

============================================================================
CUSTOMER ATTRIBUTION STRATEGY (v3 - Enhanced with Class Lookup):
============================================================================
This query uses a TIERED APPROACH for customer attribution of organizer fees:

1. DIRECT: bill_line.account_expense_customer_id (if customer has invoices)
2. CLASS-BASED: class.name matched to customer.display_name (if customer has invoices)
   - Exact match first
   - Manual mapping for close matches (e.g., "Google" -> "Google LLC")
3. EXCLUDED: Org fees for customers without invoice revenue are excluded
   (these appear in the UNKNOWN bucket in net_revenue_retention_all_customers)

NOTE: This cohort matrix shows CUSTOMER-LEVEL data only. It does not include
an UNKNOWN bucket because cohort analysis requires a cohort year (first invoice).
For P&L tie-out totals, use net_revenue_retention_all_customers which includes
an UNKNOWN row capturing all unattributed organizer fees.
============================================================================
*/

WITH manual_customer_mapping AS (
    SELECT '6660' AS from_id, '7069' AS to_id
),

/* ============================================================================
   CLASS NAME TO CUSTOMER ID MAPPING
   Maps class.name to customer.id for organizer fees without direct customer_id
   Includes both exact matches (via JOIN) and manual mappings for close matches
   ============================================================================ */
class_to_customer_manual_mapping AS (
    SELECT class_name, qbo_customer_id FROM UNNEST([
        STRUCT('5 Hour Energy' AS class_name, '3498' AS qbo_customer_id),
        STRUCT('Google' AS class_name, '1968' AS qbo_customer_id),
        STRUCT('Lyft' AS class_name, '1444' AS qbo_customer_id),
        STRUCT('Miller Coors' AS class_name, '1962' AS qbo_customer_id),
        STRUCT('Brew Dr Kombucha' AS class_name, '1930' AS qbo_customer_id),
        STRUCT('American Campus Communities' AS class_name, '1657' AS qbo_customer_id),
        STRUCT('Apple - 2019 - Spring 10 Events & Food Trucks' AS class_name, '2075' AS qbo_customer_id),
        STRUCT('Square - 2019 - Fall 5 Campus' AS class_name, NULL AS qbo_customer_id),
        STRUCT('Square - 2019 - Dunnkirk Show' AS class_name, NULL AS qbo_customer_id)
    ])
),

class_to_customer_lookup AS (
    SELECT
        c.id AS class_id,
        c.name AS class_name,
        COALESCE(
            mcm.qbo_customer_id,
            COALESCE(cust.parent_customer_id, CAST(cust.id AS STRING))
        ) AS qbo_customer_id
    FROM src_fivetran_qbo.class AS c
    LEFT JOIN class_to_customer_manual_mapping AS mcm ON c.name = mcm.class_name
    LEFT JOIN src_fivetran_qbo.customer AS cust
        ON LOWER(c.name) = LOWER(cust.display_name) AND cust._fivetran_deleted = FALSE
    WHERE c._fivetran_deleted = FALSE
),

/* ============================================================================
   CUSTOMERS WITH INVOICE REVENUE (for filtering org fees)
   Only attribute org fees to customers that have at least one invoice
   ============================================================================ */
invoice_customers AS (
    SELECT DISTINCT COALESCE(cust.parent_customer_id, CAST(inv.customer_id AS STRING)) AS qbo_customer_id
    FROM src_fivetran_qbo.invoice AS inv
    JOIN src_fivetran_qbo.invoice_line AS l ON inv.id = l.invoice_id
    JOIN src_fivetran_qbo.customer AS cust ON inv.customer_id = cust.id AND cust._fivetran_deleted = FALSE
    LEFT JOIN src_fivetran_qbo.item AS item ON item.id = l.sales_item_item_id
    LEFT JOIN src_fivetran_qbo.account AS act ON item.income_account_id = act.id
    WHERE inv._fivetran_deleted = FALSE
      AND l.sales_item_unit_price IS NOT NULL
      AND SAFE_CAST(act.account_number AS INT64) BETWEEN 4000 AND 4190
),

/* ============================================================================
   INVOICE REVENUE (Accounts 4000-4190)
   ============================================================================ */
invoice_revenue AS (
    SELECT
        inv.doc_number AS invoice_id,
        COALESCE(mcm.to_id, cust.parent_customer_id, CAST(inv.customer_id AS STRING)) AS qbo_customer_id,
        EXTRACT(YEAR FROM inv.transaction_date) AS revenue_year,
        SUM(CASE WHEN item.name = 'Discount' THEN 0 ELSE l.amount END) AS line_amount,
        SUM(CASE WHEN item.name = 'Discount' THEN l.amount ELSE 0 END) AS discount
    FROM src_fivetran_qbo.invoice AS inv
    JOIN src_fivetran_qbo.invoice_line AS l ON inv.id = l.invoice_id
    JOIN src_fivetran_qbo.customer AS cust ON inv.customer_id = cust.id AND cust._fivetran_deleted = FALSE
    LEFT JOIN manual_customer_mapping AS mcm ON CAST(inv.customer_id AS STRING) = mcm.from_id
    LEFT JOIN src_fivetran_qbo.item AS item ON item.id = l.sales_item_item_id
    LEFT JOIN src_fivetran_qbo.account AS act ON item.income_account_id = act.id
    WHERE inv._fivetran_deleted = FALSE
      AND l.sales_item_unit_price IS NOT NULL
      AND SAFE_CAST(act.account_number AS INT64) BETWEEN 4000 AND 4190
      AND EXTRACT(YEAR FROM inv.transaction_date) BETWEEN 2020 AND 2026
    GROUP BY 1, 2, 3
),

/* ============================================================================
   CREDIT MEMOS (Accounts 4000-4190) - Reduces Revenue
   ============================================================================ */
credit_memos AS (
    SELECT
        COALESCE(mcm.to_id, cust.parent_customer_id, CAST(cm.customer_id AS STRING)) AS qbo_customer_id,
        EXTRACT(YEAR FROM cm.transaction_date) AS revenue_year,
        -SUM(CASE WHEN item.name = 'Discount' THEN 0 ELSE cl.amount END) AS credit_memo,
        -SUM(CASE WHEN item.name = 'Discount' THEN cl.amount ELSE 0 END) AS cm_discount
    FROM src_fivetran_qbo.credit_memo AS cm
    JOIN src_fivetran_qbo.credit_memo_line AS cl ON cm.id = cl.credit_memo_id
    JOIN src_fivetran_qbo.customer AS cust ON cm.customer_id = cust.id AND cust._fivetran_deleted = FALSE
    LEFT JOIN manual_customer_mapping AS mcm ON CAST(cm.customer_id AS STRING) = mcm.from_id
    LEFT JOIN src_fivetran_qbo.item AS item ON item.id = cl.sales_item_item_id
    LEFT JOIN src_fivetran_qbo.account AS act ON item.income_account_id = act.id
    WHERE cm._fivetran_deleted = FALSE
      AND SAFE_CAST(act.account_number AS INT64) BETWEEN 4000 AND 4190
      AND EXTRACT(YEAR FROM cm.transaction_date) BETWEEN 2020 AND 2026
    GROUP BY 1, 2
),

/* ============================================================================
   ORGANIZER FEES (Accounts 4200-4240) - Bills paid to venues, reduces revenue
   TIERED ATTRIBUTION (only for customers with invoice revenue):
   1. Direct: bill_line.account_expense_customer_id
   2. Class-based: class.name matched to customer.display_name (exact or manual)
   ============================================================================ */
organizer_fees AS (
    SELECT
        COALESCE(
            mcm.to_id,
            cust.parent_customer_id,
            bl.account_expense_customer_id,
            class_lookup.qbo_customer_id
        ) AS qbo_customer_id,
        EXTRACT(YEAR FROM b.transaction_date) AS revenue_year,
        -SUM(bl.amount) AS org_fees
    FROM src_fivetran_qbo.bill AS b
    JOIN src_fivetran_qbo.bill_line AS bl ON b.id = bl.bill_id
    JOIN src_fivetran_qbo.account AS act ON bl.account_expense_account_id = act.id
    LEFT JOIN src_fivetran_qbo.customer AS cust
        ON bl.account_expense_customer_id = CAST(cust.id AS STRING) AND cust._fivetran_deleted = FALSE
    LEFT JOIN manual_customer_mapping AS mcm ON bl.account_expense_customer_id = mcm.from_id
    LEFT JOIN class_to_customer_lookup AS class_lookup
        ON bl.account_expense_class_id = class_lookup.class_id
    WHERE b._fivetran_deleted = FALSE
      AND SAFE_CAST(act.account_number AS INT64) BETWEEN 4200 AND 4240
      AND EXTRACT(YEAR FROM b.transaction_date) BETWEEN 2020 AND 2026
      AND COALESCE(bl.account_expense_customer_id, class_lookup.qbo_customer_id) IS NOT NULL
      -- Only include org fees for customers with invoice revenue
      AND COALESCE(mcm.to_id, cust.parent_customer_id, bl.account_expense_customer_id, class_lookup.qbo_customer_id)
          IN (SELECT qbo_customer_id FROM invoice_customers)
    GROUP BY 1, 2
),

/* ============================================================================
   VENDOR CREDITS (Accounts 4200-4240) - Reduces what we owe venues, adds to revenue
   TIERED ATTRIBUTION (only for customers with invoice revenue):
   1. Direct: vendor_credit_line.account_expense_customer_id
   2. Class-based: class.name matched to customer.display_name
   ============================================================================ */
vendor_credits AS (
    SELECT
        COALESCE(
            mcm.to_id,
            cust.parent_customer_id,
            vcl.account_expense_customer_id,
            class_lookup.qbo_customer_id
        ) AS qbo_customer_id,
        EXTRACT(YEAR FROM vc.transaction_date) AS revenue_year,
        SUM(vcl.amount) AS vendor_credit
    FROM src_fivetran_qbo.vendor_credit AS vc
    JOIN src_fivetran_qbo.vendor_credit_line AS vcl ON vc.id = vcl.vendor_credit_id
    JOIN src_fivetran_qbo.account AS act ON vcl.account_expense_account_id = act.id
    LEFT JOIN src_fivetran_qbo.customer AS cust
        ON vcl.account_expense_customer_id = CAST(cust.id AS STRING) AND cust._fivetran_deleted = FALSE
    LEFT JOIN manual_customer_mapping AS mcm ON vcl.account_expense_customer_id = mcm.from_id
    LEFT JOIN class_to_customer_lookup AS class_lookup
        ON vcl.account_expense_class_id = class_lookup.class_id
    WHERE vc._fivetran_deleted = FALSE
      AND SAFE_CAST(act.account_number AS INT64) BETWEEN 4200 AND 4240
      AND EXTRACT(YEAR FROM vc.transaction_date) BETWEEN 2020 AND 2026
      AND COALESCE(vcl.account_expense_customer_id, class_lookup.qbo_customer_id) IS NOT NULL
      AND COALESCE(mcm.to_id, cust.parent_customer_id, vcl.account_expense_customer_id, class_lookup.qbo_customer_id)
          IN (SELECT qbo_customer_id FROM invoice_customers)
    GROUP BY 1, 2
),

/* ============================================================================
   AGGREGATE INVOICE REVENUE TO CUSTOMER/YEAR LEVEL
   ============================================================================ */
invoice_by_customer_year AS (
    SELECT
        qbo_customer_id,
        revenue_year,
        SUM(line_amount + discount) AS invoice_net
    FROM invoice_revenue
    GROUP BY 1, 2
),

/* ============================================================================
   COHORT YEAR = First year customer had any invoice (revenue accounts only)
   ============================================================================ */
first_invoice_year AS (
    SELECT
        qbo_customer_id,
        MIN(revenue_year) AS cohort_year
    FROM invoice_revenue
    GROUP BY 1
),

/* ============================================================================
   CUSTOMER/YEAR SPINE - All combinations from ANY transaction type
   This ensures credit memos, org fees, vendor credits appear in correct period
   even if no invoice exists in that year
   ============================================================================ */
customer_year_spine AS (
    SELECT DISTINCT qbo_customer_id, revenue_year FROM invoice_by_customer_year
    UNION DISTINCT
    SELECT DISTINCT qbo_customer_id, revenue_year FROM credit_memos
    UNION DISTINCT
    SELECT DISTINCT qbo_customer_id, revenue_year FROM organizer_fees
    UNION DISTINCT
    SELECT DISTINCT qbo_customer_id, revenue_year FROM vendor_credits
),

/* ============================================================================
   NET REVENUE BY CUSTOMER AND YEAR
   Uses spine to include ALL transactions in their correct period
   ============================================================================ */
net_revenue_by_customer_year AS (
    SELECT
        spine.qbo_customer_id,
        spine.revenue_year,
        COALESCE(icy.invoice_net, 0) AS invoice_net,
        COALESCE(cm.credit_memo, 0) + COALESCE(cm.cm_discount, 0) AS credit_memo_net,
        COALESCE(orgf.org_fees, 0) AS org_fees,
        COALESCE(vc.vendor_credit, 0) AS vendor_credit,
        ROUND(
            COALESCE(icy.invoice_net, 0)
            + COALESCE(cm.credit_memo, 0) + COALESCE(cm.cm_discount, 0)
            + COALESCE(orgf.org_fees, 0)
            + COALESCE(vc.vendor_credit, 0)
        , 2) AS net_revenue
    FROM customer_year_spine spine
    LEFT JOIN invoice_by_customer_year icy
        ON spine.qbo_customer_id = icy.qbo_customer_id AND spine.revenue_year = icy.revenue_year
    LEFT JOIN credit_memos cm
        ON spine.qbo_customer_id = cm.qbo_customer_id AND spine.revenue_year = cm.revenue_year
    LEFT JOIN organizer_fees orgf
        ON spine.qbo_customer_id = orgf.qbo_customer_id AND spine.revenue_year = orgf.revenue_year
    LEFT JOIN vendor_credits vc
        ON spine.qbo_customer_id = vc.qbo_customer_id AND spine.revenue_year = vc.revenue_year
),

/* Join with cohort year and aggregate by cohort */
cohort_revenue AS (
    SELECT
        fiy.cohort_year,
        nr.revenue_year,
        SUM(nr.net_revenue) AS total_net_revenue
    FROM net_revenue_by_customer_year nr
    JOIN first_invoice_year fiy ON nr.qbo_customer_id = fiy.qbo_customer_id
    WHERE nr.net_revenue > 0
    GROUP BY 1, 2
),

/* Pivot by year */
cohort_pivoted AS (
    SELECT
        cohort_year,
        SUM(CASE WHEN revenue_year = 2020 THEN total_net_revenue ELSE 0 END) AS rev_2020,
        SUM(CASE WHEN revenue_year = 2021 THEN total_net_revenue ELSE 0 END) AS rev_2021,
        SUM(CASE WHEN revenue_year = 2022 THEN total_net_revenue ELSE 0 END) AS rev_2022,
        SUM(CASE WHEN revenue_year = 2023 THEN total_net_revenue ELSE 0 END) AS rev_2023,
        SUM(CASE WHEN revenue_year = 2024 THEN total_net_revenue ELSE 0 END) AS rev_2024,
        SUM(CASE WHEN revenue_year = 2025 THEN total_net_revenue ELSE 0 END) AS rev_2025,
        SUM(CASE WHEN revenue_year = 2026 THEN total_net_revenue ELSE 0 END) AS rev_2026
    FROM cohort_revenue
    GROUP BY cohort_year
),

/* Get base year revenue for each cohort */
base_revenue AS (
    SELECT
        cohort_year,
        CASE cohort_year
            WHEN 2020 THEN rev_2020
            WHEN 2021 THEN rev_2021
            WHEN 2022 THEN rev_2022
            WHEN 2023 THEN rev_2023
            WHEN 2024 THEN rev_2024
            WHEN 2025 THEN rev_2025
            WHEN 2026 THEN rev_2026
        END AS base_year_revenue
    FROM cohort_pivoted
)

/* ============================================================================
   CHART 1: DOLLAR TOTALS BY COHORT YEAR
   ============================================================================ */
SELECT
    'DOLLARS' AS chart,
    cohort_year AS first_year,
    CASE WHEN rev_2020 > 0 THEN ROUND(rev_2020, 0) END AS y2020,
    CASE WHEN rev_2021 > 0 THEN ROUND(rev_2021, 0) END AS y2021,
    CASE WHEN rev_2022 > 0 THEN ROUND(rev_2022, 0) END AS y2022,
    CASE WHEN rev_2023 > 0 THEN ROUND(rev_2023, 0) END AS y2023,
    CASE WHEN rev_2024 > 0 THEN ROUND(rev_2024, 0) END AS y2024,
    CASE WHEN rev_2025 > 0 THEN ROUND(rev_2025, 0) END AS y2025,
    CASE WHEN rev_2026 > 0 THEN ROUND(rev_2026, 0) END AS y2026
FROM cohort_pivoted
WHERE cohort_year BETWEEN 2020 AND 2026

UNION ALL

/* Grand Total row */
SELECT
    'TOTAL' AS chart,
    NULL AS first_year,
    ROUND(SUM(rev_2020), 0),
    ROUND(SUM(rev_2021), 0),
    ROUND(SUM(rev_2022), 0),
    ROUND(SUM(rev_2023), 0),
    ROUND(SUM(rev_2024), 0),
    ROUND(SUM(rev_2025), 0),
    ROUND(SUM(rev_2026), 0)
FROM cohort_pivoted
WHERE cohort_year BETWEEN 2020 AND 2026

UNION ALL

/* ============================================================================
   CHART 2: PERCENTAGE RETENTION (Base Year = 100%)
   ============================================================================ */
SELECT
    'PERCENT' AS chart,
    cp.cohort_year AS first_year,
    CASE WHEN cp.cohort_year = 2020 THEN ROUND(cp.rev_2020 / br.base_year_revenue * 100, 0) END AS y2020,
    CASE WHEN cp.cohort_year <= 2021 AND cp.rev_2021 > 0 THEN ROUND(cp.rev_2021 / br.base_year_revenue * 100, 0) END AS y2021,
    CASE WHEN cp.cohort_year <= 2022 AND cp.rev_2022 > 0 THEN ROUND(cp.rev_2022 / br.base_year_revenue * 100, 0) END AS y2022,
    CASE WHEN cp.cohort_year <= 2023 AND cp.rev_2023 > 0 THEN ROUND(cp.rev_2023 / br.base_year_revenue * 100, 0) END AS y2023,
    CASE WHEN cp.cohort_year <= 2024 AND cp.rev_2024 > 0 THEN ROUND(cp.rev_2024 / br.base_year_revenue * 100, 0) END AS y2024,
    CASE WHEN cp.cohort_year <= 2025 AND cp.rev_2025 > 0 THEN ROUND(cp.rev_2025 / br.base_year_revenue * 100, 0) END AS y2025,
    CASE WHEN cp.cohort_year <= 2026 AND cp.rev_2026 > 0 THEN ROUND(cp.rev_2026 / br.base_year_revenue * 100, 0) END AS y2026
FROM cohort_pivoted cp
JOIN base_revenue br ON cp.cohort_year = br.cohort_year
WHERE cp.cohort_year BETWEEN 2020 AND 2026

ORDER BY
    CASE chart WHEN 'DOLLARS' THEN 1 WHEN 'TOTAL' THEN 2 WHEN 'PERCENT' THEN 3 END,
    first_year NULLS LAST;

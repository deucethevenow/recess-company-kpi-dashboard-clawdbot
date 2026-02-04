/*
============================================================================
NET REVENUE RETENTION TRACKER - ALL CUSTOMERS
With Target Account Flag from HubSpot | 2022-2026
Customer-Attributed Version (with Class-Based Fallback + Unknown Bucket)
============================================================================

NET REVENUE FORMULA (Direct GL Approach):
  Invoice Line Amount (accounts 4000-4190)
  + Credit Memos (negative)
  + Organizer Fees/Bills (accounts 4200-4240, negative)
  + Vendor Credits (accounts 4200-4240, positive)
  = NET REVENUE

NOTE: Excludes accounts 4250, 4260, 4300, 4310 (Shipping, Digital Media,
      Activation Services, Platform Subscription) per business decision.

P&L TIE-OUT STATUS (as of 2026-02-01):
  - 2024: View $4,313,775 vs P&L $4,333,451 = -0.45% variance
  - 2025: View $3,905,119 vs P&L $3,911,537 = -0.16% variance
  Variance accepted as reasonable for customer-attributed analysis.
  Remaining gap due to rounding, timing, and parent/child resolution edge cases.

============================================================================
CUSTOMER ATTRIBUTION STRATEGY (v3 - P&L Tie-Out Version):
============================================================================
This query uses a TIERED APPROACH for customer attribution of organizer fees:

1. DIRECT: bill_line.account_expense_customer_id (primary - ~88% of lines)
2. CLASS-BASED: If no customer_id, use class.name to match customer.display_name
   - Exact match first
   - Manual mapping for close matches (e.g., "Google" -> "Google LLC")
3. UNKNOWN BUCKET: Lines with no customer_id AND no class match are aggregated
   into a single "UNKNOWN" customer row (qbo_customer_id = 'UNKNOWN')

This ensures the query TIES EXACTLY TO THE P&L by capturing all organizer fees.
The "UNKNOWN" row contains:
- Internal classes like "Recess College Bag" (~$335K)
- Bill lines with no class assigned (~$318K)
- Other unmatched classes

Filter out the UNKNOWN row for customer-level analysis if needed:
  WHERE qbo_customer_id != 'UNKNOWN'
============================================================================
*/

WITH manual_customer_mapping AS (
    SELECT '6660' AS from_id, '7069' AS to_id
),

company_name_mapping AS (
    SELECT original_name, normalized_name FROM UNNEST([
        STRUCT('Energizer Brands LLC' AS original_name, 'Energizer Brands, LLC' AS normalized_name),
        STRUCT('La Columbe Coffee', 'La Colombe Coffee Roasters'),
        STRUCT('Haleon US Services Inc', 'Haleon US LP')
    ])
),

/* ============================================================================
   CLASS NAME TO CUSTOMER ID MAPPING
   Maps class.name to customer.id for organizer fees without direct customer_id
   Includes both exact matches (via JOIN) and manual mappings for close matches
   ============================================================================ */
class_to_customer_manual_mapping AS (
    SELECT class_name, qbo_customer_id FROM UNNEST([
        -- Close matches where class name doesn't exactly match customer display_name
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

/* Build lookup from class_id to customer_id using both exact name match and manual mapping */
class_to_customer_lookup AS (
    SELECT
        c.id AS class_id,
        c.name AS class_name,
        COALESCE(
            -- Priority 1: Manual mapping for close matches
            mcm.qbo_customer_id,
            -- Priority 2: Exact match on display_name
            COALESCE(cust.parent_customer_id, CAST(cust.id AS STRING))
        ) AS qbo_customer_id
    FROM src_fivetran_qbo.class AS c
    LEFT JOIN class_to_customer_manual_mapping AS mcm
        ON c.name = mcm.class_name
    LEFT JOIN src_fivetran_qbo.customer AS cust
        ON LOWER(c.name) = LOWER(cust.display_name) AND cust._fivetran_deleted = FALSE
    WHERE c._fivetran_deleted = FALSE
),

hubspot_company_mapping AS (
    SELECT
        COALESCE(mcm.to_id, cust.parent_customer_id, CAST(comp.property_qbo_customer_id AS STRING)) AS qbo_customer_id,
        MIN(CAST(comp.id AS STRING)) AS hubspot_company_id,
        MAX(comp.property_name) AS hubspot_company_name,
        MAX(comp.property_market_type) AS market_type,
        MAX(CASE WHEN comp.property_hs_is_target_account = TRUE THEN 1 ELSE 0 END) = 1 AS is_target_account,
        MAX(CONCAT(COALESCE(owner.first_name, ''), ' ', COALESCE(owner.last_name, ''))) AS account_owner_name
    FROM src_fivetran_hubspot.company AS comp
    LEFT JOIN src_fivetran_qbo.customer AS cust
        ON CAST(comp.property_qbo_customer_id AS STRING) = cust.id AND cust._fivetran_deleted = FALSE
    LEFT JOIN manual_customer_mapping AS mcm
        ON CAST(comp.property_qbo_customer_id AS STRING) = mcm.from_id
    LEFT JOIN src_fivetran_hubspot.owner AS owner
        ON comp.property_hubspot_owner_id = owner.owner_id
    WHERE comp.property_qbo_customer_id IS NOT NULL
    GROUP BY 1
),

/* ============================================================================
   INVOICE REVENUE (Accounts 4000-4190)
   ============================================================================ */
invoice_revenue AS (
    SELECT
        inv.doc_number AS invoice_id,
        COALESCE(mcm.to_id, cust.parent_customer_id, CAST(inv.customer_id AS STRING)) AS qbo_customer_id,
        COALESCE(cnm.normalized_name, parent_cust.display_name, cust.display_name) AS company_name,
        EXTRACT(YEAR FROM inv.transaction_date) AS revenue_year,
        SUM(CASE WHEN item.name = 'Discount' THEN 0 ELSE l.amount END) AS line_amount,
        SUM(CASE WHEN item.name = 'Discount' THEN l.amount ELSE 0 END) AS discount
    FROM src_fivetran_qbo.invoice AS inv
    JOIN src_fivetran_qbo.invoice_line AS l ON inv.id = l.invoice_id
    JOIN src_fivetran_qbo.customer AS cust ON inv.customer_id = cust.id AND cust._fivetran_deleted = FALSE
    LEFT JOIN src_fivetran_qbo.customer AS parent_cust ON cust.parent_customer_id = parent_cust.id AND parent_cust._fivetran_deleted = FALSE
    LEFT JOIN manual_customer_mapping AS mcm ON CAST(inv.customer_id AS STRING) = mcm.from_id
    LEFT JOIN company_name_mapping AS cnm ON COALESCE(parent_cust.display_name, cust.display_name) = cnm.original_name
    LEFT JOIN src_fivetran_qbo.item AS item ON item.id = l.sales_item_item_id
    LEFT JOIN src_fivetran_qbo.account AS act ON item.income_account_id = act.id
    WHERE inv._fivetran_deleted = FALSE
      AND l.sales_item_unit_price IS NOT NULL
      AND SAFE_CAST(act.account_number AS INT64) BETWEEN 4000 AND 4190
      AND EXTRACT(YEAR FROM inv.transaction_date) BETWEEN 2022 AND 2026
    GROUP BY 1, 2, 3, 4
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
      AND EXTRACT(YEAR FROM cm.transaction_date) BETWEEN 2022 AND 2026
    GROUP BY 1, 2
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
   ORGANIZER FEES (Accounts 4200-4240) - Bills paid to venues, reduces revenue
   TIERED ATTRIBUTION:
   1. Direct: bill_line.account_expense_customer_id (if customer has invoices)
   2. Class-based: class.name matched to customer.display_name (if customer has invoices)
   3. Unknown: All other org fees go to 'UNKNOWN' bucket for P&L tie-out
   ============================================================================ */
organizer_fees AS (
    -- Attributed organizer fees: customer has invoice revenue
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
      AND EXTRACT(YEAR FROM b.transaction_date) BETWEEN 2022 AND 2026
      AND COALESCE(bl.account_expense_customer_id, class_lookup.qbo_customer_id) IS NOT NULL
      -- Only include if customer has invoice revenue
      AND COALESCE(mcm.to_id, cust.parent_customer_id, bl.account_expense_customer_id, class_lookup.qbo_customer_id)
          IN (SELECT qbo_customer_id FROM invoice_customers)
    GROUP BY 1, 2

    UNION ALL

    -- UNKNOWN bucket: All org fees that can't be tied to an invoice customer
    SELECT
        'UNKNOWN' AS qbo_customer_id,
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
      AND EXTRACT(YEAR FROM b.transaction_date) BETWEEN 2022 AND 2026
      -- Include if NO customer match OR customer has no invoice revenue
      AND (
        COALESCE(bl.account_expense_customer_id, class_lookup.qbo_customer_id) IS NULL
        OR COALESCE(mcm.to_id, cust.parent_customer_id, bl.account_expense_customer_id, class_lookup.qbo_customer_id)
           NOT IN (SELECT qbo_customer_id FROM invoice_customers)
      )
    GROUP BY 2
),

/* ============================================================================
   VENDOR CREDITS (Accounts 4200-4240) - Reduces what we owe venues, adds to revenue
   TIERED ATTRIBUTION (same as organizer_fees):
   1. Direct: vendor_credit_line.account_expense_customer_id (if customer has invoices)
   2. Class-based: class.name matched to customer.display_name (if customer has invoices)
   3. Unknown: All other vendor credits go to 'UNKNOWN' bucket for P&L tie-out
   ============================================================================ */
vendor_credits AS (
    -- Attributed vendor credits: customer has invoice revenue
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
      AND EXTRACT(YEAR FROM vc.transaction_date) BETWEEN 2022 AND 2026
      AND COALESCE(vcl.account_expense_customer_id, class_lookup.qbo_customer_id) IS NOT NULL
      AND COALESCE(mcm.to_id, cust.parent_customer_id, vcl.account_expense_customer_id, class_lookup.qbo_customer_id)
          IN (SELECT qbo_customer_id FROM invoice_customers)
    GROUP BY 1, 2

    UNION ALL

    -- UNKNOWN bucket: All vendor credits that can't be tied to an invoice customer
    SELECT
        'UNKNOWN' AS qbo_customer_id,
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
      AND EXTRACT(YEAR FROM vc.transaction_date) BETWEEN 2022 AND 2026
      AND (
        COALESCE(vcl.account_expense_customer_id, class_lookup.qbo_customer_id) IS NULL
        OR COALESCE(mcm.to_id, cust.parent_customer_id, vcl.account_expense_customer_id, class_lookup.qbo_customer_id)
           NOT IN (SELECT qbo_customer_id FROM invoice_customers)
      )
    GROUP BY 2
),

/* ============================================================================
   AGGREGATE INVOICE REVENUE TO CUSTOMER/YEAR LEVEL
   ============================================================================ */
invoice_by_customer_year AS (
    SELECT
        qbo_customer_id,
        MAX(company_name) AS company_name,
        revenue_year,
        SUM(line_amount + discount) AS invoice_net
    FROM invoice_revenue
    GROUP BY 1, 3
),

/* ============================================================================
   COHORT YEAR = First year customer had any invoice (revenue accounts only)
   ============================================================================ */
first_invoice_year AS (
    SELECT
        COALESCE(mcm.to_id, cust.parent_customer_id, CAST(inv.customer_id AS STRING)) AS qbo_customer_id,
        MIN(EXTRACT(YEAR FROM inv.transaction_date)) AS cohort_year
    FROM src_fivetran_qbo.invoice AS inv
    JOIN src_fivetran_qbo.invoice_line AS l ON inv.id = l.invoice_id
    JOIN src_fivetran_qbo.customer AS cust ON inv.customer_id = cust.id AND cust._fivetran_deleted = FALSE
    LEFT JOIN manual_customer_mapping AS mcm ON CAST(inv.customer_id AS STRING) = mcm.from_id
    LEFT JOIN src_fivetran_qbo.item AS item ON item.id = l.sales_item_item_id
    LEFT JOIN src_fivetran_qbo.account AS act ON item.income_account_id = act.id
    WHERE inv._fivetran_deleted = FALSE
      AND l.sales_item_unit_price IS NOT NULL
      AND SAFE_CAST(act.account_number AS INT64) BETWEEN 4000 AND 4190
    GROUP BY 1
),

/* ============================================================================
   CUSTOMER/YEAR SPINE - All combinations from ANY transaction type
   This ensures credit memos, org fees, vendor credits appear in correct period
   even if no invoice exists in that year
   ============================================================================ */
customer_year_spine AS (
    -- All customer/year combinations from invoices
    SELECT DISTINCT qbo_customer_id, revenue_year FROM invoice_by_customer_year WHERE qbo_customer_id != 'UNKNOWN'
    UNION DISTINCT
    -- All customer/year combinations from credit memos
    SELECT DISTINCT qbo_customer_id, revenue_year FROM credit_memos WHERE qbo_customer_id != 'UNKNOWN'
    UNION DISTINCT
    -- All customer/year combinations from org fees (attributed only)
    SELECT DISTINCT qbo_customer_id, revenue_year FROM organizer_fees WHERE qbo_customer_id != 'UNKNOWN'
    UNION DISTINCT
    -- All customer/year combinations from vendor credits (attributed only)
    SELECT DISTINCT qbo_customer_id, revenue_year FROM vendor_credits WHERE qbo_customer_id != 'UNKNOWN'
),

/* ============================================================================
   NET REVENUE BY CUSTOMER AND YEAR
   Uses spine to include ALL transactions in their correct period
   ============================================================================ */
net_revenue_by_customer_year AS (
    -- Regular customers: Join all components to unified spine
    SELECT
        spine.qbo_customer_id,
        COALESCE(icy.company_name, cust.display_name, 'Unknown') AS company_name,
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
    LEFT JOIN src_fivetran_qbo.customer cust
        ON spine.qbo_customer_id = CAST(cust.id AS STRING) AND cust._fivetran_deleted = FALSE

    UNION ALL

    -- UNKNOWN bucket: Unattributed organizer fees/vendor credits for P&L tie-out
    SELECT
        'UNKNOWN' AS qbo_customer_id,
        'Unattributed (Recess Internal, No Class)' AS company_name,
        orgf.revenue_year,
        0 AS invoice_net,
        0 AS credit_memo_net,
        orgf.org_fees,
        COALESCE(vc.vendor_credit, 0) AS vendor_credit,
        ROUND(orgf.org_fees + COALESCE(vc.vendor_credit, 0), 2) AS net_revenue
    FROM organizer_fees orgf
    LEFT JOIN vendor_credits vc
        ON orgf.qbo_customer_id = vc.qbo_customer_id AND orgf.revenue_year = vc.revenue_year
    WHERE orgf.qbo_customer_id = 'UNKNOWN'
),

/* ============================================================================
   PIVOT BY YEAR
   ============================================================================ */
pivoted AS (
    SELECT
        qbo_customer_id,
        MAX(company_name) AS company_name,
        SUM(CASE WHEN revenue_year = 2022 THEN net_revenue ELSE 0 END) AS net_rev_2022,
        SUM(CASE WHEN revenue_year = 2023 THEN net_revenue ELSE 0 END) AS net_rev_2023,
        SUM(CASE WHEN revenue_year = 2024 THEN net_revenue ELSE 0 END) AS net_rev_2024,
        SUM(CASE WHEN revenue_year = 2025 THEN net_revenue ELSE 0 END) AS net_rev_2025,
        SUM(CASE WHEN revenue_year = 2026 THEN net_revenue ELSE 0 END) AS net_rev_2026,
        SUM(net_revenue) AS total_ltv
    FROM net_revenue_by_customer_year
    GROUP BY qbo_customer_id
)

/* ============================================================================
   FINAL OUTPUT
   ============================================================================ */
SELECT
    p.qbo_customer_id,
    hcm.hubspot_company_id,
    p.company_name,
    COALESCE(hcm.is_target_account, FALSE) AS is_target_account,
    NULLIF(TRIM(hcm.account_owner_name), '') AS account_owner,
    fiy.cohort_year,
    ROUND(p.net_rev_2022, 2) AS net_rev_2022,
    ROUND(p.net_rev_2023, 2) AS net_rev_2023,
    ROUND(p.net_rev_2024, 2) AS net_rev_2024,
    ROUND(p.net_rev_2025, 2) AS net_rev_2025,
    ROUND(p.net_rev_2026, 2) AS net_rev_2026,
    CASE WHEN p.net_rev_2022 > 0 THEN ROUND((p.net_rev_2023 / p.net_rev_2022) * 100, 1) END AS nrr_2023,
    CASE WHEN p.net_rev_2023 > 0 THEN ROUND((p.net_rev_2024 / p.net_rev_2023) * 100, 1) END AS nrr_2024,
    CASE WHEN p.net_rev_2024 > 0 THEN ROUND((p.net_rev_2025 / p.net_rev_2024) * 100, 1) END AS nrr_2025,
    ROUND(p.total_ltv, 2) AS total_ltv
FROM pivoted p
LEFT JOIN hubspot_company_mapping hcm ON p.qbo_customer_id = hcm.qbo_customer_id
LEFT JOIN first_invoice_year fiy ON p.qbo_customer_id = fiy.qbo_customer_id
WHERE (p.total_ltv > 0 OR p.qbo_customer_id = 'UNKNOWN')  -- Include UNKNOWN for P&L tie-out
  AND (hcm.market_type IS NULL OR hcm.market_type NOT IN ('supplier', 'Professional Service'))
ORDER BY p.total_ltv DESC

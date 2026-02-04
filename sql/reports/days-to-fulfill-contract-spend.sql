-- =============================================================================
-- Days to Fulfill Contract Spend (From Close Date)
-- =============================================================================
-- View Name: App_KPI_Dashboard.Days_to_Fulfill_Contract_Spend_From_Close_Date
-- Created: 2026-02-03
-- Author: Deuce + Claude
--
-- Purpose: Measures days from contract close date until 100% of contract value
--          has been invoiced. This is the TRUE "time to fulfill" metric.
--
-- Key difference from old query (Days_to_Fulfill_Contract_Program):
--   OLD: First accepted offer → Last accepted offer (date span only)
--   NEW: Contract close → Invoice date when cumulative spend >= contract amount
--
-- How Gross Spend is Calculated:
--   Gross Spend = GMV Invoice Lines - Credit Memos
--   - GMV items: Event Sponsorship Fee, Sampling, Activation, Sponsorship, etc.
--   - Credit memos reduce spend (negative values)
--
-- Stats (as of 2026-02-03):
--   Median: 69 days | Average: 156 days | Fulfilled: 177 contracts ($23.9M)
--
-- Primary metric: days_close_to_fulfill
-- =============================================================================

CREATE OR REPLACE VIEW `stitchdata-384118.App_KPI_Dashboard.Days_to_Fulfill_Contract_Spend_From_Close_Date` AS

WITH hubspot_deals AS (
    -- Get all closed-won contracts with a contract value
    SELECT
        d.deal_id,
        d.property_dealname AS dealname,
        d.property_closedate AS closedate,
        d.property_amount AS contract_amount,
        d.property_start_of_term AS start_of_term,
        d.property_end_of_term AS end_of_term,
        d.property_org AS org,
        d.owner_id,
        c.property_name AS company_name
    FROM src_fivetran_hubspot.deal d
    LEFT JOIN src_fivetran_hubspot.deal_company dc ON d.deal_id = dc.deal_id AND dc.type_id = 5
    LEFT JOIN src_fivetran_hubspot.company c ON dc.company_id = c.id
    WHERE d.is_deleted IS FALSE
      AND d._fivetran_deleted IS FALSE
      AND d.property_start_of_term IS NOT NULL
      AND d.deal_pipeline_stage_id = 'closedwon'
      AND d.property_amount > 0  -- Only contracts with a value
),

-- Get invoice line amounts for GMV items
invoice_amounts AS (
    SELECT
        inv.custom_contract_id AS contract_id,
        inv.transaction_date AS invoice_date,
        inv.doc_number AS invoice_number,
        SUM(
            CASE
                WHEN item.name IN (
                    'Event Sponsorship Fee:Sampling',
                    'Event Sponsorship Fee',
                    'Event Sponsorship Fee:Sponsorship',
                    'Event Sponsorship Fee:Activation',
                    'Activation Services Fee',
                    'Sponsorship',
                    'Activation',
                    'Reimbursable Expenses',
                    'Platform Monthly Subscription',
                    'Event Sponsorship Fee:Sampling* (deleted)',
                    'Sampling*',
                    'Sampling'
                ) THEN il.amount
                ELSE 0
            END
        ) AS invoice_gross_amount
    FROM src_fivetran_qbo.invoice inv
    LEFT JOIN src_fivetran_qbo.invoice_line il ON il.invoice_id = inv.id
    LEFT JOIN src_fivetran_qbo.item item ON item.id = il.sales_item_item_id
    WHERE inv._fivetran_deleted IS FALSE
      AND inv.custom_contract_id IS NOT NULL
    GROUP BY 1, 2, 3
    HAVING invoice_gross_amount > 0
),

-- Get credit memos per contract (reduces spend)
credit_memo_amounts AS (
    SELECT
        CASE
            WHEN inv.purchase_order_number IS NULL THEN REGEXP_REPLACE(cm.doc_number, '_.*', '')
            ELSE cm.custom_sales_rep
        END AS contract_id,
        cm.transaction_date AS credit_date,
        SUM(cm.total_amount) AS credit_amount  -- Positive value, will be subtracted
    FROM src_fivetran_qbo.credit_memo AS cm
    LEFT JOIN mongodb.invoices AS inv ON inv.purchase_order_number = cm.custom_sales_rep
    WHERE cm._fivetran_deleted IS FALSE
    GROUP BY 1, 2
),

-- Combine invoices and credit memos into spend events
spend_events AS (
    SELECT
        contract_id,
        invoice_date AS event_date,
        invoice_gross_amount AS amount
    FROM invoice_amounts

    UNION ALL

    SELECT
        contract_id,
        credit_date AS event_date,
        -credit_amount AS amount  -- Negative because credits reduce spend
    FROM credit_memo_amounts
    WHERE contract_id IS NOT NULL
),

-- Calculate running cumulative spend per contract, ordered by date
cumulative_spend AS (
    SELECT
        contract_id,
        event_date,
        amount,
        SUM(amount) OVER (
            PARTITION BY contract_id
            ORDER BY event_date ASC
            ROWS UNBOUNDED PRECEDING
        ) AS cumulative_amount
    FROM spend_events
),

-- Find the FIRST date where cumulative spend >= contract amount (100% fulfilled)
fulfillment_date AS (
    SELECT
        cs.contract_id,
        MIN(cs.event_date) AS date_100_pct_spent,
        MIN(cs.cumulative_amount) AS amount_at_fulfillment
    FROM cumulative_spend cs
    JOIN hubspot_deals hd ON CAST(hd.deal_id AS STRING) = cs.contract_id
    WHERE cs.cumulative_amount >= hd.contract_amount
    GROUP BY cs.contract_id
),

-- Get total spend (even if not 100% fulfilled)
total_spend AS (
    SELECT
        contract_id,
        SUM(amount) AS total_invoiced,
        MAX(event_date) AS last_event_date
    FROM spend_events
    GROUP BY contract_id
)

-- Final output
SELECT
    hd.deal_id,
    hd.dealname,
    hd.company_name,
    hd.contract_amount,

    -- Dates
    DATE(hd.closedate) AS contract_close_date,
    DATE(hd.start_of_term) AS contract_start_date,
    DATE(hd.end_of_term) AS contract_end_date,
    fd.date_100_pct_spent,
    ts.last_event_date AS last_spend_date,

    -- Spend tracking
    ts.total_invoiced AS total_spend,  -- Net of credit memos
    SAFE_DIVIDE(ts.total_invoiced, hd.contract_amount) AS spend_pct,

    -- Days to fulfill (from CLOSE DATE) - PRIMARY METRIC
    DATE_DIFF(fd.date_100_pct_spent, DATE(hd.closedate), DAY) AS days_close_to_fulfill,

    -- Days to fulfill (from START OF TERM) - alternative measure
    DATE_DIFF(fd.date_100_pct_spent, DATE(hd.start_of_term), DAY) AS days_start_to_fulfill,

    -- Status
    CASE
        WHEN fd.date_100_pct_spent IS NOT NULL THEN 'Fulfilled'
        WHEN ts.total_invoiced IS NULL THEN 'No Invoices'
        ELSE 'In Progress'
    END AS fulfillment_status,

    -- Owner info for filtering
    hd.owner_id,
    hd.org

FROM hubspot_deals hd
LEFT JOIN fulfillment_date fd ON CAST(hd.deal_id AS STRING) = fd.contract_id
LEFT JOIN total_spend ts ON CAST(hd.deal_id AS STRING) = ts.contract_id;


-- =============================================================================
-- HELPER QUERY: Get aggregate statistics
-- =============================================================================
-- Run this after creating the view to verify stats:
/*
SELECT
    COUNT(CASE WHEN fulfillment_status = 'Fulfilled' THEN 1 END) AS fulfilled_count,
    COUNT(CASE WHEN fulfillment_status = 'In Progress' THEN 1 END) AS in_progress_count,
    COUNT(CASE WHEN fulfillment_status = 'No Invoices' THEN 1 END) AS no_invoices_count,

    APPROX_QUANTILES(
        CASE WHEN fulfillment_status = 'Fulfilled' THEN days_close_to_fulfill END,
        100
    )[OFFSET(50)] AS median_days,

    ROUND(AVG(
        CASE WHEN fulfillment_status = 'Fulfilled' THEN days_close_to_fulfill END
    ), 1) AS avg_days,

    ROUND(SUM(
        CASE WHEN fulfillment_status = 'Fulfilled' THEN contract_amount END
    ), 0) AS fulfilled_value,

    ROUND(SUM(
        CASE WHEN fulfillment_status = 'In Progress' THEN contract_amount END
    ), 0) AS in_progress_value

FROM `stitchdata-384118.App_KPI_Dashboard.Days_to_Fulfill_Contract_Spend_From_Close_Date`
*/

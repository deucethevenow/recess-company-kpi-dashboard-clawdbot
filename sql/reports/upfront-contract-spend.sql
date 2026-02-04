-- BigQuery View: App_KPI_Dashboard.Upfront_Contract_Spend_Query
-- Purpose: Track contract health by comparing actual spend vs. contracted amount
-- Key Metrics: Gross Spent, Remaining Gross, Target %, Actual Spend %, Health Status
-- Joins: HubSpot deals → QBO invoices → credit memos → deferred revenue

WITH hubspot_users AS (
  SELECT
    owner_id,
    active_user_id,
    email,
    CONCAT(first_name, ' ', last_name) as name,
    created_at,
    updated_at
  FROM src_fivetran_hubspot.owner
  WHERE is_active IS TRUE
),

gross_amount AS (
    SELECT
        invoice_id,
        SUM(
            CASE
                WHEN item.name IN ('Discount') THEN amount
                ELSE 0
            END
        ) AS discount,
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
                ) THEN amount
                ELSE 0
            END
        ) AS line_value_amount
    FROM src_fivetran_qbo.invoice_line AS il
    LEFT JOIN src_fivetran_qbo.item AS item ON item.id = il.sales_item_item_id
    GROUP BY 1
),

credit_memos AS (
    SELECT
        CASE
            WHEN inv.purchase_order_number IS NULL THEN REGEXP_REPLACE(cm.doc_number, '_.*', '')
            ELSE cm.custom_sales_rep
        END AS invoice_number,
        SUM(total_amount) AS credit_amount
    FROM src_fivetran_qbo.credit_memo AS cm
    LEFT JOIN mongodb.invoices AS inv ON inv.purchase_order_number = cm.custom_sales_rep
    GROUP BY 1
),

deferred_revenue AS (
    SELECT
        `doc_number`,
        SUM(DeferredRevenueAmount) AS deferred_revenue_amount
    FROM (
        SELECT
            inv.`doc_number`,
            inv_li.amount AS DeferredRevenueAmount
        FROM src_fivetran_qbo.invoice AS inv
        LEFT JOIN src_fivetran_qbo.invoice_line AS inv_li ON inv_li.invoice_id = inv.id
        LEFT JOIN src_fivetran_qbo.account AS act ON act.id = inv_li.sales_item_account_id
        WHERE
            inv._fivetran_deleted = FALSE
            AND act._fivetran_deleted = FALSE
            AND LOWER(act.name) LIKE '%deferred%'

        UNION ALL

        SELECT
            REGEXP_REPLACE(cm.doc_number, r'(_[cC].*)', '') AS `doc_number`,
            -cm_li.amount AS deferred_revenue_amount
        FROM src_fivetran_qbo.credit_memo AS cm
        LEFT JOIN src_fivetran_qbo.credit_memo_line AS cm_li ON cm_li.credit_memo_id = cm.id
        LEFT JOIN src_fivetran_qbo.account AS act ON act.id = cm_li.sales_item_account_id
        WHERE
            cm._fivetran_deleted = FALSE
            AND act._fivetran_deleted = FALSE
            AND LOWER(act.name) LIKE '%deferred%'
    )
    GROUP BY 1
),

qbo_invoices AS (
    SELECT
        inv.custom_contract_id AS contract_id,
        cust.display_name AS company,
        inv.doc_number AS invoice_id,
        inv.transaction_date AS invoice_date,
        inv.total_amount AS invoice_amount,
        ga.line_value_amount,
        ga.discount,
        inv.id,
        - cm.credit_amount AS credit_amount,
        COALESCE(inv.total_amount, 0) - COALESCE(cm.credit_amount, 0) AS Net_Amount,
        dr.deferred_revenue_amount,
        CASE
            WHEN dr.deferred_revenue_amount > 0 THEN dr.deferred_revenue_amount
            ELSE 0
        END AS deferred_revenue_additions,
        CASE
            WHEN dr.deferred_revenue_amount < 0 THEN dr.deferred_revenue_amount
            ELSE 0
        END AS deferred_revenue_reductions,
        SUM(dr.deferred_revenue_amount) OVER (
            PARTITION BY cust.display_name
            ORDER BY inv.transaction_date ASC, inv.doc_number ASC
        ) AS deferred_balance
    FROM src_fivetran_qbo.invoice AS inv
    LEFT JOIN src_fivetran_qbo.customer AS cust ON cust.id = inv.customer_id
    LEFT JOIN gross_amount AS ga ON ga.invoice_id = inv.id
    LEFT JOIN credit_memos AS cm ON cm.Invoice_Number = inv.doc_number
    LEFT JOIN deferred_revenue AS dr ON dr.`doc_number` = inv.doc_number
),

manual_deffered_revenue_adjustments AS (
  SELECT '8627850578' AS contract_id,    59999.99 AS manual_differed_revenue_addition, 0 AS manual_differed_revenue_reductions
  UNION ALL
  SELECT '14454487846', 300, 0
),

qbo_invoices_grouped AS (
    SELECT
        contract_id,
        SUM(line_value_amount) AS gross_spend,
        SUM(discount) AS gross_discount,
        SUM(Credit_Amount) AS credit_amount,
        SUM(IFNULL(line_value_amount,0)) + SUM(IFNULL(discount,0)) + SUM(IFNULL(Credit_Amount,0)) AS total_spend,
        SUM(Net_Amount) AS net_amount,
            SUM(IFNULL(deferred_revenue_additions,0))
          + SUM(IFNULL(deferred_revenue_reductions,0))
        AS deferred_balance
    FROM qbo_invoices
    GROUP BY contract_id
),

qbo_customers AS (
  SELECT c.id, c.fully_qualified_name
  FROM src_fivetran_qbo.customer c
),

hubspot_deals AS (
    SELECT
        d.deal_id,
        d.property_closedate AS closedate,
        d.property_contact_email AS contact_email,
        d.property_canceled_contract_ AS canceled_contract,
        d.property_dealname AS dealname,
        d.property_start_of_term AS start_of_term,
        d.property_end_of_term AS end_of_term,
        IFNULL(SAFE_CAST(d.property_grace_period AS INT64),0) AS grace_period_days,
        d.property_discount_ AS discount,
        d.property_amount AS amount,
        d.property_purchase_order_number_for_contract_id AS po_for_contract_id,
        d.property_brand_s_purchase_order_platform AS brands_purchase_order_platform,
        d.property_dealtype AS dealtype,
        d.property_payment_terms AS payment_terms,
        d.property_deal_status AS deal_status,
        d.owner_id AS owner_id,
        d.property_org AS org,
        d.property_acct_management_lead AS acct_management_lead,
        d.property_acct_coordinator_lead AS acct_coordinator_lead,
        d.property_agreed_to_auto_renewal AS agreed_to_auto_renewal,
        d.property_sponsor_agreement_type AS sponsor_agreement_type,
        d.property_brand_logo_usage AS brand_logo_useage,
        d.property_who_is_the_brands_ap_contact_email_to_send_invoices_to_ AS contact_email_to_send_invoices_to,
        d.property_custom_invoicing_instructions AS custom_invoicing_instructions,
        d.property_does_the_brand_require_po_s_ AS does_the_brand_require_po,
        d.property_special_logo_ip_use_language AS special_logo_ip_use_language,
        d.property_contract_special_terms_required_for_offers AS contract_special_terms_required_for_offers,
        d.property_deal_notes AS notes,
        d.property_contract_cancelation_reason AS contract_cancelation_reason,
        d.property_how_are_purchase_order_s_issued_for_invoices_ AS how_are_purchase_order_s_issued_for_invoices,
        d.property_purchase_order_number_for_contract_id AS purchase_order_number_for_contract_id,
        IF(CURRENT_TIMESTAMP() > d.property_end_of_term, 1,
            DATETIME_DIFF(DATETIME(d.property_end_of_term), CURRENT_DATETIME(), DAY) /
            (DATETIME_DIFF(DATETIME(d.property_end_of_term), DATETIME(d.property_start_of_term), DAY)+1)
        ) AS target,
        dp.pipeline_id,
        dp.label AS pipeline,
        inv_g.gross_spend,
        inv_g.gross_discount,
        inv_g.credit_amount,
        inv_g.total_spend,
        IF(inv_g.credit_amount < 0,
            d.property_amount - (inv_g.credit_amount + inv_g.gross_spend),
            d.property_amount - IFNULL(inv_g.gross_spend,0)
        ) AS remaining_gross,
        inv_g.net_amount AS total_net_spend,
        (
          inv_g.deferred_balance +
          IFNULL(manual_differed_revenue_addition, 0) +
          IFNULL(manual_differed_revenue_reductions, 0)
        ) AS deferred_balance,
        1 - SAFE_DIVIDE(
                IF(inv_g.credit_amount < 0,
                    d.property_amount - (inv_g.credit_amount + inv_g.gross_discount),
                    d.property_amount - inv_g.gross_spend
                ), d.property_amount) AS actual_spend_pct,
        c.id AS company_id,
        c.property_name AS company_name
    FROM src_fivetran_hubspot.deal d
    LEFT JOIN src_fivetran_hubspot.deal_company dc ON d.deal_id = dc.deal_id AND dc.type_id = 5
    LEFT JOIN src_fivetran_hubspot.company c ON dc.company_id = c.id
    LEFT JOIN src_fivetran_hubspot.deal_pipeline dp ON d.deal_pipeline_id = dp.pipeline_id
    LEFT JOIN qbo_invoices_grouped inv_g ON CAST(d.deal_id AS STRING) = inv_g.contract_id
    LEFT JOIN manual_deffered_revenue_adjustments USING (contract_id)
    WHERE d.is_deleted IS FALSE AND d._fivetran_deleted IS FALSE
    AND d.property_start_of_term IS NOT NULL
    AND d.deal_pipeline_stage_id =  'closedwon'
)

SELECT
  d.company_name AS `Company Name`,
  owner.name AS `Owner Name`,
  mgmt_lead.name AS `AM Name`,
  coord_lead.name AS `AC Name`,
  d.gross_spend AS `Gross Spent`,
  d.gross_discount AS `Gross Discount`,
  d.credit_amount AS `Credit Memo`,
  d.total_spend AS `Total Spent`,
  d.remaining_gross AS `Remaining Gross`,
  d.total_net_spend AS `Total Net Spent`,
  d.target AS `Target %`,
  d.actual_spend_pct AS `Actual Spend %`,
  IF(d.grace_period_days IN (0, NULL), d.end_of_term, DATETIME_ADD(d.end_of_term, INTERVAL d.grace_period_days DAY)) AS `Grace Period`,
  IF(d.actual_spend_pct >= 1, 'On Track',
    IF(d.target = 0, 'On Track',
       IF((d.actual_spend_pct - d.target) < 0, 'Off Track',
            IF((d.actual_spend_pct - d.target) < 0.16, 'At Risk',
                IF((d.actual_spend_pct - d.target) >=0, 'On Track', ''))))) AS `Health`,
   d.deferred_balance AS `Deferred Revenue Balance`,
   d.notes AS `Notes`,
   NULL AS _blank_col,
   CURRENT_TIMESTAMP() AS `Row Updated At`,
   d.deal_id AS `id`,
   d.pipeline_id AS `pipeline`,
   d.pipeline AS `pipeline_name`,
   d.company_id AS `associations_companies`,
   d.dealtype AS `dealtype`,
   d.closedate `closedate`,
   d.amount AS `amount`,
   d.dealname AS `dealname`,
   d.deal_status AS `deal_status`,
   d.owner_id AS `hubspot_owner_id`,
   d.acct_coordinator_lead AS `acct_management_lead`,
   d.acct_management_lead AS `acct_coordinator_lead`,
   d.start_of_term AS `start_of_term`,
   d.end_of_term AS `end_of_term`,
   d.discount AS `discount__`,
   d.org AS `org`,
   d.grace_period_days AS `grace_period`,
   d.agreed_to_auto_renewal AS `agreed_to_auto_renewal`,
   d.canceled_contract AS `canceled_contract_`,
   d.contract_cancelation_reason AS `contract_cancelation_reason`,
   d.sponsor_agreement_type AS `sponsor_agreement_type`,
   d.brand_logo_useage AS `brand_logo_usage`,
   d.special_logo_ip_use_language AS `special_logo_ip_use_language`,
   d.contract_special_terms_required_for_offers AS `contract___special_terms_required_for_offers`,
   d.payment_terms AS `payment_terms`,
   d.does_the_brand_require_po AS `does_the_brand_require_po__s_`,
   d.how_are_purchase_order_s_issued_for_invoices AS `how_are_purchase_order_s_issued_for_invoices_`,
   d.purchase_order_number_for_contract_id AS `purchase_order_number_for_contract_id`,
   d.contact_email_to_send_invoices_to AS `who_is_the_brands_ap_contact_email_to_send_invoices_to_`,
   d.brands_purchase_order_platform AS `brand_s_purchase_order_platform`,
   d.contact_email AS `contact_email`,
   d.custom_invoicing_instructions AS `custom_invoicing_instructions`,
   d.contact_email AS `contact_email1`
FROM hubspot_deals d
LEFT JOIN hubspot_users AS owner ON d.owner_id = owner.owner_id
LEFT JOIN hubspot_users AS coord_lead ON d.acct_coordinator_lead = coord_lead.owner_id
LEFT JOIN hubspot_users AS mgmt_lead ON d.acct_management_lead = mgmt_lead.owner_id
LEFT JOIN qbo_customers c ON d.company_name = c.fully_qualified_name

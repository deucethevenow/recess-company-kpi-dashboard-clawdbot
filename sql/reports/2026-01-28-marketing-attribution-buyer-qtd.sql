-- ============================================================================
-- VIEW: marketing_attribution_buyer_qtd
-- ============================================================================
-- Marketing Attribution - Quarter to Date (Buyer Market Type)
-- Formula: (First Touch + Last Touch) / 2
-- Fiscal Quarters: Jan-Mar (Q1), Apr-Jun (Q2), Jul-Sep (Q3), Oct-Dec (Q4)
--
-- Created: 2026-01-28
-- Updated: 2026-01-28 - Simplified filter (removed Retailer Partnership field check)
-- Dataset: stitchdata-384118.App_KPI_Dashboard
-- Source: src_fivetran_hubspot.deal
--
-- Marketing Lead Sources (10):
--   Direct Traffic, Paid Search, Paid Social, Organic Social, Organic Search,
--   Event, Email Marketing, Other Campaigns, Referrals, General Referral
--
-- NOT Marketing (0% attribution):
--   Retailer Partnerships, Sales Touch - SDR, Sales Touch - AE, Channel Sales,
--   Partner Buy, Offline Source
--
-- Filters:
--   - Pipeline: default (Buyer)
--   - Market Type: Buyer
--   - Excludes: Deal Type IN (existingbusiness, Renewal 2, Renewal 3, Renewal 4)
-- ============================================================================

CREATE OR REPLACE VIEW `stitchdata-384118.App_KPI_Dashboard.marketing_attribution_buyer_qtd` AS

WITH marketing_sources AS (
  SELECT source FROM UNNEST([
    'Direct Traffic', 'Paid Search', 'Paid Social', 'Organic Social',
    'Organic Search', 'Event', 'Email Marketing', 'Other Campaigns',
    'Referrals', 'General Referral'
  ]) AS source
),

current_quarter AS (
  SELECT
    DATE_TRUNC(CURRENT_DATE(), QUARTER) AS quarter_start,
    CURRENT_DATE() AS today,
    CONCAT('Q', CAST(EXTRACT(QUARTER FROM CURRENT_DATE()) AS STRING), ' ', CAST(EXTRACT(YEAR FROM CURRENT_DATE()) AS STRING)) AS quarter_label
),

base_deals AS (
  SELECT *
  FROM `src_fivetran_hubspot.deal`
  WHERE deal_pipeline_id = 'default'
    AND LOWER(property_market_type) = 'buyer'
    AND COALESCE(property_dealtype, '') NOT IN ('existingbusiness', 'Renewal 2', 'Renewal 3', 'Renewal 4')
    AND property_amount IS NOT NULL
    AND DATE(property_createdate) >= (SELECT quarter_start FROM current_quarter)
    AND DATE(property_createdate) <= CURRENT_DATE()
)

SELECT
  (SELECT quarter_label FROM current_quarter) AS fiscal_quarter,
  (SELECT quarter_start FROM current_quarter) AS period_start,
  (SELECT today FROM current_quarter) AS period_end,
  metric_type,
  ROUND(SUM(marketing_attributed_amount), 2) AS marketing_attributed_amount,
  COUNT(*) AS deal_count,
  ROUND(SUM(property_amount), 2) AS total_amount,
  ROUND(SUM(marketing_attributed_amount) / NULLIF(SUM(property_amount), 0) * 100, 1) AS marketing_pct
FROM (
  SELECT
    CASE
      WHEN property_hs_is_closed_won = true THEN 'Closed Won'
      WHEN deal_pipeline_stage_id NOT IN ('closedwon', 'closedlost') THEN 'Pipeline'
    END AS metric_type,
    property_amount,
    -- (FT + LT) / 2 attribution formula
    property_amount * (
      (CASE WHEN property_lead_source IN (SELECT source FROM marketing_sources) THEN 0.5 ELSE 0 END) +
      (CASE WHEN property_lt_lead_source IN (SELECT source FROM marketing_sources) THEN 0.5 ELSE 0 END)
    ) AS marketing_attributed_amount
  FROM base_deals
)
WHERE metric_type IS NOT NULL
GROUP BY metric_type;


-- ============================================================================
-- USAGE: After creating the view, query it with:
-- ============================================================================
-- SELECT * FROM `stitchdata-384118.App_KPI_Dashboard.marketing_attribution_buyer_qtd`;
-- ============================================================================

-- =============================================================================
-- Manual Events & Imports Pipeline - Supply Deals Query
-- =============================================================================
-- Description: Returns all deals from the "Manual Events & Imports" pipeline
--              filtered for supplier market type, with primary company info
--              and target account fields.
--
-- Pipeline ID: 16052690
-- Market Type: supplier
--
-- Key Fields:
--   - Deal ID, Company ID, Company Name, Deal Name, Deal Type
--   - Close Date, Stage, Deal Amount, Deal Owner, HS Weighted Amount
--   - Organization Type (Supply), Target Account fields
--
-- Notes:
--   - Uses type_id = 5 for PRIMARY company association (not secondary 341)
--   - Weighted Amount = Deal Amount × Stage Probability
--   - Target account fields come from company properties
--
-- Created: 2026-02-01
-- =============================================================================

WITH primary_companies AS (
  SELECT
    dc.deal_id,
    dc.company_id,
    c.property_name AS company_name,
    c.property_hs_is_target_account AS is_target_account,
    c.property_target_account_supply AS target_account_supply,
    c.property_target_account_rank AS target_account_rank
  FROM `stitchdata-384118.src_fivetran_hubspot.deal_company` dc
  LEFT JOIN `stitchdata-384118.src_fivetran_hubspot.company` c
    ON dc.company_id = c.id
  WHERE dc.type_id = 5  -- Primary company association only
)

SELECT
  d.deal_id AS Deal_ID,
  pc.company_id AS Company_ID,
  pc.company_name AS Company_Name,
  d.property_dealname AS Deal_Name,
  d.property_dealtype AS Deal_Type,
  DATE(d.property_closedate) AS Close_Date,
  dps.label AS Stage,
  d.property_amount AS Deal_Amount,
  COALESCE(d.property_owner_name, CONCAT(o.first_name, ' ', o.last_name)) AS Deal_Owner,
  ROUND(d.property_amount * COALESCE(dps.probability, 0), 2) AS HS_Weighted_Amount,
  d.property_organization_type_supply_ AS Organization_Type_Supply,
  pc.is_target_account AS Is_Target_Account,
  pc.target_account_supply AS Target_Account_Supply,
  pc.target_account_rank AS Target_Account_Rank

FROM `stitchdata-384118.src_fivetran_hubspot.deal` d

-- Join to get stage name and probability
LEFT JOIN `stitchdata-384118.src_fivetran_hubspot.deal_pipeline_stage` dps
  ON d.deal_pipeline_stage_id = dps.stage_id

-- Join to get PRIMARY associated company (type_id = 5)
LEFT JOIN primary_companies pc
  ON d.deal_id = pc.deal_id

-- Join to get owner name (fallback if property_owner_name is null)
LEFT JOIN `stitchdata-384118.src_fivetran_hubspot.owner` o
  ON d.owner_id = o.owner_id

WHERE d.deal_pipeline_id = '16052690'  -- Manual Events & Imports pipeline
  AND d.property_market_type = 'supplier'

ORDER BY d.property_closedate DESC

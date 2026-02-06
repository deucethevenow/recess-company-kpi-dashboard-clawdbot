-- Offer Acceptance Rate by Account Manager
-- Owner: Francisco (PRIMARY), All Demand AMs
-- Purpose: Track platform-market fit signal via supplier acceptance of offers
-- Note: Target is configured in dashboard/data/targets.json, not hardcoded here
--
-- Formula: Accepted / (Accepted + Denied + Ignored) * 100
-- Note: Excludes 'submitted' (pending), 'voided', 'canceled', 'draft' states
--
-- Join Path: offers → campaigns → deals → owner (Account Manager)

WITH offer_outcomes AS (
  -- Join offers through to HubSpot deal owner (Account Manager)
  SELECT
    o.owner_id,
    o.email as account_manager_email,
    o.first_name as am_first_name,
    o.last_name as am_last_name,
    off.aasm_state,
    off.created_at,
    EXTRACT(YEAR FROM off.created_at) as offer_year,
    EXTRACT(MONTH FROM off.created_at) as offer_month
  FROM `stitchdata-384118.mongodb.offers` off
  JOIN `stitchdata-384118.mongodb.campaigns` c
    ON off.campaign_id = c._id
  JOIN `stitchdata-384118.src_fivetran_hubspot.deal` d
    ON c.deal_id = CAST(d.deal_id AS STRING)
  JOIN `stitchdata-384118.src_fivetran_hubspot.owner` o
    ON d.owner_id = o.owner_id
  WHERE off.aasm_state IN ('accepted', 'denied', 'ignored')  -- Final states only
),

-- Acceptance rate by Account Manager (YTD)
am_ytd AS (
  SELECT
    account_manager_email,
    am_first_name,
    am_last_name,
    COUNT(CASE WHEN aasm_state = 'accepted' THEN 1 END) as accepted,
    COUNT(CASE WHEN aasm_state = 'denied' THEN 1 END) as denied,
    COUNT(CASE WHEN aasm_state = 'ignored' THEN 1 END) as ignored,
    COUNT(*) as total_decided,
    ROUND(
      COUNT(CASE WHEN aasm_state = 'accepted' THEN 1 END) * 100.0 /
      NULLIF(COUNT(*), 0)
    , 1) as acceptance_rate_pct
  FROM offer_outcomes
  WHERE offer_year = EXTRACT(YEAR FROM CURRENT_DATE())
  GROUP BY account_manager_email, am_first_name, am_last_name
),

-- Acceptance rate by Account Manager (Rolling 90 days)
am_90d AS (
  SELECT
    account_manager_email,
    am_first_name,
    COUNT(CASE WHEN aasm_state = 'accepted' THEN 1 END) as accepted_90d,
    COUNT(*) as total_90d,
    ROUND(
      COUNT(CASE WHEN aasm_state = 'accepted' THEN 1 END) * 100.0 /
      NULLIF(COUNT(*), 0)
    , 1) as acceptance_rate_90d
  FROM offer_outcomes
  WHERE created_at >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
  GROUP BY account_manager_email, am_first_name
)

-- Main output: Acceptance rate by Account Manager
SELECT
  ytd.am_first_name || ' ' || ytd.am_last_name as account_manager,
  ytd.account_manager_email,

  -- YTD metrics
  ytd.accepted as accepted_ytd,
  ytd.denied as denied_ytd,
  ytd.ignored as ignored_ytd,
  ytd.total_decided as total_ytd,
  ytd.acceptance_rate_pct as acceptance_rate_ytd,

  -- 90-day metrics
  r90.accepted_90d,
  r90.total_90d,
  r90.acceptance_rate_90d

FROM am_ytd ytd
LEFT JOIN am_90d r90
  ON ytd.account_manager_email = r90.account_manager_email
WHERE ytd.account_manager_email LIKE '%@recess.is'
ORDER BY ytd.total_decided DESC;


-- ============================================================
-- COMPANY-WIDE AGGREGATE (for Company Health dashboard)
-- ============================================================
/*
SELECT
  'Company-Wide' as segment,
  COUNT(CASE WHEN aasm_state = 'accepted' THEN 1 END) as accepted,
  COUNT(CASE WHEN aasm_state = 'denied' THEN 1 END) as denied,
  COUNT(CASE WHEN aasm_state = 'ignored' THEN 1 END) as ignored,
  COUNT(*) as total_decided,
  ROUND(
    COUNT(CASE WHEN aasm_state = 'accepted' THEN 1 END) * 100.0 /
    NULLIF(COUNT(*), 0)
  , 1) as acceptance_rate_pct
FROM offer_outcomes
WHERE offer_year = EXTRACT(YEAR FROM CURRENT_DATE());
*/


-- ============================================================
-- MONTHLY TREND (for trend analysis)
-- ============================================================
/*
SELECT
  offer_year,
  offer_month,
  COUNT(CASE WHEN aasm_state = 'accepted' THEN 1 END) as accepted,
  COUNT(*) as total_decided,
  ROUND(
    COUNT(CASE WHEN aasm_state = 'accepted' THEN 1 END) * 100.0 /
    NULLIF(COUNT(*), 0)
  , 1) as acceptance_rate_pct
FROM offer_outcomes
WHERE offer_year >= 2024
GROUP BY offer_year, offer_month
ORDER BY offer_year, offer_month;
*/

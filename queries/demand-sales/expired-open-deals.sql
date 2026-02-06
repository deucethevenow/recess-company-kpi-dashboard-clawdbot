-- =============================================================================
-- EXPIRED OPEN DEALS
-- =============================================================================
-- Purpose: Identify deals with close dates that have passed but are still open
-- Owner: Demand Sales Team
-- Target: 0 (all deals should have accurate close dates)
-- Refresh: Daily
-- =============================================================================

WITH deal_owners AS (
    SELECT
        owner_id,
        CONCAT(first_name, ' ', last_name) AS owner_name,
        email
    FROM `stitchdata-384118.src_fivetran_hubspot.owner`
),

stage_names AS (
    SELECT stage_id, label AS stage_name
    FROM `stitchdata-384118.src_fivetran_hubspot.deal_pipeline_stage`
    WHERE pipeline_id = 'default'
)

SELECT
    do.owner_name,
    d.property_dealname AS deal_name,
    d.property_amount AS amount,
    d.property_closedate AS original_close_date,
    DATE_DIFF(CURRENT_DATE(), d.property_closedate, DAY) AS days_overdue,
    sn.stage_name,
    d.property_createdate AS create_date,
    DATE_DIFF(CURRENT_DATE(), DATE(d.property_createdate), DAY) AS deal_age_days,

    -- Urgency indicator
    CASE
        WHEN DATE_DIFF(CURRENT_DATE(), d.property_closedate, DAY) > 30 THEN 'CRITICAL'
        WHEN DATE_DIFF(CURRENT_DATE(), d.property_closedate, DAY) > 14 THEN 'HIGH'
        WHEN DATE_DIFF(CURRENT_DATE(), d.property_closedate, DAY) > 7 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS urgency

FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
JOIN deal_owners do ON d.owner_id = do.owner_id
JOIN stage_names sn ON d.property_dealstage = sn.stage_id
WHERE d.property_hs_is_closed = FALSE
  AND d.deal_pipeline_id = 'default'
  AND d.property_closedate < CURRENT_DATE()
  AND d.property_amount > 0
ORDER BY days_overdue DESC, d.property_amount DESC;


-- =============================================================================
-- SUMMARY: Expired deals by owner
-- =============================================================================
/*
SELECT
    do.owner_name,
    COUNT(d.deal_id) AS expired_deal_count,
    SUM(d.property_amount) AS total_expired_amount,
    AVG(DATE_DIFF(CURRENT_DATE(), d.property_closedate, DAY)) AS avg_days_overdue,
    CASE
        WHEN COUNT(d.deal_id) = 0 THEN 'GREEN'
        WHEN COUNT(d.deal_id) <= 5 THEN 'YELLOW'
        ELSE 'RED'
    END AS status
FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
JOIN deal_owners do ON d.owner_id = do.owner_id
WHERE d.property_hs_is_closed = FALSE
  AND d.deal_pipeline_id = 'default'
  AND d.property_closedate < CURRENT_DATE()
GROUP BY do.owner_name
ORDER BY expired_deal_count DESC;
*/

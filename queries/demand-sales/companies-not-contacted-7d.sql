-- =============================================================================
-- COMPANIES / DEALS > 7 DAYS NOT CONTACTED
-- =============================================================================
-- Purpose: Identify deals where no activity has been logged in 7+ days
-- Owner: Demand Sales Team
-- Target: 0 (all active deals should have recent activity)
-- Refresh: Daily
--
-- HubSpot Dashboard Reference:
--   - https://app.hubspot.com/reports-dashboard/6699636/view/16787401
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
),

-- Get last activity date for each deal
deal_last_activity AS (
    SELECT
        d.deal_id,
        d.property_dealname AS deal_name,
        d.property_amount AS amount,
        d.property_closedate AS close_date,
        d.property_dealstage AS stage_id,
        d.owner_id,
        -- HubSpot tracks last activity in various ways
        GREATEST(
            COALESCE(d.property_notes_last_updated, DATE('1900-01-01')),
            COALESCE(d.property_hs_last_sales_activity_timestamp, DATE('1900-01-01')),
            COALESCE(DATE(d.property_hs_lastmodifieddate), DATE('1900-01-01'))
        ) AS last_activity_date
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.property_hs_is_closed = FALSE
      AND d.deal_pipeline_id = 'default'
      AND d.property_amount > 0
)

SELECT
    do.owner_name,
    dla.deal_name,
    dla.amount,
    dla.close_date,
    sn.stage_name,
    dla.last_activity_date,
    DATE_DIFF(CURRENT_DATE(), dla.last_activity_date, DAY) AS days_since_activity,

    -- Filter: only deals closing within 30 days
    DATE_DIFF(dla.close_date, CURRENT_DATE(), DAY) AS days_to_close,

    -- Urgency
    CASE
        WHEN DATE_DIFF(CURRENT_DATE(), dla.last_activity_date, DAY) > 14 THEN 'CRITICAL'
        WHEN DATE_DIFF(CURRENT_DATE(), dla.last_activity_date, DAY) > 10 THEN 'HIGH'
        ELSE 'MEDIUM'
    END AS urgency

FROM deal_last_activity dla
JOIN deal_owners do ON dla.owner_id = do.owner_id
JOIN stage_names sn ON dla.stage_id = sn.stage_id
WHERE DATE_DIFF(CURRENT_DATE(), dla.last_activity_date, DAY) > 7
  AND DATE_DIFF(dla.close_date, CURRENT_DATE(), DAY) <= 30  -- Closing within 30 days
  AND DATE_DIFF(dla.close_date, CURRENT_DATE(), DAY) >= 0   -- Not expired
ORDER BY days_since_activity DESC, dla.amount DESC;


-- =============================================================================
-- SUMMARY: Count by owner
-- =============================================================================
/*
SELECT
    do.owner_name,
    COUNT(dla.deal_id) AS stale_deal_count,
    SUM(dla.amount) AS total_stale_amount,
    CASE
        WHEN COUNT(dla.deal_id) = 0 THEN 'GREEN'
        WHEN COUNT(dla.deal_id) <= 3 THEN 'YELLOW'
        ELSE 'RED'
    END AS status
FROM deal_last_activity dla
JOIN deal_owners do ON dla.owner_id = do.owner_id
WHERE DATE_DIFF(CURRENT_DATE(), dla.last_activity_date, DAY) > 7
  AND DATE_DIFF(dla.close_date, CURRENT_DATE(), DAY) BETWEEN 0 AND 30
GROUP BY do.owner_name
ORDER BY stale_deal_count DESC;
*/

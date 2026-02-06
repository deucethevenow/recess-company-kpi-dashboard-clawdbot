-- =============================================================================
-- DEALS CLOSING SOON (This Week / This Month / Next Month)
-- =============================================================================
-- Purpose: Show deals with upcoming close dates for forecasting
-- Owner: Demand Sales Team
-- Refresh: Daily
--
-- HubSpot Dashboard Reference:
--   - https://app.hubspot.com/reports-dashboard/6699636/view/16787401
-- =============================================================================

WITH deal_owners AS (
    SELECT
        owner_id,
        CONCAT(first_name, ' ', last_name) AS owner_name
    FROM `stitchdata-384118.src_fivetran_hubspot.owner`
),

stage_names AS (
    SELECT stage_id, label AS stage_name
    FROM `stitchdata-384118.src_fivetran_hubspot.deal_pipeline_stage`
    WHERE pipeline_id = 'default'
),

open_deals AS (
    SELECT
        d.deal_id,
        d.property_dealname AS deal_name,
        d.property_amount AS amount,
        d.property_hs_forecast_amount AS weighted_amount,
        d.property_closedate AS close_date,
        d.property_dealstage AS stage_id,
        d.owner_id,

        -- Time bucket
        CASE
            WHEN d.property_closedate < CURRENT_DATE() THEN 'EXPIRED'
            WHEN d.property_closedate <= DATE_ADD(CURRENT_DATE(), INTERVAL 7 DAY) THEN 'THIS_WEEK'
            WHEN DATE_TRUNC(d.property_closedate, MONTH) = DATE_TRUNC(CURRENT_DATE(), MONTH) THEN 'THIS_MONTH'
            WHEN DATE_TRUNC(d.property_closedate, MONTH) = DATE_TRUNC(DATE_ADD(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH) THEN 'NEXT_MONTH'
            ELSE 'FUTURE'
        END AS time_bucket

    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.property_hs_is_closed = FALSE
      AND d.deal_pipeline_id = 'default'
      AND d.property_amount > 0
)

-- Summary by time bucket
SELECT
    time_bucket,
    COUNT(deal_id) AS deal_count,
    SUM(amount) AS total_amount,
    SUM(COALESCE(weighted_amount, amount * 0.5)) AS weighted_amount,
    ROUND(AVG(amount), 0) AS avg_deal_size
FROM open_deals
GROUP BY time_bucket

UNION ALL

-- Detail view (top deals per bucket)
SELECT
    CONCAT(od.time_bucket, '_DETAIL') AS time_bucket,
    od.deal_id AS deal_count,  -- Reusing column for deal_id in detail view
    od.amount AS total_amount,
    od.weighted_amount,
    0 AS avg_deal_size
FROM open_deals od
WHERE od.time_bucket IN ('THIS_WEEK', 'EXPIRED')

ORDER BY
    CASE time_bucket
        WHEN 'EXPIRED' THEN 1
        WHEN 'THIS_WEEK' THEN 2
        WHEN 'THIS_MONTH' THEN 3
        WHEN 'NEXT_MONTH' THEN 4
        WHEN 'FUTURE' THEN 5
        ELSE 6
    END;


-- =============================================================================
-- ALTERNATIVE: Detailed view with owner names
-- =============================================================================
/*
SELECT
    od.time_bucket,
    do.owner_name,
    od.deal_name,
    od.amount,
    od.weighted_amount,
    od.close_date,
    sn.stage_name,
    DATE_DIFF(od.close_date, CURRENT_DATE(), DAY) AS days_to_close
FROM open_deals od
JOIN deal_owners do ON od.owner_id = do.owner_id
JOIN stage_names sn ON od.stage_id = sn.stage_id
WHERE od.time_bucket IN ('EXPIRED', 'THIS_WEEK', 'THIS_MONTH')
ORDER BY od.time_bucket, od.close_date;
*/

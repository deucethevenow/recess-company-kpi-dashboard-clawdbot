-- =============================================================================
-- MEETINGS BOOKED (MTD) - Supply
-- =============================================================================
-- Purpose: Track meetings booked month-to-date for Supply pipeline
-- Owner: Ian Hong (Supply)
-- Target: 24/month
-- Refresh: Daily
-- =============================================================================

-- HubSpot Property: date_converted_meeting_booked
-- This query uses the deal-level meeting booked date from the Supply pipeline

WITH supply_meetings_from_deals AS (
    -- Method 1: Use deal property date_converted_meeting_booked
    SELECT
        d.deal_id,
        d.property_dealname AS deal_name,
        PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', d.property_date_converted_meeting_booked) AS meeting_date,
        DATE_TRUNC(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', d.property_date_converted_meeting_booked), MONTH) AS meeting_month,
        d.property_hubspot_owner_id AS owner_id
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.deal_pipeline_id = 'supply'  -- Supply pipeline
      AND d.property_date_converted_meeting_booked IS NOT NULL
      AND DATE_TRUNC(PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', d.property_date_converted_meeting_booked), MONTH)
          = DATE_TRUNC(CURRENT_DATE(), MONTH)
),

meetings AS (
    SELECT * FROM supply_meetings_from_deals
)

SELECT
    FORMAT_DATE('%Y-%m', meeting_month) AS month,
    COUNT(engagement_id) AS meetings_booked,
    24 AS monthly_target,
    COUNT(engagement_id) - 24 AS variance,
    ROUND(COUNT(engagement_id) * 100.0 / 24, 1) AS pct_of_target,

    -- Days into month for pacing
    EXTRACT(DAY FROM CURRENT_DATE()) AS days_into_month,
    EXTRACT(DAY FROM LAST_DAY(CURRENT_DATE())) AS total_month_days,

    -- Expected pace
    ROUND(24 * EXTRACT(DAY FROM CURRENT_DATE()) / EXTRACT(DAY FROM LAST_DAY(CURRENT_DATE())), 1) AS expected_pace,

    -- Ahead/behind pace
    COUNT(engagement_id) - ROUND(24 * EXTRACT(DAY FROM CURRENT_DATE()) / EXTRACT(DAY FROM LAST_DAY(CURRENT_DATE())), 1) AS ahead_behind_pace,

    CASE
        WHEN COUNT(engagement_id) >= 24 THEN 'GREEN'
        WHEN COUNT(engagement_id) >= 18 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM meetings
GROUP BY meeting_month;


-- =============================================================================
-- QUARTERLY VIEW
-- =============================================================================
/*
SELECT
    FORMAT_DATE('%Y-Q%Q', DATE_TRUNC(meeting_date, QUARTER)) AS quarter,
    COUNT(engagement_id) AS meetings_booked,
    72 AS quarterly_target,  -- 24 * 3 months
    COUNT(engagement_id) - 72 AS variance
FROM meetings
WHERE DATE_TRUNC(meeting_date, QUARTER) = DATE_TRUNC(CURRENT_DATE(), QUARTER)
GROUP BY DATE_TRUNC(meeting_date, QUARTER);
*/

-- =============================================================================
-- MEETINGS BOOKED (QTD) vs GOAL
-- =============================================================================
-- Purpose: Track meetings booked quarter-to-date against monthly targets
-- Owner: Demand Sales Team
-- Target: 45/month (135/quarter)
-- Refresh: Daily
--
-- HubSpot Dashboard Reference:
--   - https://app.hubspot.com/reports-dashboard/6699636/view/3551608
-- =============================================================================

WITH deal_owners AS (
    SELECT
        owner_id,
        CONCAT(first_name, ' ', last_name) AS owner_name,
        email
    FROM `stitchdata-384118.src_fivetran_hubspot.owner`
    WHERE email IN ('danny@recess.is', 'katie@recess.is', 'andy@recess.is')
),

-- Meetings from HubSpot engagements
meetings AS (
    SELECT
        e.engagement_id,
        e.owner_id,
        e.created_at AS meeting_date,
        DATE_TRUNC(e.created_at, MONTH) AS meeting_month,
        DATE_TRUNC(e.created_at, QUARTER) AS meeting_quarter
    FROM `stitchdata-384118.src_fivetran_hubspot.engagement` e
    WHERE e.type = 'MEETING'
      AND DATE_TRUNC(e.created_at, QUARTER) = DATE_TRUNC(CURRENT_DATE(), QUARTER)
),

-- Also count deals entering "Meeting Booked" stage this quarter
deals_to_meeting_stage AS (
    SELECT
        d.deal_id,
        d.owner_id,
        d.property_createdate AS meeting_date,
        DATE_TRUNC(d.property_createdate, MONTH) AS meeting_month,
        DATE_TRUNC(d.property_createdate, QUARTER) AS meeting_quarter
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.property_dealstage = 'meetingbooked'  -- Adjust stage ID as needed
      AND DATE_TRUNC(d.property_createdate, QUARTER) = DATE_TRUNC(CURRENT_DATE(), QUARTER)
),

monthly_targets AS (
    SELECT 45 AS monthly_target, 135 AS quarterly_target
)

-- Summary by rep by month
SELECT
    do.owner_name,
    FORMAT_DATE('%Y-%m', m.meeting_month) AS month,
    COUNT(m.engagement_id) AS meetings_booked,
    mt.monthly_target,
    COUNT(m.engagement_id) - mt.monthly_target AS variance,
    ROUND(COUNT(m.engagement_id) * 100.0 / mt.monthly_target, 1) AS pct_of_target,
    CASE
        WHEN COUNT(m.engagement_id) >= mt.monthly_target THEN 'GREEN'
        WHEN COUNT(m.engagement_id) >= mt.monthly_target * 0.75 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM deal_owners do
CROSS JOIN monthly_targets mt
LEFT JOIN meetings m ON do.owner_id = m.owner_id
GROUP BY do.owner_name, m.meeting_month, mt.monthly_target
ORDER BY do.owner_name, month;


-- =============================================================================
-- QUARTERLY SUMMARY
-- =============================================================================
/*
SELECT
    do.owner_name,
    COUNT(m.engagement_id) AS meetings_booked_qtd,
    135 AS quarterly_target,
    COUNT(m.engagement_id) - 135 AS variance,
    ROUND(COUNT(m.engagement_id) * 100.0 / 135, 1) AS pct_of_target,

    -- Days into quarter for pacing
    DATE_DIFF(CURRENT_DATE(), DATE_TRUNC(CURRENT_DATE(), QUARTER), DAY) AS days_into_quarter,
    90 AS total_quarter_days,

    -- Expected vs actual
    ROUND(135 * DATE_DIFF(CURRENT_DATE(), DATE_TRUNC(CURRENT_DATE(), QUARTER), DAY) / 90.0, 0) AS expected_pace,
    COUNT(m.engagement_id) - ROUND(135 * DATE_DIFF(CURRENT_DATE(), DATE_TRUNC(CURRENT_DATE(), QUARTER), DAY) / 90.0, 0) AS ahead_behind_pace

FROM deal_owners do
LEFT JOIN meetings m ON do.owner_id = m.owner_id
GROUP BY do.owner_name
ORDER BY meetings_booked_qtd DESC;
*/

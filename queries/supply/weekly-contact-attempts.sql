-- =============================================================================
-- WEEKLY CONTACT ATTEMPTS (Supply Activity Metric)
-- =============================================================================
-- Purpose: Track weekly outbound contact attempts on Supply Target Accounts
-- Owner: Ian Hong (Supply)
-- Target: 600/week
-- Refresh: Daily
-- =============================================================================

WITH supply_contacts AS (
    -- Get contacts marked as Supply Target Accounts
    SELECT
        c.id AS contact_id,
        c.property_email AS email,
        c.property_firstname AS first_name,
        c.property_lastname AS last_name,
        c.property_company AS company
    FROM `stitchdata-384118.src_fivetran_hubspot.contact` c
    WHERE c.property_hs_lead_status = 'Supply Target'  -- TODO: Verify property name
       OR c.property_lifecyclestage = 'supply_target'  -- TODO: Verify property name
),

contact_attempts AS (
    -- Get all contact attempts (calls, emails, sequences)
    SELECT
        e.engagement_id,
        e.contact_id,
        e.type AS engagement_type,
        e.created_at AS attempt_date,
        DATE_TRUNC(e.created_at, WEEK(MONDAY)) AS attempt_week
    FROM `stitchdata-384118.src_fivetran_hubspot.engagement` e
    WHERE e.type IN ('EMAIL', 'CALL', 'MEETING', 'NOTE')
      AND e.created_at >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 WEEK)
)

-- Weekly summary
SELECT
    FORMAT_DATE('%Y-W%V', ca.attempt_week) AS week,
    COUNT(ca.engagement_id) AS total_attempts,
    COUNTIF(ca.engagement_type = 'EMAIL') AS email_attempts,
    COUNTIF(ca.engagement_type = 'CALL') AS call_attempts,
    COUNTIF(ca.engagement_type = 'MEETING') AS meeting_attempts,
    600 AS weekly_target,
    COUNT(ca.engagement_id) - 600 AS variance,
    ROUND(COUNT(ca.engagement_id) * 100.0 / 600, 1) AS pct_of_target,
    CASE
        WHEN COUNT(ca.engagement_id) >= 600 THEN 'GREEN'
        WHEN COUNT(ca.engagement_id) >= 450 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM contact_attempts ca
JOIN supply_contacts sc ON ca.contact_id = sc.contact_id
GROUP BY ca.attempt_week
ORDER BY week DESC
LIMIT 12;


-- =============================================================================
-- DAILY BREAKDOWN (Current Week)
-- =============================================================================
/*
SELECT
    DATE(ca.attempt_date) AS date,
    COUNT(ca.engagement_id) AS attempts,
    ROUND(600 / 5.0, 0) AS daily_target,  -- 600/week ÷ 5 days
    CASE
        WHEN COUNT(ca.engagement_id) >= 120 THEN 'GREEN'
        WHEN COUNT(ca.engagement_id) >= 90 THEN 'YELLOW'
        ELSE 'RED'
    END AS status
FROM contact_attempts ca
JOIN supply_contacts sc ON ca.contact_id = sc.contact_id
WHERE DATE_TRUNC(ca.attempt_date, WEEK(MONDAY)) = DATE_TRUNC(CURRENT_DATE(), WEEK(MONDAY))
GROUP BY DATE(ca.attempt_date)
ORDER BY date;
*/

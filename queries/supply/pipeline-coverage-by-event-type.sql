-- =============================================================================
-- PIPELINE COVERAGE BY EVENT TYPE
-- =============================================================================
-- Purpose: Calculate pipeline coverage ratio for each inventory/event type
-- Owner: Ian Hong (Supply)
-- Target: 3x coverage per event type
-- Refresh: Daily
--
-- Note: Goals by event type are stored in Google Sheets
-- This query needs to join with Sheets data or use hardcoded goals
-- =============================================================================

WITH event_type_goals AS (
    -- Hardcoded goals from Google Sheets (update as needed)
    -- Goal represents sample capacity target
    SELECT 'university_housing' AS event_type, 40000 AS goal UNION ALL
    SELECT 'fitness_studios', 400000 UNION ALL
    SELECT 'youth_sports', 500000 UNION ALL
    SELECT 'kids_camp', 150000 UNION ALL
    SELECT 'music_festivals', 72000 UNION ALL
    SELECT 'running', 125000 UNION ALL
    SELECT 'gyms', 100000 UNION ALL
    SELECT 'college_events', 80000
    -- Add more event types as needed
),

supply_deals AS (
    SELECT
        d.deal_id,
        d.property_dealname AS deal_name,
        d.property_amount AS amount,
        -- Extract event type from deal properties or custom field
        COALESCE(
            d.property_event_type,  -- TODO: Verify actual property name
            'unknown'
        ) AS event_type,
        d.property_hs_is_closed_won AS is_won,
        d.property_hs_is_closed AS is_closed
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.deal_pipeline_id = 'supply'  -- TODO: Verify supply pipeline ID
      AND EXTRACT(YEAR FROM d.property_createdate) = EXTRACT(YEAR FROM CURRENT_DATE())
)

SELECT
    etg.event_type,
    etg.goal,

    -- Won (closed)
    SUM(CASE WHEN sd.is_won = TRUE THEN sd.amount ELSE 0 END) AS won_amount,
    ROUND(SUM(CASE WHEN sd.is_won = TRUE THEN sd.amount ELSE 0 END) * 100.0 / etg.goal, 1) AS pct_of_goal,

    -- Open pipeline
    SUM(CASE WHEN sd.is_closed = FALSE THEN sd.amount ELSE 0 END) AS open_pipeline,

    -- Pipeline coverage
    SAFE_DIVIDE(
        SUM(CASE WHEN sd.is_closed = FALSE THEN sd.amount ELSE 0 END),
        etg.goal - SUM(CASE WHEN sd.is_won = TRUE THEN sd.amount ELSE 0 END)
    ) AS pipeline_coverage_ratio,

    -- Gap to 3x
    (3.0 * (etg.goal - SUM(CASE WHEN sd.is_won = TRUE THEN sd.amount ELSE 0 END))) -
        SUM(CASE WHEN sd.is_closed = FALSE THEN sd.amount ELSE 0 END) AS gap_to_3x,

    -- Status
    CASE
        WHEN SAFE_DIVIDE(
            SUM(CASE WHEN sd.is_closed = FALSE THEN sd.amount ELSE 0 END),
            etg.goal - SUM(CASE WHEN sd.is_won = TRUE THEN sd.amount ELSE 0 END)
        ) >= 3.0 THEN 'GREEN'
        WHEN SAFE_DIVIDE(
            SUM(CASE WHEN sd.is_closed = FALSE THEN sd.amount ELSE 0 END),
            etg.goal - SUM(CASE WHEN sd.is_won = TRUE THEN sd.amount ELSE 0 END)
        ) >= 2.0 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM event_type_goals etg
LEFT JOIN supply_deals sd ON LOWER(sd.event_type) = LOWER(etg.event_type)
GROUP BY etg.event_type, etg.goal
ORDER BY pipeline_coverage_ratio ASC;

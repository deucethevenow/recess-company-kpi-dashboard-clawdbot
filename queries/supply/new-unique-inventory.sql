-- =============================================================================
-- NEW UNIQUE INVENTORY ADDED (Ian Hong's PRIMARY Metric)
-- =============================================================================
-- Purpose: Track new unique venues/inventory onboarded per quarter
-- Owner: Ian Hong (Supply)
-- Target: 16/quarter (4/month)
-- Refresh: Daily
--
-- Note: "Unique inventory" definition needs verification with Ian
-- Current interpretation: New venues that reached "Onboarded" stage in HubSpot
-- =============================================================================

WITH supply_pipeline_stages AS (
    -- Get Supply pipeline stages (adjust pipeline_id as needed)
    SELECT
        stage_id,
        label AS stage_name,
        display_order
    FROM `stitchdata-384118.src_fivetran_hubspot.deal_pipeline_stage`
    WHERE pipeline_id = 'supply'  -- TODO: Verify supply pipeline ID
),

-- HubSpot Properties for Supply Onboarding:
-- - date_converted_onboarded: When onboarding was completed
-- - onboarded_at: Final onboard timestamp (alternative)
-- - closedate: Deal close date

onboarded_venues AS (
    SELECT
        d.deal_id,
        d.property_dealname AS venue_name,
        d.property_createdate AS created_date,
        -- Use date_converted_onboarded for accuracy, fallback to closedate
        COALESCE(
            PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', d.property_date_converted_onboarded),
            PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', d.property_onboarded_at),
            d.property_closedate
        ) AS onboarded_date,
        DATE_TRUNC(
            COALESCE(
                PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', d.property_date_converted_onboarded),
                PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', d.property_onboarded_at),
                d.property_closedate
            ),
            QUARTER
        ) AS onboarded_quarter,
        DATE_TRUNC(
            COALESCE(
                PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', d.property_date_converted_onboarded),
                PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', d.property_onboarded_at),
                d.property_closedate
            ),
            MONTH
        ) AS onboarded_month,
        d.property_hs_object_source AS source
    FROM `stitchdata-384118.src_fivetran_hubspot.deal` d
    WHERE d.property_hs_is_closed_won = TRUE
      AND d.deal_pipeline_id = 'supply'  -- Supply pipeline
      AND EXTRACT(YEAR FROM COALESCE(
          PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', d.property_date_converted_onboarded),
          d.property_closedate
      )) = EXTRACT(YEAR FROM CURRENT_DATE())
)

-- Quarterly summary
SELECT
    FORMAT_DATE('%Y-Q%Q', onboarded_quarter) AS quarter,
    COUNT(deal_id) AS new_inventory_count,
    16 AS quarterly_target,
    COUNT(deal_id) - 16 AS variance,
    ROUND(COUNT(deal_id) * 100.0 / 16, 1) AS pct_of_target,
    CASE
        WHEN COUNT(deal_id) >= 16 THEN 'GREEN'
        WHEN COUNT(deal_id) >= 12 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM onboarded_venues
WHERE onboarded_quarter = DATE_TRUNC(CURRENT_DATE(), QUARTER)
GROUP BY onboarded_quarter;


-- =============================================================================
-- MONTHLY BREAKDOWN
-- =============================================================================
/*
SELECT
    FORMAT_DATE('%Y-%m', onboarded_month) AS month,
    COUNT(deal_id) AS new_inventory_count,
    4 AS monthly_target,  -- 16/quarter = 4/month
    COUNT(deal_id) - 4 AS variance,
    CASE
        WHEN COUNT(deal_id) >= 4 THEN 'GREEN'
        WHEN COUNT(deal_id) >= 3 THEN 'YELLOW'
        ELSE 'RED'
    END AS status
FROM onboarded_venues
WHERE EXTRACT(YEAR FROM onboarded_month) = EXTRACT(YEAR FROM CURRENT_DATE())
GROUP BY onboarded_month
ORDER BY month;
*/


-- =============================================================================
-- ALTERNATIVE: Using MongoDB audience_listings (if HubSpot supply pipeline unavailable)
-- =============================================================================
/*
SELECT
    DATE_TRUNC(published_at, QUARTER) AS quarter,
    COUNT(DISTINCT _id) AS new_listings,
    primary_type AS event_type
FROM `stitchdata-384118.mongodb.audience_listings`
WHERE published_state = 'published'
  AND is_omnichannel = FALSE
  AND EXTRACT(YEAR FROM published_at) = EXTRACT(YEAR FROM CURRENT_DATE())
GROUP BY quarter, primary_type
ORDER BY quarter, new_listings DESC;
*/

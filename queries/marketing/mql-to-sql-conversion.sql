-- =============================================================================
-- MQL → SQL CONVERSION RATE
-- =============================================================================
-- Purpose: Track conversion from Marketing Qualified Lead to Sales Qualified Lead
-- Owner: Marketing
-- Target: 30%
-- Refresh: Daily
-- =============================================================================

WITH lead_stages AS (
    SELECT
        c.id AS contact_id,
        c.property_email AS email,
        c.property_company AS company,
        c.property_lifecyclestage AS current_stage,

        -- MQL timestamp
        PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S',
            c.property_became_marketing_qualified_lead_date) AS mql_date,

        -- SQL timestamp
        PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S',
            c.property_became_sales_qualified_lead_date) AS sql_date,

        -- Extract month for cohort analysis
        DATE_TRUNC(
            PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S',
                c.property_became_marketing_qualified_lead_date),
            MONTH
        ) AS mql_month

    FROM `stitchdata-384118.src_fivetran_hubspot.contact` c
    WHERE c.property_became_marketing_qualified_lead_date IS NOT NULL
      AND EXTRACT(YEAR FROM PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S',
          c.property_became_marketing_qualified_lead_date)) = EXTRACT(YEAR FROM CURRENT_DATE())
)

-- Overall conversion rate
SELECT
    'MQL → SQL Conversion' AS metric,
    COUNT(*) AS total_mqls,
    COUNTIF(sql_date IS NOT NULL) AS converted_to_sql,
    ROUND(COUNTIF(sql_date IS NOT NULL) * 100.0 / COUNT(*), 1) AS conversion_rate_pct,
    30.0 AS target_pct,
    ROUND(COUNTIF(sql_date IS NOT NULL) * 100.0 / COUNT(*), 1) - 30.0 AS variance_from_target,
    CASE
        WHEN COUNTIF(sql_date IS NOT NULL) * 100.0 / COUNT(*) >= 30 THEN 'GREEN'
        WHEN COUNTIF(sql_date IS NOT NULL) * 100.0 / COUNT(*) >= 20 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM lead_stages;


-- =============================================================================
-- MONTHLY COHORT VIEW
-- =============================================================================
/*
SELECT
    FORMAT_DATE('%Y-%m', mql_month) AS mql_cohort,
    COUNT(*) AS mqls,
    COUNTIF(sql_date IS NOT NULL) AS converted,
    ROUND(COUNTIF(sql_date IS NOT NULL) * 100.0 / COUNT(*), 1) AS conversion_rate,
    -- Avg time to convert
    ROUND(AVG(
        CASE WHEN sql_date IS NOT NULL
             THEN TIMESTAMP_DIFF(sql_date, mql_date, DAY)
        END
    ), 1) AS avg_days_to_convert
FROM lead_stages
GROUP BY mql_month
ORDER BY mql_month DESC;
*/


-- =============================================================================
-- BY SOURCE
-- =============================================================================
/*
SELECT
    COALESCE(c.property_hs_analytics_source, 'Unknown') AS source,
    COUNT(*) AS mqls,
    COUNTIF(ls.sql_date IS NOT NULL) AS converted,
    ROUND(COUNTIF(ls.sql_date IS NOT NULL) * 100.0 / COUNT(*), 1) AS conversion_rate
FROM lead_stages ls
JOIN `stitchdata-384118.src_fivetran_hubspot.contact` c
    ON ls.contact_id = c.id
GROUP BY c.property_hs_analytics_source
ORDER BY mqls DESC;
*/

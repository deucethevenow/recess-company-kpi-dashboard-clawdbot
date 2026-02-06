-- =============================================================================
-- TOP CUSTOMER CONCENTRATION (Shared: COO + CEO + Company Health)
-- =============================================================================
-- Purpose: Track revenue concentration risk - % from top customer
-- Owner: Deuce (COO), Jack (CEO)
-- Target: <30% (single customer)
-- Refresh: Daily
--
-- Why It Matters: 41% HEINEKEN = existential risk. If they churn, business fails.
-- =============================================================================

-- Use the authoritative NRR view which has customer-level revenue data
WITH customer_revenue AS (
    SELECT
        company_name,
        total_ltv AS total_revenue,
        -- Add YTD if available
        COALESCE(net_rev_2026, net_rev_2025, net_rev_2024) AS current_year_revenue
    FROM `stitchdata-384118.App_KPI_Dashboard.net_revenue_retention_all_customers`
    WHERE total_ltv > 0
),

total_rev AS (
    SELECT SUM(total_revenue) AS grand_total
    FROM customer_revenue
),

ranked_customers AS (
    SELECT
        cr.company_name,
        cr.total_revenue,
        cr.current_year_revenue,
        cr.total_revenue * 100.0 / tr.grand_total AS pct_of_total,
        ROW_NUMBER() OVER (ORDER BY cr.total_revenue DESC) AS revenue_rank
    FROM customer_revenue cr
    CROSS JOIN total_rev tr
)

-- Summary
SELECT
    'Customer Concentration' AS metric,
    MAX(CASE WHEN revenue_rank = 1 THEN company_name END) AS top_customer,
    MAX(CASE WHEN revenue_rank = 1 THEN pct_of_total END) AS top_customer_pct,
    MAX(CASE WHEN revenue_rank = 2 THEN company_name END) AS second_customer,
    MAX(CASE WHEN revenue_rank = 2 THEN pct_of_total END) AS second_customer_pct,
    MAX(CASE WHEN revenue_rank = 3 THEN company_name END) AS third_customer,
    MAX(CASE WHEN revenue_rank = 3 THEN pct_of_total END) AS third_customer_pct,

    -- Top 5 concentration
    SUM(CASE WHEN revenue_rank <= 5 THEN pct_of_total ELSE 0 END) AS top_5_concentration_pct,

    -- Top 10 concentration
    SUM(CASE WHEN revenue_rank <= 10 THEN pct_of_total ELSE 0 END) AS top_10_concentration_pct,

    30.0 AS target_max_pct,

    CASE
        WHEN MAX(CASE WHEN revenue_rank = 1 THEN pct_of_total END) < 30 THEN 'GREEN'
        WHEN MAX(CASE WHEN revenue_rank = 1 THEN pct_of_total END) < 40 THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM ranked_customers
WHERE revenue_rank <= 10;


-- =============================================================================
-- TOP 20 CUSTOMERS (Drill-down)
-- =============================================================================
/*
SELECT
    revenue_rank,
    company_name,
    total_revenue,
    current_year_revenue,
    ROUND(pct_of_total, 1) AS pct_of_total,
    SUM(pct_of_total) OVER (ORDER BY revenue_rank) AS cumulative_pct
FROM ranked_customers
WHERE revenue_rank <= 20
ORDER BY revenue_rank;
*/


-- =============================================================================
-- CONCENTRATION BY YEAR
-- =============================================================================
/*
SELECT
    'YTD Concentration' AS period,
    MAX(CASE WHEN revenue_rank = 1 THEN company_name END) AS top_customer,
    MAX(CASE WHEN revenue_rank = 1 THEN pct_of_total END) AS top_customer_pct
FROM (
    SELECT
        company_name,
        current_year_revenue,
        current_year_revenue * 100.0 / SUM(current_year_revenue) OVER () AS pct_of_total,
        ROW_NUMBER() OVER (ORDER BY current_year_revenue DESC) AS revenue_rank
    FROM customer_revenue
    WHERE current_year_revenue > 0
)
WHERE revenue_rank = 1;
*/

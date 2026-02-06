-- Core Action State Counts for Demand (Customers)
-- Owner: Demand Sales Team
-- Purpose: Dashboard metrics for Active/Loosing/Lost customer counts
--
-- Core Action States:
-- - Active: Has revenue in 2025, stable or growing vs 2024
-- - Loosing: Has revenue in 2025 but declining >50% vs 2024
-- - Lost: Had revenue in 2024, none in 2025
-- - Inactive: No revenue in 2024 or 2025 (dormant)
--
-- Source: customer_development view
-- Output: Counts and $ totals for each state

WITH customer_years AS (
  SELECT
    customer_id,
    company_name,
    COALESCE(Net_Revenue_2024, 0) as revenue_2024,
    COALESCE(Net_Revenue_2025, 0) as revenue_2025
  FROM `stitchdata-384118.App_KPI_Dashboard.customer_development`
  WHERE customer_id IS NOT NULL
),

customer_states AS (
  SELECT DISTINCT
    customer_id,
    company_name,
    revenue_2024,
    revenue_2025,
    CASE
      WHEN revenue_2025 > 0 AND revenue_2024 > 0 THEN
        CASE
          WHEN (revenue_2024 - revenue_2025) / NULLIF(revenue_2024, 0) > 0.50
          THEN 'loosing'
          ELSE 'active'
        END
      WHEN revenue_2025 > 0 THEN 'active'  -- New or reactivated in 2025
      WHEN revenue_2024 > 0 THEN 'lost'    -- Had 2024, none in 2025
      ELSE 'inactive'                       -- No recent activity
    END as core_action_state
  FROM customer_years
  WHERE revenue_2024 > 0 OR revenue_2025 > 0  -- Exclude inactive (no activity at all)
)

-- Main output: State counts and totals
SELECT
  core_action_state,
  COUNT(DISTINCT customer_id) as customer_count,
  ROUND(SUM(revenue_2024), 2) as total_revenue_2024,
  ROUND(SUM(revenue_2025), 2) as total_revenue_2025,
  ROUND(SUM(revenue_2025) / NULLIF(SUM(revenue_2024), 0) * 100, 1) as nrr_2025
FROM customer_states
GROUP BY core_action_state

UNION ALL

-- Total row
SELECT
  'TOTAL' as core_action_state,
  COUNT(DISTINCT customer_id) as customer_count,
  ROUND(SUM(revenue_2024), 2) as total_revenue_2024,
  ROUND(SUM(revenue_2025), 2) as total_revenue_2025,
  ROUND(SUM(revenue_2025) / NULLIF(SUM(revenue_2024), 0) * 100, 1) as nrr_2025
FROM customer_states

ORDER BY
  CASE core_action_state
    WHEN 'active' THEN 1
    WHEN 'loosing' THEN 2
    WHEN 'lost' THEN 3
    WHEN 'inactive' THEN 4
    WHEN 'TOTAL' THEN 5
  END;

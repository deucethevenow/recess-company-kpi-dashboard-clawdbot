-- NRR for Top Supply Users
-- Owner: Ashton
-- Target: 110%
-- Purpose: Track revenue retention from top supply partners year-over-year
--
-- NRR Formula: (Current Year GMV from Prior Year Suppliers) / (Prior Year GMV) * 100
-- Filters to suppliers with >$10K lifetime GMV to focus on meaningful partners

WITH supplier_yearly_gmv AS (
  -- Aggregate GMV by supplier and year
  SELECT
    Supplier_Name,
    Offer_Accepted_Year as year,
    SUM(GMV) as gmv,
    SUM(Payouts) as payouts,
    COUNT(DISTINCT Offer_ID) as offer_count
  FROM `stitchdata-384118.App_KPI_Dashboard.Supplier_Metrics`
  WHERE Offer_Accepted_Year >= 2022
  GROUP BY Supplier_Name, Offer_Accepted_Year
),

supplier_pivot AS (
  -- Pivot to get year-over-year comparison
  SELECT
    Supplier_Name,
    SUM(CASE WHEN year = 2022 THEN gmv ELSE 0 END) as gmv_2022,
    SUM(CASE WHEN year = 2023 THEN gmv ELSE 0 END) as gmv_2023,
    SUM(CASE WHEN year = 2024 THEN gmv ELSE 0 END) as gmv_2024,
    SUM(CASE WHEN year = 2025 THEN gmv ELSE 0 END) as gmv_2025,
    SUM(CASE WHEN year = 2026 THEN gmv ELSE 0 END) as gmv_2026,
    SUM(gmv) as total_ltv,
    SUM(payouts) as total_payouts,
    SUM(offer_count) as total_offers
  FROM supplier_yearly_gmv
  GROUP BY Supplier_Name
),

nrr_calculation AS (
  SELECT
    Supplier_Name,
    gmv_2022,
    gmv_2023,
    gmv_2024,
    gmv_2025,
    gmv_2026,
    total_ltv,
    total_payouts,
    total_offers,

    -- NRR 2023: GMV from 2022 suppliers in 2023 / GMV in 2022
    CASE
      WHEN gmv_2022 > 0 THEN ROUND(gmv_2023 / gmv_2022 * 100, 1)
      ELSE NULL
    END as nrr_2023,

    -- NRR 2024: GMV from prior year suppliers in 2024 / GMV in 2023
    CASE
      WHEN gmv_2023 > 0 THEN ROUND(gmv_2024 / gmv_2023 * 100, 1)
      ELSE NULL
    END as nrr_2024,

    -- NRR 2025: GMV from prior year suppliers in 2025 / GMV in 2024
    CASE
      WHEN gmv_2024 > 0 THEN ROUND(gmv_2025 / gmv_2024 * 100, 1)
      ELSE NULL
    END as nrr_2025,

    -- NRR 2026 (YTD): GMV from prior year suppliers in 2026 / GMV in 2025
    CASE
      WHEN gmv_2025 > 0 THEN ROUND(gmv_2026 / gmv_2025 * 100, 1)
      ELSE NULL
    END as nrr_2026_ytd

  FROM supplier_pivot
)

SELECT
  Supplier_Name,
  gmv_2022,
  gmv_2023,
  gmv_2024,
  gmv_2025,
  gmv_2026,
  nrr_2023,
  nrr_2024,
  nrr_2025,
  nrr_2026_ytd,
  total_ltv,
  total_payouts,
  total_offers
FROM nrr_calculation
WHERE total_ltv >= 10000  -- Focus on suppliers with meaningful volume
ORDER BY total_ltv DESC;

-- SUMMARY VIEW: Aggregate NRR across all top suppliers
-- Uncomment to get overall supply NRR metrics
/*
SELECT
  'All Top Suppliers' as segment,
  SUM(gmv_2022) as gmv_2022,
  SUM(gmv_2023) as gmv_2023,
  SUM(gmv_2024) as gmv_2024,
  SUM(gmv_2025) as gmv_2025,
  SUM(gmv_2026) as gmv_2026,
  ROUND(SUM(gmv_2023) / NULLIF(SUM(gmv_2022), 0) * 100, 1) as nrr_2023,
  ROUND(SUM(gmv_2024) / NULLIF(SUM(gmv_2023), 0) * 100, 1) as nrr_2024,
  ROUND(SUM(gmv_2025) / NULLIF(SUM(gmv_2024), 0) * 100, 1) as nrr_2025,
  ROUND(SUM(gmv_2026) / NULLIF(SUM(gmv_2025), 0) * 100, 1) as nrr_2026_ytd,
  COUNT(*) as supplier_count
FROM nrr_calculation
WHERE total_ltv >= 10000;
*/

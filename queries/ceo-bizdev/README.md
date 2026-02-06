# CEO/Biz Dev Queries (Jack)

> **Owner:** Jack (CEO)
> **Primary Metric:** Revenue vs Target
> **Dashboard:** Separate from COO/CFO dashboard

## Query Index

| Query File | Metric | Target | Status |
|------------|--------|--------|--------|
| `revenue-vs-target.sql` | Revenue vs Target | $10M | ✅ Created |
| *(shared)* `coo-ops/working-capital.sql` | Working Capital | >$1M | ✅ Shared |
| *(shared)* `coo-ops/months-of-runway.sql` | Months of Runway | >12 mo | ✅ Shared |
| *(shared)* `coo-ops/top-customer-concentration.sql` | Customer Concentration | <30% | ✅ Shared |
| *(shared)* `demand-sales/pipeline-coverage-by-rep.sql` | Pipeline Coverage | 6.0x | ✅ Shared |
| `cash-position.md` | Cash Position | >$500K | 🟡 Phase 4 (SimpleFin) |

## Shared Metrics with COO/CFO

These metrics appear on BOTH dashboards but use the same underlying query:

| Metric | Query Location | Filter Difference |
|--------|----------------|-------------------|
| Working Capital | `coo-ops/working-capital.sql` | None - same view |
| Months of Runway | `coo-ops/months-of-runway.sql` | None - same view |
| Customer Concentration | `coo-ops/top-customer-concentration.sql` | None - same view |
| Cash Position | Phase 4 - SimpleFin | None - same view |
| Total Unspent Contract $ | `HS_QBO_GMV_Waterfall` view | None - same view |

## CEO-Specific Metrics

| Metric | Status | Notes |
|--------|--------|-------|
| Revenue vs Target | ✅ Created | Uses existing BigQuery revenue views |
| New Target Accounts | 🔍 Verify | Need HubSpot property name |
| Pipeline Coverage (3 methods) | ✅ Ready | Unweighted, HubSpot, AI Weighted |

## Data Sources

| Source | Tables | Status |
|--------|--------|--------|
| BigQuery (QBO) | Revenue views, balance sheet | ✅ Available |
| BigQuery (HubSpot) | Deals, pipeline | ✅ Available |
| SimpleFin | Cash position | 🟡 Phase 4 |

## Status Indicators

| Metric | 🟢 GREEN | 🟡 YELLOW | 🔴 RED |
|--------|----------|----------|--------|
| Revenue vs Target | ≥ 100% | 80-100% | < 80% |
| Pipeline Coverage | ≥ 6.0x | 4.0-6.0x | < 4.0x |
| Customer Concentration | < 30% | 30-40% | > 40% |
| Working Capital | ≥ $1M | $500K-$1M | < $500K |
| Runway | ≥ 12 mo | 6-12 mo | < 6 mo |

# Phase 1: Company Health + Primary Person Metrics

> **Status:** Active Development
> **Goal:** Launch basics - one metric per person for accountability
> **Estimated Unique Queries:** ~20
> **Dependencies:** None (this is the foundation)

---

## Scope Summary

Phase 1 establishes the foundational dashboard with two components:

1. **Company Health Cards (7)** - Top-level business health visible to all roles
2. **Primary Person Metrics (~15)** - One key metric per team member for accountability

This phase answers the question: "Is the business healthy, and is each person delivering on their #1 responsibility?"

---

## Company Health Metrics (7 Cards)

| # | Metric | Owner | Formula | Target | Data Source / Query File | Approval Status |
|---|--------|-------|---------|:------:|--------------------------|:---------------:|
| 1 | **Revenue YTD** | Jack | `YTD Revenue / Annual Target x 100` | $10M | BigQuery (QBO) - existing view | Approved |
| 2 | **Take Rate %** | Deuce | `(GMV - Payouts) / GMV x 100` | 45% | `queries/coo-ops/take-rate.sql` | Approved |
| 3 | **Demand NRR** | Andy | Cohort retention matrix | >100% | `cohort_retention_matrix_by_customer` (BQ view) | Approved |
| 4 | **Supply NRR** | Ashton | Same logic as Demand NRR, supply side | >100% | `Supplier_Metrics` (BQ view) | Needs Review |
| 5 | **Pipeline Coverage** | Andy | `Weighted Pipeline / (Quarterly Quota - Closed Won)` | 6.0x | `queries/demand-sales/pipeline-coverage-by-rep.sql` | Approved |
| 6 | **Sellable Inventory** | ? | TBD - needs PRD | TBD | BigQuery (mongodb) | Blocked - needs PRD |
| 7 | **Time to Fulfill** | Victoria | `AVG(days from contract close to fulfillment)` | <30 days | `Days_to_Fulfill_Contract_Spend` (BQ view) | Needs Review |

**Company Health Status:** 5/7 approved or ready, 2 need approval/definition

---

## Primary Person Metrics (~15 Metrics)

### Demand Sales (3 people, 1 shared metric)

| Person | Metric | Formula | Target | Query File | Approval Status |
|--------|--------|---------|:------:|------------|:---------------:|
| **Andy Cooper** | NRR | Cohort retention matrix | >100% | `cohort_retention_matrix_by_customer` (BQ view) | Ready |
| **Andy Cooper** | Pipeline Coverage | `Weighted Pipeline / (Quarterly Quota - Closed Won)` | 6.0x | `queries/demand-sales/pipeline-coverage-by-rep.sql` | Query Created |
| **Danny Sears** | Pipeline Coverage | Same as Andy, filtered by `deal_owner` | 6.0x | `queries/demand-sales/pipeline-coverage-by-rep.sql` | Query Created |
| **Katie** | Pipeline Coverage | Same as Andy, filtered by `deal_owner` | 6.0x | `queries/demand-sales/pipeline-coverage-by-rep.sql` | Query Created |

### CEO/Biz Dev (1 person)

| Person | Metric | Formula | Target | Query File | Approval Status |
|--------|--------|---------|:------:|------------|:---------------:|
| **Jack** | Revenue vs Target | `YTD Revenue / Annual Target x 100` | $10M | Existing BigQuery view | Ready |

### COO/Ops/Finance (1 person, 2 primary metrics)

| Person | Metric | Formula | Target | Query File | Approval Status |
|--------|--------|---------|:------:|------------|:---------------:|
| **Deuce** | Take Rate % | `(GMV - Payouts) / GMV x 100` | 45% | `queries/coo-ops/take-rate.sql` | Query Created |
| **Deuce** | Invoice Collection Rate | `Paid Invoices / Total Due Invoices x 100` | 95% | `queries/coo-ops/invoice-collection-rate.sql` | Query Created |

### Supply (1 person)

| Person | Metric | Formula | Target | Query File | Approval Status |
|--------|--------|---------|:------:|------------|:---------------:|
| **Ian Hong** | New Unique Inventory | `Count of closed-won deals in Supply pipeline` | 16/qtr | `queries/supply/new-unique-inventory.sql` | Query Created |

### Marketing (1 person)

| Person | Metric | Formula | Target | Query File | Approval Status |
|--------|--------|---------|:------:|------------|:---------------:|
| **Marketing** | Mktg-Influenced Pipeline | `(First Touch + Last Touch) / 2` attribution on open deals | TBD | `queries/marketing/marketing-influenced-pipeline.sql` | Query Created |

### Accounting (1 person)

| Person | Metric | Formula | Target | Query File | Approval Status |
|--------|--------|---------|:------:|------------|:---------------:|
| **Accounting** | Invoice Collection % | `Paid / Total Due x 100` | 95% | QuickBooks AR Aging | Ready |

### Demand AM (4 people)

| Person | Metric | Formula | Target | Query File | Approval Status |
|--------|--------|---------|:------:|------------|:---------------:|
| **Char Short** | Contract Spend % | `Actual Spend / Contract Value x 100` | 95% | BigQuery (contracts + spend) | Build |
| **Victoria** | Time to Fulfill | `AVG(days from close to fulfillment)` | <=30 days | BigQuery (dates) | Build |
| **Claire** | NPS Score | Survey score average | 75% | Survey tool + HubSpot | Build |
| **Francisco** | Offer Acceptance % | `Accepted Offers / Total Offers x 100` | 90% | HubSpot activities | Verify |

### Supply AM (1 person)

| Person | Metric | Formula | Target | Query File | Approval Status |
|--------|--------|---------|:------:|------------|:---------------:|
| **Ashton** | NRR Top Supply Users | Cohort retention for top supply partners | 110% | BigQuery (revenue by partner) | Build |

### Engineering (4 people, 5 metrics)

| Person | Metric | Formula | Target | Query File | Approval Status |
|--------|--------|---------|:------:|------------|:---------------:|
| **Arbind** | Features Fully Scoped | Count of scoped features per month | 5/mo | Asana / GitHub | Build |
| **Mateus** | BizSup Completed | Count of BizSup tasks completed per month | 10/mo | Asana (BizSup project) | Build |
| **Anderson** | PRDs Generated | Count of PRDs per month | 3/mo | Asana / Notion | Build |
| **Anderson** | FSDs Generated | Count of FSDs per month | 2/mo | Asana / Notion | Build |
| **Lucas** | Feature Releases | Count of feature releases | TBD | GitHub | Define |

---

## Shared Metrics (Build Once, Show Many)

These Phase 1 metrics appear on multiple dashboards but use the SAME underlying query:

| Core Metric | Appears On | Filter By |
|-------------|------------|-----------|
| **Pipeline Coverage** | Company Health, Sales (Andy), Sales (Danny), Sales (Katie) | `deal_owner` for person view |
| **NRR (Demand)** | Company Health, Sales (Andy) | None - same view |
| **NRR (Supply)** | Company Health, Supply AM (Ashton) | None - same view |
| **Revenue YTD** | Company Health, CEO (Jack) | None - same view |
| **Time to Fulfill** | Company Health, Demand AM (Victoria) | None - same view |
| **Invoice Collection** | Accounting, COO/Ops (Deuce) | None - same view |

---

## Immediate Actions (Blockers to Resolve)

1. [ ] Deuce approve Supply NRR calculation
2. [ ] Deuce approve Time to Fulfill calculation
3. [ ] Define "sellable" inventory criteria (PRD needed)
4. [ ] Verify metric definitions with Danny (Pipeline Coverage definition)
5. [ ] Verify metric definitions with Ian (New Unique Inventory)
6. [ ] Verify metric definitions with Francisco (Offer Acceptance)
7. [ ] Build Demand AM queries (Char, Victoria, Claire, Francisco)
8. [ ] Build Supply AM query (Ashton - NRR Top Supply Users)
9. [ ] Build Engineering queries (Arbind, Mateus, Anderson, Lucas) - Note: these require Phase 5 APIs

---

## Acceptance Criteria

Phase 1 is **done** when:

- [ ] All 7 Company Health cards display live data on the dashboard
- [ ] Each of the ~15 primary person metrics has a working query
- [ ] All formulas have been reviewed and approved by Deuce
- [ ] Traffic light indicators (green/yellow/red) work for all metrics with targets
- [ ] Tab-based access control restricts views by role
- [ ] Data refreshes daily (overnight batch)
- [ ] Targets are stored in `dashboard/data/targets.json` (not hardcoded in queries)

---

## Estimated Query Count

| Category | Unique Queries | Display Cards |
|----------|:--------------:|:-------------:|
| Company Health | 7 | 7 |
| Person PRIMARY | ~13 | ~15 (some reuse Pipeline Coverage) |
| **Phase 1 Total** | **~20** | **~22** |

---

## Key Technical Notes

- Pipeline Coverage uses `hs_forecast_amount` (sales rep confidence), NOT stage probability
- `customer_development` view has multiple rows per customer - must use `COUNT(DISTINCT customer_id)`
- NRR dashboard key is `nrr` but BigQuery returns `demand_nrr` - mapping needed
- Engineering metrics (Arbind, Mateus, Anderson, Lucas) technically require Phase 5 APIs (Asana, GitHub, Notion) but are listed as Phase 1 PRIMARY by business priority. Consider placeholder/manual entry until Phase 5.

---

## Integration Testing

After implementing a BQ function, follow this standard pattern:
1. Unit test (mock BQ client)
2. Integration smoke test (real BQ, `pytest -m integration`)
3. Enriched tooltip with 5 static fields
4. Add metric target to `targets.json` via Settings tab

**This phase: 14 integration smoke tests**

Run: `cd dashboard && pytest -m integration`

## Tooltip Enrichment

Each metric gets a 5-section tooltip:
- Definition (plain English)
- Why It Matters (business impact)
- Calculation (formula in monospace)
- Target pill (from `targets.json` via Settings tab)
- 2025 Benchmark pill (from `METRIC_DEFINITIONS`, where meaningful)
- Edge Cases (amber callout, when applicable)

**This phase: 16 tooltips to enrich**

## Settings Tab Targets

New metric targets added to the Settings tab's "Metric Targets" form and saved to `targets.json`:

**This phase: 18 new metric targets**

Standard pattern: "After implementing a BQ function: (1) unit test, (2) integration smoke test, (3) enriched tooltip with 5 static fields, (4) add metric target to targets.json via Settings tab"

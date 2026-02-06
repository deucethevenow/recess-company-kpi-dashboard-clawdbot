# Phase 1: Company Health + Primary Person Metrics

> **Status:** Active Development
> **Goal:** Launch basics - one metric per person for accountability
> **Estimated Unique Queries:** ~18
> **Dependencies:** None (this is the foundation)

---

## Scope Summary

Phase 1 establishes the foundational dashboard with two components:

1. **Company Health Cards (7)** - Top-level business health visible to all roles
2. **Primary Person Metrics (~13 BQ-based)** - One key metric per team member for accountability

This phase answers the question: "Is the business healthy, and is each person delivering on their #1 responsibility?"

> **Engineering PRIMARY metrics (Arbind, Mateus, Anderson, Lucas) are deferred to Phase 5.**
> Those metrics require Asana, GitHub, and Notion API integrations which are not available in Phase 1.
> See the [Master Implementation Plan](./MASTER-IMPLEMENTATION-PLAN.md) Phase 5 section for details.

---

## Batch Structure

All Phase 1 work is organized into four batches based on readiness:

| Batch | Description | Count | Blocker |
|-------|-------------|:-----:|---------|
| **A** | Ready to Implement (Approved + Query Exists) | ~10 | None |
| **B** | Needs Formula Approval (Query Exists, Needs Review) | ~3 | Deuce review |
| **C** | Needs Query Development (Data Source Clear) | ~5 | Dev work |
| **D** | Needs Definition / Blocked | ~2 | External input |

---

## Company Health Metrics (7 Cards)

| # | Metric | Owner | Formula | Target | Data Source / Query File | Batch |
|---|--------|-------|---------|:------:|--------------------------|:-----:|
| 1 | **Revenue YTD** | Jack | `YTD Revenue / Annual Target x 100` | $10M | BigQuery (QBO) - existing view | A |
| 2 | **Take Rate %** | Deuce | `(GMV - Payouts) / GMV x 100` | 45% | `queries/coo-ops/take-rate.sql` | A |
| 3 | **Demand NRR** | Andy | Cohort retention matrix | >100% | `cohort_retention_matrix_by_customer` (BQ view) | A |
| 4 | **Supply NRR** | Ashton | Same logic as Demand NRR, supply side | >100% | `Supplier_Metrics` (BQ view) | B |
| 5 | **Pipeline Coverage** | Andy | `Weighted Pipeline / (Quarterly Quota - Closed Won)` | 6.0x | `queries/demand-sales/pipeline-coverage-by-rep.sql` | A |
| 6 | **Sellable Inventory** | ? | TBD - needs PRD | TBD | BigQuery (mongodb) | D |
| 7 | **Time to Fulfill** | Victoria | `AVG(days from contract close to fulfillment)` | <30 days | `Days_to_Fulfill_Contract_Spend` (BQ view) | B |

**Company Health Status:** 4 Batch A (ready), 2 Batch B (need approval), 1 Batch D (blocked)

---

## Primary Person Metrics (BQ-Based Only, ~13 Metrics)

### Batch A: Ready to Implement (Approved + Query Exists)

Metrics where formula is approved and query SQL exists. Can be implemented immediately.

| Person | Metric | Formula | Target | Query File | Status |
|--------|--------|---------|:------:|------------|:------:|
| **Andy Cooper** | NRR | Cohort retention matrix | >100% | `cohort_retention_matrix_by_customer` (BQ view) | Ready |
| **Andy Cooper** | Pipeline Coverage | `Weighted Pipeline / (Quarterly Quota - Closed Won)` | 6.0x | `queries/demand-sales/pipeline-coverage-by-rep.sql` | Query Created |
| **Danny Sears** | Pipeline Coverage | Same as Andy, filtered by `deal_owner` | 6.0x | `queries/demand-sales/pipeline-coverage-by-rep.sql` | Query Created |
| **Katie** | Pipeline Coverage | Same as Andy, filtered by `deal_owner` | 6.0x | `queries/demand-sales/pipeline-coverage-by-rep.sql` | Query Created |
| **Jack** | Revenue vs Target | `YTD Revenue / Annual Target x 100` | $10M | Existing BigQuery view | Ready |
| **Deuce** | Take Rate % | `(GMV - Payouts) / GMV x 100` | 45% | `queries/coo-ops/take-rate.sql` | Query Created |
| **Deuce** | Invoice Collection Rate | `Paid Invoices / Total Due Invoices x 100` | 95% | `queries/coo-ops/invoice-collection-rate.sql` | Query Created |
| **Ian Hong** | New Unique Inventory | `Count of closed-won deals in Supply pipeline` | 16/qtr | `queries/supply/new-unique-inventory.sql` | Query Created |
| **Marketing** | Mktg-Influenced Pipeline | `(First Touch + Last Touch) / 2` attribution on open deals | TBD | `queries/marketing/marketing-influenced-pipeline.sql` | Query Created |
| **Accounting** | Invoice Collection % | `Paid / Total Due x 100` | 95% | QuickBooks AR Aging | Ready |
| **Francisco** | Offer Acceptance % | `Accepted Offers / Total Offers x 100` | 90% | `queries/demand-am/offer-acceptance-rate.sql` | Query Created |
| **Ashton** | NRR Top Supply Users | Cohort retention for top supply partners | 110% | `queries/supply-am/nrr-top-supply-users-financial.sql` | Query Created |

### Batch B: Needs Formula Approval (Query Exists, Needs Review)

Metrics where query exists but Deuce hasn't approved the formula yet. Blocked on review.

| Person | Metric | Formula | Target | Query File | Blocker |
|--------|--------|---------|:------:|------------|---------|
| **Ashton** (Company Health) | Supply NRR | Same logic as Demand NRR, supply side | >100% | `Supplier_Metrics` (BQ view) | Deuce approval |
| **Victoria** (Company Health) | Time to Fulfill | `AVG(days from close to fulfillment)` | <30 days | `Days_to_Fulfill_Contract_Spend` (BQ view) | Deuce approval |

### Batch C: Needs Query Development (Data Source Clear)

Metrics where we know the data source but need to write the query.

| Person | Metric | Formula | Target | Data Source | Notes |
|--------|--------|---------|:------:|-------------|-------|
| **Char Short** | Contract Spend % | `Actual Spend / Contract Value x 100` | 95% | BigQuery (contracts + spend) | `Upfront_Contract_Spend_Query` view exists |
| **Victoria** | Time to Fulfill | `AVG(days from close to fulfillment)` | <=30 days | BigQuery (dates) | `Days_to_Fulfill_Contract_Spend` view exists |
| **Claire** | NPS Score | Survey score average | 75% | `organizer_recap_NPS_score` (BQ view) | View exists, need query |

### Batch D: Needs Definition / Blocked

Metrics that need business definition or are waiting on external inputs.

| Person / Card | Metric | Target | Blocker |
|---------------|--------|:------:|---------|
| **Sellable Inventory** (Company Health) | Sellable Inventory | TBD | Needs PRD to define "sellable" criteria |

---

## Engineering PRIMARY Metrics - Deferred to Phase 5

> **These metrics are NOT in Phase 1 scope.** They require external API integrations (Asana, GitHub, Notion) that are planned for Phase 5.

| Person | Metric | Target | Required API | Phase |
|--------|--------|:------:|--------------|:-----:|
| **Arbind** | Features Fully Scoped | 5/mo | Asana / GitHub | 5 |
| **Mateus** | BizSup Completed | 10/mo | Asana | 5 |
| **Anderson** | PRDs Generated | 3/mo | Asana / Notion | 5 |
| **Anderson** | FSDs Generated | 2/mo | Asana / Notion | 5 |
| **Lucas** | Feature Releases | TBD | GitHub | 5 |

The Engineering tab will be empty in Phase 1. Consider a placeholder card with a "Coming in Phase 5" message.

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

## Immediate Actions by Batch

### Batch A - Start Now
- [ ] Wire up approved queries to dashboard UI
- [ ] Add traffic light indicators for all Batch A metrics
- [ ] Integration smoke tests for each query

### Batch B - Unblock via Review
- [ ] Deuce approve Supply NRR calculation
- [ ] Deuce approve Time to Fulfill calculation

### Batch C - Build Queries
- [ ] Build Contract Spend % query (Char Short)
- [ ] Build Time to Fulfill person-level query (Victoria)
- [ ] Build NPS Score query (Claire)

### Batch D - Resolve Blockers
- [ ] Define "sellable" inventory criteria (PRD needed)

### General
- [ ] Verify metric definitions with Danny (Pipeline Coverage definition)
- [ ] Verify metric definitions with Ian (New Unique Inventory)

---

## Acceptance Criteria

Phase 1 is **done** when:

- [ ] All 7 Company Health cards display live data on the dashboard
- [ ] Each BQ-based primary person metric (~13) has a working query
- [ ] All formulas have been reviewed and approved by Deuce
- [ ] Traffic light indicators (green/yellow/red) work for all metrics with targets
- [ ] Tab-based access control restricts views by role
- [ ] Data refreshes daily (overnight batch)
- [ ] Targets are stored in `dashboard/data/targets.json` (not hardcoded in queries)
- [ ] Engineering tab shows "Coming in Phase 5" placeholder

---

## Estimated Query Count

| Category | Unique Queries | Display Cards |
|----------|:--------------:|:-------------:|
| Company Health | 7 | 7 |
| Person PRIMARY (BQ-based) | ~11 | ~13 (some reuse Pipeline Coverage) |
| **Phase 1 Total** | **~18** | **~20** |

---

## Key Technical Notes

- Pipeline Coverage uses `hs_forecast_amount` (sales rep confidence), NOT stage probability
- `customer_development` view has multiple rows per customer - must use `COUNT(DISTINCT customer_id)`
- NRR dashboard key is `nrr` but BigQuery returns `demand_nrr` - mapping needed
- Supply AM NRR has two query versions: offer-based and financial-based (financial is recommended)
- Engineering metrics require Phase 5 APIs (Asana, GitHub, Notion) - not BQ-queryable

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

# Phase 3: Deep Dive / Drill-Downs

> **Status:** Not Started
> **Goal:** Click-through details for Phase 1/2 metrics + deeper COO/Supply/Sales analysis
> **Estimated Unique Queries:** ~15
> **Dependencies:** Phase 1 and Phase 2 (metrics must exist before drill-downs make sense)

---

## Scope Summary

Phase 3 adds interactive drill-down capability to the dashboard. When a user clicks on a Phase 1 or Phase 2 metric card, they see detailed breakdowns. This phase also includes COO deeper-analysis metrics, Supply team HubSpot-based metrics, and the AI Deal Scoring framework (blocked on model development).

This phase answers: "A metric is yellow/red -- WHY? Show me the details."

---

## Batch Structure

| Batch | Description | Items | Blocked? |
|-------|-------------|:-----:|:--------:|
| **A** | Drill-Down Views (data already available) | 14 | No |
| **B** | COO Extended Metrics (need query development) | 4 | No |
| **C** | Supply Phase 3 Metrics (HubSpot-based) | 5 | No |
| **D** | AI Deal Scoring (need ML model) | 3 | Yes |

---

## Batch A: Drill-Down Views (Data Already Available)

Drill-downs where the parent metric already exists in Phase 1 or Phase 2 and the data source uses the same BigQuery tables/views. This is the largest batch and can begin immediately.

### Revenue Drill-Downs

Parent metric: **Revenue YTD** (Phase 1, Company Health #1)

| # | Drill-Down | Parent Metric | Data Shown | Data Source | Status |
|---|-----------|--------------|------------|-------------|:------:|
| 1 | **Revenue by Customer** | Revenue YTD | Revenue ranked by customer, % of total | BigQuery (QBO invoice) | Build |
| 2 | **Revenue by Month** | Revenue YTD | Monthly revenue trend vs target | BigQuery (QBO invoice) | Build |
| 3 | **Revenue by Segment** | Revenue YTD | Revenue by industry/event type | BigQuery | Build |

### Pipeline Drill-Downs

Parent metric: **Pipeline Coverage** (Phase 1, Company Health #5)

| # | Drill-Down | Parent Metric | Data Shown | Data Source | Status |
|---|-----------|--------------|------------|-------------|:------:|
| 4 | **Pipeline by Rep by Stage** | Pipeline Coverage | Deal count and $ per stage per rep | HubSpot `deal` + `deal_pipeline_stage` | Build |
| 5 | **Pipeline by Close Date** | Pipeline Coverage | Deals grouped by expected close week/month | HubSpot `deal` | Build |
| 6 | **Deal Detail List** | Pipeline Coverage | Table of all open deals with key fields | HubSpot `deal` | Build |

### NRR Drill-Downs

Parent metric: **Demand NRR** (Phase 1, Company Health #3) and **Churned Customers** (Phase 2, Company Health #11)

| # | Drill-Down | Parent Metric | Data Shown | Data Source | Status |
|---|-----------|--------------|------------|-------------|:------:|
| 7 | **NRR by Segment** | Demand NRR | NRR broken out by customer segment | `cohort_retention_matrix_by_customer` | Build |
| 8 | **NRR by Customer** | Demand NRR | Individual customer expansion/contraction | `net_revenue_retention_all_customers` | Build |
| 9 | **Churned Customer List** | Churned Customers | Table of churned customers with last revenue | `customer_development` | Build |

### Contract & Fulfillment Drill-Downs

Parent metrics: **Contract Spend %** (Phase 1, Demand AM - Char), **Time to Fulfill** (Phase 1, Company Health #7), **Total Unspent Contract $** (Phase 2, COO)

| # | Drill-Down | Parent Metric | Data Shown | Data Source | Status |
|---|-----------|--------------|------------|-------------|:------:|
| 10 | **Contract Spend by Customer** | Contract Spend % | Spend vs contract value per customer | `Upfront_Contract_Spend_Query` | Build |
| 11 | **Time to Fulfill by Contract** | Time to Fulfill | Individual contract fulfillment times | `Days_to_Fulfill_Contract_Spend_From_Close_Date` | Build |
| 12 | **Contract Health Distribution** | Total Unspent Contract $ | On-track / at-risk / overdue contracts | `HS_QBO_GMV_Waterfall` (existing view) | Ready |

### Supply Drill-Downs

Parent metrics: **New Unique Inventory** (Phase 1, Supply - Ian Hong), **Sellable Inventory** (Phase 1, Company Health #6 - blocked on PRD)

| # | Drill-Down | Parent Metric | Data Shown | Data Source | Status |
|---|-----------|--------------|------------|-------------|:------:|
| 13 | **Supply Onboarding Funnel** | New Unique Inventory | Detailed funnel with time-in-stage | HubSpot `deal` (supply pipeline) | Build |
| 14 | **Inventory by Event Type** | Sellable Inventory | Breakdown by event type (university, fitness, etc.) | BigQuery (mongodb) | Build |

> **Note:** Item 14 is dependent on the Sellable Inventory PRD being completed (currently blocked in Phase 1).

---

## Batch B: COO Extended Metrics

These are COO-level metrics that extend Phase 2 with deeper analysis. They require new query development.

| # | Metric | Target | Formula | Query File | Status |
|---|--------|:------:|---------|------------|:------:|
| 15 | **Top Customer % Revenue** | <30% | Individual customer revenue percentages | `queries/coo-ops/top-customer-concentration.sql` | Query Created |
| 16 | **Operating Expenses vs Budget** | - | `Actual OpEx / Budgeted OpEx` by category | - | Build |
| 17 | **Bill Payment Timeliness** | 95% | `Bills paid on time / Total bills x 100` | - | Build |
| 18 | **Current Assets** | - | Asset breakdown (derivable from working-capital.sql) | `queries/coo-ops/working-capital.sql` | Build |

**Parent metric references:**
- Item 15 drills into **Customer Concentration** (Phase 2, Company Health #9)
- Item 16 is a new COO metric (no direct Phase 1/2 parent -- standalone deeper analysis)
- Item 17 is a new COO metric (standalone deeper analysis)
- Item 18 drills into **Working Capital** (Phase 2, COO)

---

## Batch C: Supply Phase 3 Metrics

HubSpot-based metrics for the Supply team. These come from HubSpot dashboard data already synced to BigQuery.

| # | Metric | Formula | Data Source | Status |
|---|--------|---------|-------------|:------:|
| 22 | **Onboarded in last 7 days** | Count where `date_converted_onboarded` in last 7 days | HubSpot Dashboard (BQ) | Build |
| 23 | **Onboarding (days in stage)** | AVG days in onboarding stage | HubSpot Dashboard (BQ) | Build |
| 24 | **Upcoming Meetings next 7 days** | Count of meetings in next 7 days | HubSpot Dashboard (BQ) | Build |
| 25 | **Meetings held in last 7 days** | Count of meetings in last 7 days | HubSpot Dashboard (BQ) | Build |
| 26 | **Contacts >14 days Supply Target** | Count of contacts stuck in Supply Target >14 days | HubSpot Dashboard (BQ) | Build |

**Parent metric references:**
- Items 22-23 extend **New Unique Inventory** (Phase 1, Supply) and **Supply Funnel** (Phase 2, Supply)
- Items 24-25 extend **Meetings Booked MTD** (Phase 2, Supply)
- Item 26 extends **Weekly Contact Attempts** (Phase 2, Supply)

---

## Batch D: AI Deal Scoring (Blocked)

Hot/Warm/Cold deals require an ML model that does not exist yet. This batch is blocked until the AI Deal Scoring model is built.

| # | Metric | Formula | Data Source | Status |
|---|--------|---------|-------------|:------:|
| 19 | **Hot Deals # / $** | AI-scored deals with high probability | AI Deal Scoring model | Blocked |
| 20 | **Warm Deals # / $** | AI-scored deals with medium probability | AI Deal Scoring model | Blocked |
| 21 | **Cold Deals # / $** | AI-scored deals with low probability | AI Deal Scoring model | Blocked |

**Blocker:** The AI Deal Scoring model must be designed, trained, and deployed before these metrics can be implemented. No query or data source exists today.

---

## Dependencies on Other Phases

| Dependency | Phase | Impact | Batch Affected |
|------------|:-----:|--------|:--------------:|
| Company Health cards live | 1 | Drill-downs link from Phase 1 cards | A |
| Secondary metrics live | 2 | Some drill-downs extend Phase 2 metrics | A |
| Sellable Inventory PRD | 1 (blocked) | Inventory by Event Type drill-down blocked until definition exists | A (#14) |
| AI Deal Scoring model | Future | Hot/Warm/Cold deals require ML model | D |

---

## Acceptance Criteria

Phase 3 is **done** when:

**Batch A:**
- [ ] Clicking any Phase 1/2 metric card opens a drill-down view
- [ ] Revenue drill-down shows by-customer, by-month, and by-segment breakdowns
- [ ] Pipeline drill-down shows by-rep-by-stage detail and deal list
- [ ] NRR drill-down shows by-segment and by-customer detail
- [ ] Contract drill-down shows individual contract health
- [ ] Supply onboarding funnel shows time-in-stage analysis
- [ ] Back-navigation returns to parent metric view

**Batch B:**
- [ ] COO extended metrics (OpEx, Bill Timeliness, Current Assets) are live
- [ ] Top Customer % Revenue shows individual customer breakdown

**Batch C:**
- [ ] All 5 Supply HubSpot metrics are live and pulling from BQ
- [ ] Onboarding days-in-stage calculation is accurate

**Batch D:**
- [ ] AI Deal Scoring model exists and is deployed
- [ ] Hot/Warm/Cold deal counts and dollar values display correctly

**All Batches:**
- [ ] All drill-down queries perform within 5 seconds

---

## Estimated Query Count

| Category | Batch | Unique Queries | Drill-Down Views |
|----------|:-----:|:--------------:|:----------------:|
| Revenue Drill-Downs | A | 3 | 3 |
| Pipeline Drill-Downs | A | 3 | 3 |
| NRR Drill-Downs | A | 3 | 3 |
| Contract Drill-Downs | A | 3 | 3 |
| Supply Drill-Downs | A | 2 | 2 |
| COO Phase 3 | B | 3 | 3 |
| Supply Phase 3 | C | 5 | 5 |
| Sales AI Scoring | D | 1 (3 views) | 3 |
| **Phase 3 Total** | | **~15 new** | **~25** |

---

## Integration Testing

After implementing a BQ function, follow this standard pattern:
1. Unit test (mock BQ client)
2. Integration smoke test (real BQ, `pytest -m integration`)
3. Enriched tooltip with 5 static fields
4. Add metric target to `targets.json` via Settings tab

**This phase: 2 integration smoke tests**

Run: `cd dashboard && pytest -m integration`

## Tooltip Enrichment

Each metric gets a 5-section tooltip:
- Definition (plain English)
- Why It Matters (business impact)
- Calculation (formula in monospace)
- Target pill (from `targets.json` via Settings tab)
- 2025 Benchmark pill (from `METRIC_DEFINITIONS`, where meaningful)
- Edge Cases (amber callout, when applicable)

**This phase: 0 tooltips to enrich**

## Settings Tab Targets

New metric targets added to the Settings tab's "Metric Targets" form and saved to `targets.json`:

**This phase: 0 new metric targets**

Standard pattern: "After implementing a BQ function: (1) unit test, (2) integration smoke test, (3) enriched tooltip with 5 static fields, (4) add metric target to targets.json via Settings tab"

# Phase 2: Secondary Metrics + CFO Dashboard

> **Status:** Not Started
> **Goal:** Add secondary metrics and critical CFO visibility
> **Estimated Unique Queries:** ~25
> **Dependencies:** Phase 1 (Company Health + Primary metrics must be live)

---

## Scope Summary

Phase 2 expands the dashboard with:

1. **CFO-specific metrics** (Runway, Working Capital, Factoring, Overdue) - HIGH priority
2. **Company Health secondary cards** (Logo Retention, Concentration, Active/Churned Customers)
3. **Department secondary metrics** across Sales, Supply, Marketing, Accounting, AM, and COO teams

This phase answers: "Beyond the #1 metric, what else does each department need to monitor daily?"

**Phase 2 scope is strictly BQ-based metrics.** The following metrics are NOT in Phase 2 scope -- they require external API integrations and are handled in Phase 4: Cash Position (SimpleFin), Lead Queue Runway (Smart Lead), Cost per MQL (ad spend data), Bills Pending Approval (Bill.com), Vendors Not Onboarded (Bill.com), Avg Ticket Response Time (Zendesk/Intercom), Open Tickets (Zendesk/Intercom). Website Traffic (GA4) and Email Open Rate (HubSpot Email API) are Phase 5.

---

## Batch Structure

### Batch A: Ready to Implement (Query Exists + Data Source Confirmed)

Metrics where the SQL query already exists and data flows through BigQuery. Prioritize CFO metrics (HIGH priority).

### Batch B: Needs Query Development (Data Source Clear)

Metrics where we know the BQ data source but need to write or adapt the query.

### Batch C: Needs Definition / Formula Review

Metrics needing business definition or formula approval from Deuce.

---

## CFO Dashboard Metrics (HIGH Priority)

> **Query directory:** `queries/coo-ops/`
> **Shared with:** CEO/Biz Dev (Jack) dashboard
> **Note:** Targets stored in `dashboard/data/targets.json` - queries should NOT hardcode targets

### Batch A (Query Exists)

| # | Metric | Owner | Formula | Target | Query File | Approval Status |
|---|--------|-------|---------|:------:|------------|:---------------:|
| 1 | **Working Capital** | Deuce | `Current Assets - Current Liabilities` | >$1M | `queries/coo-ops/working-capital.sql` | Needs Review |
| 2 | **Months of Runway** | Deuce | `Cash Balance / Avg Monthly Burn (3mo)` | >12 mo | `queries/coo-ops/months-of-runway.sql` | Needs Review |
| 3 | **Customer Concentration** | Deuce | `Top Customer Revenue / Total Revenue x 100` | <30% | `queries/coo-ops/top-customer-concentration.sql` | Needs Review |
| 4 | **Net Revenue Gap** | Deuce | `Unspent Contracts - (Target - YTD Revenue)` | Reporting | `queries/coo-ops/net-revenue-gap.sql` | Needs Review |
| 5 | **Factoring Capacity** | Deuce | `Eligible AR x 85%` (invoices <90 days) | >$400K | `queries/coo-ops/factoring-capacity.sql` | Needs Review |
| 6 | **Overdue Invoices** | Deuce | `Count & $ where balance > 0 AND due_date < today` | 0 | `queries/coo-ops/overdue-invoices.sql` | Needs Review |
| 7 | **Total Unspent Contract $** | Deuce | From GMV Waterfall | - | `HS_QBO_GMV_Waterfall` (existing view) | Ready |

**CFO Metrics Status:** 7 metrics, queries exist for all, 0/7 formally approved

---

## Company Health Secondary Cards (4)

### Batch B (Needs Query from Existing Views)

| # | Metric | Owner | Formula | Target | Data Source | Approval Status |
|---|--------|-------|---------|:------:|-------------|:---------------:|
| 8 | **Logo Retention** | ? | `Returning Customers / Prior Period Customers x 100` | 50% | `customer_development` (BQ view) | Needs Review |
| 9 | **Customer Concentration** | ? | `Top Customer Rev / Total Rev x 100` | <30% | `net_revenue_retention_all_customers` (BQ view) | Needs Review |
| 10 | **Active Customers** | ? | Count of customers with revenue in period | TBD | `customer_development` (BQ view) | Needs Review |
| 11 | **Churned Customers** | ? | Count of customers with no revenue in current period vs prior | TBD | `customer_development` (BQ view) | Needs Review |

**WARNING:** Logo Retention at 37% is a RED FLAG. Verify calculation before alarming the business.

---

## CEO/Biz Dev Secondary Metrics (Jack)

### Batch A (Query Exists / Shared)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 1 | Pipeline Coverage | 6.0x | Shared with Sales | `demand-sales/pipeline-coverage-by-rep.sql` | Query Created |
| 2 | Customer Concentration | <30% | Shared with COO | `coo-ops/top-customer-concentration.sql` | Query Created |
| 3 | Working Capital | >$1M | Shared with COO | `coo-ops/working-capital.sql` | Query Created |
| 4 | Months of Runway | >12 mo | Shared with COO | `coo-ops/months-of-runway.sql` | Query Created |
| 5 | Pipeline Coverage (3 methods) | - | Unweighted, HubSpot, AI Weighted | BigQuery views | Ready |
| 6 | Total Unspent Contract $ | - | From GMV Waterfall | `HS_QBO_GMV_Waterfall` | Ready |

### Batch C (Needs Verification)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 7 | New Target Accounts | TBD | Count of new target accounts created | - | Verify (needs HubSpot property check) |

---

## Sales Secondary Metrics (Andy, Danny, Katie)

> **Query directory:** `queries/demand-sales/`

### Batch A (All Queries Exist)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 1 | Meetings Booked (QTD) vs Goal | 45/mo | Count of meetings this quarter | `meetings-booked-qtd.sql` | Query Created |
| 2 | Companies >7 Days Not Contacted | 0 | Deals with no activity in 7+ days | `companies-not-contacted-7d.sql` | Query Created |
| 3 | Weighted Pipeline | $4.5M | Sum of `hs_forecast_amount` | `pipeline-coverage-by-rep.sql` | Query Created |
| 4 | Win Rate (90 days) | 30% | `Closed Won / (Won + Lost) x 100` | `win-rate-90-days.sql` | Query Created |
| 5 | Avg Deal Size (YTD) | $150K | `Total Won $ / Won Count` | `avg-deal-size-ytd.sql` | Query Created |
| 6 | Sales Cycle Length | <=60 days | `AVG(closedate - createdate)` for won deals | `sales-cycle-length.sql` | Query Created |
| 7 | Deals by Stage (Funnel) | See targets | Count per stage vs monthly target | `deals-by-stage-funnel.sql` | Query Created |
| 8 | Deals Closing Soon | - | Deals with closedate in next 7/30/60 days | `deals-closing-soon.sql` | Query Created |
| 9 | Expired Open Deals | 0 | Open deals where closedate < today | `expired-open-deals.sql` | Query Created |

**Monthly Funnel Targets:**

| Stage | Monthly Target |
|-------|:--------------:|
| Meeting Booked | 45 |
| Sales Qualified Lead | 36 |
| Opportunity | 23 |
| Proposal Sent | 22 |
| Active Negotiation | 15 |
| Contract Sent | 9 |
| Closed Won | 7 deals / $500K |

---

## Supply Secondary Metrics (Ian Hong)

> **Query directory:** `queries/supply/`

### Batch A (All Queries Exist)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 1 | Weekly Contact Attempts | 600/week | Count of engagements on Supply Target contacts | `weekly-contact-attempts.sql` | Query Created |
| 2 | Meetings Booked (MTD) | 24/month | Count where `date_converted_meeting_booked` this month | `meetings-booked-mtd.sql` | Query Created |
| 3 | Pipeline Coverage by Event Type | 3x | `Open Pipeline / (Goal - Won)` per event type | `pipeline-coverage-by-event-type.sql` | Query Created |
| 4 | Supply Funnel | See targets | Deals per stage vs monthly target | `supply-funnel.sql` | Query Created |
| 5 | Listings Published per Month | - | Count of published listings | `listings-published-per-month.sql` | Query Created |

**Supply Funnel Targets:**

| Stage | Monthly Target |
|-------|:--------------:|
| Attempted to Contact | 60 |
| Connected | 60 |
| Meeting Booked | 24 |
| Proposal Sent | 16 |
| Onboarded | 16 |
| Won (target accounts) | 4 |

---

## Marketing Secondary Metrics

> **Query directory:** `queries/marketing/`

### Batch A (Query Exists)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 1 | ML -> MQL -> SQL Funnel | - | Counts and conversion at each stage | `marketing-leads-funnel.sql` | Query Created |
| 2 | MQL -> SQL Conversion | 30% | `SQLs / MQLs x 100` | `mql-to-sql-conversion.sql` | Query Created |
| 3 | First Touch Attribution $ | - | Revenue attributed by first touch channel | `attribution-by-channel.sql` | Query Created |
| 4 | Last Touch Attribution $ | - | Revenue attributed by last touch channel | `attribution-by-channel.sql` | Query Created |
| 5 | Marketing Leads | - | Count of marketing leads | `marketing-leads-funnel.sql` | Query Created |

### Batch B (Needs Query Development)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 6 | Marketing-Sourced Revenue % | - | `Marketing-attributed Rev / Total Rev x 100` | - | Build |

---

## Accounting Secondary Metrics

> **Query directory:** `queries/accounting/` (to be created)

### Batch A (Query Exists)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 1 | Invoice Variance (Count & $) | $0 | QBO vs internal reconciliation | Reconciliation query #4 | Ready |
| 2 | Bill Variance (Count & $) | $0 | QBO vs internal reconciliation | Reconciliation query | Ready |

### Batch B (Needs Query Development)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 3 | Invoices Paid Within 7 Days % | - | `Invoices paid <=7 days / Total x 100` | - | Build |
| 4 | Overdue Invoices Count & $ | 0 | `Count & sum where balance > 0 AND past due` | - | Build |
| 5 | Average Days to Collection | <7 days | `AVG(payment_date - invoice_date)` | - | Build |
| 6 | Bills Overdue by Status | 0 | Count of overdue bills by status | - | Build |
| 7 | Available Factoring Capacity | >$400K | `Eligible AR x 85%` | - | Build |

---

## Demand AM Secondary Metrics

### Batch A (Query Exists)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 1 | Upsell Pipeline | - | Filter HubSpot deals by upsell type | HubSpot deal type filter | Ready |

### Batch C (Needs Definition)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 2 | Customer Health Score | - | Composite of spend, engagement, NPS | - | Define |

---

## Supply AM Secondary Metrics (Ashton)

### Batch B (Needs Query Development)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 1 | Top Partner Retention Rate | 90% | `Retained Partners / Prior Partners x 100` | - | Build |
| 2 | Avg Revenue per Partner | - | `Total Revenue / Active Partner Count` | - | Build |

### Batch C (Needs Definition)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 3 | Partner Satisfaction Score | 4.5/5 | Survey average | - | Define (manual) |

---

## COO Phase 2 Metrics (Deuce)

### Batch A (All Queries Exist)

| # | Metric | Target | Formula | Query File | Approval Status |
|---|--------|:------:|---------|------------|:---------------:|
| 1 | Net Revenue Gap | - | `Unspent Contracts - (Target - YTD Revenue)` | `queries/coo-ops/net-revenue-gap.sql` | Query Created |
| 2 | Available Factoring Capacity | >$400K | `Eligible AR x 85%` | `queries/coo-ops/factoring-capacity.sql` | Query Created |
| 3 | Overdue Invoices Count & $ | 0 | `Count & $ where past due` | `queries/coo-ops/overdue-invoices.sql` | Query Created |
| 4 | Total Unspent Contract $ | - | From GMV Waterfall | `HS_QBO_GMV_Waterfall` (existing view) | Ready |

---

## Batch Summary

| Batch | Description | Metric Count | Priority |
|-------|-------------|:------------:|:--------:|
| **A** | Ready to Implement (query exists + data confirmed) | ~38 | HIGH |
| **B** | Needs Query Development (data source clear) | ~10 | MED |
| **C** | Needs Definition / Formula Review | ~3 | LOW |
| **Total** | | **~51** | |

### Batch A Breakdown (Implement First)

| Department | Batch A Metrics |
|------------|:---------------:|
| CFO Dashboard | 7 |
| CEO/Biz Dev | 6 |
| Sales | 9 |
| Supply | 5 |
| Marketing | 5 |
| Accounting | 2 |
| Demand AM | 1 |
| COO | 4 |
| **Total Batch A** | **39** |

### Batch B Breakdown (Build Queries)

| Department | Batch B Metrics |
|------------|:---------------:|
| Company Health Secondary | 4 |
| Marketing | 1 |
| Accounting | 5 |
| Supply AM | 2 |
| **Total Batch B** | **12** |

### Batch C Breakdown (Define First)

| Department | Batch C Metrics |
|------------|:---------------:|
| CEO/Biz Dev | 1 |
| Demand AM | 1 |
| Supply AM | 1 |
| **Total Batch C** | **3** |

---

## Dependencies

| Dependency | Phase | Impact |
|------------|:-----:|--------|
| Phase 1 Company Health cards live | 1 | Secondary cards extend the Company Health view |
| Phase 1 Primary metrics approved | 1 | Some secondary metrics build on primary calculations |

**Out of scope for Phase 2:** The following metrics require external API integrations and are handled in later phases:
- **Phase 4:** Cash Position (SimpleFin), Lead Queue Runway (Smart Lead), Cost per MQL (ad spend data), Bills Pending Approval (Bill.com), Vendors Not Onboarded (Bill.com), Avg Ticket Response Time (Zendesk/Intercom), Open Tickets (Zendesk/Intercom)
- **Phase 5:** Website Traffic (GA4 API), Email Open Rate (HubSpot Email API)

---

## Acceptance Criteria

Phase 2 is **done** when:

- [ ] All CFO metrics (Working Capital, Runway, Concentration, Net Revenue Gap, Factoring, Overdue, Unspent Contract $) display live data
- [ ] Company Health secondary cards (Logo Retention, Concentration, Active Customers, Churned) are live
- [ ] All Sales secondary metrics (9 metrics) display on Sales tab
- [ ] Supply secondary metrics (5 metrics) display on Supply tab
- [ ] Marketing secondary metrics (at least 5 of 6) display on Marketing tab
- [ ] Accounting secondary metrics (at least 5 of 7) display on Accounting tab
- [ ] Demand AM and Supply AM secondary metrics are live
- [ ] CEO dashboard shows shared COO/CFO metrics
- [ ] COO dashboard shows Net Revenue Gap, Factoring, Overdue, Unspent Contract $
- [ ] All formulas reviewed and approved
- [ ] Traffic light indicators working for all metrics with targets

---

## Estimated Query Count

| Category | Unique Queries | Display Cards |
|----------|:--------------:|:-------------:|
| CFO Dashboard | 7 (most exist) | 7 |
| Company Health Secondary | 4 (use existing views) | 4 |
| Sales Secondary | 9 (all exist) | ~18 (per-rep views) |
| Supply Secondary | 5 (all exist) | 5 |
| Marketing Secondary | 5-6 | 6 |
| Accounting Secondary | 5-7 | 7 |
| AM Secondary | 3-5 | 5 |
| COO Secondary | 4 (all exist, shared) | 4 |
| **Phase 2 Total** | **~25 new** | **~56** |

---

## Integration Testing

After implementing a BQ function, follow this standard pattern:
1. Unit test (mock BQ client)
2. Integration smoke test (real BQ, `pytest -m integration`)
3. Enriched tooltip with 5 static fields
4. Add metric target to `targets.json` via Settings tab

**This phase: 13 integration smoke tests**

Run: `cd dashboard && pytest -m integration`

## Tooltip Enrichment

Each metric gets a 5-section tooltip:
- Definition (plain English)
- Why It Matters (business impact)
- Calculation (formula in monospace)
- Target pill (from `targets.json` via Settings tab)
- 2025 Benchmark pill (from `METRIC_DEFINITIONS`, where meaningful)
- Edge Cases (amber callout, when applicable)

**This phase: 18 tooltips to enrich**

## Settings Tab Targets

New metric targets added to the Settings tab's "Metric Targets" form and saved to `targets.json`:

**This phase: 7 new metric targets**

Standard pattern: "After implementing a BQ function: (1) unit test, (2) integration smoke test, (3) enriched tooltip with 5 static fields, (4) add metric target to targets.json via Settings tab"

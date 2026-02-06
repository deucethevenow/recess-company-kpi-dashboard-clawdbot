# UI Design Spec - Recess KPI Dashboard

> **Created:** 2026-02-05
> **Author:** ui-designer agent
> **Purpose:** Define layout, components, and data sources for every dashboard page
> **Component Library:** Existing Streamlit + custom HTML/CSS from `app.py`

---

## Table of Contents

1. [Component Reference](#component-reference)
2. [Shared Metrics Registry](#shared-metrics-registry)
3. [Page Designs](#page-designs)
   - [1. Overview](#1-overview-page)
   - [2. CEO / Biz Dev](#2-ceo--biz-dev-page)
   - [3. COO / Ops](#3-coo--ops-page)
   - [4. Supply](#4-supply-page)
   - [5. Supply AM](#5-supply-am-page)
   - [6. Demand Sales](#6-demand-sales-page)
   - [7. Demand AM](#7-demand-am-page)
   - [8. Marketing](#8-marketing-page)
   - [9. Accounting](#9-accounting-page)
   - [10. Engineering](#10-engineering-page)

---

## Component Reference

These components already exist in `app.py` CSS/HTML. All new pages should reuse them.

| Component | CSS Class | Usage | Streamlit Pattern |
|-----------|-----------|-------|-------------------|
| **North Star Card** | `.north-star-card` | Full-width hero metric with progress bar | `st.markdown(html, unsafe_allow_html=True)` |
| **Metric Card** | `.metric-card` | Individual KPI in a grid cell | `st.columns(N)` + `st.markdown()` per cell |
| **Section Header** | `.section-header` | Section dividers with cyan accent bar | `st.markdown()` |
| **Team Table** | `.team-table`, `.team-row` | Person-level breakdown with 5-col grid | `st.markdown()` full table HTML |
| **Capacity Table** | `.capacity-table`, `.capacity-row` | Tabular data with progress bars | `st.markdown()` full table HTML |
| **Dept Summary** | `.dept-summary` | Cyan-bordered info callout at page top | `st.markdown()` |
| **Status Badge** | `.status-badge` | On Track / At Risk / Off Track pill | Inline in cards |
| **Chart Container** | `.chart-container` | White card wrapper for Plotly charts | `st.plotly_chart()` |
| **Live Badge** | `.metric-live-badge` | Data verification status on cards | Inline in cards |

### Layout Grid Rules

- **Metric cards:** Use `st.columns(4)` for 4-across on desktop (auto-wraps to 2-col on mobile via CSS)
- **Charts:** Full-width via `st.plotly_chart(fig, use_container_width=True)`
- **Tables:** Full-width HTML blocks
- **Two-panel layouts:** Use `st.columns([2, 1])` or `st.columns([1, 1])` for side-by-side

### Color Constants

| Purpose | Variable | Value |
|---------|----------|-------|
| Primary brand | `--recess-cyan` | `#13bad5` |
| Secondary brand | `--recess-orange` | `#ff8900` |
| Success | `--success` | `#10b981` |
| Warning | `--warning` | `#f59e0b` |
| Danger | `--danger` | `#ef4444` |
| Chart colors | - | `#13bad5`, `#ff8900`, `#10b981`, `#8b5cf6`, `#f59e0b` |

---

## Shared Metrics Registry

These metrics appear on multiple pages. **Build the query/component once, display on many tabs.**

| Metric | Component ID | Source Query | Pages Using It |
|--------|-------------|-------------|----------------|
| Revenue YTD | `revenue-ytd` | BigQuery view (existing) | Overview, CEO |
| Pipeline Coverage | `pipeline-coverage` | `demand-sales/pipeline-coverage-by-rep.sql` | Overview, CEO, Demand Sales |
| Take Rate % | `take-rate` | `coo-ops/take-rate.sql` | Overview, COO |
| NRR (Demand) | `demand-nrr` | `cohort_retention_matrix_by_customer` view | Overview, Demand Sales |
| NRR (Supply) | `supply-nrr` | `Supplier_Metrics` view | Overview, Supply AM |
| Invoice Collection % | `invoice-collection` | `coo-ops/invoice-collection-rate.sql` | COO, Accounting |
| Overdue Invoices | `overdue-invoices` | `coo-ops/overdue-invoices.sql` | COO, Accounting |
| Working Capital | `working-capital` | `coo-ops/working-capital.sql` | CEO, COO |
| Months of Runway | `runway` | `coo-ops/months-of-runway.sql` | CEO, COO |
| Customer Concentration | `concentration` | `coo-ops/top-customer-concentration.sql` | CEO, COO, Overview |
| Time to Fulfill | `time-to-fulfill` | `Days_to_Fulfill_Contract_Spend` view | Overview, Demand AM |
| Contract Spend % | `contract-spend` | `Upfront_Contract_Spend_Query` view | COO, Demand AM |
| Factoring Capacity | `factoring-capacity` | `coo-ops/factoring-capacity.sql` | COO, Accounting |

---

## Page Designs

---

### 1. Overview Page

**Status:** Implemented (document current state + improvements)
**Owner:** All executives
**URL path:** Default landing page

#### Current State (Implemented)

```
+---------------------------------------------------------------+
| PAGE HEADER: "Company Overview"                    Feb 05, 2026|
+---------------------------------------------------------------+
| NORTH STAR CARD: Revenue YTD                                   |
| $7.93M of $10M target  · $2.07M remaining                     |
| [========================================----] 79.3%           |
+---------------------------------------------------------------+
| SECTION: Company Health                                        |
| +-------------+ +-------------+ +-------------+ +-------------+
| | Take Rate   | | Demand NRR  | | Supply NRR  | | Pipeline    |
| | 42%         | | 107%        | | 67%         | | Coverage Gap|
| | Target: 45% | | Target: 110%| | Target: 110%| | $4.2M (3.8x)|
| +-------------+ +-------------+ +-------------+ +-------------+
| +-------------+ +-------------+ +-------------+ +-------------+
| | Days to     | | Logo        | | Sellable    | | Customer    |
| | Fulfill     | | Retention   | | Inventory   | | Count       |
| | 69 days     | | 37%         | | -- (PRD)    | | 51          |
| +-------------+ +-------------+ +-------------+ +-------------+
+---------------------------------------------------------------+
| SECTION: Team Accountability                                   |
| +-----------------------------------------------------------+ |
| | Name    | Metric            | Actual | Target | Status    | |
| | Jack    | Revenue vs Target | $7.93M | $10M   | At Risk   | |
| | Deuce   | Take Rate %       | 49%    | 50%    | At Risk   | |
| | Ian     | New Unique Inv.   | 12     | 16     | At Risk   | |
| | ...     | ...               | ...    | ...    | ...       | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
```

#### Improvements Needed

1. **Add Revenue Trend Chart** - Line chart showing monthly revenue vs target (exists in CEO data, promote to overview)
2. **Add Department Health Summary** - 3x3 grid of department status badges showing each dept's primary metric status (green/yellow/red)
3. **Pipeline Coverage Gap card** - Already shows coverage ratio; add trend sparkline if data available

**Data Sources (all existing):**
- North Star: `bigquery_client.get_revenue_ytd()`
- Health Cards: `bigquery_client.get_company_metrics()`
- Team Table: `data_layer.PERSON_METRICS`

---

### 2. CEO / Biz Dev Page

**Owner:** Jack
**Primary Audience:** CEO, Board, Investors
**Nav key:** `ceo`

#### Layout

```
+---------------------------------------------------------------+
| PAGE HEADER: "CEO / Biz Dev"       Jack's Dashboard           |
+---------------------------------------------------------------+
| DEPT SUMMARY: Revenue function owner. All sales, AM, and      |
|               marketing roll up here.                          |
+---------------------------------------------------------------+
|                                                                |
| NORTH STAR CARD (cyan gradient):                               |
|   "Revenue vs Target"                                          |
|   $7.93M of $10M  · 79.3% to goal · FY2026                   |
|   [========================================----]               |
|                                                                |
+---------------------------------------------------------------+
| SECTION: Key Metrics                          [4-column grid]  |
| +-------------+ +-------------+ +-------------+ +-------------+|
| | Pipeline    | | Working     | | Months of   | | Customer    ||
| | Coverage    | | Capital     | | Runway      | | Concentra-  ||
| | 2.8x       | | $X.XM       | | XX months   | | tion        ||
| | Target: 6x | | Target: >$1M| | Target: >12 | | 41% (TOP1)  ||
| | SHARED      | | SHARED      | | SHARED      | | SHARED      ||
| +-------------+ +-------------+ +-------------+ +-------------+|
+---------------------------------------------------------------+
| SECTION: Revenue Trend                                         |
| +-----------------------------------------------------------+ |
| | LINE CHART: Revenue vs Target (Monthly, Aug-Jan)           | |
| | Cyan line = Actual, Dashed gray = Target pace              | |
| | Fill area under actual line                                 | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
| SECTION: Cash & Runway            [2-column: chart + metrics]  |
| +-----------------------------+ +-----------------------------+|
| | BAR CHART: Monthly Burn     | | Cash Position: $XXX,XXX    ||
| | Rate (3-month trailing)     | | Runway: XX months          ||
| |                              | | Working Capital: $X.XM     ||
| +-----------------------------+ +-----------------------------+|
+---------------------------------------------------------------+
```

#### Component Specifications

| Element | Component | Data Source | Notes |
|---------|-----------|------------|-------|
| **Hero: Revenue vs Target** | `north-star-card` (cyan) | `bigquery_client.get_revenue_ytd()` | SHARED with Overview |
| **Pipeline Coverage** | `metric-card` | `demand-sales/pipeline-coverage-by-rep.sql` (aggregate) | SHARED - show company-wide total |
| **Working Capital** | `metric-card` | `coo-ops/working-capital.sql` | SHARED with COO |
| **Months of Runway** | `metric-card` | `coo-ops/months-of-runway.sql` | SHARED with COO |
| **Customer Concentration** | `metric-card` | `coo-ops/top-customer-concentration.sql` | Show top customer name + % |
| **Revenue Trend** | Plotly line chart | Same data as current `DEPARTMENT_DETAILS["CEO / Biz Dev"]["chart_data"]` | Monthly actuals vs linear target |
| **Cash Position** | `metric-card` | Phase 4 - SimpleFin API | Show "Coming Soon" placeholder |

#### Status Thresholds

| Metric | On Track | At Risk | Off Track |
|--------|----------|---------|-----------|
| Revenue vs Target | >= 100% of pace | 85-99% | < 85% |
| Pipeline Coverage | >= 6.0x | 4.0-5.9x | < 4.0x |
| Working Capital | > $1M | $500K-$1M | < $500K |
| Runway | > 12 months | 6-12 months | < 6 months |
| Concentration | < 30% | 30-40% | > 40% |

---

### 3. COO / Ops Page

**Owner:** Deuce
**Primary Audience:** COO, CFO functions
**Nav key:** `coo`

#### Layout

```
+---------------------------------------------------------------+
| PAGE HEADER: "COO / Ops"          Deuce's Dashboard            |
+---------------------------------------------------------------+
| DEPT SUMMARY: Operational efficiency owner. Supply, AM,        |
|               Accounting, AI roll up here.                     |
+---------------------------------------------------------------+
|                                                                |
| NORTH STAR CARD (cyan gradient):                               |
|   "Take Rate %"                                                |
|   49% actual · 50% target · FY2026                            |
|   2025 reference: 49.3%                                        |
|   [=============================================-]             |
|                                                                |
+---------------------------------------------------------------+
| SECTION: Financial Health                     [4-column grid]  |
| +-------------+ +-------------+ +-------------+ +-------------+|
| | Invoice     | | Overdue     | | Working     | | Months of   ||
| | Collection  | | Invoices    | | Capital     | | Runway      ||
| | 93%         | | 4 ($45K)    | | $X.XM       | | XX months   ||
| | Target: 95% | | Target: 0   | | Target: >$1M| | Target: >12 ||
| | SHARED      | | SHARED      | | SHARED      | | SHARED      ||
| +-------------+ +-------------+ +-------------+ +-------------+|
+---------------------------------------------------------------+
| SECTION: Operational Metrics                  [4-column grid]  |
| +-------------+ +-------------+ +-------------+ +-------------+|
| | Customer    | | Net Revenue | | Factoring   | | Cash        ||
| | Concentra-  | | Gap         | | Capacity    | | Position    ||
| | tion (Top 1)| | $X.XM       | | $XXX,XXX    | | $XXX,XXX   ||
| | 41%         | | Reporting   | | Target:>$400K| | Phase 4    ||
| | SHARED      | |             | | SHARED      | |            ||
| +-------------+ +-------------+ +-------------+ +-------------+|
+---------------------------------------------------------------+
| SECTION: Department Roll-up Health                             |
| +-----------------------------------------------------------+ |
| | Dept        | Primary Metric   | Actual | Target | Status  | |
| | Supply      | New Unique Inv.  | 12     | 16     | At Risk | |
| | Supply AM   | NRR Top Supply   | 95%    | 110%   | Off Trk | |
| | Demand AM   | Contract Spend   | 89%    | 95%    | At Risk | |
| | Accounting  | Invoice Coll.    | 93%    | 95%    | At Risk | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
```

#### Component Specifications

| Element | Component | Data Source | Notes |
|---------|-----------|------------|-------|
| **Hero: Take Rate %** | `north-star-card` (cyan) | `coo-ops/take-rate.sql` | SHARED with Overview |
| **Invoice Collection** | `metric-card` | `coo-ops/invoice-collection-rate.sql` | SHARED with Accounting |
| **Overdue Invoices** | `metric-card` | `coo-ops/overdue-invoices.sql` | Show count AND dollar amount |
| **Working Capital** | `metric-card` | `coo-ops/working-capital.sql` | SHARED with CEO |
| **Months of Runway** | `metric-card` | `coo-ops/months-of-runway.sql` | SHARED with CEO |
| **Customer Concentration** | `metric-card` | `coo-ops/top-customer-concentration.sql` | SHARED with CEO |
| **Net Revenue Gap** | `metric-card` | `coo-ops/net-revenue-gap.sql` | Unspent contracts vs target gap |
| **Factoring Capacity** | `metric-card` | `coo-ops/factoring-capacity.sql` | SHARED with Accounting |
| **Cash Position** | `metric-card` | Phase 4 - SimpleFin | Placeholder |
| **Dept Roll-up Table** | `team-table` | Filter `PERSON_METRICS` by COO direct reports | Show deps that roll up to COO |

---

### 4. Supply Page

**Status:** Partially implemented (capacity data live, need additions)
**Owner:** Ian Hong
**Nav key:** `supply`

#### Current State (Implemented)

The Supply page already has:
- North star card: Q1 New Unique Inventory Goal (orange gradient)
- 4 metric cards: Total Yearly Capacity, Active Event Types, Contacts/Week, MoM Growth
- Capacity by Event Type table with progress bars
- Capacity Growth Trend chart (line)
- Weekly Contact Attempts chart (bar + target line)
- YTD contact statistics (3 cards)

#### Additions Needed

```
+---------------------------------------------------------------+
| (EXISTING) North Star: Q1 New Unique Inventory Goal            |
| (EXISTING) Supply Metrics: 4 cards                             |
+---------------------------------------------------------------+
| NEW SECTION: Meetings & Pipeline              [4-column grid]  |
| +-------------+ +-------------+ +-------------+ +-------------+|
| | Meetings    | | Pipeline    | | Supply      | | Listings    ||
| | Booked MTD  | | by Type     | | Funnel Conv.| | Published   ||
| | 18          | | See table   | | See funnel  | | XX/month    ||
| | Target: 24  | | 3x target   | |             | |             ||
| +-------------+ +-------------+ +-------------+ +-------------+|
+---------------------------------------------------------------+
| NEW SECTION: Pipeline by Event Type                            |
| +-----------------------------------------------------------+ |
| | CAPACITY TABLE: Event Type | Open $ | Goal $ | Cov. | Bar | |
| | Student Involvement        | $XXX   | $400K  | 2.1x | === | |
| | Youth Sports               | $XXX   | $200K  | 1.8x | ==  | |
| | Family Events              | $XXX   | $250K  | 3.2x | ====| |
| | ...                        |        |        |      |     | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
| NEW SECTION: Supply Funnel                                     |
| +-----------------------------------------------------------+ |
| | FUNNEL CHART (horizontal bar):                              | |
| |   Attempted to Contact ███████████████████████  60 target   | |
| |   Connected             ██████████████████      60 target   | |
| |   Meeting Booked        ███████████             24 target   | |
| |   Proposal Sent         ████████                16 target   | |
| |   Onboarded             ████████                16 target   | |
| |   Won (target accts)    ████                     4 target   | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
| (EXISTING) Capacity by Event Type table                        |
| (EXISTING) Capacity Growth Trend chart                         |
| (EXISTING) Weekly Contact Attempts chart + YTD stats           |
+---------------------------------------------------------------+
```

#### New Components to Add

| Element | Component | Data Source | Notes |
|---------|-----------|------------|-------|
| **Meetings Booked MTD** | `metric-card` | `supply/meetings-booked-mtd.sql` | Target: 24/month |
| **Pipeline by Event Type** | `capacity-table` (reuse pattern) | `supply/pipeline-coverage-by-event-type.sql` | Coverage = Open/Goal per type |
| **Supply Funnel** | Plotly horizontal bar (funnel) | `supply/supply-funnel.sql` | Actual vs monthly target per stage |
| **Listings Published** | `metric-card` | `supply/listings-published-per-month.sql` | Monthly count |

---

### 5. Supply AM Page

**Owner:** Ashton
**Nav key:** `supply_am`

#### Layout

```
+---------------------------------------------------------------+
| PAGE HEADER: "Supply AM"         Ashton's Dashboard            |
+---------------------------------------------------------------+
| DEPT SUMMARY: Supply account management. Responsible for       |
|               partner retention and relationship growth.       |
+---------------------------------------------------------------+
|                                                                |
| NORTH STAR CARD (orange gradient):                             |
|   "NRR Top Supply Users"                                       |
|   95% actual · 110% target                                    |
|   2025 reference: 66.7%                                        |
|   [=============================----------]                    |
|                                                                |
+---------------------------------------------------------------+
| SECTION: Key Metrics                          [4-column grid]  |
| +-------------+ +-------------+ +-------------+ +-------------+|
| | Partner     | | Partner     | | Avg Revenue | | Avg Ticket  ||
| | Retention   | | Satisfaction| | per Partner | | Response    ||
| | XX%         | | X.X/5       | | $XX,XXX     | | XX hrs      ||
| | Target: 90% | | Target: 4.5 | |             | | Target: 16h ||
| +-------------+ +-------------+ +-------------+ +-------------+|
+---------------------------------------------------------------+
| SECTION: Top Partner Revenue Trend                             |
| +-----------------------------------------------------------+ |
| | LINE CHART: Top 10 partner revenue over time               | |
| | Each partner as separate trace, sorted by current revenue   | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
| SECTION: Partner Detail Table                                  |
| +-----------------------------------------------------------+ |
| | Partner Name    | 2025 Rev | 2026 Rev | NRR  | Status     | |
| | Partner A       | $XXX,XXX | $XXX,XXX | 120% | On Track   | |
| | Partner B       | $XXX,XXX | $XXX,XXX | 85%  | At Risk    | |
| | Partner C       | $XXX,XXX | $XXX,XXX | 0%   | Churned    | |
| | ...             |          |          |      |            | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
```

#### Component Specifications

| Element | Component | Data Source | Notes |
|---------|-----------|------------|-------|
| **Hero: NRR Top Supply** | `north-star-card` (orange) | `Supplier_Metrics` BigQuery view | SHARED with Overview |
| **Partner Retention Rate** | `metric-card` | BigQuery (partners retained / total) | Phase 2 - build query |
| **Partner Satisfaction** | `metric-card` | Survey data (manual / Phase 4) | May show placeholder |
| **Avg Revenue per Partner** | `metric-card` | BigQuery (total payouts / partner count) | Phase 2 - build query |
| **Avg Ticket Response** | `metric-card` | Phase 4 - Zendesk/Intercom API | Placeholder until integrated |
| **Top Partner Trend** | Plotly line chart | BigQuery `Supplier_Metrics` | Show top 10 by revenue |
| **Partner Detail Table** | `team-table` (adapted) | BigQuery `Supplier_Metrics` | YoY comparison per partner |

---

### 6. Demand Sales Page

**Owner:** Andy Cooper (leader), Danny Sears, Katie
**Nav key:** `demand_sales`

#### Layout

```
+---------------------------------------------------------------+
| PAGE HEADER: "Demand Sales"      Sales Team Dashboard          |
+---------------------------------------------------------------+
| DEPT SUMMARY: Brand acquisition and pipeline management.       |
+---------------------------------------------------------------+
|                                                                |
| NORTH STAR CARD (cyan gradient):                               |
|   "Pipeline Coverage"                                          |
|   2.8x actual · 6.0x target                                   |
|   Weighted Pipeline: $X.XM  |  Remaining Quota: $X.XM         |
|   [================-----------]                                |
|                                                                |
+---------------------------------------------------------------+
| SECTION: Sales Metrics                        [4-column grid]  |
| +-------------+ +-------------+ +-------------+ +-------------+|
| | Win Rate    | | Avg Deal    | | Sales Cycle | | Meetings    ||
| | (90 days)   | | Size        | | Length      | | Booked QTD  ||
| | 28%         | | $155K       | | XX days     | | XX          ||
| | Target: 30% | | Target:$150K| | Target: 60d | | Target: 45  ||
| +-------------+ +-------------+ +-------------+ +-------------+|
+---------------------------------------------------------------+
| SECTION: Pipeline by Rep                                       |
| +-----------------------------------------------------------+ |
| | TEAM TABLE:                                                 | |
| | Rep     | Weighted $ | Quota Rem | Coverage | Status       | |
| | Andy    | $X.XM      | $X.XM     | X.Xx     | On Track     | |
| | Danny   | $X.XM      | $X.XM     | X.Xx     | At Risk      | |
| | Katie   | $X.XM      | $X.XM     | X.Xx     | On Track     | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
| SECTION: Deals by Stage               [2-column: funnel + tbl]|
| +-----------------------------+ +-----------------------------+|
| | FUNNEL CHART (horizontal):  | | DEALS CLOSING SOON TABLE   ||
| |   Meeting Booked  ████  45  | | Deal Name | Amount | Close  ||
| |   SQL              ███  36  | | Acme Corp | $200K  | Feb 10 ||
| |   Opportunity      ███  23  | | BigCo     | $150K  | Feb 15 ||
| |   Proposal Sent    ██   22  | | ...       |        |        ||
| |   Active Neg.      ██   15  | +-----------------------------+|
| |   Contract Sent    █     9  | |                             ||
| |   Closed Won       █     7  | | EXPIRED OPEN DEALS TABLE   ||
| +-----------------------------+ | Deal Name | Amount | Exp.   ||
|                                 | OldCo     | $80K   | Jan 15 ||
|                                 | ...       |        |        ||
|                                 +-----------------------------+|
+---------------------------------------------------------------+
| SECTION: Hygiene Alerts                       [3-column grid]  |
| +-------------------+ +-------------------+ +-------------------+
| | Expired Open      | | Companies Not     | | Deals >7 Days    |
| | Deals             | | Contacted (7d)    | | No Activity      |
| | X deals           | | X companies       | | X deals          |
| | Target: 0         | | Target: 0         | | Target: 0        |
| +-------------------+ +-------------------+ +-------------------+
+---------------------------------------------------------------+
```

#### Component Specifications

| Element | Component | Data Source | Notes |
|---------|-----------|------------|-------|
| **Hero: Pipeline Coverage** | `north-star-card` (cyan) | `demand-sales/pipeline-coverage-by-rep.sql` (aggregate) | SHARED - show company total |
| **Win Rate (90d)** | `metric-card` | `demand-sales/win-rate-90-days.sql` | Last 90 days rolling |
| **Avg Deal Size** | `metric-card` | `demand-sales/avg-deal-size-ytd.sql` | YTD average |
| **Sales Cycle Length** | `metric-card` | `demand-sales/sales-cycle-length.sql` | AVG days to close |
| **Meetings Booked QTD** | `metric-card` | `demand-sales/meetings-booked-qtd.sql` | Quarter to date |
| **Pipeline by Rep** | `team-table` | `demand-sales/pipeline-coverage-by-rep.sql` | Per-rep breakdown |
| **Deals by Stage Funnel** | Plotly horizontal bar | `demand-sales/deals-by-stage-funnel.sql` | Actual vs monthly target per stage |
| **Deals Closing Soon** | `capacity-table` (compact) | `demand-sales/deals-closing-soon.sql` | This week / month / next month |
| **Expired Open Deals** | `capacity-table` (compact) | `demand-sales/expired-open-deals.sql` | Target: 0 |
| **Companies Not Contacted** | `metric-card` (alert style) | `demand-sales/companies-not-contacted-7d.sql` | >7 days no activity |

#### Funnel Stage Targets (Monthly)

| Stage | Monthly Target | Chart Color |
|-------|----------------|-------------|
| Meeting Booked | 45 | `#13bad5` |
| SQL | 36 | `#13bad5` |
| Opportunity | 23 | `#13bad5` |
| Proposal Sent | 22 | `#ff8900` |
| Active Negotiation | 15 | `#ff8900` |
| Contract Sent | 9 | `#10b981` |
| Closed Won | 7 / $500K | `#10b981` |

---

### 7. Demand AM Page

**Owner:** Char Short (director), Victoria, Claire, Francisco
**Nav key:** `demand_am`

#### Layout

```
+---------------------------------------------------------------+
| PAGE HEADER: "Demand AM"     Account Management Dashboard      |
+---------------------------------------------------------------+
| DEPT SUMMARY: Account management and program execution.        |
|               Responsible for fulfillment, retention, NPS.     |
+---------------------------------------------------------------+
|                                                                |
| NORTH STAR CARD (cyan gradient):                               |
|   "Contract Spend %"                                           |
|   89% actual · 95% target                                     |
|   Unspent contracts: $X.XM remaining                           |
|   [==========================================---]              |
|                                                                |
+---------------------------------------------------------------+
| SECTION: AM Metrics                           [4-column grid]  |
| +-------------+ +-------------+ +-------------+ +-------------+|
| | Time to     | | NPS Score   | | Offer       | | Customer    ||
| | Fulfill     | |             | | Acceptance  | | Health      ||
| | 69 days     | | 71%         | | 88%         | | Score (TBD) ||
| | Target: 60d | | Target: 75% | | Target: 90% | | Phase 3    ||
| | SHARED      | |             | |             | |            ||
| +-------------+ +-------------+ +-------------+ +-------------+|
+---------------------------------------------------------------+
| SECTION: AM Performance by Person                              |
| +-----------------------------------------------------------+ |
| | TEAM TABLE:                                                 | |
| | AM         | Primary Metric      | Actual | Target | Status| |
| | Char Short | Contract Spend %    | 89%    | 95%    | AtRisk| |
| | Victoria   | Days to Fulfill     | 69 d   | 60 d   | AtRisk| |
| | Claire     | NPS Score           | 71%    | 75%    | AtRisk| |
| | Francisco  | Offer Acceptance %  | 88%    | 90%    | AtRisk| |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
| SECTION: Contract Spend Distribution                           |
| +-----------------------------------------------------------+ |
| | HORIZONTAL BAR CHART:                                       | |
| | Customer A  █████████████████████████████  98%  ($XXK)     | |
| | Customer B  ████████████████████████████   95%  ($XXK)     | |
| | Customer C  ██████████████████████         82%  ($XXK)     | |
| | Customer D  ████████████████               72%  ($XXK)     | |
| | Color: green >=95%, yellow 80-94%, red <80%                | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
| SECTION: Fulfillment Health       [2-column: chart + table]    |
| +-----------------------------+ +-----------------------------+|
| | HISTOGRAM: Days to Fulfill  | | AT-RISK ACCOUNTS TABLE     ||
| | Distribution                 | | Account | Spend | Status   ||
| | (bucket by 15-day intervals)| | Acme    | 45%   | Red      ||
| |                              | | BigCo   | 52%   | Red      ||
| +-----------------------------+ +-----------------------------+|
+---------------------------------------------------------------+
```

#### Component Specifications

| Element | Component | Data Source | Notes |
|---------|-----------|------------|-------|
| **Hero: Contract Spend %** | `north-star-card` (cyan) | `Upfront_Contract_Spend_Query` view | Char's primary metric |
| **Time to Fulfill** | `metric-card` | `Days_to_Fulfill_Contract_Spend` view | SHARED with Overview, median value |
| **NPS Score** | `metric-card` | `organizer_recap_NPS_score` view | Claire's metric |
| **Offer Acceptance %** | `metric-card` | HubSpot activities (Phase 2) | Francisco's metric |
| **Customer Health** | `metric-card` | Composite score (Phase 3) | Placeholder |
| **AM Performance Table** | `team-table` | `PERSON_METRICS` filtered by Demand AM | One row per AM |
| **Contract Spend Chart** | Plotly horizontal bar | `Upfront_Contract_Spend_Query` | Per-customer spend %, color-coded |
| **Days to Fulfill Histogram** | Plotly histogram | `Days_to_Fulfill_Contract_Spend` | Distribution of fulfillment times |
| **At-Risk Accounts** | `capacity-table` (compact) | BigQuery - contracts < 80% spend | Filterable by AM |

---

### 8. Marketing Page

**Owner:** Marketing team (1 person)
**Nav key:** `marketing`

#### Layout

```
+---------------------------------------------------------------+
| PAGE HEADER: "Marketing"     Marketing Performance Dashboard   |
+---------------------------------------------------------------+
| DEPT SUMMARY: Demand generation and brand awareness.           |
|               Attribution uses 50/50 FT+LT model.             |
+---------------------------------------------------------------+
|                                                                |
| NORTH STAR CARD (cyan gradient):                               |
|   "Marketing-Influenced Pipeline"                              |
|   $2.4M current pipeline value                                |
|   Attribution: (First Touch + Last Touch) / 2                  |
|                                                                |
+---------------------------------------------------------------+
| SECTION: Conversion Metrics                   [4-column grid]  |
| +-------------+ +-------------+ +-------------+ +-------------+|
| | MQL to SQL  | | Marketing   | | First Touch | | Last Touch  ||
| | Conversion  | | Leads (ML)  | | Attrib. $   | | Attrib. $   ||
| | 33%         | | XXX         | | $1.8M       | | $2.1M       ||
| | Target: 30% | |             | |             | |             ||
| +-------------+ +-------------+ +-------------+ +-------------+|
+---------------------------------------------------------------+
| SECTION: Marketing Leads Funnel                                |
| +-----------------------------------------------------------+ |
| | FUNNEL CHART (vertical or horizontal):                      | |
| |   Marketing Lead (ML) ████████████████████████   XXX       | |
| |   MQL                 ████████████████           XXX       | |
| |   SQL                 ███████████                XXX       | |
| |                                                             | |
| |   Conversion rates shown between stages                     | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
| SECTION: Attribution by Channel                                |
| +-----------------------------------------------------------+ |
| | STACKED BAR or GROUPED BAR CHART:                           | |
| | X-axis: Channel names (10 channels)                         | |
| | Y-axis: Revenue ($)                                         | |
| | Two bars per channel: First Touch vs Last Touch              | |
| |                                                              | |
| | Channels: Direct Traffic, Paid Search, Paid Social,          | |
| | Organic Social, Organic Search, Event, Email Marketing,      | |
| | Other Campaigns, Referrals, General Referral                 | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
```

#### Component Specifications

| Element | Component | Data Source | Notes |
|---------|-----------|------------|-------|
| **Hero: Mktg-Influenced Pipeline** | `north-star-card` (cyan) | `marketing/marketing-influenced-pipeline.sql` | 50/50 FT+LT model |
| **MQL to SQL Conversion** | `metric-card` | `marketing/mql-to-sql-conversion.sql` | Target: 30% |
| **Marketing Leads Count** | `metric-card` | `marketing/marketing-leads-funnel.sql` | Total ML count |
| **First Touch Attribution** | `metric-card` | `marketing/attribution-by-channel.sql` | Sum of FT attribution |
| **Last Touch Attribution** | `metric-card` | `marketing/attribution-by-channel.sql` | Sum of LT attribution |
| **Leads Funnel** | Plotly funnel chart | `marketing/marketing-leads-funnel.sql` | ML -> MQL -> SQL with conversion rates |
| **Attribution by Channel** | Plotly grouped bar chart | `marketing/attribution-by-channel.sql` | FT vs LT per channel |

---

### 9. Accounting Page

**Owner:** Accounting team (1 person)
**Nav key:** `accounting`

#### Layout

```
+---------------------------------------------------------------+
| PAGE HEADER: "Accounting"   AR/AP Operations Dashboard         |
+---------------------------------------------------------------+
| DEPT SUMMARY: AR/AP operations and financial controls.         |
+---------------------------------------------------------------+
|                                                                |
| NORTH STAR CARD (cyan gradient):                               |
|   "Invoice Collection Rate"                                    |
|   93% actual · 95% target                                     |
|   Invoices collected on time / Total due                       |
|   [=============================================--]            |
|                                                                |
+---------------------------------------------------------------+
| SECTION: AR Metrics                           [4-column grid]  |
| +-------------+ +-------------+ +-------------+ +-------------+|
| | Overdue     | | Overdue     | | Avg Days to | | Factoring   ||
| | Invoice Cnt | | Invoice $   | | Collection  | | Capacity    ||
| | 4           | | $45,000     | | 8 days      | | $XXX,XXX    ||
| | Target: 0   | | Target: $0  | | Target: 7d  | | Target:>$400K|
| | SHARED      | | SHARED      | |             | | SHARED      ||
| +-------------+ +-------------+ +-------------+ +-------------+|
+---------------------------------------------------------------+
| SECTION: Reconciliation Health                [2-column grid]  |
| +-----------------------------+ +-----------------------------+|
| | Invoice Variance            | | Bill Variance               ||
| | Count: X   Amount: $X,XXX  | | Count: X   Amount: $X,XXX  ||
| | Target: 0 / $0              | | Target: 0 / $0              ||
| +-----------------------------+ +-----------------------------+|
+---------------------------------------------------------------+
| SECTION: AR Aging Breakdown                                    |
| +-----------------------------------------------------------+ |
| | STACKED BAR CHART or TABLE:                                 | |
| |   Current    ████████████████████████████   $XXX,XXX       | |
| |   1-30 days  ████████████                   $XXX,XXX       | |
| |   31-60 days ██████                         $XX,XXX        | |
| |   61-90 days ███                            $XX,XXX        | |
| |   90+ days   █                              $X,XXX         | |
| |                                                             | |
| |   Color: green (current), yellow (1-30), orange (31-60),    | |
| |          red (61-90), dark red (90+)                         | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
| SECTION: Collection Trend                                      |
| +-----------------------------------------------------------+ |
| | LINE CHART: Monthly collection rate over time               | |
| | Cyan line = actual %, dashed = 95% target                   | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
```

#### Component Specifications

| Element | Component | Data Source | Notes |
|---------|-----------|------------|-------|
| **Hero: Invoice Collection %** | `north-star-card` (cyan) | `coo-ops/invoice-collection-rate.sql` | SHARED with COO |
| **Overdue Invoice Count** | `metric-card` | `coo-ops/overdue-invoices.sql` | SHARED - count field |
| **Overdue Invoice Amount** | `metric-card` | `coo-ops/overdue-invoices.sql` | SHARED - dollar field |
| **Avg Days to Collection** | `metric-card` | `coo-ops/avg-invoice-collection-time.sql` | Target: 7 days |
| **Factoring Capacity** | `metric-card` | `coo-ops/factoring-capacity.sql` | SHARED with COO |
| **Invoice Variance** | `metric-card` (wide) | Reconciliation query #4 | Count + dollar variance |
| **Bill Variance** | `metric-card` (wide) | Reconciliation query | Count + dollar variance |
| **AR Aging Breakdown** | Plotly horizontal bar (stacked) | `coo-ops/ar-aging-buckets.sql` | Color-coded by age bucket |
| **Collection Trend** | Plotly line chart | `coo-ops/ontime-collection-rate.sql` (historical) | Monthly trend with target line |

---

### 10. Engineering Page

**Owner:** VP Engineering (Arbind), Mateus, Anderson, Lucas
**Nav key:** `engineering`

#### Layout

```
+---------------------------------------------------------------+
| PAGE HEADER: "Engineering"   Product & Engineering Dashboard   |
+---------------------------------------------------------------+
| DEPT SUMMARY: Product development and technical execution.     |
|               (API integration pending - Phase 5)              |
+---------------------------------------------------------------+
|                                                                |
| INFO BANNER (warning style):                                   |
|   "Requires GitHub and Asana API integration (Phase 5).        |
|    Data will be populated once APIs are connected."            |
|                                                                |
+---------------------------------------------------------------+
| SECTION: Engineering Metrics                  [4-column grid]  |
| +-------------+ +-------------+ +-------------+ +-------------+|
| | Features    | | BizSup      | | PRDs        | | FSDs        ||
| | Fully Scoped| | Completed   | | Generated   | | Generated   ||
| | -- (TBD)    | | -- (TBD)    | | -- (TBD)    | | -- (TBD)    ||
| | Target: 5/mo| | Target:10/mo| | Target: 3/mo| | Target: 2/mo||
| | Arbind      | | Mateus      | | Anderson    | | Anderson    ||
| +-------------+ +-------------+ +-------------+ +-------------+|
+---------------------------------------------------------------+
| SECTION: Team Assignments                                      |
| +-----------------------------------------------------------+ |
| | TEAM TABLE:                                                 | |
| | Engineer  | Primary Metric        | Actual | Target | Status| |
| | Arbind    | Features Fully Scoped  | --     | 5/mo   | --   | |
| | Mateus    | BizSup Completed       | --     | 10/mo  | --   | |
| | Anderson  | PRDs Generated         | --     | 3/mo   | --   | |
| | Anderson  | FSDs Generated         | --     | 2/mo   | --   | |
| | Lucas     | Feature Releases       | --     | TBD    | --   | |
| +-----------------------------------------------------------+ |
+---------------------------------------------------------------+
| SECTION: Delivery Velocity (Phase 5)                           |
| +-----------------------------+ +-----------------------------+|
| | PLACEHOLDER: Sprint Velocity| | PLACEHOLDER: Deploy Freq.  ||
| | (Asana API needed)          | | (GitHub Actions API needed)||
| +-----------------------------+ +-----------------------------+|
+---------------------------------------------------------------+
```

#### Component Specifications

| Element | Component | Data Source | Notes |
|---------|-----------|------------|-------|
| **Features Fully Scoped** | `metric-card` | Phase 5 - Asana API | Arbind's primary metric, show "--" placeholder |
| **BizSup Completed** | `metric-card` | Phase 5 - Asana API | Mateus's metric |
| **PRDs Generated** | `metric-card` | Phase 5 - Asana/Notion API | Anderson's metric |
| **FSDs Generated** | `metric-card` | Phase 5 - Asana/Notion API | Anderson's metric |
| **Feature Releases** | `metric-card` | Phase 5 - GitHub API | Lucas's metric, target TBD |
| **Team Table** | `team-table` | `PERSON_METRICS` filtered by Engineering | Currently shows "--" for actuals |
| **Sprint Velocity** | Plotly line chart (placeholder) | Phase 5 - Asana API | Consistent velocity over sprints |
| **Deploy Frequency** | Plotly bar chart (placeholder) | Phase 5 - GitHub Actions API | Deploys per week |

#### Phase 5 Integration Requirements

| API | Metrics It Enables | Priority |
|-----|-------------------|----------|
| Asana | BizSup count, Sprint velocity, Feature scoping | High |
| GitHub | PRs merged, Deploy freq, Bug count | Medium |
| Notion | PRDs, FSDs document count | Medium |

---

## Implementation Priority

### Phase 1 (Now): Pages with Existing Data

These pages can be built immediately using existing queries and data:

| Priority | Page | Effort | Data Ready? |
|----------|------|--------|-------------|
| 1 | **Demand Sales** | Medium | Yes - all 9 queries exist |
| 2 | **CEO / Biz Dev** | Low | Yes - shared queries + existing chart data |
| 3 | **COO / Ops** | Low | Yes - 8 queries exist |
| 4 | **Supply** (additions) | Low | Yes - 6 queries exist, page partially built |
| 5 | **Accounting** | Medium | Partial - 6 queries exist, need AR aging deployment |

### Phase 2: Pages with Partial Data

| Priority | Page | Effort | What's Missing |
|----------|------|--------|----------------|
| 6 | **Demand AM** | Medium | Contract Spend query, NPS aggregation |
| 7 | **Marketing** | Medium | All 4 queries exist, need Plotly charts |
| 8 | **Supply AM** | Medium | Partner retention query, revenue-per-partner query |

### Phase 3: Pages Needing External APIs

| Priority | Page | Effort | Blocked On |
|----------|------|--------|------------|
| 9 | **Engineering** | High | Asana + GitHub + Notion API integration |

---

## Cross-Cutting Concerns

### Responsive Behavior

All pages inherit the existing mobile-responsive CSS from `app.py`:
- **Desktop (>1024px):** 4-column metric grids, side-by-side charts
- **Tablet (768-1024px):** 4-column grids, slightly tighter padding
- **Mobile (<768px):** 2-column metric grids, stacked charts, hidden page header
- **Small mobile (<480px):** Single-column layout

### Data Freshness

Every page should show the data source indicator (bottom-right corner, already implemented):
- Green "Live Data" badge when connected to BigQuery
- Yellow "Mock Data" badge when using fallback data

### Shared Component Architecture

To avoid code duplication, implement these as reusable Python functions in `app.py`:

```python
# Suggested function signatures
def render_north_star_card(label, value, target, format_type, color="cyan", subtitle=""):
    """Generic north star card - replaces per-page implementations."""

def render_metric_cards_grid(metrics: list, columns=4):
    """Render a grid of metric cards from a list of metric dicts."""

def render_funnel_chart(stages: list, title: str):
    """Render a horizontal funnel bar chart with actual vs target."""

def render_data_table(headers: list, rows: list, title: str):
    """Render a styled data table with status badges."""
```

### Navigation Consistency

All 10 pages are already defined in `NAV_ITEMS` dict in `app.py`. The sidebar navigation is complete. Each page just needs its `render_*` function implemented and wired into the `main()` routing.

---

## Appendix: Full Metric-to-Query Mapping

| Page | Metric | Query File | BigQuery View |
|------|--------|------------|---------------|
| Overview | Revenue YTD | - | `get_revenue_ytd()` |
| Overview | Take Rate | `coo-ops/take-rate.sql` | - |
| Overview | Demand NRR | - | `cohort_retention_matrix_by_customer` |
| Overview | Supply NRR | - | `Supplier_Metrics` |
| Overview | Pipeline Coverage | `demand-sales/pipeline-coverage-by-rep.sql` | - |
| Overview | Time to Fulfill | - | `Days_to_Fulfill_Contract_Spend` |
| Overview | Logo Retention | - | `customer_development` |
| Overview | Customer Count | - | `customer_development` |
| CEO | Revenue vs Target | `ceo-bizdev/revenue-vs-target.sql` | - |
| CEO | Pipeline Coverage | `demand-sales/pipeline-coverage-by-rep.sql` | - |
| CEO | Working Capital | `coo-ops/working-capital.sql` | - |
| CEO | Months of Runway | `coo-ops/months-of-runway.sql` | - |
| CEO | Customer Concentration | `coo-ops/top-customer-concentration.sql` | - |
| COO | Take Rate | `coo-ops/take-rate.sql` | - |
| COO | Invoice Collection | `coo-ops/invoice-collection-rate.sql` | - |
| COO | Overdue Invoices | `coo-ops/overdue-invoices.sql` | - |
| COO | Working Capital | `coo-ops/working-capital.sql` | - |
| COO | Months of Runway | `coo-ops/months-of-runway.sql` | - |
| COO | Customer Concentration | `coo-ops/top-customer-concentration.sql` | - |
| COO | Net Revenue Gap | `coo-ops/net-revenue-gap.sql` | - |
| COO | Factoring Capacity | `coo-ops/factoring-capacity.sql` | - |
| Supply | New Unique Inventory | `supply/new-unique-inventory.sql` | - |
| Supply | Contact Attempts | `supply/weekly-contact-attempts.sql` | - |
| Supply | Meetings MTD | `supply/meetings-booked-mtd.sql` | - |
| Supply | Pipeline by Type | `supply/pipeline-coverage-by-event-type.sql` | - |
| Supply | Funnel | `supply/supply-funnel.sql` | - |
| Supply | Listings | `supply/listings-published-per-month.sql` | - |
| Supply AM | NRR Top Supply | - | `Supplier_Metrics` |
| Demand Sales | Pipeline Coverage | `demand-sales/pipeline-coverage-by-rep.sql` | - |
| Demand Sales | Win Rate | `demand-sales/win-rate-90-days.sql` | - |
| Demand Sales | Avg Deal Size | `demand-sales/avg-deal-size-ytd.sql` | - |
| Demand Sales | Sales Cycle | `demand-sales/sales-cycle-length.sql` | - |
| Demand Sales | Funnel | `demand-sales/deals-by-stage-funnel.sql` | - |
| Demand Sales | Closing Soon | `demand-sales/deals-closing-soon.sql` | - |
| Demand Sales | Expired Deals | `demand-sales/expired-open-deals.sql` | - |
| Demand Sales | Not Contacted | `demand-sales/companies-not-contacted-7d.sql` | - |
| Demand Sales | Meetings QTD | `demand-sales/meetings-booked-qtd.sql` | - |
| Demand AM | Contract Spend | - | `Upfront_Contract_Spend_Query` |
| Demand AM | Time to Fulfill | - | `Days_to_Fulfill_Contract_Spend` |
| Demand AM | NPS Score | - | `organizer_recap_NPS_score` |
| Marketing | Influenced Pipeline | `marketing/marketing-influenced-pipeline.sql` | - |
| Marketing | MQL to SQL | `marketing/mql-to-sql-conversion.sql` | - |
| Marketing | Attribution | `marketing/attribution-by-channel.sql` | - |
| Marketing | Leads Funnel | `marketing/marketing-leads-funnel.sql` | - |
| Accounting | Invoice Collection | `coo-ops/invoice-collection-rate.sql` | - |
| Accounting | Overdue Invoices | `coo-ops/overdue-invoices.sql` | - |
| Accounting | Avg Days to Collect | `coo-ops/avg-invoice-collection-time.sql` | - |
| Accounting | AR Aging | `coo-ops/ar-aging-buckets.sql` | - |
| Accounting | Factoring Capacity | `coo-ops/factoring-capacity.sql` | - |

# Company KPI Dashboard - Master Implementation Plan

> **Last Updated:** 2026-02-03
> **Owner:** Deuce
> **Status:** Active Development
> **Developer Handoff:** Ready
> **Source:** Google Sheet `1uulb-rv4ohOO2Nv8zegXDR__8aVpeiHALKwUc1sADGw`

---

## Table of Contents

1. [Quick Start](#quick-start-for-developers)
2. [Core Requirements](#core-requirements)
3. [Business Context](#business-context)
4. **[Metric Review & Approval](#metric-review--approval)** ← **REVIEW CHECKLIST**
5. [Metric Registry](#metric-registry) ← **SINGLE SOURCE OF TRUTH**
   - [Company Health Metrics](#company-health-metrics-11-total)
   - [Sales Metrics](#1_sales---demand-sales-team)
   - [CEO/Biz Dev Metrics](#2_ceobiz-dev---jack)
   - [COO/Ops/Finance Metrics](#3_cooopsfinance---deuce)
   - [Supply Metrics](#4_supply---ian-hong)
   - [Marketing Metrics](#5_marketing)
   - [Accounting Metrics](#6_accounting)
   - [Demand AM Metrics](#7_demand-am)
   - [Supply AM Metrics](#8_supply-am---ashton)
   - [Engineering Metrics](#10_engineering)
6. [Implementation Phases](#implementation-phases)
7. [Data Architecture](#data-architecture)
8. [Security Implementation](#security-implementation)
9. [Gotchas & Learnings](#gotchas--learnings)

---

## Metric Review & Approval

> **Purpose:** Manual review and approval of each metric calculation before adding to features.json
> **Status:** 🔄 In Progress
> **Last Review:** 2026-02-04

### How to Use This Section

1. Review each metric's formula and data source
2. Mark as ✅ Approved, ❌ Needs Fix, or 🔍 Needs Verification
3. Once all metrics in a department are approved, add to `features.json`

---

### COO/CFO Dashboard (`queries/coo-ops/`)

> **Targets:** Stored in `dashboard/data/targets.json` - queries should NOT hardcode targets

| # | Metric | Formula | Target | Query File | Status |
|---|--------|---------|:------:|------------|:------:|
| 1 | **Take Rate %** | `(GMV - Payouts) / GMV × 100` | 50% | `take-rate.sql` | ✅ |
| 2 | **Invoice Collection Rate** | `Paid Invoices / Total Due Invoices × 100` | 95% | `invoice-collection-rate.sql` | 🔍 |
| 3 | **Overdue Invoices** | `Count & $ where balance > 0 AND due_date < today` | 0 | `overdue-invoices.sql` | 🔍 |
| 4 | **Working Capital** | `Current Assets - Current Liabilities` | >$1M | `working-capital.sql` | 🔍 |
| 5 | **Months of Runway** | `Cash Balance / Avg Monthly Burn (3mo)` | >12 mo | `months-of-runway.sql` | 🔍 |
| 6 | **Customer Concentration** | `Top Customer Revenue / Total Revenue × 100` | <30% | `top-customer-concentration.sql` | 🔍 |
| 7 | **Net Revenue Gap** | `Unspent Contracts - (Target - YTD Revenue)` | Reporting | `net-revenue-gap.sql` | 🔍 |
| 8 | **Factoring Capacity** | `Eligible AR × 85%` (invoices <90 days) | >$400K | `factoring-capacity.sql` | 🔍 |
| 9 | **Cash Position** | `Sum of all bank account balances` | >$500K | `cash-position.md` | 📅 Phase 4 |

**Approval Status:** 1/8 approved (Cash Position is Phase 4)

---

### CEO Dashboard (`queries/ceo-bizdev/`)

| # | Metric | Formula | Data Source | Query File | Status |
|---|--------|---------|-------------|------------|:------:|
| 1 | **Revenue vs Target** | `YTD Revenue / Annual Target × 100` | QBO `invoice` | `revenue-vs-target.sql` | 🔍 |
| 2 | **Pipeline Coverage** | `Weighted Pipeline / Remaining Quota` | HubSpot `deal` | `demand-sales/pipeline-coverage-by-rep.sql` | 🔍 |
| 3 | **Working Capital** | *(shared with COO)* | | `coo-ops/working-capital.sql` | 🔍 |
| 4 | **Months of Runway** | *(shared with COO)* | | `coo-ops/months-of-runway.sql` | 🔍 |
| 5 | **Customer Concentration** | *(shared with COO)* | | `coo-ops/top-customer-concentration.sql` | 🔍 |
| 6 | **Cash Position** | *(shared with COO)* | | `coo-ops/cash-position.md` | 📅 Phase 4 |

**Approval Status:** 0/5 approved (Cash Position is Phase 4)

---

### Demand Sales (`queries/demand-sales/`)

| # | Metric | Formula | Data Source | Query File | Status |
|---|--------|---------|-------------|------------|:------:|
| 1 | **Pipeline Coverage** | `(Weighted Pipeline) / (Quarterly Quota - Closed Won)` | HubSpot `deal` (hs_forecast_amount) | `pipeline-coverage-by-rep.sql` | 🔍 |
| 2 | **Win Rate (90d)** | `Closed Won / (Closed Won + Closed Lost) × 100` | HubSpot `deal` | `win-rate-90-days.sql` | 🔍 |
| 3 | **Avg Deal Size** | `Total Closed Won $ / Closed Won Count` | HubSpot `deal` | `avg-deal-size-ytd.sql` | 🔍 |
| 4 | **Sales Cycle Length** | `AVG(closedate - createdate)` for won deals | HubSpot `deal` | `sales-cycle-length.sql` | 🔍 |
| 5 | **Deals by Stage** | `Count per stage vs monthly target` | HubSpot `deal` + `deal_pipeline_stage` | `deals-by-stage-funnel.sql` | 🔍 |
| 6 | **Deals Closing Soon** | `Deals with closedate in next 7/30/60 days` | HubSpot `deal` | `deals-closing-soon.sql` | 🔍 |
| 7 | **Expired Open Deals** | `Open deals where closedate < today` | HubSpot `deal` | `expired-open-deals.sql` | 🔍 |
| 8 | **Companies Not Contacted** | `Deals with no activity in 7+ days` | HubSpot `deal` + `engagement` | `companies-not-contacted-7d.sql` | 🔍 |
| 9 | **Meetings Booked QTD** | `Count of meetings this quarter` | HubSpot `engagement` | `meetings-booked-qtd.sql` | 🔍 |

**Approval Status:** 0/9 approved

---

### Supply (`queries/supply/`)

| # | Metric | Formula | Data Source | Query File | Status |
|---|--------|---------|-------------|------------|:------:|
| 1 | **New Unique Inventory** | `Count of closed-won deals in Supply pipeline` | HubSpot `deal` (date_converted_onboarded) | `new-unique-inventory.sql` | 🔍 |
| 2 | **Weekly Contact Attempts** | `Count of engagements on Supply Target contacts` | HubSpot `engagement` + `contact` | `weekly-contact-attempts.sql` | 🔍 |
| 3 | **Meetings Booked MTD** | `Count where date_converted_meeting_booked this month` | HubSpot `deal` | `meetings-booked-mtd.sql` | 🔍 |
| 4 | **Pipeline Coverage by Type** | `Open Pipeline / (Goal - Won) per event type` | HubSpot `deal` + hardcoded goals | `pipeline-coverage-by-event-type.sql` | 🔍 |
| 5 | **Supply Funnel** | `Deals per stage vs monthly target` | HubSpot `deal` + `deal_pipeline_stage` | `supply-funnel.sql` | 🔍 |
| 6 | **Listings Published** | `Count of published listings per month` | MongoDB `audience_listings` | `listings-published-per-month.sql` | 🔍 |
| 7 | **Lead Queue Runway** | `Leads in Queue / Daily Contact Rate` | Smart Lead API | `lead-queue-runway.md` | 📅 Phase 4 |

**Approval Status:** 0/6 approved (Lead Queue Runway is Phase 4)

---

### Marketing (`queries/marketing/`)

| # | Metric | Formula | Data Source | Query File | Status |
|---|--------|---------|-------------|------------|:------:|
| 1 | **Marketing-Influenced Pipeline** | `(FT + LT) / 2` attribution on open deals | HubSpot `deal` + `contact` | `marketing-influenced-pipeline.sql` | 🔍 |
| 2 | **MQL → SQL Conversion** | `SQLs / MQLs × 100` | HubSpot `contact` lifecycle dates | `mql-to-sql-conversion.sql` | 🔍 |
| 3 | **Attribution by Channel** | `Revenue attributed per channel (50/50 FT+LT)` | HubSpot `deal` + `contact` | `attribution-by-channel.sql` | 🔍 |
| 4 | **Marketing Leads Funnel** | `ML → MQL → SQL counts and conversion` | HubSpot `contact` | `marketing-leads-funnel.sql` | 🔍 |

**Approval Status:** 0/4 approved

---

### Approval Legend

| Symbol | Meaning |
|:------:|---------|
| 🔍 | Needs Review - formula not yet verified |
| ✅ | Approved - calculation confirmed correct |
| ❌ | Needs Fix - formula or data source incorrect |
| 📅 | Phase 4 - requires external API integration |

### Next Steps After Approval

1. Mark each metric ✅ after review
2. Run validation queries in BigQuery
3. Add approved metrics to `context/features.json`
4. Deploy queries to dashboard

---

## Quick Start for Developers

```bash
# 1. Clone and setup
cd dashboard
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 2. Set BigQuery credentials
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/bigquery-mcp-key.json"

# 3. Run dashboard
streamlit run app.py
```

**Key Files:**
| File | Purpose |
|------|---------|
| `dashboard/app.py` | Main Streamlit application |
| `dashboard/data/bigquery_client.py` | All BigQuery query functions |
| `dashboard/data/mock_data.py` | Fallback data + pipeline calculations |
| `dashboard/data/targets.json` | Configurable targets for all metrics |

---

## Core Requirements

### 1. One Metric Per Person
Every team member has ONE PRIMARY metric they own. Clear accountability.

### 2. Automated Data Pulls
No manual updates. All data flows from source systems via BigQuery.

### 3. Security & Permissions 🔐

**Tab-based access control with email whitelist.**

| Role | Tab Access |
|------|------------|
| **Executive** | All tabs |
| **Demand Sales** | Company Health, Sales |
| **Demand AM** | Company Health, Demand AM |
| **Supply** | Company Health, Supply |
| **Accounting** | Company Health, Accounting |
| **Engineering** | Company Health, Engineering |

### 4. Simple & Prescriptive
Traffic light indicators (🟢🟡🔴). When yellow or red, show action items.

### 5. Daily Refresh
Data updates overnight. Fresh numbers every morning.

---

## Business Context

### Business Model

- **Type:** Two-sided marketplace (Recess)
- **Supply side:** Events/venues (university housing, fitness studios, music festivals)
- **Demand side:** Fortune 100 CPG brands (Kraft Heinz, Coca-Cola, etc.)
- **Revenue model:** Company earns when brands run programs at venues
- **North Star Metric:** Revenue (not GMV)

### Organization Structure (~18 people)

| Department | Team | Reports To |
|------------|------|------------|
| CEO/Biz Dev | Jack | — |
| COO/Ops | Deuce | CEO |
| Demand Sales | Andy (leader), Danny, Katie | CEO |
| Demand AM | Char (director), Victoria, Claire, Francisco | COO |
| Supply | Ian Hong | COO |
| Supply AM | Ashton | COO |
| Marketing | 1 person | CEO |
| Accounting | 1 person | COO |
| Engineering | Arbind, Mateus, Anderson, Lucas | CEO |

---

## Metric Registry

> **THIS IS THE SINGLE SOURCE OF TRUTH** for all metrics.
> Synced from Google Sheet tabs on 2026-02-03.

### Status Legend

| Status | Meaning |
|--------|---------|
| ✅ **Approved** | Deuce reviewed and confirmed |
| 🟡 **In UI** | Showing but NOT yet approved |
| ✅ **Ready** | Query exists, ready to implement |
| 🔧 **Build** | Need to create query |
| 📝 **Define** | Need business definition |
| 🔍 **Verify** | Need to clarify with owner |
| ⛔ **Blocked** | Waiting on external input |

---

## 🔗 Shared Metrics (Build Once, Show Many)

> **IMPORTANT:** These metrics appear on multiple dashboards but use the SAME underlying query.
> Build the query once, then filter/display on different tabs.

| Core Metric | Appears On | Filter By |
|-------------|------------|-----------|
| **Pipeline Coverage** | Company Health, Sales (Andy), Sales (Danny), Sales (Katie) | `deal_owner` for person view |
| **NRR (Demand)** | Company Health, Sales (Andy) | None - same view |
| **NRR (Supply)** | Company Health, Supply AM (Ashton) | None - same view |
| **Revenue YTD** | Company Health, CEO (Jack) | None - same view |
| **Time to Fulfill** | Company Health, Demand AM (Victoria) | None - same view |
| **Invoice Collection** | Accounting, COO/Ops (Deuce) | None - same view |
| **Cash Position** | CEO/Biz Dev (Jack), COO/Ops (Deuce) | None - same view |
| **Working Capital** | CEO/Biz Dev (Jack), COO/Ops (Deuce) | None - same view |
| **Runway** | CEO/Biz Dev (Jack), COO/Ops (Deuce) | None - same view |
| **Customer Concentration** | Company Health, CEO/Biz Dev (Jack) | None - same view |
| **Contract Spend %** | Demand AM (Char), COO/Ops | `account_manager` for person view |
| **Unspent Contract $** | CEO/Biz Dev, COO/Ops | None - same view |

### Development Efficiency

| Unique Queries Needed | ~50 |
|----------------------|-----|
| Total Display Cards | ~131 |
| Reuse Ratio | 2.6x |

**Build the ~50 unique queries, display them ~131 times across different tabs.**

---

## Company Health Metrics (11 Total)

### Phase 1 - Core Cards (7)

| # | Metric | Owner | Status | Target | Data Source | Why It Matters |
|---|--------|-------|:------:|--------|-------------|----------------|
| 1 | **Revenue YTD** | Jack | ✅ Approved | $10M | BigQuery (QBO) | North Star. All metrics ladder to this. |
| 2 | **Take Rate %** | Deuce | ✅ Approved | 45% | BigQuery, QuickBooks | Profitability signal. Proves business model. |
| 3 | **Demand NRR** | Andy | ✅ Approved | >100% | `cohort_retention_matrix_by_customer` | Expansion vs churn. Predicts revenue stability. |
| 4 | **Supply NRR** | Ashton | 🟡 Needs Review | >100% | `Supplier_Metrics` | Supply-side health. Same logic as Demand. |
| 5 | **Pipeline Coverage** | Andy | ✅ Approved | 6.0x | HubSpot deals | Sales forecasting accuracy. |
| 6 | **Sellable Inventory** | ? | ⛔ Blocked | TBD | BigQuery (mongodb) | Supply capacity. **Needs PRD.** |
| 7 | **Time to Fulfill** | Victoria | 🟡 Needs Review | <30 days | `Days_to_Fulfill_Contract_Spend` | Revenue recognition speed. |

### Phase 2 - Secondary Cards (4)

| # | Metric | Owner | Status | Target | Data Source | Why It Matters |
|---|--------|-------|:------:|--------|-------------|----------------|
| 8 | **Logo Retention** | ? | 🟡 Needs Review | 50% | `customer_development` | Customer satisfaction proxy. **37% is RED FLAG.** |
| 9 | **Customer Concentration** | ? | 🟡 Needs Review | <30% | `net_revenue_retention_all_customers` | Risk. 29.2% HEINEKEN = existential risk. |
| 10 | **Active Customers** | ? | 🟡 Needs Review | TBD | `customer_development` | Demand-side volume. |
| 11 | **Churned Customers** | ? | 🟡 Needs Review | TBD | `customer_development` | Churn visibility. |

---

## 1_Sales - Demand Sales Team

> **Queries:** `queries/demand-sales/`
> **HubSpot Dashboards:**
> - [Sales Pipeline](https://app.hubspot.com/reports-dashboard/6699636/view/3551608)
> - [Sales Activity](https://app.hubspot.com/reports-dashboard/6699636/view/16787401)

### 📊 Query Coverage Summary

| Category | Have | Need | Blocked |
|----------|:----:|:----:|:-------:|
| Phase 1 (PRIMARY) | 4 | 0 | 0 |
| Phase 2 (Secondary) | 9 | 0 | 0 |
| Phase 3 (AI Scoring) | 0 | 3 | 0 |
| **TOTAL** | **13** | **3** | **0** |

**✅ CREATED (10 files):**
- `pipeline-coverage-by-rep.sql` - PRIMARY for Andy, Danny, Katie (6x target)
- `win-rate-90-days.sql` - 30% target
- `avg-deal-size-ytd.sql` - $150K target
- `sales-cycle-length.sql` - ≤60 days target
- `deals-by-stage-funnel.sql` - Monthly funnel targets
- `deals-closing-soon.sql` - This week/month/next month
- `expired-open-deals.sql` - Target: 0
- `companies-not-contacted-7d.sql` - Target: 0
- `meetings-booked-qtd.sql` - 45/month target
- `README.md`

**🔧 STILL NEED (3 metrics):**
- Hot Deals # / $ (Phase 3 - AI Deal Scoring)
- Warm Deals # / $ (Phase 3 - AI Deal Scoring)
- Cold Deals # / $ (Phase 3 - AI Deal Scoring)

**Note:** NRR uses existing BigQuery view `cohort_retention_matrix_by_customer`

### PRIMARY Metrics (Phase 1)

| Person | Metric | Target | Status | Query File |
|--------|--------|--------|:------:|------------|
| **Andy Cooper** | NRR | >100% | ✅ Ready | `cohort_retention_matrix_by_customer` |
| **Andy Cooper** | Pipeline Coverage | **6.0x** | ✅ Query Created | `pipeline-coverage-by-rep.sql` |
| **Danny Sears** | Pipeline Coverage | **6.0x** | ✅ Query Created | `pipeline-coverage-by-rep.sql` |
| **Katie** | Pipeline Coverage | **6.0x** | ✅ Query Created | `pipeline-coverage-by-rep.sql` |

### SECONDARY Metrics (Phase 2)

| Metric | Target | Status | Query File |
|--------|--------|:------:|------------|
| Meetings Booked (QTD) vs Goal | 45/mo | ✅ Query Created | `meetings-booked-qtd.sql` |
| 30-Day Deals >7 Days Not Contacted | 0 | ✅ Query Created | `companies-not-contacted-7d.sql` |
| **Companies >7 Days Response** | 0 | ✅ Query Created | `companies-not-contacted-7d.sql` |
| Weighted Pipeline | $4.5M | ✅ Query Created | `pipeline-coverage-by-rep.sql` |
| Win Rate (90 days) | 30% | ✅ Query Created | `win-rate-90-days.sql` |
| Avg Deal Size (YTD) | $150K | ✅ Query Created | `avg-deal-size-ytd.sql` |
| Sales Cycle Length | ≤60 days | ✅ Query Created | `sales-cycle-length.sql` |
| Deals by Stage (Funnel) | See below | ✅ Query Created | `deals-by-stage-funnel.sql` |
| Deals Closing This Week/Month/Next | - | ✅ Query Created | `deals-closing-soon.sql` |
| Expired Open Deals | 0 | ✅ Query Created | `expired-open-deals.sql` |

**Monthly Funnel Targets:**
| Stage | Monthly Target |
|-------|----------------|
| Meeting Booked | 45 |
| Sales Qualified Lead | 36 |
| Opportunity | 23 |
| Proposal Sent | 22 |
| Active Negotiation | 15 |
| Contract Sent | 9 |
| Closed Won | 7 deals / $500K |

### Phase 3 - AI Deal Scoring

| Metric | Status | Data Source |
|--------|:------:|-------------|
| Hot Deals # / $ | 🔧 Build | AI Deal Scoring |
| Warm Deals # / $ | 🔧 Build | AI Deal Scoring |
| Cold Deals # / $ | 🔧 Build | AI Deal Scoring |

---

## 2_CEO/Biz Dev - Jack

> **Queries:** `queries/ceo-bizdev/` + shared queries from `coo-ops/` and `demand-sales/`
> **Dashboard:** Separate dashboard from COO/CFO
> **Note:** Many metrics are SHARED with COO/CFO but displayed on separate dashboards

### 📊 Query Coverage Summary

| Category | Have | Need | Phase 4 |
|----------|:----:|:----:|:-------:|
| Phase 1 (PRIMARY) | 1 | 0 | 0 |
| Phase 2 (Secondary) | 6 | 1 | 1 |
| **TOTAL** | **7** | **1** | **1** |

**✅ AVAILABLE (use shared queries):**
- Revenue vs Target → Existing BigQuery view
- Pipeline Coverage → `queries/demand-sales/pipeline-coverage-by-rep.sql`
- Customer Concentration → `queries/coo-ops/top-customer-concentration.sql`
- Working Capital → `queries/coo-ops/working-capital.sql`
- Months of Runway → `queries/coo-ops/months-of-runway.sql`
- Total Unspent Contract $ → `HS_QBO_GMV_Waterfall` (existing view)

**📅 PHASE 4 (1 metric):**
- Cash Position → SimpleFin integration (client ready in `chief-of-staff`)

**🔧 STILL NEED (1 metric):**
- New Target Accounts (needs HubSpot property verification)

### PRIMARY Metrics (Phase 1)

| Metric | Target | Status | Query File | Why It Matters |
|--------|--------|:------:|------------|----------------|
| **Revenue vs Target** | $10M | ✅ Ready | Existing BigQuery view | Primary measure of business growth. |

### SECONDARY Metrics (Phase 2)

| Metric | Target | Status | Query File | Why It Matters |
|--------|--------|:------:|------------|----------------|
| New Target Accounts | TBD | 🔍 Verify | - | Sales effectiveness at new business. |
| Pipeline Coverage | 6.0x | ✅ Query Created | `demand-sales/pipeline-coverage-by-rep.sql` | Predicts hitting targets. |
| Customer Concentration | <30% | ✅ Query Created | `coo-ops/top-customer-concentration.sql` | 41% HEINEKEN = existential risk. |
| **Cash Position** | >$500K | 📅 Phase 4 | `coo-ops/cash-position.md` | Immediate liquidity. (SimpleFin) |
| **Working Capital** | >$1M | ✅ Query Created | `coo-ops/working-capital.sql` | Operational buffer. |
| **Months of Runway** | >12 mo | ✅ Query Created | `coo-ops/months-of-runway.sql` | Critical for board. |
| Pipeline Coverage (3 methods) | - | ✅ Ready | BigQuery views | Unweighted, HubSpot, AI Weighted. |
| Total Unspent Contract $ | - | ✅ Ready | `HS_QBO_GMV_Waterfall` | Future revenue visibility. |

---

## 3_COO/Ops/Finance - Deuce

> **Queries:** `queries/coo-ops/`
> **Dashboard:** Separate dashboard from CEO (COO/CFO Dashboard)
> **Shared With:** CEO/Biz Dev (Jack) - Cash, Runway, Working Capital, Concentration

### 📊 Query Coverage Summary

| Category | Have | Need | Phase 4 |
|----------|:----:|:----:|:-------:|
| Phase 1 (PRIMARY) | 2 | 0 | 0 |
| Phase 2 (Secondary) | 4 | 0 | 1 |
| Phase 3 | 1 | 3 | 0 |
| **TOTAL** | **7** | **3** | **1** |

**✅ CREATED (8 files):**
- `take-rate.sql` - PRIMARY (45% target)
- `invoice-collection-rate.sql` - PRIMARY (95% target)
- `overdue-invoices.sql` - Target: 0
- `working-capital.sql` - Shared with CEO (>$1M target)
- `months-of-runway.sql` - Shared with CEO (>12 mo target)
- `top-customer-concentration.sql` - Shared with CEO (<30% target)
- `net-revenue-gap.sql` - Unspent contracts vs goal
- `factoring-capacity.sql` - >$400K target
- `README.md`

**📅 PHASE 4 (1 metric):**
- Cash Position → SimpleFin integration (client exists in `chief-of-staff` project)

**🔧 STILL NEED (3 metrics):**
- Operating Expenses vs Budget
- Bill Payment Timeliness
- Current Assets (can derive from working-capital.sql)

### PRIMARY Metrics (Phase 1)

| Metric | Target | Status | Query File | Why It Matters |
|--------|--------|:------:|------------|----------------|
| **Take Rate %** | 45% | ✅ Query Created | `take-rate.sql` | Unit economics. Below 45% = problems at scale. |
| Invoice Collection Rate | 95% | ✅ Query Created | `invoice-collection-rate.sql` | Cash flow health. |

### SECONDARY Metrics (Phase 2)

| Metric | Target | Status | Query File |
|--------|--------|:------:|------------|
| Net Revenue Gap | - | ✅ Query Created | `net-revenue-gap.sql` |
| Available Factoring Capacity | >$400K | ✅ Query Created | `factoring-capacity.sql` |
| Overdue Invoices Count & $ | 0 | ✅ Query Created | `overdue-invoices.sql` |
| Total Unspent Contract $ | - | ✅ Ready | `HS_QBO_GMV_Waterfall` (existing view) |
| Cash Position | >$500K | 📅 Phase 4 | `cash-position.md` (SimpleFin - client ready) |

### Phase 3 Metrics

| Metric | Target | Status | Query File |
|--------|--------|:------:|------------|
| Top Customer % Revenue | <30% | ✅ Query Created | `top-customer-concentration.sql` |
| Operating Expenses vs Budget | - | 🔧 Build | - |
| Bill Payment Timeliness | 95% | 🔧 Build | - |
| Current Assets | - | 🔧 Build | (derivable from `working-capital.sql`) |
| Contract Health Distribution | - | ✅ Ready | GMV Waterfall (existing view) |

### Shared Metrics with CEO/Biz Dev

| Metric | Query File | Also Shows On |
|--------|------------|---------------|
| Working Capital | `working-capital.sql` | CEO Dashboard |
| Months of Runway | `months-of-runway.sql` | CEO Dashboard |
| Top Customer Concentration | `top-customer-concentration.sql` | CEO Dashboard, Company Health |
| Cash Position | `cash-position.md` | CEO Dashboard |

---

## 4_Supply - Ian Hong

> **Queries:** `queries/supply/`
> **HubSpot Dashboard:** [Supply Pipeline](https://app.hubspot.com/reports-dashboard/6699636/view/18349412)

### 📊 Query Coverage Summary

| Category | Have | Need | Blocked |
|----------|:----:|:----:|:-------:|
| Phase 1 (PRIMARY) | 1 | 0 | 0 |
| Phase 2 (Secondary) | 5 | 0 | 1 |
| Phase 3 | 0 | 5 | 1 |
| Phase 4 | 1 | 2 | 1 |
| **TOTAL** | **7** | **7** | **3** |

**✅ CREATED (7 files):**
- `new-unique-inventory.sql` - PRIMARY metric
- `weekly-contact-attempts.sql`
- `meetings-booked-mtd.sql`
- `pipeline-coverage-by-event-type.sql`
- `supply-funnel.sql`
- `listings-published-per-month.sql`
- `README.md`

**⛔ BLOCKED (3 metrics):**
- Lead Queue Runway → Needs **Smart Lead API**
- New contacts sequenced → Needs **Smart Lead API**
- Total Limited Capacity → Needs `mongodb.report_datas` Fivetran sync

**🔧 STILL NEED (7 metrics):**
- Onboarded in last 7 days
- Onboarding (days in stage)
- Upcoming Meetings next 7 days
- Meetings held in last 7 days
- Contacts >14 days Supply Target
- Q1 New Inventory Value
- Total Yearly Capacity (query exists, needs deployment)

### HubSpot Property Names (Extracted from Dashboard)

| Property | Description |
|----------|-------------|
| `date_attempted_to_contact` | When first contact attempt was made |
| `date_converted_meeting_booked` | When meeting was booked |
| `date_converted_sql` | When became SQL (Sales Qualified Lead) |
| `date_converted_sal` | When became SAL (Sales Accepted Lead) |
| `date_converted_onboarded` | When onboarding completed |
| `onboarded_at` | Final onboard timestamp |
| `closedate` | Deal close date |

### PRIMARY Metrics (Phase 1)

| Metric | Target | Status | Query File | Why It Matters |
|--------|--------|:------:|------------|----------------|
| **New Unique Inventory** | 16/qtr | ✅ Query Created | `new-unique-inventory.sql` | TAM expansion. More inventory = higher close rates. |

### SECONDARY Metrics (Phase 2)

| Metric | Target | Status | Query File |
|--------|--------|:------:|------------|
| Weekly Contact Attempts | 600/week | ✅ Query Created | `weekly-contact-attempts.sql` |
| Meetings Booked (MTD) | 24/month | ✅ Query Created | `meetings-booked-mtd.sql` |
| **Lead Queue Runway** | 30 days | ⛔ Blocked | `lead-queue-runway.md` (needs Smart Lead API) |
| Pipeline Coverage by Event Type | 3x | ✅ Query Created | `pipeline-coverage-by-event-type.sql` |
| Meeting → SQL → Proposal → Won Funnel | See goals | ✅ Query Created | `supply-funnel.sql` |
| Listings Published per Month | - | ✅ Query Created | `listings-published-per-month.sql` |

**Lead Queue Runway Calculation (from Smart Lead):**
```
Lead Queue Runway = Leads in Queue / Avg Leads Contacted Per Day

Components needed from Smart Lead API:
- Leads actively sequencing
- Leads enrolled but not yet sequencing
- Leads staged for next sequence
- Send capacity (~600 emails/day)
```

**Supply Funnel Goals (Monthly Targets):**
| Stage | Monthly Target |
|-------|----------------|
| Attempted to Contact | 60 |
| Connected | 60 |
| Meeting Booked | 24 |
| Proposal Sent | 16 |
| Onboarded | 16 |
| Won (target accounts) | 4 |

### Phase 3 Metrics

| Metric | Status | Data Source |
|--------|:------:|-------------|
| Onboarded in last 7 days | 🔧 Build | HubSpot Dashboard |
| Onboarding (days in stage) | 🔧 Build | HubSpot Dashboard |
| Upcoming Meetings next 7 days | 🔧 Build | HubSpot Dashboard |
| Meetings held in last 7 days | 🔧 Build | HubSpot Dashboard |
| New contacts sequenced | 🔧 Build | Smart Lead API |
| Contacts >14 days Supply Target | 🔧 Build | HubSpot Dashboard |

### Phase 4 Metrics

| Metric | Target | Status | Data Source |
|--------|--------|:------:|-------------|
| Total Limited Capacity | - | ⛔ Blocked | `mongodb.report_datas` (waiting Fivetran sync) |
| Listings Published per Month | - | 🔧 Build | `mongodb.audience_listings` |
| Total Yearly Capacity | - | ✅ Ready | BigQuery |
| Capacity by Event Type | - | ✅ Ready | BigQuery |
| Q1 New Inventory Value | $1.162M | 🔧 Build | BigQuery |

### Supply Data Sources

| Source | What It Provides | Integration Status |
|--------|------------------|-------------------|
| HubSpot | Funnel metrics, meetings, contacts, pipeline | ✅ Available via BigQuery |
| Google Sheets | Inventory by event type, KPI goals | ✅ Manual reference |
| **Smart Lead** | Outbound sequences, lead queue, send capacity | ⛔ **API integration needed** |
| BigQuery `mongodb.report_datas` | Yearly capacity by event type | ⛔ Waiting Fivetran sync |
| BigQuery `mongodb.audience_listings` | Published listings | ✅ Available |

---

## 5_Marketing

> **Queries:** `queries/marketing/`
> **HubSpot Dashboard:** [Marketing Dashboard](https://app.hubspot.com/reports-dashboard/6699636/view/18337876)

### 📊 Query Coverage Summary

| Category | Have | Need | Blocked |
|----------|:----:|:----:|:-------:|
| Phase 1 (PRIMARY) | 1 | 0 | 0 |
| Phase 2 (Secondary) | 4 | 1 | 1 |
| Phase 5 (External APIs) | 0 | 2 | 1 |
| **TOTAL** | **5** | **3** | **2** |

**✅ CREATED (5 files):**
- `marketing-influenced-pipeline.sql` - PRIMARY metric (50/50 FT+LT attribution)
- `mql-to-sql-conversion.sql` - 30% target
- `attribution-by-channel.sql` - First Touch + Last Touch by channel
- `marketing-leads-funnel.sql` - ML → MQL → SQL
- `README.md`

**⛔ BLOCKED (2 metrics):**
- Cost per MQL → Needs **spend data integration** (where does ad spend live?)
- Website Traffic → Needs **GA4 API integration**

**🔧 STILL NEED (3 metrics):**
- Marketing-Sourced Revenue % (can build from existing data)
- Content Engagement
- Email Open Rate (HubSpot email stats)

### PRIMARY Metrics (Phase 1)

| Metric | Target | Status | Query File | Why It Matters |
|--------|--------|:------:|------------|----------------|
| **Mktg-Influenced Pipeline** | TBD | ✅ Query Created | `marketing-influenced-pipeline.sql` | Quantifies marketing's contribution. |

**Attribution Model:**
```
Formula: (First Touch + Last Touch) / 2
- First Touch (FT): How the lead originally found us
- Last Touch (LT): Final interaction before deal creation
- Each touch receives 50% credit

MARKETING CHANNELS (10):
Direct Traffic, Paid Search, Paid Social, Organic Social,
Organic Search, Event, Email Marketing, Other Campaigns,
Referrals, General Referral
```

### SECONDARY Metrics (Phase 2)

| Metric | Target | Status | Query File |
|--------|--------|:------:|------------|
| ML → MQL → SQL Funnel | - | ✅ Query Created | `marketing-leads-funnel.sql` |
| MQL → SQL Conversion | 30% | ✅ Query Created | `mql-to-sql-conversion.sql` |
| First Touch Attribution $ | - | ✅ Query Created | `attribution-by-channel.sql` |
| Last Touch Attribution $ | - | ✅ Query Created | `attribution-by-channel.sql` |
| Marketing Leads | - | ✅ Query Created | `marketing-leads-funnel.sql` |
| Cost per MQL | - | 📝 Define | Needs spend data integration |
| Marketing-Sourced Revenue % | - | 🔧 Build | BigQuery |

### Phase 5 Metrics (External APIs)

| Metric | Target | Status | Data Source |
|--------|--------|:------:|-------------|
| Website Traffic | - | 🔧 Build | GA4 integration |
| Content Engagement | - | 🔧 Build | HubSpot / GA |
| Email Open Rate | 25% | ✅ Ready | HubSpot email |

---

## 6_Accounting

### PRIMARY Metrics (Phase 1)

| Metric | Target | Status | Data Source | Why It Matters |
|--------|--------|:------:|-------------|----------------|
| **Invoice Collection %** | 95% | ✅ Ready | QuickBooks AR Aging | Cash flow health. Slow collection = working capital strain. |

### SECONDARY Metrics (Phase 2)

| Metric | Target | Status | Data Source |
|--------|--------|:------:|-------------|
| Invoices Paid Within 7 Days % | - | 🔧 Build | BigQuery |
| Overdue Invoices Count & $ | 0 | 🔧 Build | BigQuery (QBO) |
| Average Days to Collection | <7 days | 🔧 Build | BigQuery |
| Bills Overdue by Status | 0 | 🔧 Build | BigQuery (MongoDB) |
| Invoice Variance (Count & $) | $0 | ✅ Ready | Reconciliation query #4 |
| Bill Variance (Count & $) | $0 | ✅ Ready | Reconciliation query |
| Available Factoring Capacity | >$400K | 🔧 Build | QBO Balance Sheet |

### Phase 4 Metrics (External APIs)

| Metric | Target | Status | Data Source |
|--------|--------|:------:|-------------|
| Bills Pending Approval | - | 🔧 Build | Bill.com API |
| Bills Missing W-9 | 0 | ✅ Ready | QuickBooks vendor report |
| Vendors Not Onboarded (with approved offer) | 0 | 🔧 Build | Bill.com API |

---

## 7_Demand AM

### PRIMARY Metrics (Phase 1)

| Person | Metric | Target | Status | Data Source | Why It Matters |
|--------|--------|--------|:------:|-------------|----------------|
| **Char Short** | Contract Spend % | 95% | 🔧 Build | BigQuery (contracts + spend) | Customer success. Low spend = churn risk. |
| **Victoria** | Time to Fulfill | ≤30 days | 🔧 Build | BigQuery (dates) | Faster = happier customers. |
| **Claire** | NPS Score | 75% | 🔧 Build | Survey tool + HubSpot | Leading indicator of retention. |
| **Francisco** | Offer Acceptance % | 90% | ✅ Query Created | `demand-am/offer-acceptance-rate.sql` | Platform-market fit signal. |

### SECONDARY Metrics

| Metric | Target | Status | Data Source |
|--------|--------|:------:|-------------|
| Customer Health Score | - | 📝 Define | BigQuery + HubSpot (composite) |
| Upsell Pipeline | - | ✅ Ready | HubSpot deal type filter |

---

## 8_Supply AM - Ashton

### PRIMARY Metrics (Phase 1)

| Metric | Target | Status | Data Source | Why It Matters |
|--------|--------|:------:|-------------|----------------|
| **NRR Top Supply Users** | 110% | ✅ Query Created | `supply-am/nrr-top-supply-users-financial.sql` ⭐ | Key supply relationships growing or shrinking. |

**Note:** Two query versions exist:
- `nrr-top-supply-users.sql` — Offer-based (uses `Supplier_Metrics` view, simple but no credits)
- `nrr-top-supply-users-financial.sql` ⭐ **RECOMMENDED** — Financial-based (uses QBO bills linked via bill_number, includes credits, proper transaction timing)

### SECONDARY Metrics

| Metric | Target | Status | Data Source |
|--------|--------|:------:|-------------|
| Top Partner Retention Rate | 90% | 🔧 Build | BigQuery (partners) |
| Partner Satisfaction Score | 4.5/5 | 📝 Define | Survey / Manual |
| Avg Revenue per Partner | - | 🔧 Build | BigQuery (revenue) |
| Avg Ticket Response Time | ≤16hrs | 🔧 Build | Zendesk/Intercom API |
| Open Tickets | - | 🔧 Build | Zendesk/Intercom API |

---

## 10_Engineering

### PRIMARY Metrics (Phase 1)

| Person | Metric | Target | Status | Data Source | Why It Matters |
|--------|--------|--------|:------:|-------------|----------------|
| **Arbind** | Features Fully Scoped | 5/mo | 🔧 Build | Asana / GitHub | Unscoped features = mid-sprint chaos. |
| **Mateus** | BizSup Completed | 10/mo | 🔧 Build | Asana (BizSup project) | Slow BizSup = frustrated sales/AM. |
| **Anderson** | PRDs Generated | 3/mo | 🔧 Build | Asana / Notion | No PRDs = no roadmap clarity. |
| **Anderson** | FSDs Generated | 2/mo | 🔧 Build | Asana / Notion | No FSDs = ambiguous implementation. |
| **Lucas** | Feature Releases | TBD | 📝 Define | GitHub | Delivery velocity. |

### SECONDARY Metrics

| Metric | Target | Status | Data Source |
|--------|--------|:------:|-------------|
| Sprint Velocity | consistent | 🔧 Build | Asana / Jira |
| Bug Count (Open) | <10 | 🔧 Build | GitHub issues API |
| Deploy Frequency | 3+/week | 🔧 Build | GitHub Actions API |
| Incidents (MTD) | 0 | 📝 Define | PagerDuty / Manual |
| Tech Debt Tickets | - | 🔧 Build | Asana / GitHub |

---

## Implementation Phases

### Phase 1: Company Health + Primary Person Metrics (CURRENT)

**Goal:** Launch basics - one metric per person for accountability.

| Category | Count | Status |
|----------|-------|--------|
| Company Health | 7 cards | 5 ✅, 2 🟡 Needs Approval |
| Person PRIMARY | ~15 metrics | Mixed - see department sections |

**Immediate Actions:**
1. [ ] Deuce approve Supply NRR calculation
2. [ ] Deuce approve Time to Fulfill calculation
3. [ ] Define "sellable" inventory criteria (PRD)
4. [ ] Verify metric definitions with Danny (Pipeline Coverage definition)
5. [ ] Verify metric definitions with Ian (New Unique Inventory)
6. [ ] Verify metric definitions with Francisco (Offer Acceptance)

---

### Phase 2: Secondary Metrics + CFO Dashboard

**Goal:** Add secondary metrics and critical CFO visibility.

| Category | Priority | Notes |
|----------|----------|-------|
| CFO Metrics | 🔴 HIGH | Cash, Runway, Working Capital |
| Sales Secondary | 🟡 MED | Funnel metrics, Deal aging |
| Company Secondary | 🟡 MED | Logo Retention, Concentration, Churn |
| AM Secondary | 🟢 LOW | Health scores, Upsell |

---

### Phase 3: Deep Dive / Drill-Downs

**Goal:** Click-through details for Phase 1/2 metrics.

- Revenue by customer
- Pipeline by rep by stage
- NRR by segment
- Contract spend by customer
- Supply onboarding funnel

---

### Phase 4: External API Integrations

**Goal:** Connect non-BigQuery data sources.

| Integration | Metrics | Status | Notes |
|-------------|---------|:------:|-------|
| **SimpleFin** | Cash Position | 🟡 **Ready to Integrate** | Client exists in `chief-of-staff` project |
| Bill.com | Bills pending, vendor onboarding | 🔴 Not Started | |
| Zendesk/Intercom | Ticket response time | 🔴 Not Started | |
| HubSpot (deep) | Meetings, activities | 🟡 Partial | |
| Smart Lead | Lead Queue Runway | 🔴 Not Started | Required for Supply metrics |

**SimpleFin Integration Details:**
- Client: `/Users/deucethevenowworkm1/Projects/chief-of-staff/integrations/simplefin_client.py`
- Setup: `/Users/deucethevenowworkm1/Projects/chief-of-staff/scripts/setup_simplefin.py`
- Cost: $1.50/month
- Steps: Get account → Connect bank → Claim token → Add `SIMPLEFIN_ACCESS_URL` to env

---

### Phase 5: Engineering Metrics (API Heavy)

**Goal:** Engineering team accountability.

| Integration | Metrics | Status |
|-------------|---------|:------:|
| Asana API | BizSup, PRDs, FSDs, Sprints | 🔴 Not Started |
| GitHub API | Features, Bugs, Deploys | 🔴 Not Started |
| Notion API | PRDs, FSDs | 🔴 Not Started |
| GA4 | Website traffic | 🔴 Not Started |

---

## Data Architecture

### BigQuery Connection

```
Project: stitchdata-384118
Dataset: App_KPI_Dashboard
Credentials: ~/.config/bigquery-mcp-key.json
```

### Key Views (Deployed)

| View | Purpose |
|------|---------|
| `cohort_retention_matrix_by_customer` | Demand NRR by cohort |
| `net_revenue_retention_all_customers` | Customer concentration, NRR detail |
| `customer_development` | Customer count, logo retention, churn |
| `Supplier_Metrics` | Supply NRR, payouts |
| `Upfront_Contract_Spend_Query` | Contract spend % |
| `Days_to_Fulfill_Contract_Spend_From_Close_Date` | Time to fulfill |
| `HS_QBO_GMV_Waterfall` | Contract health, unspent $ |
| `pipeline_coverage_historical` | Historical pipeline analysis |
| `organizer_recap_NPS_score` | NPS scores |

### External Data Sources Needed

| Source | Purpose | Integration | Department |
|--------|---------|-------------|------------|
| **Smart Lead API** | Lead queue runway, sequences, send capacity | Phase 4 | Supply |
| SimpleFin API | Cash balance | Phase 4 | CEO/COO |
| Bill.com API | Bills status, vendor onboarding | Phase 4 | Accounting |
| Zendesk/Intercom | Ticket response times | Phase 4 | Supply AM |
| Asana API | Engineering tasks, BizSup | Phase 5 | Engineering |
| GitHub API | PRs, deploys, PRDs, FSDs | Phase 5 | Engineering |
| Notion API | PRDs, FSDs | Phase 5 | Engineering |
| Shortcut API | Sprint velocity, stories | Phase 5 | Engineering |
| GA4 | Web traffic | Phase 5 | Marketing |

---

## Security Implementation

### Tab-Based Access with Email Whitelist

```python
ROLE_MAPPING = {
    "executive": ["jack@recess.is", "deuce@recess.is"],
    "demand_sales": ["andy@recess.is", "danny@recess.is", "katie@recess.is"],
    "demand_am": ["char@recess.is", "victoria@recess.is",
                  "claire@recess.is", "francisco@recess.is"],
    "supply": ["ian@recess.is"],
    "supply_am": ["ashton@recess.is"],
    "accounting": ["accounting@recess.is"],
    "engineering": ["arbind@recess.is", "mateus@recess.is",
                    "anderson@recess.is", "lucas@recess.is"]
}

TAB_ACCESS = {
    "executive": ["*"],  # All tabs
    "demand_sales": ["company_health", "sales"],
    "demand_am": ["company_health", "demand_am"],
    "supply": ["company_health", "supply"],
    "supply_am": ["company_health", "supply_am"],
    "accounting": ["company_health", "accounting"],
    "engineering": ["company_health", "engineering"]
}
```

---

## Gotchas & Learnings

### Critical Issues Discovered

1. **customer_development has multiple rows per customer**
   - Must use `COUNT(DISTINCT customer_id)`

2. **NRR key mismatch**
   - Dashboard expected `nrr`, BigQuery returns `demand_nrr`

3. **Pipeline uses hs_forecast_amount**
   - NOT stage probability - uses sales rep confidence

4. **Logo Retention at 37% is a RED FLAG**
   - Verify calculation before alarming the business

5. **Engineering metrics require external APIs**
   - Asana, GitHub, Notion - not BigQuery

6. **Marketing attribution uses FT+LT/2**
   - Each touch gets 50% credit
   - Only counts 10 specific marketing channels

---

## Metric Count Summary

| Department | Phase 1 PRIMARY | Phase 2+ Secondary | Total |
|------------|-----------------|-------------------|-------|
| Company Health | 7 | 4 | 11 |
| Sales | 4 | ~20 | ~24 |
| CEO/Biz Dev | 1 | 9 | 10 |
| COO/Ops/Finance | 2 | 15 | 17 |
| Supply | 1 | 20 | 21 |
| Marketing | 1 | 12 | 13 |
| Accounting | 1 | 12 | 13 |
| Demand AM | 4 | 2 | 6 |
| Supply AM | 1 | 5 | 6 |
| Engineering | 5 | 5 | 10 |
| **TOTAL** | **27** | **~104** | **~131** |

---

## Immediate TODOs

1. [ ] **Deuce approve** Supply NRR calculation
2. [ ] **Deuce approve** Time to Fulfill calculation
3. [ ] **Define** "sellable" inventory criteria (PRD)
4. [ ] **Verify** with owners: Danny (Pipeline), Ian (Inventory), Francisco (Offers)
5. [ ] **Build** CFO metrics (Cash, Runway, Working Capital)
6. [ ] **Commit** this documentation to GitHub

---

## Change Log

| Date | Change |
|------|--------|
| 2026-02-03 | Created master implementation plan |
| 2026-02-03 | Added security/permissions as core requirement |
| 2026-02-03 | Corrected Supply NRR / Time to Fulfill status (in UI, not approved) |
| 2026-02-03 | Pipeline target updated 3x → 6x |
| 2026-02-03 | **COMPLETE SYNC** from all 10 Google Sheet tabs |
| 2026-02-03 | Added ~131 total metrics across all departments |
| 2026-02-03 | Added Marketing attribution model (FT+LT/2) |
| 2026-02-03 | Added Engineering team members (Arbind, Mateus, Anderson, Lucas) |
| 2026-02-03 | Documented external API dependencies |
| 2026-02-05 | Created `supply-am/nrr-top-supply-users.sql` - Supply NRR at 99.9% (below 110% target) |
| 2026-02-05 | Created `demand-am/offer-acceptance-rate.sql` - Acceptance rate at 58.2% (below 90% target) |
| 2026-02-05 | Created `supply-am/nrr-top-supply-users-financial.sql` ⭐ RECOMMENDED - Financial-based NRR with bill linkage, credits, and proper transaction timing |

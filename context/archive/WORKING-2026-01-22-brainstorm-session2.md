# Session Handoff - 2026-01-22 (Full)

## 🎯 MISSION

Design and build a unified company KPI dashboard for Recess (two-sided marketplace connecting CPG brands with events/venues). The dashboard must give each of ~18 people ONE metric they own, automate data pulls from multiple sources, replace manual Asana goal updates, and be prescriptive for non-analytical users. Security requirement: not on public web.

**North Star Metric:** Revenue (not GMV)

## 📍 CURRENT STATE

- **Phase:** Brainstorming / Department Discovery (5 of 10 departments captured)
- **Just Completed:** Accounting/Finance department metrics (dual dashboard: Operations + CFO)
- **In Progress:** Supply Account Mgmt is next
- **Status:** On track — detailed metrics captured for 5 departments, 5 SQL queries documented
- **Skill Used:** superpowers:brainstorming (one question at a time, multiple choice preferred)

## ✅ COMPLETED WORK

### Departments Captured (5/10):

1. **Supply (Ian Hong)** — Owned: New Unique Inventory Added
   - Funnel metrics, pipeline coverage by event type, lead queue health
   - Data: HubSpot + Sheets + Smart Lead → all in BigQuery

2. **Demand Sales (Andy, Danny, Katie)** — Owned: NRR (Andy), Pipeline Coverage 3x (sellers)
   - AI deal scoring, rep scorecard, stage-level goals needed
   - Top-of-funnel lead inventory problem identified

3. **Demand Account Mgmt (Char's team)** — Owned: Contract Spend % of Goal
   - Already has "one metric per owner" model (template for others)
   - KPI scorecard with weekly tracking, Land & Expand tracking

4. **Marketing (1 person)** — Owned: Marketing-Influenced Pipeline
   - Formula: (First Touch + Last Touch) / 2 (each gets 50% credit)
   - No formal target yet — need historical baseline from BigQuery
   - Focused on demand side only (not supply)

5. **Accounting/Finance** — TWO DASHBOARDS:
   - **Operations Dashboard (daily):**
     - Invoice Collection Rate (target 95%), 7-day payment rate (TBD)
     - Bills overdue by Bill.com status (Approved/Pending/W-9 Missing/Not Onboarded)
     - Factoring: Balance, Reserves, Limit ($1M), Capacity (🟢>$400K/🟡$200-400K/🔴<$200K), Fees (P&L Finance Charges)
     - Data Integrity: Invoice Variance (qty + $), Bill Variance (qty + $) — all should be 0
   - **CFO Dashboard (strategic):**
     - Runway: Cash, Working Capital, Operating Burn, Months of Runway
     - Concentration Risk: Top 1 customer at 40.9% (target <30%) — CRITICAL
     - Retention: Logo 37% (target >50%), NRR 107% (target >110%)
     - Pipeline Coverage: 3 methods (Unweighted >3x, HubSpot Weighted >1.5x, AI Weighted >1.5x) vs Total Quota from HubSpot company property
     - Unspent Contracts: Total remaining_gross, Contract Health (On Track/At Risk/Off Track)
     - Revenue Forecast by Month: from `App_KPI_Dashboard.HS_QBO_GMV_Waterfall`
     - Seasonality: Q4 at 10% (target >18%)
     - Budget vs Actual: Company-wide (not by department)
     - LTV by Tenure: 4-year customers = $1.23M avg (42x year 1)

### SQL Queries Documented (5):
1. Sales Manager Quota & Pipeline Coverage Report
2. Net Revenue Retention Tracker
3. Funnel Math Calculator (proposed)
4. QBO to Platform Invoice Reconciliation (Delta should = 0)
5. Unspent Contracts / GMV Waterfall (existing BigQuery view: `App_KPI_Dashboard.HS_QBO_GMV_Waterfall`)

### Dashboard Types Identified (9):
CEO/COO Executive, CFO Dashboard, Core Company KPIs, Supply Scorecard, Demand Sales Scorecard, Demand AM Scorecard, Marketing Scorecard, Accounting Operations, Department Scorecards

## 📋 TODO - Continue These Tasks

- [ ] **HIGH:** Gather Supply Account Mgmt metrics (1 person, venue retention/expansion)
- [ ] **HIGH:** Gather Engineering/Product metrics (4 people, VP + 3 devs)
- [ ] **HIGH:** Gather AI Automations metrics (1 person)
- [ ] **MED:** Gather CEO/Business Dev (Jack) metrics
- [ ] **MED:** Design Core Company KPI Dashboard (replaces Asana manual updates)
- [ ] **MED:** Design CEO/COO executive dashboard
- [ ] **MED:** Define technology stack and security approach
- [ ] **MED:** Design metric ownership model (one metric per person, all 18 people)
- [ ] **LOW:** Query BigQuery for historical marketing-influenced revenue %
- [ ] **LOW:** Query BigQuery for historical invoice payment rate within 7 days
- [ ] **LOW:** Write final design document

## 🏗️ TECHNICAL DECISIONS

| Decision | Rationale |
|----------|-----------|
| **BigQuery = single query layer** | All sources (HubSpot, QBO, MongoDB, Bill.com) sync via Fivetran. Dashboard never queries sources directly. |
| **Schema prefixes indicate origin** | `src_fivetran_qbo.*`, `src_fivetran_hubspot.*`, `mongodb.*`, `App_KPI_Dashboard.*` |
| **Revenue not GMV** as North Star | Business decision — Revenue is what matters |
| **Marketing attribution: (FT+LT)/2** | Linear attribution, each touch gets 50% credit |
| **3 pipeline weightings** | Unweighted (ceiling), HubSpot (process), AI (quality) — each tells different story |
| **Factoring alerts** | 🟢 >$400K / 🟡 $200-400K / 🔴 <$200K remaining capacity |
| **Invoice collection target: 95%** | Plus separate 7-day payment rate tracking (need historical baseline) |
| **Reconciliation: both qty AND $** | High count/low $ = process issue; Low count/high $ = investigate immediately |
| **Budget vs Actual: company-wide** | Not broken down by department |
| **Prescriptive > Descriptive** | Traffic lights + action items, not just data display |
| **Dashboard NOT on public web** | Security requirement — approach TBD |

## 🔍 KEY DISCOVERIES

1. **AM team is the template** — Already has "one metric per owner" with weekly tracking. Replicate for all departments.
2. **Top-of-funnel is the constraint** — Both Supply and Demand have lead inventory problems.
3. **Customer concentration is existential** — 41% from HEINEKEN, 59% from top 2. Must track prominently.
4. **LTV explodes after year 3** — 4-year customers avg $1.23M (42x year 1). Retention through years 2-3 is critical.
5. **Q4 is consistently weakest** — Dropped from 26% to 10% of annual revenue over 3 years.
6. **Data architecture is clean** — Everything in BigQuery already, just needs dashboard layer on top.

## ⚠️ ISSUES & BLOCKERS

- **No historical baseline for marketing attribution** — Need to query BigQuery for % of pipeline that was marketing-influenced
- **No historical baseline for 7-day payment rate** — Need to query BigQuery for collection speed
- **Technology stack not decided** — Need to evaluate tools that can query BigQuery securely
- **Smart Lead data** — Unclear if it syncs to BigQuery (need to verify for Supply lead queue metrics)
- **Remaining 5 departments** — Need user input to capture metrics for Supply AM, Engineering, AI Automations, CEO

## 📁 KEY FILES

```
context/plans/2026-01-22-dashboard-brainstorm.md   - COMPREHENSIVE brainstorm notes (all dept metrics, SQL queries, architecture)
context/WORKING-2026-01-22-dashboard-design.md     - Previous session handoff (outdated by this one)
context/PROGRESS.md                                - Development progress log
context/LEARNINGS.md                               - 5 learnings logged this session
.claude/CLAUDE.md                                  - Project config and workflow
```

**External References:**
```
GMV Health Analysis: ~/Downloads/Private & Shared 4/GMV_Health_Analysis_Complete_Report_Jan2026_v2*.md
Board Deck: ~/Downloads/Q32025 Board Meeting Deck.pdf
BigQuery View: stitchdata-384118.App_KPI_Dashboard.HS_QBO_GMV_Waterfall
```

## 🔧 ENVIRONMENT

- **Working directory:** `/Users/deucethevenowworkm1/Projects/company-kpi-dashboard`
- **BigQuery project:** `stitchdata-384118`
- **Key BigQuery schemas:** `src_fivetran_qbo`, `src_fivetran_hubspot`, `mongodb`, `App_KPI_Dashboard`
- **MCP tools available:** BigQuery, HubSpot, QuickBooks, Notion, Google Drive, Playwright
- **Platform:** app.recess.is (internal tool with payout board)

## 💡 NEXT SESSION SHOULD

1. **Continue brainstorming** — Gather metrics for Supply Account Mgmt, Engineering/Product, AI Automations, CEO
2. **Use brainstorming skill** — One question at a time, multiple choice preferred
3. **Read the full brainstorm doc first** — `context/plans/2026-01-22-dashboard-brainstorm.md` has all context
4. **After all 10 departments captured** — Design technology stack, security approach, metric ownership matrix
5. **Watch for scope creep** — Stay focused on department discovery before jumping to implementation

## 📝 CRITICAL VERBATIM CONTEXT

**Company:** Recess — Two-sided marketplace (CPG brands ↔ events/venues for product sampling)
**~18 people, 10 departments**
**Key People:**
- Jack (CEO), Deuce (COO/user)
- Andy Cooper (Sales Leader), Danny Sears, Katie (Sellers)
- Char Short (AM Director), Victoria, Claire, Francisco, Ashton
- Ian Hong (Supply)

**Existing BigQuery datasets:**
- `src_fivetran_qbo.invoice`, `invoice_line`, `credit_memo`, `credit_memo_line`, `customer`, `item`, `account`
- `src_fivetran_hubspot.deal`, `company`, `owner`, `deal_company`, `deal_pipeline`
- `mongodb.invoices`, `mongodb.invoice_line_items`
- `App_KPI_Dashboard.HS_QBO_GMV_Waterfall` (existing view for GMV waterfall)

**Key Business Metrics:**
- NRR: 107% overall, Target accounts dropped from 165% → 90% in 2025
- Customer count: 96 (2023) → 51 (2025) — 47% reduction
- Top customer: HEINEKEN at 40.9% of revenue ($3.41M of $7.93M)
- Pipeline: $30.7M at 3.9x coverage

## 🧵 CONVERSATION EVOLUTION

- **Original ask:** Continue brainstorming session for company KPI dashboard (picking up from previous session that captured 3 departments)
- **Session focus:** Captured Marketing + Accounting/Finance departments in detail
- **Key evolution:** Accounting expanded from "1 dashboard" → "2 dashboards" (Operations + CFO) as we realized the breadth of needs
- **User preferences:** Wants prescriptive dashboards, all data through BigQuery, specific alert thresholds defined during session

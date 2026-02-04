# Progress Log

> **Purpose:** Append-only log of all development work. Updated after EVERY commit.

---

## Log Entries

<!--
Format for each entry:
### YYYY-MM-DD HH:MM - [ACTION TYPE]

**What:** Brief description of what was done
**Files:** List of files changed
**Tests:** Test status (passed/failed/N/A for analytics)
**Next:** What should happen next

---
-->

### 2026-01-22 - [PROJECT SETUP]

**What:** Initial project structure created
**Files:**
- `.claude/CLAUDE.md`
- `README.md`
- `docs/README.md`
- `queries/README.md`
- `dashboards/README.md`
- `context/` directory with session management files

**Tests:** N/A (initial setup)
**Next:** Define first KPIs and create queries

---

### 2026-01-22 - [BRAINSTORMING SESSION]

**What:** Comprehensive brainstorming session for dashboard requirements
**Duration:** ~2 hours
**Skill Used:** superpowers:brainstorming

**Completed:**
- Captured company structure (18 people, 10 departments)
- Documented 3 departments in full:
  - Supply (Ian Hong) - inventory, funnel, lead queue metrics
  - Demand Account Mgmt (Char's team) - KPI scorecard, contract spend
  - Demand Sales (Andy's team) - pipeline, NRR, quota tracking
- Collected 3 SQL queries:
  - Sales Manager Quota & Pipeline Coverage
  - Net Revenue Retention Tracker
  - Funnel Math Calculator (proposed)
- Identified key problems:
  - Top-of-funnel lead inventory (both Supply and Demand)
  - Scattered data (HubSpot, BigQuery, Sheets, Looker, Smart Lead, Asana)
  - Manual updates required
  - Non-analytical users need prescriptive dashboards

**Key Decisions:**
- North Star = Revenue (not GMV)
- Andy (Sales Leader) owns NRR
- Sellers own Weighted Pipeline Coverage (3x target)
- Dashboard must be prescriptive, not descriptive
- Security: Not on public web

**Files Created:**
- `context/plans/2026-01-22-dashboard-brainstorm.md` - Full session notes (comprehensive)
- `context/WORKING-2026-01-22-dashboard-design.md` - Quick handoff

**Tests:** N/A (requirements gathering)
**Next:**
- Gather remaining 7 departments (Marketing, Accounting, Supply AM, Engineering, AI Automations, CEO)
- Design technology stack
- Create metric ownership matrix (all 18 people)
- Write implementation plan

---

### 2026-01-22 - [BRAINSTORMING SESSION 2]

**What:** Continued brainstorming — captured Marketing + Accounting/Finance departments
**Duration:** ~2 hours
**Skill Used:** superpowers:brainstorming

**Completed:**
- Captured 2 more departments (now 5/10 total):
  - Marketing (1 person) — Marketing-Influenced Pipeline via (FT+LT)/2 attribution
  - Accounting/Finance — DUAL dashboards (Operations + CFO)
- Documented 2 additional SQL queries:
  - QBO to Platform Invoice Reconciliation (Query #4)
  - Unspent Contracts / GMV Waterfall (Query #5)
- Established BigQuery as SINGLE query layer (all sources sync via Fivetran)
- Defined factoring alert thresholds (🟢>$400K / 🟡$200-400K / 🔴<$200K)
- Defined invoice collection target (95%) + 7-day payment rate (needs baseline)
- Captured concentration risk tracking (top customer at 40.9%)
- Defined 3 pipeline coverage methods (Unweighted, HubSpot Weighted, AI Weighted)
- Defined contract health logic (On Track / At Risk / Off Track)
- Removed Customer Segmentation section (deferred)
- Updated data architecture: all "MongoDB" refs → "BigQuery (from MongoDB)"

**Key Decisions:**
- Marketing attribution: (First Touch + Last Touch) / 2
- Accounting needs TWO dashboards (Operations daily + CFO strategic)
- Pipeline coverage: 3 weightings vs Total Quota from HubSpot company property
- Factoring capacity alerts at $400K (yellow) and $200K (red)
- Invoice collection rate target: 95%
- Budget vs Actual: company-wide (not by department)
- BigQuery = only query layer; dashboard never queries source systems directly
- Reconciliation: split into Invoice (qty + $) and Bill (qty + $)

**Files Modified:**
- `context/plans/2026-01-22-dashboard-brainstorm.md` — Multiple sections added/updated
- `context/WORKING-2026-01-22-dashboard-design.md` — Updated with 5 departments
- `context/LEARNINGS.md` — Added 5 learnings
- `context/WORKING-2026-01-22-brainstorm-session2.md` — Created comprehensive handoff

**Tests:** N/A (requirements gathering)
**Next:**
- Gather Supply Account Mgmt metrics (1 person, venue retention/expansion)
- Gather Engineering/Product metrics (4 people, VP + 3 devs)
- Gather AI Automations metrics (1 person)
- Gather CEO/Business Dev (Jack) metrics
- Design Core Company KPI Dashboard
- Define technology stack and security approach

---

### 2026-01-26 - [BRAINSTORMING SESSION 3]

**What:** Continued brainstorming — captured Supply AM, Engineering/Product; designed Core KPI Dashboard; analyzed CEO/COO metrics with CEO Advisor skill
**Skill Used:** superpowers:brainstorming, ceo-advisor

**Completed:**
- Captured 2 more departments (now 7/10 total):
  - Supply AM (Ashton) — NRR of Top Supply Users (Pareto: 80% of revenue)
  - Engineering/Product (VP + 3 devs) — Features Fully Scoped, BizSup throughput, PRD/FSD pipeline, Shortcut metrics
- Designed Core Company KPI Dashboard:
  - Revenue vs Target at top (North Star)
  - Per-person scorecard grouped by department
  - Traffic lights: 🟢🟡🔴⚪ (gray = no target set)
  - Daily refresh
- Added inventory capacity metrics to Supply (mongodb.report_datas, mongodb.audience_listings)
- Analyzed CEO/COO metrics using CEO Advisor skill:
  - Recommended: CEO = New Logos, COO = Gross Margin %
  - Identified leading indicators for revenue prediction
  - Proposed CEO Executive Dashboard structure

**Key Decisions:**
- Engineering metrics require Asana, GitHub, Shortcut APIs (NOT BigQuery)
- "Top Supply Users" = organizers generating 80% of revenue (Pareto)
- Core KPI Dashboard: company health at top + per-person metrics below
- Gray status for metrics without targets yet
- Flask and Streamlit added as technology options to evaluate

**Files Modified:**
- `context/plans/2026-01-22-dashboard-brainstorm.md` — Added Supply AM, Engineering/Product, Core KPI Dashboard design, inventory capacity metrics
- `context/WORKING-2026-01-26-session3.md` — Created session handoff

**Tests:** N/A (requirements gathering)
**Next:**
- Finalize CEO/COO owned metrics
- Design CEO Executive Dashboard with leading indicators
- Gather remaining departments (AI Automations, CEO)
- Define technology stack

---

## 2026-01-27 10:30 - CHECKPOINT - Session Handoff

**What:** Created session handoff for continuity
**Files:**
- `context/WORKING-2026-01-27-1030.md` - created
- `dashboard/app.py` - complete redesign with Recess branding, sidebar nav
- `dashboard/.streamlit/config.toml` - updated to light theme
- `dashboard/data/mock_data.py` - added METRIC_DEFINITIONS with tooltips

**Tests:** Server running at localhost:8501
**Next:** See handoff for TODO list
**Commit:** none (handoff only)

---

## 2026-01-28 10:55 - CHECKPOINT - Session Handoff

**What:** Created session handoff for continuity
**Files:**
- `context/WORKING-2026-01-28-105530.md` - created
- 8 Google Sheets for metric tracking (department tabs)
- 1 Primary Metrics Summary sheet

**Tests:** N/A (documentation session)
**Next:** See handoff for TODO list
**Commit:** none (handoff only)

---

## 2026-01-28 14:32 - CHECKPOINT - Session Handoff

**What:** Updated marketing attribution query and created comprehensive metrics tracker
**Files:**
- `queries/2026-01-28-marketing-attribution-buyer-qtd.sql` - updated (removed Retailer Partnership field filter)
- Google Sheet `1xWdrLtuY3ZMhzQTzjKBUeZ74I1UGvfeiLKZkBTQLu1s` - updated FINAL report with corrected numbers
- Google Sheet `1Cr9YkZ7FcxYLhOW-M_M6_R3u-zxLHum3vf3893V8K0o` - NEW: All 56 planned metrics from brainstorm
- `context/WORKING-2026-01-28-marketing-attribution-and-metrics-tracker.md` - created

**Tests:** N/A (query + documentation session)
**Next:** Deploy marketing attribution view to BigQuery, build Phase 1 queries
**Commit:** none (handoff only)

---

## 2026-02-03 09:12 - CHECKPOINT - Session Handoff

**What:** Created session handoff for continuity
**Files:**
- `context/WORKING-2026-02-03-09-12.md` - created
- `dashboard/data/bigquery_client.py` - created (BigQuery connection module)
- `dashboard/data/queries/take_rate.sql` - created
- `dashboard/data/queries/company_metrics.sql` - created
- `dashboard/data/mock_data.py` - modified (BigQuery integration with fallback)
- `docs/plans/2026-02-03-bigquery-data-connection-design.md` - created

**Tests:** BigQuery queries working (6/6 pass), some data values need business validation
**Next:** See handoff for TODO list
**Commit:** none (handoff only)

---

## 2026-02-03 09:25 - [BUGFIX] Take Rate and NRR Query Fixes

**What:** Fixed two critical BigQuery query bugs causing incorrect dashboard values
**Skill Used:** recess-bigquery

**Root Causes Identified:**
1. **Take Rate (was 0%):** Design doc specified account ranges 4000-4099 / 4100-4199 that don't exist in the chart of accounts. Revenue accounts are actually 4110, 4120, 4130.
2. **NRR (was -2%):** Query was calculating 2026/2025 but 2026 has only -$67K revenue (credit memos > invoices). Needed fallback to prior complete year.

**Solutions Implemented:**
1. **Take Rate:** Now uses `App_KPI_Dashboard.Supplier_Metrics` view which has pre-calculated GMV, Payouts, and take_amount. Falls back to prior year if GMV < $100K.
2. **NRR:** Now calculates dollar-weighted NRR with threshold check: if current year revenue < $500K, uses prior complete year (2025 vs 2024).

**Verified Results:**
- Take Rate: 62.4% (2025 data, correct)
- NRR: 65.2% (2025 vs 2024, correct — reflects actual customer contraction)

**Files Modified:**
- `dashboard/data/bigquery_client.py` - `get_take_rate()` and `get_nrr()` functions rewritten
- `context/LEARNINGS.md` - Added 3 new learnings about data sources and NRR interpretation

**Tests:** Python test script verified both functions return correct values
**Next:** Update UI labels (Gross Margin → Take Rate), Phase 2 scheduled refresh

---

## 2026-02-03 13:35 - CHECKPOINT - Session Handoff

**What:** Fixed Phase 1 Company Health metrics - Revenue, NRR, Take Rate naming, added 2025 refs
**Files:**
- `dashboard/data/bigquery_client.py` - Fixed `get_revenue_ytd()` to calculate Net Revenue
- `dashboard/data/mock_data.py` - Fixed NRR key (`demand_nrr`), added pipeline details
- `dashboard/app.py` - Renamed Gross Margin → Take Rate, added 2025 reference sub-labels
- `dashboard/data/targets.json` - Updated Take Rate target
- `docs/METRIC-IMPLEMENTATION-TRACKER.md` - Created comprehensive tracker
- `context/WORKING-2026-02-03-13-35.md` - Session handoff

**Tests:** Dashboard running at localhost:8501, all BigQuery queries verified
**Next:** Add Supply NRR and Time to Fulfill cards to Company Health section
**Commit:** none (handoff only)

---

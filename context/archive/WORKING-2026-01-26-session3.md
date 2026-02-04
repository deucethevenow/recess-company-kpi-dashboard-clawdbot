# Session Handoff - 2026-01-26 (Session 3)

## 🎯 MISSION

Design and build a unified company KPI dashboard for Recess (two-sided marketplace connecting CPG brands with events/venues). The dashboard must give each of ~18 people ONE metric they own, automate data pulls from multiple sources, replace manual Asana goal updates, and be prescriptive for non-analytical users. Security requirement: not on public web.

**North Star Metric:** Revenue (not GMV)

## 📍 CURRENT STATE

- **Phase:** Department Discovery (7 of 10 departments captured) + Dashboard Design
- **Just Completed:** Core Company KPI Dashboard design, CEO dashboard leading indicators analysis
- **In Progress:** Finalizing CEO/COO metrics and leading indicators
- **Status:** On track — 7 departments captured, Core KPI Dashboard designed, CEO advisor analysis in progress

## 🧠 KEY DECISIONS (This Session)

| Decision | Rationale |
|----------|-----------|
| Supply AM owned metric = NRR of Top Supply Users | Measures retention/expansion of venues generating 80% of revenue |
| "Top Supply Users" = Pareto-based (80% of revenue) | Focus on high-value partners |
| Engineering metrics from Asana + GitHub + Shortcut | NOT BigQuery — requires direct API integrations |
| VP Engineering owns Features Fully Scoped | PRD + FSD complete = scoping bottleneck cleared |
| Core KPI Dashboard = Revenue at top + per-person below | Company health context + individual accountability |
| Gray (⚪) status for metrics without targets | Track without blocking — creates pressure to set targets |
| Daily refresh for Core KPI Dashboard | Overnight batch update |
| Added inventory capacity metrics to Supply | `mongodb.report_datas` (coming) + `mongodb.audience_listings` |

## 📋 TODO (Prioritized)

- [ ] **HIGH:** Finalize CEO owned metric (New Logos recommended) and COO owned metric (Gross Margin recommended)
- [ ] **HIGH:** Design CEO Executive Dashboard with leading indicators
- [ ] **HIGH:** Gather AI Automations metrics (1 person, skipped this session)
- [ ] **HIGH:** Gather CEO/Business Dev (Jack) metrics
- [ ] **MED:** Define technology stack (Flask vs Streamlit vs Retool)
- [ ] **MED:** Address security requirements
- [ ] **MED:** Design metric ownership model (complete the ~18 people matrix)
- [ ] **LOW:** Query BigQuery for baselines (marketing attribution, 7-day payment rate, supply user NRR, ticket close time)
- [ ] **LOW:** Write final design document

## ❓ UNANSWERED QUESTIONS (Continue Next Session)

### CEO Dashboard - Leading Indicators Discussion

The user asked: *"What are leading indicators so that we know if we're going to miss our revenue goal?"*

**Analysis provided but not finalized:**

**Leading Indicators for NEW Customer Revenue:**
| Indicator | Warning Sign | Data Source |
|-----------|--------------|-------------|
| Pipeline Coverage | <3x unweighted or <1.5x weighted | HubSpot |
| Pipeline Created (monthly) | Declining MoM | HubSpot |
| MQL → SQL Conversion | <30% | HubSpot |
| Win Rate | Declining trend | HubSpot |
| Marketing-Influenced Pipeline | Declining | HubSpot (FT+LT)/2 |

**Leading Indicators for EXISTING Customer Revenue:**
| Indicator | Warning Sign | Data Source |
|-----------|--------------|-------------|
| Contract Spend % | Behind target% | BigQuery (GMV Waterfall) |
| At-Risk Contracts | Increasing count | BigQuery |
| NRR Trend | <100% or declining | BigQuery |
| Logo Retention | <50% (currently 37%) | BigQuery |

**CEO Dashboard Structure Proposed:**
```
NORTH STAR: Revenue vs Target
COMPANY HEALTH: Runway, Pipeline Coverage, NRR, Customer Count, Concentration %
LEADING - NEW BIZ: New Logos, Pipeline Created, Win Rate, Mktg Pipeline, MQL→SQL
LEADING - EXISTING: Contract Spend %, At-Risk Contracts, Logo Retention
```

**User's CEO metric considerations:**
- New logos
- Pipeline coverage
- Revenue
- Runway
- Retention for demand-side customers
- Marketing metrics

**Recommended owned metrics (pending confirmation):**
- CEO (Jack): **New Logos** (fights concentration, aligns with biz dev)
- COO (Deuce): **Gross Margin %** (spans all COO departments)

### Questions to Resolve Next Session:
1. Which ONE metric should Jack own? (New Logos vs New Customer Revenue vs Pipeline Coverage)
2. Should COO metric be Gross Margin or something else?
3. Should we add the full CEO dashboard with leading indicators to the brainstorm doc?
4. What marketing metrics beyond Marketing-Influenced Pipeline?

## 📁 KEY FILES

```
context/plans/2026-01-22-dashboard-brainstorm.md  - MASTER brainstorm (all dept metrics, SQL queries, dashboard designs)
context/WORKING-2026-01-22-brainstorm-session2.md - Previous session handoff
context/PROGRESS.md                               - Development progress log
context/LEARNINGS.md                              - 5 learnings from session 2
```

## 🔧 ENVIRONMENT

- **Working directory:** `/Users/deucethevenowworkm1/Projects/company-kpi-dashboard`
- **BigQuery project:** `stitchdata-384118`
- **Key BigQuery schemas:** `src_fivetran_qbo`, `src_fivetran_hubspot`, `mongodb`, `App_KPI_Dashboard`
- **MCP tools available:** BigQuery, HubSpot, QuickBooks, Notion, Google Drive, Playwright
- **GitHub repo (PRDs):** `RECESSDigital/recess-prd`

## 💡 NEXT SESSION SHOULD

1. **Resume CEO/COO metric discussion** — finalize owned metrics for Jack and Deuce
2. **Decide on CEO Executive Dashboard** — add to brainstorm doc with leading indicators
3. **Use brainstorming skill** — continue one question at a time approach
4. **Read the brainstorm doc** — `context/plans/2026-01-22-dashboard-brainstorm.md` has all context
5. **Consider using CEO advisor skill** — already invoked this session, has good frameworks

## 📊 DEPARTMENTS CAPTURED (7/10)

| # | Department | Owned Metric | Status |
|---|-----------|--------------|--------|
| 1 | Supply (Ian) | New Unique Inventory Added | ✅ |
| 2 | Demand Sales (Andy/Danny/Katie) | NRR / Pipeline Coverage 3x | ✅ |
| 3 | Demand AM (Char's team) | Contract Spend % of Goal | ✅ |
| 4 | Marketing | Marketing-Influenced Pipeline | ✅ |
| 5 | Accounting/Finance | Dual: Ops + CFO dashboards | ✅ |
| 6 | Supply AM (Ashton) | NRR of Top Supply Users | ✅ |
| 7 | Engineering/Product (VP + 3 devs) | Features Fully Scoped + BizSup + PRDs + FSDs | ✅ |
| 8 | AI Automations | TBD (skipped) | ⏳ |
| 9 | CEO/Biz Dev (Jack) | TBD (New Logos recommended) | ⏳ |
| 10 | COO/Ops (Deuce) | TBD (Gross Margin recommended) | ⏳ |

## 📝 CRITICAL VERBATIM CONTEXT

**Company:** Recess — Two-sided marketplace (CPG brands ↔ events/venues for product sampling)
**~18 people, 10 departments**
**Revenue:** $7.93M | **NRR:** 107% | **Logo Retention:** 37% | **Concentration:** 41% (HEINEKEN)

**Key insight from CEO Advisor skill:**
> "The CEO/COO metric pairing creates natural tension that drives healthy behavior: Jack pushes for NEW revenue (growth, diversification) → might accept lower-margin deals to land new logos. Deuce pushes for EFFICIENT revenue (margin, operations) → ensures new deals are actually profitable."

**User's last question before handoff:**
> "For the CEO, I think we should look at: New logos, Pipeline coverage, Revenue, Runway, Retention for customers on the demand side. The thing I think that we need to also do is some marketing metrics and then what are leading indicators so that we know if we're going to miss our revenue goal."

# Company KPI Dashboard - Brainstorming Session

**Date:** 2026-01-22 (Updated: 2026-01-26)
**Status:** In Progress - 9 of 10 Departments Captured, Core Dashboard Designed

---

## Executive Summary

Building a unified company dashboard to replace:
- Manual Google Sheets tracking
- Disconnected HubSpot dashboards
- Manual Asana goal updates

**Core Requirements:**
1. One metric per person (clear ownership)
2. Automated data pulls (no manual updates)
3. Secure (not on open web)
4. Simple/prescriptive for non-analytical users
5. Department scorecards + Executive overview

---

## Company Overview

### Business Model
- **Type:** Two-sided marketplace
- **Supply side:** Events/venues (university housing, fitness studios, music festivals, etc.)
- **Demand side:** Fortune 100 CPG brands (Kraft Heinz, Coca-Cola, etc.)
- **Revenue model:** Company earns when brands run programs at venues
- **North Star Metric:** Revenue (previously GMV)

### Deal Lifecycle
```
Supply acquires venue → Marketing generates brand leads →
Demand (Sales) closes brand deal → Demand Account Mgmt executes program →
Accounting invoices → Revenue recognized
```

---

## Organization Structure (~18 people)

| Department | Team Size | Reports To | Status |
|------------|-----------|------------|--------|
| Engineering/Product | 4 (VP + 3 devs) | CEO | ✅ Captured |
| Marketing | 1 | CEO | ✅ Captured |
| Business Dev/CEO (Jack) | 1 | — | ✅ Captured |
| Demand (Sales) | 3 (Andy=leader, Danny, Katie) | CEO | ✅ Captured |
| Demand Account Mgmt | 4 (Char=director, Victoria, Claire, Francisco, Ashton) | COO | ✅ Captured |
| Supply | 1 (Ian Hong) | COO | ✅ Captured |
| Supply Account Mgmt | 1 (Ashton, on Char's team) | COO | ✅ Captured |
| Accounting/Finance | 1 | COO | ✅ Captured |
| AI Automations | 1 | COO | ⏳ Pending |
| Operations/COO (Deuce) | 1 | CEO | ✅ Captured |

---

## Department Metrics - COMPLETED

### 1. Supply Department (Ian Hong)

**Owned Metric:** New Unique Inventory Added (TAM expansion)

**Current Data Sources:**
- HubSpot: Funnel metrics (Attempted → Connected → Meeting → Proposal → Won)
- Google Sheets: Inventory by event type category, KPI goals
- Smart Lead: Outbound email sequences
- BigQuery (`mongodb.report_datas`): Yearly limited capacity by event type (coming soon)
- BigQuery (`mongodb.audience_listings`): Published listings by type and month

**Key Metrics:**

| Type | Metric | Cadence | Data Source |
|------|--------|---------|-------------|
| Owned (Lagging) | New Unique Inventory Added | Quarterly | Google Sheets |
| Pipeline Coverage | Coverage by Event Type vs Goal | Weekly | HubSpot + Sheets |
| Lead Health | Days of Runway / Queue Depth | Real-time | Smart Lead |
| Activity | Target Accounts Attempted | Weekly (500 goal) | HubSpot |
| Funnel | Meeting → SQL → Proposal → Won | Monthly | HubSpot |

**Funnel Goals (Monthly):**
- Attempted to Contact: 60/month (target accounts), 60/month (all)
- Connected: 60/month
- Meeting Booked: 24/month
- Proposal Sent: 16/month
- Onboarded: 16/month
- Won: 4/month (target accounts)

**Inventory Categories Being Tracked:**
- university_housing (Goal: 40K)
- fitness_studios (Goal: 400K)
- youth_sports (Goal: 500K)
- kids_camp (Goal: 150K)
- music_festivals (Goal: 72K)
- Plus 30+ other categories

**Pipeline Coverage Calculation:**
```
For each event type:
  Goal: 400,000 samples (fitness_studios)
  Won: $50,000 (12.5% of goal)
  Open Pipeline: $200,000
  Pipeline Coverage: 0.5x ← Need 3x minimum
```

**Lead Queue Health Metrics (NEW - needs implementation):**
- Leads actively sequencing in Smart Lead
- Leads enrolled but not yet sequencing
- Leads staged for next sequence
- Send capacity (~600 emails/day)
- Days of runway remaining

**Inventory Capacity & Listings Metrics (from BigQuery):**

*Data Source 1:* `mongodb.report_datas` (coming via Fivetran MongoDB sync — not yet available)
- Key field: `key = "yearly_limited_capacity"`
- Each row = monthly snapshot with capacity per event type in JSON `data` field
- Example data structure:
```json
{
  "running": { "capacity": 125000 },
  "university_housing": { "capacity": 390000 },
  "fitness_studio": { "capacity": 76000 }
}
```

*Data Source 2:* `mongodb.audience_listings` (already in BigQuery)
- Filter: `published_state = 'published'`, `is_omnichannel = FALSE`
- Group by: `primary_type`, `DATE_TRUNC(published_at, MONTH)`

| Type | Metric | Cadence | Data Source |
|------|--------|---------|-------------|
| Capacity | Total Limited Capacity (all types summed) | Monthly | `mongodb.report_datas` |
| Capacity | Capacity by Event Type (breakdown) | Monthly | `mongodb.report_datas` |
| Growth | Month-over-Month Capacity Change | Monthly | Calculated |
| Activity | Listings Published per Month by Type | Monthly | `mongodb.audience_listings` |

**Dashboard Visualizations (Supply Capacity):**
- Total limited capacity → trend line over time
- Capacity by event type → stacked bar or breakdown table
- MoM change → growth/decline indicator
- Listings published → by type, monthly

**Note:** `mongodb.report_datas` is being added to Fivetran sync — not yet available in BigQuery. Will be at `mongodb.report_datas` once synced.

**Key Problem Identified:**
- Supply person struggles to diagnose WHY targets are missed
- Data split between HubSpot and Sheets
- Not analytical - needs prescriptive dashboard ("Do X to get back on track")

---

### 2. Demand Account Management (Char Short - Director)

**Team Structure:**
- Char Short (Director) - Oversees team + top accounts
- Victoria (AM) - Smaller accounts
- Claire (Specialist) - Day-to-day logistics
- Francisco (Specialist) - Day-to-day logistics
- Ashton (Specialist) - Support

**This team already has "one metric per owner" working!**

**KPI Scorecard (Weekly Tracking):**

| KPI | Owner | Data Source | Sample Values |
|-----|-------|-------------|---------------|
| NPS Score | Claire | Looker | 54.67% → 70.86% |
| Offer acceptance % | Francisco | Looker | 80% → 88% |
| Offer ignored % | Francisco | Looker | 13% → 12.50% |
| Avg time to respond to tickets | Ashton | HubSpot | 62 hrs → 16.3 hrs |
| % confirmed vs outstanding | Ashton | Looker | bi-weekly tracking |
| Total brand calls (weekly) | Victoria | HubSpot | 71, 1, 5, 4, 3 |
| Time to fulfill programs | Victoria | Looker | 161 → 170 |

**Contract Spend Tracking (Main AM KPI):**

| AM | Goal | Actual | % of Goal |
|----|------|--------|-----------|
| Char Short | $193,974 | $193,610 | 99.81% |
| Victoria Newton | $260,609 | $256,325 | 98.36% |
| **Total** | $507,050 | $449,934 | **88.74%** |

**Additional AM Metrics:**
- Land & Expand Deals Influenced (credit AM for expansions)
- Renewal Rate
- Balance Remaining on Contracts (main driver)

**Data Sources:**
- Google Sheets: AM KPI Tracking, Upfront Contracts Workbook
- Looker: Linked reports per metric
- HubSpot: Activity tracking, response times
- BigQuery: Spend data via SQL queries

---

### 3. Demand Sales (Andy Cooper - Leader)

**Team Structure:**
- Andy Cooper (Sales Leader)
- Danny Sears (Legacy seller - most accounts)
- Katie (New seller)

**Current Tracking - What's Working:**

1. **AI Deal Scoring & Weekly Digest**
```
📊 Pipeline Health: HEALTHY
• 143 deals | Raw: $14.5M → Weighted: $5M (66% discount)
• 68 quality deals (A/B tier) | 51 at-risk deals (D/F tier)
```

2. **Rep Scorecard (from digest):**

| Rep | Weighted Pipeline | Deals | Good | Risky |
|-----|-------------------|-------|------|-------|
| Danny | $2.6M | 77 | 29 | 35 |
| Char | $1.1M | 22 | 18 | 1 |
| Andy | $701K | 37 | 15 | 15 |
| Victoria | $536K | 6 | 5 | 0 |
| Jack | $30K | 1 | 1 | 0 |

3. **HubSpot Pipeline Stages:**
```
Meeting Booked (8) → SQL (78) → Opportunity (11) → Proposal Sent (34)
→ Active Negotiation (10) → Contract Sent (4) → Closed Won (543)
```

4. **Summary Metrics:**
- Total Deal Amount: $156.66M (avg $69.47K)
- Weighted Deal Amount: $33.23M (avg $14.74K)
- Open Deal Amount: $14.53M
- Average Deal Age: 3.3 months

**Funnel Goals (Monthly):**
- Meeting Booked: 45/month
- Sales Qualified Lead: 36/month
- Opportunity: 23/month
- Proposal Sent: 22/month
- Contract Sent: 9/month
- Won: $500K / 7 deals

**TOP OF FUNNEL PROBLEM IDENTIFIED:**
- Only 3-4 contacts enrolled in sequences in last 7 days
- Brand Nurture contacts sitting idle (Danny: 164, Jack: 45)
- Limited new contacts to sequence
- Same problem as Supply - lead inventory management

**Metric Ownership Decision:**

| Person | Role | Owned Metric |
|--------|------|--------------|
| Andy (Leader) | Sales Leader | Net Revenue Retention (NRR) |
| Danny (Seller) | Legacy accounts | Weighted Pipeline Coverage (3x target) |
| Katie (Seller) | New accounts | Weighted Pipeline Coverage (3x target) |

**Missing: Stage-Level Goals**
- Need to calculate required pipeline at each stage based on conversion rates
- "To hit $1.5M in bookings, need X SQLs, Y Proposals, Z Contracts"
- Weekly pace tracking

---

### 4. Marketing Department (1 person)

**Owned Metric:** Marketing-Influenced Pipeline (Demand Side)

**Attribution Model:**
- **Formula:** (First Touch + Last Touch) / 2
- Each attribution type gets 50% credit for fair distribution
- Currently focused on demand side (brand leads), not supply side

**Current Data Sources:**
- HubSpot: Marketing attribution reports, deal pipeline
- BigQuery: Historical revenue attribution (to be queried)

**Key Metrics:**

| Type | Metric | Cadence | Data Source |
|------|--------|---------|-------------|
| Owned | Marketing-Influenced Pipeline | Monthly | HubSpot (FT + LT) / 2 |
| Owned | Marketing-Sourced Revenue % | Monthly | BigQuery |
| Leading | MQL → SQL Conversion Rate | Monthly | HubSpot (currently 33.33%) |
| Activity | Contacts by Lead Source | Weekly | HubSpot |

**HubSpot Attribution Metrics (from Marketing Dashboard):**
- First Touch (FT) Revenue Attribution
- Last Touch (LT) Revenue Attribution
- Sales Sourced Revenue vs Marketing Sourced Revenue
- MQL → SQL conversion rates

**TARGET SETTING:**
- No formal target yet for marketing-influenced %
- Will work backwards from Sales NRR goal to determine appropriate target
- **ACTION ITEM:** Query BigQuery for historical marketing-influenced revenue % to establish baseline

**Key Problem Identified:**
- Marketing effectiveness for Supply side not tracked yet
- Attribution split between FT and LT needs dashboard consolidation
- Need historical baseline to set meaningful targets

---

### 5. Accounting/Finance (1 person + CFO oversight)

**Note:** This department requires TWO distinct dashboards:
1. **Accounting Operations Dashboard** - Day-to-day bill processing & collections
2. **CFO Dashboard** - Company health, runway, strategic metrics

---

#### 5A. Accounting Operations Dashboard

**Owned Metric:** Invoice Collection Rate (% paid within due date)

**Query Layer:** BigQuery (all sources below sync via Fivetran)

**Source Systems:**
- QuickBooks Online → Invoice data, payment status (`src_fivetran_qbo.*`)
- MongoDB (Platform) → Payout board, bill status, vendor info (`mongodb.*`)
- Bill.com → W-9 status, vendor onboarding (syncs to MongoDB → BigQuery)
- Google Sheets: Master Billing Workbook (reference only)
- Asana: Accounts Receivable task tracking (reference only)

**Key Metrics (Collections/AR):**

| Type | Metric | Target | Cadence | Data Source |
|------|--------|--------|---------|-------------|
| Owned | Invoices Paid Within Due Date % | **95%** | Weekly | QuickBooks + MongoDB |
| Owned | Invoices Paid Within 7 Days % | TBD (query historical) | Weekly | BigQuery |
| Health | Overdue Invoices Count & $ | 0 | Real-time | QuickBooks |
| Health | Average Days to Collection | <7 days | Monthly | BigQuery |

**Key Metrics (Payables/AP):**

| Type | Metric | Cadence | Data Source |
|------|--------|---------|-------------|
| Health | Bills Overdue by Bill.com Status | Real-time | BigQuery (from MongoDB) |
| — | → Approved (ready to pay) | — | — |
| — | → Pending (awaiting approval) | — | — |
| — | → Missing W-9 (blocked) | — | — |
| — | → Not Onboarded (vendor not in Bill.com) | — | — |
| Health | Bills Missing W-9s | Real-time | BigQuery (from MongoDB) |
| Health | Bills Missing Payment Info | Real-time | BigQuery (from MongoDB) |
| Critical | **Invoice Variance Count** | Daily | BigQuery (should = 0) |
| Critical | **Invoice Variance $** | Daily | BigQuery (should = $0) |
| Critical | **Bill Variance Count** | Daily | BigQuery (should = 0) |
| Critical | **Bill Variance $** | Daily | BigQuery (should = $0) |

**Factoring Metrics:**

| Type | Metric | Target/Limit | Data Source |
|------|--------|--------------|-------------|
| Health | Total Factored Balance | Monitor | BigQuery (Balance Sheet) |
| Health | Total Factored Reserves | Monitor | BigQuery (Balance Sheet) |
| Limit | Total Factored Limit | **$1,000,000** | Static (contractual) |
| Calculated | Available Factoring Capacity | 🟢 >$400K / 🟡 $200K-$400K / 🔴 <$200K | Calculated (Limit - Balance) |
| Cost | Factoring Fees Paid (YTD) | Monitor | BigQuery (P&L → Finance Charges) |

**Payout Board (from app.recess.is/payout-board):**
Tracks supplier/organizer payments with these fields:
- Supplier/Organizer
- Payout Status (OPEN, PAID IN FULL)
- Payout Amount, Bill #, Due Date
- Total Amount, Balance Due
- Approval Status (APPROVED, PENDING)
- Payment Status (PAID IN FULL, OPEN)
- Vendor Status (ONBOARDED, W-9 MISSING)
- Payment Method (PAY BY ACH, PAY BY INSTANT TRANSFER)

**AR Tracking (from Asana "Accts Receivable - Invoices Due"):**
- Invoices to Upload
- Queue (ready to send)
- Upcoming 14 Days
- Overdue
- Outstanding Unapplied Credit Memos

**Key Problem Identified:**
- **Bill payment delays due to:**
  - Missing W-9s (can't pay without W-9)
  - Vendors not onboarded in Bill.com
  - Missing payment information
- QBO vs Platform reconciliation variances need to be 0
- All source data available in BigQuery (MongoDB, QBO, HubSpot sync via Fivetran)

---

#### 5B. CFO Dashboard (Strategic/Board Level)

**Purpose:** Automate board meeting deck generation, track company health

**Reference Document:** `GMV_Health_Analysis_Complete_Report_Jan2026_v2.md`
**Reference:** Q3 2025 Board Meeting Deck

**Key Metrics - Runway & Cash:**
*Data Source: BigQuery (QBO data syncs via Fivetran)*

| Metric | Current Value | Target | Priority |
|--------|---------------|--------|----------|
| Current Assets | $2.7M | Monitor | 🟢 |
| Current Liabilities | $1.1M | <$2M | 🟢 |
| Cash | $219.7K | >$500K | 🟡 |
| Working Capital | $1.6M | >$1M | 🟢 |
| Avg 12mo Operating Burn | -$52K/mo | < -$50K | 🟡 |
| Months of Runway | TBD | >12 mo | 🟡 |

**Key Metrics - Concentration Risk (CRITICAL):**

| Metric | Current State | 2026 Target | Priority |
|--------|---------------|-------------|----------|
| Top Customer % Revenue | **40.9%** (HEINEKEN) | <30% | 🔴 Critical |
| Top 2 Customers % | **59.0%** | <45% | 🔴 Critical |
| Top 5 Customers % | **74.0%** | <55% | 🔴 High |
| Top 10 Customers % | **84.5%** | <70% | 🟡 High |

**Key Metrics - Retention & Growth:**

| Metric | Current State | 2026 Target | Priority |
|--------|---------------|-------------|----------|
| Logo Retention Rate | **37%** | >50% | 🟡 High |
| Net Revenue Retention | **107%** | >110% | 🟡 High |
| Active Customer Count | **51** | 75+ | 🟡 High |
| Average Deal Size | **$155K** | Maintain | 🟢 Monitor |

**Key Metrics - Seasonality:**

| Metric | Current State | 2026 Target | Priority |
|--------|---------------|-------------|----------|
| Q4 % of Annual Revenue | **10%** | >18% | 🟡 High |

**Key Metrics - Pipeline Coverage:**
*Total Quota sourced from HubSpot company property*

| Metric | Description | Target | Priority |
|--------|-------------|--------|----------|
| Total Quota | Sum of quota from HubSpot company property | — | Baseline |
| **Coverage (Unweighted)** | Total open deal amounts ÷ Quota | >3.0x | 🟡 High |
| **Coverage (HubSpot Weighted)** | Stage probability-weighted deals ÷ Quota | >1.5x | 🟡 High |
| **Coverage (AI Weighted)** | AI tier-weighted deals ÷ Quota | >1.5x | 🟡 High |

**Unspent Contracts & Revenue Forecast:**

| Metric | Description | Data Source |
|--------|-------------|-------------|
| **Total Unspent Contract $** | Sum of remaining_gross across all active contracts | BigQuery (HubSpot deals + QBO invoices) |
| Contract Health Distribution | # On Track / At Risk / Off Track | Calculated (target% vs actual_spend%) |
| **Remaining Spend Forecast by Month** | Projected future revenue from existing contracts | BigQuery (`App_KPI_Dashboard.HS_QBO_GMV_Waterfall`) |

*Contract Health Logic:*
- **On Track:** actual_spend_pct ≥ target% OR target = 0
- **At Risk:** (actual_spend_pct - target) is between -0.16 and 0
- **Off Track:** actual_spend_pct < target% by more than 16%

**Budget vs Actual:**
- Track YTD spending vs budget (company-wide, not by department)
- Forecast accuracy metrics

**LTV by Tenure (Key Insight):**
- 4-year customers: **$1.23M avg LTV** (42x higher than 1-year)
- Multi-year retention is critical

**Query Layer:** BigQuery (all sources sync via Fivetran)
- `src_fivetran_qbo.*` → Cash, AR/AP, runway, balance sheet
- `src_fivetran_hubspot.*` → Pipeline coverage, deal metrics, contracts
- `App_KPI_Dashboard.*` → Pre-built views (GMV Waterfall, etc.)

---

### 6. Supply Account Management (Ashton — on Char's team)

**Owned Metric:** NRR of Top Supply Users (organizers generating 80% of revenue)

**Team Note:** Ashton organizationally sits on Char's Demand AM team but leads Supply Account Management. Metrics already partially tracked in Demand AM scorecard (ticket response time).

**Definition of "Top Supply Users":**
- Organizers/venues that collectively generate 80% of revenue (Pareto-based)
- Dynamic list — recalculated periodically based on revenue contribution

**Key Metrics:**

| Type | Metric | Target | Cadence | Data Source |
|------|--------|--------|---------|-------------|
| Owned | NRR of Top Supply Users | TBD (query baseline) | Monthly | BigQuery (QBO + HubSpot) |
| Health | Avg Time to Respond to Ticket | <16 hrs (current: 16.3 hrs) | Weekly | BigQuery (from HubSpot tickets) |
| Health | Avg Time to Close Ticket | TBD (query baseline) | Weekly | BigQuery (from HubSpot tickets) |
| Yield | Avg Revenue Per Supply User | TBD (query baseline) | Monthly | BigQuery |
| Yield | GMV Per Top Supply User | TBD (query baseline) | Monthly | BigQuery |

**Known Baselines (from Demand AM Scorecard):**
- Ticket response time improved from 62 hrs → 16.3 hrs
- Target: maintain <16 hrs or improve further

**Action Items:**
- [ ] Query BigQuery for NRR of top supply users (historical)
- [ ] Query BigQuery for avg time to close ticket (baseline)
- [ ] Query BigQuery for avg revenue per supply user
- [ ] Identify the organizer list that generates 80% of revenue

---

### 7. Engineering/Product (VP + 3 Devs)

**VP Owned Metric:** Features Fully Scoped (PRD published + FSD complete)

**Team Structure & Individual Metrics:**

| Person | Role | Owned Metric | Data Source |
|--------|------|--------------|-------------|
| VP of Engineering | Overall | Features Fully Scoped | GitHub (recess-prd repo) |
| Dev 1 | Execution | BizSup Stories Completed + Time to Complete | Asana API |
| Dev 2 | Product Definition | PRDs Generated (draft → published) | GitHub API |
| Dev 3 | Engineering Design | FSDs Generated (Feature Seed Designs) | GitHub API |

---

#### 7A. Asana BizSup Metrics (Business Support Throughput)

**Project:** BizSup (`app.asana.com/...`)
**Purpose:** Track business support request flow and engineering responsiveness

**Board Stages:**
```
New/Incoming → For Business Review → QUEUED → In Flight → Launched
                                   ↘ Icebox / On Hold (parked)
```

**Key Metrics:**

| Type | Metric | Cadence | Data Source |
|------|--------|---------|-------------|
| Inflow | Tasks Created (new requests) | Weekly | Asana API |
| Bottleneck | Tasks in "For Business Review" | Real-time | Asana API |
| WIP | Tasks "In Flight" (actively being built) | Real-time | Asana API |
| Output | Tasks Completed/Launched | Weekly | Asana API |
| Efficiency | Avg Time to Complete (created → launched) | Weekly | Asana API |

---

#### 7B. GitHub PRD Pipeline (Feature Scoping Throughput)

**Repo:** `RECESSDigital/recess-prd`
**Purpose:** Track the bottleneck — getting features scoped before engineering begins

**Folder Structure & Lifecycle:**
```
draft/              ← PRDs being written (each feature = its own git branch)
features/           ← Published PRDs (merged to main, PR reviewed by Jack/Deuce)
  feature-name/
    feature-name.md     ← The PRD (requirements)
    FSD/                ← Feature Seed Design (engineering guidance for Claude Code)
    i-plan/             ← Implementation plan
    progress/           ← Progress tracking (future)
done/               ← Completed features (fully shipped)
```

**Workflow:**
1. `create prd media-plan` → creates branch `draft/media-plan`, writes PRD
2. `publish prd` → merges to main, moves to `features/`, creates PR for review
3. Engineering creates FSD (design seed so Claude Code doesn't generate tech debt)
4. Engineering creates i-plan (implementation plan)
5. Feature is "Fully Scoped" when PRD + FSD + i-plan exist

**Key Metrics:**

| Type | Metric | Cadence | Data Source |
|------|--------|---------|-------------|
| Pipeline | PRDs in Draft | Real-time | GitHub API (count in draft/) |
| Output | PRDs Published | Weekly | GitHub API (count in features/) |
| Output | FSDs Created | Weekly | GitHub API (FSD/ folders in features/) |
| Output | Implementation Plans Done | Weekly | GitHub API (i-plan/ folders) |
| **Owned** | **Features Fully Scoped** | Weekly | GitHub API (PRD + FSD + i-plan all exist) |
| Complete | Features Done (shipped) | Monthly | GitHub API (count in done/) |

**FSD (Feature Seed Design) Explained:**
- NOT a duplicate of PRD requirements
- Engineering guidance to prevent Claude Code from generating naive/unmaintainable code
- Seeds how Claude should design the implementation
- Example: `features/media-plan-I/FSD/FSD_Media_Plan_Phase_I_v2.md`
- Solves the core problem: LLM code gen without design guidance = tech debt

---

#### 7C. Shortcut Metrics (Engineering Execution — Process Maturing)

**Purpose:** Track engineering execution velocity (process still being established)
**Note:** Shortcut is used for engineering stories/tickets but process is immature

**Key Metrics:**

| Type | Metric | Cadence | Data Source |
|------|--------|---------|-------------|
| Output | Stories Completed per Sprint | Per sprint | Shortcut API |
| WIP | Stories In Progress vs Backlog | Real-time | Shortcut API |
| Efficiency | Cycle Time (start → done) | Per sprint | Shortcut API |

---

#### 7D. Integration Requirements

| System | API Needed | What It Provides |
|--------|-----------|-----------------|
| **Asana** | Asana API | BizSup task counts by section, timestamps for cycle time |
| **GitHub** | GitHub API | File/folder counts in recess-prd repo (draft/ vs features/ vs done/) |
| **Shortcut** | Shortcut API | Story states, sprint data, cycle time |

**Note:** Unlike other departments, Engineering metrics do NOT flow through BigQuery. They require direct API integrations with Asana, GitHub, and Shortcut.

---

### 8. CEO / Business Development (Jack)

**Owned Metric:** Revenue vs Target (Total Company Revenue)

**Rationale:** The entire revenue function reports to Jack. As CEO, he owns the company's North Star metric — total revenue performance against target.

**Key Metrics:**

| Type | Metric | Target | Cadence | Data Source |
|------|--------|--------|---------|-------------|
| Owned | Revenue vs Target (YTD) | $X.XM annual | Daily | BigQuery (QBO) |
| Leading | New Logos (count) | TBD | Monthly | BigQuery (HubSpot) |
| Leading | Pipeline Coverage (unweighted) | >3.0x | Weekly | BigQuery (HubSpot) |
| Leading | NRR | >110% | Monthly | BigQuery |
| Health | Customer Concentration (Top 1) | <30% | Monthly | BigQuery |

**Accountability Cascade:**
```
Jack (CEO) — Revenue vs Target
  └── Andy (Sales Leader) — NRR
        └── Danny/Katie (Sellers) — Pipeline Coverage 3x
  └── Char (AM Director) — Contract Spend %
  └── Marketing — Marketing-Influenced Pipeline
```

**Note:** Jack's metric appears both as the North Star at the top of the Core KPI Dashboard AND in his personal row in the per-person scorecard.

---

### 9. COO / Operations (Deuce)

**Owned Metric:** Gross Margin %

**Rationale:** As COO, Deuce owns operational efficiency across all departments that report to him. Gross Margin % measures how efficiently the company converts revenue into profit — spanning Supply, Supply AM, Demand AM, Accounting, and AI Automations.

**Key Metrics:**

| Type | Metric | Target | Cadence | Data Source |
|------|--------|--------|---------|-------------|
| Owned | Gross Margin % | TBD (query baseline) | Monthly | BigQuery (QBO P&L) |
| Health | Operating Expenses vs Budget | On budget | Monthly | BigQuery (QBO) |
| Health | Invoice Collection Rate | 95% | Weekly | BigQuery (QBO) |
| Health | Bill Payment Timeliness | 95% | Weekly | BigQuery (QBO + MongoDB) |

**Healthy Tension with CEO:**
- **Jack pushes for REVENUE** (growth, new customers, hitting targets)
- **Deuce pushes for MARGIN** (efficiency, profitability, operational excellence)

This tension is intentional — it prevents sacrificing margin for revenue or vice versa.

**Departments Reporting to COO:**
- Supply (Ian)
- Supply AM (Ashton)
- Demand AM (Char's team)
- Accounting/Finance
- AI Automations

---

## SQL Queries Captured

### 1. Sales Manager Quota & Pipeline Coverage Report
**Location:** User shared in conversation
**Purpose:** One row per company with quotas, actuals, and pipeline coverage
**Features:**
- Quota buckets: Renewal, Land & Expand, New Business, DG, Walmart
- Three weighting methods: Unweighted, HubSpot Stage Probability, AI Tier
- Pipeline coverage calculations per bucket

### 2. Net Revenue Retention Tracker
**Location:** User shared in conversation
**Purpose:** Track NRR by customer with target account segmentation
**Key Results (as of Jan 2026):**

| Segment | Count | NRR 2023 | NRR 2024 | NRR 2025 |
|---------|-------|----------|----------|----------|
| Target Accounts | 28 | 167.7% | 164.6% | 90.3% |
| Non-Target | 165 | 96.0% | 78.2% | 111.8% |
| **TOTAL** | 193 | 128.0% | 128.7% | **95.7%** |

**Key Insight:** Target accounts = 14.5% of customers but 64% of LTV
Target NRR dropped from 165% to 90% in 2025 (churned Haleon, Spark Foundry)

### 3. Funnel Math Query (PROPOSED)
**Purpose:** Calculate required pipeline at each stage to hit bookings target
**Features:**
- Historical conversion rates by stage
- Average cycle time calculations
- Required pipeline at each stage
- Weekly pace needed
- See full query in conversation

### 4. QBO to Platform Invoice Reconciliation
**Location:** User shared in conversation
**Purpose:** Reconcile QuickBooks invoices with platform data, calculate variance (Delta)
**Key Feature:** Delta should ideally be $0 (perfect reconciliation)

**Query Structure:**
```sql
-- CTEs: line_items, credit_memos, Mongodb_inv, purchase_discounts, Invoices, doc_number_join
-- Joins QBO invoice data (src_fivetran_qbo) with MongoDB platform data
-- Calculates: Upfront Commitment Balance, Reimbursable Expenses, Discounts, Credits
-- Final Output: Delta = QBO_Amount - Platform_Amount (should be 0)
```

**Data Sources Used:**
- `src_fivetran_qbo.invoice` - QBO invoices
- `src_fivetran_qbo.invoice_line` - Invoice line items
- `src_fivetran_qbo.credit_memo` - Credit memos
- `src_fivetran_qbo.item` - Item master
- `mongodb.invoices` - Platform invoices
- `mongodb.invoice_line_items` - Platform line items

**Related Query:** `QBO_To_Platform_Supplier_Organizer_Remittance_Reconciliation` (for bills/payables)

### 5. Unspent Contracts / GMV Waterfall
**Location:** User shared in conversation
**BigQuery View:** `stitchdata-384118.App_KPI_Dashboard.HS_QBO_GMV_Waterfall`
**Purpose:** Track remaining unspent $ on closed-won contracts, contract health, revenue forecast

**Query Structure:**
```sql
-- CTEs: hubspot_users, gross_amount, credit_memos, deferred_revenue,
--        qbo_invoices, manual_deferred_revenue_adjustments,
--        qbo_invoices_grouped, qbo_customers, hubspot_deals
-- Joins HubSpot deals (closed won, with term dates) to QBO invoice spend data
-- Key outputs per contract:
--   remaining_gross = amount - gross_spend (what's left to invoice)
--   target% = time elapsed in term (where you should be)
--   actual_spend_pct = % actually spent
--   Health = On Track / At Risk / Off Track
--   deferred_balance = deferred revenue tracking
```

**Data Sources Used:**
- `src_fivetran_hubspot.deal` - HubSpot deals (closed won)
- `src_fivetran_hubspot.deal_company` - Deal-company associations
- `src_fivetran_hubspot.company` - Company info
- `src_fivetran_hubspot.deal_pipeline` - Pipeline info
- `src_fivetran_hubspot.owner` - HubSpot users/owners
- `src_fivetran_qbo.invoice` / `invoice_line` - QBO invoices
- `src_fivetran_qbo.credit_memo` / `credit_memo_line` - Credit memos
- `src_fivetran_qbo.item` - Item master
- `src_fivetran_qbo.account` - Account master (for deferred revenue detection)
- `src_fivetran_qbo.customer` - QBO customers
- `mongodb.invoices` / `invoice_line_items` - Platform invoices

**Key Output Fields:**
- `Company Name`, `Owner Name`, `AM Name`, `AC Name`
- `Gross Spent`, `Gross Discount`, `Credit Memo`, `Total Spent`
- `Remaining Gross` ← **This is the unspent contract $**
- `Target %`, `Actual Spend %`, `Health`
- `Deferred Revenue Balance`
- `Grace Period` (end_of_term + grace_period_days)

---

## Existing Tools & Data Sources

### HubSpot
- Deal pipeline tracking
- Contact/company management
- Activity tracking (calls, emails, meetings)
- Custom properties (AI deal scoring, weighted pipeline)
- Dashboards for funnel metrics

### BigQuery
- Revenue data (from QuickBooks via Fivetran)
- NRR calculations
- Quota tracking queries
- Customer LTV analysis

### Google Sheets
- Supply KPI Tracking (inventory by category)
- AM KPI Tracking (weekly scorecard)
- Upfront Contracts Workbook (spend tracking)
- Core KPI Dashboard V2 (quota tracker)

### Looker
- AM team reports (linked from KPI sheet)
- Various operational dashboards

### Smart Lead
- Outbound email sequences (Supply side)
- Contact enrollment tracking

### Asana
- Company goals tracking (currently manual)
- Department goal tabs
- Status tracking (On track / At risk / Missed / Achieved)
- Accounts Receivable task tracking (Invoices Due project)
- **BizSup project** — Business support requests (task flow tracking)
  - Stages: New → For Business Review → QUEUED → In Flight → Launched
  - **Requires Asana API integration** for task counts, timestamps, section tracking

### GitHub (RECESSDigital/recess-prd)
- PRD lifecycle tracking (draft → published → done)
- FSD (Feature Seed Design) creation tracking
- Implementation plan (i-plan) tracking
- **Requires GitHub API integration** for folder/file counts

### Shortcut
- Engineering stories and tickets
- Sprint velocity tracking (process maturing)
- **Requires Shortcut API integration** for story states, cycle time

### MongoDB (via Fivetran → BigQuery as `mongodb.*`)
- Platform invoice data
- Payout board (supplier/organizer payments)
- Bill status and vendor information
- Invoice line items
- **`mongodb.report_datas`** — Yearly limited capacity by event type (monthly snapshots, key="yearly_limited_capacity") — *coming soon to Fivetran sync*
- **`mongodb.audience_listings`** — Published listings (filter: published_state='published', is_omnichannel=FALSE)

### Bill.com (synced to MongoDB → BigQuery)
- Payment processing for vendors
- W-9 status tracking
- Vendor onboarding status
- Payment method (ACH, Instant Transfer)

### Recess Platform (app.recess.is → MongoDB → BigQuery)
- Payout Board dashboard
- Internal reconciliation data

---

## Dashboard Requirements Emerging

### 1. Design Principles
- **Prescriptive, not descriptive** — "Do X to get back on track" not just "here's your data"
- **Traffic light indicators** — Green/Yellow/Red for quick status
- **One metric per person** — Clear ownership
- **Automated updates** — No manual data entry
- **Simple for non-analytical users** — Supply person example

### 2. Dashboard Types Needed

| Dashboard | Audience | Purpose |
|-----------|----------|---------|
| CEO/COO Executive | Jack, Deuce | Company health at a glance |
| CFO Dashboard | CFO, Board, Leadership | Runway, concentration risk, strategic health |
| **Core Company KPIs** | **All (~18 people)** | **Replaces Asana manual updates — DESIGNED** |
| Supply Scorecard | Ian + leadership | Supply team metrics |
| Demand Sales Scorecard | Andy, Danny, Katie | Sales metrics |
| Demand AM Scorecard | Char's team | AM metrics |
| Marketing Scorecard | Marketing + leadership | Marketing-influenced pipeline |
| Accounting Operations | Accounting team | AR/AP, bill processing, reconciliation |
| Department Scorecards | Each dept | Dept-specific metrics |

### 3. Data Architecture
```
Source Systems (origin of data):
├── HubSpot → Pipeline, activities, contacts, marketing attribution
├── QuickBooks Online → Invoices, AR/AP, cash, balance sheet
├── MongoDB (Platform) → Payout board, vendor info, platform invoices
├── Bill.com → Payment processing, W-9 status, vendor onboarding
├── Smart Lead → Outbound email sequences (Supply)
├── Google Sheets → Goals, manual KPI inputs
└── Asana → Task tracking (AR invoices, company goals)

        ↓ ALL sync via Fivetran ↓

┌─────────────────────────────────────────┐
│        BigQuery (Single Query Layer)     │
│  ├── src_fivetran_hubspot.*             │
│  ├── src_fivetran_qbo.*                 │
│  ├── mongodb.*                          │
│  └── App_KPI_Dashboard.* (views)        │
└─────────────────────────────────────────┘

        ↓ Dashboard queries BigQuery ↓

Dashboard displays unified view
```

**Key Principle:** ALL dashboard queries go through BigQuery.
Source systems are never queried directly by the dashboard.

### 4. Security Requirement
- **Not on open web**
- Options to explore:
  - Internal tool with SSO/auth
  - VPN-only access
  - IP whitelisting
  - Google Workspace integration (internal users only)

---

## Core Company KPI Dashboard — Design

**Purpose:** The ONE page everyone opens daily. Replaces manual Asana goal updates.
**Audience:** All ~18 people
**Refresh:** Daily (overnight data update)

### Structure

```
┌─────────────────────────────────────────────────────────────┐
│  COMPANY HEALTH (North Star)                                │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Revenue vs Target (YTD)    $X.XM / $X.XM    🟢🟡🔴  │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  PER-PERSON SCORECARD (grouped by department)               │
│                                                             │
│  ── Supply ──────────────────────────────────────────────   │
│  Ian Hong        │ New Unique Inventory │ 12 │ 16  │ 🟡    │
│                                                             │
│  ── Supply AM ───────────────────────────────────────────   │
│  Ashton          │ NRR Top Supply Users │ 95%│ 110%│ 🟡    │
│                                                             │
│  ── Demand Sales ────────────────────────────────────────   │
│  Andy Cooper     │ NRR                  │107%│ 110%│ 🟡    │
│  Danny Sears     │ Pipeline Coverage    │2.8x│ 3.0x│ 🟡    │
│  Katie           │ Pipeline Coverage    │3.2x│ 3.0x│ 🟢    │
│                                                             │
│  ── Demand AM ───────────────────────────────────────────   │
│  Char Short      │ Contract Spend %     │ 89%│ 95% │ 🟡    │
│  Victoria        │ Calls per Week       │  5 │  10 │ 🔴    │
│  Claire          │ NPS Score            │ 71%│ 75% │ 🟡    │
│  Francisco       │ Offer Acceptance %   │ 88%│ 90% │ 🟢    │
│  Ashton          │ Ticket Response Time │16hr│<16hr│ 🟢    │
│                                                             │
│  ── Marketing ───────────────────────────────────────────   │
│  [Name]          │ Mktg-Influenced Pipe │ $X │ TBD │ ⚪    │
│                                                             │
│  ── Accounting ──────────────────────────────────────────   │
│  [Name]          │ Invoice Collection % │ 93%│ 95% │ 🟡    │
│                                                             │
│  ── Engineering/Product ─────────────────────────────────   │
│  VP              │ Features Fully Scoped│  3 │  5  │ 🟡    │
│  Dev 1           │ BizSup Completed     │  8 │ 10  │ 🟡    │
│  Dev 2           │ PRDs Generated       │  2 │  3  │ 🟡    │
│  Dev 3           │ FSDs Generated       │  1 │  2  │ 🟡    │
│                                                             │
│  ── CEO/Biz Dev ─────────────────────────────────────────   │
│  Jack            │ Revenue vs Target    │$7.9M│$10M │ 🟡    │
│                                                             │
│  ── COO/Ops ────────────────────────────────────────────   │
│  Deuce           │ Gross Margin %       │ 42%│ 45% │ 🟡    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Top section | Revenue vs Target only | Keep North Star prominent, avoid clutter |
| Grouping | By department | People find themselves quickly |
| Status indicators | 🟢🟡🔴⚪ | Green (on track), Yellow (at risk), Red (off track), Gray (no target set) |
| Visual design | TBD in design phase | Could be cards, tiles, gauges, progress bars — decide when building |
| Refresh cadence | Daily | Overnight batch update, fresh numbers every morning |
| Metrics without targets | Gray (⚪) indicator | Shows "tracking but no target yet" — visually distinct |
| Prescriptive actions | Show when 🟡 or 🔴 | Brief action item to get back on track |

### Per-Person Metric Summary (from all departments captured)

| Person | Department | Owned Metric | Target | Data Source |
|--------|-----------|--------------|--------|-------------|
| Ian Hong | Supply | New Unique Inventory Added | 16/quarter | BigQuery (HubSpot) |
| Ashton | Supply AM | NRR of Top Supply Users | TBD | BigQuery (QBO + HubSpot) |
| Andy Cooper | Demand Sales | NRR | >110% | BigQuery |
| Danny Sears | Demand Sales | Pipeline Coverage (Weighted) | 3.0x | BigQuery (HubSpot) |
| Katie | Demand Sales | Pipeline Coverage (Weighted) | 3.0x | BigQuery (HubSpot) |
| Char Short | Demand AM | Contract Spend % of Goal | 95% | BigQuery |
| Victoria | Demand AM | Total Brand Calls/Week | 10+ | HubSpot → BigQuery |
| Claire | Demand AM | NPS Score | 75% | Looker → BigQuery |
| Francisco | Demand AM | Offer Acceptance % | 90% | Looker → BigQuery |
| Ashton | Demand AM | Avg Ticket Response Time | <16 hrs | BigQuery (HubSpot) |
| [Marketing] | Marketing | Marketing-Influenced Pipeline | TBD | BigQuery (HubSpot) |
| [Accounting] | Accounting | Invoice Collection Rate | 95% | BigQuery (QBO) |
| VP Engineering | Engineering | Features Fully Scoped | TBD | GitHub API |
| Dev 1 | Engineering | BizSup Stories Completed | TBD | Asana API |
| Dev 2 | Engineering | PRDs Generated | TBD | GitHub API |
| Dev 3 | Engineering | FSDs Generated | TBD | GitHub API |
| Jack | CEO/Biz Dev | Revenue vs Target | $X.XM annual | BigQuery (QBO) |
| Deuce | COO/Ops | Gross Margin % | TBD (query baseline) | BigQuery (QBO P&L) |

**Note:** Ashton appears in both Supply AM (NRR) and Demand AM (Ticket Response) since they serve both functions. Dashboard could show primary metric only or both.

---

## Outstanding Items (To Gather)

### Departments Not Yet Captured:
- [x] Marketing (1 person) - ✅ Marketing-Influenced Pipeline (FT+LT)/2
- [x] Accounting/Finance (1 person) - ✅ Dual dashboard: Operations + CFO
- [x] Supply Account Mgmt (Ashton) - ✅ NRR of Top Supply Users, ticket response/close, revenue per user
- [x] Engineering/Product (VP + 3 devs) - ✅ Features Fully Scoped, BizSup throughput, PRD/FSD pipeline, Shortcut
- [x] CEO/Business Dev (Jack) - ✅ Revenue vs Target (owns entire revenue function)
- [x] COO/Ops (Deuce) - ✅ Gross Margin % (owns operational efficiency)
- [ ] AI Automations (1 person) - Automation metrics

### Design Decisions Pending:
- [ ] Technology stack for dashboard
  - **Flask** — Python web framework, full control, custom UI, good for internal tools with auth
  - **Streamlit** — Python data app framework, fast to build, native BigQuery/charting support
  - Retool — Low-code internal tool builder
  - Custom — Full custom build (React/Vue + API)
  - **Note:** Engineering metrics require direct API integrations (Asana, GitHub, Shortcut) — NOT BigQuery
- [ ] Security implementation approach
- [ ] Data refresh frequency
- [ ] Mobile access requirements
- [ ] Alert/notification system

### Questions to Answer:
- How analytical is rest of team? (A: Most similar to Supply, B: Mixed, C: Supply is exception)
- Where does Smart Lead data live? (API available?)
- Cycle time calculation specifics

---

## Key Insights from Session

1. **AM team is the model** — They already have "one metric per owner" with weekly tracking. Replicate this structure for all departments.

2. **Top-of-funnel is the constraint** — Both Supply and Demand have lead inventory problems. Dashboard should prominently show "lead runway."

3. **Pipeline coverage is the leading indicator** — For both Supply (event types) and Demand (quota buckets), coverage ratio predicts success.

4. **Stage-level goals are missing** — Teams know their end targets but not intermediate milestones. Funnel math query solves this.

5. **Data is scattered** — HubSpot, BigQuery, Sheets, Looker, Smart Lead, Asana, MongoDB, Bill.com. Unification is the core value prop.

6. **Prescriptive > Descriptive** — Non-analytical users need "do this" not "here's data." Traffic lights + action items.

7. **Customer concentration is existential risk** — 41% from HEINEKEN, 59% from top 2 customers. CFO dashboard must prominently track this.

8. **Accounting needs TWO dashboards** — Operations (bill processing, W-9 compliance) vs CFO (runway, cash, strategic metrics). Different audiences, different cadences.

9. **Reconciliation variance = data integrity** — QBO vs Platform Delta should be 0. Non-zero indicates data quality issues that affect all reporting.

10. **Marketing attribution needs baseline** — No historical data on marketing-influenced %. Must query BigQuery to set targets.

---

## Next Steps for New Session

1. **Continue department discovery:**
   - Marketing
   - Accounting/Finance
   - Supply Account Mgmt
   - Engineering/Product
   - AI Automations

2. **Design technology approach:**
   - Evaluate dashboard platforms
   - Plan data integration architecture
   - Address security requirements

3. **Create metric ownership matrix:**
   - One metric per person, company-wide
   - Clear definitions and data sources

4. **Write implementation plan**

---

## Session Metadata

**Brainstorming Skill Used:** superpowers:brainstorming
**Total Departments Captured:** 9 of 10 (Supply, Demand Sales, Demand AM, Marketing, Accounting/Finance, Supply AM, Engineering/Product, CEO/Biz Dev, COO/Ops)
**SQL Queries Documented:** 5
**Screenshots Reviewed:** 30+
**Key Documents Reviewed:**
- GMV Health Analysis Complete Report (Jan 2026)
- Q3 2025 Board Meeting Deck
- HubSpot Marketing Dashboard
- Payout Board (app.recess.is)
- Asana Accounts Receivable project

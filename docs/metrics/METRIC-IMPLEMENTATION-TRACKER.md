# Company KPI Dashboard - Metric Implementation Tracker

> **Purpose:** Single source of truth for all KPI definitions, calculations, and implementation status
> **Created:** 2026-02-03
> **Last Updated:** 2026-02-03
> **Owner:** Deuce (final approval on all confirmations)

---

## How to Use This Document

Each metric includes:
- **Definition** — What it measures in plain English
- **Why It Matters** — Business context and impact
- **Calculation** — Exact formula used
- **Data Sources** — BigQuery tables/views, Python functions, file locations
- **Current Values** — Latest numbers with dates
- **Implementation Status** — 4-gate progress tracker

### Implementation Gates

| Gate | Symbol | Meaning |
|------|--------|---------|
| **BQ View Exists** | 🗄️ | BigQuery view/query exists and returns data |
| **Python Function** | 🐍 | Function exists in `bigquery_client.py` |
| **UI Integrated** | 🖥️ | Metric displays in Streamlit dashboard |
| **User Confirmed** | ✅ | Deuce has confirmed the value is correct |

**Legend:**
- ✅ = Complete/Confirmed
- ⚠️ = Needs review/validation
- ❌ = Not working/Not started
- ⬜ = Not applicable/Pending

---

## MASTER STATUS SUMMARY

### Company Health Metrics (Core 7)

| # | Metric | Owner | BQ View | Python Fn | UI | Confirmed | 2025 Value | 2026 Value |
|---|--------|-------|:-------:|:---------:|:--:|:---------:|------------|------------|
| 1 | Revenue YTD | Jack | ✅ | ✅ | ✅ | ⬜ | $4.04M | $18K |
| 2 | Take Rate % | Deuce | ✅ | ✅ | ✅ | ⬜ | 49.3% | ~0% |
| 3 | Demand NRR | Andy | ✅ | ✅ | ✅ | ⬜ | 22% | 0.15% |
| 4 | Supply NRR | Ashton | ✅ | ✅ | ✅ | ⬜ | 67% | ~0% |
| 5 | Pipeline Coverage | Andy | ✅ | ✅ | ✅ | ⬜ | N/A | 3.26x |
| 6 | Logo Retention | ? | ✅ | ✅ | ✅ | ⬜ | 26% | N/A |
| 7 | Customer Count | ? | ✅ | ✅ | ✅ | ⬜ | 51 | TBD |

### Person-Level Metrics (Priority)

| # | Metric | Owner | BQ View | Python Fn | UI | Confirmed | Current Value |
|---|--------|-------|:-------:|:---------:|:--:|:---------:|---------------|
| 8 | Contract Spend % | Char | ✅ | ✅ | ❌ | ⬜ | TBD |
| 9 | Days to Fulfill Contract Spend | Victoria | ✅ | ✅ | ✅ | ⬜ | 69 days (median) |
| 10 | NPS Score | Claire | ✅ | ✅ | ❌ | ⬜ | TBD |
| 11 | Customer Concentration | ? | ✅ | ✅ | ⚠️ | ⬜ | 29.2% (HEINEKEN) |
| 12 | Churned Customers | ? | ✅ | ✅ | ❌ | ⬜ | 426 |

### Not Yet Implemented

| # | Metric | Owner | BQ View | Python Fn | UI | Notes |
|---|--------|-------|:-------:|:---------:|:--:|-------|
| 13 | Sellable Inventory | Ian | ❌ | ❌ | ⚠️ | Placeholder card shows "Needs PRD" |
| 14 | New Unique Inventory | Ian | ❌ | ❌ | ⚠️ | Mock data only |
| 15 | NRR Top Supply Users | Ashton | ❌ | ❌ | ⚠️ | Mock data only |
| 16 | Offer Acceptance % | Francisco | ❌ | ❌ | ⚠️ | Mock data only |
| 17 | Mktg-Influenced Pipeline | Marketing | ❌ | ❌ | ⚠️ | Mock data only |
| 18 | Invoice Collection % | Accounting | ❌ | ❌ | ⚠️ | Mock data only |
| 19 | Engineering Metrics (4) | VP Eng | ❌ | ❌ | ⚠️ | Requires Asana/GitHub API |

---

## DETAILED METRIC SPECIFICATIONS

---

### 1. Revenue YTD

| Field | Value |
|-------|-------|
| **Owner** | Jack |
| **Target** | $5,521,390 (from targets.json) |
| **Status** | BQ ✅ → Python ✅ → UI ✅ → Confirmed ⬜ |

#### Definition
Total invoiced revenue for the current fiscal year from marketplace activities.

#### Why It Matters
The north star metric for the company. Revenue (not GMV) represents actual money earned by Recess, measuring true business performance and growth trajectory.

#### Calculation
```
Revenue YTD = SUM(invoice_line.amount)
WHERE:
  - invoice.transaction_date is in current fiscal year
  - account.account_sub_type IN ('SalesOfProductIncome', 'ServiceFeeIncome')
  - account.account_number BETWEEN 4000 AND 4190
  - account.account_number NOT IN (4250, 4260, 4300, 4310)
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery Tables** | `src_fivetran_qbo.invoice_line`, `invoice`, `account` |
| **Python Function** | `bigquery_client.get_revenue_ytd()` |
| **File Location** | `dashboard/data/bigquery_client.py:79` |

#### Current Values
| Year | Value | Notes |
|------|-------|-------|
| 2025 | **$4,040,000** | Full year |
| 2026 | **$18,284** | YTD (Feb 3) - early year |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:**

---

### 2. Take Rate %

| Field | Value |
|-------|-------|
| **Owner** | Deuce |
| **Target** | 51% (from targets.json) |
| **Status** | BQ ✅ → Python ✅ → UI ✅ → Confirmed ⬜ |

#### Definition
Percentage of GMV (Gross Merchandise Value) that Recess keeps as marketplace revenue. Formerly called "Gross Margin."

#### Why It Matters
Measures marketplace efficiency and pricing power. Higher take rate = more revenue per dollar of GMV. Tracks profitability of the platform model and helps identify pricing optimization opportunities.

#### Calculation
```
Take Rate = Marketplace Revenue / GMV

Where:
- GMV = Accounts 4110-4169 (Sampling, Sponsorship, Activation GMV)
- Marketplace Revenue = GMV + Discounts (4190) + Organizer Fees (4200s)
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery Tables** | `src_fivetran_qbo.invoice_line`, `credit_memo_line`, `bill_line`, `vendor_credit_line` |
| **Python Function** | `bigquery_client.get_take_rate()` |
| **File Location** | `dashboard/data/bigquery_client.py:113` |

#### Current Values
| Year | GMV | Marketplace Revenue | Take Rate | Notes |
|------|-----|---------------------|-----------|-------|
| 2025 | $7.92M | $3.90M | **49.3%** | Full year |
| 2026 | <$100K | — | **~0%** | Falls back to 2025 |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:**

---

### 3. Demand NRR (Net Revenue Retention)

| Field | Value |
|-------|-------|
| **Owner** | Andy |
| **Target** | 110% (from targets.json) |
| **Status** | BQ ✅ → Python ✅ → UI ✅ → Confirmed ⬜ |

#### Definition
Percentage of prior year's revenue retained from the same customer cohort in the current year. Measures customer expansion/contraction on the demand (brand) side.

#### Why It Matters
NRR > 100% means existing customers are spending MORE year-over-year (expansion). NRR < 100% means contraction. This is the leading indicator of customer health and predicts future revenue stability without new customer acquisition.

#### Calculation
```
Demand NRR = (Prior year cohort's current year revenue) / (Their prior year revenue) × 100

Example for 2026:
- Cohort: Customers who had revenue in 2025
- Numerator: That cohort's 2026 revenue
- Denominator: That cohort's 2025 revenue
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery View** | `App_KPI_Dashboard.cohort_retention_matrix_by_customer` |
| **Python Functions** | `bigquery_client.get_nrr()`, `get_demand_nrr_details()` |
| **File Location** | `dashboard/data/bigquery_client.py:213`, `:251` |

#### Current Values
| Comparison | Cohort | Original Rev | Next Year Rev | NRR |
|------------|--------|--------------|---------------|-----|
| 2025 Actuals | 2024 | $1,517,381 | $337,591 | **22.2%** |
| 2026 YTD | 2025 | $1,008,415 | $1,549 | **0.15%** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** NRR below 100% = cohort contraction (expected early in year)

---

### 4. Supply NRR

| Field | Value |
|-------|-------|
| **Owner** | Ashton |
| **Target** | 110% |
| **Status** | BQ ✅ → Python ✅ → UI ✅ → Confirmed ⬜ |

#### Definition
Percentage of prior year's payouts retained from the same supplier cohort in the current year. Measures venue/event partner retention and expansion.

#### Why It Matters
Tracks health of the supply side of the marketplace. High Supply NRR means venues are hosting more events year-over-year, indicating strong supply-side relationships and network effects.

#### Calculation
```
Supply NRR = (Prior year supplier cohort's current year payouts) / (Their prior year payouts) × 100

Example for 2026:
- Cohort: Suppliers who received payouts in 2025
- Numerator: That cohort's 2026 payouts
- Denominator: That cohort's 2025 payouts
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery View** | `App_KPI_Dashboard.Supplier_Metrics` |
| **Python Functions** | `bigquery_client.get_supply_nrr()`, `get_supply_nrr_details()` |
| **File Location** | `dashboard/data/bigquery_client.py:321`, `:362` |

#### Current Values
| Comparison | Cohort | Original Payouts | Next Year Payouts | NRR |
|------------|--------|------------------|-------------------|-----|
| 2025 Actuals | 2024 | $2.74M | $1.83M | **66.7%** |
| 2026 YTD | 2025 | $2.98M | ~$0 | **~0%** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Same seasonal pattern as Demand NRR - shows contraction early in year

---

### 5. Pipeline Coverage

| Field | Value |
|-------|-------|
| **Owner** | Andy |
| **Target** | 3.0x |
| **Status** | BQ ✅ → Python ✅ → UI ✅ → Confirmed ⬜ |

#### Definition
Ratio of weighted pipeline value to remaining quarterly revenue goal. Indicates likelihood of hitting quota.

#### Why It Matters
Leading indicator of sales health. 3x coverage means enough deals in pipeline to absorb typical close rates and still hit target. Below 3x = warning sign. Above 3x = healthy position.

#### Calculation
```
Pipeline Coverage = HubSpot Weighted Pipeline / Remaining Quarterly Goal

Where:
- Annual Goal = Sum of HubSpot Company Property quotas ($9.27M) + Unnamed deals ($2M) = $11.27M
- Quarterly Goal = Annual Goal / 4
- Remaining = Quarterly Goal - Closed Won (this quarter)
- Weighted Pipeline = Deal amount × Deal probability (closing this quarter)
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery Tables** | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.company` |
| **Python Functions** | `bigquery_client.get_pipeline_coverage()`, `get_pipeline_details()` |
| **File Location** | `dashboard/data/bigquery_client.py:637`, `:665` |

#### Current Values (Q1 2026)
| Metric | Value |
|--------|-------|
| Annual Goal | $11,268,142 |
| Q1 Goal | $2,817,036 |
| Closed Won | $630,658 |
| Remaining to Goal | $2,186,377 |
| HS Weighted Pipeline | $7,132,571 |
| Total Pipeline (raw) | $9,929,168 |
| Open Deals | 94 |
| **Pipeline Coverage** | **3.26x** ✅ |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Dynamic quota from HubSpot company properties now working

---

### 6. Logo Retention

| Field | Value |
|-------|-------|
| **Owner** | TBD |
| **Target** | 50% |
| **Status** | BQ ✅ → Python ✅ → UI ✅ → Confirmed ⬜ |

#### Definition
Percentage of customers (logos) from prior year that generated revenue in current year. Counts customers, not dollars.

#### Why It Matters
Measures customer loyalty independent of spend. A company could have high NRR (existing customers spending more) but low Logo Retention (losing many small customers). Both metrics together tell the full retention story.

#### Calculation
```
Logo Retention = Customers with revenue in BOTH years / Customers with revenue in prior year

Example (2024→2025):
- 535 customers had revenue in 2024
- 139 of those also had revenue in 2025
- Logo Retention = 139 / 535 = 26%
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery View** | `App_KPI_Dashboard.customer_development` |
| **Python Function** | `bigquery_client.get_logo_retention()` |
| **File Location** | `dashboard/data/bigquery_client.py:543` |

#### Current Values
| Period | Retained | Total | Logo Retention |
|--------|----------|-------|----------------|
| 2024→2025 | ~139 | ~535 | **26%** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Uses COUNT(DISTINCT customer_id) due to multiple rows per customer

---

### 7. Customer Count (Active Customers)

| Field | Value |
|-------|-------|
| **Owner** | TBD |
| **Target** | 75 |
| **Status** | BQ ✅ → Python ✅ → UI ✅ → Confirmed ⬜ |

#### Definition
Number of unique customers with positive net revenue in the current fiscal year.

#### Why It Matters
Tracks customer base growth. Combined with Logo Retention, shows whether growth is coming from new logos vs. existing customer expansion. Important for understanding concentration risk.

#### Calculation
```
Customer Count = COUNT(DISTINCT customer_id)
WHERE Net_Revenue_{fiscal_year} > 0
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery View** | `App_KPI_Dashboard.customer_development` |
| **Python Function** | `bigquery_client.get_customer_count()` |
| **File Location** | `dashboard/data/bigquery_client.py:432` |

#### Current Values
| Year | Active Customers |
|------|-----------------|
| 2025 | **51** |
| 2026 | TBD (early year) |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Customers with Net_Revenue_2025 > 0

---

### 8. Contract Spend %

| Field | Value |
|-------|-------|
| **Owner** | Char |
| **Target** | 95% |
| **Status** | BQ ✅ → Python ✅ → UI ❌ → Confirmed ⬜ |

#### Definition
Percentage of upfront contract value that has been invoiced/spent across all active contracts.

#### Why It Matters
Measures how well Account Management is executing against committed deals. Low spend % = contracts not being fulfilled = deferred revenue risk and unhappy customers. High spend % = strong execution and revenue recognition.

#### Calculation
```
Contract Spend % = Total Invoiced Amount / Total Contract Value

Calculated per contract, then aggregated:
- Gross Spend = SUM of GMV invoice line items
- Contract Value = Deal amount from HubSpot
- Spend % = Gross Spend / Contract Value
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery View** | `App_KPI_Dashboard.Upfront_Contract_Spend_Query` |
| **Python Function** | `bigquery_client.get_contract_spend_pct()` |
| **File Location** | `dashboard/data/bigquery_client.py:992` |
| **Full Query** | See `queries/upfront_contract_spend.sql` |

#### Current Values
| Metric | Value |
|--------|-------|
| Contract Spend % (aggregate) | **TBD - needs query** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Python function exists but not wired to UI

---

### 9. Days to Fulfill Contract Spend (From Close Date)

| Field | Value |
|-------|-------|
| **Owner** | Victoria |
| **Target** | 60 days (based on 69-day median) |
| **Status** | BQ ✅ → Python ✅ → UI ✅ → Confirmed ⬜ |

#### Definition
Days from Closed Won date until contract spend reaches 100% of the contract value.

#### Why It Matters
Measures operational efficiency in program execution. Faster fulfillment improves customer satisfaction, accelerates cash flow, and reduces deferred revenue balance. This is the key ops velocity metric.

#### Calculation
```
Days to Fulfill = Date of 100% spend - Closed Won date

Where:
- Closed Won date = HubSpot closedate (when deal moved to Closed Won)
- Contract amount = HubSpot property_amount (the closed deal value)
- Date of 100% spend = First invoice date where cumulative spend >= contract amount

How Gross Spend is Calculated:
- GMV Invoices: Sum of invoice line items for GMV categories
  (Event Sponsorship Fee, Sampling, Activation, Sponsorship, etc.)
- Credit Memos: Subtracted from gross (reduces spend)
- Formula: Gross Spend = GMV Invoice Lines - Credit Memos

Process:
1. Get contract close date and amount from HubSpot (Closed Won deals)
2. Get all invoices linked to contract, ordered by date
3. Get credit memos linked to same contract
4. Calculate running cumulative spend (invoices - credit memos)
5. Find first invoice date where cumulative spend >= contract amount
6. Days = that invoice date - close date
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery View** | `App_KPI_Dashboard.Days_to_Fulfill_Contract_Spend_From_Close_Date` |
| **Legacy View** | `App_KPI_Dashboard.Days_to_Fulfill_Contract_Program` (deprecated - only measured offer date span) |
| **Python Function** | `bigquery_client.get_time_to_fulfill()` ✅ Updated with fallback |
| **File Location** | `dashboard/data/bigquery_client.py:1064` |
| **Full Query** | `sql/reports/days-to-fulfill-contract-spend.sql` (run in BigQuery console) |

#### Query Logic (Summary)
```sql
-- Key CTEs:
-- 1. hubspot_deals: Get closed-won contracts with amount
-- 2. invoice_amounts: Get GMV invoice lines per contract
-- 3. cumulative_spend: Running total by invoice date
-- 4. fulfillment_date: First date where cumulative >= contract amount

SELECT
    deal_id,
    contract_amount,
    contract_close_date,
    date_100_pct_spent,
    DATE_DIFF(date_100_pct_spent, contract_close_date, DAY) AS days_close_to_fulfill,
    fulfillment_status  -- 'Fulfilled', 'In Progress', 'No Invoices'
FROM ...
```

#### Current Values (as of 2026-02-03)
| Metric | Value | Notes |
|--------|-------|-------|
| **Median Days** | **69 days** | Recommended primary metric |
| Average Days | 156 days | Skewed by outliers |
| Min Days | -113 days | Pre-invoicing before close |
| Max Days | 864 days | Old/stale contracts |
| Fulfilled Contracts | 177 | $23.9M in contract value |
| In Progress | 49 | $3.3M still being executed |

#### Sample Data
| Contract | Amount | Close Date | 100% Spent | Days |
|----------|--------|------------|------------|------|
| Lunchables (Kraft) | $80K | Oct 8 | Oct 10 | **2 days** |
| Kraft Lunchables/KMC | $90K | Jul 9 | Jul 30 | **21 days** |
| Danone Stok Energy | $50K | Aug 21 | Sep 19 | **29 days** |
| Ferrara Nerds | $70K | Oct 2 | Nov 19 | **48 days** |
| PepsiCo Mt Dew | $25K | Aug 7 | Dec 5 | **120 days** |

#### Why This Replaced the Old Metric
| Old Metric | New Metric |
|------------|------------|
| First offer → Last offer date span | Contract close → 100% invoiced |
| No financial awareness | Tracks actual $ fulfillment |
| 14 days median (misleading) | 69 days median (accurate) |
| Didn't know if contract was "done" | Knows exactly when 100% spent |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** New view created 2026-02-03. Python function needs update.

---

### 10. NPS Score

| Field | Value |
|-------|-------|
| **Owner** | Claire |
| **Target** | 75 |
| **Status** | BQ ✅ → Python ✅ → UI ❌ → Confirmed ⬜ |

#### Definition
Net Promoter Score from organizer recap surveys. Measures customer satisfaction and likelihood to recommend Recess.

#### Why It Matters
Leading indicator of customer retention and word-of-mouth growth. High NPS correlates with renewals, referrals, and expansion. Low NPS signals churn risk.

#### Calculation
```
NPS = % Promoters (9-10) - % Detractors (0-6)

Score ranges:
- 9-10: Promoters
- 7-8: Passives (not counted)
- 0-6: Detractors
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery View** | `App_KPI_Dashboard.organizer_recap_NPS_score` |
| **Python Function** | `bigquery_client.get_nps_score()` |
| **File Location** | `dashboard/data/bigquery_client.py:1060` |

#### Current Values
| Metric | Value |
|--------|-------|
| NPS Score | **TBD - needs query** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Python function exists but not wired to UI

---

### 11. Customer Concentration

| Field | Value |
|-------|-------|
| **Owner** | TBD |
| **Target** | <30% (top customer) |
| **Status** | BQ ✅ → Python ✅ → UI ⚠️ → Confirmed ⬜ |

#### Definition
Percentage of total revenue from the largest customer(s). Measures revenue concentration risk.

#### Why It Matters
High concentration = high risk. If top customer churns, revenue impact is severe. Target <30% for top customer, <50% for top 2. Diversification reduces business risk.

#### Calculation
```
Customer Concentration = Customer Revenue / Total Revenue × 100

Typically reported as:
- Top 1 customer %
- Top 2 customers combined %
- Top 5 customers combined %
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery View** | `App_KPI_Dashboard.net_revenue_retention_all_customers` |
| **Python Function** | `bigquery_client.get_customer_concentration()` |
| **File Location** | `dashboard/data/bigquery_client.py:485` |

#### Current Values (2025)
| Rank | Customer | Revenue | % of Total |
|------|----------|---------|------------|
| 1 | HEINEKEN USA | $1.18M | **29.2%** |
| 2 | Kraft Heinz | $957K | 23.7% |
| 3 | Advantage Solutions | $224K | 5.5% |
| 4 | Church & Dwight | $183K | 4.5% |
| 5 | Peace Tea | $126K | 3.1% |
| — | **Top 2 Combined** | — | **52.9%** ⚠️ |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Top 2 concentration (52.9%) is a risk factor

---

### 12. Churned Customers

| Field | Value |
|-------|-------|
| **Owner** | TBD |
| **Target** | N/A (minimize) |
| **Status** | BQ ✅ → Python ✅ → UI ❌ → Confirmed ⬜ |

#### Definition
Count of customers who had revenue in the prior year but $0 in the current year.

#### Why It Matters
Direct measure of customer loss. Combined with Logo Retention, helps understand the "leaky bucket" - how many customers leave each year. High churn requires more new logos just to stay flat.

#### Calculation
```
Churned Customers = COUNT(customers WHERE prior_year_revenue > 0 AND current_year_revenue = 0)
```

#### Data Sources
| Source | Location |
|--------|----------|
| **BigQuery View** | `App_KPI_Dashboard.customer_development` |
| **Python Function** | `bigquery_client.get_churned_customers()` |
| **File Location** | `dashboard/data/bigquery_client.py:458` |

#### Current Values
| Period | Churned Count |
|--------|---------------|
| 2024→2025 | **426 customers** |

#### Confirmation
- [ ] **Deuce Confirmed:** ⬜ Not yet confirmed
- **Date:**
- **Notes:** Had 2024 revenue but $0 in 2025

---

## NOT YET IMPLEMENTED METRICS

### 13. Sellable Inventory
- **Owner:** Ian
- **Definition:** Count of inventory items currently available and meeting "sellable" criteria
- **Why It Matters:** Measures supply-side capacity to fulfill demand
- **Blocker:** Need PRD to define "sellable" criteria
- **Status:** ❌ BQ → ❌ Python → ⚠️ UI (placeholder)

### 14. New Unique Inventory
- **Owner:** Ian
- **Definition:** Count of new inventory items added in period
- **Why It Matters:** Measures supply growth and marketplace expansion
- **Status:** ❌ BQ → ❌ Python → ⚠️ UI (mock data)

### 15. NRR Top Supply Users
- **Owner:** Ashton
- **Definition:** NRR calculated only for top suppliers (Pareto - 80% of payouts)
- **Why It Matters:** Focuses retention on highest-value supply partners
- **Status:** ❌ BQ → ❌ Python → ⚠️ UI (mock data)

### 16. Offer Acceptance %
- **Owner:** Francisco
- **Definition:** Percentage of offers sent that are accepted by venues
- **Why It Matters:** Measures supply engagement and offer quality
- **Status:** ❌ BQ → ❌ Python → ⚠️ UI (mock data)

### 17. Marketing-Influenced Pipeline
- **Owner:** Marketing
- **Definition:** Pipeline value where marketing touchpoint influenced the deal
- **Why It Matters:** Measures marketing ROI and contribution to revenue
- **Calculation:** (First Touch + Last Touch) / 2 attribution
- **Status:** ❌ BQ → ❌ Python → ⚠️ UI (mock data)

### 18. Invoice Collection %
- **Owner:** Accounting
- **Definition:** Percentage of invoiced amount collected within terms
- **Why It Matters:** Measures cash flow efficiency and AR health
- **Status:** ❌ BQ → ❌ Python → ⚠️ UI (mock data)

### 19. Engineering Metrics (4)
- **Owner:** VP Engineering
- **Metrics:**
  - Features Fully Scoped (PRD + FSD complete)
  - Business Support Tickets Closed
  - PRDs Completed
  - FSDs Completed
- **Why It Matters:** Measures engineering throughput and planning quality
- **Blocker:** Requires Asana/GitHub/Shortcut API integrations (not BigQuery)
- **Status:** ❌ BQ → ❌ Python → ⚠️ UI (mock data)

---

## BIGQUERY VIEWS INVENTORY

| View Name | Dataset | Purpose | Used By |
|-----------|---------|---------|---------|
| `cohort_retention_matrix_by_customer` | App_KPI_Dashboard | Demand NRR | `get_nrr()` |
| `net_revenue_retention_all_customers` | App_KPI_Dashboard | Customer concentration, drill-down | `get_customer_concentration()` |
| `customer_development` | App_KPI_Dashboard | Customer count, logo retention, churn | `get_customer_count()`, `get_logo_retention()`, `get_churned_customers()` |
| `Supplier_Metrics` | App_KPI_Dashboard | Supply NRR | `get_supply_nrr()` |
| `Upfront_Contract_Spend_Query` | App_KPI_Dashboard | Contract spend % | `get_contract_spend_pct()` |
| `Days_to_Fulfill_Contract_Spend_From_Close_Date` | App_KPI_Dashboard | Days to fulfill (NEW) | TBD |
| `Days_to_Fulfill_Contract_Program` | App_KPI_Dashboard | Days to fulfill (DEPRECATED) | `get_time_to_fulfill()` |
| `organizer_recap_NPS_score` | App_KPI_Dashboard | NPS score | `get_nps_score()` |

---

## PYTHON FUNCTIONS INVENTORY

| Function | Line | Returns | UI Status |
|----------|------|---------|-----------|
| `get_revenue_ytd()` | :79 | float | ✅ |
| `get_take_rate()` | :113 | float | ✅ |
| `get_nrr()` | :213 | float | ✅ |
| `get_demand_nrr_details()` | :251 | dict | ⚠️ |
| `get_supply_nrr()` | :321 | float | ✅ |
| `get_supply_nrr_details()` | :362 | dict | ⚠️ |
| `get_customer_count()` | :432 | int | ✅ |
| `get_churned_customers()` | :458 | int | ❌ |
| `get_customer_concentration()` | :485 | dict | ⚠️ |
| `get_logo_retention()` | :543 | float | ✅ |
| `get_quota_from_company_properties()` | :583 | dict | ✅ |
| `get_pipeline_coverage()` | :637 | float | ✅ |
| `get_pipeline_details()` | :665 | dict | ⚠️ |
| `get_pipeline_coverage_by_owner()` | :807 | list | ❌ |
| `get_company_metrics()` | :962 | dict | ✅ |
| `get_contract_spend_pct()` | :992 | float | ❌ |
| `get_time_to_fulfill()` | :1064 | dict | ✅ Updated - tries new view, falls back to legacy |
| `get_avg_days_to_fulfill()` | :1048 | float | ❌ |
| `get_nps_score()` | :1060 | float | ❌ |

---

## NEXT STEPS (PRIORITIZED)

### Immediate
1. [x] Create BigQuery view `Days_to_Fulfill_Contract_Spend_From_Close_Date` - ✅ DEPLOYED to BigQuery
2. [x] Update Python function for new Days to Fulfill view
3. [ ] Wire Contract Spend % to UI
4. [ ] Wire NPS Score to UI
5. [ ] Wire Churned Customers to UI

### Short-term
6. [ ] Update UI labels: "Gross Margin" → "Take Rate"
7. [ ] Add 2025 reference values for context
8. [x] Set target for Days to Fulfill (60 days based on 69-day median)

### Medium-term
9. [ ] Set up Cloud Scheduler for daily refresh
10. [ ] Define "sellable" inventory criteria (PRD needed)
11. [ ] Integrate engineering metrics via API

---

## CHANGE LOG

| Date | Change | By |
|------|--------|-----|
| 2026-02-03 | Initial tracker created | Claude |
| 2026-02-03 | Added comprehensive definitions for all 12 implemented metrics | Claude |
| 2026-02-03 | Created new Days to Fulfill query (from close date to 100% spend) | Claude |
| 2026-02-03 | Added Definition/Why It Matters/Calculation format for all metrics | Claude |
| 2026-02-03 | Clarified spend calculation: GMV invoices - credit memos = gross spend | Claude |
| 2026-02-03 | Updated Python function with fallback pattern, wired to UI | Claude |
| 2026-02-03 | **DEPLOYED** BigQuery view via bq CLI - verified: 177 fulfilled, 69-day median | Claude |
| | | |

# Learnings & Gotchas

> **Purpose:** Document unexpected behaviors, gotchas, and lessons learned.
> **Rule:** Log discoveries IMMEDIATELY - don't wait for session end.
> **This file is append-only** - never delete entries.

---

## Format

```markdown
### YYYY-MM-DD - [Category] Brief Title

**Context:** What were you doing?
**Gotcha:** What was unexpected?
**Solution:** How to handle it correctly
**Files:** Related files (if any)
```

---

## Entries

### 2026-02-03 - [Data] Pipeline Coverage quota calculation excludes DG and Walmart

**Context:** Validating Pipeline Coverage metric, user clarified quota should be $9.27M from company properties + $2M unnamed = $11.27M total
**Gotcha:** Not all HubSpot quota properties are included in the main goal:
- **Included:** `land_expand_quota` ($3.90M), `new_customer_quota` ($2.46M), `renewal_quota` ($2.91M) = **$9,268,142**
- **Excluded:** `dg_quota` ($385k), `walmart_quota` ($787k) - tracked separately
- **Unnamed accounts:** $2M added for accounts without company records
- **Total annual goal:** $11,268,142
**Solution:** Created `get_quota_from_company_properties()` that sums only the three included quota types. Added configurable `unnamed_accounts_adjustment` parameter (default $2M). DG and Walmart quotas are fetched but returned separately for reference.
**Files:** `dashboard/data/bigquery_client.py` - `get_quota_from_company_properties()`, `get_pipeline_coverage()`, `get_pipeline_details()`

---

### 2026-02-03 - [Data] customer_development view has MULTIPLE ROWS per customer

**Context:** Validating Logo Retention and Active Customers metrics
**Gotcha:** The `customer_development` view returns 2,468 rows but only 209 unique customers. Each row represents a customer-supplier-deal combination. Counting rows (535 with 2024 revenue) vs counting DISTINCT customer_id (69 customers) gives wildly different results!
**Solution:** ALWAYS use `COUNT(DISTINCT customer_id)` when counting customers from this view. The correct metrics are:
- Customers with 2024 revenue: **69** (not 535)
- Customers with 2025 revenue: **40** (not 566)
- Logo Retention: **26.1%** (18/69, not 17.9% from 96/535)
- Churned Customers: **51** (not 426)
**Files:** `dashboard/data/bigquery_client.py` - all customer count queries

---

### 2026-02-03 - [Data] Take Rate uses Supplier_Metrics, NOT QuickBooks accounts

**Context:** Debugging Take Rate query returning 0% in KPI Dashboard
**Gotcha:** The design doc specified "4000 Services Revenue / 4100 GMV" from QuickBooks accounts, but those account ranges (4000-4099) don't exist in the chart of accounts. Revenue accounts are 4110, 4120, 4130 (GMV types) and 4190 (discounts).
**Solution:** Use `App_KPI_Dashboard.Supplier_Metrics` which has pre-calculated `GMV`, `Payouts`, and `take_amount` per offer. Take Rate = take_amount / GMV (~62% for 2025).
**Files:** `dashboard/data/bigquery_client.py`

### 2026-02-03 - [Data] NRR requires fiscal year fallback logic

**Context:** Debugging NRR query returning -2% instead of expected ~107%
**Gotcha:** Early in fiscal year, current year NRR is meaningless (one credit memo can make it negative). The query was calculating 2026/2025 but 2026 only has -$67K revenue (credit memos exceed invoices so far).
**Solution:** Add threshold check: if current year revenue < $500K, show prior complete year NRR instead. Query now shows 2025 NRR (65%) which is the most recent meaningful metric.
**Files:** `dashboard/data/bigquery_client.py`

### 2026-02-03 - [Business] NRR of 65% is correct (customer contraction)

**Context:** Validating NRR calculation seemed too low (expected >100%)
**Gotcha:** The 65% NRR is mathematically correct: 74 customers with 2024 revenue ($4.56M) generated only $2.97M in 2025. This is true cohort-based NRR showing significant customer contraction.
**Solution:** The metric is working correctly. Total revenue only dropped 11% (not 35%) because new customers offset churn. Consider adding "Gross Revenue Retention" and "New Customer Revenue" as complementary metrics.
**Files:** None - business insight

### 2026-01-22 - [Architecture] BigQuery is the ONLY query layer

**Context:** Gathering Accounting/Finance dashboard metrics
**Gotcha:** Initially labeled data sources as "MongoDB" or "QuickBooks" — but ALL data syncs to BigQuery via Fivetran. The dashboard never queries source systems directly.
**Solution:** Always reference BigQuery as the data source. Use schema prefixes to indicate origin: `src_fivetran_qbo.*`, `src_fivetran_hubspot.*`, `mongodb.*`, `App_KPI_Dashboard.*` (views)
**Files:** `context/plans/2026-01-22-dashboard-brainstorm.md`

### 2026-01-22 - [Design] Accounting needs TWO dashboards

**Context:** Capturing Accounting/Finance department requirements
**Gotcha:** "Accounting" actually serves two completely different audiences with different needs:
  1. Accounting Operations (daily) — bill processing, W-9 compliance, reconciliation
  2. CFO Dashboard (strategic) — runway, concentration risk, NRR, board metrics
**Solution:** Always treat these as separate dashboards with separate refresh cadences and audiences.
**Files:** `context/plans/2026-01-22-dashboard-brainstorm.md`

### 2026-01-22 - [Business] Marketing attribution = (FT + LT) / 2

**Context:** Gathering Marketing department metrics
**Gotcha:** User initially just said "marketing-influenced pipeline" — but the specific formula matters: First Touch + Last Touch divided by 2 (each gets 50% credit). This is a linear attribution model, not full credit to either.
**Solution:** Always use (FT + LT) / 2 for marketing-influenced pipeline calculations.
**Files:** `context/plans/2026-01-22-dashboard-brainstorm.md`

### 2026-01-22 - [Business] Pipeline coverage needs THREE weightings

**Context:** Refining CFO Dashboard pipeline metrics
**Gotcha:** "Pipeline coverage" is not a single number. The company tracks it three ways: Unweighted (raw amounts), HubSpot Weighted (stage probability), and AI Weighted (deal quality tier). Each tells a different story.
**Solution:** Always show all three coverage ratios. Unweighted target >3x, weighted targets >1.5x. Total Quota comes from HubSpot company property.
**Files:** `context/plans/2026-01-22-dashboard-brainstorm.md`

### 2026-01-22 - [Business] Factoring capacity alerts

**Context:** Defining accounting operations metrics
**Gotcha:** Factoring has a hard $1M limit. Alert thresholds are: 🟢 >$400K available / 🟡 $200K-$400K / 🔴 <$200K. Fees tracked under P&L Finance Charges.
**Solution:** Calculate Available Capacity = Limit ($1M) - Balance. Show factoring fees YTD from P&L.
**Files:** `context/plans/2026-01-22-dashboard-brainstorm.md`

### 2026-02-03 - [Data] Deal type to quota category mapping

**Context:** Building pipeline coverage by quota type (New Customer, Renewal, Land & Expand)
**Gotcha:** HubSpot `property_dealtype` values don't match quota categories exactly:
- `newbusiness` → **New Customer** quota
- `existingbusiness`, `Renewal 2`, `Campaign - Existing` → **Renewal** quota
- `Land and Expand` → **Land & Expand** quota
- Other values (`Pilot`, `Campaign`) → **Other** (not tracked against quota)
**Solution:** Use CASE statement to map deal types to quota categories. Also discovered `property_ai_weighted_forecast` for AI-based pipeline weighting (more conservative than HS weighted).
**Files:** `dashboard/data/queries/pipeline_coverage_by_quota_type.sql`, `dashboard/data/queries/pipeline_coverage_by_company.sql`

---

### 2026-02-03 - [Data] Deals can be linked to multiple companies in HubSpot

**Context:** Pipeline coverage queries were double-counting deals
**Gotcha:** The `deal_company` association table can have multiple companies per deal (e.g., Chobani + lacolombe.net for the same deal). This causes pipeline to be counted multiple times.
**Solution:** Deduplicate by `deal_id` using ROW_NUMBER(), assigning each deal to the company with the **highest quota** (most likely the intended attribution). Use `WHERE rn = 1` to get one row per deal.
**Files:** `dashboard/data/bigquery_client.py` - all pipeline coverage functions

---

<!-- Add new learnings above this line, newest first -->

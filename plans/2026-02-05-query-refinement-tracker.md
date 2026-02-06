# Query Refinement Tracker — Owner Review Required

> **Purpose:** Prioritized list of queries needing Deuce's domain knowledge before handoff
> **Created:** 2026-02-05
> **Status:** Active — work through top-to-bottom
> **How to use:** Review each query, answer the open questions, mark ✅ when approved

---

## Priority System

| Priority | Meaning | Why |
|:--------:|---------|-----|
| **P0** | Blocks multiple dashboards | CEO + COO both waiting on this |
| **P1** | Blocks one dashboard section | Single department blocked |
| **P2** | Enhances existing metric | Query works, needs refinement |
| **P3** | Reporting only | Nice-to-have, no target tied to it |

---

## Phase 1 — Core Metrics (Blocks Launch)

These queries power Company Health cards and primary person metrics. Nothing ships until these are approved.

---

### P0-1: Revenue vs Target (`queries/ceo-bizdev/revenue-vs-target.sql`)

**Appears on:** CEO Dashboard, Company Health Card #1
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Calculates YTD revenue from QBO invoices, compares to $10M annual target, shows pacing (projected annual, ahead/behind pace).

**Open questions for Deuce:**

- [ ] **Fiscal year:** Query uses calendar year (`EXTRACT(YEAR FROM CURRENT_DATE())`). Is the fiscal year Jan-Dec or different? The North Star on the dashboard showed $-0.04M which suggests FY might have a different start.
- [ ] **Revenue source:** Uses `src_fivetran_qbo.invoice` total_amount. Should this include credit memos? Should it exclude certain invoice types?
- [ ] **Target:** Hardcoded `$10M`. Should this come from `targets.json` instead? (Settings tab already has `revenue_target`.)
- [ ] **"Revenue" definition:** Is revenue = invoice total_amount, or should we use a P&L account filter (accounts 4110, 4120, 4130)?

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Needs fix: _______________
```

---

### P0-2: Pipeline Coverage (`queries/demand-sales/pipeline-coverage-by-rep.sql`)

**Appears on:** Company Health Card #5, Sales (Andy), Sales (Danny), Sales (Katie)
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Calculates weighted pipeline coverage per sales rep using `hs_forecast_amount` (rep confidence weighting) divided by remaining quarterly quota.

**Open questions for Deuce:**

- [ ] **Quarterly quotas hardcoded:** Danny=$800K, Katie=$600K, Andy=$700K. Are these current? Should they come from HubSpot company properties or `targets.json`?
- [ ] **Pipeline filter:** Only counts `deal_pipeline_id = 'default'` (Purchase Manual pipeline). Is this correct, or should other pipelines be included?
- [ ] **Weighting:** Uses `hs_forecast_amount` (rep-entered confidence). Fallback is `amount * stage_probability / 100`. Is this the right hierarchy?
- [ ] **Closed Won filter:** Uses `property_hs_is_closed_won = TRUE`. Is there a separate "churned" or "cancelled" status that should be excluded from closed-won YTD?
- [ ] **6.0x target:** Based on 17.5% historical win rate. Is this still the right target?

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Needs fix: _______________
```

---

### P0-3: Working Capital (`queries/coo-ops/working-capital.sql`)

**Appears on:** COO Dashboard, CEO Dashboard
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Pulls QBO account balances, classifies into Current Assets vs Current Liabilities, calculates Working Capital = CA - CL.

**Open questions for Deuce:**

- [ ] **Account classification:** Currently classifies `LongTermLiability` as "Current Liability" (line 33). This is wrong — long-term liabilities are NOT current. Should this be removed?
- [ ] **CreditCard accounts:** Classified as "Current Liability". Correct?
- [ ] **Missing categories:** `PrepaidExpenses` is marked as Current Asset. Are there other sub_types that should be included? (e.g., `UndepositedFunds`, `AllowanceForBadDebts`)
- [ ] **ABS() on liabilities:** Line 51 uses `ABS()` on liability totals — QBO stores liabilities as negative values. Verify this matches your QBO chart of accounts behavior.
- [ ] **$1M target:** Still correct?
- [ ] **Missing accounts:** Are there inter-company or trust accounts that should be excluded?

**Known issue:** `LongTermLiability` classification is likely wrong. This inflates current liabilities and understates working capital.

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Needs fix: _______________
```

---

### P0-4: Months of Runway (`queries/coo-ops/months-of-runway.sql`)

**Appears on:** COO Dashboard, CEO Dashboard
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Calculates cash runway by dividing current cash position by average monthly burn. Uses 3mo/6mo/12mo burn averages with waterfall fallback.

**Open questions for Deuce:**

- [ ] **Cash source:** Uses `quickbooks__balance_sheet` where `account_type = 'Bank'`. Does this capture all cash equivalents? What about money market accounts, savings accounts?
- [ ] **Burn definition:** Burn = change in cash position month-over-month. This is total cash flow (operating + investing + financing), NOT operating burn alone. Is this the right definition, or should we isolate operating expenses?
- [ ] **12mo primary, 6mo fallback, 3mo last resort:** This priority is designed to smooth seasonality. Is that the right approach for Recess?
- [ ] **"Cash positive" handling:** When avg burn is positive (generating cash), runway = NULL and status = GREEN. Should it show "∞" or a specific message instead?
- [ ] **>12 months target:** Still correct?
- [ ] **Which bank accounts?** Filter requires `account_number IS NOT NULL`. Are there bank accounts without account numbers that should be included?

**Dependency:** Working Capital query (#3) uses the same cash classification. Fix that first.

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Needs fix: _______________
```

---

### P0-5: Customer Concentration (`queries/coo-ops/top-customer-concentration.sql`)

**Appears on:** Company Health Card #9, COO Dashboard, CEO Dashboard
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Uses `net_revenue_retention_all_customers` view to rank customers by total LTV, calculates top customer's % of total revenue.

**Open questions for Deuce:**

- [ ] **LTV vs YTD:** Currently uses `total_ltv` (lifetime revenue) for concentration. Should this use current year revenue (`net_rev_2026`) instead? LTV-based concentration might mask a recent shift.
- [ ] **Year fallback:** `COALESCE(net_rev_2026, net_rev_2025, net_rev_2024)` for "current year" revenue — this falls back to prior years if current year is null. Is that the right behavior early in FY2026?
- [ ] **HEINEKEN 41% note:** Comment says "41% HEINEKEN = existential risk" but the Company Health card says 29.2%. Which is the current actual? Is the calculation correct?
- [ ] **<30% target:** Still correct for single customer? What about top-5 concentration — should there be a separate target?
- [ ] **Denominator:** Total LTV across ALL customers. Should this exclude churned customers (zero recent revenue)?

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Needs fix: _______________
```

---

### P1-6: Take Rate (`queries/coo-ops/take-rate.sql`)

**Appears on:** Company Health Card #2, COO Dashboard
**Current status:** ✅ Approved
**Query exists:** Yes — already approved

**Note:** Already approved. Listed here for completeness. Uses `Supplier_Metrics` view. Target is 50% (was 45% in Phase 1 plan — verify which is current).

- [ ] **Target discrepancy:** Phase 1 plan says 45%, query hardcodes 50%, `targets.json` says 50%. Confirm 50% is correct.

---

### P1-7: Invoice Collection Rate (`queries/coo-ops/invoice-collection-rate.sql`)

**Appears on:** COO Dashboard, Accounting tab
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Calculates % of invoices collected (paid) out of total invoices due, both by count and by dollar amount.

**Open questions for Deuce:**

- [ ] **"Collected" = paid in full?** Query checks `balance = 0`. Does partial payment count? If invoice is $100K and $90K is paid (balance = $10K), it's counted as NOT collected.
- [ ] **Time window:** Includes invoices from current year AND prior year. Is that the right window? Should it be rolling 12 months instead?
- [ ] **By count vs by amount:** Returns both `collection_rate_by_count` and `collection_rate_by_amount`. Which is the primary KPI? (A few large unpaid invoices affect "by amount" more than "by count")
- [ ] **95% target:** Is this by count or by amount?
- [ ] **Credit memos:** If a customer gets a credit memo that zeroes the balance, does that count as "collected"?

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Needs fix: _______________
```

---

### P1-8: Overdue Invoices (`queries/coo-ops/overdue-invoices.sql`)

**Appears on:** COO Dashboard, Accounting tab
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Counts invoices with outstanding balance past due date. Includes count, dollar amount, and aging stats.

**Open questions for Deuce:**

- [ ] **Simple and clean** — this query is straightforward. Main question: are there invoice types that should be excluded (e.g., recurring invoices, progress billings)?
- [ ] **Target 0:** Is zero overdue invoices realistic, or should YELLOW threshold be higher?
- [ ] **RED at >3:** Currently GREEN=0, YELLOW=1-3, RED=4+. Are these the right thresholds?

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Needs fix: _______________
```

---

## Phase 2 — Secondary Metrics

These queries support Phase 2 tabs (COO extended, Sales detail, Marketing, etc.). Lower urgency than Phase 1 but still need review.

---

### P1-9: Net Revenue Gap (`queries/coo-ops/net-revenue-gap.sql`)

**Appears on:** COO Dashboard
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Calculates gap between unspent contract value and remaining revenue goal. Formula: `Unspent Contracts - (Annual Target - YTD Revenue)`.

**Open questions for Deuce:**

- [ ] **Unspent contracts source:** Uses `HS_QBO_GMV_Waterfall` view filtering on `contract_status IN ('Active', 'Pending')`. Are these the right statuses? What about "Signed but not started"?
- [ ] **Spent value column:** Uses `contract_value - COALESCE(spent_value, 0)`. Verify that `spent_value` in the waterfall view means what we think — is it "invoiced" or "fulfilled"?
- [ ] **$10M annual target hardcoded:** Should come from `targets.json`. But also — is the revenue gap comparing against the right target? Is this calendar-year or fiscal-year aligned?
- [ ] **"Positive = good":** The logic says positive gap means more unspent than needed. Is this the right framing? (A large positive gap could also mean contracts aren't being fulfilled.)
- [ ] **20% buffer for GREEN:** Requires unspent >= 120% of remaining goal for GREEN. Is 20% the right buffer?

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Needs fix: _______________
```

---

### P1-10: Factoring Capacity (`queries/coo-ops/factoring-capacity.sql`)

**Appears on:** COO Dashboard
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Calculates available invoice factoring capacity. Eligible AR (invoices <90 days old with balance > 0) × 85% advance rate.

**Open questions for Deuce:**

- [ ] **Does Recess actually use invoice factoring?** If not, this metric may not be relevant. If yes, who is the factoring partner?
- [ ] **85% advance rate:** Is this the actual contracted rate, or a generic assumption?
- [ ] **"Currently factored" = 0:** Hardcoded to zero. If Recess does factor invoices, where is that data tracked?
- [ ] **Eligibility criteria:** Currently just `balance > 0` and `age < 90 days`. Real factoring has more restrictions:
  - Customer creditworthiness minimums?
  - Minimum invoice size?
  - Excluded customers or invoice types?
- [ ] **$400K target:** Where does this come from? Is it the factoring facility limit?
- [ ] **Should this exist at all?** If factoring isn't used, this slot could show something more useful (e.g., "Available Credit Facility" or "Cash Reserves").

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Remove this metric: _______________
[ ] Replace with: _______________
```

---

### P2-11: Cash Burn (`queries/coo-ops/cash-burn.sql`)

**Appears on:** COO Dashboard (supports Runway calculation)
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Tracks monthly change in cash position from balance sheet Bank accounts. Provides 3/6/12 month averages.

**Open questions for Deuce:**

- [ ] **Identical to operating-burn.sql?** Both cash-burn.sql and operating-burn.sql calculate the same thing (change in bank account balance). operating-burn.sql also pulls Net Income for context. Do we need both, or should we consolidate?
- [ ] **Bank accounts only:** Same concern as Months of Runway — does `account_type = 'Bank'` capture all cash?
- [ ] **No target:** This is a reporting metric feeding into Runway. Correct that it has no standalone target?

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Consolidate with operating-burn.sql
[ ] Needs fix: _______________
```

---

### P2-12: Operating Burn (`queries/coo-ops/operating-burn.sql`)

**Appears on:** COO Dashboard
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Same as Cash Burn but also calculates Net Income from P&L (accounts 4xxx/7xxx = revenue, 5xxx/6xxx = expenses). Shows the gap between net income and cash flow.

**Open questions for Deuce:**

- [ ] **Account number logic:** `LEFT(account_number, 1) IN ('4','7')` for revenue, `('5','6')` for expenses. Does this match your QBO chart of accounts?
- [ ] **"Operating Burn" naming:** The query comment says "= total cash flow, matching the Recess Forecast spreadsheet CFS (Roll Forward) definition." Is that accurate?
- [ ] **Consolidate with cash-burn.sql?** Both essentially compute the same cash change. This one adds the P&L overlay. Recommend keeping only this one and renaming.
- [ ] **2025 baseline:** Shows `baseline_2025_avg` for year-over-year. Is this useful?

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Consolidate with cash-burn.sql (keep this one)
[ ] Needs fix: _______________
```

---

### P2-13: On-Time Collection Rate (`queries/coo-ops/ontime-collection-rate.sql`)

**Appears on:** COO Dashboard, Accounting tab
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Tracks % of invoices paid within 14 days of due date. Groups by year (2025 baseline vs 2026).

**Open questions for Deuce:**

- [ ] **14-day grace period:** Currently "on time" = paid within 14 days AFTER due date. Is 14 days the right window? Most companies use 0 days (on or before due date) or 7 days.
- [ ] **"On-time" definition:** The comment says "7 days" but the SQL says `INTERVAL 14 DAY`. Which is correct?
- [ ] **Overlap with Invoice Collection Rate:** This is a MORE SPECIFIC version of #7 (Invoice Collection Rate). Should these be combined? Or does "collection rate" = total collected and "on-time rate" = timeliness?
- [ ] **Payment join:** Uses `payment_line` → `payment` join. Does this handle partial payments correctly?
- [ ] **95% target:** Same target as Invoice Collection Rate. Are they the same metric?

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Merge with invoice-collection-rate.sql
[ ] Needs fix: _______________
```

---

### P2-14: Avg Invoice Collection Time (`queries/coo-ops/avg-invoice-collection-time.sql`)

**Appears on:** COO Dashboard, Accounting tab
**Current status:** 🔍 Needs Review
**Query exists:** Yes — fully functional

**What it does:** Average days from invoice creation to payment receipt. Includes median, P25, P75, P90 percentiles.

**Open questions for Deuce:**

- [ ] **Baseline metric — no target set.** What should the target be? Current 2025 baseline will tell us. Suggest: set target after reviewing 2025 actuals.
- [ ] **Paid invoices only:** Excludes unpaid invoices (survivorship bias). Is that the right approach? Or should unpaid invoices count as "still collecting" with days = today - invoice_date?
- [ ] **Outlier handling:** No cap on `days_to_collect`. A 500-day outlier will skew the average. Should we cap at 365 days or use median instead?
- [ ] **Relationship to other AR metrics:** This + On-Time Rate + Collection Rate = three AR metrics. Is that too many? Consider: keep this one + Overdue Invoices, drop the overlapping ones.

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Set target to: _____ days
[ ] Needs fix: _______________
```

---

### P3-15: AR Aging Buckets (`queries/coo-ops/ar-aging-buckets.sql`)

**Appears on:** COO Dashboard drill-down, Accounting tab
**Current status:** 🔍 Needs Review
**Query exists:** Yes — reporting only, no target

**What it does:** Breaks down overdue AR into aging buckets (1-30, 31-60, 61-90, 91-120, 120+ days).

**Open questions for Deuce:**

- [ ] **Reporting only — no target.** This is a drill-down of Overdue Invoices (#8). Correct that it has no standalone target?
- [ ] **Bucket boundaries:** Standard AR aging. Any Recess-specific adjustments needed?
- [ ] **Same base query as Overdue Invoices.** Could consolidate into one query with a detail CTE. Recommend: keep separate for clarity.

**Approve / Fix:**
```
[ ] Approved as-is
[ ] Needs fix: _______________
```

---

## Non-COO Queries Needing Review

These are in other departments but still need your sign-off.

---

### P1-16: Demand NRR (`net_revenue_retention_all_customers` BQ view)

**Appears on:** Company Health Card #3, Sales (Andy)
**Current status:** ✅ Approved in master plan
**Query:** Uses existing BigQuery view, not a standalone .sql file

**Quick check:** Already approved. No action needed unless you want to revisit.

---

### P1-17: Supply NRR (`queries/supply-am/nrr-top-supply-users-financial.sql`)

**Appears on:** Company Health Card #4, Supply AM (Ashton)
**Current status:** 🟡 Needs Review

- [ ] **Financial vs Offer-based:** Two versions exist. Financial (using payouts data) is recommended. Confirm?
- [ ] **>100% target:** NRR above 100% means expansion. Is this realistic for supply side?

---

### P1-18: Time to Fulfill (uses `Days_to_Fulfill_Contract_Spend` BQ view)

**Appears on:** Company Health Card #7, Demand AM (Victoria)
**Current status:** 🟡 Needs Review

- [ ] **<30 days target:** Still correct? Dashboard showed "No contracts fully spent" which means the metric can't compute.
- [ ] **"Fulfillment" definition:** From contract close to... what exactly? All spend completed? First fulfillment event?

---

### P1-19: Demand Sales Queries (9 queries in `queries/demand-sales/`)

**Appears on:** Sales tab (Andy, Danny, Katie)
**Current status:** All 🔍 Needs Review

These are less finance-heavy but still need a pass. The main decisions:

- [ ] **Win Rate 90d:** 30% target — is 90-day lookback the right window?
- [ ] **Avg Deal Size:** $150K target — current?
- [ ] **Sales Cycle Length:** ≤60 days target — current?
- [ ] **Meetings Booked QTD:** 24 target — current quarterly target?

---

### P1-20: Supply Queries (6 queries in `queries/supply/`)

**Appears on:** Supply tab (Ian Hong)
**Current status:** All 🔍 Needs Review

- [ ] **New Unique Inventory:** 16/qtr target — current?
- [ ] **Weekly Contact Attempts:** 50/week target — current?
- [ ] **Pipeline by Event Type:** Hardcoded goals per type — need updated goals

---

### P1-21: Marketing Queries (4 queries in `queries/marketing/`)

**Appears on:** Marketing tab
**Current status:** All 🔍 Needs Review

- [ ] **Marketing-Influenced Pipeline:** 50/50 first-touch/last-touch attribution. Is this the right model?
- [ ] **MQL → SQL Conversion:** 30% target — current?

---

## Summary: Review Order

Work through these top-to-bottom. Check the boxes, add notes, and I'll implement your fixes.

| # | Query | Priority | Phase | Est. Review Time |
|---|-------|:--------:|:-----:|:----------------:|
| 1 | Revenue vs Target | P0 | 1 | 5 min |
| 2 | Pipeline Coverage | P0 | 1 | 5 min |
| 3 | Working Capital | P0 | 1 | 10 min |
| 4 | Months of Runway | P0 | 1 | 10 min |
| 5 | Customer Concentration | P0 | 1 | 5 min |
| 6 | Take Rate (verify target) | P1 | 1 | 2 min |
| 7 | Invoice Collection Rate | P1 | 1 | 5 min |
| 8 | Overdue Invoices | P1 | 1 | 3 min |
| 9 | Net Revenue Gap | P1 | 2 | 10 min |
| 10 | Factoring Capacity | P1 | 2 | 5 min |
| 11 | Cash Burn | P2 | 2 | 3 min |
| 12 | Operating Burn | P2 | 2 | 5 min |
| 13 | On-Time Collection Rate | P2 | 2 | 5 min |
| 14 | Avg Collection Time | P2 | 2 | 3 min |
| 15 | AR Aging Buckets | P3 | 2 | 2 min |
| 16 | Supply NRR | P1 | 1 | 5 min |
| 17 | Time to Fulfill | P1 | 1 | 5 min |
| 18 | Demand Sales (9 queries) | P1 | 1 | 15 min |
| 19 | Supply (6 queries) | P1 | 1 | 10 min |
| 20 | Marketing (4 queries) | P1 | 1 | 10 min |

**Total estimated review time: ~2 hours**
**Recommended approach:** Do P0 items first (~35 min), then P1 items (~55 min). P2/P3 can wait.

---

## Key Decisions Needed (Cross-Cutting)

These decisions affect multiple queries:

1. **Fiscal year:** Calendar year (Jan-Dec) or different? Affects Revenue, Net Revenue Gap, NRR, most queries.
2. **"Revenue" = what?** QBO invoice total_amount vs P&L account filter vs Supplier_Metrics GMV. Need one authoritative definition.
3. **AR metric consolidation:** 5 AR-related metrics (Invoice Collection Rate, On-Time Collection, Avg Collection Time, Overdue Invoices, AR Aging). Keep all 5, or consolidate to 3?
4. **Cash/Burn consolidation:** cash-burn.sql and operating-burn.sql overlap significantly. Keep both or merge?
5. **Factoring relevance:** If Recess doesn't factor invoices, this metric slot should be repurposed.

---

## After Review

Once you've marked items approved or noted fixes:

1. I'll implement your fixes in the SQL files
2. Wire approved queries to `bigquery_client.py` functions
3. Run integration smoke tests against live BQ
4. Update `targets.json` with confirmed targets
5. Hand off to implementer with clear "approved" status on each query

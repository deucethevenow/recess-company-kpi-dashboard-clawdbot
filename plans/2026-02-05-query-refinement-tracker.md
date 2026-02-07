# Query Refinement Tracker — Owner Review

> **Purpose:** Prioritized list of queries needing Deuce's domain knowledge before handoff
> **Created:** 2026-02-05
> **Last Updated:** 2026-02-06
> **Status:** In Progress — P0 items reviewed, P1 partially reviewed

---

## Cross-Cutting Decisions (Resolved 2026-02-06)

| # | Decision | Answer | Affects |
|---|----------|--------|---------|
| 1 | **Fiscal year** | Calendar year (Jan-Dec) | All date-filtered queries |
| 2 | **Revenue definition** | QBO Invoice `total_amount` (5-component: invoices - credit memos - discounts - organizer payouts + vendor credits) | Revenue vs Target, Net Revenue Gap |
| 3 | **AR metric consolidation** | Keep all 5 AR metrics | Invoice Collection, On-Time, Avg Time, Overdue, AR Aging |
| 4 | **Cash/Burn consolidation** | Keep both — waiting on CFO input for operating burn definition | cash-burn.sql, operating-burn.sql |
| 5 | **Factoring relevance** | Yes, Recess factors invoices. 90% advance rate. | factoring-capacity.sql |

### Revenue Formula (Authoritative)

Already implemented in `bigquery_client.py` lines 79-159 (`get_revenue_ytd()`):

```
Net Revenue = Invoices (accts 4110-4169)
            - Credit Memos (same accts, separate table)
            - Discounts (acct 4190)
            - Organizer Payouts (bills on accts 4200-4299)
            + Vendor Credits (separate table, accts 4200-4299)

2025 Reference: $7.92M GMV → $3.90M net revenue (49.3% take rate)
```

---

## Phase 1 — Core Metrics (Blocks Launch)

---

### P0-1: Revenue vs Target (`queries/ceo-bizdev/revenue-vs-target.sql`) ✅ REVIEWED

**Appears on:** CEO Dashboard, Company Health Card #1

**Decisions:**
- [x] **Fiscal year:** Calendar year (Jan-Dec) — query already correct
- [x] **Revenue source:** Must use full 5-component formula (invoices - CMs - discounts - payouts + vendor credits). **Current query only uses `invoice.total_amount` — NEEDS UPDATE**
- [x] **Target:** Pull from `targets.json` (not hardcoded $10M)
- [x] **Revenue definition:** 5-component formula from `bigquery_client.py`

**Action items:**
1. Update SQL to use 5-component net revenue formula (match `get_revenue_ytd()`)
2. Remove hardcoded `$10M` target — read from `targets.json`

---

### P0-2: Pipeline Coverage (`queries/demand-sales/pipeline-coverage-by-rep.sql`) ✅ REVIEWED

**Appears on:** Company Health Card #5, Sales (Andy), Sales (Danny), Sales (Katie)

**Decisions:**
- [x] **Quarterly quotas updated:**

| Rep | Quarterly Quota (Gross) | Quarterly Target (Net Revenue) |
|-----|:-----------------------:|:------------------------------:|
| Andy Cooper | $712,973 | $349,357 |
| Danny Sears | $1,000,153 | $490,075 |
| Katie Olmstead | $603,911 | $295,916 |
| **Total** | **$2,317,036** | **$1,135,347** |

- [x] **Pipeline filter:** Default pipeline only — correct
- [x] **Weighting:** `hs_forecast_amount` = stage weighting x deal amount (HubSpot auto-calculated) — correct
- [x] **6.0x target:** Confirmed correct
- [x] **Show BOTH gross and net coverage:** Net = bookings x 49% take rate
- [x] **Show BOTH QTD and YTD closed won**

**Action items:**
1. Update quotas to new values
2. Add net coverage ratio (weighted pipeline x 49% / net quarterly target)
3. Add QTD closed won alongside YTD
4. Source quotas from `targets.json` for future editability

---

### P0-3: Working Capital (`queries/coo-ops/working-capital.sql`) ✅ REVIEWED

**Appears on:** COO Dashboard, CEO Dashboard

**Decisions:**
- [x] **BUG FIX:** Remove `LongTermLiability` from Current Liabilities (line 33) — inflates liabilities
- [x] **CreditCard:** Keep as Current Liability — correct
- [x] **Account types:** Look complete, no missing types identified
- [x] **ABS() on liabilities:** Need to verify QBO sign convention against live data
- [x] **$1M target:** Confirmed correct

**Action items:**
1. Remove `LongTermLiability` from CASE statement (line 33)
2. Run test query against live BQ to verify liability sign convention
3. Target remains >$1M

---

### P0-4: Months of Runway (`queries/coo-ops/months-of-runway.sql`) ✅ REVIEWED

**Appears on:** COO Dashboard, CEO Dashboard

**Decisions:**
- [x] **Burn definition:** Show BOTH operating burn AND total cash burn versions of runway
- [x] **Cash positive:** Show the number even when positive (don't hide behind NULL)
- [x] **Cash accounts:** Bank + money market accounts. **Chase bank balance needs SimpleFin (Phase 4)**
- [x] **>12 months target:** Confirmed correct

**Action items:**
1. Add operating burn version alongside total cash burn runway
2. Show number even when cash positive (negative months = cash positive context)
3. Expand account_type filter to include money market accounts
4. Note: Current number may be understated until SimpleFin (Phase 4 Batch A) connects Chase bank

---

### P0-5: Customer Concentration (`queries/coo-ops/top-customer-concentration.sql`) ✅ REVIEWED

**Appears on:** Company Health Card #9, COO Dashboard, CEO Dashboard

**Decisions:**
- [x] **Use current year (YTD) revenue** — NOT lifetime LTV
- [x] **Show how many customers make up 80% of current year revenue** (concentration index)
- [x] **Show top-5 customer % of current year revenue** (no formal target, visibility only)
- [x] **<30% target:** Still correct for top single customer (now on current-year basis)
- [x] **LTV is secondary reference only**

**Action items:**
1. Rewrite query to use current-year revenue (`net_rev_2026`) instead of `total_ltv`
2. Add "customers to 80%" count (e.g., "3 customers = 80% of revenue")
3. Add top-5 concentration % display
4. Keep LTV as secondary drill-down data

---

### P1-6: Take Rate (`queries/coo-ops/take-rate.sql`) ✅ REVIEWED

**Appears on:** Company Health Card #2, COO Dashboard
**Status:** ✅ Already approved

- [x] **Target:** 50% confirmed (Phase 1 plan's 45% is outdated — update plan)

**Action items:**
1. Update Phase 1 plan to say 50% (not 45%)

---

### P1-7: Invoice Collection Rate (`queries/coo-ops/invoice-collection-rate.sql`) ✅ REVIEWED

**Appears on:** COO Dashboard, Accounting tab

**Decisions:**
- [x] **"Collected" = paid in full** (balance = 0). Partial payments do NOT count.
- [x] **Show BOTH by count and by amount** — let viewer choose focus
- [x] **95% target** applies to both perspectives

**Action items:**
1. Keep dual display (count + amount)
2. No SQL changes needed — query already returns both

---

### P1-8: Overdue Invoices (`queries/coo-ops/overdue-invoices.sql`) ✅ REVIEWED

**Appears on:** COO Dashboard, Accounting tab

**Decisions:**
- [x] **Use DOLLAR AMOUNT thresholds** (not count-based)
- [x] **GREEN:** $0 overdue
- [x] **YELLOW:** Up to $50K overdue
- [x] **RED:** Over $50K overdue

**Action items:**
1. Change status logic from count-based to dollar-based thresholds
2. GREEN = $0, YELLOW = ≤$50K, RED = >$50K

---

### P1-9: Net Revenue Gap (`queries/coo-ops/net-revenue-gap.sql`) ✅ REVIEWED — MAJOR REWRITE

**Appears on:** COO Dashboard

**Current query is fundamentally broken** — references columns that don't exist in `HS_QBO_GMV_Waterfall`.

**Corrected understanding:**

The GMV Waterfall (`App_KPI_Dashboard.HS_QBO_GMV_Waterfall`) is a **time-phased revenue forecast** showing expected GMV by customer by month. It distributes contract value across months based on invoicing schedule (default, overridden by HubSpot field for % invoiced in first 1-90 days).

Key column: `Adjusted_GMV_Amount` (forecasted GMV per row/month)
Filter: `Include_in_GMV_Analysis = true` (closed_won in Purchase/AM/Campaign/Self-Service pipelines)

**Corrected formula:**

```
1. Annual Revenue Target            = from targets.json
2. YTD Actual Net Revenue           = 5-component formula
3. Remaining Revenue Needed         = (1) - (2)

4. Future Forecasted GMV            = SUM(Adjusted_GMV_Amount) for remaining months
                                      FROM HS_QBO_GMV_Waterfall
                                      WHERE Include_in_GMV_Analysis = true
                                        AND month > current month
5. Forecasted Net Revenue           = (4) x 49% take rate

6. NET REVENUE GAP                  = (3) - (5)
   Positive = need more new deals
   Zero/negative = existing contracts cover it
```

**Action items:**
1. Complete rewrite of `net-revenue-gap.sql`
2. Verify `HS_QBO_GMV_Waterfall` column names against live BQ schema
3. Implement time-phased GMV summation
4. Apply 49% take rate conversion
5. Pull target from `targets.json`

---

### P1-10: Factoring Capacity (`queries/coo-ops/factoring-capacity.sql`) ✅ REVIEWED

**Appears on:** COO Dashboard

**Decisions:**
- [x] **Recess uses factoring** — metric is relevant
- [x] **Advance rate:** 90% (not 85% — update query)
- [x] **$400K target:** Keep for now

**Action items:**
1. Update advance rate from 85% to 90%

---

### P2-11: Cash Burn (`queries/coo-ops/cash-burn.sql`) — ON HOLD

**Status:** Waiting on CFO input for operating burn definition
**Decision:** Keep both cash-burn.sql and operating-burn.sql for now

---

### P2-12: Operating Burn (`queries/coo-ops/operating-burn.sql`) — ON HOLD

**Status:** Waiting on CFO input
**Decision:** Keep for now, do not start implementation

---

### P1-17: Supply NPR (`queries/supply-am/nrr-top-supply-users-financial.sql`) ✅ REVIEWED

**Appears on:** Company Health Card #4, Supply AM (Ashton)

**Decisions:**
- [x] **Financial-based** (using payouts data) — confirmed
- [x] **This is Net Payout Retention (NPR), not NRR** — rename throughout

**Action items:**
1. Rename from "Supply NRR" to "Supply NPR" (Net Payout Retention) across codebase

---

### P1-18: Time to Fulfill ✅ REVIEWED

**Appears on:** Company Health Card #7, Demand AM (Victoria)

**Decisions:**
- [x] **Fulfillment definition:** From contract close date until gross spend (invoices + credit memos) equals 100% of the contract value
- [x] **<30 days target:** Confirmed

**Action items:**
1. Verify `Days_to_Fulfill_Contract_Spend` view matches this definition
2. Target remains <30 days

---

### P2-13: On-Time Collection Rate — NOT YET REVIEWED

### P2-14: Avg Invoice Collection Time — NOT YET REVIEWED

### P3-15: AR Aging Buckets — NOT YET REVIEWED

---

## Non-COO Queries Needing Review

---

### P1-16: Demand NRR — ✅ Already approved in master plan

---

### P1-19: Demand Sales Queries (9 queries) — NOT YET REVIEWED

**Targets to confirm:**
- Win Rate 90d: 30% target?
- Avg Deal Size: $150K target?
- Sales Cycle Length: ≤60 days target?
- Meetings Booked QTD: 24 target?

---

### P1-20: Supply Queries (6 queries) — NOT YET REVIEWED

**Targets to confirm:**
- New Unique Inventory: 16/qtr target?
- Weekly Contact Attempts: 50/week target?
- Pipeline by Event Type: hardcoded goals need updating?

---

### P1-21: Marketing Queries (4 queries) — NOT YET REVIEWED

**Targets to confirm:**
- Marketing-Influenced Pipeline: 50/50 FT/LT attribution model?
- MQL to SQL Conversion: 30% target?

---

## Summary: Review Progress

| # | Query | Priority | Status | Key Changes |
|---|-------|:--------:|:------:|-------------|
| 1 | Revenue vs Target | P0 | ✅ | Use 5-component formula, targets.json |
| 2 | Pipeline Coverage | P0 | ✅ | New quotas, show gross+net, QTD+YTD |
| 3 | Working Capital | P0 | ✅ | Fix LongTermLiability bug, verify signs |
| 4 | Months of Runway | P0 | ✅ | Both burn types, show number always, add money market |
| 5 | Customer Concentration | P0 | ✅ | YTD revenue (not LTV), 80% index, top-5 |
| 6 | Take Rate | P1 | ✅ | 50% target confirmed |
| 7 | Invoice Collection Rate | P1 | ✅ | Show both count + amount |
| 8 | Overdue Invoices | P1 | ✅ | Dollar thresholds: $0/$50K/$100K |
| 9 | Net Revenue Gap | P1 | ✅ | **Major rewrite** — use GMV Waterfall forecast x 49% |
| 10 | Factoring Capacity | P1 | ✅ | 90% advance rate (was 85%) |
| 11 | Cash Burn | P2 | ⏸ ON HOLD | Waiting on CFO |
| 12 | Operating Burn | P2 | ⏸ ON HOLD | Waiting on CFO |
| 13 | On-Time Collection Rate | P2 | ⬜ | Not yet reviewed |
| 14 | Avg Collection Time | P2 | ⬜ | Not yet reviewed |
| 15 | AR Aging Buckets | P3 | ⬜ | Not yet reviewed |
| 16 | Demand NRR | P1 | ✅ | Already approved |
| 17 | Supply NPR | P1 | ✅ | Financial-based, rename to NPR |
| 18 | Time to Fulfill | P1 | ✅ | Close → 100% gross spend, <30d target |
| 19 | Demand Sales (9) | P1 | ⬜ | Targets need confirmation |
| 20 | Supply (6) | P1 | ⬜ | Targets need confirmation |
| 21 | Marketing (4) | P1 | ⬜ | Targets need confirmation |

**Progress: 14/21 reviewed (5 P0 + 9 P1), 2 on hold, 5 remaining**

---

## After All Reviews Complete

1. Implement SQL fixes for all action items above
2. Wire approved queries to `bigquery_client.py` functions
3. Run integration smoke tests against live BQ
4. Update `targets.json` with confirmed targets
5. Hand off to implementer with clear "approved" status on each query

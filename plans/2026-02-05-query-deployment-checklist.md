# SQL Query Deployment Checklist

> **Generated:** 2026-02-05
> **BigQuery Project:** `stitchdata-384118`
> **Dataset:** `App_KPI_Dashboard`
> **Total SQL Files Reviewed:** 31

---

## Executive Summary

| Status | Count |
|--------|-------|
| **Deployment Ready (with minor issues)** | 22 |
| **Needs Fixes Before Deploy** | 9 |
| **Blocked (external dependency)** | 0 (blocked metrics have no SQL files yet) |

**Key Findings:**
1. **Hardcoded targets in 25+ queries** -- All queries hardcode target values (e.g., `50.0 AS target_pct`, `6.0x`, `$10M`) instead of reading from `dashboard/data/targets.json`. This is acceptable for BigQuery views since targets are display-layer concerns, BUT the dashboard code must override these with `targets.json` values at render time.
2. **Hardcoded quotas in pipeline-coverage-by-rep.sql** -- Sales rep quarterly quotas are hardcoded ($800K, $600K, $700K). These should be configurable.
3. **Supply pipeline ID assumed as `'supply'`** -- Multiple supply queries use `deal_pipeline_id = 'supply'` with TODO comments. This pipeline ID needs verification in HubSpot.
4. **meetings-booked-mtd.sql has a column mismatch bug** -- References `engagement_id` but CTE returns `deal_id`. Will fail at runtime.
5. **3 extra COO queries found** not in the master plan: `avg-invoice-collection-time.sql`, `ar-aging-buckets.sql`, `ontime-collection-rate.sql`. These are bonus reporting queries.

---

## Deployment Table

### COO/Ops Queries (`queries/coo-ops/`) -- 11 files

| # | Query File | Metric | Tables Referenced | Formula Match | Issues | Ready? |
|---|-----------|--------|-------------------|:-------------:|--------|:------:|
| 1 | `take-rate.sql` | Take Rate % | `App_KPI_Dashboard.Supplier_Metrics` | YES | Hardcodes target `50.0%` (targets.json also says 50%). Master plan says 45% in some places, 50% in others -- **discrepancy needs resolution** | YES* |
| 2 | `invoice-collection-rate.sql` | Invoice Collection Rate | `src_fivetran_qbo.invoice` | YES | Hardcodes target `95.0%`. Formula correct: `Paid / Total Due`. | YES |
| 3 | `overdue-invoices.sql` | Overdue Invoices | `src_fivetran_qbo.invoice`, `src_fivetran_qbo.customer` | YES | Hardcodes target `0`. Clean query, correct logic. | YES |
| 4 | `working-capital.sql` | Working Capital | `src_fivetran_qbo.account` | YES | Hardcodes target `$1M`. Includes `LongTermLiability` in "Current Liability" bucket -- **may overstate current liabilities**. | YES* |
| 5 | `months-of-runway.sql` | Months of Runway | `src_fivetran_qbo.account`, `src_fivetran_qbo.bill_line`, `src_fivetran_qbo.bill` | YES | Hardcodes target `12 months`. Uses `bill_line` for expenses (not P&L) -- may miss non-bill operating expenses like payroll. | YES* |
| 6 | `top-customer-concentration.sql` | Customer Concentration | `App_KPI_Dashboard.net_revenue_retention_all_customers` | YES | Hardcodes target `<30%`. Uses `total_ltv` for ranking which is lifetime, not YTD. Consider YTD-only view for current-year risk. | YES* |
| 7 | `net-revenue-gap.sql` | Net Revenue Gap | `src_fivetran_qbo.invoice`, `App_KPI_Dashboard.HS_QBO_GMV_Waterfall` | PARTIAL | Hardcodes `$10M` annual target. HS_QBO_GMV_Waterfall columns `contract_status`, `contract_value`, `spent_value` need schema verification -- may not match actual view columns. | NO |
| 8 | `factoring-capacity.sql` | Factoring Capacity | `src_fivetran_qbo.invoice`, `src_fivetran_qbo.customer` | YES | Hardcodes target `$400K`. Clean implementation. `85%` advance rate is industry standard. | YES |
| 9 | `avg-invoice-collection-time.sql` | Avg Collection Time | `src_fivetran_qbo.invoice`, `src_fivetran_qbo.payment_line`, `src_fivetran_qbo.payment` | YES | Not in master plan (bonus). Uses `payment_line` join which is correct for QBO. | YES |
| 10 | `ar-aging-buckets.sql` | AR Aging Buckets | `src_fivetran_qbo.invoice`, `src_fivetran_qbo.customer` | YES | Not in master plan (bonus reporting). Clean query. | YES |
| 11 | `ontime-collection-rate.sql` | On-Time Collection Rate | `src_fivetran_qbo.invoice`, `src_fivetran_qbo.payment_line`, `src_fivetran_qbo.payment` | YES | Not in master plan (bonus). Comment says "7 days" but code uses `14 DAY` interval -- **comment/code mismatch** but code is correct per header. | YES* |

### CEO/Biz Dev Queries (`queries/ceo-bizdev/`) -- 1 file

| # | Query File | Metric | Tables Referenced | Formula Match | Issues | Ready? |
|---|-----------|--------|-------------------|:-------------:|--------|:------:|
| 12 | `revenue-vs-target.sql` | Revenue vs Target | `src_fivetran_qbo.invoice` | YES | Hardcodes `$10M` annual target (matches `targets.json` Jack target). Uses `total_amount` from invoices -- should verify this represents recognized revenue, not just invoiced amounts. | YES* |

### Demand Sales Queries (`queries/demand-sales/`) -- 9 files

| # | Query File | Metric | Tables Referenced | Formula Match | Issues | Ready? |
|---|-----------|--------|-------------------|:-------------:|--------|:------:|
| 13 | `pipeline-coverage-by-rep.sql` | Pipeline Coverage | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.owner`, `src_fivetran_hubspot.deal_pipeline_stage` | YES | **Hardcodes quarterly quotas per rep** ($800K Danny, $600K Katie, $700K Andy). These should be configurable. Uses `hs_forecast_amount` correctly per master plan note #3. | YES* |
| 14 | `win-rate-90-days.sql` | Win Rate (90d) | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.owner` | YES | Formula: `Won / (Won + Lost)` -- correct. Filters to `deal_pipeline_id = 'default'`. Includes `char@recess.is` and `jack@recess.is` beyond the 3 sales reps. | YES |
| 15 | `avg-deal-size-ytd.sql` | Avg Deal Size | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.owner` | YES | Hardcodes target `$150K`. Correct formula: `AVG(amount)` for closed-won YTD. | YES |
| 16 | `sales-cycle-length.sql` | Sales Cycle Length | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.owner` | YES | Formula: `AVG(closedate - createdate)` -- correct per master plan. Uses `DATE_DIFF` properly. `property_createdate` may be TIMESTAMP, needs `DATE()` cast (already done). | YES |
| 17 | `deals-by-stage-funnel.sql` | Deals by Stage | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.deal_pipeline_stage` | YES | **Hardcodes monthly funnel targets** (45, 36, 23, 22, 15, 9, 7). These match master plan exactly. UNION with Closed Won MTD is clean. | YES |
| 18 | `deals-closing-soon.sql` | Deals Closing Soon | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.owner`, `src_fivetran_hubspot.deal_pipeline_stage` | PARTIAL | **UNION detail view reuses columns poorly** (`deal_id` mapped to `deal_count` column). May confuse downstream consumers. Works but semantically messy. | YES* |
| 19 | `expired-open-deals.sql` | Expired Open Deals | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.owner`, `src_fivetran_hubspot.deal_pipeline_stage` | YES | Returns detail rows, not summary. No target hardcoded. Clean query. | YES |
| 20 | `companies-not-contacted-7d.sql` | Deals Not Contacted 7d | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.owner`, `src_fivetran_hubspot.deal_pipeline_stage` | PARTIAL | Uses `property_notes_last_updated`, `property_hs_last_sales_activity_timestamp`, `property_hs_lastmodifieddate` -- good multi-source approach. But `GREATEST` with `DATE('1900-01-01')` fallback is fragile. Master plan says "engagement" join but query uses deal properties instead -- **different approach but functionally equivalent**. | YES* |
| 21 | `meetings-booked-qtd.sql` | Meetings Booked QTD | `src_fivetran_hubspot.engagement`, `src_fivetran_hubspot.owner`, `src_fivetran_hubspot.deal` | YES | Hardcodes target `45/month`. Uses engagement type `MEETING`. Also has `deals_to_meeting_stage` CTE but never uses it in the final SELECT (dead code, no harm). | YES |

### Supply Queries (`queries/supply/`) -- 6 files

| # | Query File | Metric | Tables Referenced | Formula Match | Issues | Ready? |
|---|-----------|--------|-------------------|:-------------:|--------|:------:|
| 22 | `new-unique-inventory.sql` | New Unique Inventory | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.deal_pipeline_stage` | PARTIAL | Hardcodes target `16/quarter`. Uses `deal_pipeline_id = 'supply'` -- **pipeline ID needs verification**. `PARSE_TIMESTAMP` on custom properties may fail if format doesn't match `'%Y-%m-%dT%H:%M:%S'`. | NO |
| 23 | `weekly-contact-attempts.sql` | Weekly Contact Attempts | `src_fivetran_hubspot.engagement`, `src_fivetran_hubspot.contact` | PARTIAL | Hardcodes target `600/week`. Filters contacts by `hs_lead_status = 'Supply Target'` OR `lifecyclestage = 'supply_target'` with TODO notes -- **property names need verification**. JOIN on `e.contact_id` assumes engagement table has `contact_id` column -- **may need engagement_contact association table** instead. | NO |
| 24 | `meetings-booked-mtd.sql` | Meetings Booked MTD (Supply) | `src_fivetran_hubspot.deal` | PARTIAL | **BUG: References `engagement_id` in final SELECT but CTE `supply_meetings_from_deals` returns `deal_id`, not `engagement_id`**. Will produce SQL error at runtime. Also uses `property_hubspot_owner_id` -- should verify this property name vs standard `owner_id`. | NO |
| 25 | `pipeline-coverage-by-event-type.sql` | Pipeline Coverage by Type | `src_fivetran_hubspot.deal` | PARTIAL | **Hardcodes event type goals** (university_housing: $40K, fitness_studios: $400K, etc.) -- master plan acknowledges these come from Google Sheets. Uses `property_event_type` with TODO -- **property name needs verification**. `deal_pipeline_id = 'supply'` needs verification. | NO |
| 26 | `supply-funnel.sql` | Supply Funnel | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.deal_pipeline_stage` | YES | Hardcodes monthly targets (60, 60, 24, 16, 16, 4) matching master plan. `deal_pipeline_id = 'supply'` needs verification. JOIN between `stage_name` and `funnel_targets.stage` -- **names must match exactly** or rows will be NULL. | NO |
| 27 | `listings-published-per-month.sql` | Listings Published | `mongodb.audience_listings` | YES | No hardcoded targets (reporting only). Uses `published_state = 'published'`, `is_omnichannel = FALSE`. Clean query with MoM trend. | YES |

### Marketing Queries (`queries/marketing/`) -- 4 files

| # | Query File | Metric | Tables Referenced | Formula Match | Issues | Ready? |
|---|-----------|--------|-------------------|:-------------:|--------|:------:|
| 28 | `marketing-influenced-pipeline.sql` | Mktg-Influenced Pipeline | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.deal_contact`, `src_fivetran_hubspot.contact` | YES | Attribution model matches master plan: `(FT + LT) / 2`. All 10 marketing channels defined. **Last touch is same as first touch** (simplified) -- note in code acknowledges this. | YES* |
| 29 | `mql-to-sql-conversion.sql` | MQL to SQL Conversion | `src_fivetran_hubspot.contact` | YES | Hardcodes target `30%`. Formula: `SQLs / MQLs` -- correct. Uses `PARSE_TIMESTAMP` on lifecycle dates. | YES |
| 30 | `attribution-by-channel.sql` | Attribution by Channel | `src_fivetran_hubspot.deal`, `src_fivetran_hubspot.deal_contact`, `src_fivetran_hubspot.contact` | YES | Same FT=LT simplification as marketing-influenced-pipeline. Channel grouping is clean. | YES* |
| 31 | `marketing-leads-funnel.sql` | Marketing Leads Funnel | `src_fivetran_hubspot.contact` | YES | ML -> MQL -> SQL funnel. Uses correlated subqueries (could be optimized but functionally correct). | YES |

---

## Issues Detail

### CRITICAL (Must Fix Before Deploy)

| # | File | Issue | Severity |
|---|------|-------|----------|
| 1 | `supply/meetings-booked-mtd.sql` | **Column `engagement_id` referenced but CTE only returns `deal_id`**. Query will fail at runtime. Fix: Change `COUNT(engagement_id)` to `COUNT(deal_id)` in final SELECT. | CRITICAL |
| 2 | `coo-ops/net-revenue-gap.sql` | `HS_QBO_GMV_Waterfall` columns `contract_status`, `contract_value`, `spent_value` need schema verification. If these columns don't exist, query fails. | HIGH |

### HIGH (Should Fix Before Deploy)

| # | File | Issue | Severity |
|---|------|-------|----------|
| 3 | `supply/new-unique-inventory.sql` | `deal_pipeline_id = 'supply'` -- pipeline ID unverified. `PARSE_TIMESTAMP` format may not match actual HubSpot data format. | HIGH |
| 4 | `supply/weekly-contact-attempts.sql` | `engagement.contact_id` may not exist as a direct column. HubSpot Fivetran schema typically uses `engagement_contact` association table. Property names `hs_lead_status = 'Supply Target'` unverified. | HIGH |
| 5 | `supply/pipeline-coverage-by-event-type.sql` | `property_event_type` unverified. Hardcoded goals from Google Sheets. | HIGH |
| 6 | `supply/supply-funnel.sql` | Stage name matching between `deal_pipeline_stage.label` and hardcoded `funnel_targets.stage` may not align. | HIGH |

### MEDIUM (Can Deploy But Should Fix)

| # | File | Issue | Severity |
|---|------|-------|----------|
| 7 | `coo-ops/take-rate.sql` | Target discrepancy: master plan says 45% in COO section but 50% in Company Health and targets.json. | MEDIUM |
| 8 | `coo-ops/working-capital.sql` | `LongTermLiability` classified as Current Liability -- may overstate current liabilities. | MEDIUM |
| 9 | `coo-ops/months-of-runway.sql` | Burn rate from `bill_line` only -- misses payroll and non-bill expenses. | MEDIUM |
| 10 | `demand-sales/pipeline-coverage-by-rep.sql` | Quarterly quotas hardcoded per rep. Should be configurable or pulled from HubSpot. | MEDIUM |
| 11 | `marketing/marketing-influenced-pipeline.sql` | Last touch = First touch (simplified). True last-touch attribution needs engagement data join. | MEDIUM |
| 12 | `marketing/attribution-by-channel.sql` | Same FT=LT simplification as above. | MEDIUM |

### LOW (Minor / Informational)

| # | File | Issue | Severity |
|---|------|-------|----------|
| 13 | `coo-ops/ontime-collection-rate.sql` | Comment says "7 days" in some places but interval is 14 days. Code is correct per header. | LOW |
| 14 | `demand-sales/deals-closing-soon.sql` | UNION detail view reuses columns semantically wrong (deal_id as deal_count). | LOW |
| 15 | `demand-sales/meetings-booked-qtd.sql` | `deals_to_meeting_stage` CTE defined but unused (dead code). | LOW |
| 16 | `demand-sales/companies-not-contacted-7d.sql` | Uses deal properties instead of engagement join per master plan. Functionally equivalent but different approach. | LOW |

---

## Hardcoded Targets Summary

Almost all queries hardcode their target values directly in SQL. This is noted here for awareness:

| Query | Hardcoded Target | targets.json Value | Match? |
|-------|------------------|--------------------|:------:|
| take-rate.sql | 50% | 50% | YES (but master plan says 45% in COO section) |
| invoice-collection-rate.sql | 95% | 95% (Accounting) | YES |
| overdue-invoices.sql | 0 | N/A | -- |
| working-capital.sql | $1M | N/A | -- |
| months-of-runway.sql | 12 months | N/A | -- |
| top-customer-concentration.sql | 30% | N/A | -- |
| net-revenue-gap.sql | $10M | $10M (Jack) | YES |
| factoring-capacity.sql | $400K | N/A | -- |
| revenue-vs-target.sql | $10M | $10M (Jack) | YES |
| pipeline-coverage-by-rep.sql | 6.0x | 6.0 (Danny, Katie) | YES |
| deals-by-stage-funnel.sql | 45/36/23/22/15/9/7 | N/A | -- |
| new-unique-inventory.sql | 16/quarter | 16 (Ian Hong) | YES |
| weekly-contact-attempts.sql | 600/week | N/A | -- |
| meetings-booked-mtd.sql | 24/month | N/A | -- |
| mql-to-sql-conversion.sql | 30% | N/A | -- |

**Recommendation:** The dashboard application layer should read from `targets.json` and override these hardcoded values. The SQL-level targets are useful for standalone query execution / debugging but should not be the source of truth in production.

---

## Schema Dependencies

### Verified Tables/Views (Known to Exist)

| Table/View | Used By |
|-----------|---------|
| `App_KPI_Dashboard.Supplier_Metrics` | take-rate.sql |
| `App_KPI_Dashboard.net_revenue_retention_all_customers` | top-customer-concentration.sql |
| `App_KPI_Dashboard.HS_QBO_GMV_Waterfall` | net-revenue-gap.sql (columns unverified) |
| `src_fivetran_qbo.invoice` | invoice-collection-rate, overdue-invoices, factoring-capacity, revenue-vs-target, net-revenue-gap, avg-invoice-collection-time, ar-aging-buckets, ontime-collection-rate |
| `src_fivetran_qbo.customer` | overdue-invoices, factoring-capacity, ar-aging-buckets |
| `src_fivetran_qbo.account` | working-capital, months-of-runway |
| `src_fivetran_qbo.bill` | months-of-runway |
| `src_fivetran_qbo.bill_line` | months-of-runway |
| `src_fivetran_qbo.payment` | avg-invoice-collection-time, ontime-collection-rate |
| `src_fivetran_qbo.payment_line` | avg-invoice-collection-time, ontime-collection-rate |
| `src_fivetran_hubspot.deal` | ALL demand-sales queries, ALL supply queries, marketing queries |
| `src_fivetran_hubspot.owner` | pipeline-coverage, win-rate, avg-deal-size, sales-cycle, meetings-booked-qtd, deals-closing-soon, expired-open-deals, companies-not-contacted |
| `src_fivetran_hubspot.deal_pipeline_stage` | pipeline-coverage, deals-by-stage, supply-funnel, new-unique-inventory, deals-closing-soon, expired-open-deals, companies-not-contacted |
| `src_fivetran_hubspot.engagement` | meetings-booked-qtd, weekly-contact-attempts |
| `src_fivetran_hubspot.contact` | weekly-contact-attempts, marketing queries |
| `src_fivetran_hubspot.deal_contact` | marketing-influenced-pipeline, attribution-by-channel |
| `mongodb.audience_listings` | listings-published-per-month |

### Unverified Properties/Columns (Need HubSpot Schema Check)

| Property | Used In | Risk |
|----------|---------|------|
| `deal.property_event_type` | pipeline-coverage-by-event-type | HIGH |
| `deal.property_date_converted_onboarded` | new-unique-inventory | HIGH |
| `deal.property_onboarded_at` | new-unique-inventory | HIGH |
| `deal.property_date_converted_meeting_booked` | meetings-booked-mtd | HIGH |
| `deal.property_hubspot_owner_id` | meetings-booked-mtd | MEDIUM |
| `deal.property_notes_last_updated` | companies-not-contacted-7d | MEDIUM |
| `deal.property_hs_last_sales_activity_timestamp` | companies-not-contacted-7d | MEDIUM |
| `deal.property_hs_forecast_amount` | pipeline-coverage, deals-closing-soon | LOW (documented in master plan) |
| `contact.property_hs_lead_status` | weekly-contact-attempts | HIGH |
| `engagement.contact_id` | weekly-contact-attempts | HIGH (may need association table) |
| `deal_pipeline_id = 'supply'` | ALL supply queries | HIGH |

---

## Recommended Deployment Order

### Wave 1: Core Financial Metrics (Deploy First -- No External Dependencies)

These use QBO tables only (Fivetran QBO sync is stable):

1. `coo-ops/invoice-collection-rate.sql`
2. `coo-ops/overdue-invoices.sql`
3. `coo-ops/working-capital.sql`
4. `coo-ops/factoring-capacity.sql`
5. `coo-ops/avg-invoice-collection-time.sql`
6. `coo-ops/ar-aging-buckets.sql`
7. `coo-ops/ontime-collection-rate.sql`
8. `ceo-bizdev/revenue-vs-target.sql`

### Wave 2: Deployed View Queries (Use Existing BigQuery Views)

These depend on already-deployed App_KPI_Dashboard views:

9. `coo-ops/take-rate.sql` (uses `Supplier_Metrics`)
10. `coo-ops/top-customer-concentration.sql` (uses `net_revenue_retention_all_customers`)

### Wave 3: Demand Sales HubSpot Queries

These use standard HubSpot Fivetran tables (well-understood schema):

11. `demand-sales/pipeline-coverage-by-rep.sql`
12. `demand-sales/win-rate-90-days.sql`
13. `demand-sales/avg-deal-size-ytd.sql`
14. `demand-sales/sales-cycle-length.sql`
15. `demand-sales/deals-by-stage-funnel.sql`
16. `demand-sales/deals-closing-soon.sql`
17. `demand-sales/expired-open-deals.sql`
18. `demand-sales/companies-not-contacted-7d.sql`
19. `demand-sales/meetings-booked-qtd.sql`

### Wave 4: Marketing Queries

These use HubSpot contact + deal_contact associations:

20. `marketing/marketing-leads-funnel.sql`
21. `marketing/mql-to-sql-conversion.sql`
22. `marketing/marketing-influenced-pipeline.sql`
23. `marketing/attribution-by-channel.sql`

### Wave 5: MongoDB Queries

24. `supply/listings-published-per-month.sql` (uses `mongodb.audience_listings`)

### Wave 6: Supply Queries (Deploy After Schema Verification)

**BLOCKED until supply pipeline ID and custom property names are verified:**

25. `supply/new-unique-inventory.sql` (after pipeline ID + property verification)
26. `supply/meetings-booked-mtd.sql` (after bug fix + property verification)
27. `supply/supply-funnel.sql` (after pipeline ID + stage name verification)
28. `supply/weekly-contact-attempts.sql` (after engagement schema + property verification)
29. `supply/pipeline-coverage-by-event-type.sql` (after property verification)

### Wave 7: Needs Schema Verification

30. `coo-ops/net-revenue-gap.sql` (after `HS_QBO_GMV_Waterfall` column verification)
31. `coo-ops/months-of-runway.sql` (deploy but note burn rate limitation)

---

## Pre-Deployment Action Items

| # | Action | Owner | Priority |
|---|--------|-------|----------|
| 1 | **Fix `meetings-booked-mtd.sql` bug**: Change `COUNT(engagement_id)` to `COUNT(deal_id)` | Dev | CRITICAL |
| 2 | **Verify supply pipeline ID** in HubSpot: Is it `'supply'` or something else? | Deuce/Ian | HIGH |
| 3 | **Verify HubSpot custom properties**: `date_converted_onboarded`, `date_converted_meeting_booked`, `event_type`, `hs_lead_status` values for supply | Deuce/Ian | HIGH |
| 4 | **Verify `HS_QBO_GMV_Waterfall` columns**: Do `contract_status`, `contract_value`, `spent_value` exist? | Dev | HIGH |
| 5 | **Verify engagement schema**: Does `engagement` table have direct `contact_id` or need `engagement_contact` join? | Dev | HIGH |
| 6 | **Resolve take rate target**: Master plan says 45% (COO section) vs 50% (Company Health section, targets.json). Pick one. | Deuce | MEDIUM |
| 7 | **Fix `working-capital.sql`**: Remove `LongTermLiability` from Current Liability classification | Dev | MEDIUM |
| 8 | **Consider externalizing quotas**: Move pipeline-coverage-by-rep.sql quotas to targets.json | Dev | LOW |
| 9 | **Consider true last-touch attribution**: Marketing queries use simplified FT=LT model | Marketing | LOW |

---

## Queries NOT Yet Created (From Master Plan)

These metrics are defined in the master plan but have no SQL files:

| Metric | Department | Status | Blocker |
|--------|-----------|--------|---------|
| Cash Position | COO/CEO | Phase 4 | Needs SimpleFin API |
| Lead Queue Runway | Supply | Phase 4 | Needs Smart Lead API |
| Operating Expenses vs Budget | COO | Needs Build | -- |
| Bill Payment Timeliness | COO | Needs Build | -- |
| Current Assets | COO | Derivable from working-capital.sql | -- |
| New Target Accounts | CEO | Needs HubSpot property verification | -- |
| Hot/Warm/Cold Deals | Sales | Phase 3 | Needs AI Deal Scoring |
| Contract Spend % | Demand AM | Needs Build | -- |
| Time to Fulfill | Demand AM | Needs Build (view exists: `Days_to_Fulfill_Contract_Spend_From_Close_Date`) | -- |
| NPS Score | Demand AM | Needs Build (view exists: `organizer_recap_NPS_score`) | -- |
| Offer Acceptance % | Demand AM | Needs Build | -- |
| NRR Top Supply Users | Supply AM | Needs Build | -- |
| Cost per MQL | Marketing | Needs ad spend data | -- |
| All Engineering metrics | Engineering | Phase 5 | Needs Asana/GitHub/Notion APIs |
| All Accounting secondary | Accounting | Needs Build | -- |

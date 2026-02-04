# Session Handoff: BigQuery Capacity Pipeline

**Date:** 2026-02-01
**Branch:** `feature/bigquery-capacity-pipeline-clean` (in recess-marketplace repo)
**PR:** #2239 (Draft)

---

## Mission

Implement BigQuery capacity pipeline to sync `limited_capacity` data from Rails to BigQuery for the Company KPI Dashboard. This enables joining with HubSpot data via `owner_email` for comprehensive reporting.

---

## What Was Completed

### 1. Implementation (Complete)
- **BigqueryService** (`app/services/bigquery_service.rb`)
  - `create_listings_capacity_table` - Creates table if not exists
  - `insert_listings_capacity(rows)` - Batch insert with 500-row chunks
  - `delete_listings_capacity_for_month(report_month)` - Idempotent DELETE before INSERT

- **YearlyReport** (`app/models/yearly_report.rb`)
  - Modified `report_for_recently_added_listings` to dual-write to both Google Sheets and BigQuery
  - Added `sync_to_bigquery: true` parameter (default enabled)
  - Added `owner_email` field for HubSpot join key

- **Schema** (`config/bigquery_schemas/listings_capacity_schema.json`)
  - 17 fields including `listing_id`, `report_month`, `owner_email`, `limited_capacity`, `synced_at`

### 2. Tests (Complete)
- **`spec/models/yearly_report_bigquery_spec.rb`** - 7 test cases covering:
  - Correct data structure for BigQuery insert
  - `owner_email` included for HubSpot join
  - DELETE before INSERT ordering (idempotent)
  - `sync_to_bigquery: false` flag skips BigQuery
  - Google Sheets still works when BigQuery disabled
  - Returns count hash with `bigquery_rows` and `sheets_rows`
  - Handles inactive BigQuery service gracefully

### 3. Code Review Fixes
- Fixed confusing test name ("does not call" → "calls but returns early")
- Added `.ordered` assertions to verify DELETE happens before INSERT

### 4. PR Created
- **PR #2239**: `feat: Add BigQuery capacity pipeline for Company KPI Dashboard`
- 6 clean commits cherry-picked from dev
- Draft status, CI running

---

## Key Decisions

1. **Direct Rails → BigQuery** (not SQL-based) because `limited_capacity` requires `ActivationPlanService` logic
2. **Idempotent DELETE + INSERT** pattern for monthly data sync
3. **Feature flag guard** via `BigqueryService.active?` - returns early if disabled
4. **`owner_email` as join key** to HubSpot `contact.property_email`

---

## Files Changed (in recess-marketplace)

| File | Change |
|------|--------|
| `app/services/bigquery_service.rb` | Added 3 new methods |
| `app/models/yearly_report.rb` | Modified `report_for_recently_added_listings` |
| `config/bigquery_schemas/listings_capacity_schema.json` | New file |
| `spec/models/yearly_report_bigquery_spec.rb` | New file (7 tests) |

---

## TODO / Next Steps

1. **Wait for CI** - PR #2239 is running tests
2. **Mark PR Ready for Review** - Once CI passes
3. **Deploy to Staging** - Verify with real BigQuery credentials
4. **Manual Verification** - Run `YearlyReport.report_for_recently_added_listings(Date.today)` on staging
5. **Create Looker Studio view** - Join `listings_capacity` with HubSpot data

---

## Related Documentation

- Implementation Plan: `context/plans/2026-01-28-bigquery-capacity-pipeline.md`
- Dashboard Context: `docs/yearly-capacity-report/dashboard-context.md`

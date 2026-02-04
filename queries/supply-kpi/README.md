# Supply KPI Queries

BigQuery queries for supply-side KPIs tracked in the dashboard.

## Completed Queries

| File | Description | Status |
|------|-------------|--------|
| `manual-events-imports-pipeline-deals.sql` | Deals from Manual Events & Imports pipeline with target account fields | ✅ Done |

## TODO: Queries to Create

These queries would replace the mock data in `dashboard/data/mock_data.py` with live BigQuery data.

### Priority 1: Core Supply Metrics

| Query | Description | Mock Data Source | BigQuery Tables |
|-------|-------------|------------------|-----------------|
| `supply-capacity-by-type.sql` | Capacity (reach) by event type | `SUPPLY_CAPACITY_BY_TYPE` | `mongodb.audience_listings`, `mongodb.audience_creatives` |
| `supply-new-unique-inventory.sql` | New venues/listings added QTD | `DEPARTMENT_DETAILS["Supply"]` | `mongodb.audience_listings` (filter by `created_at`) |
| `supply-pipeline-by-stage.sql` | Pipeline value by stage for supply pipeline | `DEPARTMENT_DETAILS["Supply"]` | `src_fivetran_hubspot.deal`, `deal_pipeline_stage` |

### Priority 2: Activity Tracking

| Query | Description | Mock Data Source | BigQuery Tables |
|-------|-------------|------------------|-----------------|
| `supply-contact-attempts.sql` | Weekly contact attempts for target accounts | `SUPPLY_CONTACT_ATTEMPTS` | `src_fivetran_hubspot.contact` (filter by `property_target_account_supply`) |
| `supply-meetings-booked.sql` | Meetings booked MTD for supply pipeline | `DEPARTMENT_DETAILS["Supply"]` | `src_fivetran_hubspot.engagement_meeting`, `engagement_deal` |

### Priority 3: Target Account Tracking

| Query | Description | Mock Data Source | BigQuery Tables |
|-------|-------------|------------------|-----------------|
| `supply-target-accounts-status.sql` | Target account progress (contacted, converted) | N/A (new metric) | `src_fivetran_hubspot.company` (filter by `property_target_account_supply`) |
| `supply-capacity-trend.sql` | Monthly capacity trend by event type | `SUPPLY_CAPACITY_TREND` | `mongodb.report_data` (key = 'yearly_limited_capacity') |

---

## Key Data Sources

### HubSpot (via Fivetran)
- **Pipeline ID:** `16052690` (Manual Events & Imports)
- **Market Type Filter:** `property_market_type = 'supplier'`
- **Target Account Field:** `property_target_account_supply` (on company)
- **Primary Company Association:** `type_id = 5` in `deal_company`

### MongoDB (via Stitch)
- **Capacity Data:** `mongodb.report_data` (key = 'yearly_limited_capacity')
- **Listings:** `mongodb.audience_listings` (use `org.name` for supplier)
- **Event Types:** `primary_type` field (needs normalization - see bigquery.md)

---

## Notes

- All queries should use the project `stitchdata-384118`
- Filter deleted records: `_fivetran_deleted = FALSE` for Fivetran tables
- See `/tech-stack/bigquery.md` in recess-brain repo for full schema docs

---

*Created: 2026-02-01*

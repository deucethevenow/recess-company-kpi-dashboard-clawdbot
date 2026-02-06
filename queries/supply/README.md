# Supply Queries (Ian Hong)

> **Owner:** Ian Hong
> **Primary Metric:** New Unique Inventory Added (16/quarter)
> **HubSpot Dashboard:** [Supply Pipeline](https://app.hubspot.com/reports-dashboard/6699636/view/18349412)

## HubSpot Property Names (from dashboard)

These are the actual HubSpot property names used for Supply tracking:

| Property | Description |
|----------|-------------|
| `date_attempted_to_contact` | When first contact attempt was made |
| `date_converted_meeting_booked` | When meeting was booked |
| `date_converted_sql` | When became SQL (Sales Qualified Lead) |
| `date_converted_sal` | When became SAL (Sales Accepted Lead) |
| `date_converted_onboarded` | When onboarding completed |
| `onboarded_at` | Final onboard timestamp |
| `closedate` | Deal close date |

## Query Index

| Query File | Metric | Target | Status |
|------------|--------|--------|--------|
| `new-unique-inventory.sql` | New Unique Inventory Added | 16/qtr | ✅ Created |
| `weekly-contact-attempts.sql` | Weekly Contact Attempts | 600/week | ✅ Created |
| `meetings-booked-mtd.sql` | Meetings Booked (MTD) | 24/month | ✅ Created |
| `pipeline-coverage-by-event-type.sql` | Pipeline Coverage by Event Type | 3x | ✅ Created |
| `supply-funnel.sql` | Supply Funnel Conversion | See targets | ✅ Created |
| `listings-published-per-month.sql` | Listings Published | - | ✅ Created |
| `lead-queue-runway.md` | Lead Queue Runway | 30 days | ⛔ Needs Smart Lead API |

## Monthly Funnel Targets

| Stage | Monthly Target |
|-------|----------------|
| Attempted to Contact | 60 |
| Connected | 60 |
| Meeting Booked | 24 |
| Proposal Sent | 16 |
| Onboarding | 16 |
| Won (target accounts) | 4 |

## Data Sources

| Source | Tables/Endpoints | Status |
|--------|-----------------|--------|
| HubSpot (via BigQuery) | `src_fivetran_hubspot.deal`, `engagement`, `contact` | ✅ Available |
| MongoDB (via BigQuery) | `mongodb.audience_listings` | ✅ Available |
| MongoDB (via BigQuery) | `mongodb.report_datas` | ⛔ Waiting Fivetran sync |
| Google Sheets | Inventory goals by event type | ✅ Manual reference |
| **Smart Lead API** | Lead queue, sequences, send capacity | ⛔ **Integration needed** |

## Event Type Goals (from Google Sheets)

| Event Type | Sample Capacity Goal |
|------------|---------------------|
| university_housing | 40,000 |
| fitness_studios | 400,000 |
| youth_sports | 500,000 |
| kids_camp | 150,000 |
| music_festivals | 72,000 |
| running | 125,000 |
| gyms | 100,000 |
| college_events | 80,000 |

## TODOs / Verification Needed

1. **Verify Supply Pipeline ID** - Queries assume `deal_pipeline_id = 'supply'`
2. **Verify event_type property** - Need actual HubSpot property name
3. **Verify "Supply Target" contact property** - For filtering contact attempts
4. **Define "unique inventory"** - Clarify with Ian what counts as unique
5. **Smart Lead API integration** - Required for Lead Queue Runway metric

## Status Indicators

| Metric | 🟢 GREEN | 🟡 YELLOW | 🔴 RED |
|--------|----------|----------|--------|
| New Inventory (qtr) | ≥ 16 | 12-16 | < 12 |
| Contact Attempts (wk) | ≥ 600 | 450-600 | < 450 |
| Meetings (mo) | ≥ 24 | 18-24 | < 18 |
| Pipeline Coverage | ≥ 3x | 2x-3x | < 2x |
| Lead Queue Runway | ≥ 30 days | 15-30 days | < 15 days |

## Key Insight: Lead Inventory Problem

From the original brainstorm document:

> "Supply person struggles to diagnose WHY targets are missed. Data split between HubSpot and Sheets. Not analytical - needs prescriptive dashboard."

The **Lead Queue Runway** metric is critical because it predicts when prospecting will stall. If runway drops below 15 days, Ian needs to source more leads immediately.

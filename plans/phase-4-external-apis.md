# Phase 4: External API Integrations

> **Status:** Not Started
> **Goal:** Connect non-BigQuery data sources for metrics that cannot be derived from existing warehouse
> **Estimated Unique Queries/Integrations:** ~10
> **Dependencies:** Phase 1 and Phase 2 (dashboard framework must be running)

---

## Scope Summary

Phase 4 connects external APIs that are NOT currently flowing through BigQuery. These integrations unblock metrics that are marked as "Blocked" or "Phase 4" in earlier phases.

This phase answers: "We have the dashboard structure, but some data lives outside BigQuery -- let's connect it."

---

## Integration Overview

| # | Integration | Metrics Unblocked | Current Status | Priority |
|---|-------------|:-----------------:|:--------------:|:--------:|
| 1 | **SimpleFin** | 1 (Cash Position) | Ready to Integrate | HIGH |
| 2 | **Bill.com** | 2-3 (Bills pending, vendor onboarding) | Not Started | MEDIUM |
| 3 | **Zendesk/Intercom** | 2 (Ticket response time, open tickets) | Not Started | LOW |
| 4 | **Smart Lead** | 2-3 (Lead Queue Runway, contacts sequenced) | Not Started | MEDIUM |
| 5 | **HubSpot (deep)** | 2-3 (Meetings, activities beyond BQ sync) | Partial | MEDIUM |

---

## 1. SimpleFin Integration (Cash Position)

> **Priority:** HIGH
> **Existing Code:** Client exists in `chief-of-staff` project
> **Cost:** $1.50/month

### Metrics Unblocked

| Metric | Target | Appears On | Current Status |
|--------|:------:|------------|:--------------:|
| **Cash Position** | >$500K | CEO Dashboard, COO Dashboard | Blocked (Phase 4) |

### Technical Details

| Item | Detail |
|------|--------|
| Client Code | `/Users/deucethevenowworkm1/Projects/chief-of-staff/integrations/simplefin_client.py` |
| Setup Script | `/Users/deucethevenowworkm1/Projects/chief-of-staff/scripts/setup_simplefin.py` |
| Auth Method | Access URL token |
| Data Returned | Sum of all connected bank account balances |
| Refresh Frequency | Daily |
| Env Variable | `SIMPLEFIN_ACCESS_URL` |

### Implementation Steps

1. [ ] Sign up for SimpleFin ($1.50/mo)
2. [ ] Run setup script to get access token
3. [ ] Connect bank accounts via SimpleFin bridge
4. [ ] Claim access token and store as `SIMPLEFIN_ACCESS_URL`
5. [ ] Adapt `simplefin_client.py` for dashboard use
6. [ ] Create `queries/coo-ops/cash-position.py` (API call, not SQL)
7. [ ] Display on CEO and COO dashboards
8. [ ] Add to daily refresh schedule

---

## 2. Bill.com Integration

> **Priority:** MEDIUM
> **Current Status:** Not Started

### Metrics Unblocked

| Metric | Target | Appears On | Current Status |
|--------|:------:|------------|:--------------:|
| **Bills Pending Approval** | - | Accounting tab | Build |
| **Vendors Not Onboarded** (with approved offer) | 0 | Accounting tab | Build |
| **Bills Missing W-9** | 0 | Accounting tab | Ready (QBO vendor report) |

### Technical Details

| Item | Detail |
|------|--------|
| API | Bill.com REST API v3 |
| Auth Method | OAuth 2.0 or API keys |
| Data Needed | Bills by status, vendor onboarding status |
| Refresh Frequency | Daily |
| Env Variables | `BILLCOM_API_KEY`, `BILLCOM_ORG_ID` |

### Implementation Steps

1. [ ] Get Bill.com API credentials
2. [ ] Build `integrations/billcom_client.py`
3. [ ] Create `queries/accounting/bills-pending-approval.py`
4. [ ] Create `queries/accounting/vendors-not-onboarded.py`
5. [ ] Display on Accounting tab
6. [ ] Add to daily refresh schedule

---

## 3. Zendesk/Intercom Integration

> **Priority:** LOW
> **Current Status:** Not Started

### Metrics Unblocked

| Metric | Target | Appears On | Current Status |
|--------|:------:|------------|:--------------:|
| **Avg Ticket Response Time** | <=16hrs | Supply AM (Ashton) | Build |
| **Open Tickets** | - | Supply AM (Ashton) | Build |

### Technical Details

| Item | Detail |
|------|--------|
| API | Zendesk REST API or Intercom API (TBD which platform is used) |
| Auth Method | API token |
| Data Needed | Ticket response times, open ticket count |
| Refresh Frequency | Daily |
| Env Variables | `ZENDESK_API_KEY` or `INTERCOM_API_KEY` |

### Implementation Steps

1. [ ] Determine which platform (Zendesk vs Intercom) is primary
2. [ ] Get API credentials
3. [ ] Build `integrations/support_client.py`
4. [ ] Create `queries/supply-am/ticket-response-time.py`
5. [ ] Create `queries/supply-am/open-tickets.py`
6. [ ] Display on Supply AM tab
7. [ ] Add to daily refresh schedule

---

## 4. Smart Lead Integration

> **Priority:** MEDIUM
> **Current Status:** Not Started
> **Blocks:** Supply metrics (Ian Hong)

### Metrics Unblocked

| Metric | Target | Appears On | Current Status |
|--------|:------:|------------|:--------------:|
| **Lead Queue Runway** | 30 days | Supply (Ian Hong) | Blocked |
| **New Contacts Sequenced** | - | Supply (Ian Hong) | Blocked |

### Lead Queue Runway Calculation

```
Lead Queue Runway = Leads in Queue / Avg Leads Contacted Per Day

Components needed from Smart Lead API:
- Leads actively sequencing
- Leads enrolled but not yet sequencing
- Leads staged for next sequence
- Send capacity (~600 emails/day)
```

### Technical Details

| Item | Detail |
|------|--------|
| API | Smart Lead API |
| Auth Method | API key |
| Data Needed | Sequence enrollment, lead counts, send capacity |
| Refresh Frequency | Daily |
| Env Variables | `SMARTLEAD_API_KEY` |

### Implementation Steps

1. [ ] Get Smart Lead API credentials
2. [ ] Review API documentation for available endpoints
3. [ ] Build `integrations/smartlead_client.py`
4. [ ] Create `queries/supply/lead-queue-runway.py`
5. [ ] Create `queries/supply/contacts-sequenced.py`
6. [ ] Display on Supply tab
7. [ ] Add to daily refresh schedule

---

## 5. HubSpot Deep Integration

> **Priority:** MEDIUM
> **Current Status:** Partial (basic data flows through BigQuery via Fivetran)
> **Note:** Some HubSpot data already available in BigQuery. This covers ADDITIONAL data needs.

### Metrics Enhanced

| Metric | What's Missing | Current Workaround |
|--------|---------------|-------------------|
| **Meetings (detailed)** | Meeting outcomes, attendees | Basic count via BQ |
| **Activities (detailed)** | Activity types, response times | Basic engagement via BQ |
| **Email tracking** | Open rates, reply rates | Not available |

### Technical Details

| Item | Detail |
|------|--------|
| API | HubSpot API v3 |
| Auth Method | Private app access token (already exists: portal 6699636) |
| Additional Data | Meeting outcomes, email tracking, activity details |
| Refresh Frequency | Daily |
| Note | Most HubSpot data already in BQ - this is for gaps only |

### Implementation Steps

1. [ ] Audit which HubSpot data is NOT in BigQuery
2. [ ] Identify specific API endpoints needed
3. [ ] Extend existing HubSpot integration for missing data
4. [ ] Create supplementary queries for enhanced metrics
5. [ ] Add to daily refresh schedule

---

## Supply Data Dependencies (Phase 4)

Additional Supply metrics that require non-BigQuery data:

| Metric | Target | Data Source | Status |
|--------|:------:|-------------|:------:|
| Total Limited Capacity | - | `mongodb.report_datas` (waiting Fivetran sync) | Blocked |
| Total Yearly Capacity | - | BigQuery | Ready |
| Capacity by Event Type | - | BigQuery | Ready |
| Q1 New Inventory Value | $1.162M | BigQuery | Build |

**Note:** `mongodb.report_datas` Fivetran sync is a data pipeline issue, not an API integration. This needs to be resolved with the data engineering team.

---

## Dependencies on Other Phases

| Dependency | Phase | Impact |
|------------|:-----:|--------|
| Dashboard framework running | 1 | APIs need a place to display data |
| COO dashboard structure | 2 | Cash Position displays on COO tab |
| Accounting tab structure | 2 | Bill.com metrics display on Accounting tab |
| Supply AM tab structure | 2 | Zendesk/Intercom metrics display on Supply AM tab |
| Fivetran `mongodb.report_datas` sync | Infra | Blocks Total Limited Capacity |

---

## Acceptance Criteria

Phase 4 is **done** when:

- [ ] SimpleFin Cash Position shows live bank balance on CEO + COO dashboards
- [ ] Bill.com bills pending and vendor onboarding status display on Accounting tab
- [ ] Zendesk/Intercom ticket metrics display on Supply AM tab
- [ ] Smart Lead lead queue runway displays on Supply tab
- [ ] All API integrations have error handling and fallback displays
- [ ] All API credentials stored securely in environment variables (NOT in code)
- [ ] Daily refresh schedule includes all API calls
- [ ] API rate limits are respected (especially HubSpot: 100 requests/10 seconds)
- [ ] Monitoring/alerting exists for API failures

---

## Estimated Integration Count

| Integration | API Calls/Day | New Queries | Display Cards |
|-------------|:------------:|:-----------:|:-------------:|
| SimpleFin | 1 | 1 | 2 (CEO + COO) |
| Bill.com | 2-3 | 2-3 | 3 |
| Zendesk/Intercom | 2 | 2 | 2 |
| Smart Lead | 2-3 | 2-3 | 3 |
| HubSpot (deep) | 3-5 | 2-3 | 3 |
| **Phase 4 Total** | **~12** | **~10** | **~13** |

---

## Security Considerations

- All API keys stored as environment variables
- SimpleFin access URL is sensitive (grants read access to bank balances)
- Bill.com credentials grant access to financial data
- HubSpot private app token already in use (portal ID: 6699636)
- API calls should be server-side only (never exposed to client)
- Implement credential rotation schedule

---

## Integration Testing

After implementing a BQ function, follow this standard pattern:
1. Unit test (mock BQ client)
2. Integration smoke test (real BQ, `pytest -m integration`)
3. Enriched tooltip with 5 static fields
4. Add metric target to `targets.json` via Settings tab

**This phase: 0 integration smoke tests**

Run: `cd dashboard && pytest -m integration`

## Tooltip Enrichment

Each metric gets a 5-section tooltip:
- Definition (plain English)
- Why It Matters (business impact)
- Calculation (formula in monospace)
- Target pill (from `targets.json` via Settings tab)
- 2025 Benchmark pill (from `METRIC_DEFINITIONS`, where meaningful)
- Edge Cases (amber callout, when applicable)

**This phase: 2 tooltips to enrich**

## Settings Tab Targets

New metric targets added to the Settings tab's "Metric Targets" form and saved to `targets.json`:

**This phase: 2 new metric targets**

Standard pattern: "After implementing a BQ function: (1) unit test, (2) integration smoke test, (3) enriched tooltip with 5 static fields, (4) add metric target to targets.json via Settings tab"

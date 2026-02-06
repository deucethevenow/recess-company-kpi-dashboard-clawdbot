# Phase 5: Engineering Metrics + Remaining External Integrations

> **Status:** Not Started
> **Goal:** Engineering team accountability + remaining API-dependent metrics (GA4, email)
> **Estimated Unique Integrations/Queries:** ~12
> **Dependencies:** Phase 1 (Engineering PRIMARY metrics defined), Phase 4 (API integration pattern established)

---

## Scope Summary

Phase 5 connects the engineering-specific toolchain (Asana, GitHub, Notion) to the dashboard and adds remaining external API metrics for Marketing (GA4, email stats). Engineering team members each have a PRIMARY metric defined in Phase 1, but the data sources are all external APIs.

This phase answers: "Is the engineering team delivering on their commitments, and what does marketing's web/email funnel look like?"

---

## Engineering Team Overview

| Person | Role | Primary Metric | Target | Data Source |
|--------|------|---------------|:------:|-------------|
| **Arbind** | Engineer | Features Fully Scoped | 5/mo | Asana / GitHub |
| **Mateus** | Engineer | BizSup Completed | 10/mo | Asana (BizSup project) |
| **Anderson** | Engineer | PRDs Generated | 3/mo | Asana / Notion |
| **Anderson** | Engineer | FSDs Generated | 2/mo | Asana / Notion |
| **Lucas** | Engineer | Feature Releases | TBD | GitHub |

---

## Integration 1: Asana API

> **Priority:** HIGH (blocks 3 of 4 engineers' PRIMARY metrics)
> **Current Status:** Not Started

### Metrics Powered by Asana

| # | Metric | Person | Formula | Target | Status |
|---|--------|--------|---------|:------:|:------:|
| 1 | **Features Fully Scoped** | Arbind | Count of tasks marked "scoped" in Features project per month | 5/mo | Build |
| 2 | **BizSup Completed** | Mateus | Count of completed tasks in BizSup project per month | 10/mo | Build |
| 3 | **PRDs Generated** | Anderson | Count of PRD tasks completed per month | 3/mo | Build |
| 4 | **FSDs Generated** | Anderson | Count of FSD tasks completed per month | 2/mo | Build |
| 5 | **Sprint Velocity** | Team | Story points completed per sprint (consistency) | Consistent | Build |
| 6 | **Tech Debt Tickets** | Team | Count of open tech debt tasks | - | Build |

### Technical Details

| Item | Detail |
|------|--------|
| API | Asana REST API |
| Auth Method | Personal Access Token or OAuth 2.0 |
| Projects to Track | Features, BizSup, PRDs, FSDs, Sprints |
| Data Needed | Task completion counts, dates, assignees, custom fields |
| Refresh Frequency | Daily |
| Env Variables | `ASANA_API_KEY`, `ASANA_WORKSPACE_ID` |

### Implementation Steps

1. [ ] Get Asana API credentials (personal access token)
2. [ ] Identify project GIDs for: Features, BizSup, PRDs, FSDs
3. [ ] Build `integrations/asana_client.py`
4. [ ] Create query files:
   - `queries/engineering/features-scoped.py` (Arbind)
   - `queries/engineering/bizsup-completed.py` (Mateus)
   - `queries/engineering/prds-generated.py` (Anderson)
   - `queries/engineering/fsds-generated.py` (Anderson)
   - `queries/engineering/sprint-velocity.py` (Team)
   - `queries/engineering/tech-debt-tickets.py` (Team)
5. [ ] Display on Engineering tab
6. [ ] Add to daily refresh schedule

---

## Integration 2: GitHub API

> **Priority:** HIGH (blocks Lucas's PRIMARY metric)
> **Current Status:** Not Started

### Metrics Powered by GitHub

| # | Metric | Person | Formula | Target | Status |
|---|--------|--------|---------|:------:|:------:|
| 1 | **Feature Releases** | Lucas | Count of releases/deploys per period | TBD | Define |
| 2 | **Bug Count (Open)** | Team | Count of open issues labeled "bug" | <10 | Build |
| 3 | **Deploy Frequency** | Team | Count of deployments per week | 3+/week | Build |

### Technical Details

| Item | Detail |
|------|--------|
| API | GitHub REST API v3 or GraphQL v4 |
| Auth Method | Personal Access Token or GitHub App |
| Repos to Track | Main application repo(s) |
| Data Needed | Releases, issues (bugs), deployment events, PR merges |
| Refresh Frequency | Daily |
| Env Variables | `GITHUB_TOKEN`, `GITHUB_ORG`, `GITHUB_REPOS` |

### Implementation Steps

1. [ ] Get GitHub API token with appropriate scopes
2. [ ] Identify repositories to track
3. [ ] Build `integrations/github_client.py`
4. [ ] Create query files:
   - `queries/engineering/feature-releases.py` (Lucas)
   - `queries/engineering/bug-count-open.py` (Team)
   - `queries/engineering/deploy-frequency.py` (Team)
5. [ ] Display on Engineering tab
6. [ ] Add to daily refresh schedule

---

## Integration 3: Notion API

> **Priority:** MEDIUM (supplementary to Asana for PRDs/FSDs)
> **Current Status:** Not Started

### Metrics Powered by Notion

| # | Metric | Person | Formula | Target | Status |
|---|--------|--------|---------|:------:|:------:|
| 1 | **PRDs in Notion** | Anderson | Count of PRD pages created/updated per month | 3/mo | Build |
| 2 | **FSDs in Notion** | Anderson | Count of FSD pages created/updated per month | 2/mo | Build |

**Note:** Anderson's PRD/FSD metrics may come from Asana OR Notion depending on where the team tracks them. Determine primary source before building both.

### Technical Details

| Item | Detail |
|------|--------|
| API | Notion API v1 |
| Auth Method | Internal integration token |
| Data Needed | Page creation/update counts in PRD and FSD databases |
| Refresh Frequency | Daily |
| Env Variables | `NOTION_API_KEY`, `NOTION_PRD_DB_ID`, `NOTION_FSD_DB_ID` |

### Implementation Steps

1. [ ] Determine if Notion is primary source for PRDs/FSDs (vs Asana)
2. [ ] Create Notion internal integration
3. [ ] Get database IDs for PRD and FSD databases
4. [ ] Build `integrations/notion_client.py`
5. [ ] Create query files:
   - `queries/engineering/prds-notion.py`
   - `queries/engineering/fsds-notion.py`
6. [ ] Deduplicate with Asana data if both are used
7. [ ] Display on Engineering tab

---

## Integration 4: GA4 (Google Analytics 4)

> **Priority:** LOW
> **Current Status:** Not Started
> **Department:** Marketing

### Metrics Powered by GA4

| # | Metric | Department | Formula | Target | Status |
|---|--------|-----------|---------|:------:|:------:|
| 1 | **Website Traffic** | Marketing | Sessions, users, pageviews per period | - | Build |
| 2 | **Content Engagement** | Marketing | Avg session duration, pages per session | - | Build |

### Technical Details

| Item | Detail |
|------|--------|
| API | Google Analytics Data API (GA4) |
| Auth Method | Service account (same GCP project as BigQuery?) |
| Property ID | TBD |
| Data Needed | Sessions, users, pageviews, engagement metrics |
| Refresh Frequency | Daily |
| Env Variables | `GA4_PROPERTY_ID` (may use existing BigQuery service account) |

### Implementation Steps

1. [ ] Get GA4 property ID
2. [ ] Confirm service account has GA4 access (may reuse BigQuery credentials)
3. [ ] Build `integrations/ga4_client.py`
4. [ ] Create query files:
   - `queries/marketing/website-traffic.py`
   - `queries/marketing/content-engagement.py`
5. [ ] Display on Marketing tab
6. [ ] Add to daily refresh schedule

---

## Integration 5: HubSpot Email Stats

> **Priority:** LOW
> **Department:** Marketing

### Metrics Powered by HubSpot Email

| # | Metric | Department | Formula | Target | Status |
|---|--------|-----------|---------|:------:|:------:|
| 1 | **Email Open Rate** | Marketing | `Opens / Sent x 100` | 25% | Ready (HubSpot email) |

### Technical Details

| Item | Detail |
|------|--------|
| API | HubSpot Marketing Email API |
| Auth Method | Existing HubSpot private app token (portal 6699636) |
| Data Needed | Email send/open/click counts |
| Note | May already be accessible via Phase 4 HubSpot deep integration |

### Implementation Steps

1. [ ] Check if email stats are available in existing BigQuery HubSpot sync
2. [ ] If not, extend HubSpot integration from Phase 4
3. [ ] Create `queries/marketing/email-open-rate.py`
4. [ ] Display on Marketing tab

---

## Other Engineering Secondary Metrics

| # | Metric | Target | Formula | Data Source | Status |
|---|--------|:------:|---------|-------------|:------:|
| 1 | **Incidents (MTD)** | 0 | Count of production incidents | PagerDuty / Manual | Define |

**Note:** Incidents may remain a manual metric if there's no PagerDuty or incident tracking system.

---

## Complete Engineering Dashboard Layout

| Card | Person | Data Source | Phase |
|------|--------|-------------|:-----:|
| Features Fully Scoped | Arbind | Asana | 5 |
| BizSup Completed | Mateus | Asana | 5 |
| PRDs Generated | Anderson | Asana / Notion | 5 |
| FSDs Generated | Anderson | Asana / Notion | 5 |
| Feature Releases | Lucas | GitHub | 5 |
| Sprint Velocity | Team | Asana | 5 |
| Bug Count (Open) | Team | GitHub | 5 |
| Deploy Frequency | Team | GitHub | 5 |
| Incidents (MTD) | Team | Manual/PagerDuty | 5 |
| Tech Debt Tickets | Team | Asana/GitHub | 5 |

---

## Dependencies on Other Phases

| Dependency | Phase | Impact |
|------------|:-----:|--------|
| Dashboard framework running | 1 | Engineering tab must exist |
| Engineering PRIMARY metrics defined | 1 | Targets and owners confirmed |
| API integration pattern | 4 | Reuse integration architecture from Phase 4 |
| HubSpot deep integration | 4 | Email stats may piggyback on Phase 4 HubSpot work |

---

## Acceptance Criteria

Phase 5 is **done** when:

- [ ] Arbind's "Features Fully Scoped" metric displays live Asana data
- [ ] Mateus's "BizSup Completed" metric displays live Asana data
- [ ] Anderson's "PRDs Generated" and "FSDs Generated" display live data
- [ ] Lucas's "Feature Releases" metric displays live GitHub data
- [ ] Team metrics (Sprint Velocity, Bug Count, Deploy Frequency) are live
- [ ] Marketing website traffic from GA4 displays on Marketing tab
- [ ] Marketing email open rate displays on Marketing tab
- [ ] All integrations have error handling and fallback displays
- [ ] All API credentials stored securely in environment variables
- [ ] Daily refresh schedule includes all new API calls
- [ ] Engineering tab respects role-based access control

---

## Estimated Integration Count

| Integration | API Calls/Day | New Queries | Display Cards |
|-------------|:------------:|:-----------:|:-------------:|
| Asana | 5-10 | 6 | 6 |
| GitHub | 3-5 | 3 | 3 |
| Notion | 2-3 | 2 | 2 (may merge with Asana) |
| GA4 | 1-2 | 2 | 2 |
| HubSpot Email | 1 | 1 | 1 |
| **Phase 5 Total** | **~15** | **~12** | **~14** |

---

## Open Questions

1. **Asana vs Notion for PRDs/FSDs** - Which is the source of truth? Build for one, not both, unless deduplication is needed.
2. **Lucas's "Feature Releases" definition** - Is this GitHub releases, merged PRs to main, or deployments?
3. **Incidents tracking** - Does the team use PagerDuty, or is this manual?
4. **Sprint tool** - Asana sprints, or a separate tool like Shortcut/Linear?

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

**This phase: 4 tooltips to enrich**

## Settings Tab Targets

New metric targets added to the Settings tab's "Metric Targets" form and saved to `targets.json`:

**This phase: 4 new metric targets**

Standard pattern: "After implementing a BQ function: (1) unit test, (2) integration smoke test, (3) enriched tooltip with 5 static fields, (4) add metric target to targets.json via Settings tab"

# Phase 5: Engineering Metrics + Remaining External Integrations

> **Status:** Not Started
> **Goal:** Engineering team accountability + remaining API-dependent metrics (GA4, email)
> **Estimated Unique Integrations/Queries:** ~14
> **Dependencies:** Phase 1 (Engineering PRIMARY metrics defined), Phase 4 (API integration pattern established)

---

## Scope Summary

Phase 5 connects the engineering-specific toolchain (Asana, GitHub, Notion) to the dashboard and adds remaining external API metrics for Marketing (GA4, email stats). Engineering team members each have a PRIMARY metric that is Phase 1 by business priority but Phase 5 by implementation order due to external API dependencies. Phase 1 should use placeholder/manual entry for these metrics until Phase 5 is built.

This phase answers: "Is the engineering team delivering on their commitments, and what does marketing's web/email funnel look like?"

---

## Engineering Team PRIMARY Metrics

> **NOTE:** These are Phase 1 PRIMARY metrics by business priority but Phase 5 by implementation order (API dependency). Phase 1 should use placeholder/manual entry until Phase 5 is built.

| Person | Role | Primary Metric | Target | Data Source | Why It Matters |
|--------|------|---------------|:------:|-------------|----------------|
| **Arbind** | Engineer | Features Fully Scoped | 5/mo | Asana / GitHub | Unscoped features = mid-sprint chaos. |
| **Mateus** | Engineer | BizSup Completed | 10/mo | Asana (BizSup project) | Slow BizSup = frustrated sales/AM. |
| **Anderson** | Engineer | PRDs Generated | 3/mo | Asana / Notion | No PRDs = no roadmap clarity. |
| **Anderson** | Engineer | FSDs Generated | 2/mo | Asana / Notion | No FSDs = ambiguous implementation. |
| **Lucas** | Engineer | Feature Releases | TBD | GitHub | Delivery velocity. |

---

## Engineering Team SECONDARY Metrics

| Metric | Target | Data Source | Status |
|--------|:------:|-------------|:------:|
| Sprint Velocity | Consistent | Asana | Build |
| Bug Count (Open) | <10 | GitHub Issues API | Build |
| Deploy Frequency | 3+/week | GitHub Actions API | Build |
| Tech Debt Tickets | - | Asana / GitHub | Build |
| Incidents (MTD) | 0 | PagerDuty / Manual | Define |

---

## Batch Structure

### Batch A: Asana API (Highest Impact)

> Blocks 3 of 4 engineers' PRIMARY metrics. Build `asana_client.py` + 6 query files.

**Metrics delivered:**

| # | Metric | Person | Type | Target |
|---|--------|--------|------|:------:|
| 1 | Features Fully Scoped | Arbind | PRIMARY | 5/mo |
| 2 | BizSup Completed | Mateus | PRIMARY | 10/mo |
| 3 | PRDs Generated | Anderson | PRIMARY | 3/mo |
| 4 | FSDs Generated | Anderson | PRIMARY | 2/mo |
| 5 | Sprint Velocity | Team | SECONDARY | Consistent |
| 6 | Tech Debt Tickets | Team | SECONDARY | - |

**Files to create:**
- `integrations/asana_client.py`
- `queries/engineering/features-scoped.py` (Arbind)
- `queries/engineering/bizsup-completed.py` (Mateus)
- `queries/engineering/prds-generated.py` (Anderson)
- `queries/engineering/fsds-generated.py` (Anderson)
- `queries/engineering/sprint-velocity.py` (Team)
- `queries/engineering/tech-debt-tickets.py` (Team)

**Env:** `ASANA_API_KEY`, `ASANA_WORKSPACE_ID`

---

### Batch B: GitHub API

> Blocks Lucas's PRIMARY metric. Build `github_client.py` + 3 query files.

**Metrics delivered:**

| # | Metric | Person | Type | Target |
|---|--------|--------|------|:------:|
| 1 | Feature Releases | Lucas | PRIMARY | TBD |
| 2 | Bug Count (Open) | Team | SECONDARY | <10 |
| 3 | Deploy Frequency | Team | SECONDARY | 3+/week |

**Files to create:**
- `integrations/github_client.py`
- `queries/engineering/feature-releases.py` (Lucas)
- `queries/engineering/bug-count-open.py` (Team)
- `queries/engineering/deploy-frequency.py` (Team)

**Env:** `GITHUB_TOKEN`, `GITHUB_ORG`, `GITHUB_REPOS`

---

### Batch C: Notion API (If Needed)

> Only if Notion is primary source for PRDs/FSDs. May be skipped if Asana handles it.

**Metrics delivered:**

| # | Metric | Person | Type | Target |
|---|--------|--------|------|:------:|
| 1 | PRDs in Notion | Anderson | PRIMARY (alt source) | 3/mo |
| 2 | FSDs in Notion | Anderson | PRIMARY (alt source) | 2/mo |

**Note:** Anderson's PRD/FSD metrics may come from Asana OR Notion depending on where the team tracks them. Determine primary source before building both. If both are used, deduplication logic is required.

**Files to create (if needed):**
- `integrations/notion_client.py`
- `queries/engineering/prds-notion.py`
- `queries/engineering/fsds-notion.py`

**Env:** `NOTION_API_KEY`, `NOTION_PRD_DB_ID`, `NOTION_FSD_DB_ID`

---

### Batch D: GA4 + HubSpot Email (Marketing)

> Low priority. Website traffic and email stats for Marketing tab.

**Metrics delivered:**

| # | Metric | Department | Type | Target |
|---|--------|-----------|------|:------:|
| 1 | Website Traffic | Marketing | SECONDARY | - |
| 2 | Content Engagement | Marketing | SECONDARY | - |
| 3 | Email Open Rate | Marketing | SECONDARY | 25% |

**Files to create:**
- `integrations/ga4_client.py`
- `queries/marketing/website-traffic.py`
- `queries/marketing/content-engagement.py`
- `queries/marketing/email-open-rate.py`

**Env (GA4):** `GA4_PROPERTY_ID` (may reuse existing BigQuery service account)
**Env (HubSpot Email):** Existing HubSpot private app token (portal 6699636) -- may piggyback on Phase 4 HubSpot deep integration

---

## Integration 1: Asana API

> **Priority:** HIGH (blocks 3 of 4 engineers' PRIMARY metrics)
> **Current Status:** Not Started
> **Batch:** A

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
> **Batch:** B

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
> **Batch:** C (may be skipped)

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
> **Batch:** D

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
> **Batch:** D

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

| Card | Person | Data Source | Batch |
|------|--------|-------------|:-----:|
| Features Fully Scoped | Arbind | Asana | A |
| BizSup Completed | Mateus | Asana | A |
| PRDs Generated | Anderson | Asana / Notion | A / C |
| FSDs Generated | Anderson | Asana / Notion | A / C |
| Feature Releases | Lucas | GitHub | B |
| Sprint Velocity | Team | Asana | A |
| Bug Count (Open) | Team | GitHub | B |
| Deploy Frequency | Team | GitHub | B |
| Incidents (MTD) | Team | Manual/PagerDuty | -- |
| Tech Debt Tickets | Team | Asana/GitHub | A |

---

## Dependencies on Other Phases

| Dependency | Phase | Impact |
|------------|:-----:|--------|
| Dashboard framework running | 1 | Engineering tab must exist |
| Engineering PRIMARY metrics defined | 1 | Targets and owners confirmed; Phase 1 uses placeholder/manual entry |
| API integration pattern | 4 | Reuse integration architecture from Phase 4 |
| HubSpot deep integration | 4 | Email stats may piggyback on Phase 4 HubSpot work |

---

## Acceptance Criteria

Phase 5 is **done** when:

- [ ] Arbind's "Features Fully Scoped" metric displays live Asana data
- [ ] Mateus's "BizSup Completed" metric displays live Asana data
- [ ] Anderson's "PRDs Generated" and "FSDs Generated" display live data
- [ ] Lucas's "Feature Releases" metric displays live GitHub data
- [ ] Team metrics (Sprint Velocity, Bug Count, Deploy Frequency, Tech Debt Tickets) are live
- [ ] Marketing website traffic from GA4 displays on Marketing tab
- [ ] Marketing email open rate displays on Marketing tab
- [ ] All integrations have error handling and fallback displays
- [ ] All API credentials stored securely in environment variables
- [ ] Daily refresh schedule includes all new API calls
- [ ] Engineering tab respects role-based access control
- [ ] Phase 1 placeholder/manual entry for Engineering PRIMARY metrics is replaced with live data

---

## Estimated Integration Count

| Integration | Batch | API Calls/Day | New Queries | Display Cards |
|-------------|:-----:|:------------:|:-----------:|:-------------:|
| Asana | A | 5-10 | 6 | 6 |
| GitHub | B | 3-5 | 3 | 3 |
| Notion | C | 2-3 | 2 | 2 (may merge with Asana) |
| GA4 | D | 1-2 | 2 | 2 |
| HubSpot Email | D | 1 | 1 | 1 |
| **Phase 5 Total** | | **~15** | **~14** | **~14** |

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

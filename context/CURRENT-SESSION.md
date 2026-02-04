# Session Handoff - 2026-02-03 13:35

## 🎯 MISSION
Fix and validate Phase 1 Company Health metrics in the KPI Dashboard, ensuring all metrics pull live data from BigQuery with correct calculations and display 2025 reference values for context.

## 📍 CURRENT STATE
- **Phase:** Phase 1 Company Health Metrics - 5 of 7 metrics live in UI
- **Active Feature:** BigQuery data connection
- **Baseline:** HEALTHY - Dashboard running at localhost:8501, BigQuery queries working

## 🧠 KEY DECISIONS
- **Revenue = Net Revenue (not GMV):** Formula is GMV - Credit Memos - Payouts + Vendor Credits = $3.89M (2025)
- **NRR key fixed:** Changed `bq_metrics.get("nrr")` → `bq_metrics.get("demand_nrr")` to match BigQuery return
- **Take Rate replaces Gross Margin:** Renamed throughout UI, targets, and settings
- **2025 reference values:** Added as sub-labels to all Company Health cards
- **Pipeline card enhanced:** Now shows Q1 Goal, Closed, and Surplus/Gap

## 📋 TODO (Top 5, Prioritized)
- [ ] **HIGH:** Add Supply NRR card to Company Health section (function exists: `get_supply_nrr()`)
- [ ] **HIGH:** Add Time to Fulfill card to Company Health section (function exists: `get_time_to_fulfill()`)
- [ ] **MED:** Verify all cards display correctly after dashboard restart (user needs to refresh browser)
- [ ] **MED:** Update Team Accountability section to use live BigQuery data for person metrics
- [ ] **LOW:** Create Sellable Inventory query (blocked - needs PRD to define "sellable" criteria)

## 🧵 SCOPE NOTES
- Original ask: Orient to project and show full status of metrics
- Current scope: Fixing Phase 1 metrics one-by-one until all are live and correct

## 📎 REFERENCES
- **Implementation Tracker:** `docs/METRIC-IMPLEMENTATION-TRACKER.md` ← Master status of all metrics
- **Design doc:** `docs/plans/2026-02-03-bigquery-data-connection-design.md`
- **BigQuery client:** `dashboard/data/bigquery_client.py`
- **Detailed work log:** `context/PROGRESS.md`
- **Gotchas & learnings:** `context/LEARNINGS.md`
- **Feature status:** `context/features.json`

## 🔧 ENVIRONMENT
- **Credentials:** `GOOGLE_APPLICATION_CREDENTIALS="/Users/deucethevenowworkm1/.config/bigquery-mcp-key.json"`
- **Dashboard:** `cd dashboard && source venv/bin/activate && streamlit run app.py`
- **BigQuery Project:** `stitchdata-384118`
- **Dataset:** `App_KPI_Dashboard`

## 📊 PHASE 1 TRACKER SNAPSHOT

| # | Metric | Owner | 2026 Value | 2025 Value | In UI | Status |
|---|--------|-------|------------|------------|:-----:|--------|
| 1 | Revenue YTD | Jack | -$70K | $3.89M | ✅ | 🟢 Live |
| 2 | Take Rate % | Deuce | 49% | 49% | ✅ | 🟢 Live |
| 3 | Demand NRR | Andy | 0.15% | 22% | ✅ | 🟢 Fixed |
| 4 | Supply NRR | Ashton | 2.7% | 67% | ❌ | 🟡 Needs UI |
| 5 | Pipeline Coverage | Andy | 3.26x | — | ✅ | 🟢 Live |
| 6 | Sellable Inventory | ? | — | — | ❌ | 🔴 Needs PRD |
| 7 | Time to Fulfill | Victoria | 14 days | 14 days | ❌ | 🟡 Needs UI |

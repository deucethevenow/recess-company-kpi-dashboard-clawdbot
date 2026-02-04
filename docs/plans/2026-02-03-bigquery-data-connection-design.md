# BigQuery Data Connection Design

> **Status:** Draft
> **Created:** 2026-02-03
> **Decision:** Option E (Scheduled Materialization) with Two-Tier Architecture

---

## 1. Overview

### Goal
Remove all hardcoded values from `mock_data.py` and connect the Streamlit dashboard to live BigQuery data, with a daily scheduled refresh at midnight.

### Architecture Summary

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TWO-TIER DATA ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   TIER 1: Summary Table (fast reads for Overview page)                       │
│   ─────────────────────────────────────────────────────                      │
│   App_KPI_Dashboard.dashboard_kpis                                           │
│   • Single table with all KPI metrics as rows                                │
│   • Refreshed daily at midnight via Cloud Scheduler                          │
│   • Streamlit reads this for company health cards                            │
│                                                                              │
│   TIER 2: Detail Views (drill-down pages)                                    │
│   ─────────────────────────────────────────                                  │
│   Existing views (already deployed):                                         │
│   • net_revenue_retention_all_customers                                      │
│   • cohort_retention_matrix_by_customer                                      │
│   • customer_development                                                     │
│   • Upfront_Contract_Spend_Query                                             │
│   • Days_to_Fulfill_Contract_Program                                         │
│   • organizer_recap_NPS_score                                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Build Sequence

| Phase | What | Why |
|-------|------|-----|
| **Phase 1** | Create BigQuery client + connect to existing views | See real data immediately, validate queries |
| **Phase 2** | Create `dashboard_kpis` table + scheduled refresh | Optimization layer once queries are proven |

---

## 2. Data Model

### 2.1 Summary Table Schema

```sql
CREATE TABLE IF NOT EXISTS `stitchdata-384118.App_KPI_Dashboard.dashboard_kpis` (
  metric_key STRING NOT NULL,           -- e.g., "revenue_ytd", "nrr", "gross_margin"
  metric_value FLOAT64,                 -- The actual numeric value
  metric_format STRING,                 -- "currency", "percent", "number", "multiplier"
  department STRING,                    -- "company", "ceo", "coo", "supply", etc.
  person_name STRING,                   -- NULL for company metrics, name for individual
  fiscal_year INT64 NOT NULL,           -- 2026
  updated_at TIMESTAMP NOT NULL         -- When this row was last refreshed
)
PARTITION BY DATE(updated_at)
CLUSTER BY department, metric_key;
```

### 2.2 Metric Key Mapping

| UI Metric | metric_key | Source | Formula |
|-----------|------------|--------|---------|
| Revenue YTD | `revenue_ytd` | QuickBooks invoice_line | Sum of account 4000-4190 |
| **Take Rate %** | `take_rate` | QuickBooks | (4000 Services Revenue) / (4100 GMV) |
| Net Revenue Retention | `nrr` | `net_revenue_retention_all_customers` | 2026 revenue / 2025 revenue |
| Pipeline Coverage | `pipeline_coverage` | HubSpot deals (Fivetran) | Weighted pipeline / quota |
| Logo Retention | `logo_retention` | `customer_development` | Retained / Total at period start |
| Customer Count | `customer_count` | `customer_development` | Count of active customers |

### 2.3 Individual KPIs (Person-Level)

| Person | metric_key | Source View |
|--------|------------|-------------|
| Jack | `person_revenue_ytd` | QuickBooks |
| Deuce | `person_take_rate` | QuickBooks (4000/4100) |
| Ian Hong | `person_new_inventory` | Supply pipeline |
| Andy Cooper | `person_nrr` | `net_revenue_retention_all_customers` |
| Char Short | `person_contract_spend` | `Upfront_Contract_Spend_Query` |
| Victoria | `person_time_to_fulfill` | `Days_to_Fulfill_Contract_Program` |
| Claire | `person_nps` | `organizer_recap_NPS_score` |

---

## 3. Components

### 3.1 New Files to Create

```
dashboard/
├── data/
│   ├── bigquery_client.py      # NEW: BigQuery connection + query methods
│   ├── mock_data.py            # MODIFY: Fallback only, reads from BQ first
│   ├── queries/                # NEW: SQL query files for dashboard
│   │   ├── company_metrics.sql
│   │   ├── person_metrics.sql
│   │   └── refresh_kpis.sql    # The scheduled job query
│   └── targets_manager.py      # KEEP: Targets stay in JSON (editable via UI)
```

### 3.2 BigQuery Client Module

```python
# dashboard/data/bigquery_client.py

from google.cloud import bigquery
from functools import lru_cache
import os

PROJECT_ID = "stitchdata-384118"
DATASET = "App_KPI_Dashboard"

def get_client():
    """Get authenticated BigQuery client."""
    # Uses GOOGLE_APPLICATION_CREDENTIALS env var
    return bigquery.Client(project=PROJECT_ID)

@lru_cache(maxsize=1)
def get_company_metrics(fiscal_year: int = 2026) -> dict:
    """Fetch company-level KPIs from dashboard_kpis table."""
    query = f"""
    SELECT metric_key, metric_value, metric_format
    FROM `{PROJECT_ID}.{DATASET}.dashboard_kpis`
    WHERE department = 'company'
      AND fiscal_year = {fiscal_year}
      AND person_name IS NULL
    """
    client = get_client()
    results = client.query(query).to_dataframe()
    return {row.metric_key: row.metric_value for _, row in results.iterrows()}

def get_person_metrics(fiscal_year: int = 2026) -> list[dict]:
    """Fetch person-level KPIs from dashboard_kpis table."""
    query = f"""
    SELECT metric_key, metric_value, metric_format, person_name, department
    FROM `{PROJECT_ID}.{DATASET}.dashboard_kpis`
    WHERE person_name IS NOT NULL
      AND fiscal_year = {fiscal_year}
    """
    client = get_client()
    return client.query(query).to_dataframe().to_dict('records')

def get_nrr_detail() -> list[dict]:
    """Fetch detailed NRR by customer (Tier 2 - drill-down)."""
    query = f"""
    SELECT *
    FROM `{PROJECT_ID}.{DATASET}.net_revenue_retention_all_customers`
    WHERE qbo_customer_id != 'UNKNOWN'
    ORDER BY net_revenue_2026 DESC
    """
    client = get_client()
    return client.query(query).to_dataframe().to_dict('records')
```

### 3.3 Data Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            DATA FLOW                                      │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│   NIGHTLY REFRESH (Cloud Scheduler @ midnight)                            │
│   ──────────────────────────────────────────────                          │
│                                                                           │
│   Source Tables              Scheduled Query           Summary Table      │
│   ┌─────────────┐                                     ┌─────────────┐    │
│   │ QuickBooks  │───┐                                 │             │    │
│   │ (invoices)  │   │      ┌───────────────┐         │ dashboard_  │    │
│   └─────────────┘   │      │               │         │ kpis        │    │
│   ┌─────────────┐   ├─────▶│ refresh_kpis  │────────▶│             │    │
│   │ HubSpot     │   │      │ .sql          │         │ (12 rows)   │    │
│   │ (deals)     │───┤      │               │         │             │    │
│   └─────────────┘   │      └───────────────┘         └─────────────┘    │
│   ┌─────────────┐   │                                       │            │
│   │ Existing    │───┘                                       │            │
│   │ Views       │                                           ▼            │
│   └─────────────┘                                   ┌─────────────┐      │
│                                                     │  Streamlit  │      │
│   RUNTIME (on page load)                            │  Dashboard  │      │
│   ──────────────────────                            └─────────────┘      │
│                                                           │              │
│   Detail Views ◄──────────────────────────────────────────┘              │
│   (Tier 2 - only when user clicks drill-down)                            │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Scheduled Query (Cloud Scheduler)

### 4.1 Schedule Configuration

| Setting | Value |
|---------|-------|
| Frequency | Daily at 00:00 PST (midnight Pacific) |
| Query Location | US (same as dataset) |
| Destination Table | `App_KPI_Dashboard.dashboard_kpis` |
| Write Preference | WRITE_TRUNCATE (replace all) |
| Cron Expression | `0 8 * * *` (08:00 UTC = 00:00 PST) |

### 4.2 Refresh Query Structure

```sql
-- File: queries/scheduled/refresh_dashboard_kpis.sql
-- This runs nightly to populate the dashboard_kpis table

-- Company-level metrics
SELECT
  'revenue_ytd' as metric_key,
  SUM(il.amount) as metric_value,
  'currency' as metric_format,
  'company' as department,
  CAST(NULL AS STRING) as person_name,
  2026 as fiscal_year,
  CURRENT_TIMESTAMP() as updated_at
FROM `stitchdata-384118.src_fivetran_qbo.invoice_line` il
-- ... joins and filters

UNION ALL

-- NRR (from existing view)
SELECT
  'nrr' as metric_key,
  SAFE_DIVIDE(SUM(net_revenue_2026), SUM(net_revenue_2025)) as metric_value,
  'percent' as metric_format,
  'company' as department,
  NULL as person_name,
  2026 as fiscal_year,
  CURRENT_TIMESTAMP() as updated_at
FROM `stitchdata-384118.App_KPI_Dashboard.net_revenue_retention_all_customers`
WHERE qbo_customer_id != 'UNKNOWN' AND net_revenue_2025 > 0

UNION ALL
-- ... additional metrics follow same pattern
```

---

## 5. Error Handling & Fallbacks

### 5.1 Graceful Degradation

```python
# In bigquery_client.py

def get_company_metrics_safe(fiscal_year: int = 2026) -> dict:
    """Fetch metrics with fallback to mock data."""
    try:
        return get_company_metrics(fiscal_year)
    except Exception as e:
        logger.warning(f"BigQuery unavailable, using mock data: {e}")
        from .mock_data import get_company_metrics as get_mock
        return get_mock()
```

### 5.2 Monitoring

| Check | Alert Threshold |
|-------|-----------------|
| Scheduled query fails | Immediate (via Cloud Monitoring) |
| `dashboard_kpis` not updated in 25 hours | Warning |
| BigQuery client connection errors | After 3 consecutive failures |

---

## 6. Implementation Plan

### Phase 1: Direct Connection (This Session)

| Task | Files | Estimate |
|------|-------|----------|
| 1.1 Create `bigquery_client.py` | `dashboard/data/bigquery_client.py` | 15 min |
| 1.2 Create SQL query files | `dashboard/data/queries/*.sql` | 30 min |
| 1.3 Modify `mock_data.py` to use BQ | `dashboard/data/mock_data.py` | 20 min |
| 1.4 Test with existing views | Manual testing | 15 min |

### Phase 2: Scheduled Refresh (Next Session)

| Task | Files | Estimate |
|------|-------|----------|
| 2.1 Create `dashboard_kpis` table in BigQuery | BigQuery Console | 5 min |
| 2.2 Write full `refresh_kpis.sql` | `queries/scheduled/refresh_dashboard_kpis.sql` | 45 min |
| 2.3 Set up Cloud Scheduler | GCP Console | 10 min |
| 2.4 Update client to read from summary table | `bigquery_client.py` | 10 min |
| 2.5 Test end-to-end | Manual testing | 15 min |

---

## 7. Resolved Questions

- [x] **HubSpot Pipeline**: Yes - available in BigQuery via Fivetran (`src_fivetran_hubspot.*`)
- [x] **Take Rate (not Gross Margin)**: Changed metric from Gross Margin to Take Rate
  - Formula: `(4000 Services Revenue - Events) / (4100 01 - Marketplace Revenue GMV)`
  - This measures platform take rate as a % of GMV
- [x] **Timezone**: PST (Pacific Standard Time) - midnight refresh at 00:00 PST

---


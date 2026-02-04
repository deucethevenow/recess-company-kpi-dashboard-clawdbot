# SQL Queries

This folder contains all SQL queries for the KPI Dashboard.

## Folder Structure

```
sql/
├── views/          # BigQuery VIEW definitions (deployed to App_KPI_Dashboard)
└── reports/        # Ad-hoc report queries and analysis
```

## Views (Deployed to BigQuery)

| View | Dataset | Description |
|------|---------|-------------|
| `net_revenue_retention_all_customers` | App_KPI_Dashboard | Customer NRR with UNKNOWN bucket |
| `cohort_retention_matrix_by_customer` | App_KPI_Dashboard | Net revenue cohort matrix |
| `gross_gmv_retention_cohort` | App_KPI_Dashboard | Gross GMV cohort matrix |
| `pipeline_coverage_historical` | App_KPI_Dashboard | Historical pipeline coverage analysis |

## Deploying Views

Use the `bq` CLI to deploy views:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="~/.config/bigquery-mcp-key.json"
bq mk --use_legacy_sql=false --project_id=stitchdata-384118 --view "$(cat sql/views/your_view.sql)" --force App_KPI_Dashboard.view_name
```

## Reports

Ad-hoc queries for analysis. Not deployed as views.

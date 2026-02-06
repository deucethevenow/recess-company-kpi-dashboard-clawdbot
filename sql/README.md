# SQL Queries

This folder contains all SQL queries for the KPI Dashboard.

## Folder Structure

```
sql/
├── views/          # BigQuery VIEW definitions (deployed to App_KPI_Dashboard)
└── reports/        # Ad-hoc report queries and analysis
```

## Views (Deployed to BigQuery)

### Demand (Customer) Views
| View | Dataset | Description |
|------|---------|-------------|
| `net_revenue_retention_all_customers` | App_KPI_Dashboard | Customer NRR with UNKNOWN bucket |
| `cohort_retention_matrix_by_customer` | App_KPI_Dashboard | Net revenue cohort matrix |
| `gross_gmv_retention_cohort` | App_KPI_Dashboard | Gross GMV cohort matrix |
| `pipeline_coverage_historical` | App_KPI_Dashboard | Historical pipeline coverage analysis |

### Supply (Supplier) Views
| View | Dataset | Description |
|------|---------|-------------|
| `Supplier_Development` | App_KPI_Dashboard | Supplier NPR with Core Action State (active/loosing/lost) |
| `cohort_payout_retention_matrix_by_supplier` | App_KPI_Dashboard | Supplier payout cohort matrix |

## Deploying Views

Use the `bq` CLI to deploy views:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="~/.config/bigquery-mcp-key.json"

# For views without comment headers:
bq mk --use_legacy_sql=false --project_id=stitchdata-384118 \
  --view "$(cat sql/views/your_view.sql)" \
  --force App_KPI_Dashboard.view_name

# For views with comment headers (skip first N lines, remove trailing semicolon):
bq mk --use_legacy_sql=false --project_id=stitchdata-384118 \
  --view "$(sed -n '28,$p' sql/views/supplier-development.sql | sed 's/;$//')" \
  --force App_KPI_Dashboard.Supplier_Development
```

**Note:** Views with `/* ... */` comment blocks at the top need `sed -n 'N,$p'` to skip the header lines.

## Reports

Ad-hoc queries for analysis. Not deployed as views.

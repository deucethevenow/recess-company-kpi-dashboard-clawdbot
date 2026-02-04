# Recess KPI Dashboard

A real-time executive KPI dashboard for Recess, built with Streamlit and BigQuery.

## Features

- **Live BigQuery Integration** - Real-time data from your data warehouse
- **Company Health Metrics** - 8 key metrics with 2025 reference values
- **Team Accountability** - Individual performance tracking by department
- **Data Source Indicators** - Visual confirmation of live vs. mock data on each card
- **Responsive Design** - Works on desktop and mobile
- **60-Second Cache** - Fast page loads with fresh data

## Quick Start

```bash
# Navigate to dashboard directory
cd dashboard

# Start the dashboard (sets credentials automatically)
./start.sh
```

Dashboard will be available at **http://localhost:8501**

## Prerequisites

- Python 3.9+
- Google Cloud credentials with BigQuery access
- BigQuery dataset: `stitchdata-384118.App_KPI_Dashboard`

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/company-kpi-dashboard.git
   cd company-kpi-dashboard
   ```

2. **Set up Python environment**
   ```bash
   cd dashboard
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Configure BigQuery credentials**
   ```bash
   # Set the path to your service account key
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/bigquery-key.json"
   ```

4. **Run the dashboard**
   ```bash
   streamlit run app.py --server.port 8501
   ```

## Project Structure

```
company-kpi-dashboard/
├── dashboard/                 # Streamlit application
│   ├── app.py                # Main dashboard application
│   ├── start.sh              # Startup script with credentials
│   ├── requirements.txt      # Python dependencies
│   └── data/
│       ├── bigquery_client.py    # BigQuery queries
│       ├── mock_data.py          # Data layer with caching
│       ├── targets_manager.py    # Target configuration
│       └── targets.json          # Editable targets
├── docs/
│   ├── METRIC-IMPLEMENTATION-TRACKER.md   # Metric status tracker
│   └── plans/                             # Implementation plans
├── context/                   # Session management
├── queries/                   # SQL query files
└── README.md
```

## Company Health Metrics

| # | Metric | Owner | Data Source | Status |
|---|--------|-------|-------------|--------|
| 1 | Revenue YTD | Jack | QuickBooks → BigQuery | ✅ Live |
| 2 | Take Rate % | Deuce | QuickBooks → BigQuery | ✅ Live |
| 3 | Demand NRR | Andy | BigQuery cohort analysis | ✅ Live |
| 4 | Supply NRR | Ashton | BigQuery supplier metrics | ✅ Live |
| 5 | Pipeline Coverage | Andy | HubSpot → BigQuery | ✅ Live |
| 6 | Time to Fulfill | Victoria | BigQuery contract data | ✅ Live |
| 7 | Logo Retention | TBD | BigQuery customer data | ✅ Live |
| 8 | Customer Count | TBD | BigQuery customer data | ✅ Live |
| 9 | Sellable Inventory | Ian | — | 🟡 Needs PRD |

## Configuration

### Targets

Edit `dashboard/data/targets.json` to update company and individual targets:

```json
{
  "company": {
    "revenue_target": 10000000,
    "take_rate_target": 0.51,
    "nrr_target": 1.10,
    "pipeline_target": 3.0
  }
}
```

Or use the **Settings** page in the dashboard UI.

### BigQuery Views

The dashboard queries these BigQuery views in `App_KPI_Dashboard`:

| View | Purpose |
|------|---------|
| `cohort_retention_matrix_by_customer` | Demand NRR calculation |
| `Supplier_Metrics` | Supply NRR, take rate |
| `customer_development` | Customer count, logo retention |
| `Days_to_Fulfill_Contract_Program` | Time to fulfill |
| `net_revenue_retention_all_customers` | Customer concentration |
| HubSpot tables (`src_fivetran_hubspot.*`) | Pipeline coverage |
| QuickBooks tables (`src_fivetran_qbo.*`) | Revenue, invoices |

## Development

### Adding a New Metric

1. **Create BigQuery view** in `App_KPI_Dashboard` dataset
2. **Add Python function** in `dashboard/data/bigquery_client.py`
3. **Wire to mock_data.py** - add to `get_company_metrics()` and `METRIC_VERIFICATION`
4. **Add to UI** in `app.py` → `render_health_metrics()`
5. **Update tracker** in `docs/METRIC-IMPLEMENTATION-TRACKER.md`

### Data Caching

- **Targets**: 5-second cache (quick updates via Settings)
- **BigQuery data**: 60-second cache (reduces API calls)

To force a refresh, restart the Streamlit server.

## Troubleshooting

### "Mock Data" indicator showing

The `GOOGLE_APPLICATION_CREDENTIALS` environment variable is not set. Use `./start.sh` or:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"
streamlit run app.py
```

### Slow page loads

First load fetches from BigQuery (~5-10s). Subsequent loads use cache.

### Metrics showing wrong values

Check `docs/METRIC-IMPLEMENTATION-TRACKER.md` for expected values and verify BigQuery views are returning correct data.

## Tech Stack

- **Frontend**: Streamlit with custom CSS (Recess brand)
- **Backend**: Python 3.9+
- **Data**: Google BigQuery
- **Data Sources**: QuickBooks (via Fivetran), HubSpot (via Fivetran)

## License

Proprietary - Recess Inc.

## Contributors

- Dashboard built with Claude Code
- Data engineering by Recess team

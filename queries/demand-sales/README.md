# Demand Sales Queries

> **Owner:** Andy Cooper (Sales Leader), Danny Sears, Katie
> **HubSpot Dashboards:**
> - [Sales Pipeline Dashboard](https://app.hubspot.com/reports-dashboard/6699636/view/3551608)
> - [Sales Activity Dashboard](https://app.hubspot.com/reports-dashboard/6699636/view/16787401)

## Query Index

| Query File | Metric | Target | Refresh |
|------------|--------|--------|---------|
| `pipeline-coverage-by-rep.sql` | Pipeline Coverage | 6.0x | Daily |
| `win-rate-90-days.sql` | Win Rate (90 days) | 30% | Daily |
| `avg-deal-size-ytd.sql` | Avg Deal Size | $150K | Daily |
| `sales-cycle-length.sql` | Sales Cycle Length | ≤60 days | Daily |
| `deals-by-stage-funnel.sql` | Deals by Stage | See funnel targets | Daily |
| `deals-closing-soon.sql` | Deals Closing This Week/Month | - | Daily |
| `expired-open-deals.sql` | Expired Open Deals | 0 | Daily |
| `companies-not-contacted-7d.sql` | Deals >7 Days Not Contacted | 0 | Daily |
| `meetings-booked-qtd.sql` | Meetings Booked (QTD) | 45/month | Daily |

## Monthly Funnel Targets

| Stage | Monthly Target |
|-------|----------------|
| Meeting Booked | 45 |
| Sales Qualified Lead | 36 |
| Opportunity | 23 |
| Proposal Sent | 22 |
| Active Negotiation | 15 |
| Contract Sent | 9 |
| Closed Won | 7 deals / $500K |

## Data Sources

All queries use BigQuery tables synced from HubSpot via Fivetran:

| Table | Purpose |
|-------|---------|
| `src_fivetran_hubspot.deal` | Deal records, amounts, stages, close dates |
| `src_fivetran_hubspot.deal_pipeline_stage` | Stage names and probabilities |
| `src_fivetran_hubspot.owner` | Sales rep info |
| `src_fivetran_hubspot.engagement` | Activities (calls, meetings, emails) |
| `src_fivetran_hubspot.company` | Company records |

## Key Fields Used

| Field | Description |
|-------|-------------|
| `property_amount` | Deal amount (unweighted) |
| `property_hs_forecast_amount` | Sales rep weighted amount (confidence) |
| `property_closedate` | Expected close date |
| `property_dealstage` | Current pipeline stage |
| `property_hs_is_closed` | Whether deal is closed |
| `property_hs_is_closed_won` | Whether deal was won (vs lost) |
| `deal_pipeline_id` | Pipeline ID ('default' = Purchase Manual) |

## Status Indicators

| Color | Pipeline Coverage | Win Rate | Cycle Length |
|-------|------------------|----------|--------------|
| 🟢 GREEN | ≥ 6.0x | ≥ 30% | ≤ 60 days |
| 🟡 YELLOW | 4.0x - 6.0x | 20% - 30% | 60 - 90 days |
| 🔴 RED | < 4.0x | < 20% | > 90 days |

## Notes

1. **Pipeline Coverage Target:** Based on historical analysis showing 17.5% win rate, 6x coverage is needed (not the industry standard 3x)

2. **Weighting Method:** Uses `hs_forecast_amount` (sales rep confidence) not stage probability

3. **Pipeline Filter:** Only includes "Purchase (Manual)" pipeline (`deal_pipeline_id = 'default'`)

4. **Quotas:** Currently hardcoded in queries - TODO: pull from HubSpot company properties

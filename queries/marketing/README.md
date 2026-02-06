# Marketing Queries

> **Owner:** Marketing Team
> **Primary Metric:** Marketing-Influenced Pipeline
> **HubSpot Dashboard:** [Marketing Dashboard](https://app.hubspot.com/reports-dashboard/6699636/view/18337876)

## Attribution Model

Marketing uses a **50/50 First Touch + Last Touch attribution model:**

```
Attribution Credit = (First Touch + Last Touch) / 2

Where:
- First Touch (FT): How the lead originally found us
- Last Touch (LT): Final interaction before deal creation
```

## Marketing Channels (10 Total)

| Channel | Description |
|---------|-------------|
| `DIRECT_TRAFFIC` | Direct website visits |
| `PAID_SEARCH` | Google Ads, Bing Ads |
| `PAID_SOCIAL` | LinkedIn, Meta, Twitter ads |
| `ORGANIC_SOCIAL` | Organic social media |
| `ORGANIC_SEARCH` | SEO traffic |
| `EVENT` | Trade shows, webinars |
| `EMAIL_MARKETING` | Email campaigns |
| `OTHER_CAMPAIGNS` | Other marketing campaigns |
| `REFERRALS` | Partner referrals |
| `GENERAL_REFERRAL` | General referrals |

## Query Index

| Query File | Metric | Target | Status |
|------------|--------|--------|--------|
| `marketing-influenced-pipeline.sql` | Marketing-Influenced Pipeline | TBD | ✅ Created |
| `mql-to-sql-conversion.sql` | MQL → SQL Conversion Rate | 30% | ✅ Created |
| `attribution-by-channel.sql` | First/Last Touch Attribution $ | - | ✅ Created |
| `marketing-leads-funnel.sql` | ML → MQL → SQL Funnel | - | ✅ Created |

## HubSpot Properties Used

| Property | Description |
|----------|-------------|
| `property_hs_analytics_first_touch_converting_campaign` | First touch campaign |
| `property_hs_analytics_last_touch_converting_campaign` | Last touch campaign |
| `property_hs_analytics_source` | Traffic source |
| `property_hs_analytics_source_data_1` | Source detail 1 |
| `property_hs_analytics_source_data_2` | Source detail 2 |
| `property_lifecyclestage` | Lead lifecycle stage |
| `property_hs_lead_status` | Lead status |
| `property_became_marketing_qualified_lead_date` | MQL date |
| `property_became_sales_qualified_lead_date` | SQL date |

## Data Sources

| Source | Tables | Status |
|--------|--------|--------|
| HubSpot (via BigQuery) | `contact`, `deal` | ✅ Available |
| HubSpot Multi-Touch | `attribution_touch`, `attribution_campaign` | 🔍 Verify schema |
| GA4 | Website traffic | ⛔ Integration needed |

## Status Indicators

| Metric | 🟢 GREEN | 🟡 YELLOW | 🔴 RED |
|--------|----------|----------|--------|
| MQL → SQL Rate | ≥ 30% | 20-30% | < 20% |
| Marketing Pipeline | ≥ 100% of target | 75-100% | < 75% |

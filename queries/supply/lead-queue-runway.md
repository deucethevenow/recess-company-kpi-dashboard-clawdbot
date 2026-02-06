# Lead Queue Runway (Requires Smart Lead API)

> **Owner:** Ian Hong (Supply)
> **Target:** 30 days of runway
> **Status:** ⛔ BLOCKED - Requires Smart Lead API integration

## Overview

This metric cannot be calculated via BigQuery alone. It requires direct API access to Smart Lead to get:

1. **Leads actively sequencing** - Currently being sent emails
2. **Leads enrolled but not yet sequencing** - In queue, waiting to start
3. **Leads staged for next sequence** - Ready to be enrolled
4. **Send capacity** - ~600 emails/day

## Calculation

```
Lead Queue Runway = Total Leads in Queue / Avg Leads Contacted Per Day

Where:
- Total Leads in Queue = (actively sequencing) + (enrolled not sequencing) + (staged)
- Avg Leads Contacted Per Day = ~120 (based on 600 emails/day, 5 days/week)
```

## Traffic Light Thresholds

| Status | Runway |
|--------|--------|
| 🟢 GREEN | ≥ 30 days |
| 🟡 YELLOW | 15-30 days |
| 🔴 RED | < 15 days |

## Integration Requirements

### Smart Lead API

- **API Documentation:** [Smart Lead API Docs](https://help.smartlead.ai/api)
- **Required Endpoints:**
  - GET /campaigns - List active campaigns
  - GET /campaigns/{id}/leads - Get leads in each campaign
  - GET /leads/stats - Get sending statistics

### Implementation Options

1. **Direct API Integration**
   - Build Python function to call Smart Lead API
   - Cache results in BigQuery for dashboard queries

2. **Zapier/n8n Integration**
   - Set up scheduled sync from Smart Lead to Google Sheets
   - Query Google Sheets from dashboard

3. **Fivetran Connector**
   - Check if Fivetran has Smart Lead connector
   - Would sync directly to BigQuery

## Sample Python Code (Placeholder)

```python
import requests

SMARTLEAD_API_KEY = "your_api_key"
BASE_URL = "https://api.smartlead.ai/v1"

def get_lead_queue_runway():
    """Calculate lead queue runway from Smart Lead API."""

    headers = {"Authorization": f"Bearer {SMARTLEAD_API_KEY}"}

    # Get all campaigns
    campaigns = requests.get(f"{BASE_URL}/campaigns", headers=headers).json()

    total_leads_in_queue = 0
    for campaign in campaigns:
        leads = requests.get(
            f"{BASE_URL}/campaigns/{campaign['id']}/leads",
            headers=headers
        ).json()

        # Count leads by status
        actively_sequencing = len([l for l in leads if l['status'] == 'active'])
        enrolled_waiting = len([l for l in leads if l['status'] == 'enrolled'])
        staged = len([l for l in leads if l['status'] == 'staged'])

        total_leads_in_queue += (actively_sequencing + enrolled_waiting + staged)

    # Calculate runway
    avg_daily_contacts = 120  # Based on 600 emails/day, 5 days/week
    runway_days = total_leads_in_queue / avg_daily_contacts

    return {
        "total_leads_in_queue": total_leads_in_queue,
        "avg_daily_contacts": avg_daily_contacts,
        "runway_days": round(runway_days, 1),
        "status": "GREEN" if runway_days >= 30 else "YELLOW" if runway_days >= 15 else "RED"
    }
```

## Action Items

1. [ ] Get Smart Lead API credentials
2. [ ] Test API endpoints
3. [ ] Decide integration approach (direct API vs Zapier vs Fivetran)
4. [ ] Implement and deploy

# Cash Position (SimpleFin Integration)

> **Owner:** Deuce (COO), Jack (CEO)
> **Target:** >$500K
> **Status:** 🟡 READY TO INTEGRATE - SimpleFin client exists in `chief-of-staff` project

## Overview

Real-time bank balance data requires SimpleFin API integration. The client has already been built in the `chief-of-staff` project.

## Existing Implementation

**Location:** `/Users/deucethevenowworkm1/Projects/chief-of-staff/`

| File | Purpose |
|------|---------|
| `integrations/simplefin_client.py` | SimpleFin API client with `get_total_cash()` |
| `scripts/setup_simplefin.py` | Setup script for token claim and testing |

### Key Methods Available

```python
from integrations.simplefin_client import SimpleFINClient

client = SimpleFINClient()

# Get total cash across all accounts
result = await client.get_total_cash()
# Returns: {
#   "total_balance": 750000.00,
#   "total_available": 745000.00,
#   "account_count": 3,
#   "accounts": [...]
# }

# Get individual account balances
balances = await client.get_balances()
# Returns: [{
#   "account_name": "Chase Checking x3998",
#   "institution": "chase.com",
#   "balance": 674114.99,
#   "balance_date": "2026-01-29T10:00:00+00:00"
# }]

# Get Chase-specific balance
chase = await client.get_chase_balance()
```

## Setup Steps

1. **Get SimpleFin Account** ($1.50/month)
   - Sign up at https://beta-bridge.simplefin.org/
   - Connect your bank account(s)
   - Generate a Setup Token

2. **Claim the Token** (one-time)
   ```bash
   cd /Users/deucethevenowworkm1/Projects/chief-of-staff
   python scripts/setup_simplefin.py YOUR_SETUP_TOKEN
   ```

3. **Add to Environment**
   ```bash
   # Add to .env file:
   SIMPLEFIN_ACCESS_URL=https://username:password@beta-bridge.simplefin.org/simplefin
   ```

4. **Test Connection**
   ```bash
   python scripts/setup_simplefin.py --test
   ```

5. **Compare vs QBO** (verify reconciliation)
   ```bash
   python scripts/setup_simplefin.py --compare
   ```

## Integration Options for KPI Dashboard

### Option 1: Direct API Call (Recommended for Real-Time)

Add SimpleFin client to the dashboard app:

```python
# dashboard/data/simplefin_data.py
from chief_of_staff.integrations.simplefin_client import SimpleFINClient

async def get_cash_position():
    client = SimpleFINClient()
    result = await client.get_total_cash()

    return {
        "cash_position": result["total_balance"],
        "available_balance": result["total_available"],
        "account_count": result["account_count"],
        "as_of": result["fetched_at"],
        "status": (
            "GREEN" if result["total_balance"] >= 500000 else
            "YELLOW" if result["total_balance"] >= 250000 else
            "RED"
        )
    }
```

### Option 2: Sync to BigQuery (For Historical Tracking)

Create a scheduled job to sync balances to BigQuery:

```sql
-- Create table for cash position history
CREATE TABLE IF NOT EXISTS `stitchdata-384118.App_KPI_Dashboard.cash_position_daily` (
    snapshot_date DATE,
    account_id STRING,
    account_name STRING,
    institution STRING,
    balance FLOAT64,
    available_balance FLOAT64,
    balance_date TIMESTAMP,
    fetched_at TIMESTAMP
);

-- Query current cash position from synced data
SELECT
    'Cash Position' AS metric,
    SUM(balance) AS total_cash,
    SUM(available_balance) AS total_available,
    COUNT(DISTINCT account_id) AS account_count,
    MAX(fetched_at) AS as_of,
    CASE
        WHEN SUM(balance) >= 500000 THEN 'GREEN'
        WHEN SUM(balance) >= 250000 THEN 'YELLOW'
        ELSE 'RED'
    END AS status
FROM `stitchdata-384118.App_KPI_Dashboard.cash_position_daily`
WHERE snapshot_date = CURRENT_DATE();
```

### Option 3: QBO Fallback (Less Accurate)

If SimpleFin isn't available, use QBO book balance as approximation:

```sql
-- Approximate cash position from QBO (reconciliation balance, not real-time)
SELECT
    'Cash Position (QBO Book Balance)' AS metric,
    SUM(current_balance) AS cash_position,
    'YELLOW' AS data_quality  -- Mark as approximate
FROM `stitchdata-384118.src_fivetran_qbo.account`
WHERE _fivetran_deleted = FALSE
  AND active = TRUE
  AND account_type = 'Bank';
```

⚠️ **Warning:** QBO book balance may be days or weeks behind actual balance.

## Traffic Light Thresholds

| Status | Cash Position |
|--------|---------------|
| 🟢 GREEN | ≥ $500K |
| 🟡 YELLOW | $250K-$500K |
| 🔴 RED | < $250K |

## Comparison Feature

The setup script includes a `--compare` flag that shows:
- Actual bank balance (SimpleFin)
- QBO book balance
- Variance between them

This is useful for identifying:
- Unmatched transactions in QBO Banking
- Outstanding checks not yet cashed
- Deposits in transit

## Action Items

1. [x] Build SimpleFin client (done in chief-of-staff)
2. [x] Build setup script (done in chief-of-staff)
3. [ ] Set up SimpleFin account and connect bank
4. [ ] Run token claim and add to .env
5. [ ] Test connection
6. [ ] Decide: Direct API call vs BigQuery sync
7. [ ] Integrate into KPI dashboard

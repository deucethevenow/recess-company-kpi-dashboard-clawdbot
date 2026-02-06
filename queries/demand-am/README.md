# Demand AM Queries

Queries for Demand Account Management metrics (Char's team).

## Queries

| File | Metric | Owner | Target | Status |
|------|--------|-------|--------|--------|
| `offer-acceptance-rate.sql` | Offer Acceptance % | Francisco | 90% | ✅ Created |

## Data Sources

- **offers** (`mongodb.offers`) - Offer records with acceptance state
- **campaigns** (`mongodb.campaigns`) - Links offers to HubSpot deals
- **deal** (`src_fivetran_hubspot.deal`) - HubSpot deals
- **owner** (`src_fivetran_hubspot.owner`) - Deal owners (Account Managers)

## Join Path

```
offers → campaign_id → campaigns → deal_id → deals → owner_id → owner (AM)
```

## Key Findings (2025 YTD)

- **Company-Wide Acceptance Rate:** 58.2% (well below 90% target!)
- By AM:
  - Danny Sears: 58.0%
  - Char Short: 58.6%
  - Victoria Newton: 39.7%

## Offer States

| State | Included in Rate | Description |
|-------|------------------|-------------|
| `accepted` | ✅ Yes | Supplier accepted the offer |
| `denied` | ✅ Yes | Supplier explicitly declined |
| `ignored` | ✅ Yes | No response within window |
| `submitted` | ❌ No | Pending - still in flight |
| `voided` | ❌ No | Canceled by system |
| `canceled` | ❌ No | Canceled by user |
| `draft` | ❌ No | Not yet submitted |

## Usage

```sql
-- Main query shows acceptance rate by Account Manager
-- Uncomment COMPANY-WIDE AGGREGATE section for overall rate
-- Uncomment MONTHLY TREND section for trend analysis
```

# Supply AM Queries

Queries for Supply Account Management metrics (Ashton's team).

## Queries

| File | Metric | Owner | Target | Status |
|------|--------|-------|--------|--------|
| `nrr-top-supply-users.sql` | NRR Top Supply Users (Offer-Based) | Ashton | 110% | ✅ Created |
| `nrr-top-supply-users-financial.sql` | NRR Top Supply Users (Financial-Based) | Ashton | 110% | ✅ Created |

## Query Comparison

### `nrr-top-supply-users.sql` (Offer-Based)
- Uses `Supplier_Metrics` view (pre-aggregated)
- Timing based on **offer acceptance date**
- Simple and fast
- Does NOT include vendor credits (adjustments/refunds)

### `nrr-top-supply-users-financial.sql` (Financial-Based) ⭐ RECOMMENDED
- Uses QBO bills linked to MongoDB remittances via bill_number
- Timing based on **financial transaction date** (when money moved)
- Properly consolidates multi-vendor suppliers (e.g., WeWork's 200+ venues → 1 org)
- Includes vendor credits properly attributed via bill linkage
- More accurate for true financial NRR

## Data Sources

### Offer-Based Query
- **Supplier_Metrics** (`App_KPI_Dashboard.Supplier_Metrics`) - Aggregated supplier GMV, payouts, samples by year

### Financial-Based Query
- **bill** (`src_fivetran_qbo.bill`) - QBO bills with transaction dates
- **bill_line** (`src_fivetran_qbo.bill_line`) - Bill line items with account attribution
- **vendor_credit** (`src_fivetran_qbo.vendor_credit`) - Refunds/adjustments
- **vendor_credit_line** (`src_fivetran_qbo.vendor_credit_line`) - Credit line items
- **account** (`src_fivetran_qbo.account`) - Account definitions (filter to payout accounts)
- **remittance_line_items** (`mongodb.remittance_line_items`) - Links bill_number to supplier org

## Key Findings (2025)

### Offer-Based (from Supplier_Metrics)
- **Supply NRR 2025:** 99.9% (below 110% target)
- Top suppliers by LTV: Inspired Consumer, Tanger Outlets, Nautical Fulfillment
- 176 suppliers with >$10K lifetime GMV

### Bill # Linkage Quality (Financial Query)
| Year | QBO Bills | Linked to Platform | Linkage % |
|------|-----------|-------------------|-----------|
| 2026 | 39 | 39 | 100.0% |
| 2025 | 4,917 | 4,856 | 98.8% |
| 2024 | 4,351 | 3,537 | 81.3% |
| 2023 | 5,864 | 3,797 | 64.8% |

### QBO Payout Accounts Used
| Account # | Name |
|-----------|------|
| 4200 | Event Organizer Fee |
| 4210 | Sampling Payouts |
| 4220 | Sponsorship Payouts |
| 4230 | Activation Payouts |

## Join Paths

### Financial-Based Query (Recommended)
```
QBO bill (doc_number) → remittance_line_items (bill_number) → ctx.supplier.org.name
     ↓
QBO vendor_credit (doc_number minus suffix) → same linkage for credits
```

### Vendor Credit Patterns
Credits reference their parent bill with a suffix:
- `{bill_number}c1`, `{bill_number}c2` - Sequential credits
- `{bill_number}_credit` - Alternative suffix

## Usage

### Financial-Based (Recommended)
```sql
-- Run nrr-top-supply-users-financial.sql for accurate financial NRR
-- Uses bill transaction dates and includes vendor credits

-- For aggregate NRR, uncomment SUMMARY VIEW section
-- For linkage diagnostics, uncomment LINKAGE DIAGNOSTICS section
```

### Offer-Based (Simple)
```sql
-- Run nrr-top-supply-users.sql for quick offer-based view
-- Uses offer acceptance dates, does not include credits

-- For aggregate NRR, uncomment SUMMARY VIEW section
```

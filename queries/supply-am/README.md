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

**After Split Bill Fix (2026-02-05):**

| Year | QBO Bills | Linked | Linkage % | Improvement |
|------|-----------|--------|-----------|-------------|
| 2026 | 39 | 39 | **100.0%** | — |
| 2025 | 4,917 | 4,897 | **99.6%** | +0.8% |
| 2024 | 4,351 | 4,143 | **95.2%** | +17.9% |
| 2023 | 5,864 | 4,892 | **83.4%** | +18.6% |

**Split Bill Handling:** Bills with `_2`, `_3`, `_4` suffixes (e.g., `20250129-545719_2`) are now linked to their primary bill's supplier org using `REGEXP_REPLACE(doc_number, r'_\d+$', '')`.

### P&L Reconciliation (2025)

| Metric | Amount | Notes |
|--------|--------|-------|
| **QBO P&L Total (4200-4230)** | $4,045,628 | All payout account activity |
| **Linked to Platform** | $4,032,340 | 99.7% of $ linked |
| **Unlinked Bills (Gross)** | $53,268 | Before vendor credits |
| **Vendor Credits on Unlinked** | -$40,000 | ~85.8% credited to $0 |
| **TRUE GAP (Net)** | $1,080 | 0.03% of total |

**Why the match is so close:**
- Most "unlinked" bills were **canceled offers** that received vendor credits reducing them to $0
- These are non-events financially — no money actually changed hands
- Only 3 bills remain as true gaps (West Coast Farmers Market, $1,080)

### How Unlinked Bills Are Handled

**In the NRR Calculation:**
```sql
WHERE supplier_org_name != 'UNLINKED'  -- Excluded from NRR
```

**Why this is acceptable:**
1. **Canceled Offers (85.8%)**: Bills fully credited to $0 are non-events — the offer was voided
2. **Split Bills (now fixed)**: Previously unlinked `_2`, `_3` bills now link correctly
3. **True Gaps (<0.1%)**: Only $1,080 of $4M+ can't be attributed — immaterial variance

**Net Effect on NRR:**
- Unlinked bills are **excluded** from both numerator and denominator
- Since most unlinked have $0 net (bill = credit), excluding them doesn't skew NRR
- NRR calculation captures 99.97% of actual net payout dollars

### QBO Payout Accounts Used
| Account # | Name |
|-----------|------|
| 4200 | Event Organizer Fee |
| 4210 | Sampling Payouts |
| 4220 | Sponsorship Payouts |
| 4230 | Activation Payouts |

### Unlinked Bills Analysis

**Google Sheet with full details:** [Supply NRR Financial Analysis](https://docs.google.com/spreadsheets/d/1I2YtLhQnD4TMfLSo3xy9lV9bUAWSru29F_ZiAxdMyrI)

**Categories of Unlinked Bills:**

| Category | Count | Net $ | Status |
|----------|-------|-------|--------|
| Canceled Offers (credited to $0) | ~50 | $0 | ✅ Non-issue |
| Split Bills (_2, _3 suffix) | ~200 | Varies | ✅ Fixed |
| True Gaps (no remittance) | 3 | $1,080 | ⚠️ Investigate |

**Remaining True Gaps (2025):**
- `20251215-550901` - West Coast Farmers Market ($360)
- `20251215-550904` - West Coast Farmers Market ($360)
- `20251215-550905` - West Coast Farmers Market ($360)

These appear to be recent bills without corresponding remittances in MongoDB yet.

## Join Paths

### Financial-Based Query (Recommended)
```
QBO bill (doc_number) → remittance_line_items (bill_number) → ctx.supplier.org.name
     ↓
QBO vendor_credit (doc_number minus suffix) → same linkage for credits
```

### Split Bill Handling
```sql
-- Extract base bill number for linking
REGEXP_REPLACE(b.doc_number, r'_\d+$', '') as base_bill_number

-- Example: '20250129-545719_2' → '20250129-545719'
-- This links split bills back to the primary bill's supplier org
```

### Vendor Credit Patterns
Credits reference their parent bill with a suffix:
- `{bill_number}c1`, `{bill_number}c2` - Sequential credits
- `{bill_number}_credit` - Alternative suffix

## NRR Methodology

### Formula
```
Supply NRR = (Current Year Net Payouts to Prior Year Suppliers) / (Prior Year Net Payouts)

Where:
- Net Payouts = Bills - Vendor Credits (both in payout accounts 4200-4230)
- Prior Year Suppliers = Suppliers with net_revenue > 0 in prior year
- Timing = QBO transaction_date (when money moved)
```

### Why Financial-Based is More Accurate

| Aspect | Offer-Based | Financial-Based |
|--------|-------------|-----------------|
| **Timing** | Offer acceptance date | Bill transaction date |
| **Credits** | Not included | Properly subtracted |
| **Canceled offers** | Still counted | Zeroed out by credits |
| **Multi-venue suppliers** | By venue | By org (consolidated) |
| **P&L Match** | Approximate | 99.97% of net $ |

### P&L Reconciliation Formula
```
QBO P&L Payout Total = Σ(Bills in 4200-4230) - Σ(Vendor Credits in 4200-4230)

Financial Query Captures:
- Linked bills (attributed to supplier org)
- Linked credits (subtracted from supplier org)

Variance = Unlinked bills - Unlinked credits
         = TRUE GAP (bills with no remittance AND no credit)
```

**Current TRUE GAP: $1,080 / $4,045,628 = 0.03%**

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

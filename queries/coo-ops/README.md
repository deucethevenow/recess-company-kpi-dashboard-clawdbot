# COO/Ops/Finance Queries (Deuce)

> **Owner:** Deuce (COO)
> **Primary Metrics:** Take Rate %, Invoice Collection Rate
> **Shared With:** CEO/Biz Dev (Jack) - Cash, Runway, Working Capital

## Query Index

| Query File | Metric | Target | Status |
|------------|--------|--------|--------|
| `take-rate.sql` | Take Rate % | 45% | ✅ Created |
| `invoice-collection-rate.sql` | Invoice Collection Rate | 95% | ✅ Created |
| `overdue-invoices.sql` | Overdue Invoices Count & $ | 0 | ✅ Created |
| `working-capital.sql` | Working Capital | >$1M | ✅ Created |
| `months-of-runway.sql` | Months of Runway | >12 mo | ✅ Created |
| `top-customer-concentration.sql` | Top Customer % Revenue | <30% | ✅ Created |
| `net-revenue-gap.sql` | Net Revenue Gap | - | ✅ Created |
| `factoring-capacity.sql` | Available Factoring Capacity | >$400K | ✅ Created |
| `cash-position.md` | Cash Position | >$500K | ⛔ Needs SimpleFin API |

## Shared Metrics (Build Once, Display on Multiple Dashboards)

| Metric | Displays On |
|--------|-------------|
| Cash Position | COO/Ops, CEO/Biz Dev |
| Working Capital | COO/Ops, CEO/Biz Dev |
| Months of Runway | COO/Ops, CEO/Biz Dev |
| Top Customer Concentration | COO/Ops, CEO/Biz Dev, Company Health |
| Invoice Collection | COO/Ops, Accounting |

## Data Sources

| Source | Tables | Status |
|--------|--------|--------|
| QuickBooks (via BigQuery) | `src_fivetran_qbo.invoice`, `credit_memo`, `account` | ✅ Available |
| HubSpot (via BigQuery) | `HS_QBO_GMV_Waterfall` | ✅ Available |
| SimpleFin API | Bank balances | ⛔ Integration needed |

## Key QBO Account IDs

| Account Type | Account IDs | Description |
|--------------|-------------|-------------|
| Revenue | 4110, 4120, 4130 | Sampling, Sponsorship, Activation |
| COGS | 5000-5999 | Cost of Goods Sold |
| AR | 1100 | Accounts Receivable |
| AP | 2000 | Accounts Payable |
| Cash | 1000 | Cash and equivalents |

## Status Indicators

| Metric | 🟢 GREEN | 🟡 YELLOW | 🔴 RED |
|--------|----------|----------|--------|
| Take Rate | ≥ 45% | 40-45% | < 40% |
| Invoice Collection | ≥ 95% | 90-95% | < 90% |
| Working Capital | ≥ $1M | $500K-$1M | < $500K |
| Runway | ≥ 12 mo | 6-12 mo | < 6 mo |
| Customer Concentration | < 30% | 30-40% | > 40% |
| Factoring Capacity | ≥ $400K | $200K-$400K | < $200K |

## Critical Gotchas

1. **Always filter `_fivetran_deleted = FALSE`** on QBO tables
2. **Credit memos** - For NRR, attribute to period ISSUED; for contract tracking, tie to ORIGINAL invoice
3. **Revenue accounts** - Use 4110, 4120, 4130 only (not 4000 which is parent)
4. **AR Aging** - Calculate from invoice `due_date`, not `transaction_date`

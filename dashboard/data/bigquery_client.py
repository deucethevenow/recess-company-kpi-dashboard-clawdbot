"""
BigQuery client for KPI Dashboard.

Provides connection handling and query methods for fetching
company metrics, person metrics, and detail views from BigQuery.

Authentication: Uses GOOGLE_APPLICATION_CREDENTIALS environment variable.
Set this to your service account key path before running:
    export GOOGLE_APPLICATION_CREDENTIALS="/path/to/bigquery-mcp-key.json"
"""

import logging
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from google.cloud import bigquery
from google.cloud.exceptions import GoogleCloudError

# Configure logging
logger = logging.getLogger(__name__)

# =============================================================================
# CONFIGURATION
# =============================================================================

PROJECT_ID = "stitchdata-384118"
DATASET = "App_KPI_Dashboard"
FISCAL_YEAR = 2026

# Path to SQL query files
QUERIES_DIR = Path(__file__).parent / "queries"

# =============================================================================
# CLIENT MANAGEMENT
# =============================================================================

_client: Optional[bigquery.Client] = None


def get_client() -> bigquery.Client:
    """Get or create BigQuery client.

    Returns:
        Authenticated BigQuery client

    Raises:
        GoogleCloudError: If authentication fails
    """
    global _client
    if _client is None:
        _client = bigquery.Client(project=PROJECT_ID)
        logger.info("BigQuery client initialized for project: %s", PROJECT_ID)
    return _client


def is_bigquery_available() -> bool:
    """Check if BigQuery connection is available.

    Returns:
        True if we can connect to BigQuery, False otherwise
    """
    try:
        client = get_client()
        # Simple query to test connection
        query = f"SELECT 1 as test"
        list(client.query(query).result())
        return True
    except Exception as e:
        logger.warning("BigQuery not available: %s", e)
        return False


# =============================================================================
# COMPANY METRICS (Overview Page)
# =============================================================================

def get_revenue_ytd(fiscal_year: int = FISCAL_YEAR) -> Optional[float]:
    """Fetch YTD Net Revenue (Take) from QuickBooks.

    Net Revenue = What Recess keeps after paying organizers.

    Formula:
        GMV (invoices 4110-4169)
        - Credit Memos (same accounts)
        + Discounts (4190, typically negative)
        - Payouts to organizers (bills 4200-4299)
        + Vendor Credits (same 4200-4299 accounts)

    2025 Reference: $3,890,004 (Take Rate: 49.1%)

    Returns:
        Net revenue YTD or None if query fails
    """
    query = f"""
    WITH gmv_invoices AS (
        -- GMV from invoices (4110-4169)
        SELECT COALESCE(SUM(il.amount), 0) as amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.invoice_line` il
        JOIN `{PROJECT_ID}.src_fivetran_qbo.invoice` i ON il.invoice_id = i.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON il.sales_item_account_id = a.id
        WHERE EXTRACT(YEAR FROM i.transaction_date) = {fiscal_year}
          AND SAFE_CAST(a.account_number AS INT64) BETWEEN 4110 AND 4169
          AND i._fivetran_deleted = FALSE
    ),
    credit_memos AS (
        -- Credit memos reduce GMV
        SELECT COALESCE(SUM(cl.amount), 0) as amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.credit_memo_line` cl
        JOIN `{PROJECT_ID}.src_fivetran_qbo.credit_memo` cm ON cl.credit_memo_id = cm.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON cl.sales_item_account_id = a.id
        WHERE EXTRACT(YEAR FROM cm.transaction_date) = {fiscal_year}
          AND SAFE_CAST(a.account_number AS INT64) BETWEEN 4110 AND 4169
          AND cm._fivetran_deleted = FALSE
    ),
    discounts AS (
        -- Discounts (4190) - typically negative amounts
        SELECT COALESCE(SUM(il.amount), 0) as amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.invoice_line` il
        JOIN `{PROJECT_ID}.src_fivetran_qbo.invoice` i ON il.invoice_id = i.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON il.sales_item_account_id = a.id
        WHERE EXTRACT(YEAR FROM i.transaction_date) = {fiscal_year}
          AND a.account_number = '4190'
          AND i._fivetran_deleted = FALSE
    ),
    payouts AS (
        -- Payouts to organizers (bills 4200-4299)
        SELECT COALESCE(SUM(bl.amount), 0) as amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.bill_line` bl
        JOIN `{PROJECT_ID}.src_fivetran_qbo.bill` b ON bl.bill_id = b.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON bl.account_expense_account_id = a.id
        WHERE EXTRACT(YEAR FROM b.transaction_date) = {fiscal_year}
          AND SAFE_CAST(a.account_number AS INT64) BETWEEN 4200 AND 4299
          AND b._fivetran_deleted = FALSE
    ),
    vendor_credits AS (
        -- Vendor credits reduce payouts
        SELECT COALESCE(SUM(vcl.amount), 0) as amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.vendor_credit_line` vcl
        JOIN `{PROJECT_ID}.src_fivetran_qbo.vendor_credit` vc ON vcl.vendor_credit_id = vc.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON vcl.account_expense_account_id = a.id
        WHERE EXTRACT(YEAR FROM vc.transaction_date) = {fiscal_year}
          AND SAFE_CAST(a.account_number AS INT64) BETWEEN 4200 AND 4299
          AND vc._fivetran_deleted = FALSE
    )
    SELECT
        g.amount - c.amount + d.amount - p.amount + v.amount as net_revenue
    FROM gmv_invoices g, credit_memos c, discounts d, payouts p, vendor_credits v
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result and result[0].net_revenue is not None:
            return float(result[0].net_revenue)
        return None
    except GoogleCloudError as e:
        logger.error("Failed to fetch revenue YTD: %s", e)
        return None


def get_take_rate(fiscal_year: int = FISCAL_YEAR) -> Optional[float]:
    """Fetch Take Rate from QuickBooks chart of accounts.

    Formula: Take Rate = Market Place Revenue / GMV

    Where:
    - GMV = Sum of 4110-4169 accounts (Sampling, Sponsorship, Activation GMV)
    - Market Place Revenue = GMV + Discounts (4190) + Organizer Fees (4200s)

    Data Sources:
    - Invoices: GMV (4110-4169) and Discounts (4190)
    - Credit Memos: Reduce GMV (refunds, adjustments)
    - Bills: Organizer Fees / Payouts (4200-4299)
    - Vendor Credits: Reduce Organizer Fees

    For current fiscal year with limited data, falls back to prior complete year.

    2025 Reference: 49.3% (GMV: $7.92M, Revenue: $3.90M)

    Returns:
        Take rate as decimal (e.g., 0.49 for 49%) or None if query fails
    """
    prior_year = fiscal_year - 1

    query = f"""
    WITH invoice_revenue AS (
        SELECT SAFE_CAST(a.account_number AS INT64) as acct_num, SUM(il.amount) as amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.invoice_line` il
        JOIN `{PROJECT_ID}.src_fivetran_qbo.invoice` i ON il.invoice_id = i.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON il.sales_item_account_id = a.id
        WHERE EXTRACT(YEAR FROM i.transaction_date) = @year AND i._fivetran_deleted = FALSE
        GROUP BY 1
    ),
    credit_memos AS (
        SELECT SAFE_CAST(a.account_number AS INT64) as acct_num, -SUM(cl.amount) as amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.credit_memo_line` cl
        JOIN `{PROJECT_ID}.src_fivetran_qbo.credit_memo` cm ON cl.credit_memo_id = cm.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON cl.sales_item_account_id = a.id
        WHERE EXTRACT(YEAR FROM cm.transaction_date) = @year AND cm._fivetran_deleted = FALSE
        GROUP BY 1
    ),
    bills AS (
        SELECT SAFE_CAST(a.account_number AS INT64) as acct_num, -SUM(bl.amount) as amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.bill_line` bl
        JOIN `{PROJECT_ID}.src_fivetran_qbo.bill` b ON bl.bill_id = b.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON bl.account_expense_account_id = a.id
        WHERE EXTRACT(YEAR FROM b.transaction_date) = @year AND b._fivetran_deleted = FALSE
            AND SAFE_CAST(a.account_number AS INT64) BETWEEN 4200 AND 4299
        GROUP BY 1
    ),
    vendor_credits AS (
        SELECT SAFE_CAST(a.account_number AS INT64) as acct_num, SUM(vcl.amount) as amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.vendor_credit_line` vcl
        JOIN `{PROJECT_ID}.src_fivetran_qbo.vendor_credit` vc ON vcl.vendor_credit_id = vc.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON vcl.account_expense_account_id = a.id
        WHERE EXTRACT(YEAR FROM vc.transaction_date) = @year AND vc._fivetran_deleted = FALSE
            AND SAFE_CAST(a.account_number AS INT64) BETWEEN 4200 AND 4299
        GROUP BY 1
    ),
    all_income AS (
        SELECT * FROM invoice_revenue UNION ALL SELECT * FROM credit_memos
        UNION ALL SELECT * FROM bills UNION ALL SELECT * FROM vendor_credits
    )
    SELECT
        SAFE_DIVIDE(
            SUM(CASE WHEN acct_num BETWEEN 4110 AND 4299 THEN amount ELSE 0 END),
            SUM(CASE WHEN acct_num BETWEEN 4110 AND 4169 THEN amount ELSE 0 END)
        ) as take_rate,
        SUM(CASE WHEN acct_num BETWEEN 4110 AND 4169 THEN amount ELSE 0 END) as gmv
    FROM all_income
    """

    try:
        client = get_client()

        # Try current fiscal year first
        job_config = bigquery.QueryJobConfig(
            query_parameters=[bigquery.ScalarQueryParameter("year", "INT64", fiscal_year)]
        )
        result = list(client.query(query, job_config=job_config).result())

        # If GMV < $100K, fall back to prior year
        if result and result[0].gmv and result[0].gmv > 100000:
            if result[0].take_rate is not None:
                return float(result[0].take_rate)

        # Fall back to prior year
        job_config = bigquery.QueryJobConfig(
            query_parameters=[bigquery.ScalarQueryParameter("year", "INT64", prior_year)]
        )
        result = list(client.query(query, job_config=job_config).result())
        if result and result[0].take_rate is not None:
            return float(result[0].take_rate)

        return None
    except GoogleCloudError as e:
        logger.error("Failed to fetch take rate: %s", e)
        return None


def get_invoice_collection_rate(fiscal_year: int = FISCAL_YEAR) -> Dict[str, Any]:
    """Fetch invoice collection rate from QuickBooks data.

    Formula: Paid Invoices / Total Due Invoices
    Where: paid = balance = 0, due = due_date <= today

    Query: queries/coo-ops/invoice-collection-rate.sql

    Returns:
        Dict with collection_rate, paid_count, total_count, or empty dict on error
    """
    query = f"""
    SELECT
        COUNTIF(balance = 0) AS paid_invoices,
        COUNT(*) AS total_due_invoices,
        SAFE_DIVIDE(COUNTIF(balance = 0), COUNT(*)) AS collection_rate_pct
    FROM `{PROJECT_ID}.src_fivetran_qbo.invoice`
    WHERE due_date <= CURRENT_DATE()
      AND _fivetran_deleted = FALSE
      AND EXTRACT(YEAR FROM transaction_date) = {fiscal_year}
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            row = result[0]
            return {
                "collection_rate": float(row.collection_rate_pct) if row.collection_rate_pct else 0,
                "paid_count": int(row.paid_invoices) if row.paid_invoices else 0,
                "total_count": int(row.total_due_invoices) if row.total_due_invoices else 0,
            }
        return {}
    except GoogleCloudError as e:
        logger.error("Failed to fetch invoice collection rate: %s", e)
        return {}


def get_overdue_invoices() -> Dict[str, Any]:
    """Fetch overdue invoice count and dollar amount.

    Formula: Invoices where balance > 0 AND due_date < today
    Target: 0

    Query: queries/coo-ops/overdue-invoices.sql

    Returns:
        Dict with count, amount, or empty dict on error
    """
    query = f"""
    SELECT
        COUNT(*) AS overdue_count,
        COALESCE(SUM(balance), 0) AS overdue_amount
    FROM `{PROJECT_ID}.src_fivetran_qbo.invoice`
    WHERE balance > 0
      AND due_date < CURRENT_DATE()
      AND _fivetran_deleted = FALSE
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            row = result[0]
            return {
                "count": int(row.overdue_count) if row.overdue_count else 0,
                "amount": float(row.overdue_amount) if row.overdue_amount else 0,
            }
        return {}
    except GoogleCloudError as e:
        logger.error("Failed to fetch overdue invoices: %s", e)
        return {}


def get_working_capital() -> Dict[str, Any]:
    """Fetch working capital from QuickBooks balance sheet.

    Formula: Current Assets - Current Liabilities
    Target: >$1M
    Shared: COO/Ops + CEO/Biz Dev dashboards

    Query: queries/coo-ops/working-capital.sql

    Returns:
        Dict with working_capital, current_assets, current_liabilities
    """
    query = f"""
    WITH balance_sheet AS (
        SELECT
            a.classification,
            a.account_sub_type,
            COALESCE(SUM(jel.amount), 0) as balance
        FROM `{PROJECT_ID}.src_fivetran_qbo.journal_entry_line` jel
        JOIN `{PROJECT_ID}.src_fivetran_qbo.journal_entry` je ON jel.journal_entry_id = je.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON jel.account_id = a.id
        WHERE je._fivetran_deleted = FALSE
          AND a.classification IN ('Asset', 'Liability')
          AND a.account_sub_type IN (
            'Bank', 'AccountsReceivable', 'OtherCurrentAsset',
            'AccountsPayable', 'OtherCurrentLiability', 'CreditCard'
          )
        GROUP BY 1, 2
    )
    SELECT
        SUM(CASE WHEN classification = 'Asset' THEN balance ELSE 0 END) as current_assets,
        SUM(CASE WHEN classification = 'Liability' THEN ABS(balance) ELSE 0 END) as current_liabilities,
        SUM(CASE WHEN classification = 'Asset' THEN balance ELSE 0 END)
        - SUM(CASE WHEN classification = 'Liability' THEN ABS(balance) ELSE 0 END) as working_capital
    FROM balance_sheet
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            row = result[0]
            return {
                "working_capital": float(row.working_capital) if row.working_capital else 0,
                "current_assets": float(row.current_assets) if row.current_assets else 0,
                "current_liabilities": float(row.current_liabilities) if row.current_liabilities else 0,
            }
        return {}
    except GoogleCloudError as e:
        logger.error("Failed to fetch working capital: %s", e)
        return {}


def get_months_of_runway() -> Dict[str, Any]:
    """Fetch months of runway from QuickBooks.

    Formula: Cash Balance / Average Monthly Burn (3-month trailing)
    Target: >12 months
    Shared: COO/Ops + CEO/Biz Dev dashboards

    Query: queries/coo-ops/months-of-runway.sql

    Returns:
        Dict with months, cash_balance, avg_monthly_burn
    """
    query = f"""
    WITH monthly_expenses AS (
        SELECT
            DATE_TRUNC(je.transaction_date, MONTH) as month,
            SUM(CASE WHEN a.classification = 'Expense' THEN jel.amount ELSE 0 END) as expenses
        FROM `{PROJECT_ID}.src_fivetran_qbo.journal_entry_line` jel
        JOIN `{PROJECT_ID}.src_fivetran_qbo.journal_entry` je ON jel.journal_entry_id = je.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON jel.account_id = a.id
        WHERE je._fivetran_deleted = FALSE
          AND je.transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH)
        GROUP BY 1
    ),
    cash AS (
        SELECT COALESCE(SUM(jel.amount), 0) as cash_balance
        FROM `{PROJECT_ID}.src_fivetran_qbo.journal_entry_line` jel
        JOIN `{PROJECT_ID}.src_fivetran_qbo.journal_entry` je ON jel.journal_entry_id = je.id
        JOIN `{PROJECT_ID}.src_fivetran_qbo.account` a ON jel.account_id = a.id
        WHERE je._fivetran_deleted = FALSE
          AND a.account_sub_type = 'Bank'
    )
    SELECT
        c.cash_balance,
        AVG(e.expenses) as avg_monthly_burn,
        SAFE_DIVIDE(c.cash_balance, AVG(e.expenses)) as months_of_runway
    FROM cash c, monthly_expenses e
    GROUP BY c.cash_balance
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            row = result[0]
            return {
                "months": float(row.months_of_runway) if row.months_of_runway else None,
                "cash_balance": float(row.cash_balance) if row.cash_balance else 0,
                "avg_monthly_burn": float(row.avg_monthly_burn) if row.avg_monthly_burn else 0,
            }
        return {}
    except GoogleCloudError as e:
        logger.error("Failed to fetch months of runway: %s", e)
        return {}


def get_nrr(fiscal_year: int = FISCAL_YEAR) -> Optional[float]:
    """Fetch Net Revenue Retention using cohort-based calculation.

    Uses: App_KPI_Dashboard.cohort_retention_matrix_by_customer
    Formula: Cohort NRR = (Prior year cohort's current year revenue) / (Their prior year revenue)

    Example for 2026:
    - 2025 Cohort spent $1,008k in 2025
    - Same cohort spent $1.5k in 2026 (so far)
    - NRR = $1.5k / $1,008k = 0.15%

    For early in fiscal year, shows prior complete year comparison as reference.

    Returns:
        NRR as decimal (e.g., 1.07 for 107%) or None if query fails
    """
    prior_year = fiscal_year - 1

    query = f"""
    SELECT
        SAFE_DIVIDE(
            SUM(CAST(y{fiscal_year} AS FLOAT64)),
            SUM(CAST(y{prior_year} AS FLOAT64))
        ) as nrr
    FROM `{PROJECT_ID}.{DATASET}.cohort_retention_matrix_by_customer`
    WHERE first_year = {prior_year}
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result and result[0].nrr is not None:
            return float(result[0].nrr)
        return None
    except GoogleCloudError as e:
        logger.error("Failed to fetch NRR: %s", e)
        return None


def get_demand_nrr_details(fiscal_year: int = FISCAL_YEAR) -> Dict[str, Any]:
    """Fetch detailed Demand NRR with both current year and prior year comparison.

    Uses: App_KPI_Dashboard.cohort_retention_matrix_by_customer

    Returns dict with:
    - current_year: 2026 YTD data (2025 cohort's 2026 revenue vs their 2025 revenue)
    - prior_year: 2025 Actuals (2024 cohort's 2025 revenue vs their 2024 revenue)

    Returns:
        Dictionary with NRR details for both periods
    """
    prior_year = fiscal_year - 1
    prior_prior_year = fiscal_year - 2

    query = f"""
    SELECT
        first_year as cohort_year,
        SUM(CAST(y{prior_prior_year} AS FLOAT64)) as rev_prior_prior,
        SUM(CAST(y{prior_year} AS FLOAT64)) as rev_prior,
        SUM(CAST(y{fiscal_year} AS FLOAT64)) as rev_current
    FROM `{PROJECT_ID}.{DATASET}.cohort_retention_matrix_by_customer`
    WHERE first_year IN ({prior_prior_year}, {prior_year})
    GROUP BY first_year
    ORDER BY first_year
    """
    try:
        client = get_client()
        results = list(client.query(query).result())

        response = {
            "current_year": {
                "cohort": prior_year,
                "cohort_original_revenue": 0,
                "cohort_next_year_revenue": 0,
                "nrr_pct": 0,
                "label": f"{fiscal_year} YTD"
            },
            "prior_year": {
                "cohort": prior_prior_year,
                "cohort_original_revenue": 0,
                "cohort_next_year_revenue": 0,
                "nrr_pct": 0,
                "label": f"{prior_year} Actuals"
            }
        }

        for row in results:
            if row.cohort_year == prior_year:
                # 2025 cohort's performance in 2026 (current year)
                orig = float(row.rev_prior or 0)
                next_yr = float(row.rev_current or 0)
                response["current_year"]["cohort_original_revenue"] = orig
                response["current_year"]["cohort_next_year_revenue"] = next_yr
                response["current_year"]["nrr_pct"] = (next_yr / orig * 100) if orig > 0 else 0

            elif row.cohort_year == prior_prior_year:
                # 2024 cohort's performance in 2025 (prior complete year)
                orig = float(row.rev_prior_prior or 0)
                next_yr = float(row.rev_prior or 0)
                response["prior_year"]["cohort_original_revenue"] = orig
                response["prior_year"]["cohort_next_year_revenue"] = next_yr
                response["prior_year"]["nrr_pct"] = (next_yr / orig * 100) if orig > 0 else 0

        return response
    except GoogleCloudError as e:
        logger.error("Failed to fetch NRR details: %s", e)
        return {}


def get_supply_npr(fiscal_year: int = FISCAL_YEAR) -> Optional[float]:
    """Fetch Supply Net Payout Retention (NPR) using financial-based calculation.

    NOTE: Renamed from get_supply_nrr to get_supply_npr to clarify terminology:
    - NPR (Net Payout Retention) = Suppliers - did they get paid more?
    - NRR (Net Revenue Retention) = Customers - did they spend more?

    Uses QBO bill transaction dates (when money moved) instead of offer acceptance dates.
    This is more accurate because:
    - Uses actual financial transaction dates
    - Includes vendor credits (refunds, adjustments)
    - Handles split bills (_2, _3 suffixes) properly
    - Links QBO bills to MongoDB remittances for supplier org attribution

    Formula: (Current Year Net Payouts to Prior Year Suppliers) / (Prior Year Net Payouts)
    Net Payouts = Bills - Vendor Credits

    Target: 110%

    Returns:
        Supply NPR as decimal (e.g., 0.87 for 87%) or None if query fails
    """
    prior_year = fiscal_year - 1

    query = f"""
    -- Financial-based Supply NRR using QBO bills linked to MongoDB remittances
    WITH payout_accounts AS (
        SELECT id as account_id
        FROM `{PROJECT_ID}.src_fivetran_qbo.account`
        WHERE _fivetran_deleted = FALSE
          AND account_number IN ('4200', '4210', '4220', '4230')
    ),
    remittance_supplier_map AS (
        SELECT DISTINCT
            rli.bill_number,
            rli.ctx.supplier.org.name as supplier_org_name
        FROM `{PROJECT_ID}.mongodb.remittance_line_items` rli
        WHERE rli.bill_number IS NOT NULL
          AND rli.ctx.supplier.org.name IS NOT NULL
    ),
    qbo_payout_bills AS (
        SELECT
            b.doc_number as bill_number,
            REGEXP_REPLACE(b.doc_number, r'_\\d+$', '') as base_bill_number,
            EXTRACT(YEAR FROM b.transaction_date) as txn_year,
            SUM(CAST(bl.amount AS FLOAT64)) as bill_amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.bill` b
        JOIN `{PROJECT_ID}.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
        JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
        WHERE b._fivetran_deleted = FALSE
          AND EXTRACT(YEAR FROM b.transaction_date) >= {prior_year}
        GROUP BY b.doc_number, b.transaction_date
    ),
    qbo_payout_credits AS (
        SELECT
            REGEXP_REPLACE(vc.doc_number, r'(_credit|c\\d+)$', '') as bill_number,
            EXTRACT(YEAR FROM vc.transaction_date) as credit_year,
            SUM(CAST(vcl.amount AS FLOAT64)) as credit_amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.vendor_credit` vc
        JOIN `{PROJECT_ID}.src_fivetran_qbo.vendor_credit_line` vcl ON vc.id = vcl.vendor_credit_id
        JOIN payout_accounts pa ON vcl.account_expense_account_id = pa.account_id
        WHERE vc._fivetran_deleted = FALSE
          AND REGEXP_CONTAINS(vc.doc_number, r'(_credit|c\\d+)$')
          AND EXTRACT(YEAR FROM vc.transaction_date) >= {prior_year}
        GROUP BY vc.doc_number, vc.transaction_date
    ),
    bills_with_supplier AS (
        SELECT
            COALESCE(rsm.supplier_org_name, 'UNLINKED') as supplier_org_name,
            b.txn_year,
            b.bill_amount,
            0.0 as credit_amount
        FROM qbo_payout_bills b
        LEFT JOIN remittance_supplier_map rsm ON b.base_bill_number = rsm.bill_number
    ),
    credits_with_supplier AS (
        SELECT
            COALESCE(rsm.supplier_org_name, 'UNLINKED') as supplier_org_name,
            c.credit_year as txn_year,
            0.0 as bill_amount,
            c.credit_amount
        FROM qbo_payout_credits c
        LEFT JOIN remittance_supplier_map rsm ON c.bill_number = rsm.bill_number
    ),
    all_transactions AS (
        SELECT * FROM bills_with_supplier
        UNION ALL
        SELECT * FROM credits_with_supplier
    ),
    supplier_yearly_revenue AS (
        SELECT
            supplier_org_name,
            txn_year,
            SUM(bill_amount) - SUM(credit_amount) as net_revenue
        FROM all_transactions
        WHERE supplier_org_name != 'UNLINKED'
        GROUP BY supplier_org_name, txn_year
    ),
    supplier_pivot AS (
        SELECT
            supplier_org_name,
            SUM(CASE WHEN txn_year = {prior_year} THEN net_revenue ELSE 0 END) as rev_prior,
            SUM(CASE WHEN txn_year = {fiscal_year} THEN net_revenue ELSE 0 END) as rev_current
        FROM supplier_yearly_revenue
        GROUP BY supplier_org_name
    )
    SELECT
        SAFE_DIVIDE(
            SUM(CASE WHEN rev_prior > 0 THEN rev_current END),
            SUM(CASE WHEN rev_prior > 0 THEN rev_prior END)
        ) as supply_nrr
    FROM supplier_pivot
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result and result[0].supply_nrr is not None:
            return float(result[0].supply_nrr)
        return None
    except GoogleCloudError as e:
        logger.error("Failed to fetch supply NPR: %s", e)
        return None


# Alias for backward compatibility
def get_supply_nrr(fiscal_year: int = FISCAL_YEAR) -> Optional[float]:
    """Deprecated: Use get_supply_npr() instead. Kept for backward compatibility."""
    return get_supply_npr(fiscal_year)


def get_supply_npr_details(fiscal_year: int = FISCAL_YEAR) -> Dict[str, Any]:
    """Fetch detailed Supply NPR using financial-based calculation.

    Uses QBO bill transaction dates linked to MongoDB remittances for accurate
    supplier org attribution. Includes vendor credits and handles split bills.

    Returns dict with:
    - current_year: 2026 YTD data (2025 suppliers' 2026 net payouts vs their 2025 net payouts)
    - prior_year: 2025 Actuals (2024 suppliers' 2025 net payouts vs their 2024 net payouts)

    Net Payouts = Bills - Vendor Credits (both attributed by transaction_date)

    Returns:
        Dictionary with Supply NPR details for both periods
    """
    prior_year = fiscal_year - 1
    prior_prior_year = fiscal_year - 2

    query = f"""
    -- Financial-based Supply NRR details using QBO bills linked to MongoDB remittances
    WITH payout_accounts AS (
        SELECT id as account_id
        FROM `{PROJECT_ID}.src_fivetran_qbo.account`
        WHERE _fivetran_deleted = FALSE
          AND account_number IN ('4200', '4210', '4220', '4230')
    ),
    remittance_supplier_map AS (
        SELECT DISTINCT
            rli.bill_number,
            rli.ctx.supplier.org.name as supplier_org_name
        FROM `{PROJECT_ID}.mongodb.remittance_line_items` rli
        WHERE rli.bill_number IS NOT NULL
          AND rli.ctx.supplier.org.name IS NOT NULL
    ),
    qbo_payout_bills AS (
        SELECT
            b.doc_number as bill_number,
            REGEXP_REPLACE(b.doc_number, r'_\\d+$', '') as base_bill_number,
            EXTRACT(YEAR FROM b.transaction_date) as txn_year,
            SUM(CAST(bl.amount AS FLOAT64)) as bill_amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.bill` b
        JOIN `{PROJECT_ID}.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
        JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
        WHERE b._fivetran_deleted = FALSE
          AND EXTRACT(YEAR FROM b.transaction_date) >= {prior_prior_year}
        GROUP BY b.doc_number, b.transaction_date
    ),
    qbo_payout_credits AS (
        SELECT
            REGEXP_REPLACE(vc.doc_number, r'(_credit|c\\d+)$', '') as bill_number,
            EXTRACT(YEAR FROM vc.transaction_date) as credit_year,
            SUM(CAST(vcl.amount AS FLOAT64)) as credit_amount
        FROM `{PROJECT_ID}.src_fivetran_qbo.vendor_credit` vc
        JOIN `{PROJECT_ID}.src_fivetran_qbo.vendor_credit_line` vcl ON vc.id = vcl.vendor_credit_id
        JOIN payout_accounts pa ON vcl.account_expense_account_id = pa.account_id
        WHERE vc._fivetran_deleted = FALSE
          AND REGEXP_CONTAINS(vc.doc_number, r'(_credit|c\\d+)$')
          AND EXTRACT(YEAR FROM vc.transaction_date) >= {prior_prior_year}
        GROUP BY vc.doc_number, vc.transaction_date
    ),
    bills_with_supplier AS (
        SELECT
            COALESCE(rsm.supplier_org_name, 'UNLINKED') as supplier_org_name,
            b.txn_year,
            b.bill_amount,
            0.0 as credit_amount
        FROM qbo_payout_bills b
        LEFT JOIN remittance_supplier_map rsm ON b.base_bill_number = rsm.bill_number
    ),
    credits_with_supplier AS (
        SELECT
            COALESCE(rsm.supplier_org_name, 'UNLINKED') as supplier_org_name,
            c.credit_year as txn_year,
            0.0 as bill_amount,
            c.credit_amount
        FROM qbo_payout_credits c
        LEFT JOIN remittance_supplier_map rsm ON c.bill_number = rsm.bill_number
    ),
    all_transactions AS (
        SELECT * FROM bills_with_supplier
        UNION ALL
        SELECT * FROM credits_with_supplier
    ),
    supplier_yearly_revenue AS (
        SELECT
            supplier_org_name,
            txn_year,
            SUM(bill_amount) - SUM(credit_amount) as net_revenue
        FROM all_transactions
        WHERE supplier_org_name != 'UNLINKED'
        GROUP BY supplier_org_name, txn_year
    ),
    supplier_pivot AS (
        SELECT
            supplier_org_name,
            SUM(CASE WHEN txn_year = {prior_prior_year} THEN net_revenue ELSE 0 END) as rev_prior_prior,
            SUM(CASE WHEN txn_year = {prior_year} THEN net_revenue ELSE 0 END) as rev_prior,
            SUM(CASE WHEN txn_year = {fiscal_year} THEN net_revenue ELSE 0 END) as rev_current
        FROM supplier_yearly_revenue
        GROUP BY supplier_org_name
    )
    SELECT
        -- 2024 cohort in 2025 (prior complete year comparison)
        SUM(CASE WHEN rev_prior_prior > 0 THEN rev_prior_prior END) as prior_cohort_original,
        SUM(CASE WHEN rev_prior_prior > 0 THEN rev_prior END) as prior_cohort_next_year,
        COUNT(CASE WHEN rev_prior_prior > 0 THEN 1 END) as prior_cohort_count,
        -- 2025 cohort in 2026 (current year)
        SUM(CASE WHEN rev_prior > 0 THEN rev_prior END) as current_cohort_original,
        SUM(CASE WHEN rev_prior > 0 THEN rev_current END) as current_cohort_next_year,
        COUNT(CASE WHEN rev_prior > 0 THEN 1 END) as current_cohort_count
    FROM supplier_pivot
    """
    try:
        client = get_client()
        result = list(client.query(query).result())

        if not result:
            return {}

        row = result[0]
        prior_orig = float(row.prior_cohort_original or 0)
        prior_next = float(row.prior_cohort_next_year or 0)
        curr_orig = float(row.current_cohort_original or 0)
        curr_next = float(row.current_cohort_next_year or 0)

        return {
            "current_year": {
                "cohort": prior_year,
                "cohort_original_payouts": curr_orig,
                "cohort_next_year_payouts": curr_next,
                "supplier_count": int(row.current_cohort_count or 0),
                "npr_pct": (curr_next / curr_orig * 100) if curr_orig > 0 else 0,
                "label": f"{fiscal_year} YTD"
            },
            "prior_year": {
                "cohort": prior_prior_year,
                "cohort_original_payouts": prior_orig,
                "cohort_next_year_payouts": prior_next,
                "supplier_count": int(row.prior_cohort_count or 0),
                "npr_pct": (prior_next / prior_orig * 100) if prior_orig > 0 else 0,
                "label": f"{prior_year} Actuals"
            },
            "methodology": "financial"  # Indicates this uses QBO transaction dates
        }
    except GoogleCloudError as e:
        logger.error("Failed to fetch supply NPR details: %s", e)
        return {}


# Alias for backward compatibility
def get_supply_nrr_details(fiscal_year: int = FISCAL_YEAR) -> Dict[str, Any]:
    """Deprecated: Use get_supply_npr_details() instead. Kept for backward compatibility."""
    return get_supply_npr_details(fiscal_year)


def get_customer_count(fiscal_year: int = FISCAL_YEAR) -> Optional[int]:
    """Fetch active customer count from customer_development view.

    Note: Uses Net_Revenue_YYYY columns and customer_id field.
    customer_development view has data through 2025, so we use that.

    Returns:
        Number of active customers or None if query fails
    """
    # Use 2025 data (most recent complete year)
    query = f"""
    SELECT COUNT(DISTINCT customer_id) as customer_count
    FROM `{PROJECT_ID}.{DATASET}.customer_development`
    WHERE Net_Revenue_2025 > 0
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            return int(result[0].customer_count)
        return None
    except GoogleCloudError as e:
        logger.error("Failed to fetch customer count: %s", e)
        return None


def get_churned_customers(fiscal_year: int = FISCAL_YEAR) -> Optional[int]:
    """Fetch count of churned customers from customer_development view.

    Definition: Customers who had revenue in prior year but $0 in current year.

    Returns:
        Number of churned customers or None if query fails
    """
    prior_year = fiscal_year - 1

    query = f"""
    SELECT COUNT(DISTINCT customer_id) as churned_count
    FROM `{PROJECT_ID}.{DATASET}.customer_development`
    WHERE COALESCE(Net_Revenue_{prior_year}, 0) > 0
      AND COALESCE(Net_Revenue_{fiscal_year}, 0) = 0
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            return int(result[0].churned_count)
        return None
    except GoogleCloudError as e:
        logger.error("Failed to fetch churned customers: %s", e)
        return None


def get_customer_concentration(fiscal_year: int = FISCAL_YEAR) -> Dict[str, Any]:
    """Fetch customer concentration metrics.

    Returns top customers and their percentage of total revenue.

    Returns:
        Dictionary with top_customer_pct, top_customer_name, and top_customers list
    """
    prior_year = fiscal_year - 1  # Use prior complete year for meaningful data

    query = f"""
    WITH customer_revenue AS (
        SELECT
            company_name,
            SAFE_CAST(net_rev_{prior_year} AS FLOAT64) as revenue
        FROM `{PROJECT_ID}.{DATASET}.net_revenue_retention_all_customers`
        WHERE qbo_customer_id != 'UNKNOWN'
          AND SAFE_CAST(net_rev_{prior_year} AS FLOAT64) > 0
    ),
    total AS (
        SELECT SUM(revenue) as total_revenue FROM customer_revenue
    )
    SELECT
        c.company_name,
        c.revenue,
        c.revenue / t.total_revenue as pct_of_total
    FROM customer_revenue c
    CROSS JOIN total t
    ORDER BY c.revenue DESC
    LIMIT 5
    """
    try:
        client = get_client()
        results = list(client.query(query).result())

        if not results:
            return {}

        top_customers = []
        for row in results:
            top_customers.append({
                "name": row.company_name,
                "revenue": float(row.revenue),
                "pct": float(row.pct_of_total)
            })

        return {
            "top_customer_name": top_customers[0]["name"] if top_customers else None,
            "top_customer_pct": top_customers[0]["pct"] if top_customers else None,
            "top_2_combined_pct": sum(c["pct"] for c in top_customers[:2]) if len(top_customers) >= 2 else None,
            "top_customers": top_customers,
            "year": prior_year
        }
    except GoogleCloudError as e:
        logger.error("Failed to fetch customer concentration: %s", e)
        return {}


def get_logo_retention(fiscal_year: int = FISCAL_YEAR) -> Optional[float]:
    """Fetch logo retention rate.

    Formula: Unique customers with revenue in both years / Unique customers with revenue last year

    CRITICAL: Must use COUNT(DISTINCT customer_id) because customer_development
    view has multiple rows per customer (deal/supplier combinations).

    Returns:
        Logo retention as decimal (e.g., 0.26 for 26%) or None if query fails
    """
    prior_year = fiscal_year - 1
    prior_prior_year = fiscal_year - 2  # For comparison when current year has limited data

    query = f"""
    SELECT
        SAFE_DIVIDE(
            COUNT(DISTINCT CASE
                WHEN COALESCE(Net_Revenue_{prior_prior_year}, 0) > 0
                 AND COALESCE(Net_Revenue_{prior_year}, 0) > 0
                THEN customer_id
            END),
            COUNT(DISTINCT CASE
                WHEN COALESCE(Net_Revenue_{prior_prior_year}, 0) > 0
                THEN customer_id
            END)
        ) as logo_retention
    FROM `{PROJECT_ID}.{DATASET}.customer_development`
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result and result[0].logo_retention is not None:
            return float(result[0].logo_retention)
        return None
    except GoogleCloudError as e:
        logger.error("Failed to fetch logo retention: %s", e)
        return None


def get_quota_from_company_properties(fiscal_year: int = FISCAL_YEAR) -> Dict[str, Any]:
    """Fetch quota totals from HubSpot company properties.

    Sums Land & Expand, New Customer, and Renewal quotas.
    Excludes DG Quota and Walmart Quota (tracked separately).

    Returns:
        Dictionary with quota breakdown and total
    """
    query = f"""
    SELECT
        ROUND(COALESCE(SUM(SAFE_CAST(property_x_{fiscal_year}_land_expand_quota AS FLOAT64)), 0), 2) as land_expand_quota,
        ROUND(COALESCE(SUM(SAFE_CAST(property_x_{fiscal_year}_new_customer_quota AS FLOAT64)), 0), 2) as new_customer_quota,
        ROUND(COALESCE(SUM(SAFE_CAST(property_x_{fiscal_year}_renewal_quota AS FLOAT64)), 0), 2) as renewal_quota,
        -- Also fetch DG and Walmart for reference (not included in main total)
        ROUND(COALESCE(SUM(SAFE_CAST(property_x_{fiscal_year}_dg_quota AS FLOAT64)), 0), 2) as dg_quota,
        ROUND(COALESCE(SUM(SAFE_CAST(property_x_{fiscal_year}_walmart_quota AS FLOAT64)), 0), 2) as walmart_quota
    FROM `{PROJECT_ID}.src_fivetran_hubspot.company`
    WHERE property_name IS NOT NULL
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if not result:
            return {"total": 0, "breakdown": {}}

        row = result[0]
        land_expand = float(row.land_expand_quota) if row.land_expand_quota else 0
        new_customer = float(row.new_customer_quota) if row.new_customer_quota else 0
        renewal = float(row.renewal_quota) if row.renewal_quota else 0
        dg = float(row.dg_quota) if row.dg_quota else 0
        walmart = float(row.walmart_quota) if row.walmart_quota else 0

        # Main total excludes DG and Walmart
        total = land_expand + new_customer + renewal

        return {
            "total": total,
            "breakdown": {
                "land_expand": land_expand,
                "new_customer": new_customer,
                "renewal": renewal,
            },
            "excluded": {
                "dg_quota": dg,
                "walmart_quota": walmart,
            },
            "all_quotas_total": total + dg + walmart,
        }
    except GoogleCloudError as e:
        logger.error("Failed to fetch quota from company properties: %s", e)
        return {"total": 0, "breakdown": {}}


def get_pipeline_coverage(
    fiscal_year: int = FISCAL_YEAR,
    annual_goal_override: Optional[float] = None,
    quarterly_goal_override: Optional[float] = None,
    unnamed_accounts_adjustment: float = 2_000_000
) -> Optional[float]:
    """Fetch pipeline coverage from HubSpot deals.

    Formula: HS Weighted Pipeline (closing this quarter) / Remaining Quarterly Goal

    Uses:
    - Default pipeline only (Purchase Manual)
    - HubSpot's property_hs_forecast_amount for weighted pipeline
    - Deals with close date in current quarter

    Args:
        fiscal_year: The fiscal year (default: current)
        annual_goal_override: Override the annual goal (default: dynamic from company properties + unnamed)
        quarterly_goal_override: Override the quarterly goal (default: annual/4)
        unnamed_accounts_adjustment: Additional quota for unnamed accounts (default: $2M)

    Returns:
        Pipeline coverage as multiplier (e.g., 3.26 for 3.26x) or None if query fails
    """
    result = get_pipeline_details(fiscal_year, annual_goal_override, quarterly_goal_override, unnamed_accounts_adjustment)
    return result.get("coverage") if result else None


def get_pipeline_details(
    fiscal_year: int = FISCAL_YEAR,
    annual_goal_override: Optional[float] = None,
    quarterly_goal_override: Optional[float] = None,
    unnamed_accounts_adjustment: float = 2_000_000
) -> Dict[str, Any]:
    """Fetch detailed pipeline metrics for current quarter.

    Pipeline Coverage = HS Weighted Pipeline (this quarter) / Remaining Goal

    Goal Calculation:
    - Company Properties: Land & Expand + New Customer + Renewal quotas
    - Plus: Unnamed accounts adjustment (default $2M)
    - Total: ~$11.27M (from $9.27M properties + $2M unnamed)

    Filters:
    - Default pipeline only ("Purchase Manual")
    - Deals with close date in current quarter
    - Uses HubSpot's property_hs_forecast_amount for weighted value

    Args:
        fiscal_year: The fiscal year
        annual_goal_override: Override annual goal (default: dynamic from company properties)
        quarterly_goal_override: Override quarterly goal (default: annual/4)
        unnamed_accounts_adjustment: Additional quota for unnamed accounts (default: $2M)

    Returns dict with:
    - annual_goal: Full year booking goal (company properties + unnamed)
    - quarterly_goal: Current quarter goal
    - goal_breakdown: Source of annual goal components
    - closed_won: Closed won this quarter
    - remaining_to_goal: Gap to hit quarterly goal
    - open_deals: Count of open deals closing this quarter
    - total_pipeline: Raw pipeline value
    - weighted_pipeline: HubSpot weighted forecast
    - coverage: Coverage ratio (weighted / remaining)
    - pipeline_gap: Surplus (negative) or shortfall (positive)
    """
    # Get quota from company properties (dynamic)
    quota_data = get_quota_from_company_properties(fiscal_year)
    company_properties_total = quota_data.get("total", 0)

    # Calculate annual goal: company properties + unnamed accounts adjustment
    if annual_goal_override:
        annual_goal = annual_goal_override
        goal_breakdown = {"override": annual_goal_override}
    else:
        annual_goal = company_properties_total + unnamed_accounts_adjustment
        goal_breakdown = {
            "company_properties": company_properties_total,
            "unnamed_accounts": unnamed_accounts_adjustment,
            "quota_breakdown": quota_data.get("breakdown", {}),
            "excluded_quotas": quota_data.get("excluded", {}),
        }

    quarterly_goal = quarterly_goal_override or (annual_goal / 4)

    # Calculate quarter boundaries
    # Q1: Jan-Mar, Q2: Apr-Jun, Q3: Jul-Sep, Q4: Oct-Dec
    from datetime import datetime
    current_month = datetime.now().month
    current_quarter = (current_month - 1) // 3 + 1
    quarter_start_month = (current_quarter - 1) * 3 + 1
    quarter_end_month = quarter_start_month + 3

    quarter_start = f"{fiscal_year}-{quarter_start_month:02d}-01"
    if quarter_end_month <= 12:
        quarter_end = f"{fiscal_year}-{quarter_end_month:02d}-01"
    else:
        quarter_end = f"{fiscal_year + 1}-01-01"

    query = f"""
    WITH closed_this_quarter AS (
        SELECT COALESCE(SUM(SAFE_CAST(property_amount AS FLOAT64)), 0) as closed_won
        FROM `{PROJECT_ID}.src_fivetran_hubspot.deal`
        WHERE deal_pipeline_id = 'default'
          AND is_deleted = false
          AND property_hs_is_closed_won = true
          AND property_closedate >= '{quarter_start}'
          AND property_closedate < '{quarter_end}'
    ),
    weighted_pipeline AS (
        SELECT
            COUNT(*) as deal_count,
            COALESCE(SUM(SAFE_CAST(property_amount AS FLOAT64)), 0) as total_pipeline,
            COALESCE(SUM(SAFE_CAST(property_hs_forecast_amount AS FLOAT64)), 0) as hs_weighted_pipeline
        FROM `{PROJECT_ID}.src_fivetran_hubspot.deal`
        WHERE deal_pipeline_id = 'default'
          AND is_deleted = false
          AND property_hs_is_closed = false
          AND property_closedate >= '{quarter_start}'
          AND property_closedate < '{quarter_end}'
    )
    SELECT
        c.closed_won,
        p.deal_count,
        p.total_pipeline,
        p.hs_weighted_pipeline
    FROM closed_this_quarter c, weighted_pipeline p
    """
    try:
        client = get_client()
        result = list(client.query(query).result())

        if not result:
            return {}

        row = result[0]
        closed_won = float(row.closed_won) if row.closed_won else 0
        weighted_pipeline = float(row.hs_weighted_pipeline) if row.hs_weighted_pipeline else 0
        remaining_to_goal = max(quarterly_goal - closed_won, 0)

        # Coverage = weighted pipeline / remaining goal
        # If goal already met, show coverage vs quarterly goal
        if remaining_to_goal > 0:
            coverage = weighted_pipeline / remaining_to_goal
        else:
            coverage = weighted_pipeline / quarterly_goal if quarterly_goal > 0 else 0

        pipeline_gap = remaining_to_goal - weighted_pipeline  # Negative = surplus

        return {
            "annual_goal": annual_goal,
            "quarterly_goal": quarterly_goal,
            "goal_breakdown": goal_breakdown,
            "current_quarter": current_quarter,
            "quarter_start": quarter_start,
            "quarter_end": quarter_end,
            "closed_won": closed_won,
            "remaining_to_goal": remaining_to_goal,
            "open_deals": int(row.deal_count) if row.deal_count else 0,
            "total_pipeline": float(row.total_pipeline) if row.total_pipeline else 0,
            "weighted_pipeline": weighted_pipeline,
            "coverage": round(coverage, 2),
            "pipeline_gap": pipeline_gap,
            "goal_met": closed_won >= quarterly_goal,
        }
    except GoogleCloudError as e:
        logger.error("Failed to fetch pipeline details: %s", e)
        return {}


def get_pipeline_coverage_by_owner(
    fiscal_year: int = FISCAL_YEAR,
    quarter: Optional[str] = None
) -> List[Dict[str, Any]]:
    """Fetch pipeline coverage by quota type, grouped by owner.

    Returns coverage for New Customer, Renewal, and Land & Expand quotas
    with both HS weighted and AI weighted pipeline, plus 2025 reference data.

    Args:
        fiscal_year: The fiscal year for quotas
        quarter: Optional quarter filter (Q1, Q2, Q3, Q4). Default: current quarter.

    Returns:
        List of dicts with owner-level pipeline coverage by quota type
    """
    # Default to current quarter
    if quarter is None:
        current_month = datetime.now().month
        current_quarter = (current_month - 1) // 3 + 1
        quarter = f"Q{current_quarter}"

    query = f"""
    WITH company_quotas AS (
        SELECT
            c.id as company_id,
            COALESCE(o.first_name || ' ' || o.last_name, 'Unassigned') as owner_name,
            COALESCE(SAFE_CAST(c.property_x_{fiscal_year}_new_customer_quota AS FLOAT64), 0) as new_customer_quota,
            COALESCE(SAFE_CAST(c.property_x_{fiscal_year}_renewal_quota AS FLOAT64), 0) as renewal_quota,
            COALESCE(SAFE_CAST(c.property_x_{fiscal_year}_land_expand_quota AS FLOAT64), 0) as land_expand_quota
        FROM `{PROJECT_ID}.src_fivetran_hubspot.company` c
        LEFT JOIN `{PROJECT_ID}.src_fivetran_hubspot.owner` o
            ON SAFE_CAST(c.property_hubspot_owner_id AS INT64) = o.owner_id
        WHERE c.property_name IS NOT NULL
          AND (
            SAFE_CAST(c.property_x_{fiscal_year}_new_customer_quota AS FLOAT64) > 0 OR
            SAFE_CAST(c.property_x_{fiscal_year}_renewal_quota AS FLOAT64) > 0 OR
            SAFE_CAST(c.property_x_{fiscal_year}_land_expand_quota AS FLOAT64) > 0
          )
    ),
    owner_quotas AS (
        SELECT owner_name,
            SUM(new_customer_quota) as new_customer_annual_quota,
            SUM(renewal_quota) as renewal_annual_quota,
            SUM(land_expand_quota) as land_expand_annual_quota
        FROM company_quotas
        GROUP BY owner_name
    ),
    deal_to_owner AS (
        SELECT
            d.deal_id, cq.owner_name,
            SAFE_CAST(d.property_amount AS FLOAT64) as deal_amount,
            SAFE_CAST(d.property_hs_forecast_amount AS FLOAT64) as hs_weighted,
            SAFE_CAST(d.property_ai_weighted_forecast AS FLOAT64) as ai_weighted,
            CASE
                WHEN d.property_dealtype = 'newbusiness' THEN 'new_customer'
                WHEN d.property_dealtype IN ('existingbusiness', 'Renewal 2', 'Campaign - Existing') THEN 'renewal'
                WHEN d.property_dealtype = 'Land and Expand' THEN 'land_expand'
                ELSE 'other'
            END as quota_category,
            ROW_NUMBER() OVER (PARTITION BY d.deal_id ORDER BY (cq.new_customer_quota + cq.renewal_quota + cq.land_expand_quota) DESC) as rn
        FROM `{PROJECT_ID}.src_fivetran_hubspot.deal` d
        JOIN `{PROJECT_ID}.src_fivetran_hubspot.deal_company` dc ON d.deal_id = dc.deal_id
        JOIN company_quotas cq ON dc.company_id = cq.company_id
        WHERE d.deal_pipeline_id = 'default' AND d.is_deleted = false AND d.property_hs_is_closed = false
          AND EXTRACT(YEAR FROM d.property_closedate) = {fiscal_year}
          AND CONCAT('Q', CAST(EXTRACT(QUARTER FROM d.property_closedate) AS STRING)) = '{quarter}'
    ),
    owner_pipeline AS (
        SELECT owner_name,
            SUM(CASE WHEN quota_category = 'new_customer' THEN deal_amount ELSE 0 END) as new_cust_unweighted,
            SUM(CASE WHEN quota_category = 'renewal' THEN deal_amount ELSE 0 END) as renewal_unweighted,
            SUM(CASE WHEN quota_category = 'land_expand' THEN deal_amount ELSE 0 END) as land_exp_unweighted,
            SUM(CASE WHEN quota_category = 'new_customer' THEN hs_weighted ELSE 0 END) as new_cust_hs_weighted,
            SUM(CASE WHEN quota_category = 'renewal' THEN hs_weighted ELSE 0 END) as renewal_hs_weighted,
            SUM(CASE WHEN quota_category = 'land_expand' THEN hs_weighted ELSE 0 END) as land_exp_hs_weighted,
            SUM(CASE WHEN quota_category = 'new_customer' THEN ai_weighted ELSE 0 END) as new_cust_ai_weighted,
            SUM(CASE WHEN quota_category = 'renewal' THEN ai_weighted ELSE 0 END) as renewal_ai_weighted,
            SUM(CASE WHEN quota_category = 'land_expand' THEN ai_weighted ELSE 0 END) as land_exp_ai_weighted
        FROM deal_to_owner WHERE rn = 1 GROUP BY owner_name
    ),
    deals_2025 AS (
        SELECT d.deal_id, cq.owner_name,
            SAFE_CAST(d.property_amount AS FLOAT64) as deal_amount,
            d.property_hs_is_closed_won as is_won,
            CASE
                WHEN d.property_dealtype = 'newbusiness' THEN 'new_customer'
                WHEN d.property_dealtype IN ('existingbusiness', 'Renewal 2', 'Campaign - Existing') THEN 'renewal'
                WHEN d.property_dealtype = 'Land and Expand' THEN 'land_expand'
                ELSE 'other'
            END as quota_category,
            ROW_NUMBER() OVER (PARTITION BY d.deal_id ORDER BY (cq.new_customer_quota + cq.renewal_quota + cq.land_expand_quota) DESC) as rn
        FROM `{PROJECT_ID}.src_fivetran_hubspot.deal` d
        JOIN `{PROJECT_ID}.src_fivetran_hubspot.deal_company` dc ON d.deal_id = dc.deal_id
        JOIN company_quotas cq ON dc.company_id = cq.company_id
        WHERE d.deal_pipeline_id = 'default' AND d.is_deleted = false AND d.property_hs_is_closed = true
          AND EXTRACT(YEAR FROM d.property_closedate) = {fiscal_year - 1}
    ),
    owner_2025_stats AS (
        SELECT owner_name,
            SUM(CASE WHEN is_won AND quota_category = 'new_customer' THEN deal_amount ELSE 0 END) as new_cust_2025_won,
            SUM(CASE WHEN is_won AND quota_category = 'renewal' THEN deal_amount ELSE 0 END) as renewal_2025_won,
            SUM(CASE WHEN is_won AND quota_category = 'land_expand' THEN deal_amount ELSE 0 END) as land_exp_2025_won,
            COUNT(CASE WHEN is_won AND quota_category = 'new_customer' THEN 1 END) as new_cust_won_count,
            COUNT(CASE WHEN NOT is_won AND quota_category = 'new_customer' THEN 1 END) as new_cust_lost_count,
            COUNT(CASE WHEN is_won AND quota_category = 'renewal' THEN 1 END) as renewal_won_count,
            COUNT(CASE WHEN NOT is_won AND quota_category = 'renewal' THEN 1 END) as renewal_lost_count,
            COUNT(CASE WHEN is_won AND quota_category = 'land_expand' THEN 1 END) as land_exp_won_count,
            COUNT(CASE WHEN NOT is_won AND quota_category = 'land_expand' THEN 1 END) as land_exp_lost_count
        FROM deals_2025 WHERE rn = 1 GROUP BY owner_name
    )
    SELECT
        q.owner_name,
        '{quarter}' as quarter,
        ROUND(q.new_customer_annual_quota, 0) as new_cust_annual_quota,
        ROUND(q.renewal_annual_quota, 0) as renewal_annual_quota,
        ROUND(q.land_expand_annual_quota, 0) as land_exp_annual_quota,
        ROUND(q.new_customer_annual_quota/4, 0) as new_cust_quarterly_quota,
        ROUND(q.renewal_annual_quota/4, 0) as renewal_quarterly_quota,
        ROUND(q.land_expand_annual_quota/4, 0) as land_exp_quarterly_quota,
        ROUND(COALESCE(p.new_cust_unweighted, 0), 0) as new_cust_unweighted,
        ROUND(COALESCE(p.renewal_unweighted, 0), 0) as renewal_unweighted,
        ROUND(COALESCE(p.land_exp_unweighted, 0), 0) as land_exp_unweighted,
        ROUND(COALESCE(p.new_cust_hs_weighted, 0), 0) as new_cust_hs_weighted,
        ROUND(COALESCE(p.renewal_hs_weighted, 0), 0) as renewal_hs_weighted,
        ROUND(COALESCE(p.land_exp_hs_weighted, 0), 0) as land_exp_hs_weighted,
        ROUND(COALESCE(p.new_cust_ai_weighted, 0), 0) as new_cust_ai_weighted,
        ROUND(COALESCE(p.renewal_ai_weighted, 0), 0) as renewal_ai_weighted,
        ROUND(COALESCE(p.land_exp_ai_weighted, 0), 0) as land_exp_ai_weighted,
        ROUND(COALESCE(p.new_cust_hs_weighted, 0) / NULLIF(q.new_customer_annual_quota/4, 0), 2) as new_cust_hs_coverage,
        ROUND(COALESCE(p.renewal_hs_weighted, 0) / NULLIF(q.renewal_annual_quota/4, 0), 2) as renewal_hs_coverage,
        ROUND(COALESCE(p.land_exp_hs_weighted, 0) / NULLIF(q.land_expand_annual_quota/4, 0), 2) as land_exp_hs_coverage,
        ROUND(COALESCE(p.new_cust_ai_weighted, 0) / NULLIF(q.new_customer_annual_quota/4, 0), 2) as new_cust_ai_coverage,
        ROUND(COALESCE(p.renewal_ai_weighted, 0) / NULLIF(q.renewal_annual_quota/4, 0), 2) as renewal_ai_coverage,
        ROUND(COALESCE(p.land_exp_ai_weighted, 0) / NULLIF(q.land_expand_annual_quota/4, 0), 2) as land_exp_ai_coverage,
        ROUND(COALESCE(r.new_cust_2025_won, 0), 0) as new_cust_prior_year_won,
        ROUND(COALESCE(r.renewal_2025_won, 0), 0) as renewal_prior_year_won,
        ROUND(COALESCE(r.land_exp_2025_won, 0), 0) as land_exp_prior_year_won,
        ROUND(SAFE_DIVIDE(r.new_cust_won_count, r.new_cust_won_count + r.new_cust_lost_count), 3) as new_cust_prior_year_close_rate,
        ROUND(SAFE_DIVIDE(r.renewal_won_count, r.renewal_won_count + r.renewal_lost_count), 3) as renewal_prior_year_close_rate,
        ROUND(SAFE_DIVIDE(r.land_exp_won_count, r.land_exp_won_count + r.land_exp_lost_count), 3) as land_exp_prior_year_close_rate
    FROM owner_quotas q
    LEFT JOIN owner_pipeline p ON q.owner_name = p.owner_name
    LEFT JOIN owner_2025_stats r ON q.owner_name = r.owner_name
    ORDER BY (q.new_customer_annual_quota + q.renewal_annual_quota + q.land_expand_annual_quota) DESC
    """
    try:
        client = get_client()
        results = list(client.query(query).result())
        return [dict(row) for row in results]
    except GoogleCloudError as e:
        logger.error("Failed to fetch pipeline coverage by owner: %s", e)
        return []


def get_company_metrics(fiscal_year: int = FISCAL_YEAR) -> Dict[str, Any]:
    """Fetch all company-level metrics.

    This is the main entry point for the Overview page.

    Note: Supply-side uses NPR (Net Payout Retention) terminology,
    Demand-side uses NRR (Net Revenue Retention) terminology.

    Returns:
        Dictionary with all company metrics, or empty dict if BigQuery unavailable
    """
    if not is_bigquery_available():
        logger.warning("BigQuery unavailable, returning empty metrics")
        return {}

    return {
        "revenue_ytd": get_revenue_ytd(fiscal_year),
        "take_rate": get_take_rate(fiscal_year),
        "demand_nrr": get_nrr(fiscal_year),
        "supply_npr": get_supply_npr(fiscal_year),  # NPR for suppliers
        "supply_nrr": get_supply_npr(fiscal_year),  # Alias for backward compatibility
        "customer_count": get_customer_count(fiscal_year),
        "logo_retention": get_logo_retention(fiscal_year),
        "pipeline_coverage": get_pipeline_coverage(),
        "demand_nrr_details": get_demand_nrr_details(fiscal_year),
        "supply_npr_details": get_supply_npr_details(fiscal_year),  # NPR for suppliers
        "supply_nrr_details": get_supply_npr_details(fiscal_year),  # Alias for backward compatibility
        "updated_at": datetime.now().isoformat(),
    }


# =============================================================================
# PERSON METRICS (Team Scorecard)
# =============================================================================

def get_contract_spend_pct() -> Optional[float]:
    """Fetch contract spend percentage from Upfront_Contract_Spend_Query.

    Returns:
        Spend percentage as decimal or None if query fails
    """
    query = f"""
    SELECT
        SAFE_DIVIDE(SUM(actual_spend), SUM(contract_value)) as spend_pct
    FROM `{PROJECT_ID}.{DATASET}.Upfront_Contract_Spend_Query`
    WHERE fiscal_year = {FISCAL_YEAR}
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result and result[0].spend_pct is not None:
            return float(result[0].spend_pct)
        return None
    except GoogleCloudError as e:
        logger.error("Failed to fetch contract spend: %s", e)
        return None


def get_time_to_fulfill() -> Dict[str, Any]:
    """Fetch time to fulfill contract spend metrics.

    Uses the new view that measures days from contract close date until
    100% of contract value has been invoiced. This is the TRUE "time to
    fulfill" metric - measuring actual financial completion, not just
    offer acceptance dates.

    Primary metric is median (less sensitive to outliers like old contracts).

    View: Days_to_Fulfill_Contract_Spend_From_Close_Date
    Fallback: Days_to_Fulfill_Contract_Program (legacy)

    Returns:
        Dictionary with median_days, avg_days, contract_count,
        fulfilled_count, in_progress_count
    """
    # Try new view first (measures contract close → 100% invoiced)
    # Filter to 2026 deals only for current year performance
    query_new = f"""
    SELECT
        APPROX_QUANTILES(
            CASE WHEN fulfillment_status = 'Fulfilled' THEN days_close_to_fulfill END,
            100
        )[OFFSET(50)] as median_days,
        AVG(CASE WHEN fulfillment_status = 'Fulfilled' THEN days_close_to_fulfill END) as avg_days,
        COUNT(*) as contract_count,
        COUNTIF(fulfillment_status = 'Fulfilled') as fulfilled_count,
        COUNTIF(fulfillment_status = 'In Progress') as in_progress_count
    FROM `{PROJECT_ID}.{DATASET}.Days_to_Fulfill_Contract_Spend_From_Close_Date`
    WHERE contract_close_date >= '2026-01-01'
    """

    # Fallback to legacy view if new view doesn't exist
    query_legacy = f"""
    SELECT
        APPROX_QUANTILES(days_between_first_last, 100)[OFFSET(50)] as median_days,
        AVG(days_between_first_last) as avg_days,
        COUNT(*) as contract_count,
        COUNT(*) as fulfilled_count,
        0 as in_progress_count
    FROM `{PROJECT_ID}.{DATASET}.Days_to_Fulfill_Contract_Program`
    WHERE days_between_first_last IS NOT NULL
    """

    try:
        client = get_client()

        # Use new view with 2026 filter - return data even if median is None
        # (None means no 2026 contracts fulfilled yet, which is valid data)
        try:
            result = list(client.query(query_new).result())
            if result:
                row = result[0]
                logger.info("Using new Days_to_Fulfill_Contract_Spend_From_Close_Date view (2026 only)")
                return {
                    "median_days": int(row.median_days) if row.median_days else None,
                    "avg_days": float(row.avg_days) if row.avg_days else None,
                    "contract_count": int(row.contract_count) if row.contract_count else 0,
                    "fulfilled_count": int(row.fulfilled_count) if row.fulfilled_count else 0,
                    "in_progress_count": int(row.in_progress_count) if row.in_progress_count else 0,
                }
        except Exception as e:
            logger.warning("New Time to Fulfill view not available, using legacy: %s", e)

            # Only fallback to legacy if new view query fails (not if it returns null)
            result = list(client.query(query_legacy).result())
            if result:
                row = result[0]
                logger.info("Using legacy Days_to_Fulfill_Contract_Program view")
                return {
                    "median_days": int(row.median_days) if row.median_days else None,
                    "avg_days": float(row.avg_days) if row.avg_days else None,
                    "contract_count": int(row.contract_count) if row.contract_count else 0,
                    "fulfilled_count": int(row.fulfilled_count) if row.fulfilled_count else 0,
                    "in_progress_count": 0,
                }
        return {}
    except GoogleCloudError as e:
        logger.error("Failed to fetch time to fulfill: %s", e)
        return {}


def get_avg_days_to_fulfill() -> Optional[float]:
    """Fetch average days to fulfill from Days_to_Fulfill_Contract_Program.

    Note: Consider using get_time_to_fulfill() instead for median value.

    Returns:
        Average days or None if query fails
    """
    result = get_time_to_fulfill()
    return result.get("avg_days")


def get_nps_score() -> Optional[float]:
    """Fetch NPS score from organizer_recap_NPS_score.

    Returns:
        NPS score as decimal or None if query fails
    """
    query = f"""
    SELECT AVG(nps_score) as nps
    FROM `{PROJECT_ID}.{DATASET}.organizer_recap_NPS_score`
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result and result[0].nps is not None:
            return float(result[0].nps)
        return None
    except GoogleCloudError as e:
        logger.error("Failed to fetch NPS score: %s", e)
        return None


# =============================================================================
# DETAIL VIEWS (Drill-down pages - Tier 2)
# =============================================================================

def get_nrr_by_customer(fiscal_year: int = FISCAL_YEAR) -> List[Dict[str, Any]]:
    """Fetch detailed NRR by customer for drill-down view.

    Returns:
        List of customer NRR records or empty list if query fails
    """
    query = f"""
    SELECT *
    FROM `{PROJECT_ID}.{DATASET}.net_revenue_retention_all_customers`
    WHERE qbo_customer_id != 'UNKNOWN'
    ORDER BY net_revenue_{fiscal_year} DESC
    """
    try:
        client = get_client()
        df = client.query(query).to_dataframe()
        return df.to_dict('records')
    except GoogleCloudError as e:
        logger.error("Failed to fetch NRR detail: %s", e)
        return []


def get_cohort_matrix(fiscal_year: int = FISCAL_YEAR) -> List[Dict[str, Any]]:
    """Fetch cohort retention matrix for drill-down view.

    Returns:
        List of cohort records or empty list if query fails
    """
    query = f"""
    SELECT *
    FROM `{PROJECT_ID}.{DATASET}.cohort_retention_matrix_by_customer`
    ORDER BY cohort_year, customer_name
    """
    try:
        client = get_client()
        df = client.query(query).to_dataframe()
        return df.to_dict('records')
    except GoogleCloudError as e:
        logger.error("Failed to fetch cohort matrix: %s", e)
        return []


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def run_query(query: str) -> List[Dict[str, Any]]:
    """Run an arbitrary query and return results as list of dicts.

    Args:
        query: SQL query string

    Returns:
        List of row dictionaries or empty list if query fails
    """
    try:
        client = get_client()
        df = client.query(query).to_dataframe()
        return df.to_dict('records')
    except GoogleCloudError as e:
        logger.error("Query failed: %s", e)
        return []


def load_query_file(filename: str) -> Optional[str]:
    """Load SQL query from file in queries directory.

    Args:
        filename: Name of SQL file (e.g., 'company_metrics.sql')

    Returns:
        Query string or None if file not found
    """
    query_path = QUERIES_DIR / filename
    if query_path.exists():
        return query_path.read_text()
    logger.warning("Query file not found: %s", query_path)
    return None


# =============================================================================
# DEMAND SALES METRICS
# =============================================================================

def get_win_rate_90d() -> Dict[str, Any]:
    """Fetch 90-day win rate from HubSpot deals.

    Formula: Closed Won / (Closed Won + Closed Lost) in last 90 days
    Target: 30%
    Pipeline: Default (Purchase Manual)

    Query: queries/demand-sales/win-rate-90-days.sql

    Returns:
        Dict with win_rate, won_count, lost_count, total_decided
    """
    query = f"""
    SELECT
        COUNTIF(property_hs_is_closed_won = true) AS won_count,
        COUNTIF(property_hs_is_closed_won = false) AS lost_count,
        SAFE_DIVIDE(
            COUNTIF(property_hs_is_closed_won = true),
            COUNT(*)
        ) AS win_rate
    FROM `{PROJECT_ID}.src_fivetran_hubspot.deal`
    WHERE deal_pipeline_id = 'default'
      AND is_deleted = false
      AND property_hs_is_closed = true
      AND DATE(property_closedate) >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            row = result[0]
            won = int(row.won_count) if row.won_count else 0
            lost = int(row.lost_count) if row.lost_count else 0
            return {
                "win_rate": float(row.win_rate) if row.win_rate else 0,
                "won_count": won,
                "lost_count": lost,
                "total_decided": won + lost,
            }
        return {}
    except GoogleCloudError as e:
        logger.error("Failed to fetch win rate: %s", e)
        return {}


def get_avg_deal_size_ytd(fiscal_year: int = FISCAL_YEAR) -> Dict[str, Any]:
    """Fetch average deal size for closed-won deals YTD.

    Formula: Total Closed Won $ / Closed Won Count
    Target: $150K

    Query: queries/demand-sales/avg-deal-size-ytd.sql

    Returns:
        Dict with avg_deal_size, deal_count, total_revenue
    """
    query = f"""
    SELECT
        AVG(SAFE_CAST(property_amount AS FLOAT64)) AS avg_deal_size,
        COUNT(*) AS deal_count,
        SUM(SAFE_CAST(property_amount AS FLOAT64)) AS total_revenue
    FROM `{PROJECT_ID}.src_fivetran_hubspot.deal`
    WHERE deal_pipeline_id = 'default'
      AND is_deleted = false
      AND property_hs_is_closed_won = true
      AND EXTRACT(YEAR FROM property_closedate) = {fiscal_year}
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            row = result[0]
            return {
                "avg_deal_size": float(row.avg_deal_size) if row.avg_deal_size else 0,
                "deal_count": int(row.deal_count) if row.deal_count else 0,
                "total_revenue": float(row.total_revenue) if row.total_revenue else 0,
            }
        return {}
    except GoogleCloudError as e:
        logger.error("Failed to fetch avg deal size: %s", e)
        return {}


def get_sales_cycle_length(fiscal_year: int = FISCAL_YEAR) -> Dict[str, Any]:
    """Fetch average sales cycle length for won deals.

    Formula: AVG(closedate - createdate) for closed-won deals
    Target: <=60 days

    Query: queries/demand-sales/sales-cycle-length.sql

    Returns:
        Dict with avg_days, median_days, deal_count
    """
    query = f"""
    SELECT
        AVG(DATE_DIFF(property_closedate, property_createdate, DAY)) AS avg_days,
        APPROX_QUANTILES(
            DATE_DIFF(property_closedate, property_createdate, DAY), 100
        )[OFFSET(50)] AS median_days,
        COUNT(*) AS deal_count
    FROM `{PROJECT_ID}.src_fivetran_hubspot.deal`
    WHERE deal_pipeline_id = 'default'
      AND is_deleted = false
      AND property_hs_is_closed_won = true
      AND EXTRACT(YEAR FROM property_closedate) = {fiscal_year}
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            row = result[0]
            return {
                "avg_days": float(row.avg_days) if row.avg_days else 0,
                "median_days": int(row.median_days) if row.median_days else 0,
                "deal_count": int(row.deal_count) if row.deal_count else 0,
            }
        return {}
    except GoogleCloudError as e:
        logger.error("Failed to fetch sales cycle length: %s", e)
        return {}


# =============================================================================
# MARKETING METRICS
# =============================================================================

def get_marketing_influenced_pipeline() -> Dict[str, Any]:
    """Fetch marketing-influenced pipeline using 50/50 FT+LT attribution.

    Formula: (First Touch + Last Touch) / 2 for each deal
    Only counts 10 specific marketing channels.

    Query: queries/marketing/marketing-influenced-pipeline.sql

    Returns:
        Dict with influenced_pipeline, ft_attribution, lt_attribution, deal_count
    """
    query = f"""
    WITH marketing_channels AS (
        SELECT 'DIRECT_TRAFFIC' AS channel UNION ALL SELECT 'PAID_SEARCH'
        UNION ALL SELECT 'PAID_SOCIAL' UNION ALL SELECT 'ORGANIC_SOCIAL'
        UNION ALL SELECT 'ORGANIC_SEARCH' UNION ALL SELECT 'EVENT'
        UNION ALL SELECT 'EMAIL_MARKETING' UNION ALL SELECT 'OTHER_CAMPAIGNS'
        UNION ALL SELECT 'REFERRALS' UNION ALL SELECT 'GENERAL_REFERRAL'
    ),
    deal_attribution AS (
        SELECT
            d.deal_id,
            SAFE_CAST(d.property_amount AS FLOAT64) AS deal_amount,
            c.property_hs_analytics_source AS first_touch,
            c.property_hs_analytics_source_data_2 AS last_touch
        FROM `{PROJECT_ID}.src_fivetran_hubspot.deal` d
        JOIN `{PROJECT_ID}.src_fivetran_hubspot.deal_contact` dc ON d.deal_id = dc.deal_id
        JOIN `{PROJECT_ID}.src_fivetran_hubspot.contact` c ON dc.contact_id = c.id
        WHERE d.deal_pipeline_id = 'default'
          AND d.is_deleted = false
          AND d.property_hs_is_closed = false
    )
    SELECT
        SUM((CASE WHEN da.first_touch IN (SELECT channel FROM marketing_channels) THEN da.deal_amount / 2 ELSE 0 END)
          + (CASE WHEN da.last_touch IN (SELECT channel FROM marketing_channels) THEN da.deal_amount / 2 ELSE 0 END)) AS influenced_pipeline,
        SUM(CASE WHEN da.first_touch IN (SELECT channel FROM marketing_channels) THEN da.deal_amount ELSE 0 END) AS ft_attribution,
        SUM(CASE WHEN da.last_touch IN (SELECT channel FROM marketing_channels) THEN da.deal_amount ELSE 0 END) AS lt_attribution,
        COUNT(DISTINCT da.deal_id) AS deal_count
    FROM deal_attribution da
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            row = result[0]
            return {
                "influenced_pipeline": float(row.influenced_pipeline) if row.influenced_pipeline else 0,
                "ft_attribution": float(row.ft_attribution) if row.ft_attribution else 0,
                "lt_attribution": float(row.lt_attribution) if row.lt_attribution else 0,
                "deal_count": int(row.deal_count) if row.deal_count else 0,
            }
        return {}
    except GoogleCloudError as e:
        logger.error("Failed to fetch marketing influenced pipeline: %s", e)
        return {}


def get_mql_to_sql_conversion() -> Dict[str, Any]:
    """Fetch MQL to SQL conversion rate.

    Formula: SQLs / MQLs x 100
    Target: 30%

    Query: queries/marketing/mql-to-sql-conversion.sql

    Returns:
        Dict with conversion_rate, mql_count, sql_count
    """
    query = f"""
    SELECT
        COUNTIF(property_hs_lifecyclestage_marketingqualifiedlead_date IS NOT NULL) AS mql_count,
        COUNTIF(property_hs_lifecyclestage_salesqualifiedlead_date IS NOT NULL) AS sql_count,
        SAFE_DIVIDE(
            COUNTIF(property_hs_lifecyclestage_salesqualifiedlead_date IS NOT NULL),
            COUNTIF(property_hs_lifecyclestage_marketingqualifiedlead_date IS NOT NULL)
        ) AS conversion_rate
    FROM `{PROJECT_ID}.src_fivetran_hubspot.contact`
    WHERE property_hs_lifecyclestage_marketingqualifiedlead_date IS NOT NULL
      AND EXTRACT(YEAR FROM property_hs_lifecyclestage_marketingqualifiedlead_date) = {FISCAL_YEAR}
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            row = result[0]
            return {
                "conversion_rate": float(row.conversion_rate) if row.conversion_rate else 0,
                "mql_count": int(row.mql_count) if row.mql_count else 0,
                "sql_count": int(row.sql_count) if row.sql_count else 0,
            }
        return {}
    except GoogleCloudError as e:
        logger.error("Failed to fetch MQL to SQL conversion: %s", e)
        return {}


# =============================================================================
# SUPPLY NPR (NET PAYOUT RETENTION) METRICS
# =============================================================================

def get_supplier_development() -> List[Dict[str, Any]]:
    """Fetch Supplier_Development view data.

    Returns supplier-level data including:
    - supplier_org_name: Name from MongoDB remittance or 'Unlinked (Not in Platform)'
    - core_action_state: active / loosing / lost / inactive
    - first_year: First year with payouts (cohort assignment)
    - payout_YYYY: Net payouts by year
    - npr_YYYY: Net Payout Retention by year

    Returns:
        List of supplier records or empty list if query fails
    """
    query = f"""
    SELECT *
    FROM `{PROJECT_ID}.{DATASET}.Supplier_Development`
    ORDER BY total_payout DESC
    """
    try:
        client = get_client()
        df = client.query(query).to_dataframe()
        return df.to_dict('records')
    except GoogleCloudError as e:
        logger.error("Failed to fetch Supplier Development: %s", e)
        return []


def get_supplier_cohort_matrix() -> List[Dict[str, Any]]:
    """Fetch cohort_payout_retention_matrix_by_supplier data.

    Returns cohort retention matrix with 3 charts:
    - PAYOUT_DOLLARS: Dollar totals by cohort and year
    - TOTAL: Grand total row for P&L validation
    - NPR_PERCENT: Net Payout Retention % (base year = 100%)

    Returns:
        List of cohort records or empty list if query fails
    """
    query = f"""
    SELECT *
    FROM `{PROJECT_ID}.{DATASET}.cohort_payout_retention_matrix_by_supplier`
    ORDER BY
        CASE chart WHEN 'PAYOUT_DOLLARS' THEN 1 WHEN 'TOTAL' THEN 2 WHEN 'NPR_PERCENT' THEN 3 END,
        first_year NULLS LAST
    """
    try:
        client = get_client()
        df = client.query(query).to_dataframe()
        return df.to_dict('records')
    except GoogleCloudError as e:
        logger.error("Failed to fetch supplier cohort matrix: %s", e)
        return []


def get_core_action_state_counts(entity: str = 'supplier') -> Dict[str, Any]:
    """Fetch Active/Loosing/Lost counts for dashboard.

    Args:
        entity: 'supplier' or 'customer'

    Returns:
        Dict with counts and totals by state:
        - active: count, 2024 total, 2025 total
        - loosing: count, 2024 total, 2025 total
        - lost: count, 2024 total, 2025 total
        - total: aggregate counts
    """
    if entity == 'supplier':
        query = f"""
        WITH payout_accounts AS (
          SELECT id as account_id
          FROM `{PROJECT_ID}.src_fivetran_qbo.account`
          WHERE _fivetran_deleted = FALSE
            AND account_number IN ('4200', '4210', '4220', '4230')
        ),
        remittance_supplier_map AS (
          SELECT DISTINCT rli.bill_number, rli.ctx.supplier.org.name as supplier_org_name
          FROM `{PROJECT_ID}.mongodb.remittance_line_items` rli
          WHERE rli.bill_number IS NOT NULL AND rli.ctx.supplier.org.name IS NOT NULL
        ),
        qbo_payout_bills AS (
          SELECT REGEXP_REPLACE(b.doc_number, r'_\\d+$', '') as base_bill_number,
            EXTRACT(YEAR FROM b.transaction_date) as txn_year,
            SUM(CAST(bl.amount AS FLOAT64)) as bill_amount
          FROM `{PROJECT_ID}.src_fivetran_qbo.bill` b
          JOIN `{PROJECT_ID}.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
          JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
          WHERE b._fivetran_deleted = FALSE AND EXTRACT(YEAR FROM b.transaction_date) IN (2024, 2025)
          GROUP BY 1, 2
        ),
        qbo_payout_credits AS (
          SELECT REGEXP_REPLACE(vc.doc_number, r'(_credit|c\\d+)$', '') as bill_number,
            EXTRACT(YEAR FROM vc.transaction_date) as credit_year,
            SUM(CAST(vcl.amount AS FLOAT64)) as credit_amount
          FROM `{PROJECT_ID}.src_fivetran_qbo.vendor_credit` vc
          JOIN `{PROJECT_ID}.src_fivetran_qbo.vendor_credit_line` vcl ON vc.id = vcl.vendor_credit_id
          JOIN payout_accounts pa ON vcl.account_expense_account_id = pa.account_id
          WHERE vc._fivetran_deleted = FALSE
            AND REGEXP_CONTAINS(vc.doc_number, r'(_credit|c\\d+)$')
            AND EXTRACT(YEAR FROM vc.transaction_date) IN (2024, 2025)
          GROUP BY 1, 2
        ),
        bills_with_supplier AS (
          SELECT COALESCE(rsm.supplier_org_name, 'Unlinked') as supplier_org_name, b.txn_year,
            b.bill_amount, 0.0 as credit_amount
          FROM qbo_payout_bills b
          LEFT JOIN remittance_supplier_map rsm ON b.base_bill_number = rsm.bill_number
        ),
        credits_with_supplier AS (
          SELECT COALESCE(rsm.supplier_org_name, 'Unlinked') as supplier_org_name, c.credit_year as txn_year,
            0.0 as bill_amount, c.credit_amount
          FROM qbo_payout_credits c
          LEFT JOIN remittance_supplier_map rsm ON c.bill_number = rsm.bill_number
        ),
        all_transactions AS (
          SELECT * FROM bills_with_supplier UNION ALL SELECT * FROM credits_with_supplier
        ),
        supplier_yearly_payouts AS (
          SELECT supplier_org_name, txn_year, SUM(bill_amount) - SUM(credit_amount) as net_payouts
          FROM all_transactions GROUP BY supplier_org_name, txn_year
        ),
        supplier_pivot AS (
          SELECT supplier_org_name,
            SUM(CASE WHEN txn_year = 2024 THEN net_payouts ELSE 0 END) as payout_2024,
            SUM(CASE WHEN txn_year = 2025 THEN net_payouts ELSE 0 END) as payout_2025
          FROM supplier_yearly_payouts GROUP BY supplier_org_name
        ),
        supplier_states AS (
          SELECT supplier_org_name, payout_2024, payout_2025,
            CASE
              WHEN payout_2025 > 0 AND payout_2024 > 0 THEN
                CASE WHEN (payout_2024 - payout_2025) / NULLIF(payout_2024, 0) > 0.50 THEN 'loosing' ELSE 'active' END
              WHEN payout_2025 > 0 THEN 'active'
              WHEN payout_2024 > 0 THEN 'lost'
              ELSE 'inactive'
            END as core_action_state
          FROM supplier_pivot WHERE payout_2024 > 0 OR payout_2025 > 0
        )
        SELECT core_action_state, COUNT(*) as count,
          ROUND(SUM(payout_2024), 2) as total_2024, ROUND(SUM(payout_2025), 2) as total_2025
        FROM supplier_states GROUP BY core_action_state
        """
    else:
        # Customer entity
        query = f"""
        WITH customer_years AS (
          SELECT customer_id, COALESCE(Net_Revenue_2024, 0) as revenue_2024,
            COALESCE(Net_Revenue_2025, 0) as revenue_2025
          FROM `{PROJECT_ID}.{DATASET}.customer_development`
          WHERE customer_id IS NOT NULL
        ),
        customer_states AS (
          SELECT DISTINCT customer_id, revenue_2024, revenue_2025,
            CASE
              WHEN revenue_2025 > 0 AND revenue_2024 > 0 THEN
                CASE WHEN (revenue_2024 - revenue_2025) / NULLIF(revenue_2024, 0) > 0.50 THEN 'loosing' ELSE 'active' END
              WHEN revenue_2025 > 0 THEN 'active'
              WHEN revenue_2024 > 0 THEN 'lost'
              ELSE 'inactive'
            END as core_action_state
          FROM customer_years WHERE revenue_2024 > 0 OR revenue_2025 > 0
        )
        SELECT core_action_state, COUNT(DISTINCT customer_id) as count,
          ROUND(SUM(revenue_2024), 2) as total_2024, ROUND(SUM(revenue_2025), 2) as total_2025
        FROM customer_states GROUP BY core_action_state
        """

    try:
        client = get_client()
        results = list(client.query(query).result())

        response = {
            "active": {"count": 0, "total_2024": 0, "total_2025": 0},
            "loosing": {"count": 0, "total_2024": 0, "total_2025": 0},
            "lost": {"count": 0, "total_2024": 0, "total_2025": 0},
            "inactive": {"count": 0, "total_2024": 0, "total_2025": 0},
            "entity": entity,
        }

        for row in results:
            state = row.core_action_state
            if state in response:
                response[state]["count"] = int(row.count or 0)
                response[state]["total_2024"] = float(row.total_2024 or 0)
                response[state]["total_2025"] = float(row.total_2025 or 0)

        # Calculate totals
        response["total"] = {
            "count": sum(response[s]["count"] for s in ["active", "loosing", "lost", "inactive"]),
            "total_2024": sum(response[s]["total_2024"] for s in ["active", "loosing", "lost", "inactive"]),
            "total_2025": sum(response[s]["total_2025"] for s in ["active", "loosing", "lost", "inactive"]),
        }

        return response
    except GoogleCloudError as e:
        logger.error("Failed to fetch core action state counts for %s: %s", entity, e)
        return {}


def get_supply_npr_summary_by_year() -> List[Dict[str, Any]]:
    """Fetch Supply NPR summary by year for P&L validation.

    Returns aggregate supplier payouts by year that should match QBO P&L exactly.

    Returns:
        List of yearly summary records with gross_bills, vendor_credits, net_payouts, npr_vs_prior_year
    """
    query = f"""
    WITH payout_accounts AS (
      SELECT id as account_id
      FROM `{PROJECT_ID}.src_fivetran_qbo.account`
      WHERE _fivetran_deleted = FALSE AND account_number IN ('4200', '4210', '4220', '4230')
    ),
    all_bills AS (
      SELECT EXTRACT(YEAR FROM b.transaction_date) as txn_year, SUM(CAST(bl.amount AS FLOAT64)) as gross_bills
      FROM `{PROJECT_ID}.src_fivetran_qbo.bill` b
      JOIN `{PROJECT_ID}.src_fivetran_qbo.bill_line` bl ON b.id = bl.bill_id
      JOIN payout_accounts pa ON bl.account_expense_account_id = pa.account_id
      WHERE b._fivetran_deleted = FALSE
      GROUP BY 1
    ),
    all_credits AS (
      SELECT EXTRACT(YEAR FROM vc.transaction_date) as txn_year, SUM(CAST(vcl.amount AS FLOAT64)) as vendor_credits
      FROM `{PROJECT_ID}.src_fivetran_qbo.vendor_credit` vc
      JOIN `{PROJECT_ID}.src_fivetran_qbo.vendor_credit_line` vcl ON vc.id = vcl.vendor_credit_id
      JOIN payout_accounts pa ON vcl.account_expense_account_id = pa.account_id
      WHERE vc._fivetran_deleted = FALSE
      GROUP BY 1
    ),
    yearly_totals AS (
      SELECT COALESCE(b.txn_year, c.txn_year) as year,
        COALESCE(b.gross_bills, 0) as gross_bills, COALESCE(c.vendor_credits, 0) as vendor_credits,
        COALESCE(b.gross_bills, 0) - COALESCE(c.vendor_credits, 0) as net_payouts
      FROM all_bills b FULL OUTER JOIN all_credits c ON b.txn_year = c.txn_year
    )
    SELECT year, ROUND(gross_bills, 2) as gross_bills, ROUND(vendor_credits, 2) as vendor_credits,
      ROUND(net_payouts, 2) as net_payouts,
      ROUND(net_payouts / NULLIF(LAG(net_payouts) OVER (ORDER BY year), 0) * 100, 1) as npr_vs_prior_year
    FROM yearly_totals WHERE year >= 2022 ORDER BY year
    """
    try:
        client = get_client()
        df = client.query(query).to_dataframe()
        return df.to_dict('records')
    except GoogleCloudError as e:
        logger.error("Failed to fetch supply NPR summary: %s", e)
        return []

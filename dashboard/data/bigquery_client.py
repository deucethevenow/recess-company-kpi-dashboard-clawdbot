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


def get_supply_nrr(fiscal_year: int = FISCAL_YEAR) -> Optional[float]:
    """Fetch Supply Net Revenue Retention from Supplier_Metrics view.

    Formula: Payouts to prior year suppliers in current year / Their prior year payouts

    Example for 2026:
    - Suppliers who had payouts in 2025
    - Their 2026 payouts / Their 2025 payouts

    Returns:
        Supply NRR as decimal (e.g., 0.67 for 67%) or None if query fails
    """
    prior_year = fiscal_year - 1

    query = f"""
    WITH supplier_yearly AS (
        SELECT
            Supplier_Name,
            SUM(CASE WHEN Offer_Accepted_Year = {prior_year} THEN Payouts ELSE 0 END) as payouts_prior,
            SUM(CASE WHEN Offer_Accepted_Year = {fiscal_year} THEN Payouts ELSE 0 END) as payouts_current
        FROM `{PROJECT_ID}.{DATASET}.Supplier_Metrics`
        GROUP BY Supplier_Name
    )
    SELECT
        SAFE_DIVIDE(
            SUM(CASE WHEN payouts_prior > 0 THEN payouts_current END),
            SUM(CASE WHEN payouts_prior > 0 THEN payouts_prior END)
        ) as supply_nrr
    FROM supplier_yearly
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result and result[0].supply_nrr is not None:
            return float(result[0].supply_nrr)
        return None
    except GoogleCloudError as e:
        logger.error("Failed to fetch supply NRR: %s", e)
        return None


def get_supply_nrr_details(fiscal_year: int = FISCAL_YEAR) -> Dict[str, Any]:
    """Fetch detailed Supply NRR with both current year and prior year comparison.

    Returns dict with:
    - current_year: 2026 YTD data (2025 suppliers' 2026 payouts vs their 2025 payouts)
    - prior_year: 2025 Actuals (2024 suppliers' 2025 payouts vs their 2024 payouts)

    Returns:
        Dictionary with Supply NRR details for both periods
    """
    prior_year = fiscal_year - 1
    prior_prior_year = fiscal_year - 2

    query = f"""
    WITH supplier_yearly AS (
        SELECT
            Supplier_Name,
            SUM(CASE WHEN Offer_Accepted_Year = {prior_prior_year} THEN Payouts ELSE 0 END) as payouts_{prior_prior_year},
            SUM(CASE WHEN Offer_Accepted_Year = {prior_year} THEN Payouts ELSE 0 END) as payouts_{prior_year},
            SUM(CASE WHEN Offer_Accepted_Year = {fiscal_year} THEN Payouts ELSE 0 END) as payouts_{fiscal_year}
        FROM `{PROJECT_ID}.{DATASET}.Supplier_Metrics`
        GROUP BY Supplier_Name
    )
    SELECT
        -- 2024 cohort in 2025 (prior complete year comparison)
        SUM(CASE WHEN payouts_{prior_prior_year} > 0 THEN payouts_{prior_prior_year} END) as prior_cohort_original,
        SUM(CASE WHEN payouts_{prior_prior_year} > 0 THEN payouts_{prior_year} END) as prior_cohort_next_year,
        COUNT(CASE WHEN payouts_{prior_prior_year} > 0 THEN 1 END) as prior_cohort_count,
        -- 2025 cohort in 2026 (current year)
        SUM(CASE WHEN payouts_{prior_year} > 0 THEN payouts_{prior_year} END) as current_cohort_original,
        SUM(CASE WHEN payouts_{prior_year} > 0 THEN payouts_{fiscal_year} END) as current_cohort_next_year,
        COUNT(CASE WHEN payouts_{prior_year} > 0 THEN 1 END) as current_cohort_count
    FROM supplier_yearly
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
                "nrr_pct": (curr_next / curr_orig * 100) if curr_orig > 0 else 0,
                "label": f"{fiscal_year} YTD"
            },
            "prior_year": {
                "cohort": prior_prior_year,
                "cohort_original_payouts": prior_orig,
                "cohort_next_year_payouts": prior_next,
                "supplier_count": int(row.prior_cohort_count or 0),
                "nrr_pct": (prior_next / prior_orig * 100) if prior_orig > 0 else 0,
                "label": f"{prior_year} Actuals"
            }
        }
    except GoogleCloudError as e:
        logger.error("Failed to fetch supply NRR details: %s", e)
        return {}


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
        "supply_nrr": get_supply_nrr(fiscal_year),
        "customer_count": get_customer_count(fiscal_year),
        "logo_retention": get_logo_retention(fiscal_year),
        "pipeline_coverage": get_pipeline_coverage(),
        "demand_nrr_details": get_demand_nrr_details(fiscal_year),
        "supply_nrr_details": get_supply_nrr_details(fiscal_year),
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
    """Fetch time to fulfill metrics from Days_to_Fulfill_Contract_Program.

    Uses median as primary metric (less sensitive to outliers).
    Also returns average for reference.

    Returns:
        Dictionary with median_days, avg_days, contract_count
    """
    query = f"""
    SELECT
        APPROX_QUANTILES(days_between_first_last, 100)[OFFSET(50)] as median_days,
        AVG(days_between_first_last) as avg_days,
        COUNT(*) as contract_count
    FROM `{PROJECT_ID}.{DATASET}.Days_to_Fulfill_Contract_Program`
    WHERE days_between_first_last IS NOT NULL
    """
    try:
        client = get_client()
        result = list(client.query(query).result())
        if result:
            row = result[0]
            return {
                "median_days": int(row.median_days) if row.median_days else None,
                "avg_days": float(row.avg_days) if row.avg_days else None,
                "contract_count": int(row.contract_count) if row.contract_count else 0,
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

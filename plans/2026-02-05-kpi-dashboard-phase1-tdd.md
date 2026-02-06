# KPI Dashboard Phase 1 — Company Health + Department Metrics (TDD)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy all existing SQL queries to BigQuery as reusable functions, connect them to the Streamlit dashboard via the data layer, and render department-specific pages — all using strict TDD (Red-Green-Refactor).

**Architecture:** Each department's metrics flow through 3 layers: BigQuery query functions (`bigquery_client.py`) → data aggregation (`data_layer.py`) → Streamlit page rendering (`app.py`). Tests mock BigQuery at the client boundary so they run without credentials. Existing patterns in `bigquery_client.py` are followed exactly.

**Tech Stack:** Python 3.9, pytest, unittest.mock, Streamlit, google-cloud-bigquery, Plotly

---

## Prerequisites

- Project root: `/Users/deucethevenowworkm1/Projects/company-kpi-dashboard`
- Dashboard code: `dashboard/` (Streamlit app)
- SQL queries: `queries/` (by department)
- BigQuery: project `stitchdata-384118`, dataset `App_KPI_Dashboard`
- Virtual env: `dashboard/venv/`

---

## Task 1: Set Up Test Infrastructure

**Files:**
- Create: `dashboard/tests/__init__.py`
- Create: `dashboard/tests/conftest.py`
- Create: `dashboard/tests/test_bigquery_client.py`
- Modify: `dashboard/requirements.txt` (add pytest)

**Step 1: Create test directory and conftest with BigQuery mock fixtures**

```bash
mkdir -p /Users/deucethevenowworkm1/Projects/company-kpi-dashboard/dashboard/tests
```

Create `dashboard/tests/__init__.py`:
```python
```

Create `dashboard/tests/conftest.py`:
```python
"""Shared test fixtures for KPI Dashboard tests.

All BigQuery tests use mocked clients to run without credentials.
"""
import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest


@pytest.fixture
def mock_bq_client():
    """Mock BigQuery client that returns configurable query results."""
    client = MagicMock()
    return client


@pytest.fixture
def mock_bq_result():
    """Factory fixture to create mock BigQuery query results.

    Usage:
        result = mock_bq_result([{"column": value}])
    """
    def _make_result(rows):
        """Create mock rows that behave like BigQuery Row objects."""
        mock_rows = []
        for row_data in rows:
            mock_row = MagicMock()
            for key, value in row_data.items():
                setattr(mock_row, key, value)
            # Support dict() conversion
            mock_row.__iter__ = lambda self, d=row_data: iter(d.items())
            mock_row.keys = lambda d=row_data: d.keys()
            mock_row.values = lambda d=row_data: d.values()
            mock_rows.append(mock_row)
        return mock_rows
    return _make_result


@pytest.fixture
def targets_json(tmp_path):
    """Create a temporary targets.json for testing."""
    targets = {
        "company": {
            "revenue_target": 10_000_000,
            "take_rate_target": 0.50,
            "nrr_target": 1.10,
            "customer_count_target": 75,
            "pipeline_target": 6.0,
            "logo_retention_target": 0.50,
        },
        "people": {},
        "last_updated": "2026-02-05T00:00:00",
        "updated_by": "test",
    }
    targets_file = tmp_path / "targets.json"
    targets_file.write_text(json.dumps(targets))
    return targets_file


@pytest.fixture
def sql_queries_dir():
    """Path to the SQL query files."""
    return Path(__file__).parent.parent.parent / "queries"
```

**Step 2: Write a smoke test to verify test infrastructure works**

Create `dashboard/tests/test_bigquery_client.py`:
```python
"""Tests for BigQuery client functions.

All tests mock the BigQuery client — no credentials required.
"""
from unittest.mock import patch, MagicMock

import pytest


def test_fixtures_work(mock_bq_client, mock_bq_result):
    """Smoke test: verify test fixtures are functional."""
    rows = mock_bq_result([{"value": 42}])
    assert rows[0].value == 42
    assert mock_bq_client is not None
```

**Step 3: Install pytest and run to verify GREEN**

```bash
cd /Users/deucethevenowworkm1/Projects/company-kpi-dashboard/dashboard
source venv/bin/activate
pip install pytest
pytest tests/test_bigquery_client.py::test_fixtures_work -v
```

Expected: `1 passed`

**Step 4: Commit**

```bash
git add dashboard/tests/ dashboard/requirements.txt
git commit -m "test: add test infrastructure with BigQuery mock fixtures"
```

---

## Task 2: COO/Ops — Take Rate Query Function (TDD)

**Files:**
- Modify: `dashboard/tests/test_bigquery_client.py`
- Modify: `dashboard/data/bigquery_client.py`
- Reference: `queries/coo-ops/take-rate.sql`

**Step 1: Write the failing test**

Add to `dashboard/tests/test_bigquery_client.py`:
```python
class TestGetTakeRate:
    """Tests for get_take_rate BigQuery function."""

    @patch("data.bigquery_client.get_client")
    def test_returns_take_rate_as_decimal(self, mock_get_client, mock_bq_result):
        """Take rate should return decimal (e.g., 0.49 for 49%)."""
        from data.bigquery_client import get_take_rate

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        # Mock: GMV = $7.92M, Net Revenue = $3.89M → Take Rate = 0.491
        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([
            {"take_rate": 0.491, "gmv": 7_920_000}
        ])
        mock_client.query.return_value = mock_query_job

        result = get_take_rate(fiscal_year=2025)
        assert result == pytest.approx(0.491, abs=0.001)

    @patch("data.bigquery_client.get_client")
    def test_returns_none_on_error(self, mock_get_client):
        """Should return None when BigQuery query fails."""
        from data.bigquery_client import get_take_rate
        from google.cloud.exceptions import GoogleCloudError

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.query.side_effect = GoogleCloudError("Connection failed")

        result = get_take_rate(fiscal_year=2025)
        assert result is None

    @patch("data.bigquery_client.get_client")
    def test_falls_back_to_prior_year_when_low_gmv(self, mock_get_client, mock_bq_result):
        """When current year GMV < $100K, should fall back to prior year."""
        from data.bigquery_client import get_take_rate

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        # First call (2026): low GMV
        low_gmv_result = MagicMock()
        low_gmv_result.result.return_value = mock_bq_result([
            {"take_rate": 0.5, "gmv": 50_000}
        ])
        # Second call (2025 fallback): real data
        real_result = MagicMock()
        real_result.result.return_value = mock_bq_result([
            {"take_rate": 0.493, "gmv": 7_920_000}
        ])
        mock_client.query.side_effect = [low_gmv_result, real_result]

        result = get_take_rate(fiscal_year=2026)
        assert result == pytest.approx(0.493, abs=0.001)
        assert mock_client.query.call_count == 2
```

**Step 2: Run test to verify it fails**

```bash
cd /Users/deucethevenowworkm1/Projects/company-kpi-dashboard/dashboard
source venv/bin/activate
pytest tests/test_bigquery_client.py::TestGetTakeRate -v
```

Expected: PASS (function already exists in bigquery_client.py)

Note: `get_take_rate` already exists. This test **validates the existing implementation**. If tests pass, the function is confirmed working. If they fail, we fix the function.

**Step 3: Run tests and verify GREEN**

```bash
pytest tests/test_bigquery_client.py::TestGetTakeRate -v
```

Expected: `3 passed`

**Step 4: Commit**

```bash
git add dashboard/tests/test_bigquery_client.py
git commit -m "test: add take rate query tests (validates existing implementation)"
```

---

## Task 3: COO/Ops — Invoice Collection Rate (TDD)

**Files:**
- Modify: `dashboard/tests/test_bigquery_client.py`
- Modify: `dashboard/data/bigquery_client.py`
- Reference: `queries/coo-ops/invoice-collection-rate.sql`

**Step 1: Write the failing test**

Add to `dashboard/tests/test_bigquery_client.py`:
```python
class TestGetInvoiceCollectionRate:
    """Tests for COO/Ops invoice collection rate metric."""

    @patch("data.bigquery_client.get_client")
    def test_returns_collection_rate_as_decimal(self, mock_get_client, mock_bq_result):
        """Invoice collection rate: paid invoices / total due invoices."""
        from data.bigquery_client import get_invoice_collection_rate

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([{
            "paid_invoices": 95,
            "total_due_invoices": 100,
            "collection_rate_pct": 95.0,
        }])
        mock_client.query.return_value = mock_query_job

        result = get_invoice_collection_rate()
        assert result["collection_rate"] == pytest.approx(0.95, abs=0.01)
        assert result["paid_count"] == 95
        assert result["total_count"] == 100

    @patch("data.bigquery_client.get_client")
    def test_returns_none_on_error(self, mock_get_client):
        """Should return empty dict when query fails."""
        from data.bigquery_client import get_invoice_collection_rate
        from google.cloud.exceptions import GoogleCloudError

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.query.side_effect = GoogleCloudError("fail")

        result = get_invoice_collection_rate()
        assert result == {}
```

**Step 2: Run test to verify it FAILS (function doesn't exist yet)**

```bash
pytest tests/test_bigquery_client.py::TestGetInvoiceCollectionRate -v
```

Expected: FAIL with `ImportError: cannot import name 'get_invoice_collection_rate'`

**Step 3: Write minimal implementation**

Add to `dashboard/data/bigquery_client.py` after `get_take_rate`:
```python
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
```

**Step 4: Run test to verify it PASSES**

```bash
pytest tests/test_bigquery_client.py::TestGetInvoiceCollectionRate -v
```

Expected: `2 passed`

**Step 5: Commit**

```bash
git add dashboard/data/bigquery_client.py dashboard/tests/test_bigquery_client.py
git commit -m "feat: add invoice collection rate BigQuery function with tests"
```

---

## Task 4: COO/Ops — Overdue Invoices (TDD)

**Files:**
- Modify: `dashboard/tests/test_bigquery_client.py`
- Modify: `dashboard/data/bigquery_client.py`
- Reference: `queries/coo-ops/overdue-invoices.sql`

**Step 1: Write the failing test**

```python
class TestGetOverdueInvoices:
    """Tests for overdue invoices metric."""

    @patch("data.bigquery_client.get_client")
    def test_returns_count_and_amount(self, mock_get_client, mock_bq_result):
        """Should return count and dollar amount of overdue invoices."""
        from data.bigquery_client import get_overdue_invoices

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([{
            "overdue_count": 4,
            "overdue_amount": 45_000.0,
        }])
        mock_client.query.return_value = mock_query_job

        result = get_overdue_invoices()
        assert result["count"] == 4
        assert result["amount"] == 45_000.0

    @patch("data.bigquery_client.get_client")
    def test_returns_empty_dict_on_error(self, mock_get_client):
        """Should return empty dict when query fails."""
        from data.bigquery_client import get_overdue_invoices
        from google.cloud.exceptions import GoogleCloudError

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.query.side_effect = GoogleCloudError("fail")

        result = get_overdue_invoices()
        assert result == {}
```

**Step 2: Run test to verify FAIL**

```bash
pytest tests/test_bigquery_client.py::TestGetOverdueInvoices -v
```

Expected: FAIL — `ImportError: cannot import name 'get_overdue_invoices'`

**Step 3: Write minimal implementation**

```python
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
```

**Step 4: Run test to verify PASS**

```bash
pytest tests/test_bigquery_client.py::TestGetOverdueInvoices -v
```

Expected: `2 passed`

**Step 5: Commit**

```bash
git add dashboard/data/bigquery_client.py dashboard/tests/test_bigquery_client.py
git commit -m "feat: add overdue invoices BigQuery function with tests"
```

---

## Task 5: COO/Ops — Working Capital (TDD)

**Files:**
- Modify: `dashboard/tests/test_bigquery_client.py`
- Modify: `dashboard/data/bigquery_client.py`
- Reference: `queries/coo-ops/working-capital.sql`

**Step 1: Write the failing test**

```python
class TestGetWorkingCapital:
    """Tests for working capital metric (shared COO + CEO)."""

    @patch("data.bigquery_client.get_client")
    def test_returns_working_capital(self, mock_get_client, mock_bq_result):
        """Working Capital = Current Assets - Current Liabilities."""
        from data.bigquery_client import get_working_capital

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([{
            "current_assets": 2_000_000.0,
            "current_liabilities": 800_000.0,
            "working_capital": 1_200_000.0,
        }])
        mock_client.query.return_value = mock_query_job

        result = get_working_capital()
        assert result["working_capital"] == 1_200_000.0
        assert result["current_assets"] == 2_000_000.0
        assert result["current_liabilities"] == 800_000.0
```

**Step 2: Run test — FAIL**

```bash
pytest tests/test_bigquery_client.py::TestGetWorkingCapital -v
```

**Step 3: Implement**

```python
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
```

**Step 4: Run test — PASS**

```bash
pytest tests/test_bigquery_client.py::TestGetWorkingCapital -v
```

**Step 5: Commit**

```bash
git add dashboard/data/bigquery_client.py dashboard/tests/test_bigquery_client.py
git commit -m "feat: add working capital BigQuery function with tests"
```

---

## Task 6: COO/Ops — Months of Runway (TDD)

**Files:**
- Modify: `dashboard/tests/test_bigquery_client.py`
- Modify: `dashboard/data/bigquery_client.py`
- Reference: `queries/coo-ops/months-of-runway.sql`

**Step 1: Write the failing test**

```python
class TestGetMonthsOfRunway:
    """Tests for months of runway metric (shared COO + CEO)."""

    @patch("data.bigquery_client.get_client")
    def test_returns_months_of_runway(self, mock_get_client, mock_bq_result):
        """Months of Runway = Cash Balance / Avg Monthly Burn (3mo)."""
        from data.bigquery_client import get_months_of_runway

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([{
            "cash_balance": 600_000.0,
            "avg_monthly_burn": 50_000.0,
            "months_of_runway": 12.0,
        }])
        mock_client.query.return_value = mock_query_job

        result = get_months_of_runway()
        assert result["months"] == 12.0
        assert result["cash_balance"] == 600_000.0
        assert result["avg_monthly_burn"] == 50_000.0

    @patch("data.bigquery_client.get_client")
    def test_returns_empty_on_zero_burn(self, mock_get_client, mock_bq_result):
        """When burn is zero, should handle gracefully."""
        from data.bigquery_client import get_months_of_runway

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([{
            "cash_balance": 600_000.0,
            "avg_monthly_burn": 0,
            "months_of_runway": None,
        }])
        mock_client.query.return_value = mock_query_job

        result = get_months_of_runway()
        assert result["months"] is None
```

**Step 2: Run test — FAIL**

```bash
pytest tests/test_bigquery_client.py::TestGetMonthsOfRunway -v
```

**Step 3: Implement**

```python
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
```

**Step 4: Run test — PASS**

```bash
pytest tests/test_bigquery_client.py::TestGetMonthsOfRunway -v
```

**Step 5: Commit**

```bash
git add dashboard/data/bigquery_client.py dashboard/tests/test_bigquery_client.py
git commit -m "feat: add months of runway BigQuery function with tests"
```

---

## Task 7: Demand Sales — Win Rate, Avg Deal Size, Sales Cycle (TDD)

**Files:**
- Create: `dashboard/tests/test_demand_sales.py`
- Modify: `dashboard/data/bigquery_client.py`
- Reference: `queries/demand-sales/win-rate-90-days.sql`, `avg-deal-size-ytd.sql`, `sales-cycle-length.sql`

**Step 1: Write the failing tests**

Create `dashboard/tests/test_demand_sales.py`:
```python
"""Tests for Demand Sales BigQuery functions."""
from unittest.mock import patch, MagicMock

import pytest


class TestGetWinRate:
    """Tests for 90-day win rate."""

    @patch("data.bigquery_client.get_client")
    def test_returns_win_rate(self, mock_get_client, mock_bq_result):
        from data.bigquery_client import get_win_rate_90d

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([{
            "won_count": 7,
            "lost_count": 16,
            "win_rate": 0.304,
        }])
        mock_client.query.return_value = mock_query_job

        result = get_win_rate_90d()
        assert result["win_rate"] == pytest.approx(0.304, abs=0.01)
        assert result["won_count"] == 7
        assert result["total_decided"] == 23


class TestGetAvgDealSize:
    """Tests for average deal size YTD."""

    @patch("data.bigquery_client.get_client")
    def test_returns_avg_deal_size(self, mock_get_client, mock_bq_result):
        from data.bigquery_client import get_avg_deal_size_ytd

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([{
            "avg_deal_size": 155_000.0,
            "deal_count": 12,
            "total_revenue": 1_860_000.0,
        }])
        mock_client.query.return_value = mock_query_job

        result = get_avg_deal_size_ytd()
        assert result["avg_deal_size"] == 155_000.0
        assert result["deal_count"] == 12


class TestGetSalesCycleLength:
    """Tests for average sales cycle length."""

    @patch("data.bigquery_client.get_client")
    def test_returns_avg_days(self, mock_get_client, mock_bq_result):
        from data.bigquery_client import get_sales_cycle_length

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([{
            "avg_days": 55.0,
            "median_days": 48,
            "deal_count": 12,
        }])
        mock_client.query.return_value = mock_query_job

        result = get_sales_cycle_length()
        assert result["avg_days"] == 55.0
        assert result["median_days"] == 48
```

**Step 2: Run tests — FAIL**

```bash
pytest tests/test_demand_sales.py -v
```

Expected: FAIL — `ImportError` for all three functions

**Step 3: Implement all three functions**

Add to `dashboard/data/bigquery_client.py`:
```python
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
      AND property_closedate >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
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
```

**Step 4: Run tests — PASS**

```bash
pytest tests/test_demand_sales.py -v
```

Expected: `3 passed`

**Step 5: Commit**

```bash
git add dashboard/data/bigquery_client.py dashboard/tests/test_demand_sales.py
git commit -m "feat: add demand sales BigQuery functions (win rate, deal size, cycle) with tests"
```

---

## Task 8: Marketing — Attribution & Funnel (TDD)

**Files:**
- Create: `dashboard/tests/test_marketing.py`
- Modify: `dashboard/data/bigquery_client.py`
- Reference: `queries/marketing/marketing-influenced-pipeline.sql`, `mql-to-sql-conversion.sql`

**Step 1: Write failing tests**

Create `dashboard/tests/test_marketing.py`:
```python
"""Tests for Marketing BigQuery functions."""
from unittest.mock import patch, MagicMock

import pytest


class TestGetMarketingInfluencedPipeline:
    """Tests for marketing-influenced pipeline (50/50 FT+LT attribution)."""

    @patch("data.bigquery_client.get_client")
    def test_returns_influenced_pipeline(self, mock_get_client, mock_bq_result):
        from data.bigquery_client import get_marketing_influenced_pipeline

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([{
            "influenced_pipeline": 2_400_000.0,
            "ft_attribution": 1_800_000.0,
            "lt_attribution": 2_100_000.0,
            "deal_count": 15,
        }])
        mock_client.query.return_value = mock_query_job

        result = get_marketing_influenced_pipeline()
        assert result["influenced_pipeline"] == 2_400_000.0
        assert result["deal_count"] == 15


class TestGetMqlToSqlConversion:
    """Tests for MQL to SQL conversion rate."""

    @patch("data.bigquery_client.get_client")
    def test_returns_conversion_rate(self, mock_get_client, mock_bq_result):
        from data.bigquery_client import get_mql_to_sql_conversion

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([{
            "mql_count": 100,
            "sql_count": 33,
            "conversion_rate": 0.33,
        }])
        mock_client.query.return_value = mock_query_job

        result = get_mql_to_sql_conversion()
        assert result["conversion_rate"] == pytest.approx(0.33, abs=0.01)
        assert result["mql_count"] == 100
```

**Step 2: Run — FAIL**

```bash
pytest tests/test_marketing.py -v
```

**Step 3: Implement**

```python
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
      AND EXTRACT(YEAR FROM SAFE.PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*SZ',
          property_hs_lifecyclestage_marketingqualifiedlead_date)) = {FISCAL_YEAR}
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
```

**Step 4: Run — PASS**

```bash
pytest tests/test_marketing.py -v
```

**Step 5: Commit**

```bash
git add dashboard/data/bigquery_client.py dashboard/tests/test_marketing.py
git commit -m "feat: add marketing BigQuery functions (attribution, MQL conversion) with tests"
```

---

## Task 9: Data Layer Integration — Wire New Functions (TDD)

**Files:**
- Create: `dashboard/tests/test_data_layer.py`
- Modify: `dashboard/data/data_layer.py`

**Step 1: Write failing test for COO metrics aggregation**

Create `dashboard/tests/test_data_layer.py`:
```python
"""Tests for the data layer aggregation."""
from unittest.mock import patch, MagicMock

import pytest


class TestGetCOOMetrics:
    """Tests for COO/Ops department metrics aggregation."""

    @patch("data.data_layer._bigquery_available", True)
    @patch("data.data_layer.USE_BIGQUERY", True)
    @patch("data.data_layer.bq")
    def test_aggregates_coo_metrics(self, mock_bq):
        from data.data_layer import get_coo_metrics

        mock_bq.get_invoice_collection_rate.return_value = {
            "collection_rate": 0.93, "paid_count": 93, "total_count": 100
        }
        mock_bq.get_overdue_invoices.return_value = {
            "count": 4, "amount": 45_000.0
        }
        mock_bq.get_working_capital.return_value = {
            "working_capital": 1_200_000.0, "current_assets": 2_000_000.0,
            "current_liabilities": 800_000.0
        }
        mock_bq.get_months_of_runway.return_value = {
            "months": 12.0, "cash_balance": 600_000.0, "avg_monthly_burn": 50_000.0
        }

        result = get_coo_metrics()
        assert result["invoice_collection_rate"] == 0.93
        assert result["overdue_count"] == 4
        assert result["working_capital"] == 1_200_000.0
        assert result["months_of_runway"] == 12.0

    @patch("data.data_layer._bigquery_available", False)
    def test_returns_mock_when_bq_unavailable(self):
        from data.data_layer import get_coo_metrics

        result = get_coo_metrics()
        # Should return mock/fallback data
        assert "invoice_collection_rate" in result
        assert isinstance(result["invoice_collection_rate"], float)
```

**Step 2: Run — FAIL**

```bash
pytest tests/test_data_layer.py::TestGetCOOMetrics -v
```

Expected: FAIL — `ImportError: cannot import name 'get_coo_metrics'`

**Step 3: Implement get_coo_metrics in data_layer.py**

Add to `dashboard/data/data_layer.py`:
```python
def get_coo_metrics() -> Dict[str, Any]:
    """Get COO/Ops department metrics.

    Aggregates: Take Rate, Invoice Collection, Overdue Invoices,
    Working Capital, Months of Runway, Customer Concentration,
    Net Revenue Gap, Factoring Capacity.

    Falls back to mock data when BigQuery is unavailable.
    """
    if USE_BIGQUERY and _bigquery_available:
        try:
            invoice = bq.get_invoice_collection_rate()
            overdue = bq.get_overdue_invoices()
            capital = bq.get_working_capital()
            runway = bq.get_months_of_runway()

            return {
                "invoice_collection_rate": invoice.get("collection_rate", 0),
                "paid_count": invoice.get("paid_count", 0),
                "total_invoices": invoice.get("total_count", 0),
                "overdue_count": overdue.get("count", 0),
                "overdue_amount": overdue.get("amount", 0),
                "working_capital": capital.get("working_capital", 0),
                "current_assets": capital.get("current_assets", 0),
                "current_liabilities": capital.get("current_liabilities", 0),
                "months_of_runway": runway.get("months"),
                "cash_balance": runway.get("cash_balance", 0),
                "avg_monthly_burn": runway.get("avg_monthly_burn", 0),
                "source": "bigquery",
            }
        except Exception as e:
            logger.warning("Failed to fetch COO metrics from BQ: %s", e)

    # Fallback mock data
    return {
        "invoice_collection_rate": 0.93,
        "paid_count": 93,
        "total_invoices": 100,
        "overdue_count": 4,
        "overdue_amount": 45_000,
        "working_capital": 1_200_000,
        "current_assets": 2_000_000,
        "current_liabilities": 800_000,
        "months_of_runway": 12,
        "cash_balance": 600_000,
        "avg_monthly_burn": 50_000,
        "source": "mock",
    }
```

**Step 4: Run — PASS**

```bash
pytest tests/test_data_layer.py -v
```

**Step 5: Commit**

```bash
git add dashboard/data/data_layer.py dashboard/tests/test_data_layer.py
git commit -m "feat: add COO metrics aggregation to data layer with tests"
```

---

## Task 10: Run Full Test Suite & Verify

**Step 1: Run all tests**

```bash
cd /Users/deucethevenowworkm1/Projects/company-kpi-dashboard/dashboard
source venv/bin/activate
pytest tests/ -v --tb=short
```

Expected: All tests pass

**Step 2: Verify dashboard still runs**

```bash
GOOGLE_APPLICATION_CREDENTIALS="/Users/deucethevenowworkm1/.config/bigquery-mcp-key.json" \
  streamlit run app.py --server.headless true &
sleep 5
curl -s http://localhost:8501 | head -20
kill %1
```

Expected: Dashboard returns HTML

**Step 3: Final commit**

```bash
git add -A
git commit -m "test: full test suite passing, dashboard verified"
```

---

## Summary

| Task | Component | Tests | Status |
|------|-----------|-------|--------|
| 1 | Test infrastructure | 1 smoke test | Setup |
| 2 | Take Rate (existing) | 3 tests | Validates existing |
| 3 | Invoice Collection Rate | 2 tests | New function |
| 4 | Overdue Invoices | 2 tests | New function |
| 5 | Working Capital | 1 test | New function (shared) |
| 6 | Months of Runway | 2 tests | New function (shared) |
| 7 | Win Rate, Deal Size, Cycle | 3 tests | New functions |
| 8 | Marketing Attribution, MQL | 2 tests | New functions |
| 9 | Data Layer (COO) | 2 tests | New aggregation |
| 10 | Full Suite Verification | All | Integration check |

**Total: 10 tasks, ~18 tests, ~8 new BigQuery functions, 1 data layer aggregation**

---

## Next Plans (Future)

After this plan is complete, subsequent plans should cover:
- **Phase 1b:** Supply, Demand AM, Accounting, Engineering BQ functions
- **Phase 2:** Department page renderers (Streamlit pages per department)
- **Phase 3:** Deploy SQL as BigQuery views in `App_KPI_Dashboard` dataset
- **Phase 4:** End-to-end integration testing with live BigQuery data

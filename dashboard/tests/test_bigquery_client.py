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


class TestGetTakeRate:
    """Tests for get_take_rate BigQuery function."""

    @patch("data.bigquery_client.get_client")
    def test_returns_take_rate_as_float(self, mock_get_client, mock_bq_result):
        """Take rate should return float (e.g., 0.491 for 49.1%)."""
        from data.bigquery_client import get_take_rate

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        # Mock: GMV = $7.92M, Take Rate = 0.491
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

        # First call (2026): low GMV -> triggers fallback
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


class TestGetInvoiceCollectionRate:
    """Tests for COO/Ops invoice collection rate metric."""

    @patch("data.bigquery_client.get_client")
    def test_returns_collection_rate_dict(self, mock_get_client, mock_bq_result):
        """Invoice collection rate: paid invoices / total due invoices."""
        from data.bigquery_client import get_invoice_collection_rate

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([{
            "paid_invoices": 95,
            "total_due_invoices": 100,
            "collection_rate_pct": 0.95,
        }])
        mock_client.query.return_value = mock_query_job

        result = get_invoice_collection_rate()
        assert result["collection_rate"] == pytest.approx(0.95, abs=0.01)
        assert result["paid_count"] == 95
        assert result["total_count"] == 100

    @patch("data.bigquery_client.get_client")
    def test_returns_empty_dict_on_error(self, mock_get_client):
        """Should return empty dict when query fails."""
        from data.bigquery_client import get_invoice_collection_rate
        from google.cloud.exceptions import GoogleCloudError

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.query.side_effect = GoogleCloudError("fail")

        result = get_invoice_collection_rate()
        assert result == {}


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

    @patch("data.bigquery_client.get_client")
    def test_returns_empty_dict_on_error(self, mock_get_client):
        from data.bigquery_client import get_working_capital
        from google.cloud.exceptions import GoogleCloudError

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.query.side_effect = GoogleCloudError("fail")

        result = get_working_capital()
        assert result == {}


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
    def test_handles_zero_burn_gracefully(self, mock_get_client, mock_bq_result):
        """When burn is zero, months should be None."""
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

    @patch("data.bigquery_client.get_client")
    def test_returns_empty_dict_on_error(self, mock_get_client):
        from data.bigquery_client import get_months_of_runway
        from google.cloud.exceptions import GoogleCloudError

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.query.side_effect = GoogleCloudError("fail")

        result = get_months_of_runway()
        assert result == {}

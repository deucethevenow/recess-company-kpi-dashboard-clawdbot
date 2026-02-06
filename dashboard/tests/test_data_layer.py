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
        assert isinstance(result["invoice_collection_rate"], (int, float))

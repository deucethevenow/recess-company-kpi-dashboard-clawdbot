"""Tests for Accounting BigQuery functions."""
from unittest.mock import MagicMock, patch


class TestGetAvgDaysToCollection:
    @patch("data.bigquery_client.get_client")
    def test_returns_avg_days(self, mock_get_client, mock_bq_result):
        from data.bigquery_client import get_avg_days_to_collection

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([
            {
                "avg_days_to_collect": 8.5,
                "median_days_to_collect": 7.0,
                "invoices_paid": 120,
            }
        ])
        mock_client.query.return_value = mock_query_job

        result = get_avg_days_to_collection()
        assert result["avg_days_to_collect"] == 8.5
        assert result["median_days_to_collect"] == 7.0
        assert result["invoice_count"] == 120

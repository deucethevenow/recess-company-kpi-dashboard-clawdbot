"""Tests for Demand AM BigQuery functions."""
from unittest.mock import MagicMock, patch

import pytest


class TestGetOfferAcceptanceRate:
    @patch("data.bigquery_client.get_client")
    def test_returns_acceptance_rate(self, mock_get_client, mock_bq_result):
        from data.bigquery_client import get_offer_acceptance_rate

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([
            {"acceptance_rate": 0.88}
        ])
        mock_client.query.return_value = mock_query_job

        result = get_offer_acceptance_rate()
        assert result == pytest.approx(0.88, abs=0.001)


class TestGetAvgTicketResponseTime:
    @patch("data.bigquery_client.get_client")
    def test_returns_avg_response_hours(self, mock_get_client, mock_bq_result):
        from data.bigquery_client import get_avg_ticket_response_time

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([
            {"avg_response_hours": 12.5}
        ])
        mock_client.query.return_value = mock_query_job

        result = get_avg_ticket_response_time()
        assert result == pytest.approx(12.5, abs=0.01)

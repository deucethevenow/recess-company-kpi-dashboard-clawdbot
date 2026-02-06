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

    @patch("data.bigquery_client.get_client")
    def test_returns_empty_dict_on_error(self, mock_get_client):
        from data.bigquery_client import get_win_rate_90d
        from google.cloud.exceptions import GoogleCloudError

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.query.side_effect = GoogleCloudError("fail")

        result = get_win_rate_90d()
        assert result == {}


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

    @patch("data.bigquery_client.get_client")
    def test_returns_empty_dict_on_error(self, mock_get_client):
        from data.bigquery_client import get_avg_deal_size_ytd
        from google.cloud.exceptions import GoogleCloudError

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.query.side_effect = GoogleCloudError("fail")

        result = get_avg_deal_size_ytd()
        assert result == {}


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

    @patch("data.bigquery_client.get_client")
    def test_returns_empty_dict_on_error(self, mock_get_client):
        from data.bigquery_client import get_sales_cycle_length
        from google.cloud.exceptions import GoogleCloudError

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.query.side_effect = GoogleCloudError("fail")

        result = get_sales_cycle_length()
        assert result == {}

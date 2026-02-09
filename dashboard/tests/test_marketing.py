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

    @patch("data.bigquery_client.get_client")
    def test_returns_empty_dict_on_error(self, mock_get_client):
        from data.bigquery_client import get_marketing_influenced_pipeline
        from google.cloud.exceptions import GoogleCloudError

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.query.side_effect = GoogleCloudError("fail")

        result = get_marketing_influenced_pipeline()
        assert result == {}


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


class TestGetMarketingLeadsFunnel:
    """Tests for marketing leads funnel."""

    @patch("data.bigquery_client.get_client")
    def test_returns_funnel_rows(self, mock_get_client, mock_bq_result):
        from data.bigquery_client import get_marketing_leads_funnel

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([
            {"funnel_stage": "ML", "contact_count": 100, "pct_of_top_funnel": 100, "stage_conversion_rate": 40},
            {"funnel_stage": "MQL", "contact_count": 40, "pct_of_top_funnel": 40, "stage_conversion_rate": 25},
        ])
        mock_client.query.return_value = mock_query_job

        result = get_marketing_leads_funnel()
        assert result[0]["funnel_stage"] == "ML"
        assert result[1]["contact_count"] == 40


class TestGetAttributionByChannel:
    """Tests for attribution by channel."""

    @patch("data.bigquery_client.get_client")
    def test_returns_channel_rows(self, mock_get_client, mock_bq_result):
        from data.bigquery_client import get_attribution_by_channel

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        mock_query_job = MagicMock()
        mock_query_job.result.return_value = mock_bq_result([
            {
                "channel": "DIRECT_TRAFFIC",
                "channel_group": "Direct",
                "deal_count": 5,
                "first_touch_revenue": 100000,
                "last_touch_revenue": 100000,
                "total_attributed_revenue": 200000,
                "pct_of_total": 50,
            }
        ])
        mock_client.query.return_value = mock_query_job

        result = get_attribution_by_channel()
        assert result[0]["channel_group"] == "Direct"
        assert result[0]["total_attributed_revenue"] == 200000

    @patch("data.bigquery_client.get_client")
    def test_returns_empty_dict_on_error(self, mock_get_client):
        from data.bigquery_client import get_mql_to_sql_conversion
        from google.cloud.exceptions import GoogleCloudError

        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.query.side_effect = GoogleCloudError("fail")

        result = get_mql_to_sql_conversion()
        assert result == {}

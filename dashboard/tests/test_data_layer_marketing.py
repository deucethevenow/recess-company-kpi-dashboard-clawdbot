"""Tests for marketing data-layer helpers."""
from unittest.mock import patch


@patch("data.data_layer._bigquery_available", True)
@patch("data.data_layer.USE_BIGQUERY", True)
@patch("data.data_layer.bq")
def test_get_marketing_funnel_returns_rows(mock_bq):
    from data.data_layer import get_marketing_funnel

    mock_bq.get_marketing_leads_funnel.return_value = [
        {"funnel_stage": "ML", "contact_count": 100, "pct_of_top_funnel": 100, "stage_conversion_rate": 40},
        {"funnel_stage": "MQL", "contact_count": 40, "pct_of_top_funnel": 40, "stage_conversion_rate": 25},
        {"funnel_stage": "SQL", "contact_count": 10, "pct_of_top_funnel": 10, "stage_conversion_rate": None},
    ]

    rows = get_marketing_funnel()
    assert rows[0]["funnel_stage"] == "ML"
    assert rows[1]["contact_count"] == 40


@patch("data.data_layer._bigquery_available", True)
@patch("data.data_layer.USE_BIGQUERY", True)
@patch("data.data_layer.bq")
def test_get_marketing_attribution_returns_rows(mock_bq):
    from data.data_layer import get_marketing_attribution

    mock_bq.get_attribution_by_channel.return_value = [
        {
            "channel": "DIRECT_TRAFFIC",
            "channel_group": "Direct",
            "deal_count": 5,
            "first_touch_revenue": 100000,
            "last_touch_revenue": 100000,
            "total_attributed_revenue": 200000,
            "pct_of_total": 50,
        }
    ]

    rows = get_marketing_attribution()
    assert rows[0]["channel_group"] == "Direct"
    assert rows[0]["total_attributed_revenue"] == 200000

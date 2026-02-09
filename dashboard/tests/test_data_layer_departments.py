"""Tests for department metric aggregation in data_layer."""
from unittest.mock import MagicMock, patch


def _metric_by_label(metrics, label):
    return next((m for m in metrics if m.get("label") == label), None)


@patch("data.data_layer._bigquery_available", True)
@patch("data.data_layer.USE_BIGQUERY", True)
@patch("data.data_layer.bq")
def test_get_demand_sales_metrics_bigquery(mock_bq):
    from data.data_layer import get_demand_sales_metrics

    mock_bq.get_nrr.return_value = 1.07
    mock_bq.get_pipeline_details.return_value = {"weighted_pipeline": 5_000_000}
    mock_bq.get_win_rate_90d.return_value = {"win_rate": 0.28}
    mock_bq.get_avg_deal_size_ytd.return_value = {"avg_deal_size": 155_000}

    metrics = get_demand_sales_metrics()

    nrr = _metric_by_label(metrics, "NRR")
    weighted = _metric_by_label(metrics, "Weighted Pipeline")
    win_rate = _metric_by_label(metrics, "Win Rate (90 days)")
    avg_deal = _metric_by_label(metrics, "Avg Deal Size")

    assert nrr["value"] == 1.07
    assert weighted["value"] == 5_000_000
    assert win_rate["value"] == 0.28
    assert avg_deal["value"] == 155_000


@patch("data.data_layer._bigquery_available", True)
@patch("data.data_layer.USE_BIGQUERY", True)
@patch("data.data_layer.bq")
def test_get_demand_am_metrics_bigquery(mock_bq):
    from data.data_layer import get_demand_am_metrics

    mock_bq.get_contract_spend_pct.return_value = 0.89
    mock_bq.get_nps_score.return_value = 0.71

    metrics = get_demand_am_metrics()

    contract = _metric_by_label(metrics, "Contract Spend %")
    nps = _metric_by_label(metrics, "NPS Score")

    assert contract["value"] == 0.89
    assert nps["value"] == 0.71


@patch("data.data_layer._bigquery_available", True)
@patch("data.data_layer.USE_BIGQUERY", True)
@patch("data.data_layer.bq")
def test_get_marketing_metrics_bigquery(mock_bq):
    from data.data_layer import get_marketing_metrics

    mock_bq.get_marketing_influenced_pipeline.return_value = {
        "influenced_pipeline": 2_400_000,
        "ft_attribution": 1_800_000,
        "lt_attribution": 2_100_000,
    }
    mock_bq.get_mql_to_sql_conversion.return_value = {"conversion_rate": 0.33}

    metrics = get_marketing_metrics()

    influenced = _metric_by_label(metrics, "Marketing-Influenced Pipeline")
    mql = _metric_by_label(metrics, "MQL → SQL Conversion")
    ft = _metric_by_label(metrics, "First Touch Attribution $")
    lt = _metric_by_label(metrics, "Last Touch Attribution $")

    assert influenced["value"] == 2_400_000
    assert mql["value"] == 0.33
    assert ft["value"] == 1_800_000
    assert lt["value"] == 2_100_000


@patch("data.data_layer.get_coo_metrics")
def test_get_accounting_metrics_uses_coo_metrics(mock_get_coo):
    from data.data_layer import get_accounting_metrics

    mock_get_coo.return_value = {
        "invoice_collection_rate": 0.93,
        "overdue_count": 4,
        "overdue_amount": 45_000,
    }

    metrics = get_accounting_metrics()

    collection = _metric_by_label(metrics, "Invoice Collection Rate")
    overdue = _metric_by_label(metrics, "Invoices Overdue")
    overdue_amount = _metric_by_label(metrics, "Overdue Amount")

    assert collection["value"] == 0.93
    assert overdue["value"] == 4
    assert overdue_amount["value"] == 45_000


@patch("data.data_layer._bigquery_available", False)
@patch("data.data_layer.USE_BIGQUERY", True)
def test_get_marketing_metrics_fallback_to_defaults():
    from data.data_layer import get_marketing_metrics

    metrics = get_marketing_metrics()

    influenced = _metric_by_label(metrics, "Marketing-Influenced Pipeline")
    mql = _metric_by_label(metrics, "MQL → SQL Conversion")

    assert influenced["value"] is not None
    assert mql["value"] is not None

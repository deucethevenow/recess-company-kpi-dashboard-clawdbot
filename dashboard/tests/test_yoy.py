"""Tests for YoY comparison data functions."""
import pytest
from unittest.mock import patch, MagicMock


# ─────────────────────────────────────────────
# _safe_change_pct
# ─────────────────────────────────────────────

def test_safe_change_pct_calculation():
    """Verify math: (100-80)/80 = 0.25."""
    from data.data_layer import _safe_change_pct
    result = _safe_change_pct(100, 80)
    assert result == pytest.approx(0.25)


def test_safe_change_pct_negative_change():
    """Verify negative change: (80-100)/100 = -0.20."""
    from data.data_layer import _safe_change_pct
    result = _safe_change_pct(80, 100)
    assert result == pytest.approx(-0.20)


def test_safe_change_pct_none_handling():
    """None inputs return None."""
    from data.data_layer import _safe_change_pct
    assert _safe_change_pct(None, 100) is None
    assert _safe_change_pct(100, None) is None
    assert _safe_change_pct(None, None) is None


def test_safe_change_pct_zero_handling():
    """Zero prior returns None (avoid division by zero)."""
    from data.data_layer import _safe_change_pct
    assert _safe_change_pct(100, 0) is None


def test_safe_change_pct_negative_prior():
    """Negative prior uses abs(prior) in denominator."""
    from data.data_layer import _safe_change_pct
    # (10 - (-5)) / abs(-5) = 15/5 = 3.0
    result = _safe_change_pct(10, -5)
    assert result == pytest.approx(3.0)


# ─────────────────────────────────────────────
# get_yoy_metrics
# ─────────────────────────────────────────────

@patch("data.data_layer._bigquery_available", False)
def test_get_yoy_metrics_returns_dict():
    """YoY metrics returns a dict with expected keys."""
    from data.data_layer import get_yoy_metrics
    result = get_yoy_metrics()
    assert isinstance(result, dict)
    assert "revenue" in result
    assert "take_rate" in result
    assert "nrr" in result


@patch("data.data_layer._bigquery_available", False)
def test_yoy_metric_structure():
    """Each YoY metric has current, prior, and change_pct."""
    from data.data_layer import get_yoy_metrics
    result = get_yoy_metrics()
    for key, metric in result.items():
        assert "current" in metric, f"{key} missing 'current'"
        assert "prior" in metric, f"{key} missing 'prior'"
        assert "change_pct" in metric, f"{key} missing 'change_pct'"


@patch("data.data_layer._bigquery_available", False)
def test_yoy_metrics_includes_all_expected_keys():
    """YoY metrics contains all expected metric keys."""
    from data.data_layer import get_yoy_metrics
    result = get_yoy_metrics()
    expected_keys = {
        "revenue", "take_rate", "nrr", "supply_nrr",
        "customer_count", "logo_retention", "pipeline_coverage",
        "time_to_fulfill",
    }
    assert set(result.keys()) == expected_keys


@patch("data.data_layer._bigquery_available", False)
def test_yoy_metrics_fallback_priors():
    """When BQ unavailable, prior values use hardcoded fallbacks."""
    from data.data_layer import get_yoy_metrics
    result = get_yoy_metrics()
    # Hardcoded fallback values from the implementation
    assert result["revenue"]["prior"] == 3_900_000
    assert result["take_rate"]["prior"] == 0.493
    assert result["nrr"]["prior"] == 0.222
    assert result["supply_nrr"]["prior"] == 0.667
    assert result["customer_count"]["prior"] == 51
    assert result["logo_retention"]["prior"] == 0.26
    assert result["time_to_fulfill"]["prior"] == 69


@patch("data.data_layer._bigquery_available", False)
def test_yoy_pipeline_coverage_has_no_prior():
    """Pipeline coverage has no prior year data (None)."""
    from data.data_layer import get_yoy_metrics
    result = get_yoy_metrics()
    assert result["pipeline_coverage"]["prior"] is None
    assert result["pipeline_coverage"]["change_pct"] is None


# ─────────────────────────────────────────────
# get_quarterly_revenue
# ─────────────────────────────────────────────

@patch("data.data_layer._bigquery_available", False)
def test_get_quarterly_revenue_returns_list():
    """Quarterly revenue returns list of 4 quarter dicts."""
    from data.data_layer import get_quarterly_revenue
    result = get_quarterly_revenue()
    assert isinstance(result, list)
    assert len(result) == 4
    for q in result:
        assert "quarter" in q
        assert "target" in q


@patch("data.data_layer._bigquery_available", False)
def test_quarterly_revenue_structure():
    """Each quarter has quarter, target, status, is_current."""
    from data.data_layer import get_quarterly_revenue
    result = get_quarterly_revenue()
    for q in result:
        assert "quarter" in q
        assert "quarter_num" in q
        assert "target" in q
        assert "actual" in q
        assert "status" in q
        assert "is_current" in q


@patch("data.data_layer._bigquery_available", False)
def test_quarterly_revenue_quarter_labels():
    """Quarters are labeled Q1 through Q4."""
    from data.data_layer import get_quarterly_revenue
    result = get_quarterly_revenue()
    labels = [q["quarter"] for q in result]
    assert labels == ["Q1", "Q2", "Q3", "Q4"]


@patch("data.data_layer._bigquery_available", False)
def test_quarterly_revenue_exactly_one_current():
    """Exactly one quarter should be marked as current."""
    from data.data_layer import get_quarterly_revenue
    result = get_quarterly_revenue()
    current_quarters = [q for q in result if q["is_current"]]
    assert len(current_quarters) == 1


@patch("data.data_layer._bigquery_available", False)
def test_quarterly_revenue_status_values():
    """Status is one of past, current, or future."""
    from data.data_layer import get_quarterly_revenue
    result = get_quarterly_revenue()
    for q in result:
        assert q["status"] in ("past", "current", "future")


# ─────────────────────────────────────────────
# get_revenue_time_horizons
# ─────────────────────────────────────────────

@patch("data.data_layer._bigquery_available", False)
def test_get_revenue_time_horizons_returns_dict():
    """Revenue time horizons returns month/quarter/ytd."""
    from data.data_layer import get_revenue_time_horizons
    result = get_revenue_time_horizons()
    assert "month" in result
    assert "quarter" in result
    assert "ytd" in result


@patch("data.data_layer._bigquery_available", False)
def test_revenue_time_horizons_structure():
    """Each horizon has actual, target, prior_year, change_pct."""
    from data.data_layer import get_revenue_time_horizons
    result = get_revenue_time_horizons()
    for key, val in result.items():
        assert "actual" in val, f"{key} missing 'actual'"
        assert "target" in val, f"{key} missing 'target'"
        assert "prior_year" in val, f"{key} missing 'prior_year'"
        assert "change_pct" in val, f"{key} missing 'change_pct'"


@patch("data.data_layer._bigquery_available", False)
def test_revenue_time_horizons_have_labels():
    """Each horizon has a human-readable label."""
    from data.data_layer import get_revenue_time_horizons
    result = get_revenue_time_horizons()
    for key, val in result.items():
        assert "label" in val, f"{key} missing 'label'"
        assert isinstance(val["label"], str)
        assert len(val["label"]) > 0


@patch("data.data_layer._bigquery_available", False)
def test_revenue_time_horizons_ytd_label():
    """YTD label is 'Year to Date'."""
    from data.data_layer import get_revenue_time_horizons
    result = get_revenue_time_horizons()
    assert result["ytd"]["label"] == "Year to Date"

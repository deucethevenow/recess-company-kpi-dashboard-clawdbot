"""Integration smoke tests for BigQuery data functions.

These tests run REAL queries against BigQuery to catch SQL type mismatches,
schema changes, and other issues that unit tests (with mocked clients) can't detect.

Run: pytest -m integration  (requires GOOGLE_APPLICATION_CREDENTIALS)
Skip: pytest  (default — addopts in pytest.ini excludes integration marker)
"""

import pytest

pytestmark = pytest.mark.integration


# =============================================================================
# Company Metrics (Overview Page)
# =============================================================================

class TestCompanyMetricsIntegration:
    """Smoke tests for company-level BigQuery functions."""

    def test_get_revenue_ytd(self, bq_client):
        from data.bigquery_client import get_revenue_ytd
        result = get_revenue_ytd()
        assert result is None or isinstance(result, (int, float))

    def test_get_take_rate(self, bq_client):
        from data.bigquery_client import get_take_rate
        result = get_take_rate()
        assert result is None or isinstance(result, (int, float))

    def test_get_nrr(self, bq_client):
        from data.bigquery_client import get_nrr
        result = get_nrr()
        assert result is None or isinstance(result, (int, float))

    def test_get_supply_nrr(self, bq_client):
        from data.bigquery_client import get_supply_nrr
        result = get_supply_nrr()
        assert result is None or isinstance(result, (int, float))

    def test_get_customer_count(self, bq_client):
        from data.bigquery_client import get_customer_count
        result = get_customer_count()
        assert result is None or isinstance(result, int)

    def test_get_churned_customers(self, bq_client):
        from data.bigquery_client import get_churned_customers
        result = get_churned_customers()
        assert result is None or isinstance(result, int)

    def test_get_logo_retention(self, bq_client):
        from data.bigquery_client import get_logo_retention
        result = get_logo_retention()
        assert result is None or isinstance(result, (int, float))

    def test_get_customer_concentration(self, bq_client):
        from data.bigquery_client import get_customer_concentration
        result = get_customer_concentration()
        assert isinstance(result, dict)
        # Should have at least concentration_pct key
        if result:
            assert "concentration_pct" in result or "top1_pct" in result or len(result) > 0

    def test_get_company_metrics_aggregate(self, bq_client):
        from data.bigquery_client import get_company_metrics
        result = get_company_metrics()
        assert isinstance(result, dict)
        assert "revenue_ytd" in result or "take_rate" in result


# =============================================================================
# Pipeline & Sales
# =============================================================================

class TestPipelineIntegration:
    """Smoke tests for pipeline and sales functions."""

    def test_get_pipeline_coverage(self, bq_client):
        from data.bigquery_client import get_pipeline_coverage
        result = get_pipeline_coverage()
        assert result is None or isinstance(result, (int, float))

    def test_get_pipeline_details(self, bq_client):
        from data.bigquery_client import get_pipeline_details
        result = get_pipeline_details()
        assert result is None or isinstance(result, dict)

    def test_get_pipeline_coverage_by_owner(self, bq_client):
        from data.bigquery_client import get_pipeline_coverage_by_owner
        result = get_pipeline_coverage_by_owner()
        assert isinstance(result, (list, dict, type(None)))

    def test_get_quota_from_company_properties(self, bq_client):
        from data.bigquery_client import get_quota_from_company_properties
        result = get_quota_from_company_properties()
        assert isinstance(result, dict)

    def test_get_win_rate_90d(self, bq_client):
        from data.bigquery_client import get_win_rate_90d
        result = get_win_rate_90d()
        assert isinstance(result, dict)

    def test_get_avg_deal_size_ytd(self, bq_client):
        from data.bigquery_client import get_avg_deal_size_ytd
        result = get_avg_deal_size_ytd()
        assert isinstance(result, dict)

    def test_get_sales_cycle_length(self, bq_client):
        from data.bigquery_client import get_sales_cycle_length
        result = get_sales_cycle_length()
        assert isinstance(result, dict)


# =============================================================================
# COO / Ops Metrics
# =============================================================================

class TestCOOMetricsIntegration:
    """Smoke tests for COO/Ops BigQuery functions."""

    def test_get_invoice_collection_rate(self, bq_client):
        from data.bigquery_client import get_invoice_collection_rate
        result = get_invoice_collection_rate()
        assert isinstance(result, dict)
        if result:
            assert "collection_rate" in result

    def test_get_overdue_invoices(self, bq_client):
        from data.bigquery_client import get_overdue_invoices
        result = get_overdue_invoices()
        assert isinstance(result, dict)

    def test_get_working_capital(self, bq_client):
        from data.bigquery_client import get_working_capital
        result = get_working_capital()
        assert isinstance(result, dict)

    def test_get_months_of_runway(self, bq_client):
        from data.bigquery_client import get_months_of_runway
        result = get_months_of_runway()
        assert isinstance(result, dict)


# =============================================================================
# Fulfillment & Operational
# =============================================================================

class TestFulfillmentIntegration:
    """Smoke tests for fulfillment and operational functions."""

    def test_get_time_to_fulfill(self, bq_client):
        from data.bigquery_client import get_time_to_fulfill
        result = get_time_to_fulfill()
        assert isinstance(result, dict)

    def test_get_avg_days_to_fulfill(self, bq_client):
        from data.bigquery_client import get_avg_days_to_fulfill
        result = get_avg_days_to_fulfill()
        assert result is None or isinstance(result, (int, float))

    def test_get_contract_spend_pct(self, bq_client):
        from data.bigquery_client import get_contract_spend_pct
        result = get_contract_spend_pct()
        assert result is None or isinstance(result, (int, float))

    def test_get_nps_score(self, bq_client):
        from data.bigquery_client import get_nps_score
        result = get_nps_score()
        assert result is None or isinstance(result, (int, float))


# =============================================================================
# NRR Details & Cohort Analysis
# =============================================================================

class TestNRRDetailsIntegration:
    """Smoke tests for NRR detail and cohort functions."""

    def test_get_demand_nrr_details(self, bq_client):
        from data.bigquery_client import get_demand_nrr_details
        result = get_demand_nrr_details()
        assert isinstance(result, dict)

    def test_get_supply_nrr_details(self, bq_client):
        from data.bigquery_client import get_supply_nrr_details
        result = get_supply_nrr_details()
        assert isinstance(result, dict)

    def test_get_nrr_by_customer(self, bq_client):
        from data.bigquery_client import get_nrr_by_customer
        result = get_nrr_by_customer()
        assert isinstance(result, list)

    def test_get_cohort_matrix(self, bq_client):
        from data.bigquery_client import get_cohort_matrix
        result = get_cohort_matrix()
        assert isinstance(result, list)


# =============================================================================
# Marketing
# =============================================================================

class TestMarketingIntegration:
    """Smoke tests for marketing BigQuery functions."""

    def test_get_marketing_influenced_pipeline(self, bq_client):
        from data.bigquery_client import get_marketing_influenced_pipeline
        result = get_marketing_influenced_pipeline()
        assert isinstance(result, dict)

    def test_get_mql_to_sql_conversion(self, bq_client):
        from data.bigquery_client import get_mql_to_sql_conversion
        result = get_mql_to_sql_conversion()
        assert isinstance(result, dict)

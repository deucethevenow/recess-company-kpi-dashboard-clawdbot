"""Shared test fixtures for KPI Dashboard tests.

All BigQuery tests use mocked clients to run without credentials.
"""
import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest


@pytest.fixture
def mock_bq_client():
    """Mock BigQuery client that returns configurable query results."""
    client = MagicMock()
    return client


@pytest.fixture
def mock_bq_result():
    """Factory fixture to create mock BigQuery query results.

    Usage:
        result = mock_bq_result([{"column": value}])
    """
    def _make_result(rows):
        """Create mock rows that behave like BigQuery Row objects."""
        mock_rows = []
        for row_data in rows:
            mock_row = MagicMock()
            for key, value in row_data.items():
                setattr(mock_row, key, value)
            # Support dict() conversion
            mock_row.__iter__ = lambda self, d=row_data: iter(d.items())
            mock_row.keys = lambda d=row_data: d.keys()
            mock_row.values = lambda d=row_data: d.values()
            mock_rows.append(mock_row)
        return mock_rows
    return _make_result


@pytest.fixture
def targets_json(tmp_path):
    """Create a temporary targets.json for testing."""
    targets = {
        "company": {
            "revenue_target": 10_000_000,
            "take_rate_target": 0.50,
            "nrr_target": 1.10,
            "customer_count_target": 75,
            "pipeline_target": 6.0,
            "logo_retention_target": 0.50,
        },
        "people": {},
        "last_updated": "2026-02-05T00:00:00",
        "updated_by": "test",
    }
    targets_file = tmp_path / "targets.json"
    targets_file.write_text(json.dumps(targets))
    return targets_file


@pytest.fixture
def sql_queries_dir():
    """Path to the SQL query files."""
    return Path(__file__).parent.parent.parent / "queries"

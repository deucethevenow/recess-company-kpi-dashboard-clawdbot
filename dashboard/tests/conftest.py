"""Shared test fixtures for KPI Dashboard tests."""
from unittest.mock import MagicMock

import pytest


@pytest.fixture
def mock_bq_client():
    """Mock BigQuery client that returns configurable query results."""
    return MagicMock()


@pytest.fixture
def mock_bq_result():
    """Factory fixture to create mock BigQuery query results.

    Usage:
        result = mock_bq_result([{"column": value}])
    """
    def _make_result(rows):
        mock_rows = []
        for row_data in rows:
            mock_row = MagicMock()
            for key, value in row_data.items():
                setattr(mock_row, key, value)
            mock_rows.append(mock_row)
        return mock_rows
    return _make_result

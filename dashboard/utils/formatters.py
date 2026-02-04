"""
Shared formatting utilities for the KPI Dashboard.

Provides consistent value formatting across the application.
"""

from typing import Optional, Union

# Numeric constants
MILLION = 1_000_000
THOUSAND = 1_000


def format_metric_value(
    value: Optional[Union[int, float]],
    fmt: str,
    precision: int = 0
) -> str:
    """Format a metric value based on its type.

    This is the primary formatting function used across the dashboard
    for consistent display of metrics.

    Args:
        value: The numeric value to format (can be None)
        fmt: Format type - one of:
             - 'currency': Dollar amounts ($1.5M, $500K, $100)
             - 'percent': Percentages (45%, 107%)
             - 'multiplier': Multipliers with x suffix (3.0x)
             - 'number': Plain numbers with commas (1,234)
             - 'hours': Hour values (16.5hrs)
             - 'days': Day values (5 days)
        precision: Decimal places for currency millions (default 0)

    Returns:
        Formatted string representation, or "—" if value is None

    Examples:
        >>> format_metric_value(1_500_000, "currency")
        '$1.5M'
        >>> format_metric_value(0.45, "percent")
        '45%'
        >>> format_metric_value(3.0, "multiplier")
        '3.0x'
    """
    if value is None:
        return "—"

    if fmt == "currency":
        if value >= MILLION:
            return f"${value/MILLION:.{precision + 1}f}M" if precision else f"${value/MILLION:.2f}M"
        elif value >= THOUSAND:
            return f"${value/THOUSAND:.0f}K"
        else:
            return f"${value:.0f}"
    elif fmt == "percent":
        return f"{value * 100:.0f}%"
    elif fmt == "multiplier":
        return f"{value:.1f}x"
    elif fmt == "number":
        return f"{value:,.0f}"
    elif fmt == "hours":
        return f"{value:.1f}hrs"
    elif fmt == "days":
        return f"{value:.0f} days"
    else:
        return str(value)


def format_for_display(
    value: Optional[Union[int, float]],
    fmt: str
) -> str:
    """Format a target value for display (more compact version).

    Used specifically for displaying targets in settings and exports
    with slightly different formatting than metrics.

    Args:
        value: The numeric value to format
        fmt: Format type (same options as format_metric_value)

    Returns:
        Formatted string representation
    """
    if value is None:
        return "—"

    if fmt == "currency":
        if value >= MILLION:
            return f"${value/MILLION:.1f}M"
        elif value >= THOUSAND:
            return f"${value/THOUSAND:.0f}K"
        return f"${value:.0f}"
    elif fmt == "percent":
        return f"{value * 100:.0f}%"
    elif fmt == "multiplier":
        return f"{value:.1f}x"
    elif fmt == "days":
        return f"{value:.0f} days"
    elif fmt == "hours":
        return f"{value:.0f} hrs"
    else:
        return f"{value:.0f}"


def format_currency_compact(value: Optional[Union[int, float]]) -> str:
    """Format currency in compact form (e.g., $7.93M).

    Args:
        value: Dollar amount

    Returns:
        Compact currency string
    """
    if value is None:
        return "—"

    if value >= MILLION:
        return f"${value/MILLION:.2f}M"
    elif value >= THOUSAND:
        return f"${value/THOUSAND:.0f}K"
    else:
        return f"${value:.0f}"


def format_percent(value: Optional[float], decimals: int = 0) -> str:
    """Format a decimal as a percentage.

    Args:
        value: Decimal value (e.g., 0.45 for 45%)
        decimals: Number of decimal places

    Returns:
        Percentage string (e.g., "45%")
    """
    if value is None:
        return "—"
    return f"{value * 100:.{decimals}f}%"

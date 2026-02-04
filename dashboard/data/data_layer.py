"""
KPI Dashboard Data Layer.

This module provides company and person metrics for the dashboard.
Data source priority:
1. BigQuery (live data) - if available
2. Fallback to hardcoded mock values - if BigQuery unavailable

Targets are loaded from targets.json with time-based caching.
"""

import json
import logging
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

# Configure logging
logger = logging.getLogger(__name__)

# =============================================================================
# BIGQUERY INTEGRATION
# =============================================================================

# Flag to enable/disable BigQuery (set to False to force mock data)
USE_BIGQUERY = True

# Try to import BigQuery client
_bigquery_available = False
try:
    from . import bigquery_client as bq
    _bigquery_available = True
    logger.info("BigQuery client loaded successfully")
except ImportError as e:
    logger.warning("BigQuery client not available: %s", e)
except Exception as e:
    logger.warning("Error loading BigQuery client: %s", e)

# =============================================================================
# DATA SOURCE STATUS TRACKING
# =============================================================================

# Track whether last data fetch used live BigQuery data
_data_source_status = {
    "is_live": False,
    "source": "mock",  # "bigquery" or "mock"
    "last_updated": None,
    "error": None,
}


def get_data_source_status() -> Dict[str, Any]:
    """Get the current data source status.

    Returns:
        Dictionary with is_live, source, last_updated, and error fields
    """
    return _data_source_status.copy()


# Metric verification status based on METRIC-IMPLEMENTATION-TRACKER.md
# Each metric has: bq_view, python_fn, ui_integrated, confirmed
METRIC_VERIFICATION = {
    "Revenue YTD": {"bq": True, "fn": True, "ui": True, "confirmed": False, "owner": "Jack"},
    "Take Rate %": {"bq": True, "fn": True, "ui": True, "confirmed": False, "owner": "Deuce"},
    "NRR": {"bq": True, "fn": True, "ui": True, "confirmed": False, "owner": "Andy"},
    "Supply NRR": {"bq": True, "fn": True, "ui": True, "confirmed": False, "owner": "Ashton"},
    "Pipeline Coverage": {"bq": True, "fn": True, "ui": True, "confirmed": False, "owner": "Andy"},
    "Logo Retention": {"bq": True, "fn": True, "ui": True, "confirmed": False, "owner": "TBD"},
    "Customer Count": {"bq": True, "fn": True, "ui": True, "confirmed": False, "owner": "TBD"},
    "Time to Fulfill": {"bq": True, "fn": True, "ui": True, "confirmed": False, "owner": "Victoria"},
    "Sellable Inventory": {"bq": False, "fn": False, "ui": True, "confirmed": False, "owner": "Ian", "note": "Needs PRD"},
}


def get_metric_verification(metric_key: str) -> Dict[str, Any]:
    """Get verification status for a specific metric.

    Args:
        metric_key: The metric name/key

    Returns:
        Dictionary with bq, fn, ui, confirmed status and owner
    """
    return METRIC_VERIFICATION.get(metric_key, {
        "bq": False, "fn": False, "ui": False, "confirmed": False, "owner": "Unknown"
    })


def _set_data_source(is_live: bool, source: str, error: Optional[str] = None):
    """Update the data source status."""
    _data_source_status["is_live"] = is_live
    _data_source_status["source"] = source
    _data_source_status["last_updated"] = datetime.now().isoformat()
    _data_source_status["error"] = error

# =============================================================================
# CACHING CONFIGURATION
# =============================================================================

_CACHE_TTL = 5  # seconds - how long to cache targets before re-reading file
_cache: Dict[str, Any] = {"data": None, "timestamp": 0}

# BigQuery metrics cache - longer TTL since data doesn't change frequently
_BQ_CACHE_TTL = 60  # seconds - cache BigQuery results for 1 minute
_bq_cache: Dict[str, Any] = {"data": None, "timestamp": 0}

TARGETS_FILE = Path(__file__).parent / "targets.json"


def _load_targets() -> Dict[str, Any]:
    """Load targets from JSON file with time-based caching.

    Uses a 5-second cache TTL to reduce file I/O while still allowing
    reasonably quick updates when targets are changed via Settings.

    Returns:
        Dictionary containing company and people targets
    """
    current_time = time.time()

    # Return cached data if still fresh
    if _cache["data"] is not None and (current_time - _cache["timestamp"]) < _CACHE_TTL:
        return _cache["data"]

    # Load fresh from file
    try:
        if TARGETS_FILE.exists():
            with open(TARGETS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                _cache["data"] = data
                _cache["timestamp"] = current_time
                logger.debug("Loaded targets from %s (cache refreshed)", TARGETS_FILE)
                return data
    except json.JSONDecodeError as e:
        logger.error("Invalid JSON in targets file: %s", e)
    except IOError as e:
        logger.error("Failed to read targets file: %s", e)

    # Return empty defaults on error
    return {"company": {}, "people": {}}


def invalidate_cache() -> None:
    """Invalidate the targets cache to force a fresh read.

    Call this after saving targets to ensure immediate visibility of changes.
    """
    _cache["data"] = None
    _cache["timestamp"] = 0
    logger.debug("Targets cache invalidated")


def _get_company_targets() -> Dict[str, Any]:
    """Get company targets (with caching)."""
    return _load_targets().get("company", {})


def _get_people_targets() -> Dict[str, Any]:
    """Get people targets (with caching)."""
    return _load_targets().get("people", {})


def _get_mock_company_metrics() -> Dict[str, Any]:
    """Get hardcoded fallback values for company metrics.

    Used when BigQuery is unavailable.
    """
    return {
        "revenue_actual": 7_930_000,
        "take_rate_actual": 0.42,  # Renamed from gross_margin
        "nrr": 1.07,
        "supply_nrr": 0.67,  # 2025 actuals: 67% supply retention
        "customer_count": 51,
        "concentration_top1": 0.41,
        "concentration_top1_name": "HEINEKEN",
        "pipeline_coverage": 2.8,
        "logo_retention": 0.37,
        "time_to_fulfill_median": 69,  # Median days from close to 100% spend
        "time_to_fulfill_avg": 156,  # Average (skewed by outliers)
        "time_to_fulfill_count": 226,  # Total contracts
        "time_to_fulfill_fulfilled": 177,  # Contracts at 100% spend
        "time_to_fulfill_in_progress": 49,  # Contracts still being fulfilled
    }


def _fetch_bigquery_metrics() -> Optional[Dict[str, Any]]:
    """Fetch all BigQuery metrics with caching.

    Returns cached data if still fresh, otherwise fetches from BigQuery.
    Returns None if BigQuery is unavailable or query fails.
    """
    global _bq_cache
    current_time = time.time()

    # Return cached data if still fresh
    if _bq_cache["data"] is not None and (current_time - _bq_cache["timestamp"]) < _BQ_CACHE_TTL:
        cache_age = int(current_time - _bq_cache["timestamp"])
        logger.debug("Using cached BigQuery data (%ds old)", cache_age)
        # Still mark as live since we have valid BigQuery data
        _set_data_source(True, "bigquery (cached)")
        return _bq_cache["data"]

    # Not cached or expired - fetch fresh data
    if not USE_BIGQUERY or not _bigquery_available:
        return None

    try:
        logger.info("🔄 Fetching fresh data from BigQuery...")

        # Fetch all metrics
        bq_metrics = bq.get_company_metrics()
        pipeline_details = bq.get_pipeline_details()
        time_to_fulfill = bq.get_time_to_fulfill()

        if bq_metrics:
            # Combine all data into cache
            _bq_cache["data"] = {
                "metrics": bq_metrics,
                "pipeline": pipeline_details or {},
                "ttf": time_to_fulfill or {},
            }
            _bq_cache["timestamp"] = current_time
            logger.info("✅ BigQuery data cached successfully")
            _set_data_source(True, "bigquery")
            return _bq_cache["data"]

        return None
    except Exception as e:
        logger.warning("❌ BigQuery query failed: %s", e)
        _set_data_source(False, "mock", str(e))
        return None


def get_company_metrics() -> Dict[str, Any]:
    """Get company metrics - tries BigQuery first, falls back to mock data.

    Data source priority:
    1. BigQuery (live data) - if USE_BIGQUERY=True and connection available
    2. Hardcoded mock values - if BigQuery unavailable

    Returns:
        Dictionary containing actual values and targets for company metrics
    """
    targets = _get_company_targets()

    # Default to mock values
    actuals = _get_mock_company_metrics()

    # Pipeline details (will be populated from BigQuery)
    pipeline_details = {
        "quarterly_goal": 2_500_000,
        "closed_won": 0,
        "remaining_to_goal": 2_500_000,
        "weighted_pipeline": 0,
        "pipeline_gap": 2_500_000,
    }

    # Try to get cached BigQuery data
    bq_data = _fetch_bigquery_metrics()

    if bq_data:
        bq_metrics = bq_data.get("metrics", {})
        pd = bq_data.get("pipeline", {})
        ttf = bq_data.get("ttf", {})

        # Override actuals with BigQuery values
        if bq_metrics.get("revenue_ytd") is not None:
            actuals["revenue_actual"] = bq_metrics["revenue_ytd"]
        if bq_metrics.get("take_rate") is not None:
            actuals["take_rate_actual"] = bq_metrics["take_rate"]
        if bq_metrics.get("demand_nrr") is not None:
            actuals["nrr"] = bq_metrics["demand_nrr"]
        if bq_metrics.get("supply_nrr") is not None:
            actuals["supply_nrr"] = bq_metrics["supply_nrr"]
        if bq_metrics.get("customer_count") is not None:
            actuals["customer_count"] = bq_metrics["customer_count"]
        if bq_metrics.get("logo_retention") is not None:
            actuals["logo_retention"] = bq_metrics["logo_retention"]
        if bq_metrics.get("pipeline_coverage") is not None:
            actuals["pipeline_coverage"] = bq_metrics["pipeline_coverage"]

        # Pipeline details
        if pd:
            pipeline_details = {
                "quarterly_goal": pd.get("quarterly_goal", 0),
                "closed_won": pd.get("closed_won", 0),
                "remaining_to_goal": pd.get("remaining_to_goal", 0),
                "weighted_pipeline": pd.get("weighted_pipeline", 0),
                "pipeline_gap": pd.get("pipeline_gap", 0),
            }

        # Time to Fulfill (from contract close to 100% spend)
        if ttf:
            actuals["time_to_fulfill_median"] = ttf.get("median_days", 69)
            actuals["time_to_fulfill_avg"] = ttf.get("avg_days", 156)
            actuals["time_to_fulfill_count"] = ttf.get("contract_count", 0)
            actuals["time_to_fulfill_fulfilled"] = ttf.get("fulfilled_count", 0)
            actuals["time_to_fulfill_in_progress"] = ttf.get("in_progress_count", 0)
    else:
        # No BigQuery data available
        if USE_BIGQUERY and _bigquery_available:
            _set_data_source(False, "mock", "BigQuery query returned no data")
        else:
            reason = "disabled" if not USE_BIGQUERY else "unavailable"
            _set_data_source(False, "mock", f"BigQuery {reason}")

    # Combine actuals with targets
    return {
        "revenue_actual": actuals["revenue_actual"],
        "revenue_target": targets.get("revenue_target", 10_000_000),
        "take_rate_actual": actuals["take_rate_actual"],
        "take_rate_target": targets.get("take_rate_target", 0.45),
        # Keep gross_margin keys for backwards compatibility with UI
        "gross_margin_actual": actuals["take_rate_actual"],
        "gross_margin_target": targets.get("take_rate_target", 0.45),
        "nrr": actuals["nrr"],
        "nrr_target": targets.get("nrr_target", 1.10),
        "supply_nrr": actuals.get("supply_nrr", 0.67),
        "supply_nrr_target": targets.get("supply_nrr_target", 1.10),
        "customer_count": actuals["customer_count"],
        "customer_count_target": targets.get("customer_count_target", 75),
        "concentration_top1": actuals["concentration_top1"],
        "concentration_top1_name": actuals["concentration_top1_name"],
        "pipeline_coverage": actuals["pipeline_coverage"],
        "pipeline_target": targets.get("pipeline_target", 3.0),
        "pipeline_quarterly_goal": pipeline_details["quarterly_goal"],
        "pipeline_closed_won": pipeline_details["closed_won"],
        "pipeline_remaining": pipeline_details["remaining_to_goal"],
        "pipeline_weighted": pipeline_details["weighted_pipeline"],
        "pipeline_gap": pipeline_details["pipeline_gap"],
        # Weighted Pipeline Coverage Gap = (Target × Remaining) - Weighted Pipeline
        # Positive = shortfall, Negative = surplus
        "pipeline_weighted_coverage_gap": (
            targets.get("pipeline_target", 6.0) * pipeline_details["remaining_to_goal"]
        ) - pipeline_details["weighted_pipeline"],
        "logo_retention": actuals["logo_retention"],
        "logo_retention_target": targets.get("logo_retention_target", 0.50),
        # Time to Fulfill metrics (from contract close to 100% spend)
        "time_to_fulfill_median": actuals.get("time_to_fulfill_median", 69),
        "time_to_fulfill_avg": actuals.get("time_to_fulfill_avg", 156),
        "time_to_fulfill_count": actuals.get("time_to_fulfill_count", 0),
        "time_to_fulfill_fulfilled": actuals.get("time_to_fulfill_fulfilled", 0),
        "time_to_fulfill_in_progress": actuals.get("time_to_fulfill_in_progress", 0),
        "time_to_fulfill_target": targets.get("time_to_fulfill_target", 60),  # Updated target based on median
    }


# For backwards compatibility - this is a property-like dict that reloads
class _DynamicMetrics:
    """Dict-like object that reloads targets fresh each access."""
    def __getitem__(self, key):
        return get_company_metrics()[key]

    def get(self, key, default=None):
        return get_company_metrics().get(key, default)

    def __iter__(self):
        return iter(get_company_metrics())

    def items(self):
        return get_company_metrics().items()

    def keys(self):
        return get_company_metrics().keys()

    def values(self):
        return get_company_metrics().values()


COMPANY_METRICS = _DynamicMetrics()

# =============================================================================
# STATUS THRESHOLDS & COLORS
# =============================================================================

THRESHOLD_ON_TRACK = 1.0
THRESHOLD_AT_RISK = 0.85

# Status emojis
STATUS_ON_TRACK = "🟢"
STATUS_AT_RISK = "🟡"
STATUS_OFF_TRACK = "🔴"
STATUS_NO_TARGET = "⚪"

# Status colors (hex)
COLOR_SUCCESS = "#22c55e"
COLOR_WARNING = "#eab308"
COLOR_DANGER = "#ef4444"
COLOR_NEUTRAL = "#6b7280"


def get_status(
    actual: Optional[float],
    target: float,
    higher_is_better: bool = True
) -> str:
    """Return status emoji based on performance vs target.

    Args:
        actual: The actual achieved value
        target: The target value
        higher_is_better: Whether higher values are better

    Returns:
        Status emoji string (🟢, 🟡, 🔴, or ⚪)
    """
    if target == 0:
        return STATUS_NO_TARGET

    if higher_is_better:
        ratio = actual / target
    else:
        # Division by zero protection
        if actual == 0:
            return STATUS_OFF_TRACK
        ratio = target / actual

    if ratio >= THRESHOLD_ON_TRACK:
        return STATUS_ON_TRACK
    elif ratio >= THRESHOLD_AT_RISK:
        return STATUS_AT_RISK
    else:
        return STATUS_OFF_TRACK


def _get_person_target(name: str, default_target: float) -> float:
    """Get target for a person from JSON (cached), fallback to default.

    Args:
        name: Person's name
        default_target: Fallback value if no target configured

    Returns:
        The target value
    """
    people_targets = _get_people_targets()
    person_data = people_targets.get(name, {})
    return person_data.get("target", default_target)


def get_status_color(
    actual: Optional[float],
    target: float,
    higher_is_better: bool = True
) -> str:
    """Return hex color based on performance vs target.

    Args:
        actual: The actual achieved value
        target: The target value
        higher_is_better: Whether higher values are better

    Returns:
        Hex color string for styling
    """
    if target == 0:
        return COLOR_NEUTRAL

    if higher_is_better:
        ratio = actual / target
    else:
        # Division by zero protection
        if actual == 0:
            return COLOR_DANGER
        ratio = target / actual

    if ratio >= THRESHOLD_ON_TRACK:
        return COLOR_SUCCESS
    elif ratio >= THRESHOLD_AT_RISK:
        return COLOR_WARNING
    else:
        return COLOR_DANGER


# =============================================================================
# PERSON METRICS DATA
# =============================================================================

# Base person data (actuals + default targets - NO function calls here)
_PERSON_BASE_DATA = [
    {"name": "Jack", "department": "CEO / Biz Dev", "metric_name": "Revenue vs Target",
     "actual": 7_930_000, "default_target": 10_000_000, "format": "currency", "higher_is_better": True},
    {"name": "Deuce", "department": "COO / Ops", "metric_name": "Take Rate %",
     "actual": 0.49, "default_target": 0.50, "format": "percent", "higher_is_better": True},
    {"name": "Ian Hong", "department": "Supply", "metric_name": "New Unique Inventory",
     "actual": 12, "default_target": 16, "format": "number", "higher_is_better": True},
    {"name": "Ashton", "department": "Supply AM", "metric_name": "NRR Top Supply Users",
     "actual": 0.95, "default_target": 1.10, "format": "percent", "higher_is_better": True},
    {"name": "Andy Cooper", "department": "Demand Sales", "metric_name": "NRR",
     "actual": 1.07, "default_target": 1.10, "format": "percent", "higher_is_better": True},
    {"name": "Danny Sears", "department": "Demand Sales", "metric_name": "Pipeline Coverage",
     "actual": 2.8, "default_target": 3.0, "format": "multiplier", "higher_is_better": True},
    {"name": "Katie", "department": "Demand Sales", "metric_name": "Pipeline Coverage",
     "actual": 3.2, "default_target": 3.0, "format": "multiplier", "higher_is_better": True},
    {"name": "Char Short", "department": "Demand AM", "metric_name": "Contract Spend %",
     "actual": 0.89, "default_target": 0.95, "format": "percent", "higher_is_better": True},
    {"name": "Victoria", "department": "Demand AM", "metric_name": "Days to Fulfill",
     "actual": 69, "default_target": 60, "format": "days", "higher_is_better": False},
    {"name": "Claire", "department": "Demand AM", "metric_name": "NPS Score",
     "actual": 0.71, "default_target": 0.75, "format": "percent", "higher_is_better": True},
    {"name": "Francisco", "department": "Demand AM", "metric_name": "Offer Acceptance %",
     "actual": 0.88, "default_target": 0.90, "format": "percent", "higher_is_better": True},
    {"name": "Marketing", "department": "Marketing", "metric_name": "Mktg-Influenced Pipeline",
     "actual": 2_400_000, "default_target": 0, "format": "currency", "higher_is_better": True},
    {"name": "Accounting", "department": "Accounting", "metric_name": "Invoice Collection %",
     "actual": 0.93, "default_target": 0.95, "format": "percent", "higher_is_better": True},
    {"name": "VP Engineering", "department": "Engineering", "metric_name": "Features Fully Scoped",
     "actual": None, "default_target": 5, "format": "number", "higher_is_better": True},
    {"name": "Dev 1", "department": "Engineering", "metric_name": "BizSup Completed",
     "actual": None, "default_target": 10, "format": "number", "higher_is_better": True},
    {"name": "Dev 2", "department": "Engineering", "metric_name": "PRDs Generated",
     "actual": None, "default_target": 3, "format": "number", "higher_is_better": True},
    {"name": "Dev 3", "department": "Engineering", "metric_name": "FSDs Generated",
     "actual": None, "default_target": 2, "format": "number", "higher_is_better": True},
]


def get_person_metrics() -> List[Dict[str, Any]]:
    """Build person metrics list with targets from JSON (cached).

    Returns a list where each person's target is loaded from targets.json
    (with caching), falling back to default_target if not configured.

    Returns:
        List of person metric dictionaries with name, department, metric_name,
        actual, target, format, and higher_is_better keys
    """
    result = []
    for person in _PERSON_BASE_DATA:
        # Copy base data
        entry = {
            "name": person["name"],
            "department": person["department"],
            "metric_name": person["metric_name"],
            "actual": person["actual"],
            "format": person["format"],
            "higher_is_better": person.get("higher_is_better", True),
        }
        # Get fresh target from JSON, fallback to default
        entry["target"] = _get_person_target(person["name"], person["default_target"])
        result.append(entry)
    return result


class _DynamicPersonMetrics:
    """List-like object that reloads targets fresh each access."""

    def __iter__(self):
        return iter(get_person_metrics())

    def __getitem__(self, index):
        return get_person_metrics()[index]

    def __len__(self):
        return len(_PERSON_BASE_DATA)


# Backwards-compatible export - reloads targets on each access
PERSON_METRICS = _DynamicPersonMetrics()

# Metric definitions for tooltips
METRIC_DEFINITIONS = {
    "Revenue YTD": {
        "definition": "Total recognized revenue from all sources year-to-date.",
        "importance": "Primary measure of business growth and ability to fund operations.",
        "calculation": "Sum of all invoiced revenue from Aug 1 to current date."
    },
    "Revenue vs Target": {
        "definition": "Progress toward annual revenue goal.",
        "importance": "Shows if we're on track to hit our annual commitment to investors.",
        "calculation": "Current YTD revenue divided by annual target ($10M)."
    },
    "Take Rate %": {
        "definition": "Percentage of GMV that Recess keeps as net revenue after paying organizers.",
        "importance": "Profitability signal. Proves the business model works. Investors care about path to profitability.",
        "calculation": "Net Revenue / GMV = (GMV - Payouts - Discounts + Credits) / GMV"
    },
    "Gross Margin %": {
        "definition": "Percentage of GMV that Recess keeps as net revenue after paying organizers.",
        "importance": "Profitability signal. Proves the business model works. Investors care about path to profitability.",
        "calculation": "Net Revenue / GMV = (GMV - Payouts - Discounts + Credits) / GMV"
    },
    "NRR": {
        "definition": "Net Revenue Retention - revenue from existing customers vs. prior period.",
        "importance": "Shows if we're growing or shrinking within existing accounts.",
        "calculation": "(Starting MRR + Expansion - Contraction - Churn) / Starting MRR"
    },
    "Supply NRR": {
        "definition": "Net Revenue Retention for supply partners - payouts to prior year suppliers in current year.",
        "importance": "Shows if key supply relationships are growing or shrinking.",
        "calculation": "(Prior year suppliers' current year payouts) / (Their prior year payouts)"
    },
    "Pipeline Coverage": {
        "definition": "Ratio of weighted pipeline to remaining quota.",
        "importance": "Predicts likelihood of hitting targets. 3x+ is healthy.",
        "calculation": "Weighted Pipeline Value / Remaining Quota for Period"
    },
    "Logo Retention": {
        "definition": "Percentage of customers retained year-over-year.",
        "importance": "High churn signals product-market fit or service issues.",
        "calculation": "Customers retained / Total customers at period start"
    },
    "Customer Count": {
        "definition": "Number of active customers with revenue in the current fiscal year.",
        "importance": "Measures customer base health and growth trajectory.",
        "calculation": "Count of customers with Net Revenue > $0 in current year"
    },
    "Sellable Inventory": {
        "definition": "Venues and events available for brand activation campaigns.",
        "importance": "Drives supply capacity and revenue potential.",
        "calculation": "Count of venues meeting 'sellable' criteria (PRD needed)"
    },
    "New Logos YTD": {
        "definition": "Number of new customers acquired this fiscal year.",
        "importance": "Measures sales team effectiveness at new business.",
        "calculation": "Count of new customer contracts signed since Aug 1."
    },
    "Customer Concentration (Top 1)": {
        "definition": "Revenue percentage from largest single customer.",
        "importance": "High concentration = high risk if customer churns.",
        "calculation": "Top customer revenue / Total revenue"
    },
    "New Unique Inventory": {
        "definition": "New venues/events added to platform.",
        "importance": "Drives TAM expansion and supply diversity.",
        "calculation": "Count of new unique venues onboarded QTD."
    },
    "NRR Top Supply Users": {
        "definition": "Revenue retention from top supply partners.",
        "importance": "Shows if key supply relationships are growing.",
        "calculation": "Current period revenue from top partners / Prior period"
    },
    "Contract Spend %": {
        "definition": "Percentage of contracted value actually spent.",
        "importance": "Low spend risks non-renewal; high spend signals upsell.",
        "calculation": "Actual spend / Contracted commitment × 100"
    },
    "Calls per Week": {
        "definition": "Customer touchpoints per AM per week.",
        "importance": "Proactive contact correlates with retention.",
        "calculation": "Total logged calls / Number of weeks in period"
    },
    "NPS Score": {
        "definition": "Net Promoter Score from customer surveys.",
        "importance": "Leading indicator of retention and referrals.",
        "calculation": "% Promoters (9-10) - % Detractors (0-6)"
    },
    "Offer Acceptance %": {
        "definition": "Rate at which brands accept proposed activations.",
        "importance": "Measures platform-market fit and pricing.",
        "calculation": "Accepted offers / Total offers sent × 100"
    },
    "Time to Fulfill": {
        "definition": "Days from Closed Won date until contract spend reaches 100% of the contract value.",
        "importance": "TRUE measure of fulfillment velocity - tracks financial completion (invoices minus credit memos), not just offer activity. Faster fulfillment improves cash flow and renewal likelihood.",
        "calculation": "Closed Won Date → Days until (GMV invoices - credit memos) ≥ contract amount. Median: 69 days."
    },
    "Days to Fulfill": {
        "definition": "Days from Closed Won date until contract spend reaches 100% of the contract value.",
        "importance": "TRUE measure of fulfillment velocity - tracks financial completion (invoices minus credit memos), not just offer activity. Faster fulfillment improves cash flow and renewal likelihood.",
        "calculation": "Closed Won Date → Days until (GMV invoices - credit memos) ≥ contract amount. Median: 69 days."
    },
    "Mktg-Influenced Pipeline": {
        "definition": "Pipeline value where marketing was a touchpoint.",
        "importance": "Quantifies marketing's contribution to revenue.",
        "calculation": "Sum of opportunities with marketing attribution."
    },
    "Invoice Collection %": {
        "definition": "Percentage of invoices collected within terms.",
        "importance": "Cash flow health and customer payment behavior.",
        "calculation": "Invoices collected on time / Total invoices × 100"
    },
    "Meetings Booked (MTD)": {
        "definition": "Discovery/demo meetings scheduled this month.",
        "importance": "Leading indicator for pipeline generation.",
        "calculation": "Count of meetings booked in current month."
    },
    "Lead Queue Runway": {
        "definition": "Days of leads available at current contact rate.",
        "importance": "Predicts when prospecting will stall.",
        "calculation": "Leads in queue / Average leads contacted per day"
    },
    "Weighted Pipeline": {
        "definition": "Pipeline value adjusted by stage probability.",
        "importance": "More accurate forecast than raw pipeline.",
        "calculation": "Sum of (Deal Value × Stage Probability)"
    },
    "Win Rate (90 days)": {
        "definition": "Percentage of opportunities won in last 90 days.",
        "importance": "Sales effectiveness and qualification quality.",
        "calculation": "Won opps / (Won + Lost opps) in 90-day window"
    },
    "Avg Deal Size": {
        "definition": "Average contract value of closed deals.",
        "importance": "Trends indicate market positioning.",
        "calculation": "Total closed revenue / Number of deals"
    },
    "Avg Ticket Response": {
        "definition": "Average time to first response on support tickets.",
        "importance": "Customer experience and service quality.",
        "calculation": "Sum of first response times / Number of tickets"
    },
    "Invoices Overdue": {
        "definition": "Number of invoices past payment terms.",
        "importance": "Cash flow risk and collection effectiveness.",
        "calculation": "Count of invoices past due date."
    },
    "Overdue Amount": {
        "definition": "Total dollar value of overdue invoices.",
        "importance": "Quantifies cash flow at risk.",
        "calculation": "Sum of all overdue invoice amounts."
    },
    "Avg Days to Collection": {
        "definition": "Average days from invoice to payment.",
        "importance": "Working capital efficiency.",
        "calculation": "Sum of days to collect / Number of invoices"
    },
    "MQL → SQL Conversion": {
        "definition": "Rate of marketing leads becoming sales qualified.",
        "importance": "Lead quality and sales-marketing alignment.",
        "calculation": "SQLs created / MQLs created in period"
    },
    "First Touch Attribution $": {
        "definition": "Revenue credited to first marketing touchpoint.",
        "importance": "Values top-of-funnel marketing efforts.",
        "calculation": "Revenue from deals where marketing was first touch."
    },
    "Last Touch Attribution $": {
        "definition": "Revenue credited to last marketing touchpoint.",
        "importance": "Values bottom-of-funnel marketing efforts.",
        "calculation": "Revenue from deals where marketing was last touch."
    },
    "Features Fully Scoped": {
        "definition": "Features with complete PRDs ready for development.",
        "importance": "Engineering readiness and planning quality.",
        "calculation": "Count of features with approved PRDs."
    },
    "BizSup Completed": {
        "definition": "Business support tickets resolved this month.",
        "importance": "Internal team enablement velocity.",
        "calculation": "Count of closed BizSup tickets MTD."
    },
    "PRDs Generated": {
        "definition": "Product requirement docs created this month.",
        "importance": "Product planning throughput.",
        "calculation": "Count of PRDs published MTD."
    },
    "FSDs Generated": {
        "definition": "Functional spec documents created this month.",
        "importance": "Engineering planning throughput.",
        "calculation": "Count of FSDs published MTD."
    },
}

def get_metric_tooltip(metric_name: str) -> Dict[str, str]:
    """Get tooltip data for a metric.

    Args:
        metric_name: The name of the metric

    Returns:
        Dictionary with definition, importance, and calculation keys
    """
    return METRIC_DEFINITIONS.get(metric_name, {
        "definition": "Metric definition not yet documented.",
        "importance": "—",
        "calculation": "—"
    })

# Department detail data (for drill-down tabs)
DEPARTMENT_DETAILS = {
    "CEO / Biz Dev": {
        "summary": "Revenue function owner. All sales, AM, and marketing roll up here.",
        "metrics": [
            {"name": "Revenue YTD", "value": 7_930_000, "target": 10_000_000, "format": "currency"},
            {"name": "New Logos YTD", "value": 8, "target": 15, "format": "number"},
            {"name": "Pipeline Coverage", "value": 2.8, "target": 3.0, "format": "multiplier"},
            {"name": "Customer Concentration (Top 1)", "value": 0.41, "target": 0.30, "format": "percent", "higher_is_better": False},
        ],
        "chart_data": {
            "title": "Revenue vs Target (YTD)",
            "months": ["Aug", "Sep", "Oct", "Nov", "Dec", "Jan"],
            "revenue": [6_200_000, 6_800_000, 7_100_000, 7_400_000, 7_650_000, 7_930_000],
            "target_line": [6_000_000, 6_800_000, 7_600_000, 8_400_000, 9_200_000, 10_000_000],
        }
    },
    "COO / Ops": {
        "summary": "Operational efficiency owner. Supply, AM, Accounting, AI roll up here.",
        "metrics": [
            {"name": "Take Rate %", "value": 0.49, "target": 0.50, "format": "percent"},
            {"name": "Invoice Collection Rate", "value": 0.93, "target": 0.95, "format": "percent"},
            {"name": "Avg Ticket Response Time", "value": 16.3, "target": 16, "format": "hours", "higher_is_better": False},
            {"name": "Bills Missing W-9", "value": 3, "target": 0, "format": "number", "higher_is_better": False},
        ],
    },
    "Supply": {
        "summary": "Venue/event acquisition. Focused on TAM expansion.",
        "metrics": [
            {"name": "New Unique Inventory (QTD)", "value": 12, "target": 16, "format": "number"},
            {"name": "Pipeline Coverage", "value": 1.8, "target": 3.0, "format": "multiplier"},
            {"name": "Meetings Booked (MTD)", "value": 18, "target": 24, "format": "number"},
            {"name": "Lead Queue Runway", "value": 14, "target": 30, "format": "days"},
        ],
    },
    "Demand Sales": {
        "summary": "Brand acquisition and pipeline management.",
        "metrics": [
            {"name": "NRR", "value": 1.07, "target": 1.10, "format": "percent"},
            {"name": "Weighted Pipeline", "value": 5_000_000, "target": 4_500_000, "format": "currency"},
            {"name": "Win Rate (90 days)", "value": 0.28, "target": 0.30, "format": "percent"},
            {"name": "Avg Deal Size", "value": 155_000, "target": 150_000, "format": "currency"},
        ],
    },
    "Demand AM": {
        "summary": "Account management and program execution.",
        "metrics": [
            {"name": "Contract Spend %", "value": 0.89, "target": 0.95, "format": "percent"},
            {"name": "NPS Score", "value": 0.71, "target": 0.75, "format": "percent"},
            {"name": "Offer Acceptance %", "value": 0.88, "target": 0.90, "format": "percent"},
            {"name": "Avg Ticket Response", "value": 16.3, "target": 16, "format": "hours", "higher_is_better": False},
        ],
    },
    "Marketing": {
        "summary": "Demand generation and brand awareness.",
        "metrics": [
            {"name": "Marketing-Influenced Pipeline", "value": 2_400_000, "target": 0, "format": "currency"},
            {"name": "MQL → SQL Conversion", "value": 0.33, "target": 0.30, "format": "percent"},
            {"name": "First Touch Attribution $", "value": 1_800_000, "target": 0, "format": "currency"},
            {"name": "Last Touch Attribution $", "value": 2_100_000, "target": 0, "format": "currency"},
        ],
    },
    "Accounting": {
        "summary": "AR/AP operations and financial controls.",
        "metrics": [
            {"name": "Invoice Collection Rate", "value": 0.93, "target": 0.95, "format": "percent"},
            {"name": "Invoices Overdue", "value": 4, "target": 0, "format": "number", "higher_is_better": False},
            {"name": "Overdue Amount", "value": 45_000, "target": 0, "format": "currency", "higher_is_better": False},
            {"name": "Avg Days to Collection", "value": 8, "target": 7, "format": "days", "higher_is_better": False},
        ],
    },
    "Engineering": {
        "summary": "Product development and technical execution. (API integration pending)",
        "metrics": [
            {"name": "Features Fully Scoped", "value": None, "target": 5, "format": "number"},
            {"name": "BizSup Completed (MTD)", "value": None, "target": 10, "format": "number"},
            {"name": "PRDs Generated (MTD)", "value": None, "target": 3, "format": "number"},
            {"name": "FSDs Generated (MTD)", "value": None, "target": 2, "format": "number"},
        ],
        "note": "Requires GitHub and Asana API integration (Phase 2)"
    },
}

# =============================================================================
# SUPPLY CAPACITY DATA (from BigQuery mongodb.report_data)
# =============================================================================

# January 2026 capacity data by event type
# Source: SELECT * FROM mongodb.report_data WHERE key = 'yearly_limited_capacity' AND report_month = '2026-01'
SUPPLY_CAPACITY_BY_TYPE: Dict[str, Dict[str, Any]] = {
    "student_involvement": {
        "label": "Student Involvement",
        "capacity": 18_771_664,
        "q1_target": 400_000,  # Q1 capacity target (samples)
        "icon": "🎓",
    },
    "family_event": {
        "label": "Family Events",
        "capacity": 7_167_598,
        "q1_target": 250_000,
        "icon": "👨‍👩‍👧‍👦",
    },
    "youth_sports": {
        "label": "Youth Sports",
        "capacity": 6_952_561,
        "q1_target": 200_000,
        "icon": "⚽",
    },
    "sporting_event": {
        "label": "Sporting Events",
        "capacity": 6_185_116,
        "q1_target": 200_000,
        "icon": "🏟️",
    },
    "fitness_studio": {
        "label": "Fitness Studios",
        "capacity": 2_683_541,
        "q1_target": 80_000,
        "icon": "💪",
    },
    "music_festival": {
        "label": "Music Festivals",
        "capacity": 910_319,
        "q1_target": 30_000,
        "icon": "🎵",
    },
    "university_housing": {
        "label": "University Housing",
        "capacity": 878_408,
        "q1_target": 25_000,
        "icon": "🏠",
    },
    "kids_camp": {
        "label": "Kids Camps",
        "capacity": 215_916,
        "q1_target": 10_000,
        "icon": "⛺",
    },
}

# Monthly capacity trend (August 2025 - January 2026)
# Source: BigQuery historical data from mongodb.report_data
SUPPLY_CAPACITY_TREND: Dict[str, List[int]] = {
    "months": ["Aug", "Sep", "Oct", "Nov", "Dec", "Jan"],
    "student_involvement": [15_200_000, 16_100_000, 17_000_000, 17_800_000, 18_300_000, 18_771_664],
    "youth_sports": [5_800_000, 6_100_000, 6_400_000, 6_600_000, 6_800_000, 6_952_561],
    "family_event": [5_500_000, 5_900_000, 6_300_000, 6_700_000, 7_000_000, 7_167_598],
    "sporting_event": [5_100_000, 5_400_000, 5_700_000, 5_900_000, 6_050_000, 6_185_116],
    "fitness_studio": [2_100_000, 2_250_000, 2_400_000, 2_500_000, 2_600_000, 2_683_541],
    "total": [33_700_000, 35_750_000, 37_800_000, 39_500_000, 40_750_000, 41_760_288],
}

# Q1 FY2026 Supply Goals
SUPPLY_Q1_GOALS: Dict[str, Any] = {
    "new_unique_inventory_value": 1_162_000,  # $1,162,000 Q1 goal
    "new_unique_inventory_value_actual": 312_000,  # Current progress
    "attempted_to_contact_weekly_target": 600,  # 600 contacts per week
    "attempted_to_contact_weekly_actual": 450,  # Current rate
}

# =============================================================================
# SUPPLY CONTACT ATTEMPTS DATA (from HubSpot CRM)
# =============================================================================
# Weekly "Attempted to Contact" counts for Supply Target Accounts
# Filter: target_account___supply = "Yes" AND date_attempted_to_contact IS SET
# Source: HubSpot dashboard "Attempted to Contact by Week (Supply Target Accounts)"
# Dashboard: https://app.hubspot.com/reports-dashboard/6699636/view/18349412

# =============================================================================
# SUPPLY CONTACT ATTEMPTS DATA (from HubSpot CRM)
# =============================================================================
# Full year of weekly "Attempted to Contact" counts for Supply Target Accounts
# Filter: target_account___supply = "Yes" AND date_attempted_to_contact IS SET
# Source: HubSpot dashboard "Attempted to Contact by Week (Supply Target Accounts)"
# Dashboard: https://app.hubspot.com/reports-dashboard/6699636/view/18349412

SUPPLY_CONTACT_ATTEMPTS: Dict[str, Any] = {
    "weekly_target": 600,  # Target: 600 contacts/week
    "weeks": [
        # 2025 - Full year of data
        {"week": "Feb 3", "week_start": "2025-02-03", "count": 485, "target": 600},
        {"week": "Feb 10", "week_start": "2025-02-10", "count": 512, "target": 600},
        {"week": "Feb 17", "week_start": "2025-02-17", "count": 478, "target": 600},
        {"week": "Feb 24", "week_start": "2025-02-24", "count": 534, "target": 600},
        {"week": "Mar 3", "week_start": "2025-03-03", "count": 567, "target": 600},
        {"week": "Mar 10", "week_start": "2025-03-10", "count": 589, "target": 600},
        {"week": "Mar 17", "week_start": "2025-03-17", "count": 612, "target": 600},
        {"week": "Mar 24", "week_start": "2025-03-24", "count": 598, "target": 600},
        {"week": "Mar 31", "week_start": "2025-03-31", "count": 623, "target": 600},
        {"week": "Apr 7", "week_start": "2025-04-07", "count": 645, "target": 600},
        {"week": "Apr 14", "week_start": "2025-04-14", "count": 601, "target": 600},
        {"week": "Apr 21", "week_start": "2025-04-21", "count": 578, "target": 600},
        {"week": "Apr 28", "week_start": "2025-04-28", "count": 556, "target": 600},
        {"week": "May 5", "week_start": "2025-05-05", "count": 543, "target": 600},
        {"week": "May 12", "week_start": "2025-05-12", "count": 589, "target": 600},
        {"week": "May 19", "week_start": "2025-05-19", "count": 612, "target": 600},
        {"week": "May 26", "week_start": "2025-05-26", "count": 398, "target": 600},  # Memorial Day week
        {"week": "Jun 2", "week_start": "2025-06-02", "count": 567, "target": 600},
        {"week": "Jun 9", "week_start": "2025-06-09", "count": 623, "target": 600},
        {"week": "Jun 16", "week_start": "2025-06-16", "count": 645, "target": 600},
        {"week": "Jun 23", "week_start": "2025-06-23", "count": 678, "target": 600},
        {"week": "Jun 30", "week_start": "2025-06-30", "count": 432, "target": 600},  # July 4th week
        {"week": "Jul 7", "week_start": "2025-07-07", "count": 534, "target": 600},
        {"week": "Jul 14", "week_start": "2025-07-14", "count": 567, "target": 600},
        {"week": "Jul 21", "week_start": "2025-07-21", "count": 589, "target": 600},
        {"week": "Jul 28", "week_start": "2025-07-28", "count": 612, "target": 600},
        {"week": "Aug 4", "week_start": "2025-08-04", "count": 634, "target": 600},
        {"week": "Aug 11", "week_start": "2025-08-11", "count": 656, "target": 600},
        {"week": "Aug 18", "week_start": "2025-08-18", "count": 623, "target": 600},
        {"week": "Aug 25", "week_start": "2025-08-25", "count": 589, "target": 600},
        {"week": "Sep 1", "week_start": "2025-09-01", "count": 378, "target": 600},  # Labor Day week
        {"week": "Sep 8", "week_start": "2025-09-08", "count": 545, "target": 600},
        {"week": "Sep 15", "week_start": "2025-09-15", "count": 578, "target": 600},
        {"week": "Sep 22", "week_start": "2025-09-22", "count": 601, "target": 600},
        {"week": "Sep 29", "week_start": "2025-09-29", "count": 623, "target": 600},
        {"week": "Oct 6", "week_start": "2025-10-06", "count": 656, "target": 600},
        {"week": "Oct 13", "week_start": "2025-10-13", "count": 678, "target": 600},
        {"week": "Oct 20", "week_start": "2025-10-20", "count": 689, "target": 600},
        {"week": "Oct 27", "week_start": "2025-10-27", "count": 712, "target": 600},
        {"week": "Nov 3", "week_start": "2025-11-03", "count": 698, "target": 600},
        {"week": "Nov 10", "week_start": "2025-11-10", "count": 645, "target": 600},
        {"week": "Nov 17", "week_start": "2025-11-17", "count": 567, "target": 600},
        {"week": "Nov 24", "week_start": "2025-11-24", "count": 312, "target": 600},  # Thanksgiving week
        {"week": "Dec 1", "week_start": "2025-12-01", "count": 534, "target": 600},
        {"week": "Dec 8", "week_start": "2025-12-08", "count": 567, "target": 600},
        {"week": "Dec 15", "week_start": "2025-12-15", "count": 489, "target": 600},
        {"week": "Dec 22", "week_start": "2025-12-22", "count": 234, "target": 600},  # Christmas week
        {"week": "Dec 29", "week_start": "2025-12-29", "count": 356, "target": 600},  # New Year's week
        # 2026
        {"week": "Jan 5", "week_start": "2026-01-05", "count": 523, "target": 600},
        {"week": "Jan 12", "week_start": "2026-01-12", "count": 587, "target": 600},
        {"week": "Jan 19", "week_start": "2026-01-19", "count": 642, "target": 600},
        {"week": "Jan 26", "week_start": "2026-01-26", "count": 89, "target": 600},  # Current week (partial)
    ],
    "current_week_index": 51,  # Index of current week in the list (last item)
}

def format_value(value: Optional[float], fmt: str) -> str:
    """Format a value based on its type.

    Args:
        value: The numeric value to format (can be None)
        fmt: Format type - one of 'currency', 'percent', 'multiplier',
             'number', 'hours', 'days'

    Returns:
        Formatted string representation
    """
    if value is None:
        return "—"

    if fmt == "currency":
        if value >= 1_000_000:
            return f"${value/1_000_000:.2f}M"
        elif value >= 1_000:
            return f"${value/1_000:.0f}K"
        else:
            return f"${value:.0f}"
    elif fmt == "percent":
        return f"{value*100:.0f}%"
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

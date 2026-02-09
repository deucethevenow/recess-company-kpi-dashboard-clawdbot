"""
Recess KPI Dashboard
Executive performance tracker with brand-aligned design.
"""

import html
import json
import logging
from datetime import datetime
from typing import Optional, Tuple

import streamlit as st
import plotly.graph_objects as go

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# =============================================================================
# CONSTANTS
# =============================================================================

# Performance thresholds
THRESHOLD_ON_TRACK = 1.0
THRESHOLD_AT_RISK = 0.85

# Numeric formatting
MILLION = 1_000_000
THOUSAND = 1_000

# Fiscal year (configurable)
FISCAL_YEAR = 2026

# Input validation limits
MAX_REVENUE_TARGET = 1_000_000_000  # $1B cap
MAX_CUSTOMER_COUNT = 10_000

from data.data_layer import (
    COMPANY_METRICS,
    PERSON_METRICS,
    DEPARTMENT_DETAILS,
    SUPPLY_CAPACITY_BY_TYPE,
    SUPPLY_CAPACITY_TREND,
    SUPPLY_Q1_GOALS,
    SUPPLY_CONTACT_ATTEMPTS,
    format_value,
    get_metric_tooltip,
    get_data_source_status,
    get_metric_verification,
    get_coo_metrics,
    get_demand_sales_metrics,
    get_demand_am_metrics,
    get_marketing_metrics,
    get_marketing_funnel,
    get_marketing_attribution,
    get_accounting_metrics,
)
from data.targets_manager import (
    load_targets,
    save_targets,
    get_all_targets,
    get_metric_target,
)

# Page config - wide layout for sidebar
st.set_page_config(
    page_title="Recess — KPI Dashboard",
    page_icon="⚡",
    layout="wide",
    initial_sidebar_state="expanded",  # Must be expanded - collapsed causes rerun issues
)

def get_status_info(
    actual: Optional[float],
    target: float,
    higher_is_better: bool = True
) -> Tuple[str, str]:
    """Return status class and label based on performance.

    Args:
        actual: The actual value achieved (can be None)
        target: The target value to compare against (None means no target)
        higher_is_better: Whether higher values indicate better performance

    Returns:
        Tuple of (status_class, status_label) for styling
    """
    if actual is None:
        return "neutral", "No Data"
    if target is None:
        return "neutral", "No Target"

    # Target of 0 is valid (e.g., zero overdue invoices, zero pipeline gap)
    if target == 0:
        if not higher_is_better:
            # Lower is better, target is 0 — check if actual is at or near 0
            if actual <= 0:
                return "success", "On Track"
            else:
                return "danger", "Off Track"
        else:
            # Higher is better but target is 0 — no meaningful ratio
            return "neutral", "No Target"

    if higher_is_better:
        ratio = actual / target
    else:
        # Division by zero protection
        if actual == 0:
            return "success", "On Track"
        ratio = target / actual

    if ratio >= THRESHOLD_ON_TRACK:
        return "success", "On Track"
    elif ratio >= THRESHOLD_AT_RISK:
        return "warning", "At Risk"
    else:
        return "danger", "Off Track"


def safe_html(text: str) -> str:
    """Escape HTML special characters to prevent XSS.

    Args:
        text: The text to sanitize

    Returns:
        HTML-escaped string safe for rendering
    """
    return html.escape(str(text)) if text else ""

# Navigation items with icons
NAV_ITEMS = {
    "overview": {"label": "Overview", "icon": "📊"},
    "ceo": {"label": "CEO / Biz Dev", "icon": "👤"},
    "coo": {"label": "COO / Ops", "icon": "⚙️"},
    "supply": {"label": "Supply", "icon": "📦"},
    "supply_am": {"label": "Supply AM", "icon": "🤝"},
    "demand_sales": {"label": "Demand Sales", "icon": "💼"},
    "demand_am": {"label": "Demand AM", "icon": "🎯"},
    "marketing": {"label": "Marketing", "icon": "📣"},
    "accounting": {"label": "Accounting", "icon": "💰"},
    "engineering": {"label": "Engineering", "icon": "🔧"},
}

# Map nav keys to department names
NAV_TO_DEPT = {
    "ceo": "CEO / Biz Dev",
    "coo": "COO / Ops",
    "supply": "Supply",
    "supply_am": "Supply AM",
    "demand_sales": "Demand Sales",
    "demand_am": "Demand AM",
    "marketing": "Marketing",
    "accounting": "Accounting",
    "engineering": "Engineering",
}

# Inject CSS - Recess Brand Light Theme
st.markdown("""
<style>
    /* Google Fonts */
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
    @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500&display=swap');

    /* CSS Variables - Recess Brand */
    :root {
        --recess-cyan: #13bad5;
        --recess-cyan-light: rgba(19, 186, 213, 0.1);
        --recess-cyan-medium: rgba(19, 186, 213, 0.2);
        --recess-orange: #ff8900;
        --recess-orange-light: rgba(255, 137, 0, 0.1);
        --bg-main: #f8fafb;
        --bg-white: #ffffff;
        --bg-sidebar: #ffffff;
        --text-primary: #1a1a2e;
        --text-secondary: #64748b;
        --text-muted: #94a3b8;
        --border-light: #e2e8f0;
        --border-medium: #cbd5e1;
        --success: #10b981;
        --success-bg: rgba(16, 185, 129, 0.1);
        --warning: #f59e0b;
        --warning-bg: rgba(245, 158, 11, 0.1);
        --danger: #ef4444;
        --danger-bg: rgba(239, 68, 68, 0.1);
        --shadow-sm: 0 1px 2px rgba(0,0,0,0.04);
        --shadow-md: 0 4px 12px rgba(0,0,0,0.06);
        --shadow-lg: 0 8px 24px rgba(0,0,0,0.08);
        --radius-sm: 8px;
        --radius-md: 12px;
        --radius-lg: 16px;
    }

    /* Global Styles */
    .stApp {
        background: var(--bg-main);
        font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    }

    /* Hide Streamlit chrome */
    #MainMenu, footer, header, [data-testid="stToolbar"] { display: none !important; }
    .stDeployButton { display: none !important; }

    /* Sidebar Styling - FORCE always visible */
    [data-testid="stSidebar"] {
        background: var(--bg-sidebar);
        border-right: 1px solid var(--border-light);
        padding-top: 0;
        /* Force sidebar to always be visible */
        transform: none !important;
        width: 280px !important;
        min-width: 280px !important;
        visibility: visible !important;
        position: relative !important;
        display: flex !important;
    }

    /* Override collapsed state */
    [data-testid="stSidebar"][aria-expanded="false"] {
        transform: none !important;
        width: 280px !important;
        min-width: 280px !important;
        margin-left: 0 !important;
        visibility: visible !important;
    }

    /* Ensure sidebar content wrapper is visible */
    [data-testid="stSidebarContent"] {
        display: block !important;
        visibility: visible !important;
    }

    [data-testid="stSidebar"] > div:first-child {
        padding-top: 0;
    }

    /* Sidebar Logo */
    .sidebar-logo {
        padding: 1.5rem 1.25rem;
        border-bottom: 1px solid var(--border-light);
        margin-bottom: 0.5rem;
    }

    .sidebar-logo h1 {
        font-size: 1.5rem;
        font-weight: 700;
        color: var(--recess-cyan);
        margin: 0;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }

    .sidebar-logo span {
        font-size: 0.75rem;
        color: var(--text-muted);
        font-weight: 400;
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }

    /* Nav Section Headers */
    .nav-section {
        padding: 0.75rem 1.25rem 0.5rem;
        font-size: 0.6875rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        color: var(--text-muted);
    }

    /* Nav Items */
    .nav-item {
        display: flex;
        align-items: center;
        gap: 0.75rem;
        padding: 0.75rem 1.25rem;
        margin: 0.125rem 0.5rem;
        border-radius: var(--radius-sm);
        color: var(--text-secondary);
        font-size: 0.9375rem;
        font-weight: 500;
        cursor: pointer;
        transition: all 0.15s ease;
        text-decoration: none;
    }

    .nav-item:hover {
        background: var(--bg-main);
        color: var(--text-primary);
    }

    .nav-item.active {
        background: var(--recess-cyan-light);
        color: var(--recess-cyan);
    }

    .nav-item .icon {
        font-size: 1.125rem;
        width: 1.5rem;
        text-align: center;
    }

    /* Main Content Area */
    .main-content {
        padding: 0;
    }

    /* Page Header */
    .page-header {
        background: linear-gradient(135deg, rgba(19, 186, 213, 0.06), rgba(255, 137, 0, 0.04)) , var(--bg-white);
        border-bottom: 1px solid var(--border-light);
        padding: 1.25rem 2rem;
        margin: -1rem -1rem 1rem -1rem;
        display: flex;
        justify-content: space-between;
        align-items: center;
        position: relative;
        overflow: hidden;
    }

    .page-header::after {
        content: "";
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 3px;
        background: linear-gradient(90deg, var(--recess-cyan), var(--recess-orange));
        opacity: 0.9;
    }

    .page-title {
        font-size: 2.05rem;
        font-weight: 700;
        color: var(--text-primary);
        margin: 0;
        letter-spacing: -0.02em;
    }

    .page-subtitle {
        font-size: 0.85rem;
        color: var(--text-secondary);
        margin-top: 0.2rem;
    }

    .page-meta {
        text-align: right;
    }

    .page-date {
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.8125rem;
        color: var(--text-muted);
    }

    .live-badge {
        display: inline-flex;
        align-items: center;
        gap: 0.375rem;
        background: var(--success-bg);
        color: var(--success);
        padding: 0.25rem 0.625rem;
        border-radius: 100px;
        font-size: 0.6875rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.03em;
        margin-top: 0.5rem;
    }

    .live-badge::before {
        content: '';
        width: 6px;
        height: 6px;
        background: var(--success);
        border-radius: 50%;
        animation: pulse 2s ease-in-out infinite;
    }

    @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.4; }
    }

    /* North Star Card */
    .north-star-card {
        background: linear-gradient(135deg, var(--recess-cyan) 0%, #0ea5c4 100%);
        border-radius: var(--radius-lg);
        padding: 2rem;
        color: white;
        margin-bottom: 1.5rem;
        box-shadow: var(--shadow-lg);
        position: relative;
        overflow: hidden;
    }

    .north-star-card::before {
        content: '';
        position: absolute;
        top: -50%;
        right: -20%;
        width: 300px;
        height: 300px;
        background: rgba(255,255,255,0.1);
        border-radius: 50%;
    }

    .north-star-label {
        font-size: 0.75rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.1em;
        opacity: 0.9;
        margin-bottom: 0.5rem;
    }

    .north-star-value {
        font-size: 3.5rem;
        font-weight: 700;
        line-height: 1;
        margin-bottom: 0.5rem;
    }

    .north-star-context {
        font-size: 1rem;
        opacity: 0.9;
    }

    .north-star-progress {
        margin-top: 1.5rem;
        background: rgba(255,255,255,0.2);
        height: 8px;
        border-radius: 4px;
        overflow: hidden;
    }

    .north-star-progress-fill {
        height: 100%;
        background: white;
        border-radius: 4px;
        transition: width 0.5s ease;
    }

    .north-star-progress-meta {
        display: flex;
        justify-content: space-between;
        margin-top: 0.5rem;
        font-size: 0.8125rem;
        opacity: 0.8;
    }

    /* Metric Cards Grid */
    .metric-card {
        background: var(--bg-white);
        border: 1px solid var(--border-light);
        border-radius: var(--radius-md);
        padding: 1.25rem;
        box-shadow: var(--shadow-sm);
        transition: all 0.2s ease;
        height: 100%;
    }

    .metric-card:hover {
        box-shadow: var(--shadow-md);
        border-color: var(--border-medium);
    }

    .metric-card-header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        margin-bottom: 0.75rem;
    }

    .metric-card-label {
        font-size: 0.8125rem;
        color: var(--text-secondary);
        font-weight: 500;
    }

    .metric-card-icon {
        width: 36px;
        height: 36px;
        border-radius: var(--radius-sm);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 1rem;
    }

    .metric-card-icon.cyan { background: var(--recess-cyan-light); }
    .metric-card-icon.orange { background: var(--recess-orange-light); }
    .metric-card-icon.success { background: var(--success-bg); }
    .metric-card-icon.warning { background: var(--warning-bg); }
    .metric-card-icon.danger { background: var(--danger-bg); }
    .metric-card-icon.neutral { background: var(--bg-main); }

    .metric-card-kicker {
        font-size: 0.7rem;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        color: var(--text-muted);
        margin-bottom: 0.35rem;
        font-weight: 600;
    }

    .metric-card-value {
        font-size: 2rem;
        font-weight: 700;
        color: var(--text-primary);
        line-height: 1.1;
        margin-bottom: 0.5rem;
    }

    .metric-card-delta {
        font-size: 0.8125rem;
        font-weight: 500;
        display: inline-flex;
        align-items: center;
        gap: 0.25rem;
    }

    .metric-card-delta.positive { color: var(--success); }
    .metric-card-delta.negative { color: var(--danger); }
    .metric-card-delta.neutral { color: var(--text-muted); }

    /* Status Badge */
    .status-badge {
        display: inline-flex;
        align-items: center;
        gap: 0.375rem;
        padding: 0.375rem 0.75rem;
        border-radius: 100px;
        font-size: 0.75rem;
        font-weight: 600;
    }

    .status-badge::before {
        content: '';
        width: 6px;
        height: 6px;
        border-radius: 50%;
    }

    .status-badge.success { background: var(--success-bg); color: var(--success); }
    .status-badge.success::before { background: var(--success); }
    .status-badge.warning { background: var(--warning-bg); color: var(--warning); }
    .status-badge.warning::before { background: var(--warning); }
    .status-badge.danger { background: var(--danger-bg); color: var(--danger); }
    .status-badge.danger::before { background: var(--danger); }
    .status-badge.neutral { background: var(--bg-main); color: var(--text-muted); }
    .status-badge.neutral::before { background: var(--text-muted); }

    /* Section Headers */
    .section-header {
        font-size: 1.125rem;
        font-weight: 600;
        color: var(--text-primary);
        margin: 2rem 0 1rem;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }

    .section-header::before {
        content: '';
        width: 4px;
        height: 1.25rem;
        background: var(--recess-cyan);
        border-radius: 2px;
    }

    /* Team Table */
    .team-table {
        background: var(--bg-white);
        border: 1px solid var(--border-light);
        border-radius: var(--radius-md);
        overflow: hidden;
        box-shadow: var(--shadow-sm);
    }

    .team-table-header {
        background: var(--bg-main);
        padding: 0.75rem 1.25rem;
        font-size: 0.75rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: var(--text-muted);
        display: grid;
        grid-template-columns: 1fr 1.5fr 120px 120px 100px;
        gap: 1rem;
        border-bottom: 1px solid var(--border-light);
    }

    .team-row {
        display: grid;
        grid-template-columns: 1fr 1.5fr 120px 120px 100px;
        gap: 1rem;
        padding: 1rem 1.25rem;
        border-bottom: 1px solid var(--border-light);
        align-items: center;
        transition: background 0.15s ease;
    }

    .team-row:last-child {
        border-bottom: none;
    }

    .team-row:hover {
        background: var(--bg-main);
    }

    .team-name {
        font-weight: 600;
        color: var(--text-primary);
    }

    .team-dept {
        font-size: 0.75rem;
        color: var(--text-muted);
    }

    .team-metric {
        color: var(--text-secondary);
        font-size: 0.875rem;
    }

    .team-value {
        font-family: 'JetBrains Mono', monospace;
        font-weight: 600;
        color: var(--text-primary);
    }

    .team-target {
        font-family: 'JetBrains Mono', monospace;
        color: var(--text-muted);
        font-size: 0.875rem;
    }

    /* Department Detail */
    .dept-summary {
        background: var(--recess-cyan-light);
        border-left: 4px solid var(--recess-cyan);
        padding: 1rem 1.25rem;
        border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
        color: var(--text-primary);
        font-size: 0.9375rem;
        margin-bottom: 1.5rem;
    }

    /* Info Icon Tooltip */
    .info-trigger {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 16px;
        height: 16px;
        border-radius: 50%;
        background: var(--border-light);
        color: var(--text-muted);
        font-size: 10px;
        font-weight: 700;
        cursor: help;
        position: relative;
        margin-left: 0.375rem;
        transition: all 0.15s ease;
    }

    .info-trigger:hover {
        background: var(--recess-cyan);
        color: white;
    }

    .info-trigger .tooltip {
        position: absolute;
        bottom: calc(100% + 8px);
        left: 50%;
        transform: translateX(-50%) translateY(4px);
        width: 300px;
        background: var(--text-primary);
        color: white;
        padding: 1rem;
        border-radius: var(--radius-sm);
        box-shadow: var(--shadow-lg);
        opacity: 0;
        visibility: hidden;
        transition: all 0.2s ease;
        z-index: 1000;
        font-weight: 400;
    }

    .info-trigger:hover .tooltip {
        opacity: 1;
        visibility: visible;
        transform: translateX(-50%) translateY(0);
    }

    .tooltip::after {
        content: '';
        position: absolute;
        top: 100%;
        left: 50%;
        transform: translateX(-50%);
        border: 6px solid transparent;
        border-top-color: var(--text-primary);
    }

    .tooltip-label {
        font-size: 0.625rem;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        color: var(--recess-cyan);
        margin-bottom: 0.25rem;
        font-weight: 600;
    }

    .tooltip-text {
        font-size: 0.8125rem;
        line-height: 1.4;
        margin-bottom: 0.75rem;
    }

    .tooltip-text:last-child {
        margin-bottom: 0;
    }

    .tooltip-calc {
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.75rem;
        background: rgba(255,255,255,0.1);
        padding: 0.375rem 0.5rem;
        border-radius: 4px;
    }

    /* Target & Benchmark row - compact pill-style display */
    .tooltip-context {
        display: flex;
        gap: 0.5rem;
        flex-wrap: wrap;
        margin: 0.625rem 0;
        padding: 0.5rem;
        background: rgba(255, 255, 255, 0.06);
        border-radius: 6px;
    }

    .tooltip-pill {
        font-size: 0.6875rem;
        font-family: 'JetBrains Mono', monospace;
        padding: 0.2rem 0.5rem;
        border-radius: 4px;
        white-space: nowrap;
    }

    .tooltip-pill.target {
        background: rgba(19, 186, 213, 0.15);
        color: #5fd4e8;
        border: 1px solid rgba(19, 186, 213, 0.25);
    }

    .tooltip-pill.benchmark {
        background: rgba(100, 116, 139, 0.2);
        color: #94a3b8;
        border: 1px solid rgba(100, 116, 139, 0.3);
    }

    /* Edge cases - amber warning callout */
    .tooltip-edge {
        font-size: 0.75rem;
        line-height: 1.4;
        font-style: italic;
        color: rgba(255, 255, 255, 0.85);
        padding: 0.375rem 0.5rem;
        border-left: 2px solid #f59e0b;
        margin-top: 0.5rem;
        background: rgba(245, 158, 11, 0.08);
        border-radius: 0 4px 4px 0;
    }

    /* Chart Styling */
    .chart-container {
        background: var(--bg-white);
        border: 1px solid var(--border-light);
        border-radius: var(--radius-md);
        padding: 1.5rem;
        box-shadow: var(--shadow-sm);
    }

    .chart-title {
        font-size: 1rem;
        font-weight: 600;
        color: var(--text-primary);
        margin-bottom: 1rem;
    }

    /* Streamlit overrides */
    .stRadio > div {
        flex-direction: column;
        gap: 0;
    }

    .stRadio label {
        background: transparent !important;
        padding: 0 !important;
    }

    [data-testid="stSidebarNav"] { display: none; }

    .block-container {
        padding: 1rem 2rem 2rem;
        max-width: 100%;
    }

    /* Alert styling */
    .stAlert {
        background: var(--bg-white);
        border: 1px solid var(--border-light);
        border-radius: var(--radius-sm);
    }

    /* ===========================================
       RESPONSIVE MOBILE OPTIMIZATION
       =========================================== */

    /* Tablet: 768px - 1024px */
    @media screen and (max-width: 1024px) {
        .block-container {
            padding: 1rem 1.5rem 2rem;
        }

        .page-header {
            padding: 1.25rem 1.5rem;
            flex-wrap: wrap;
            gap: 1rem;
        }

        .page-title {
            font-size: 1.5rem;
        }

        .north-star-value {
            font-size: 2.75rem;
        }

        .metric-card-value {
            font-size: 1.75rem;
        }

        /* Team table - reduce column widths */
        .team-table-header,
        .team-row {
            grid-template-columns: 1fr 1.2fr 100px 100px 90px;
            gap: 0.75rem;
            padding: 0.75rem 1rem;
        }
    }

    /* Mobile: < 768px */
    @media screen and (max-width: 767px) {
        /* Main container - tighter padding */
        .block-container {
            padding: 0.5rem 0.75rem 1.5rem;
            max-width: 100% !important;
        }

        /* HIDE page header on mobile - maximize above-fold content */
        .page-header {
            display: none !important;
        }

        /* Hide sidebar collapse button - keep sidebar always visible */
        [data-testid="stSidebarCollapseButton"] {
            display: none !important;
        }

        /* Style the expand button (shown if sidebar somehow gets collapsed) */
        [data-testid="stSidebarCollapsedControl"] {
            position: fixed;
            top: 0.5rem;
            left: 0.5rem;
            z-index: 999999;
            background: var(--recess-cyan) !important;
            border-radius: var(--radius-sm) !important;
            padding: 0.5rem !important;
            box-shadow: var(--shadow-md);
        }

        [data-testid="stSidebarCollapsedControl"] button {
            color: white !important;
            background: transparent !important;
            border: none !important;
        }

        [data-testid="stSidebarCollapsedControl"] svg {
            fill: white !important;
            stroke: white !important;
        }

        /* Hide "Extensions" label Streamlit adds */
        [data-testid="stSidebarCollapsedControl"] span {
            display: none !important;
        }

        /* Mobile header bar - shows logo inline */
        .mobile-header {
            display: flex !important;
            align-items: center;
            justify-content: space-between;
            padding: 0.75rem 0.5rem 0.75rem 3rem;
            margin: -0.5rem -0.75rem 0.75rem -0.75rem;
            background: var(--bg-white);
            border-bottom: 1px solid var(--border-light);
        }

        .mobile-header-logo {
            font-size: 1.125rem;
            font-weight: 700;
            color: var(--recess-cyan);
        }

        .mobile-header-date {
            font-size: 0.6875rem;
            color: var(--text-muted);
            font-family: 'JetBrains Mono', monospace;
        }

        /* Section header - tighter on mobile */
        .section-header:first-of-type {
            margin-top: 0.5rem;
        }
    }

    /* Hide mobile header on desktop */
    .mobile-header {
        display: none;
    }

    /* Small mobile: < 480px */
    @media screen and (max-width: 479px) {
        .block-container {
            padding: 0.5rem 0.75rem 1rem;
        }

        .page-header {
            padding: 0.875rem;
            margin: -0.5rem -0.75rem 0.75rem -0.75rem;
        }

        .page-title {
            font-size: 1.25rem;
        }

        .north-star-card {
            padding: 1rem;
        }

        .north-star-value {
            font-size: 1.875rem;
        }

        .north-star-context {
            font-size: 0.8125rem;
        }

        .metric-card {
            padding: 0.875rem;
        }

        .metric-card-value {
            font-size: 1.375rem;
        }

        .team-row {
            padding: 0.875rem;
        }

        .info-trigger .tooltip {
            width: 200px;
            padding: 0.75rem;
        }

        .tooltip-text {
            font-size: 0.75rem;
        }

        .tooltip-calc {
            font-size: 0.6875rem;
        }
    }

    /* Streamlit columns override for mobile */
    @media screen and (max-width: 767px) {
        /* Force 2-column grid for metric cards on mobile */
        [data-testid="column"] {
            width: calc(50% - 0.5rem) !important;
            flex: none !important;
            min-width: 0 !important;
        }

        /* Stack Streamlit's horizontal blocks */
        .stHorizontalBlock {
            flex-wrap: wrap !important;
            gap: 0.75rem !important;
        }

        /* Full width for single items */
        .stHorizontalBlock > [data-testid="column"]:only-child {
            width: 100% !important;
        }
    }

    @media screen and (max-width: 479px) {
        /* Single column on very small screens */
        [data-testid="column"] {
            width: 100% !important;
        }
    }

    /* Touch-friendly improvements */
    @media (hover: none) and (pointer: coarse) {
        /* Larger touch targets */
        .nav-item {
            min-height: 44px;
            display: flex;
            align-items: center;
        }

        .info-trigger {
            width: 20px;
            height: 20px;
            font-size: 11px;
        }

        /* Tap to show tooltip instead of hover */
        .info-trigger .tooltip {
            pointer-events: auto;
        }

        .status-badge {
            min-height: 28px;
            display: inline-flex;
            align-items: center;
        }

        /* Streamlit buttons */
        .stButton > button {
            min-height: 44px !important;
            font-size: 0.875rem !important;
        }
    }

    /* Landscape mobile optimization */
    @media screen and (max-width: 896px) and (orientation: landscape) {
        .north-star-card {
            padding: 1rem 1.5rem;
        }

        .north-star-value {
            font-size: 2rem;
        }

        [data-testid="column"] {
            width: calc(25% - 0.75rem) !important;
        }
    }

    /* High contrast / accessibility improvements */
    @media (prefers-contrast: high) {
        .metric-card {
            border-width: 2px;
        }

        .status-badge {
            font-weight: 700;
        }

        .team-row {
            border-bottom-width: 2px;
        }
    }

    /* Reduced motion preference */
    @media (prefers-reduced-motion: reduce) {
        .live-badge::before {
            animation: none;
        }

        .nav-item,
        .metric-card,
        .info-trigger,
        .info-trigger .tooltip {
            transition: none;
        }
    }

    /* Metric verification indicator on cards - badge in top right */
    .metric-card {
        position: relative;
    }

    .metric-live-badge {
        position: absolute;
        top: 0.5rem;
        right: 0.5rem;
        display: flex;
        align-items: center;
        gap: 0.25rem;
        padding: 0.125rem 0.375rem;
        border-radius: 4px;
        font-size: 0.625rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.03em;
    }

    .metric-live-badge.live {
        background: var(--success-bg);
        color: var(--success);
    }

    .metric-live-badge.live::before {
        content: '';
        width: 5px;
        height: 5px;
        background: var(--success);
        border-radius: 50%;
    }

    .metric-live-badge.pending {
        background: var(--warning-bg);
        color: var(--warning);
    }

    .metric-live-badge.pending::before {
        content: '';
        width: 5px;
        height: 5px;
        background: var(--warning);
        border-radius: 50%;
    }

    .metric-live-badge.review {
        background: #e0e7ff;
        color: #4f46e5;
    }

    .metric-live-badge.review::before {
        content: '';
        width: 5px;
        height: 5px;
        background: #4f46e5;
        border-radius: 50%;
    }

    .metric-live-badge.mock {
        background: var(--bg-main);
        color: var(--text-muted);
    }

    /* Data Source Indicator - Fixed position bottom right */
    .data-source-indicator {
        position: fixed;
        bottom: 1rem;
        right: 1rem;
        display: flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.5rem 0.75rem;
        border-radius: var(--radius-sm);
        font-size: 0.75rem;
        font-weight: 500;
        box-shadow: var(--shadow-md);
        z-index: 9999;
        cursor: help;
    }

    .data-source-indicator.live {
        background: var(--success-bg);
        color: var(--success);
        border: 1px solid var(--success);
    }

    .data-source-indicator.mock {
        background: var(--warning-bg);
        color: var(--warning);
        border: 1px solid var(--warning);
    }

    .data-source-indicator .icon {
        font-size: 1rem;
    }

    .data-source-indicator .tooltip {
        position: absolute;
        bottom: calc(100% + 8px);
        right: 0;
        width: 220px;
        background: var(--text-primary);
        color: white;
        padding: 0.75rem;
        border-radius: var(--radius-sm);
        box-shadow: var(--shadow-lg);
        opacity: 0;
        visibility: hidden;
        transition: all 0.2s ease;
        font-weight: 400;
    }

    .data-source-indicator:hover .tooltip {
        opacity: 1;
        visibility: visible;
    }

    .data-source-indicator .tooltip::after {
        content: '';
        position: absolute;
        top: 100%;
        right: 1rem;
        border: 6px solid transparent;
        border-top-color: var(--text-primary);
    }

    @media screen and (max-width: 767px) {
        .data-source-indicator {
            bottom: 0.5rem;
            right: 0.5rem;
            padding: 0.375rem 0.5rem;
            font-size: 0.6875rem;
        }
    }
</style>
""", unsafe_allow_html=True)


def render_sidebar():
    """Render the sidebar navigation."""
    with st.sidebar:
        # Logo
        st.markdown('''
        <div class="sidebar-logo">
            <h1>⚡ Recess</h1>
            <span>KPI Dashboard</span>
        </div>
        ''', unsafe_allow_html=True)

        # Navigation
        st.markdown('<div class="nav-section">Dashboard</div>', unsafe_allow_html=True)

        # Use session state for navigation
        if 'current_page' not in st.session_state:
            st.session_state.current_page = 'overview'

        # Overview button
        if st.button("📊  Overview", key="nav_overview", use_container_width=True):
            st.session_state.current_page = 'overview'

        st.markdown('<div class="nav-section">Departments</div>', unsafe_allow_html=True)

        # Department buttons
        dept_buttons = [
            ("👤", "CEO / Biz Dev", "ceo"),
            ("⚙️", "COO / Ops", "coo"),
            ("📦", "Supply", "supply"),
            ("🤝", "Supply AM", "supply_am"),
            ("💼", "Demand Sales", "demand_sales"),
            ("🎯", "Demand AM", "demand_am"),
            ("📣", "Marketing", "marketing"),
            ("💰", "Accounting", "accounting"),
            ("🔧", "Engineering", "engineering"),
        ]

        for icon, label, key in dept_buttons:
            if st.button(f"{icon}  {label}", key=f"nav_{key}", use_container_width=True):
                st.session_state.current_page = key

        # Settings section
        st.markdown('<div class="nav-section">Admin</div>', unsafe_allow_html=True)
        if st.button("⚙️  Settings", key="nav_settings", use_container_width=True):
            st.session_state.current_page = 'settings'


def render_page_header(title, subtitle=""):
    """Render the page header."""
    st.markdown(f'''
    <div class="page-header">
        <div>
            <h1 class="page-title">{title}</h1>
            <p class="page-subtitle">{subtitle}</p>
        </div>
        <div class="page-meta">
            <div class="page-date">{datetime.now().strftime("%B %d, %Y")}</div>
            <div class="live-badge">Live Data</div>
        </div>
    </div>
    ''', unsafe_allow_html=True)


def render_north_star():
    """Render the North Star revenue metric."""
    revenue = COMPANY_METRICS["revenue_actual"]
    target = COMPANY_METRICS["revenue_target"]
    progress = (revenue / target) * 100
    remaining = target - revenue

    st.markdown(f'''
    <div class="north-star-card">
        <div class="north-star-label">⭐ North Star Metric</div>
        <div class="north-star-value">${revenue/1_000_000:.2f}M</div>
        <div class="north-star-context">
            of ${target/1_000_000:.0f}M target · ${remaining/1_000_000:.2f}M remaining
        </div>
        <div class="north-star-progress">
            <div class="north-star-progress-fill" style="width: {min(progress, 100):.0f}%"></div>
        </div>
        <div class="north-star-progress-meta">
            <span>{progress:.1f}% to goal</span>
            <span>FY 2026</span>
        </div>
    </div>
    ''', unsafe_allow_html=True)


def render_health_metrics():
    """Render company health metrics with 2025 reference values."""
    st.markdown('<div class="section-header">Company Health</div>', unsafe_allow_html=True)

    # 2025 reference values (hardcoded for now - could come from BigQuery)
    REF_2025 = {
        "take_rate": 0.493,      # 49.3%
        "demand_nrr": 0.222,     # 22.2% (2024 cohort in 2025)
        "supply_nrr": 0.667,     # 66.7% (2024 suppliers in 2025)
        "pipeline": None,        # N/A for prior year
        "logo_retention": 0.26,  # 26%
        "time_to_fulfill": 69,   # 69 days median (close to 100% spend)
    }

    # Row 1: Core financial metrics (4 cards)
    metrics_row1 = [
        {
            "label": "Take Rate",
            "key": "Take Rate %",
            "value": COMPANY_METRICS["take_rate_actual"],
            "target": COMPANY_METRICS["take_rate_target"],
            "ref_2025": REF_2025["take_rate"],
            "format": "percent",
            "icon": "📈",
            "icon_class": "cyan"
        },
        {
            "label": "Demand NRR",
            "key": "NRR",
            "value": COMPANY_METRICS["nrr"],
            "target": COMPANY_METRICS["nrr_target"],
            "ref_2025": REF_2025["demand_nrr"],
            "format": "percent",
            "icon": "🔄",
            "icon_class": "success"
        },
        {
            "label": "Supply NRR",
            "key": "Supply NRR",
            "value": COMPANY_METRICS.get("supply_nrr", 0),
            "target": COMPANY_METRICS.get("supply_nrr_target", 1.10),
            "ref_2025": REF_2025["supply_nrr"],
            "format": "percent",
            "icon": "📦",
            "icon_class": "orange"
        },
        {
            "label": "Weighted Pipeline Coverage Gap",
            "key": "Pipeline Coverage",
            "value": COMPANY_METRICS.get("pipeline_weighted_coverage_gap", 0),
            "target": 0,  # Target is 0 (no gap)
            "ref_2025": None,
            "format": "pipeline_gap",
            "icon": "📊",
            "icon_class": "success",
            "show_pipeline_details": True,
            "coverage_ratio": COMPANY_METRICS.get("pipeline_coverage", 0),
            "higher_is_better": False,  # Lower gap = better (negative = surplus)
        },
    ]

    # Row 2: Operational & retention metrics (4 cards)
    metrics_row2 = [
        {
            "label": "Days to Fulfill",
            "key": "Time to Fulfill",
            "value": COMPANY_METRICS.get("time_to_fulfill_median"),  # None if no 2026 data yet
            "target": COMPANY_METRICS.get("time_to_fulfill_target", 60),
            "ref_2025": REF_2025["time_to_fulfill"],
            "format": "days",
            "icon": "⏱️",
            "icon_class": "cyan",
            "higher_is_better": False,  # Lower days = better
            "no_data_message": "No contracts fully spent",
        },
        {
            "label": "Logo Retention",
            "key": "Logo Retention",
            "value": COMPANY_METRICS["logo_retention"],
            "target": COMPANY_METRICS["logo_retention_target"],
            "ref_2025": REF_2025["logo_retention"],
            "format": "percent",
            "icon": "🏢",
            "icon_class": "warning"
        },
        {
            "label": "Sellable Inventory",
            "key": "Sellable Inventory",
            "value": None,  # Not implemented yet
            "target": None,
            "ref_2025": None,
            "format": "number",
            "icon": "📋",
            "icon_class": "neutral",
            "status_override": ("neutral", "Needs PRD"),
        },
        {
            "label": "Customer Count",
            "key": "Customer Count",
            "value": COMPANY_METRICS.get("customer_count", 51),
            "target": COMPANY_METRICS.get("customer_count_target", 75),
            "ref_2025": 51,  # 2025 had 51 active customers
            "format": "number",
            "icon": "👥",
            "icon_class": "success"
        },
    ]

    # Helper function to render a metric card
    def render_metric_card(m, col):
        val = m["value"]
        tgt = m["target"]
        ref = m.get("ref_2025")
        fmt = m["format"]
        higher_is_better = m.get("higher_is_better", True)

        # Format current value based on format type
        if val is None:
            val_str = m.get("no_data_message", "—")
        elif fmt == "percent":
            val_str = f"{val*100:.0f}%"
        elif fmt == "multiplier":
            val_str = f"{val:.1f}x"
        elif fmt == "days":
            val_str = f"{int(val)} days"
        elif fmt == "number":
            val_str = f"{int(val):,}"
        elif fmt == "pipeline_gap":
            # Show gap amount with coverage ratio: "$4.2M (3.8x)"
            coverage = m.get("coverage_ratio", 0)
            val_str = f"${abs(val)/1_000_000:.1f}M ({coverage:.1f}x)"
        else:
            val_str = str(val)

        # Format 2025 reference value
        if ref is None:
            ref_str = "—"
        elif fmt == "percent":
            ref_str = f"{ref*100:.0f}%"
        elif fmt == "multiplier":
            ref_str = f"{ref:.1f}x"
        elif fmt == "days":
            ref_str = f"{int(ref)} days"
        elif fmt == "number":
            ref_str = f"{int(ref):,}"
        else:
            ref_str = str(ref)

        # Get status - check for override first
        if "status_override" in m:
            status_class, status_label = m["status_override"]
        elif val is None or tgt is None:
            status_class, status_label = "neutral", "No Data"
        else:
            status_class, status_label = get_status_info(val, tgt, higher_is_better)

        tooltip = get_metric_tooltip(m["key"])
        target_info = get_metric_target(m["key"])

        # Build enriched tooltip HTML — target from Settings, benchmark from METRIC_DEFINITIONS
        edge_html = ""
        if tooltip.get("edge_cases"):
            edge_html = f'<div class="tooltip-label">\u26a0 Edge Cases</div><div class="tooltip-edge">{tooltip["edge_cases"]}</div>'

        context_pills = ""
        pills = []
        if target_info:
            pills.append(f'<span class="tooltip-pill target">\U0001f3af Target: {target_info["display"]}</span>')
        if tooltip.get("benchmark_2025"):
            pills.append(f'<span class="tooltip-pill benchmark">\U0001f4ca 2025: {tooltip["benchmark_2025"]}</span>')
        if pills:
            context_pills = f'<div class="tooltip-context">{"".join(pills)}</div>'

        tooltip_html = f'''<div class="tooltip"><div class="tooltip-label">Definition</div><div class="tooltip-text">{tooltip["definition"]}</div><div class="tooltip-label">Why It Matters</div><div class="tooltip-text">{tooltip["importance"]}</div><div class="tooltip-label">Calculation</div><div class="tooltip-calc">{tooltip["calculation"]}</div>{context_pills}{edge_html}</div>'''

        # Get verification status
        verification = get_metric_verification(m["key"])
        bq_ok = verification.get("bq", False)
        fn_ok = verification.get("fn", False)
        confirmed = verification.get("confirmed", False)

        # Build verification badge
        needs_review = verification.get("needs_review", False)
        if needs_review:
            badge_class = "review"
            badge_text = verification.get("note", "Needs Review")
        elif bq_ok and fn_ok:
            badge_class = "live"
            badge_text = "Live"
        else:
            badge_class = "pending"
            badge_text = verification.get("note", "Pending")

        with col:
            # Build sub-label: 2026 Target + 2025 Benchmark
            lines = []
            if target_info:
                lines.append(f'\U0001f3af 2026 Target: <span style="color: #5fd4e8;">{target_info["display"]}</span>')
            if ref:
                lines.append(f'\U0001f4ca 2025: <span style="color: #94a3b8;">{ref_str}</span>')
            if lines:
                inner = "".join(f"<div>{line}</div>" for line in lines)
                sub_label = f'<div style="font-size: 11px; color: #64748b; margin-top: 4px; line-height: 1.6;">{inner}</div>'
            else:
                sub_label = ""

            # Special handling for Pipeline Coverage - show weighted pipeline and needed amount
            if m.get("show_pipeline_details"):
                goal = COMPANY_METRICS.get("pipeline_quarterly_goal", 0)
                closed = COMPANY_METRICS.get("pipeline_closed_won", 0)
                weighted = COMPANY_METRICS.get("pipeline_weighted", 0)
                target = COMPANY_METRICS.get("pipeline_target", 6.0)
                needed = target * (goal - closed)
                sub_label = f'''<div style="font-size: 11px; color: #64748b; margin-top: 8px; line-height: 1.6;">
                    <div>Weighted Pipeline: <b>${weighted/1_000_000:.2f}M</b></div>
                    <div>Needed for {target:.0f}x: <b>${needed/1_000_000:.2f}M</b></div>
                </div>'''

            st.markdown(f'''
            <div class="metric-card">
                <div class="metric-live-badge {badge_class}">{badge_text}</div>
                <div class="metric-card-header">
                    <div class="metric-card-label">{m["label"]}<span class="info-trigger">i{tooltip_html}</span></div>
                    <div class="metric-card-icon {m["icon_class"]}">{m["icon"]}</div>
                </div>
                <div class="metric-card-kicker">Current YTD</div>
                <div class="metric-card-value">{val_str}</div>
                <span class="status-badge {status_class}">{status_label}</span>
                {sub_label}
            </div>
            ''', unsafe_allow_html=True)

    # Render Row 1
    cols = st.columns(4)
    for i, m in enumerate(metrics_row1):
        render_metric_card(m, cols[i])

    # Add spacing between rows
    st.markdown('<div style="height: 1rem;"></div>', unsafe_allow_html=True)

    # Render Row 2
    cols2 = st.columns(4)
    for i, m in enumerate(metrics_row2):
        render_metric_card(m, cols2[i])


def render_metric_card_generic(metric: dict, col):
    """Render a generic metric card using the standard styling."""
    label = metric.get("label", "Metric")
    value = metric.get("value")
    target = metric.get("target")
    fmt = metric.get("format", "number")
    icon = metric.get("icon", "📊")
    icon_class = metric.get("icon_class", "cyan")
    higher_is_better = metric.get("higher_is_better", True)

    value_str = format_value(value, fmt)
    if value is None and metric.get("placeholder"):
        value_str = metric.get("placeholder")

    if metric.get("status_override"):
        status_class, status_label = metric.get("status_override")
    else:
        status_class, status_label = get_status_info(value, target, higher_is_better)

    tooltip_key = metric.get("tooltip_key", label)
    tooltip = get_metric_tooltip(tooltip_key)
    target_info = get_metric_target(tooltip_key)

    edge_html = ""
    if tooltip.get("edge_cases"):
        edge_html = f'<div class="tooltip-label">⚠ Edge Cases</div><div class="tooltip-edge">{tooltip["edge_cases"]}</div>'

    pills = []
    if target_info:
        pills.append(f'<span class="tooltip-pill target">🎯 Target: {target_info["display"]}</span>')
    if tooltip.get("benchmark_2025"):
        pills.append(f'<span class="tooltip-pill benchmark">📊 2025: {tooltip["benchmark_2025"]}</span>')
    context_pills = f'<div class="tooltip-context">{"".join(pills)}</div>' if pills else ""

    tooltip_html = (
        f'<div class="tooltip">'
        f'<div class="tooltip-label">Definition</div>'
        f'<div class="tooltip-text">{tooltip["definition"]}</div>'
        f'<div class="tooltip-label">Why It Matters</div>'
        f'<div class="tooltip-text">{tooltip["importance"]}</div>'
        f'<div class="tooltip-label">Calculation</div>'
        f'<div class="tooltip-calc">{tooltip["calculation"]}</div>'
        f'{context_pills}{edge_html}'
        f'</div>'
    )

    sub_label = metric.get("sub_label", "")
    if not sub_label and (target_info or tooltip.get("benchmark_2025")):
        lines = []
        if target_info:
            lines.append(f'🎯 2026 Target: <span style="color: #5fd4e8;">{target_info["display"]}</span>')
        if tooltip.get("benchmark_2025"):
            lines.append(f'📊 2025: <span style="color: #94a3b8;">{tooltip["benchmark_2025"]}</span>')
        if lines:
            inner = "".join(f"<div>{line}</div>" for line in lines)
            sub_label = f'<div style="font-size: 11px; color: #64748b; margin-top: 4px; line-height: 1.6;">{inner}</div>'

    with col:
        st.markdown(f'''
        <div class="metric-card">
            <div class="metric-card-header">
                <div class="metric-card-label">{label}<span class="info-trigger">i{tooltip_html}</span></div>
                <div class="metric-card-icon {icon_class}">{icon}</div>
            </div>
            <div class="metric-card-kicker">Current YTD</div>
            <div class="metric-card-value">{value_str}</div>
            <span class="status-badge {status_class}">{status_label}</span>
            {sub_label}
        </div>
        ''', unsafe_allow_html=True)


def render_metric_grid(metrics: list, columns: int = 4):
    """Render a grid of metric cards."""
    cols = st.columns(columns)
    for idx, metric in enumerate(metrics):
        render_metric_card_generic(metric, cols[idx % columns])


def render_team_scorecard():
    """Render the team scorecard table."""
    st.markdown('<div class="section-header">Team Accountability</div>', unsafe_allow_html=True)

    # Table header
    st.markdown('''
    <div class="team-table">
        <div class="team-table-header">
            <div>Team Member</div>
            <div>Metric</div>
            <div>Actual</div>
            <div>Target</div>
            <div>Status</div>
        </div>
    ''', unsafe_allow_html=True)

    # Build rows
    rows_html = ""
    for person in PERSON_METRICS:
        actual = person["actual"]
        target = person["target"]
        fmt = person["format"]
        higher_is_better = person.get("higher_is_better", True)

        actual_str = format_value(actual, fmt)
        target_str = format_value(target, fmt) if target > 0 else "—"

        status_class, status_label = get_status_info(actual, target, higher_is_better)

        rows_html += f'''
        <div class="team-row">
            <div>
                <div class="team-name">{person["name"]}</div>
                <div class="team-dept">{person["department"]}</div>
            </div>
            <div class="team-metric">{person["metric_name"]}</div>
            <div class="team-value">{actual_str}</div>
            <div class="team-target">{target_str}</div>
            <div><span class="status-badge {status_class}">{status_label}</span></div>
        </div>
        '''

    st.markdown(rows_html + '</div>', unsafe_allow_html=True)


def render_department_detail(dept_name):
    """Render department detail view."""
    if dept_name not in DEPARTMENT_DETAILS:
        st.info(f"📋 Detailed metrics for {dept_name} coming soon. Requires API integration (Phase 2).")
        return

    details = DEPARTMENT_DETAILS[dept_name]

    # Summary
    st.markdown(f'<div class="dept-summary">{details["summary"]}</div>', unsafe_allow_html=True)

    if "note" in details:
        st.info(f"📋 {details['note']}")

    # Metrics grid
    st.markdown('<div class="section-header">Key Metrics</div>', unsafe_allow_html=True)

    metrics = details.get("metrics", [])
    cols = st.columns(min(len(metrics), 4))

    icon_map = {"currency": "💵", "percent": "📊", "number": "🔢", "multiplier": "📈", "hours": "⏱️", "days": "📅"}

    for i, m in enumerate(metrics):
        value = m["value"]
        target = m.get("target", 0)
        fmt = m["format"]
        higher_is_better = m.get("higher_is_better", True)

        value_str = format_value(value, fmt)
        status_class, status_label = get_status_info(value, target, higher_is_better)
        tooltip = get_metric_tooltip(m["name"])
        target_info = get_metric_target(m["name"])
        icon = icon_map.get(fmt, "📊")

        # Build enriched tooltip
        edge_html = ""
        if tooltip.get("edge_cases"):
            edge_html = f'<div class="tooltip-label">\u26a0 Edge Cases</div><div class="tooltip-edge">{tooltip["edge_cases"]}</div>'

        dept_pills = []
        if target_info:
            dept_pills.append(f'<span class="tooltip-pill target">\U0001f3af Target: {target_info["display"]}</span>')
        if tooltip.get("benchmark_2025"):
            dept_pills.append(f'<span class="tooltip-pill benchmark">\U0001f4ca 2025: {tooltip["benchmark_2025"]}</span>')
        dept_context = f'<div class="tooltip-context">{"".join(dept_pills)}</div>' if dept_pills else ""

        dept_tooltip_html = f'''<div class="tooltip"><div class="tooltip-label">Definition</div><div class="tooltip-text">{tooltip["definition"]}</div><div class="tooltip-label">Why It Matters</div><div class="tooltip-text">{tooltip["importance"]}</div><div class="tooltip-label">Calculation</div><div class="tooltip-calc">{tooltip["calculation"]}</div>{dept_context}{edge_html}</div>'''

        # Build sub-label with target + benchmark
        dept_lines = []
        if target_info:
            dept_lines.append(f'\U0001f3af 2026 Target: <span style="color: #5fd4e8;">{target_info["display"]}</span>')
        if tooltip.get("benchmark_2025"):
            dept_lines.append(f'\U0001f4ca 2025: <span style="color: #94a3b8;">{tooltip["benchmark_2025"]}</span>')
        if dept_lines:
            dept_inner = "".join(f"<div>{line}</div>" for line in dept_lines)
            dept_sub = f'<div style="font-size: 11px; color: #64748b; margin-top: 4px; line-height: 1.6;">{dept_inner}</div>'
        else:
            dept_sub = ""

        with cols[i % 4]:
            st.markdown(f'''
            <div class="metric-card">
                <div class="metric-card-header">
                    <div class="metric-card-label">{m["name"]}<span class="info-trigger">i{dept_tooltip_html}</span></div>
                    <div class="metric-card-icon cyan">{icon}</div>
                </div>
                <div class="metric-card-value">{value_str}</div>
                <span class="status-badge {status_class}">{status_label}</span>
                {dept_sub}
            </div>
            ''', unsafe_allow_html=True)

    # Chart if available
    if "chart_data" in details:
        st.markdown('<div class="section-header">Trend</div>', unsafe_allow_html=True)

        chart_data = details["chart_data"]

        fig = go.Figure()

        fig.add_trace(go.Scatter(
            x=chart_data["months"],
            y=chart_data["revenue"],
            name="Actual",
            line=dict(color="#13bad5", width=3),
            mode="lines+markers",
            marker=dict(size=8, color="#13bad5"),
            fill='tozeroy',
            fillcolor='rgba(19, 186, 213, 0.1)',
        ))

        fig.add_trace(go.Scatter(
            x=chart_data["months"],
            y=chart_data["target_line"],
            name="Target",
            line=dict(color="#94a3b8", width=2, dash="dot"),
            mode="lines",
        ))

        fig.update_layout(
            title=dict(
                text=chart_data.get("title", "Performance Trend"),
                font=dict(size=14, color="#1a1a2e", family="Inter, sans-serif"),
                x=0
            ),
            template="plotly_white",
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#64748b", family="Inter, sans-serif", size=12),
            legend=dict(
                orientation="h",
                yanchor="bottom",
                y=1.02,
                xanchor="right",
                x=1,
            ),
            margin=dict(l=0, r=0, t=40, b=0),
            yaxis=dict(
                tickformat="$,.0f",
                gridcolor="#e2e8f0",
                zerolinecolor="#e2e8f0",
            ),
            xaxis=dict(
                gridcolor="#e2e8f0",
            ),
            height=300,
        )

        st.plotly_chart(fig, use_container_width=True, config={'displayModeBar': False})


def render_ceo_dashboard():
    """Render the CEO / Biz Dev dashboard."""
    render_north_star()

    coo_metrics = get_coo_metrics()
    metrics = [
        {
            "label": "Pipeline Coverage",
            "tooltip_key": "Pipeline Coverage",
            "value": COMPANY_METRICS.get("pipeline_coverage"),
            "target": COMPANY_METRICS.get("pipeline_target"),
            "format": "multiplier",
            "icon": "📊",
            "icon_class": "cyan",
        },
        {
            "label": "Working Capital",
            "tooltip_key": "Working Capital",
            "value": coo_metrics.get("working_capital"),
            "target": (get_metric_target("Working Capital") or {}).get("value"),
            "format": "currency",
            "icon": "💵",
            "icon_class": "success",
        },
        {
            "label": "Months of Runway",
            "tooltip_key": "Months of Runway",
            "value": coo_metrics.get("months_of_runway"),
            "target": (get_metric_target("Months of Runway") or {}).get("value"),
            "format": "number",
            "icon": "⏳",
            "icon_class": "warning",
        },
        {
            "label": "Customer Concentration",
            "tooltip_key": "Customer Concentration",
            "value": COMPANY_METRICS.get("concentration_top1"),
            "target": (get_metric_target("Customer Concentration") or {}).get("value"),
            "format": "percent",
            "icon": "🎯",
            "icon_class": "orange",
            "higher_is_better": False,
            "sub_label": f'<div style="font-size: 11px; color: #64748b; margin-top: 4px; line-height: 1.6;">Top customer: <b>{COMPANY_METRICS.get("concentration_top1_name", "—")}</b></div>',
        },
    ]

    st.markdown('<div class="section-header">Key Metrics</div>', unsafe_allow_html=True)
    render_metric_grid(metrics, columns=4)

    render_overview_revenue_trend()


def render_coo_dashboard():
    """Render the COO / Ops dashboard."""
    take_rate = COMPANY_METRICS.get("take_rate_actual")
    take_rate_target = COMPANY_METRICS.get("take_rate_target")
    progress = (take_rate / take_rate_target * 100) if take_rate_target else 0

    st.markdown(f'''
    <div class="north-star-card" style="background: linear-gradient(135deg, #13bad5 0%, #0ea5c4 100%);">
        <div class="north-star-label">⚙️ Take Rate %</div>
        <div class="north-star-value">{format_value(take_rate, "percent")}</div>
        <div class="north-star-context">Target: {format_value(take_rate_target, "percent") if take_rate_target else "—"}</div>
        <div class="north-star-progress">
            <div class="north-star-progress-fill" style="width: {min(progress, 100):.0f}%"></div>
        </div>
        <div class="north-star-progress-meta">
            <span>{progress:.1f}% to goal</span>
            <span>FY {FISCAL_YEAR}</span>
        </div>
    </div>
    ''', unsafe_allow_html=True)

    coo_metrics = get_coo_metrics()

    st.markdown('<div class="section-header">Financial Health</div>', unsafe_allow_html=True)
    finance_metrics = [
        {
            "label": "Invoice Collection %",
            "tooltip_key": "Invoice Collection %",
            "value": coo_metrics.get("invoice_collection_rate"),
            "target": (get_metric_target("Invoice Collection %") or {}).get("value"),
            "format": "percent",
            "icon": "💳",
            "icon_class": "success",
        },
        {
            "label": "Overdue Invoices",
            "tooltip_key": "Overdue Invoices",
            "value": coo_metrics.get("overdue_count"),
            "target": (get_metric_target("Overdue Invoices") or {}).get("value"),
            "format": "number",
            "icon": "⏰",
            "icon_class": "warning",
            "higher_is_better": False,
            "sub_label": f'<div style="font-size: 11px; color: #64748b; margin-top: 4px; line-height: 1.6;">${coo_metrics.get("overdue_amount", 0):,.0f} overdue</div>',
        },
        {
            "label": "Working Capital",
            "tooltip_key": "Working Capital",
            "value": coo_metrics.get("working_capital"),
            "target": (get_metric_target("Working Capital") or {}).get("value"),
            "format": "currency",
            "icon": "💼",
            "icon_class": "cyan",
        },
        {
            "label": "Months of Runway",
            "tooltip_key": "Months of Runway",
            "value": coo_metrics.get("months_of_runway"),
            "target": (get_metric_target("Months of Runway") or {}).get("value"),
            "format": "number",
            "icon": "🧭",
            "icon_class": "orange",
        },
    ]
    render_metric_grid(finance_metrics, columns=4)

    st.markdown('<div class="section-header">Operational Metrics</div>', unsafe_allow_html=True)
    ops_metrics = [
        {
            "label": "Customer Concentration",
            "tooltip_key": "Customer Concentration",
            "value": COMPANY_METRICS.get("concentration_top1"),
            "target": (get_metric_target("Customer Concentration") or {}).get("value"),
            "format": "percent",
            "icon": "🎯",
            "icon_class": "warning",
            "higher_is_better": False,
            "sub_label": f'<div style="font-size: 11px; color: #64748b; margin-top: 4px; line-height: 1.6;">Top customer: <b>{COMPANY_METRICS.get("concentration_top1_name", "—")}</b></div>',
        },
        {
            "label": "Net Revenue Gap",
            "tooltip_key": "Net Revenue Gap",
            "value": None,
            "target": None,
            "format": "currency",
            "icon": "📉",
            "icon_class": "neutral",
            "status_override": ("neutral", "Pending"),
            "placeholder": "—",
        },
        {
            "label": "Factoring Capacity",
            "tooltip_key": "Factoring Capacity",
            "value": None,
            "target": None,
            "format": "currency",
            "icon": "🏦",
            "icon_class": "neutral",
            "status_override": ("neutral", "Pending"),
            "placeholder": "—",
        },
        {
            "label": "Cash Position",
            "tooltip_key": "Cash Position",
            "value": coo_metrics.get("cash_balance"),
            "target": None,
            "format": "currency",
            "icon": "💵",
            "icon_class": "neutral",
            "status_override": ("neutral", "Phase 4"),
        },
    ]
    render_metric_grid(ops_metrics, columns=4)

    st.markdown('<div class="section-header">Department Roll-up Health</div>', unsafe_allow_html=True)
    rollup_depts = {"Supply", "Supply AM", "Demand AM", "Accounting"}
    rows_html = ""
    for person in PERSON_METRICS:
        if person["department"] not in rollup_depts:
            continue
        actual = person["actual"]
        target = person["target"]
        fmt = person["format"]
        higher_is_better = person.get("higher_is_better", True)
        actual_str = format_value(actual, fmt)
        target_str = format_value(target, fmt) if target else "—"
        status_class, status_label = get_status_info(actual, target, higher_is_better)

        rows_html += f'''
        <div class="team-row">
            <div>
                <div class="team-name">{person["department"]}</div>
                <div class="team-dept">{person["name"]}</div>
            </div>
            <div class="team-metric">{person["metric_name"]}</div>
            <div class="team-value">{actual_str}</div>
            <div class="team-target">{target_str}</div>
            <div><span class="status-badge {status_class}">{status_label}</span></div>
        </div>
        '''

    st.markdown('''
    <div class="team-table">
        <div class="team-table-header">
            <div>Department</div>
            <div>Primary Metric</div>
            <div>Actual</div>
            <div>Target</div>
            <div>Status</div>
        </div>
    ''', unsafe_allow_html=True)
    st.markdown(rows_html + '</div>', unsafe_allow_html=True)


def render_demand_sales_dashboard():
    """Render the Demand Sales dashboard."""
    coverage = COMPANY_METRICS.get("pipeline_coverage")
    target = COMPANY_METRICS.get("pipeline_target", 6.0)
    progress = (coverage / target * 100) if target else 0

    st.markdown(f'''
    <div class="north-star-card" style="background: linear-gradient(135deg, #13bad5 0%, #0ea5c4 100%);">
        <div class="north-star-label">💼 Pipeline Coverage</div>
        <div class="north-star-value">{format_value(coverage, "multiplier")}</div>
        <div class="north-star-context">Target: {format_value(target, "multiplier") if target else "—"}</div>
        <div class="north-star-progress">
            <div class="north-star-progress-fill" style="width: {min(progress, 100):.0f}%"></div>
        </div>
        <div class="north-star-progress-meta">
            <span>{progress:.1f}% to goal</span>
            <span>FY {FISCAL_YEAR}</span>
        </div>
    </div>
    ''', unsafe_allow_html=True)

    st.markdown('<div class="section-header">Sales Metrics</div>', unsafe_allow_html=True)
    dept_metrics = get_demand_sales_metrics()
    metrics = []
    icon_map = {"currency": "💵", "percent": "📈", "multiplier": "📊", "number": "🔢", "days": "📅"}
    for m in dept_metrics:
        metrics.append({
            "label": m["label"],
            "tooltip_key": m["tooltip_key"],
            "value": m.get("value"),
            "target": m.get("target"),
            "format": m.get("format", "number"),
            "icon": icon_map.get(m.get("format"), "📊"),
            "icon_class": "cyan",
            "higher_is_better": m.get("higher_is_better", True),
            "status_override": m.get("status_override"),
            "placeholder": m.get("placeholder"),
        })
    render_metric_grid(metrics, columns=4)

    st.markdown('<div class="section-header">Pipeline by Rep</div>', unsafe_allow_html=True)
    st.markdown('''
    <div class="team-table">
        <div class="team-table-header">
            <div>Rep</div>
            <div>Metric</div>
            <div>Actual</div>
            <div>Target</div>
            <div>Status</div>
        </div>
    ''', unsafe_allow_html=True)

    rows_html = ""
    for person in PERSON_METRICS:
        if person["department"] != "Demand Sales":
            continue
        actual = person["actual"]
        target = person["target"]
        fmt = person["format"]
        higher_is_better = person.get("higher_is_better", True)
        actual_str = format_value(actual, fmt)
        target_str = format_value(target, fmt) if target else "—"
        status_class, status_label = get_status_info(actual, target, higher_is_better)

        rows_html += f'''
        <div class="team-row">
            <div>
                <div class="team-name">{person["name"]}</div>
                <div class="team-dept">Demand Sales</div>
            </div>
            <div class="team-metric">{person["metric_name"]}</div>
            <div class="team-value">{actual_str}</div>
            <div class="team-target">{target_str}</div>
            <div><span class="status-badge {status_class}">{status_label}</span></div>
        </div>
        '''

    st.markdown(rows_html + '</div>', unsafe_allow_html=True)


def render_accounting_dashboard():
    """Render the Accounting dashboard."""
    coo_metrics = get_coo_metrics()
    collection_rate = coo_metrics.get("invoice_collection_rate")
    target = (get_metric_target("Invoice Collection %") or {}).get("value")
    progress = (collection_rate / target * 100) if target else 0

    st.markdown(f'''
    <div class="north-star-card" style="background: linear-gradient(135deg, #13bad5 0%, #0ea5c4 100%);">
        <div class="north-star-label">💰 Invoice Collection Rate</div>
        <div class="north-star-value">{format_value(collection_rate, "percent")}</div>
        <div class="north-star-context">Target: {format_value(target, "percent") if target else "—"}</div>
        <div class="north-star-progress">
            <div class="north-star-progress-fill" style="width: {min(progress, 100):.0f}%"></div>
        </div>
        <div class="north-star-progress-meta">
            <span>{progress:.1f}% to goal</span>
            <span>FY {FISCAL_YEAR}</span>
        </div>
    </div>
    ''', unsafe_allow_html=True)

    st.markdown('<div class="section-header">AR Metrics</div>', unsafe_allow_html=True)
    acct_metrics = get_accounting_metrics()
    metrics = []
    icon_map = {"currency": "💵", "percent": "📈", "number": "🔢", "days": "📅"}
    for m in acct_metrics:
        metrics.append({
            "label": m["label"],
            "tooltip_key": m["tooltip_key"],
            "value": m.get("value"),
            "target": m.get("target"),
            "format": m.get("format", "number"),
            "icon": icon_map.get(m.get("format"), "📊"),
            "icon_class": "cyan",
            "higher_is_better": m.get("higher_is_better", True),
            "status_override": m.get("status_override"),
            "placeholder": m.get("placeholder"),
        })
    metrics.append({
        "label": "Factoring Capacity",
        "tooltip_key": "Factoring Capacity",
        "value": None,
        "target": None,
        "format": "currency",
        "icon": "🏦",
        "icon_class": "neutral",
        "status_override": ("neutral", "Pending"),
        "placeholder": "—",
    })
    render_metric_grid(metrics, columns=4)


def render_demand_am_dashboard():
    """Render the Demand AM dashboard."""
    dept_metrics = get_demand_am_metrics()
    contract_metric = next((m for m in dept_metrics if m.get("label") == "Contract Spend %"), None)
    contract_value = contract_metric.get("value") if contract_metric else None
    contract_target = contract_metric.get("target") if contract_metric else None
    progress = (contract_value / contract_target * 100) if contract_target else 0

    st.markdown(f'''
    <div class="north-star-card" style="background: linear-gradient(135deg, #13bad5 0%, #0ea5c4 100%);">
        <div class="north-star-label">🎯 Contract Spend %</div>
        <div class="north-star-value">{format_value(contract_value, "percent")}</div>
        <div class="north-star-context">Target: {format_value(contract_target, "percent") if contract_target else "—"}</div>
        <div class="north-star-progress">
            <div class="north-star-progress-fill" style="width: {min(progress, 100):.0f}%"></div>
        </div>
        <div class="north-star-progress-meta">
            <span>{progress:.1f}% to goal</span>
            <span>FY {FISCAL_YEAR}</span>
        </div>
    </div>
    ''', unsafe_allow_html=True)

    st.markdown('<div class="section-header">AM Metrics</div>', unsafe_allow_html=True)
    metrics = []
    icon_map = {"currency": "💵", "percent": "📈", "number": "🔢", "hours": "⏱️", "days": "📅"}
    for m in dept_metrics:
        metrics.append({
            "label": m["label"],
            "tooltip_key": m["tooltip_key"],
            "value": m.get("value"),
            "target": m.get("target"),
            "format": m.get("format", "number"),
            "icon": icon_map.get(m.get("format"), "📊"),
            "icon_class": "cyan",
            "higher_is_better": m.get("higher_is_better", True),
            "status_override": m.get("status_override"),
            "placeholder": m.get("placeholder"),
        })
    render_metric_grid(metrics, columns=4)

    st.markdown('<div class="section-header">AM Performance by Person</div>', unsafe_allow_html=True)
    st.markdown('''
    <div class="team-table">
        <div class="team-table-header">
            <div>AM</div>
            <div>Primary Metric</div>
            <div>Actual</div>
            <div>Target</div>
            <div>Status</div>
        </div>
    ''', unsafe_allow_html=True)

    rows_html = ""
    for person in PERSON_METRICS:
        if person["department"] != "Demand AM":
            continue
        actual = person["actual"]
        target = person["target"]
        fmt = person["format"]
        higher_is_better = person.get("higher_is_better", True)
        actual_str = format_value(actual, fmt)
        target_str = format_value(target, fmt) if target else "—"
        status_class, status_label = get_status_info(actual, target, higher_is_better)

        rows_html += f'''
        <div class="team-row">
            <div>
                <div class="team-name">{person["name"]}</div>
                <div class="team-dept">Demand AM</div>
            </div>
            <div class="team-metric">{person["metric_name"]}</div>
            <div class="team-value">{actual_str}</div>
            <div class="team-target">{target_str}</div>
            <div><span class="status-badge {status_class}">{status_label}</span></div>
        </div>
        '''

    st.markdown(rows_html + '</div>', unsafe_allow_html=True)

    st.info("📊 Contract spend distribution + fulfillment charts will be added after Phase 1 data wiring.")


def render_marketing_dashboard():
    """Render the Marketing dashboard."""
    dept_metrics = get_marketing_metrics()
    pipeline_metric = next((m for m in dept_metrics if "Marketing-Influenced" in m.get("label", "")), None)
    pipeline_value = pipeline_metric.get("value") if pipeline_metric else None

    st.markdown(f'''
    <div class="north-star-card" style="background: linear-gradient(135deg, #13bad5 0%, #0ea5c4 100%);">
        <div class="north-star-label">📣 Marketing-Influenced Pipeline</div>
        <div class="north-star-value">{format_value(pipeline_value, "currency")}</div>
        <div class="north-star-context">Attribution: (First Touch + Last Touch) / 2</div>
        <div class="north-star-progress">
            <div class="north-star-progress-fill" style="width: 65%"></div>
        </div>
        <div class="north-star-progress-meta">
            <span>QTD pipeline</span>
            <span>FY {FISCAL_YEAR}</span>
        </div>
    </div>
    ''', unsafe_allow_html=True)

    st.markdown('<div class="section-header">Conversion Metrics</div>', unsafe_allow_html=True)
    metrics = []
    icon_map = {"currency": "💵", "percent": "📈", "number": "🔢"}
    for m in dept_metrics:
        metrics.append({
            "label": m["label"],
            "tooltip_key": m["tooltip_key"],
            "value": m.get("value"),
            "target": m.get("target"),
            "format": m.get("format", "number"),
            "icon": icon_map.get(m.get("format"), "📊"),
            "icon_class": "cyan",
            "higher_is_better": m.get("higher_is_better", True),
            "status_override": m.get("status_override"),
            "placeholder": m.get("placeholder"),
        })
    render_metric_grid(metrics, columns=4)

    st.markdown('<div class="section-header">Marketing Leads Funnel</div>', unsafe_allow_html=True)
    funnel_rows = get_marketing_funnel()
    if funnel_rows:
        stages = [row["funnel_stage"] for row in funnel_rows]
        counts = [row["contact_count"] for row in funnel_rows]
        conv = [row.get("stage_conversion_rate") for row in funnel_rows]

        funnel_fig = go.Figure()
        funnel_fig.add_trace(go.Bar(
            x=stages,
            y=counts,
            text=[f"{c:,}" for c in counts],
            textposition="auto",
            marker_color="#13bad5",
            name="Leads",
        ))
        funnel_fig.update_layout(
            title=dict(text="Marketing Funnel (YTD)", x=0, font=dict(size=14, color="#1a1a2e")),
            template="plotly_white",
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#64748b", family="Inter, sans-serif", size=12),
            margin=dict(l=0, r=0, t=40, b=0),
            yaxis=dict(title="Contacts", gridcolor="#e2e8f0"),
            height=320,
            showlegend=False,
        )
        st.plotly_chart(funnel_fig, use_container_width=True, config={'displayModeBar': False})

        # Conversion callouts
        conversions = []
        for stage, rate in zip(stages, conv):
            if rate is not None and stage in ("ML", "MQL"):
                conversions.append(f"{stage} → next: {rate:.0f}%")
        if conversions:
            st.markdown(
                '<div class="dept-summary">' + " · ".join(conversions) + "</div>",
                unsafe_allow_html=True,
            )
    else:
        st.info("📊 Funnel data not available (Missing Query).")

    st.markdown('<div class="section-header">Attribution by Channel</div>', unsafe_allow_html=True)
    attribution_rows = get_marketing_attribution()
    if attribution_rows:
        channels = [row["channel"] for row in attribution_rows][:10]
        totals = [row["total_attributed_revenue"] for row in attribution_rows][:10]

        attr_fig = go.Figure()
        attr_fig.add_trace(go.Bar(
            x=channels,
            y=totals,
            marker_color="#ff8900",
            hovertemplate="<b>%{x}</b><br>$%{y:,.0f}<extra></extra>",
        ))
        attr_fig.update_layout(
            title=dict(text="Top Channels by Attributed Revenue", x=0, font=dict(size=14, color="#1a1a2e")),
            template="plotly_white",
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#64748b", family="Inter, sans-serif", size=12),
            margin=dict(l=0, r=0, t=40, b=0),
            yaxis=dict(title="Attributed Revenue", gridcolor="#e2e8f0", tickformat="$,.0f"),
            height=320,
            showlegend=False,
        )
        st.plotly_chart(attr_fig, use_container_width=True, config={'displayModeBar': False})
    else:
        st.info("📊 Attribution data not available (Missing Query).")



def render_engineering_dashboard():
    """Render the Engineering dashboard placeholder (Phase 5)."""
    st.info("⚠️ Requires GitHub and Asana API integration (Phase 5). Metrics will populate once APIs are connected.")

    st.markdown('<div class="section-header">Engineering Metrics</div>', unsafe_allow_html=True)
    metrics = [
        {"label": "Features Fully Scoped", "tooltip_key": "Features Fully Scoped", "value": None, "target": 5, "format": "number", "icon": "🧩", "icon_class": "neutral", "status_override": ("neutral", "Phase 5"), "placeholder": "—"},
        {"label": "BizSup Completed", "tooltip_key": "BizSup Completed", "value": None, "target": 10, "format": "number", "icon": "✅", "icon_class": "neutral", "status_override": ("neutral", "Phase 5"), "placeholder": "—"},
        {"label": "PRDs Generated", "tooltip_key": "PRDs Generated", "value": None, "target": 3, "format": "number", "icon": "📝", "icon_class": "neutral", "status_override": ("neutral", "Phase 5"), "placeholder": "—"},
        {"label": "FSDs Generated", "tooltip_key": "FSDs Generated", "value": None, "target": 2, "format": "number", "icon": "📄", "icon_class": "neutral", "status_override": ("neutral", "Phase 5"), "placeholder": "—"},
    ]
    render_metric_grid(metrics, columns=4)



def render_supply_dashboard():
    """Render the Supply department dashboard with capacity data."""
    # Q1 Goals Summary Card
    q1_value_target = SUPPLY_Q1_GOALS["new_unique_inventory_value"]
    q1_value_actual = SUPPLY_Q1_GOALS["new_unique_inventory_value_actual"]
    q1_progress = (q1_value_actual / q1_value_target) * 100 if q1_value_target > 0 else 0

    st.markdown(f'''
    <div class="north-star-card" style="background: linear-gradient(135deg, #ff8900 0%, #e67e00 100%);">
        <div class="north-star-label">🎯 Q1 New Unique Inventory Goal</div>
        <div class="north-star-value">${q1_value_actual/1000:,.0f}K</div>
        <div class="north-star-context">
            of ${q1_value_target/1000:,.0f}K target · ${(q1_value_target - q1_value_actual)/1000:,.0f}K remaining
        </div>
        <div class="north-star-progress">
            <div class="north-star-progress-fill" style="width: {min(q1_progress, 100):.0f}%"></div>
        </div>
        <div class="north-star-progress-meta">
            <span>{q1_progress:.1f}% to goal</span>
            <span>Q1 FY2026</span>
        </div>
    </div>
    ''', unsafe_allow_html=True)

    # Key Metrics Row
    st.markdown('<div class="section-header">Supply Metrics</div>', unsafe_allow_html=True)

    cols = st.columns(4)

    # Total Capacity
    total_capacity = sum(d["capacity"] for d in SUPPLY_CAPACITY_BY_TYPE.values())
    with cols[0]:
        st.markdown(f'''
        <div class="metric-card">
            <div class="metric-card-header">
                <div class="metric-card-label">Total Yearly Capacity</div>
                <div class="metric-card-icon cyan">📦</div>
            </div>
            <div class="metric-card-value">{total_capacity/MILLION:.1f}M</div>
            <span class="status-badge success">samples</span>
        </div>
        ''', unsafe_allow_html=True)

    # Active Event Types
    with cols[1]:
        st.markdown(f'''
        <div class="metric-card">
            <div class="metric-card-header">
                <div class="metric-card-label">Active Event Types</div>
                <div class="metric-card-icon success">🏷️</div>
            </div>
            <div class="metric-card-value">{len(SUPPLY_CAPACITY_BY_TYPE)}</div>
            <span class="status-badge success">categories</span>
        </div>
        ''', unsafe_allow_html=True)

    # Weekly Contact Target
    contact_target = SUPPLY_Q1_GOALS["attempted_to_contact_weekly_target"]
    contact_actual = SUPPLY_Q1_GOALS["attempted_to_contact_weekly_actual"]
    contact_status, contact_label = get_status_info(contact_actual, contact_target)
    with cols[2]:
        st.markdown(f'''
        <div class="metric-card">
            <div class="metric-card-header">
                <div class="metric-card-label">Contacts / Week</div>
                <div class="metric-card-icon orange">📞</div>
            </div>
            <div class="metric-card-value">{contact_actual:,}</div>
            <span class="status-badge {contact_status}">{contact_label} ({contact_target} goal)</span>
        </div>
        ''', unsafe_allow_html=True)

    # MoM Growth
    trend = SUPPLY_CAPACITY_TREND["total"]
    if len(trend) >= 2:
        mom_growth = ((trend[-1] - trend[-2]) / trend[-2]) * 100
        growth_status = "success" if mom_growth >= 0 else "danger"
        with cols[3]:
            st.markdown(f'''
            <div class="metric-card">
                <div class="metric-card-header">
                    <div class="metric-card-label">MoM Capacity Growth</div>
                    <div class="metric-card-icon {growth_status}">📈</div>
                </div>
                <div class="metric-card-value">{mom_growth:+.1f}%</div>
                <span class="status-badge {growth_status}">vs. prior month</span>
            </div>
            ''', unsafe_allow_html=True)

    # Capacity by Event Type Table
    st.markdown('<div class="section-header">Capacity by Event Type (January 2026)</div>', unsafe_allow_html=True)

    # Sort by capacity descending
    sorted_types = sorted(
        SUPPLY_CAPACITY_BY_TYPE.items(),
        key=lambda x: x[1]["capacity"],
        reverse=True
    )

    # Custom table with progress bars
    st.markdown('''
    <style>
    .capacity-table {
        background: var(--bg-white);
        border: 1px solid var(--border-light);
        border-radius: var(--radius-md);
        overflow: hidden;
        box-shadow: var(--shadow-sm);
    }
    .capacity-header {
        background: var(--bg-main);
        padding: 0.75rem 1.25rem;
        display: grid;
        grid-template-columns: 2fr 1fr 1.5fr 0.75fr;
        gap: 1rem;
        font-size: 0.75rem;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        color: var(--text-muted);
        border-bottom: 1px solid var(--border-light);
    }
    .capacity-row {
        display: grid;
        grid-template-columns: 2fr 1fr 1.5fr 0.75fr;
        gap: 1rem;
        padding: 1rem 1.25rem;
        border-bottom: 1px solid var(--border-light);
        align-items: center;
        transition: background 0.15s ease;
    }
    .capacity-row:last-child { border-bottom: none; }
    .capacity-row:hover { background: var(--bg-main); }
    .capacity-type {
        display: flex;
        align-items: center;
        gap: 0.75rem;
    }
    .capacity-type-icon {
        font-size: 1.25rem;
        width: 2rem;
        text-align: center;
    }
    .capacity-type-label {
        font-weight: 600;
        color: var(--text-primary);
    }
    .capacity-value {
        font-family: 'JetBrains Mono', monospace;
        font-weight: 600;
        color: var(--text-primary);
    }
    .capacity-bar-container {
        display: flex;
        align-items: center;
        gap: 0.75rem;
    }
    .capacity-bar {
        flex: 1;
        height: 8px;
        background: var(--border-light);
        border-radius: 4px;
        overflow: hidden;
    }
    .capacity-bar-fill {
        height: 100%;
        border-radius: 4px;
        transition: width 0.3s ease;
    }
    .capacity-bar-fill.high { background: var(--recess-cyan); }
    .capacity-bar-fill.medium { background: var(--recess-orange); }
    .capacity-bar-fill.low { background: var(--text-muted); }
    .capacity-pct {
        font-size: 0.8125rem;
        font-weight: 500;
        color: var(--text-secondary);
        min-width: 3rem;
        text-align: right;
    }

    /* Responsive table for mobile */
    @media screen and (max-width: 767px) {
        .capacity-header { display: none; }
        .capacity-row {
            grid-template-columns: 1fr;
            gap: 0.5rem;
        }
        .capacity-type { margin-bottom: 0.25rem; }
        .capacity-bar-container { margin-top: 0.25rem; }
    }
    </style>
    ''', unsafe_allow_html=True)

    table_html = '''
    <div class="capacity-table">
        <div class="capacity-header">
            <div>Event Type</div>
            <div>Capacity</div>
            <div>% of Total</div>
            <div>Share</div>
        </div>
    '''

    for type_key, data in sorted_types:
        capacity = data["capacity"]
        pct = (capacity / total_capacity) * 100
        # Color based on share
        bar_class = "high" if pct >= 15 else ("medium" if pct >= 5 else "low")

        table_html += f'''
        <div class="capacity-row">
            <div class="capacity-type">
                <span class="capacity-type-icon">{data["icon"]}</span>
                <span class="capacity-type-label">{data["label"]}</span>
            </div>
            <div class="capacity-value">{capacity/MILLION:.2f}M</div>
            <div class="capacity-bar-container">
                <div class="capacity-bar">
                    <div class="capacity-bar-fill {bar_class}" style="width: {pct}%"></div>
                </div>
            </div>
            <div class="capacity-pct">{pct:.1f}%</div>
        </div>
        '''

    table_html += '</div>'
    st.markdown(table_html, unsafe_allow_html=True)

    # Monthly Capacity Trend Chart
    st.markdown('<div class="section-header">Capacity Growth Trend</div>', unsafe_allow_html=True)

    fig = go.Figure()

    # Add total capacity line
    fig.add_trace(go.Scatter(
        x=SUPPLY_CAPACITY_TREND["months"],
        y=[v/MILLION for v in SUPPLY_CAPACITY_TREND["total"]],
        name="Total Capacity",
        line=dict(color="#13bad5", width=3),
        mode="lines+markers",
        marker=dict(size=8, color="#13bad5"),
        fill='tozeroy',
        fillcolor='rgba(19, 186, 213, 0.1)',
    ))

    # Add top event types as separate traces
    colors = ["#ff8900", "#10b981", "#8b5cf6", "#f59e0b"]
    top_types = ["student_involvement", "youth_sports", "family_event", "sporting_event"]

    for i, type_key in enumerate(top_types):
        if type_key in SUPPLY_CAPACITY_TREND:
            fig.add_trace(go.Scatter(
                x=SUPPLY_CAPACITY_TREND["months"],
                y=[v/MILLION for v in SUPPLY_CAPACITY_TREND[type_key]],
                name=SUPPLY_CAPACITY_BY_TYPE[type_key]["label"],
                line=dict(color=colors[i], width=2),
                mode="lines",
            ))

    fig.update_layout(
        title=dict(
            text="Monthly Capacity by Event Type (Millions)",
            font=dict(size=14, color="#1a1a2e", family="Inter, sans-serif"),
            x=0
        ),
        template="plotly_white",
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        font=dict(color="#64748b", family="Inter, sans-serif", size=12),
        legend=dict(
            orientation="h",
            yanchor="bottom",
            y=1.02,
            xanchor="right",
            x=1,
        ),
        margin=dict(l=0, r=0, t=40, b=0),
        yaxis=dict(
            title="Capacity (Millions)",
            gridcolor="#e2e8f0",
            zerolinecolor="#e2e8f0",
        ),
        xaxis=dict(
            gridcolor="#e2e8f0",
        ),
        height=350,
    )

    st.plotly_chart(fig, use_container_width=True, config={'displayModeBar': False})

    # Weekly "Attempted to Contact" Chart (from HubSpot)
    st.markdown('<div class="section-header">Weekly Contact Attempts (52-Week View)</div>', unsafe_allow_html=True)
    st.markdown('''
    <div class="dept-summary">
        Supply Target Accounts marked "Attempted to Contact" in HubSpot (target: 600/week).
        Data filtered by <code>target_account___supply = "Yes"</code>.
    </div>
    ''', unsafe_allow_html=True)

    # Build bar chart data
    weeks_data = SUPPLY_CONTACT_ATTEMPTS["weeks"]
    week_labels = [w["week"] for w in weeks_data]
    counts = [w["count"] for w in weeks_data]
    targets = [w["target"] for w in weeks_data]
    current_week_idx = SUPPLY_CONTACT_ATTEMPTS["current_week_index"]
    weekly_target = SUPPLY_CONTACT_ATTEMPTS["weekly_target"]

    # Color bars based on target achievement
    bar_colors = []
    for i, (count, target) in enumerate(zip(counts, targets)):
        if i == current_week_idx:
            bar_colors.append("#94a3b8")  # Gray for current (partial) week
        elif count >= target:
            bar_colors.append("#10b981")  # Green for met target
        elif count >= target * 0.9:
            bar_colors.append("#f59e0b")  # Amber for close to target
        else:
            bar_colors.append("#ef4444")  # Red for below target

    contact_fig = go.Figure()

    # Add bar chart for actual counts (no text labels for cleaner 52-week view)
    contact_fig.add_trace(go.Bar(
        x=week_labels,
        y=counts,
        name="Contacts Attempted",
        marker_color=bar_colors,
        hovertemplate="<b>%{x}</b><br>Contacts: %{y:,}<extra></extra>",
    ))

    # Add target line
    contact_fig.add_trace(go.Scatter(
        x=week_labels,
        y=targets,
        name="Target (600/week)",
        mode="lines",
        line=dict(color="#ff8900", width=2, dash="dash"),
        hoverinfo="skip",
    ))

    contact_fig.update_layout(
        title=dict(
            text="Weekly Supply Contact Attempts vs Target (Feb 2025 - Jan 2026)",
            font=dict(size=14, color="#1a1a2e", family="Inter, sans-serif"),
            x=0
        ),
        template="plotly_white",
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        font=dict(color="#64748b", family="Inter, sans-serif", size=12),
        legend=dict(
            orientation="h",
            yanchor="bottom",
            y=1.02,
            xanchor="right",
            x=1,
        ),
        margin=dict(l=0, r=0, t=40, b=60),
        yaxis=dict(
            title="Contacts",
            gridcolor="#e2e8f0",
            zerolinecolor="#e2e8f0",
            range=[0, max(counts) * 1.15],
        ),
        xaxis=dict(
            gridcolor="#e2e8f0",
            tickangle=-45,
            tickmode="auto",
            nticks=26,  # Show every ~2 weeks
            rangeslider=dict(visible=True, thickness=0.05),
        ),
        height=400,
        bargap=0.15,
        showlegend=True,
    )

    st.plotly_chart(contact_fig, use_container_width=True, config={'displayModeBar': False})

    # Calculate YTD statistics (excluding current partial week)
    completed_weeks = [w for i, w in enumerate(weeks_data) if i != current_week_idx]
    ytd_total = sum(w["count"] for w in completed_weeks)
    weeks_count = len(completed_weeks)
    weekly_avg = ytd_total / weeks_count if weeks_count > 0 else 0
    weeks_on_target = sum(1 for w in completed_weeks if w["count"] >= w["target"])
    target_hit_rate = (weeks_on_target / weeks_count * 100) if weeks_count > 0 else 0
    pacing_pct = (weekly_avg / weekly_target) * 100 if weekly_target > 0 else 0
    pacing_status = "success" if pacing_pct >= 100 else ("warning" if pacing_pct >= 90 else "danger")
    target_status = "success" if target_hit_rate >= 70 else ("warning" if target_hit_rate >= 50 else "danger")

    st.markdown(f'''
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 1rem; margin-top: 1rem;">
        <div class="metric-card">
            <div class="metric-card-header">
                <div class="metric-card-label">YTD Total Attempts</div>
                <div class="metric-card-icon cyan">📊</div>
            </div>
            <div class="metric-card-value">{ytd_total:,}</div>
            <span class="status-badge success">{weeks_count} weeks</span>
        </div>
        <div class="metric-card">
            <div class="metric-card-header">
                <div class="metric-card-label">Weekly Average</div>
                <div class="metric-card-icon orange">📈</div>
            </div>
            <div class="metric-card-value">{weekly_avg:,.0f}</div>
            <span class="status-badge {pacing_status}">{pacing_pct:.0f}% of target</span>
        </div>
        <div class="metric-card">
            <div class="metric-card-header">
                <div class="metric-card-label">Weeks On Target</div>
                <div class="metric-card-icon success">🎯</div>
            </div>
            <div class="metric-card-value">{weeks_on_target}/{weeks_count}</div>
            <span class="status-badge {target_status}">{target_hit_rate:.0f}% hit rate</span>
        </div>
    </div>
    ''', unsafe_allow_html=True)


def render_supply_am_dashboard():
    """Render the Supply AM dashboard with Core Action State tiles showing $ at risk."""
    from data.bigquery_client import get_core_action_state_counts, get_supply_npr

    # Fetch NPR data
    npr_data = get_supply_npr()
    npr_current = npr_data.get("npr_pct", 0) / 100 if npr_data.get("npr_pct") else 0
    npr_status = "success" if npr_current >= 1.10 else ("warning" if npr_current >= 0.95 else "danger")

    # North Star: NPR
    st.markdown(f'''
    <div class="north-star-card" style="background: linear-gradient(135deg, #13bad5 0%, #0891b2 100%);">
        <div class="north-star-label">🎯 Net Payout Retention (NPR)</div>
        <div class="north-star-value">{npr_current:.0%}</div>
        <div class="north-star-context">
            2025 vs 2024 · Target: 110%
        </div>
    </div>
    ''', unsafe_allow_html=True)

    # Fetch Core Action State data
    state_data = get_core_action_state_counts('supplier')

    # Core Action State Tiles
    st.markdown('<div class="section-header">Supplier Health (Core Action State)</div>', unsafe_allow_html=True)

    cols = st.columns(4)

    # Helper to format LTV
    def format_ltv(amount):
        if amount >= 1_000_000:
            return f"${amount/1_000_000:.1f}M"
        elif amount >= 1_000:
            return f"${amount/1_000:.0f}K"
        else:
            return f"${amount:.0f}"

    # Active Suppliers
    active = state_data.get("active", {})
    active_count = active.get("count", 0)
    active_ltv = active.get("total_ltv", 0)
    active_2025 = active.get("total_2025", 0)
    with cols[0]:
        st.markdown(f'''
        <div class="metric-card">
            <div class="metric-card-header">
                <div class="metric-card-label">Active Suppliers</div>
                <div class="metric-card-icon success">🟢</div>
            </div>
            <div class="metric-card-value">{active_count:,}</div>
            <div style="font-size: 1.25rem; font-weight: 600; color: var(--success); margin: 0.25rem 0;">{format_ltv(active_ltv)} LTV</div>
            <span class="status-badge success">${active_2025/1_000_000:.1f}M in 2025</span>
        </div>
        ''', unsafe_allow_html=True)

    # At-Risk (Loosing) Suppliers
    loosing = state_data.get("loosing", {})
    loosing_count = loosing.get("count", 0)
    loosing_ltv = loosing.get("total_ltv", 0)
    loosing_2024 = loosing.get("total_2024", 0)  # $ at risk = what they did in 2024
    with cols[1]:
        st.markdown(f'''
        <div class="metric-card">
            <div class="metric-card-header">
                <div class="metric-card-label">At-Risk (Loosing)</div>
                <div class="metric-card-icon warning">🟡</div>
            </div>
            <div class="metric-card-value">{loosing_count:,}</div>
            <div style="font-size: 1.25rem; font-weight: 600; color: var(--warning); margin: 0.25rem 0;">{format_ltv(loosing_ltv)} LTV</div>
            <span class="status-badge warning">${loosing_2024/1_000:,.0f}K at risk</span>
        </div>
        ''', unsafe_allow_html=True)

    # Lost Suppliers
    lost = state_data.get("lost", {})
    lost_count = lost.get("count", 0)
    lost_ltv = lost.get("total_ltv", 0)
    lost_2024 = lost.get("total_2024", 0)  # $ churned = what they did in 2024
    with cols[2]:
        st.markdown(f'''
        <div class="metric-card">
            <div class="metric-card-header">
                <div class="metric-card-label">Lost Suppliers</div>
                <div class="metric-card-icon danger">🔴</div>
            </div>
            <div class="metric-card-value">{lost_count:,}</div>
            <div style="font-size: 1.25rem; font-weight: 600; color: var(--danger); margin: 0.25rem 0;">{format_ltv(lost_ltv)} LTV</div>
            <span class="status-badge danger">${lost_2024/1_000:,.0f}K churned</span>
        </div>
        ''', unsafe_allow_html=True)

    # Inactive Suppliers
    inactive = state_data.get("inactive", {})
    inactive_count = inactive.get("count", 0)
    inactive_ltv = inactive.get("total_ltv", 0)
    with cols[3]:
        st.markdown(f'''
        <div class="metric-card">
            <div class="metric-card-header">
                <div class="metric-card-label">Inactive</div>
                <div class="metric-card-icon neutral">⚪</div>
            </div>
            <div class="metric-card-value">{inactive_count:,}</div>
            <div style="font-size: 1.25rem; font-weight: 600; color: var(--text-muted); margin: 0.25rem 0;">{format_ltv(inactive_ltv)} LTV</div>
            <span class="status-badge neutral">dormant</span>
        </div>
        ''', unsafe_allow_html=True)

    # Summary row
    total = state_data.get("total", {})
    total_2024 = total.get("total_2024", 0)
    total_2025 = total.get("total_2025", 0)
    total_ltv = total.get("total_ltv", 0)
    overall_npr = (total_2025 / total_2024 * 100) if total_2024 > 0 else 0

    st.markdown(f'''
    <div style="background: var(--bg-main); border-radius: var(--radius-md); padding: 1rem 1.5rem; margin-top: 1rem; border: 1px solid var(--border-light);">
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
            <div>
                <span style="font-weight: 600; color: var(--text-primary);">Total Suppliers:</span>
                <span style="margin-left: 0.5rem; color: var(--text-secondary);">{total.get("count", 0):,}</span>
            </div>
            <div>
                <span style="font-weight: 600; color: var(--text-primary);">Total LTV:</span>
                <span style="margin-left: 0.5rem; color: var(--recess-cyan); font-weight: 600;">${total_ltv/1_000_000:.1f}M</span>
            </div>
            <div>
                <span style="font-weight: 600; color: var(--text-primary);">2024 Payouts:</span>
                <span style="margin-left: 0.5rem; color: var(--text-secondary);">${total_2024/1_000_000:.2f}M</span>
            </div>
            <div>
                <span style="font-weight: 600; color: var(--text-primary);">2025 Payouts:</span>
                <span style="margin-left: 0.5rem; color: var(--text-secondary);">${total_2025/1_000_000:.2f}M</span>
            </div>
            <div>
                <span style="font-weight: 600; color: var(--text-primary);">Overall NPR:</span>
                <span style="margin-left: 0.5rem; color: {'var(--success)' if overall_npr >= 100 else 'var(--danger)'}; font-weight: 600;">{overall_npr:.1f}%</span>
            </div>
        </div>
    </div>
    ''', unsafe_allow_html=True)

    # Info about the states
    st.markdown('''
    <div style="margin-top: 1.5rem; padding: 1rem; background: var(--bg-white); border-radius: var(--radius-md); border: 1px solid var(--border-light);">
        <div style="font-weight: 600; margin-bottom: 0.5rem; color: var(--text-primary);">Core Action State Definitions</div>
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 0.75rem; font-size: 0.875rem; color: var(--text-secondary);">
            <div>🟢 <strong>Active:</strong> Payouts in 2025, stable or growing</div>
            <div>🟡 <strong>Loosing:</strong> Payouts declining >50% YoY</div>
            <div>🔴 <strong>Lost:</strong> Had 2024 payouts, none in 2025</div>
            <div>⚪ <strong>Inactive:</strong> No recent payout activity</div>
        </div>
    </div>
    ''', unsafe_allow_html=True)


def render_mobile_header():
    """Render a compact header for mobile devices (hidden on desktop via CSS)."""
    st.markdown(f'''
    <div class="mobile-header">
        <span class="mobile-header-logo">⚡ Recess KPIs</span>
        <span class="mobile-header-date">{datetime.now().strftime("%b %d")}</span>
    </div>
    ''', unsafe_allow_html=True)


def render_data_source_indicator():
    """Render the data source indicator in the bottom right corner."""
    status = get_data_source_status()
    is_live = status.get("is_live", False)
    source = status.get("source", "unknown")
    last_updated = status.get("last_updated", "Never")
    error = status.get("error")

    # Format last updated time
    if last_updated and last_updated != "Never":
        try:
            updated_str = last_updated[:16].replace("T", " ")
        except:
            updated_str = "N/A"
    else:
        updated_str = "N/A"

    if is_live:
        indicator_class = "live"
        icon = "✅"
        label = "Live Data"
        cached_note = " (cached)" if "cached" in source else ""
        tooltip_content = f'''
            <div style="font-size: 0.6875rem; text-transform: uppercase; letter-spacing: 0.05em; color: #10b981; margin-bottom: 0.25rem;">Connected</div>
            <div style="margin-bottom: 0.5rem;">BigQuery data is live{cached_note}</div>
            <div style="font-size: 0.6875rem; color: #94a3b8;">Updated: {updated_str}</div>
        '''
    else:
        indicator_class = "mock"
        icon = "⚠️"
        label = "Mock Data"
        error_msg = error if error else "BigQuery unavailable"
        tooltip_content = f'''
            <div style="font-size: 0.6875rem; text-transform: uppercase; letter-spacing: 0.05em; color: #f59e0b; margin-bottom: 0.25rem;">Offline</div>
            <div style="margin-bottom: 0.5rem;">Using fallback mock data</div>
            <div style="font-size: 0.6875rem; color: #94a3b8;">Reason: {error_msg}</div>
        '''

    st.markdown(f'''
    <div class="data-source-indicator {indicator_class}">
        <span class="icon">{icon}</span>
        <span>{label}</span>
        <div class="tooltip">{tooltip_content}</div>
    </div>
    ''', unsafe_allow_html=True)


def render_settings_page():
    """Render the settings/admin page for editing targets."""
    render_page_header("Settings", "Manage targets and configuration")

    # Load current targets
    targets = get_all_targets()
    company_targets = targets.get("company", {})
    people_targets = targets.get("people", {})

    # Last updated info
    last_updated = targets.get("last_updated")
    if last_updated:
        st.markdown(f'''
        <div class="dept-summary">
            <strong>Last updated:</strong> {last_updated[:16].replace("T", " ")} by {targets.get("updated_by", "Unknown")}
        </div>
        ''', unsafe_allow_html=True)

    # Company Targets Section
    st.markdown('<div class="section-header">Company Targets</div>', unsafe_allow_html=True)

    with st.form("company_targets_form"):
        col1, col2 = st.columns(2)

        with col1:
            revenue_target = st.number_input(
                "Revenue Target ($)",
                value=int(company_targets.get("revenue_target", 10_000_000)),
                min_value=0,
                max_value=MAX_REVENUE_TARGET,
                step=100_000,
                format="%d",
                help=f"Annual revenue target (max ${MAX_REVENUE_TARGET/MILLION:.0f}B)"
            )
            take_rate_target = st.number_input(
                "Take Rate Target (%)",
                value=float(company_targets.get("take_rate_target", 0.50)) * 100,
                min_value=0.0,
                max_value=100.0,
                step=1.0,
                help="Target take rate (Net Revenue / GMV)"
            )
            nrr_target = st.number_input(
                "NRR Target (%)",
                value=float(company_targets.get("nrr_target", 1.10)) * 100,
                min_value=0.0,
                max_value=200.0,
                step=1.0,
                help="Net Revenue Retention target"
            )

        with col2:
            customer_target = st.number_input(
                "Customer Count Target",
                value=int(company_targets.get("customer_count_target", 75)),
                min_value=0,
                max_value=MAX_CUSTOMER_COUNT,
                step=1,
                help=f"Target number of customers (max {MAX_CUSTOMER_COUNT:,})"
            )
            pipeline_target = st.number_input(
                "Pipeline Coverage Target (x)",
                value=float(company_targets.get("pipeline_target", 3.0)),
                min_value=0.0,
                step=0.1,
                help="Pipeline coverage multiplier target"
            )
            logo_retention_target = st.number_input(
                "Logo Retention Target (%)",
                value=float(company_targets.get("logo_retention_target", 0.50)) * 100,
                min_value=0.0,
                max_value=100.0,
                step=1.0,
                help="Logo retention rate target"
            )

        submitted_company = st.form_submit_button("💾 Save Company Targets", use_container_width=True)

        if submitted_company:
            targets["company"] = {
                "revenue_target": revenue_target,
                "take_rate_target": take_rate_target / 100,
                "nrr_target": nrr_target / 100,
                "customer_count_target": customer_target,
                "pipeline_target": pipeline_target,
                "logo_retention_target": logo_retention_target / 100,
            }
            if save_targets(targets):
                st.success("✅ Company targets saved successfully!")
                st.rerun()
            else:
                st.error("❌ Failed to save targets. Please try again.")

    # Metric Targets Section
    st.markdown('<div class="section-header">Metric Targets</div>', unsafe_allow_html=True)
    st.caption("These targets appear in tooltip info cards and drive status badges. Changes take effect within 5 seconds.")

    metric_targets = targets.get("metric_targets", {})

    with st.form("metric_targets_form"):
        st.markdown("**Company Health**")
        col1, col2, col3 = st.columns(3)
        with col1:
            mt_take_rate = st.number_input(
                "Take Rate Target (%)", value=float(metric_targets.get("Take Rate %", {}).get("value", 0.50)) * 100,
                min_value=0.0, max_value=100.0, step=1.0, key="mt_take_rate")
            mt_demand_nrr = st.number_input(
                "Demand NRR Target (%)", value=float(metric_targets.get("Demand NRR", {}).get("value", 1.10)) * 100,
                min_value=0.0, max_value=300.0, step=1.0, key="mt_demand_nrr")
            mt_supply_nrr = st.number_input(
                "Supply NRR Target (%)", value=float(metric_targets.get("Supply NRR", {}).get("value", 1.10)) * 100,
                min_value=0.0, max_value=300.0, step=1.0, key="mt_supply_nrr")
            mt_logo_retention = st.number_input(
                "Logo Retention Target (%)", value=float(metric_targets.get("Logo Retention", {}).get("value", 0.50)) * 100,
                min_value=0.0, max_value=100.0, step=1.0, key="mt_logo_retention")
        with col2:
            mt_customer_count = st.number_input(
                "Customer Count Target", value=int(metric_targets.get("Customer Count", {}).get("value", 75)),
                min_value=0, step=1, key="mt_customer_count")
            mt_revenue = st.number_input(
                "Revenue YTD Target ($)", value=int(metric_targets.get("Revenue YTD", {}).get("value", 10_000_000)),
                min_value=0, step=100_000, key="mt_revenue")
            mt_pipeline = st.number_input(
                "Pipeline Coverage Target (x)", value=float(metric_targets.get("Pipeline Coverage", {}).get("value", 6.0)),
                min_value=0.0, step=0.5, key="mt_pipeline")
            mt_invoice = st.number_input(
                "Invoice Collection Target (%)", value=float(metric_targets.get("Invoice Collection %", {}).get("value", 0.95)) * 100,
                min_value=0.0, max_value=100.0, step=1.0, key="mt_invoice")
        with col3:
            mt_working_capital = st.number_input(
                "Working Capital Target ($)", value=int(metric_targets.get("Working Capital", {}).get("value", 1_000_000)),
                min_value=0, step=100_000, key="mt_working_capital")
            mt_runway = st.number_input(
                "Months of Runway Target", value=int(metric_targets.get("Months of Runway", {}).get("value", 12)),
                min_value=0, step=1, key="mt_runway")
            mt_concentration = st.number_input(
                "Customer Concentration Max (%)", value=float(metric_targets.get("Customer Concentration", {}).get("value", 0.30)) * 100,
                min_value=0.0, max_value=100.0, step=1.0, key="mt_concentration")
            mt_days_fulfill = st.number_input(
                "Days to Fulfill Max", value=int(metric_targets.get("Days to Fulfill", {}).get("value", 60)),
                min_value=0, step=5, key="mt_days_fulfill")

        st.markdown("**Sales & Marketing**")
        col1, col2, col3 = st.columns(3)
        with col1:
            mt_win_rate = st.number_input(
                "Win Rate Target (%)", value=float(metric_targets.get("Win Rate (90d)", {}).get("value", 0.30)) * 100,
                min_value=0.0, max_value=100.0, step=1.0, key="mt_win_rate")
            mt_deal_size = st.number_input(
                "Avg Deal Size Target ($)", value=int(metric_targets.get("Avg Deal Size", {}).get("value", 150_000)),
                min_value=0, step=10_000, key="mt_deal_size")
            mt_sales_cycle = st.number_input(
                "Sales Cycle Max (days)", value=int(metric_targets.get("Sales Cycle Length", {}).get("value", 60)),
                min_value=0, step=5, key="mt_sales_cycle")
        with col2:
            mt_mql_sql = st.number_input(
                "MQL→SQL Conversion (%)", value=float(metric_targets.get("MQL to SQL Conversion", {}).get("value", 0.30)) * 100,
                min_value=0.0, max_value=100.0, step=1.0, key="mt_mql_sql")
            mt_weighted_pipeline = st.number_input(
                "Weighted Pipeline Target ($)", value=int(metric_targets.get("Weighted Pipeline", {}).get("value", 5_000_000)),
                min_value=0, step=100_000, key="mt_weighted_pipeline")
            mt_meetings = st.number_input(
                "Meetings Booked Target (MTD)", value=int(metric_targets.get("Meetings Booked (MTD)", {}).get("value", 24)),
                min_value=0, step=1, key="mt_meetings")
        with col3:
            mt_deals_closing = st.number_input(
                "Deals Closing ≤30d Target", value=int(metric_targets.get("Deals Closing ≤30d", {}).get("value", 5)),
                min_value=0, step=1, key="mt_deals_closing")
            mt_expired_deals = st.number_input(
                "Expired Open Deals Max", value=int(metric_targets.get("Expired Open Deals", {}).get("value", 0)),
                min_value=0, step=1, key="mt_expired_deals")

        st.markdown("**Operational**")
        col1, col2, col3 = st.columns(3)
        with col1:
            mt_nps = st.number_input(
                "NPS Score Target", value=int(metric_targets.get("NPS Score", {}).get("value", 50)),
                min_value=0, max_value=100, step=5, key="mt_nps")
            mt_contract_spend = st.number_input(
                "Contract Spend Target (%)", value=float(metric_targets.get("Contract Spend %", {}).get("value", 1.00)) * 100,
                min_value=0.0, max_value=100.0, step=1.0, key="mt_contract_spend")
        with col2:
            mt_overdue = st.number_input(
                "Overdue Invoices Max", value=int(metric_targets.get("Overdue Invoices", {}).get("value", 0)),
                min_value=0, step=1, key="mt_overdue")
            mt_contacts = st.number_input(
                "Weekly Contact Attempts", value=int(metric_targets.get("Weekly Contact Attempts", {}).get("value", 50)),
                min_value=0, step=5, key="mt_contacts")
        with col3:
            mt_not_contacted = st.number_input(
                "Companies Not Contacted 7d Max", value=int(metric_targets.get("Companies Not Contacted 7d", {}).get("value", 0)),
                min_value=0, step=1, key="mt_not_contacted")

        submitted_metrics = st.form_submit_button("💾 Save Metric Targets", use_container_width=True)

        if submitted_metrics:
            def _fmt_pct(v): return f"{int(v)}%"
            def _fmt_curr(v): return f"${v/1_000_000:.0f}M" if v >= 1_000_000 else f"${v/1_000:.0f}K"
            def _fmt_days_max(v): return f"≤{int(v)} days"
            def _fmt_num(v): return f"{int(v)}"
            def _fmt_mult(v): return f"{v:.1f}x"

            targets["metric_targets"] = {
                "Take Rate %": {"value": mt_take_rate / 100, "format": "percent", "display": _fmt_pct(mt_take_rate)},
                "Demand NRR": {"value": mt_demand_nrr / 100, "format": "percent", "display": _fmt_pct(mt_demand_nrr)},
                "Supply NRR": {"value": mt_supply_nrr / 100, "format": "percent", "display": _fmt_pct(mt_supply_nrr)},
                "Logo Retention": {"value": mt_logo_retention / 100, "format": "percent", "display": _fmt_pct(mt_logo_retention)},
                "Customer Count": {"value": mt_customer_count, "format": "number", "display": _fmt_num(mt_customer_count)},
                "Days to Fulfill": {"value": mt_days_fulfill, "format": "days_max", "display": _fmt_days_max(mt_days_fulfill)},
                "Revenue YTD": {"value": mt_revenue, "format": "currency", "display": _fmt_curr(mt_revenue)},
                "Pipeline Coverage": {"value": mt_pipeline, "format": "multiplier", "display": _fmt_mult(mt_pipeline)},
                "Invoice Collection %": {"value": mt_invoice / 100, "format": "percent", "display": _fmt_pct(mt_invoice)},
                "Win Rate (90d)": {"value": mt_win_rate / 100, "format": "percent", "display": _fmt_pct(mt_win_rate)},
                "Avg Deal Size": {"value": mt_deal_size, "format": "currency", "display": _fmt_curr(mt_deal_size)},
                "Sales Cycle Length": {"value": mt_sales_cycle, "format": "days_max", "display": _fmt_days_max(mt_sales_cycle)},
                "Working Capital": {"value": mt_working_capital, "format": "currency_min", "display": f">${_fmt_curr(mt_working_capital)}"},
                "Months of Runway": {"value": mt_runway, "format": "months_min", "display": f">{mt_runway} mo"},
                "Customer Concentration": {"value": mt_concentration / 100, "format": "percent_max", "display": f"<{int(mt_concentration)}%"},
                "MQL to SQL Conversion": {"value": mt_mql_sql / 100, "format": "percent", "display": _fmt_pct(mt_mql_sql)},
                "NPS Score": {"value": mt_nps, "format": "number_min", "display": f"{mt_nps}+"},
                "Contract Spend %": {"value": mt_contract_spend / 100, "format": "percent", "display": _fmt_pct(mt_contract_spend)},
                "Overdue Invoices": {"value": mt_overdue, "format": "number_max", "display": _fmt_num(mt_overdue)},
                "Weighted Pipeline": {"value": mt_weighted_pipeline, "format": "currency", "display": _fmt_curr(mt_weighted_pipeline)},
                "Meetings Booked (MTD)": {"value": mt_meetings, "format": "number", "display": _fmt_num(mt_meetings)},
                "Weekly Contact Attempts": {"value": mt_contacts, "format": "number", "display": _fmt_num(mt_contacts)},
                "Companies Not Contacted 7d": {"value": mt_not_contacted, "format": "number_max", "display": _fmt_num(mt_not_contacted)},
                "Deals Closing ≤30d": {"value": mt_deals_closing, "format": "number", "display": _fmt_num(mt_deals_closing)},
                "Expired Open Deals": {"value": mt_expired_deals, "format": "number_max", "display": _fmt_num(mt_expired_deals)},
            }
            if save_targets(targets):
                st.success("✅ Metric targets saved successfully!")
                st.rerun()
            else:
                st.error("❌ Failed to save metric targets. Please try again.")

    # Team Targets Section
    st.markdown('<div class="section-header">Team Targets</div>', unsafe_allow_html=True)

    # Create a form for each person
    for person in PERSON_METRICS:
        name = person["name"]
        metric_name = person["metric_name"]
        current_target = person["target"]
        fmt = person["format"]

        # Get saved target if exists
        saved_target = people_targets.get(name, {}).get("target", current_target)

        with st.expander(f"**{name}** — {metric_name}", expanded=False):
            with st.form(f"person_{name}_form"):
                # Different input based on format
                if fmt == "currency":
                    new_target = st.number_input(
                        f"Target for {metric_name}",
                        value=int(saved_target),
                        min_value=0,
                        step=10_000,
                        format="%d",
                        key=f"input_{name}"
                    )
                elif fmt == "percent":
                    new_target_pct = st.number_input(
                        f"Target for {metric_name} (%)",
                        value=float(saved_target) * 100,
                        min_value=0.0,
                        max_value=200.0,
                        step=1.0,
                        key=f"input_{name}"
                    )
                    new_target = new_target_pct / 100
                elif fmt in ["hours", "days"]:
                    new_target = st.number_input(
                        f"Target for {metric_name}",
                        value=float(saved_target),
                        min_value=0.0,
                        step=1.0,
                        key=f"input_{name}"
                    )
                else:  # number, multiplier
                    new_target = st.number_input(
                        f"Target for {metric_name}",
                        value=float(saved_target),
                        min_value=0.0,
                        step=1.0,
                        key=f"input_{name}"
                    )

                submitted = st.form_submit_button(f"💾 Save {name}'s Target")

                if submitted:
                    if name not in targets["people"]:
                        targets["people"][name] = {}
                    targets["people"][name]["target"] = new_target
                    targets["people"][name]["metric_name"] = metric_name
                    targets["people"][name]["format"] = fmt
                    if save_targets(targets):
                        st.success(f"✅ Target for {name} saved!")
                        st.rerun()
                    else:
                        st.error("❌ Failed to save. Please try again.")

    # Export/Import Section
    st.markdown('<div class="section-header">Data Management</div>', unsafe_allow_html=True)

    col1, col2 = st.columns(2)
    with col1:
        st.download_button(
            label="📥 Export Targets (JSON)",
            data=json.dumps(targets, indent=2),
            file_name="recess_targets.json",
            mime="application/json",
            use_container_width=True
        )
    with col2:
        st.info("💡 Targets are saved to `dashboard/data/targets.json`")


def main():
    """Main app."""
    render_sidebar()

    # Mobile header (hidden on desktop via CSS)
    render_mobile_header()

    # Data source indicator (bottom right)
    render_data_source_indicator()

    # Get current page
    page = st.session_state.get('current_page', 'overview')

    if page == 'overview':
        render_page_header("Company Overview", "Real-time performance across all departments")
        render_north_star()
        render_health_metrics()
        render_team_scorecard()
    elif page == 'settings':
        render_settings_page()
    elif page == 'ceo':
        render_page_header("CEO / Biz Dev", "Jack's dashboard — revenue and growth")
        render_ceo_dashboard()
    elif page == 'coo':
        render_page_header("COO / Ops", "Deuce's dashboard — operations and finance")
        render_coo_dashboard()
    elif page == 'demand_sales':
        render_page_header("Demand Sales", "Sales team pipeline and coverage")
        render_demand_sales_dashboard()
    elif page == 'demand_am':
        render_page_header("Demand AM", "Account management performance")
        render_demand_am_dashboard()
    elif page == 'marketing':
        render_page_header("Marketing", "Demand generation performance")
        render_marketing_dashboard()
    elif page == 'accounting':
        render_page_header("Accounting", "AR/AP operations and cash health")
        render_accounting_dashboard()
    elif page == 'engineering':
        render_page_header("Engineering", "Product & engineering delivery (Phase 5)")
        render_engineering_dashboard()
    elif page == 'supply':
        # Custom Supply dashboard with capacity data
        render_page_header("Supply", "Venue/event acquisition and capacity tracking")
        render_supply_dashboard()
    elif page == 'supply_am':
        # Custom Supply AM dashboard with Core Action State tiles
        render_page_header("Supply AM", "Supplier relationship management and NPR tracking")
        render_supply_am_dashboard()
    else:
        # Department detail page
        dept_name = NAV_TO_DEPT.get(page, page)
        render_page_header(dept_name, DEPARTMENT_DETAILS.get(dept_name, {}).get("summary", "Department metrics and performance"))
        render_department_detail(dept_name)


if __name__ == "__main__":
    main()

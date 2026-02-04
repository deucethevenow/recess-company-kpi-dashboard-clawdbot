"""
2025 Reference Values for Company Health Metrics.

These values serve as benchmarks and can be displayed on the dashboard
for comparison with current year performance.

Last validated: 2026-02-03
"""

REFERENCE_YEAR = 2025

COMPANY_HEALTH_2025 = {
    # Revenue (Market Place Revenue = Net after discounts and payouts)
    "revenue": {
        "value": 3_907_000,
        "formatted": "$3.91M",
        "owner": "Jack",
        "target": 10_000_000,
        "note": "Revenue = Market Place Revenue (GMV - Discounts - Organizer Fees)",
    },

    # Take Rate
    "take_rate": {
        "value": 0.493,  # 49.3%
        "formatted": "49.3%",
        "owner": "Deuce",
        "target": 0.45,  # 45%
        "components": {
            "gmv": 7_920_470,
            "discounts": -1_248_996,
            "organizer_fees": -2_769_659,
            "market_place_revenue": 3_901_815,
        },
    },

    # Demand NRR (2024 cohort's 2025 revenue vs their 2024 revenue)
    # Source: cohort_retention_matrix_by_customer view
    "demand_nrr": {
        "value": 0.222,  # 22.2%
        "formatted": "22%",
        "owner": "Andy",
        "target": 1.07,  # 107%
        "components": {
            "cohort_year": 2024,
            "cohort_2024_revenue": 1_517_381,  # 2024 cohort's 2024 revenue
            "cohort_2025_revenue": 337_591,    # Same cohort's 2025 revenue
            "nrr_calculation": "337,591 / 1,517,381 = 22.2%",
        },
        "note": "Cohort-based NRR from cohort_retention_matrix_by_customer",
    },

    # Supply NRR (2024 cohort's 2025 payouts vs their 2024 payouts)
    # Source: Supplier_Metrics view
    "supply_nrr": {
        "value": 0.667,  # 66.7%
        "formatted": "66.7%",
        "owner": "Ashton",
        "target": 1.07,  # 107%
        "components": {
            "cohort_year": 2024,
            "cohort_2024_payouts": 2_740_588,  # 2024 cohort's 2024 payouts
            "cohort_2025_payouts": 1_827_746,  # Same cohort's 2025 payouts
            "supplier_count": 156,
            "nrr_calculation": "1,827,746 / 2,740,588 = 66.7%",
        },
        "note": "Cohort-based NRR from Supplier_Metrics",
    },

    # Pipeline Coverage (dynamic from HubSpot company properties)
    "pipeline_coverage": {
        "value": 3.26,  # Q1 2026 coverage
        "formatted": "3.26x",
        "owner": "Andy",
        "target": 3.0,  # 3.0x
        "annual_goal": 11_268_142,
        "goal_breakdown": {
            "company_properties": 9_268_142,  # Land & Expand + New Customer + Renewal
            "unnamed_accounts": 2_000_000,
        },
        "quota_breakdown": {
            "land_expand": 3_901_985,
            "new_customer": 2_457_788,
            "renewal": 2_908_369,
        },
        "excluded_quotas": {  # Tracked separately
            "dg_quota": 385_329,
            "walmart_quota": 786_682,
        },
        "note": "Quota from HubSpot property_x_YYYY_*_quota fields. DG and Walmart excluded from main total.",
    },

    # Days to Fulfill (Contract Spend from Close Date)
    # Measures: Closed Won Date → Days Until Contract Spend = 100% of Contract
    # 100% = Cumulative (GMV invoices - credit memos) >= contract amount (property_amount)
    "time_to_fulfill": {
        "value": 69,  # 69 days (median) - from new view
        "formatted": "69 days",
        "owner": "Victoria",
        "target": 60,  # Target is 60 days
        "components": {
            "median_days": 69,
            "avg_days": 156,
            "contract_count": 226,
            "fulfilled_count": 177,
            "in_progress_count": 49,
        },
    },

    # Logo Retention (uses DISTINCT customer_id)
    "logo_retention": {
        "value": 0.261,  # 26.1%
        "formatted": "26.1%",
        "owner": "TBD",
        "target": 0.50,  # 50%
        "components": {
            "unique_customers_2024": 69,  # NOT 535 (that was rows)
            "retained_2025": 18,           # NOT 96 (that was rows)
        },
        "note": "Must use COUNT(DISTINCT customer_id) - view has multiple rows per customer",
    },

    # Customer Concentration
    "customer_concentration": {
        "value": 0.292,  # 29.2% (HEINEKEN)
        "formatted": "29.2%",
        "owner": "TBD",
        "target": None,  # Lower is better (less concentration risk)
        "top_customers": [
            {"name": "HEINEKEN USA", "revenue": 1_181_208, "pct": 0.292},
            {"name": "The Kraft Heinz Company", "revenue": 957_402, "pct": 0.237},
            {"name": "Advantage Solutions", "revenue": 223_866, "pct": 0.055},
        ],
        "components": {
            "top_customer_revenue": 1_181_208,
            "total_revenue": 4_045_323,
            "top_2_combined_pct": 0.529,  # 52.9%
        },
    },

    # Active Customers (uses DISTINCT customer_id)
    "active_customers": {
        "value": 40,  # NOT 566 (that was rows)
        "formatted": "40",
        "owner": "TBD",
        "target": None,
        "note": "Unique customers with 2025 revenue > 0",
    },

    # Churned Customers (uses DISTINCT customer_id)
    "churned_customers": {
        "value": 51,  # NOT 426 (that was rows)
        "formatted": "51",
        "owner": "TBD",
        "target": None,  # Lower is better
        "components": {
            "unique_customers_2024": 69,
            "churn_rate": 0.739,  # 73.9% (51/69)
        },
        "note": "Had 2024 revenue but $0 in 2025",
    },
}


def get_reference_value(metric_key: str) -> dict:
    """Get 2025 reference value for a metric."""
    return COMPANY_HEALTH_2025.get(metric_key, {})


def get_all_reference_values() -> dict:
    """Get all 2025 reference values."""
    return COMPANY_HEALTH_2025

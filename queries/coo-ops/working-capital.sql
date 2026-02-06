-- =============================================================================
-- WORKING CAPITAL (Shared: COO + CEO)
-- =============================================================================
-- Purpose: Calculate working capital (Current Assets - Current Liabilities)
-- Owner: Deuce (COO), Jack (CEO)
-- Target: >$1M
-- Refresh: Daily
--
-- Formula: Working Capital = Current Assets - Current Liabilities
-- Current Assets = Cash + AR + Other current assets
-- Current Liabilities = AP + Other current liabilities
-- =============================================================================

WITH balance_sheet AS (
    SELECT
        acc.id AS account_id,
        acc.name AS account_name,
        acc.account_type,
        acc.account_sub_type,
        acc.classification,
        acc.balance AS current_balance,
        acc.account_number,

        -- Classify as current vs non-current
        CASE
            -- Current Assets
            WHEN acc.account_type = 'Bank' THEN 'Current Asset'
            WHEN acc.account_type = 'Accounts Receivable' THEN 'Current Asset'
            WHEN acc.account_sub_type IN ('OtherCurrentAssets', 'Inventory', 'PrepaidExpenses') THEN 'Current Asset'

            -- Current Liabilities
            WHEN acc.account_type = 'Accounts Payable' THEN 'Current Liability'
            WHEN acc.account_sub_type IN ('OtherCurrentLiabilities', 'CreditCard', 'LongTermLiability') THEN 'Current Liability'

            ELSE 'Other'
        END AS balance_sheet_category

    FROM `stitchdata-384118.src_fivetran_qbo.account` acc
    WHERE acc._fivetran_deleted = FALSE
      AND acc.active = TRUE
)

-- Working Capital Calculation
SELECT
    'Working Capital' AS metric,

    -- Current Assets
    SUM(CASE WHEN balance_sheet_category = 'Current Asset' THEN current_balance ELSE 0 END) AS current_assets,

    -- Current Liabilities (typically negative in QBO, so we ABS it)
    ABS(SUM(CASE WHEN balance_sheet_category = 'Current Liability' THEN current_balance ELSE 0 END)) AS current_liabilities,

    -- Working Capital
    SUM(CASE WHEN balance_sheet_category = 'Current Asset' THEN current_balance ELSE 0 END) -
    ABS(SUM(CASE WHEN balance_sheet_category = 'Current Liability' THEN current_balance ELSE 0 END)) AS working_capital,

    1000000 AS target,  -- $1M

    -- Current Ratio
    ROUND(
        SUM(CASE WHEN balance_sheet_category = 'Current Asset' THEN current_balance ELSE 0 END) /
        NULLIF(ABS(SUM(CASE WHEN balance_sheet_category = 'Current Liability' THEN current_balance ELSE 0 END)), 0),
        2
    ) AS current_ratio,

    CASE
        WHEN SUM(CASE WHEN balance_sheet_category = 'Current Asset' THEN current_balance ELSE 0 END) -
             ABS(SUM(CASE WHEN balance_sheet_category = 'Current Liability' THEN current_balance ELSE 0 END)) >= 1000000
        THEN 'GREEN'
        WHEN SUM(CASE WHEN balance_sheet_category = 'Current Asset' THEN current_balance ELSE 0 END) -
             ABS(SUM(CASE WHEN balance_sheet_category = 'Current Liability' THEN current_balance ELSE 0 END)) >= 500000
        THEN 'YELLOW'
        ELSE 'RED'
    END AS status

FROM balance_sheet;


-- =============================================================================
-- BREAKDOWN BY ACCOUNT TYPE
-- =============================================================================
/*
SELECT
    balance_sheet_category,
    account_type,
    account_sub_type,
    COUNT(*) AS account_count,
    SUM(current_balance) AS total_balance
FROM balance_sheet
WHERE balance_sheet_category IN ('Current Asset', 'Current Liability')
GROUP BY balance_sheet_category, account_type, account_sub_type
ORDER BY balance_sheet_category, total_balance DESC;
*/


-- =============================================================================
-- INDIVIDUAL ACCOUNTS
-- =============================================================================
/*
SELECT
    account_name,
    account_number,
    balance_sheet_category,
    current_balance
FROM balance_sheet
WHERE balance_sheet_category IN ('Current Asset', 'Current Liability')
ORDER BY balance_sheet_category, ABS(current_balance) DESC;
*/

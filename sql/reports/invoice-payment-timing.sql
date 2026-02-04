-- BigQuery View: App_KPI_Dashboard.invoice_payment_timing_query
-- Purpose: Analyze invoice payment velocity and cash flow by quarter
-- Key Metrics: avg_days_to_payment (DSO), invoices_paid_within_7_days, pct_paid_within_7_days
-- Joins: QBO invoices → payment_line → payments

WITH invoice_payments AS (
  SELECT
    inv.id AS invoice_id,
    inv.doc_number AS invoice_number,
    cust.display_name AS customer_name,
    inv.transaction_date AS invoice_date,
    inv.due_date,
    inv.total_amount AS invoice_amount,
    pmt.transaction_date AS payment_date,
    pl.amount AS payment_amount,
    DATE_DIFF(pmt.transaction_date, inv.transaction_date, DAY) AS days_to_pay_from_invoice,
    DATE_DIFF(pmt.transaction_date, inv.due_date, DAY) AS days_from_due_date,
    EXTRACT(YEAR FROM inv.transaction_date) AS invoice_year,
    EXTRACT(QUARTER FROM inv.transaction_date) AS invoice_quarter,
    CONCAT(EXTRACT(YEAR FROM inv.transaction_date), '-Q', EXTRACT(QUARTER FROM inv.transaction_date)) AS invoice_quarter_label
  FROM src_fivetran_qbo.invoice AS inv
  LEFT JOIN src_fivetran_qbo.customer AS cust
    ON cust.id = inv.customer_id AND cust._fivetran_deleted = FALSE
  LEFT JOIN src_fivetran_qbo.payment_line AS pl
    ON pl.invoice_id = inv.id
  LEFT JOIN src_fivetran_qbo.payment AS pmt
    ON pmt.id = pl.payment_id AND pmt._fivetran_deleted = FALSE
  WHERE inv._fivetran_deleted = FALSE
    AND inv.total_amount > 0
),

invoice_detail AS (
  SELECT
    invoice_id,
    invoice_number,
    customer_name,
    invoice_date,
    due_date,
    invoice_amount,
    payment_date,
    payment_amount,
    days_to_pay_from_invoice,
    days_from_due_date,
    invoice_quarter_label,
    CASE
      WHEN payment_date IS NULL THEN 'Unpaid'
      WHEN days_from_due_date <= 7 THEN 'Paid Within 7 Days of Due Date'
      WHEN days_from_due_date <= 30 THEN 'Paid 8-30 Days After Due Date'
      WHEN days_from_due_date <= 60 THEN 'Paid 31-60 Days After Due Date'
      ELSE 'Paid 60+ Days After Due Date'
    END AS payment_timing_bucket
  FROM invoice_payments
),

quarterly_summary AS (
  SELECT
    invoice_quarter_label,
    COUNT(DISTINCT invoice_id) AS total_invoices,
    COUNT(DISTINCT CASE WHEN payment_date IS NOT NULL THEN invoice_id END) AS paid_invoices,
    COUNT(DISTINCT CASE WHEN days_from_due_date <= 7 THEN invoice_id END) AS paid_within_7_days_of_due,
    ROUND(SUM(CASE WHEN days_from_due_date <= 7 THEN invoice_amount ELSE 0 END), 2) AS amount_paid_within_7_days,
    ROUND(AVG(CASE WHEN payment_date IS NOT NULL THEN days_to_pay_from_invoice END), 1) AS avg_days_to_pay,
    ROUND(SUM(invoice_amount), 2) AS total_invoiced_amount,
    ROUND(SUM(CASE WHEN payment_date IS NOT NULL THEN payment_amount ELSE 0 END), 2) AS total_paid_amount
  FROM invoice_detail
  GROUP BY invoice_quarter_label
)

SELECT
  invoice_quarter_label AS quarter,
  total_invoices,
  paid_invoices,
  paid_within_7_days_of_due AS invoices_paid_within_7_days,
  ROUND(SAFE_DIVIDE(paid_within_7_days_of_due, paid_invoices) * 100, 1) AS pct_paid_within_7_days,
  amount_paid_within_7_days,
  avg_days_to_pay AS avg_days_to_payment,
  total_invoiced_amount,
  total_paid_amount
FROM quarterly_summary
WHERE invoice_quarter_label IS NOT NULL
ORDER BY invoice_quarter_label DESC

# ============================================================
# Historical Yearly Limited Capacity Report
# ============================================================
#
# PURPOSE:
#   Pulls ALREADY-STORED monthly capacity snapshots from the
#   yearly_limited_capacity report and pushes them to a Google Sheet.
#   This data was captured monthly — no recalculation needed.
#
# HOW TO RUN:
#   1. Open Rails console:  rails c
#   2. Load this script:    load 'docs/plans/Yearly Report Limited Avg Listings/generate_historical_capacity_report.rb'
#
# OUTPUT:
#   A tab in the Google Sheet with columns:
#   Event Type | 1/2024 | 2/2024 | 3/2024 | ... (total capacity per month)
#
# NOTES:
#   - This reads EXISTING ReportData records (no heavy computation)
#   - Should complete in seconds (just a database read + sheet push)
#   - Each month's value = total yearly limited capacity as calculated
#     at that point in time (forward-looking 1 year from that month)
#
# ============================================================

spreadsheet_id = "1PuNrdfRq5Ya5u6bxzdjb_WXhxS3b_Uodah_cTrCq5hc"

# Find the existing yearly_limited_capacity report
report = YearlyReport.find_by(key: :yearly_limited_capacity)

if report.nil?
  puts "ERROR: No YearlyReport found with key :yearly_limited_capacity"
  puts "Available reports:"
  YearlyReport.all.each { |r| puts "  - #{r.key}" }
else
  # Push all historical data to your Google Sheet
  report.report(nil, nil, spreadsheet_id)

  puts "=" * 60
  puts "Historical Yearly Limited Capacity Report"
  puts "=" * 60
  puts "Sheet: https://docs.google.com/spreadsheets/d/#{spreadsheet_id}"
  puts ""
  puts "Data points found: #{report.report_items.where(key: :yearly_limited_capacity).count}"
  puts ""
  puts "Date range:"
  items = report.report_items.where(key: :yearly_limited_capacity).order_by(date: :asc)
  puts "  Earliest: #{items.first&.date}"
  puts "  Latest:   #{items.last&.date}"
  puts "=" * 60
end

# ============================================================
# Average Yearly Limited Capacity Report
# ============================================================
#
# PURPOSE:
#   Generates a one-time report showing average yearly limited
#   capacity per event type with stats (total, count, avg, median).
#   Pushes results to a Google Sheet.
#
# HOW TO RUN:
#   1. SSH into the Rails server (or use rails console locally)
#   2. Open Rails console:  rails c
#   3. Load this script:    load 'docs/plans/Yearly Report Limited Avg Listings/generate_avg_capacity_report.rb'
#
#   OR paste the contents directly into rails console.
#
# OUTPUT:
#   A new tab in the Google Sheet with columns:
#   Event Type | Total Capacity | Listing Count | Avg Capacity | Median Capacity
#
# NOTES:
#   - This script is READ-ONLY on the database (no writes to MongoDB)
#   - It only writes to the external Google Sheet
#   - Processing time depends on listing count (progress logged every 100 listings)
#   - Uses consider_max: true (limited capacity, respects max_duration constraints)
#
# ============================================================

spreadsheet_id = "1PuNrdfRq5Ya5u6bxzdjb_WXhxS3b_Uodah_cTrCq5hc"

# Date range: from beginning of current month, looking 1 year forward
start_date = Date.today.beginning_of_month
end_date = start_date + 1.year

# Query all published, non-omnichannel listings
listing_types = Marketplace.listing_types.keys
scope = AudienceListing.published.not_omnichannel.in(primary_type: listing_types)

# Initialize stats hash per event type
data = {}
listing_types.each { |lt| data[lt] = { capacity: 0, count: 0, capacities: [] } }

total_count = scope.count
puts "=" * 60
puts "Average Yearly Limited Capacity Report"
puts "=" * 60
puts "Date window: #{start_date} to #{end_date}"
puts "Processing #{total_count} listings..."
puts "-" * 60

scope.no_timeout.each_with_index do |listing, index|
  puts "  Progress: #{index + 1}/#{total_count}" if (index + 1) % 100 == 0

  listing_type = listing.primary_type

  # Get product_sampling segments for this listing
  product_sampling_segments = listing.spaces.map do |key, space_info|
    space_info[:segment] if space_info[:type].to_sym.eql?(:product_sampling)
  end.compact

  # Sum capacity across ALL segments for this listing
  listing_total_capacity = 0
  product_sampling_segments.each do |segment|
    capacity = YearlyReport.capacity_for_segment_in_timeframe(
      start_date, end_date, listing, segment, { consider_max: true }
    )
    listing_total_capacity += capacity.to_i
  end

  # Count listing ONCE (not per segment) with its total capacity
  if listing_total_capacity > 0
    data[listing_type][:capacity] += listing_total_capacity
    data[listing_type][:count] += 1
    data[listing_type][:capacities] << listing_total_capacity
  end
end

# Median calculation
calculate_median = ->(values) {
  return 0 if values.nil? || values.empty?
  sorted = values.sort
  len = sorted.length
  len.odd? ? sorted[len / 2] : ((sorted[len / 2 - 1] + sorted[len / 2]) / 2.0).round(0)
}

# Build report rows
headers = ["Event Type", "Total Capacity", "Listing Count", "Avg Capacity", "Median Capacity"]
rows = []

data.each do |listing_type, stats|
  total = stats[:capacity]
  count = stats[:count]
  avg = count > 0 ? (total.to_f / count).round(0) : 0
  median = calculate_median.call(stats[:capacities])
  rows << [listing_type, total, count, avg, median]
end

# Push to Google Sheet
tab_name = "Avg Yearly Limited Capacity #{start_date.strftime('%b %Y')}"
tabs_data = {}
tabs_data[tab_name] = CSV.generate do |csv|
  csv << headers
  rows.each { |row| csv << row }
end

GoogleSheetClient.sync_tabs_for(spreadsheet_id, tabs_data)

# Print summary
puts "-" * 60
puts "DONE! Report pushed to Google Sheet."
puts "Sheet: https://docs.google.com/spreadsheets/d/#{spreadsheet_id}"
puts "Tab: '#{tab_name}'"
puts "-" * 60
puts "\nSummary by event type:"
puts "-" * 60
printf "  %-20s %10s %8s %10s %10s\n", "Type", "Total", "Count", "Avg", "Median"
puts "  " + "-" * 58
data.each do |lt, stats|
  next if stats[:count] == 0
  avg = (stats[:capacity].to_f / stats[:count]).round(0)
  median = calculate_median.call(stats[:capacities])
  printf "  %-20s %10d %8d %10d %10d\n", lt, stats[:capacity], stats[:count], avg, median
end
puts "=" * 60

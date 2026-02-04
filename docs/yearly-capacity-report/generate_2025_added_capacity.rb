# ============================================================
# 2025 Added Limited Capacity by Primary Type
# ============================================================
#
# Run in Rails console:
#   rails c
#   load 'docs/plans/Yearly Report Limited Avg Listings/generate_2025_added_capacity.rb'
#
# OR just paste the contents below into rails c
#
# What it does:
#   - Finds all listings published in 2025 (published + non-omnichannel)
#   - Calculates yearly limited capacity for each (forward 1 year from today)
#   - Groups by primary_type
#   - Pushes results to Google Sheet
#
# Output tab: "2025 Added Limited Capacity by Type"
# Read-only on database. Only writes to external Google Sheet.
# May take several minutes depending on listing count.
# ============================================================

spreadsheet_id = "1PuNrdfRq5Ya5u6bxzdjb_WXhxS3b_Uodah_cTrCq5hc"

publish_start = Date.new(2025, 1, 1)
publish_end = Date.new(2025, 12, 31)

capacity_start = Date.today.beginning_of_month
capacity_end = capacity_start + 1.year

listing_types = Marketplace.listing_types.keys
scope = AudienceListing.published.not_omnichannel
          .where(published_at: publish_start..publish_end)
          .in(primary_type: listing_types)

data = {}
listing_types.each { |lt| data[lt] = { capacity: 0, count: 0 } }

total_count = scope.count
puts "Processing #{total_count} listings published in 2025..."

scope.no_timeout.each_with_index do |listing, index|
  puts "  #{index + 1}/#{total_count}" if (index + 1) % 50 == 0

  listing_type = listing.primary_type
  segments = listing.spaces.map do |key, space_info|
    space_info[:segment] if space_info[:type].to_sym.eql?(:product_sampling)
  end.compact

  listing_capacity = 0
  segments.each do |segment|
    capacity = YearlyReport.capacity_for_segment_in_timeframe(
      capacity_start, capacity_end, listing, segment, { consider_max: true }
    )
    listing_capacity += capacity.to_i
  end

  if listing_capacity > 0
    data[listing_type][:capacity] += listing_capacity
    data[listing_type][:count] += 1
  end
end

headers = ["Event Type", "Listings Published in 2025", "Yearly Limited Capacity"]
rows = data.select { |lt, s| s[:count] > 0 }.sort_by { |lt, s| -s[:capacity] }.map do |lt, stats|
  [lt, stats[:count], stats[:capacity]]
end

tab_name = "2025 Added Limited Capacity by Type"
tabs_data = {}
tabs_data[tab_name] = CSV.generate do |csv|
  csv << headers
  rows.each { |row| csv << row }
end

GoogleSheetClient.sync_tabs_for(spreadsheet_id, tabs_data)

puts "\nDone! Check: https://docs.google.com/spreadsheets/d/#{spreadsheet_id}"
puts "Tab: '#{tab_name}'"
puts "\nTop 10:"
rows.first(10).each { |r| puts "  #{r[0]}: #{r[1]} listings, #{r[2].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} capacity" }

# Average Yearly Limited Capacity Report Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a new YearlyReport type that calculates and displays average, median, total capacity, and listing count per event type.

**Architecture:** Extend the existing `YearlyReport` model with a new report key `:yearly_avg_limited_capacity`. The data collection method stores individual listing capacities (not just totals) to enable median calculation. The report output method generates a Google Sheet with 4 metrics per month as columns.

**Tech Stack:** Ruby, Mongoid, Google Sheets API (via existing `GoogleSheetClient`)

**Repository:** RECESSDigital/recess-marketplace (branch: dev)

**Final Plan Location:** `~/recess-marketplace/docs/plans/Yearly Report Limited Avg Listings/2025-01-21-yearly-avg-limited-capacity.md`

---

## Task 0: Set Up Plan in Repository

**Step 1: Create the plan folder**

```bash
mkdir -p ~/recess-marketplace/docs/plans/"Yearly Report Limited Avg Listings"
```

**Step 2: Copy this plan to the folder**

Copy this plan file to:
`~/recess-marketplace/docs/plans/Yearly Report Limited Avg Listings/2025-01-21-yearly-avg-limited-capacity.md`

---

## Data Structure

The `ReportData.data` hash will store:

```ruby
{
  "running" => {
    capacity: 125000,      # total capacity
    count: 45,             # number of unique listings
    capacities: [2500, 3000, 2800, ...]  # individual values for median
  },
  "cycling" => { ... },
  ...
}
```

## Output Format

Google Sheet columns per month:
| Event Type | Jan 2024 Total | Jan 2024 Count | Jan 2024 Avg | Jan 2024 Median | Feb 2024 Total | ... |

---

### Task 1: Add Data Collection Method

**Files:**
- Modify: `app/models/yearly_report.rb` (add new method after line ~75)

**Step 1: Add the `report_data_for_yearly_avg_limited_capacity` method**

Add this method to `YearlyReport` class, following the pattern of existing `report_data_for_yearly_limited_capacity`:

```ruby
def report_data_for_yearly_avg_limited_capacity start_date
  end_date = start_date + 1.year
  listing_types = Marketplace.listing_types.keys
  scope = AudienceListing.published.not_omnichannel.in(primary_type: listing_types)
  options = { consider_max: true, track_individual: true }
  report_data_for_listing_capacity_with_stats scope, start_date, end_date, options
end
```

**Step 2: Verify syntax**

Run: `ruby -c app/models/yearly_report.rb`
Expected: `Syntax OK`

---

### Task 2: Add Stats-Tracking Data Collection Helper

**Files:**
- Modify: `app/models/yearly_report.rb` (add new method after `report_data_for_listing_capacity`)

**Step 1: Add the `report_data_for_listing_capacity_with_stats` method**

This method collects individual capacities per listing (not per segment) to enable median calculation:

```ruby
def report_data_for_listing_capacity_with_stats scope, start_date, end_date, options={}
  listing_types = Marketplace.listing_types.keys
  data = {}
  listing_types.each do |listing_type|
    data[listing_type] = { capacity: 0, count: 0, capacities: [] }
  end

  scope.no_timeout.each do |listing|
    listing_type = listing.primary_type
    product_sampling_segments = listing.spaces.map do |key, space_info|
      space_info[:segment] if space_info[:type].to_sym.eql? :product_sampling
    end.compact

    # Sum capacity across all segments for this listing
    listing_total_capacity = 0
    product_sampling_segments.each do |product_sampling_segment|
      capacity = YearlyReport.capacity_for_segment_in_timeframe(
        start_date, end_date, listing, product_sampling_segment, options
      )
      listing_total_capacity += capacity.to_i
    end

    # Only count listing once, with its total capacity across segments
    if listing_total_capacity > 0
      data[listing_type][:capacity] += listing_total_capacity
      data[listing_type][:count] += 1
      data[listing_type][:capacities] << listing_total_capacity
    end
  end

  data
end
```

**Step 2: Verify syntax**

Run: `ruby -c app/models/yearly_report.rb`
Expected: `Syntax OK`

---

### Task 3: Add Report Output Method

**Files:**
- Modify: `app/models/yearly_report.rb` (add new method after `report_yearly_added_limited_capacity`)

**Step 1: Add the `report_yearly_avg_limited_capacity` method**

```ruby
def report_yearly_avg_limited_capacity scope, spreadsheet_id=nil
  report_capacity_with_stats scope, "avg yearly limited capacity (#{ENV['FQDN_APP']})", spreadsheet_id
end
```

**Step 2: Verify syntax**

Run: `ruby -c app/models/yearly_report.rb`
Expected: `Syntax OK`

---

### Task 4: Add Stats Report Generator

**Files:**
- Modify: `app/models/yearly_report.rb` (add new method after `report_capacity`)

**Step 1: Add the `report_capacity_with_stats` method**

This generates the multi-column format with Total, Count, Avg, Median per month:

```ruby
def report_capacity_with_stats scope, tab_name, spreadsheet_id=nil
  spreadsheet_id ||= google_sheet_id
  listing_types = Marketplace.listing_types.keys
  rows = []
  headers = [:event_type]
  report_data = {}

  # Initialize data structure for each listing type
  listing_types.each do |listing_type|
    report_data[listing_type] = []
  end

  # Collect data from each time period
  scope.order_by(date: :asc).each do |item|
    month_label = "#{item.date.month}/#{item.date.year}"
    headers << "#{month_label} Total"
    headers << "#{month_label} Count"
    headers << "#{month_label} Avg"
    headers << "#{month_label} Median"

    listing_types.each do |listing_type|
      item_data = item.data[listing_type] || { capacity: 0, count: 0, capacities: [] }
      total = item_data[:capacity].to_i
      count = item_data[:count].to_i
      capacities = item_data[:capacities] || []

      avg = count > 0 ? (total.to_f / count).round(0) : 0
      median = calculate_median(capacities)

      report_data[listing_type] << total
      report_data[listing_type] << count
      report_data[listing_type] << avg
      report_data[listing_type] << median
    end
  end

  # Build rows
  report_data.each do |listing_type, values|
    rows << [listing_type] + values
  end

  tabs_data = {}
  tabs_data["#{tab_name}"] = CSV.generate do |csv|
    csv << headers
    rows.each do |row|
      csv << row
    end
  end
  GoogleSheetClient.sync_tabs_for spreadsheet_id, tabs_data
end

def calculate_median(values)
  return 0 if values.nil? || values.empty?
  sorted = values.sort
  len = sorted.length
  if len.odd?
    sorted[len / 2]
  else
    ((sorted[len / 2 - 1] + sorted[len / 2]) / 2.0).round(0)
  end
end
```

**Step 2: Verify syntax**

Run: `ruby -c app/models/yearly_report.rb`
Expected: `Syntax OK`

---

### Task 5: Create the YearlyReport Record

**Step 1: Create the report via Rails console (or seed/migration)**

In Rails console or a rake task:

```ruby
# Create the new report record
YearlyReport.find_or_create_by(key: :yearly_avg_limited_capacity) do |report|
  report.google_sheet_id = "YOUR_SPREADSHEET_ID_HERE"
end
```

**Step 2: Verify creation**

```ruby
YearlyReport.where(key: :yearly_avg_limited_capacity).first
```

Expected: Returns the new report record

---

### Task 6: Generate Initial Data

**Step 1: Generate data for current month**

```ruby
report = YearlyReport.find_by(key: :yearly_avg_limited_capacity)
report.generate_one_year_data
```

**Step 2: Verify data was stored**

```ruby
report.report_items.first.data
```

Expected: Hash with event types containing `capacity`, `count`, and `capacities` arrays

---

### Task 7: Run Report to Google Sheets

**Step 1: Execute report output**

```ruby
report = YearlyReport.find_by(key: :yearly_avg_limited_capacity)
report.report
```

**Step 2: Verify in Google Sheets**

Open the configured spreadsheet and verify:
- Tab named "avg yearly limited capacity (environment)"
- Columns: event_type, [Month] Total, [Month] Count, [Month] Avg, [Month] Median
- Data rows for each event type

---

## Verification Checklist

1. **Syntax check**: `ruby -c app/models/yearly_report.rb` returns "Syntax OK"
2. **Report record exists**: `YearlyReport.where(key: :yearly_avg_limited_capacity).count == 1`
3. **Data generation works**: `report.generate_one_year_data` completes without error
4. **Data structure correct**: `report.report_items.first.data["running"]` has keys `:capacity`, `:count`, `:capacities`
5. **Report output works**: `report.report` syncs to Google Sheets
6. **Median calculation**: Verify median values are reasonable (not 0 for event types with data)

---

## Files Modified Summary

| File | Change |
|------|--------|
| `app/models/yearly_report.rb` | Add 4 methods: `report_data_for_yearly_avg_limited_capacity`, `report_data_for_listing_capacity_with_stats`, `report_yearly_avg_limited_capacity`, `report_capacity_with_stats`, `calculate_median` |

---

## Notes

- The existing `report_data_for_listing_capacity` method sums capacity per segment, but counts each segment separately. The new `report_data_for_listing_capacity_with_stats` sums all segments for a listing, then counts the listing once.
- Individual capacities are stored in `ReportData.data[listing_type][:capacities]` array to enable median calculation.
- The report can be run for any date range: `report.report(start_date, end_date, spreadsheet_id)`

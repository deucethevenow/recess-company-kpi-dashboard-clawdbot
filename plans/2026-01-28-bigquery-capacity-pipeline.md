# BigQuery Capacity Pipeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Write monthly listings capacity data directly to BigQuery so it can be joined with HubSpot data for the Company KPI Dashboard.

**Architecture:** Extend `YearlyReport` to write detailed listing-level capacity data to BigQuery alongside existing Google Sheets output. Data flows: Rails → BigQuery (new) + Google Sheets (existing). BigQuery data joins with Fivetran-synced HubSpot data.

**Tech Stack:** Ruby on Rails, BigqueryService (existing), Google Cloud BigQuery, MongoDB (source)

---

## Background Context

### The Problem
- `limited_capacity` requires complex Ruby calculation via `ActivationPlanService` (availability windows, min/max duration rules)
- Cannot replicate this calculation in pure SQL
- Need to join capacity data with HubSpot `target_account___supply` property
- Current flow: Rails → Google Sheets (no join capability)

### The Solution
- Add BigQuery write step to existing `YearlyReport.report_for_recently_added_listings`
- Use existing `BigqueryService` class
- Creates `listings_capacity` table with owner_email as join key to HubSpot contacts

### Key Data Points
- **BigQuery Project:** `united-creek-231117`
- **BigQuery Dataset:** `recess_stagging`
- **HubSpot Schema:** `src_fivetran_hubspot` (Fivetran-synced)
- **Join Key:** `owner_email` → HubSpot `contact.property_email`
- **Target Property:** `property_target_account___supply` on contacts/companies

---

## Task 1: Create BigQuery Table Schema

**Files:**
- Create: `app/services/data_dashboard/listings_capacity_schema.json`

**Step 1: Create the schema file**

```json
[
  {"name": "listing_id", "type": "STRING", "mode": "REQUIRED"},
  {"name": "report_month", "type": "DATE", "mode": "REQUIRED"},
  {"name": "created_at", "type": "DATE", "mode": "NULLABLE"},
  {"name": "published_at", "type": "DATE", "mode": "NULLABLE"},
  {"name": "top_org_name", "type": "STRING", "mode": "NULLABLE"},
  {"name": "team_name", "type": "STRING", "mode": "NULLABLE"},
  {"name": "owner_email", "type": "STRING", "mode": "NULLABLE"},
  {"name": "listing_name", "type": "STRING", "mode": "NULLABLE"},
  {"name": "primary_type", "type": "STRING", "mode": "NULLABLE"},
  {"name": "segment", "type": "STRING", "mode": "NULLABLE"},
  {"name": "daily_capacity", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "min_capacity", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "min_duration", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "max_capacity", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "max_duration", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "limited_capacity", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "unlimited_capacity", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "synced_at", "type": "TIMESTAMP", "mode": "REQUIRED"}
]
```

**Step 2: Verify the schema file exists**

Run: `cat app/services/data_dashboard/listings_capacity_schema.json | python3 -m json.tool`
Expected: Valid JSON output

**Step 3: Commit**

```bash
git add app/services/data_dashboard/listings_capacity_schema.json
git commit -m "feat: add BigQuery schema for listings capacity table"
```

---

## Task 2: Add BigQuery Table Creation Method

**Files:**
- Modify: `app/services/bigquery_service.rb` (add method around line 126)

**Step 1: Add table creation method**

Add after the existing `create` method (line 126):

```ruby
def self.create_listings_capacity_table
  table_name = "listings_capacity"
  return if dataset.table(table_name)&.exists?

  dataset.create_table table_name do |table|
    table.schema do |schema|
      schema.load File.open("./app/services/data_dashboard/listings_capacity_schema.json")
    end
  end
end
```

**Step 2: Verify syntax**

Run: `bundle exec ruby -c app/services/bigquery_service.rb`
Expected: `Syntax OK`

**Step 3: Commit**

```bash
git add app/services/bigquery_service.rb
git commit -m "feat: add BigQuery table creation for listings_capacity"
```

---

## Task 3: Add BigQuery Insert Method for Listings Capacity

**Files:**
- Modify: `app/services/bigquery_service.rb`

**Step 1: Add bulk insert method**

Add after the method from Task 2:

```ruby
def self.insert_listings_capacity(rows)
  return unless active?

  create_listings_capacity_table
  table = dataset.table("listings_capacity")

  # BigQuery streaming insert has 10,000 row limit per request
  rows.each_slice(500) do |batch|
    result = table.insert batch
    if result.insert_errors.any?
      puts "BigQuery insert errors: #{result.insert_errors.map(&:errors)}"
    end
  end
end

def self.delete_listings_capacity_for_month(report_month)
  return unless active?

  dataset.query(
    "DELETE FROM listings_capacity WHERE report_month = @month",
    params: { month: report_month.to_s }
  )
end
```

**Step 2: Verify syntax**

Run: `bundle exec ruby -c app/services/bigquery_service.rb`
Expected: `Syntax OK`

**Step 3: Commit**

```bash
git add app/services/bigquery_service.rb
git commit -m "feat: add BigQuery insert/delete methods for listings_capacity"
```

---

## Task 4: Update YearlyReport to Write to BigQuery

**Files:**
- Modify: `app/models/yearly_report.rb` (modify `report_for_recently_added_listings` method, lines 185-232)

**Step 1: Add BigQuery sync call**

Replace lines 185-232 with:

```ruby
def self.report_for_recently_added_listings date=Date.today, spreadsheet_id="1LOCbTQs8G_zCBPnMhYtNNqpvamMqywOpd1DGLUIUdLM", sync_to_bigquery: true
  start_date = date.beginning_of_month
  end_date = date.end_of_month
  scope = AudienceListing.published.not_omnichannel.where(published_at: start_date..end_date)
  headers = [:listing_id, :created_at, :published_at, :top_org, :team, :owner, :name, :primary_type, :segment, :daily_capacity, :min_capacity, :min_duration, :max_capacity, :max_duration, :limited_capacity, :unlimited_capacity]
  rows = []
  bigquery_rows = []
  window_start = (start_date + 1.month).beginning_of_month
  window_end = window_start + 1.year
  synced_at = Time.current

  scope.each do |listing|
    listing_id = listing.id.to_s
    created_at = Date.parse(listing.created_at.to_s) rescue nil
    published_at = Date.parse(listing.published_at.to_s) rescue nil
    top_org = listing.top_org
    top_org_name = top_org[:name] if top_org.present?
    team = listing.team
    team_name = team[:name] if team.present?
    owner = listing.owner
    owner_email = owner[:email] if owner.present?
    name = listing.formatted_title
    primary_type = listing.primary_type
    product_sampling_segments = listing.spaces.map{ |key, space_info| space_info[:segment] if space_info[:type].to_sym.eql? :product_sampling }.compact

    product_sampling_segments.each do |segment|
      next_single_date = [listing.availability_windows.first]
      daily_capacity = ActivationPlanService.capacity_for_dates next_single_date, listing.engagement_capacity, segment
      min_duration = listing.engagement_capacity[segment][:sampling_capacity][:min_duration].to_i
      min_dates_window = ActivationPlanService.select_dates_by_min_max listing, listing.availability_windows, min_duration, min_duration
      min_capacity = 0
      min_capacity = ActivationPlanService.capacity_for_dates min_dates_window, listing.engagement_capacity, segment if min_duration > 0

      max_duration = listing.engagement_capacity[segment][:sampling_capacity][:max_duration].to_i
      max_dates_window = ActivationPlanService.select_dates_by_min_max listing, listing.availability_windows, max_duration, max_duration
      max_capacity = 0
      max_capacity = ActivationPlanService.capacity_for_dates max_dates_window, listing.engagement_capacity, segment if max_duration > 0
      limited_capacity = YearlyReport.capacity_for_segment_in_timeframe window_start, window_end, listing, segment, { consider_max: true }
      unlimited_capacity = YearlyReport.capacity_for_segment_in_timeframe window_start, window_end, listing, segment, { consider_max: false }

      # Google Sheets row
      rows << [listing_id, created_at, published_at, top_org_name, team_name, owner_email, name, primary_type, segment, daily_capacity, min_capacity, min_duration, max_capacity, max_duration, limited_capacity, unlimited_capacity]

      # BigQuery row
      bigquery_rows << {
        listing_id: listing_id,
        report_month: start_date.to_s,
        created_at: created_at&.to_s,
        published_at: published_at&.to_s,
        top_org_name: top_org_name,
        team_name: team_name,
        owner_email: owner_email,
        listing_name: name,
        primary_type: primary_type,
        segment: segment,
        daily_capacity: daily_capacity.to_i,
        min_capacity: min_capacity.to_i,
        min_duration: min_duration,
        max_capacity: max_capacity.to_i,
        max_duration: max_duration,
        limited_capacity: limited_capacity.to_i,
        unlimited_capacity: unlimited_capacity.to_i,
        synced_at: synced_at
      }
    end
  end

  # Sync to Google Sheets (existing behavior)
  tabs_data = {}
  tabs_data["recently added listings info for #{Date::MONTHNAMES[Date.today.month]} (#{ENV['FQDN_APP']})"] = CSV.generate do |csv|
    csv << headers
    rows.each do |row|
      csv << row
    end
  end
  GoogleSheetClient.sync_tabs_for spreadsheet_id, tabs_data

  # Sync to BigQuery (new behavior)
  if sync_to_bigquery && bigquery_rows.any?
    BigqueryService.delete_listings_capacity_for_month(start_date)
    BigqueryService.insert_listings_capacity(bigquery_rows)
    puts "Synced #{bigquery_rows.count} rows to BigQuery listings_capacity table"
  end

  { sheets_rows: rows.count, bigquery_rows: bigquery_rows.count }
end
```

**Step 2: Verify syntax**

Run: `bundle exec ruby -c app/models/yearly_report.rb`
Expected: `Syntax OK`

**Step 3: Commit**

```bash
git add app/models/yearly_report.rb
git commit -m "feat: add BigQuery sync to YearlyReport.report_for_recently_added_listings"
```

---

## Task 5: Create Test Spec

**Files:**
- Create: `spec/models/yearly_report_bigquery_spec.rb`

**Step 1: Write the test file**

```ruby
require 'rails_helper'

RSpec.describe YearlyReport, '.report_for_recently_added_listings BigQuery sync', js: false do
  let!(:listing) do
    create(:audience_listing, :published, :product_sampling,
           published_at: Date.today.beginning_of_month + 5.days)
  end

  describe 'BigQuery sync' do
    before do
      allow(BigqueryService).to receive(:active?).and_return(true)
      allow(BigqueryService).to receive(:delete_listings_capacity_for_month)
      allow(BigqueryService).to receive(:insert_listings_capacity)
      allow(GoogleSheetClient).to receive(:sync_tabs_for)
    end

    it 'calls BigQuery insert with correct data structure' do
      result = YearlyReport.report_for_recently_added_listings(Date.today)

      expect(BigqueryService).to have_received(:insert_listings_capacity) do |rows|
        expect(rows).to be_an(Array)
        expect(rows.first).to include(
          :listing_id,
          :report_month,
          :owner_email,
          :primary_type,
          :limited_capacity,
          :synced_at
        )
      end
    end

    it 'deletes existing month data before inserting' do
      YearlyReport.report_for_recently_added_listings(Date.today)

      expect(BigqueryService).to have_received(:delete_listings_capacity_for_month)
        .with(Date.today.beginning_of_month)
        .ordered
      expect(BigqueryService).to have_received(:insert_listings_capacity).ordered
    end

    it 'skips BigQuery sync when sync_to_bigquery is false' do
      YearlyReport.report_for_recently_added_listings(Date.today, nil, sync_to_bigquery: false)

      expect(BigqueryService).not_to have_received(:insert_listings_capacity)
    end

    it 'returns count of synced rows' do
      result = YearlyReport.report_for_recently_added_listings(Date.today)

      expect(result[:bigquery_rows]).to be >= 0
      expect(result[:sheets_rows]).to be >= 0
    end
  end
end
```

**Step 2: Run the test**

Run: `bundle exec rspec spec/models/yearly_report_bigquery_spec.rb -v`
Expected: All tests pass (green)

**Step 3: Commit**

```bash
git add spec/models/yearly_report_bigquery_spec.rb
git commit -m "test: add specs for YearlyReport BigQuery sync"
```

---

## Task 6: Manual Verification in Rails Console

**Files:** None (manual verification)

**Step 1: Test table creation**

```ruby
rails c
# Test BigQuery connection
BigqueryService.active?  # Should return true

# Create the table (if not exists)
BigqueryService.create_listings_capacity_table

# Verify table exists
BigqueryService.dataset.table("listings_capacity").exists?  # Should return true
```

**Step 2: Test data sync (dry run)**

```ruby
# Run for current month with BigQuery sync
result = YearlyReport.report_for_recently_added_listings(Date.today)
puts result  # Should show { sheets_rows: N, bigquery_rows: N }

# Verify data in BigQuery
BigqueryService.dataset.query("SELECT COUNT(*) as cnt FROM listings_capacity").first[:cnt]
```

**Step 3: Document the results**

Note the row count and any errors for QA verification.

---

## Task 7: Create Dashboard Query Documentation

**Files:**
- Update: `docs/company-kpi-dashboard/yearly-capacity-report/dashboard-context.md`

**Step 1: Add the final dashboard query**

Append to the document:

```markdown
## Final Dashboard Query

This query joins Rails-calculated limited_capacity with HubSpot target account data:

```sql
SELECT
  lc.report_month,
  lc.primary_type,
  lc.listing_name,
  lc.owner_email,
  lc.limited_capacity,
  lc.unlimited_capacity,
  -- Contact-level target account
  COALESCE(c.property_target_account___supply, 'Unknown') as contact_target_account,
  -- Company-level target account (via contact association)
  COALESCE(comp.property_target_account_supply, 'Unknown') as company_target_account,
  -- Unified target account flag
  CASE
    WHEN c.property_target_account___supply = 'Yes' THEN 'Yes'
    WHEN comp.property_target_account_supply = 'true' THEN 'Yes'
    ELSE 'No'
  END as is_target_account
FROM `recess_stagging.listings_capacity` lc
LEFT JOIN `src_fivetran_hubspot.contact` c
  ON LOWER(lc.owner_email) = LOWER(c.property_email)
LEFT JOIN `src_fivetran_hubspot.company` comp
  ON c.property_associatedcompanyid = CAST(comp.id AS STRING)
WHERE lc.report_month = '2026-01-01'  -- Adjust as needed
ORDER BY lc.limited_capacity DESC
```

### Summary by Event Type and Target Account Status

```sql
SELECT
  lc.primary_type,
  CASE
    WHEN c.property_target_account___supply = 'Yes' THEN 'Yes'
    WHEN comp.property_target_account_supply = 'true' THEN 'Yes'
    ELSE 'No'
  END as is_target_account,
  COUNT(DISTINCT lc.listing_id) as listing_count,
  SUM(lc.limited_capacity) as total_limited_capacity
FROM `recess_stagging.listings_capacity` lc
LEFT JOIN `src_fivetran_hubspot.contact` c
  ON LOWER(lc.owner_email) = LOWER(c.property_email)
LEFT JOIN `src_fivetran_hubspot.company` comp
  ON c.property_associatedcompanyid = CAST(comp.id AS STRING)
WHERE lc.report_month = '2026-01-01'
GROUP BY 1, 2
ORDER BY 1, 2
```
```

**Step 2: Commit**

```bash
git add docs/company-kpi-dashboard/yearly-capacity-report/dashboard-context.md
git commit -m "docs: add final BigQuery dashboard queries for capacity + HubSpot join"
```

---

## Verification Checklist

After completing all tasks:

- [ ] `BigqueryService.create_listings_capacity_table` creates table successfully
- [ ] `YearlyReport.report_for_recently_added_listings` writes to both Google Sheets AND BigQuery
- [ ] Row counts match between Sheets and BigQuery
- [ ] `owner_email` field is populated correctly
- [ ] Dashboard query successfully joins with HubSpot contact data
- [ ] Target account filtering works correctly
- [ ] All specs pass: `bundle exec rspec spec/models/yearly_report_bigquery_spec.rb`

---

## Rollback Plan

If issues arise:

1. **Disable BigQuery sync:** Call with `sync_to_bigquery: false`
2. **Existing behavior unchanged:** Google Sheets sync continues to work
3. **Delete bad data:** `BigqueryService.dataset.query("DELETE FROM listings_capacity WHERE report_month = 'YYYY-MM-DD'")`
4. **Drop table if needed:** `BigqueryService.dataset.table("listings_capacity").delete`

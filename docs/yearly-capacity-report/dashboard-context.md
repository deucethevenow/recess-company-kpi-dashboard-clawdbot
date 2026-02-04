# Dashboard Context: Yearly Limited Capacity Metrics

## Overview

We have a monthly report that calculates "yearly limited capacity" per event type. This data is now synced from MongoDB to BigQuery via Fivetran and ready for dashboard consumption.

## Data Source

**BigQuery Table:** `mongodb.report_data`

**Current Data:** 4 months of snapshots (Oct 2025, Nov 2025, Dec 2025, Jan 2026), auto-updates monthly.

## Schema

| Column | Type | Description |
|--------|------|-------------|
| `_id` | STRING | MongoDB document ID |
| `key` | STRING | Report type (filter by `'yearly_limited_capacity'`) |
| `date` | TIMESTAMP | Month this snapshot represents |
| `data` | STRUCT | Capacity per event type (see below) |
| `report_id` | STRING | Parent report reference |
| `created_at` | TIMESTAMP | When snapshot was created |
| `updated_at` | TIMESTAMP | Last update time |

### The `data` STRUCT

Each event type is a nested struct with a `capacity` field:

```
data.sporting_event.capacity (INT64)
data.student_involvement.capacity (INT64)
data.youth_sports.capacity (INT64)
data.travel_hospitality.capacity (INT64)
data.family_event.capacity (INT64)
data.social_sports.capacity (INT64)
data.fitness_studio.capacity (INT64)
data.festival.capacity (INT64)
data.haunted_house.capacity (INT64)
data.food_delivery.capacity (INT64)
data.healthcare.capacity (INT64)
data.university_housing.capacity (INT64)
data.endurance_race.capacity (INT64)
data._5_k_run.capacity (INT64)
... (64 event types total)
```

**Note:** Some event types may have `null` capacity in certain months if no listings existed for that type.

## Dashboard Queries

### 1. Latest Month - All Event Types

```sql
SELECT
  FORMAT_TIMESTAMP('%Y-%m', date) as month,
  data.sporting_event.capacity as sporting_event,
  data.student_involvement.capacity as student_involvement,
  data.youth_sports.capacity as youth_sports,
  data.travel_hospitality.capacity as travel_hospitality,
  data.family_event.capacity as family_event,
  data.social_sports.capacity as social_sports,
  data.fitness_studio.capacity as fitness_studio,
  data.haunted_house.capacity as haunted_house,
  data.festival.capacity as festival,
  data.food_delivery.capacity as food_delivery,
  data.healthcare.capacity as healthcare,
  data.zoo.capacity as zoo,
  data.endurance_race.capacity as endurance_race,
  data.farmers_market.capacity as farmers_market,
  data.food_festival.capacity as food_festival,
  data.fair.capacity as fair,
  data._5_k_run.capacity as five_k_run,
  data.music_festival.capacity as music_festival,
  data.drive_in_movie.capacity as drive_in_movie,
  data.wine_spirits.capacity as wine_spirits,
  data.concert.capacity as concert,
  data.university_housing.capacity as university_housing,
  data.conventional_housing.capacity as conventional_housing,
  data.holiday_market.capacity as holiday_market,
  data.motorsports.capacity as motorsports,
  data.art_show.capacity as art_show,
  data.holiday_lights_drive_thru.capacity as holiday_lights_drive_thru,
  data.mall.capacity as mall,
  data.trade_show.capacity as trade_show,
  data.pet_event.capacity as pet_event,
  data.film_festival.capacity as film_festival,
  data.kids_camp.capacity as kids_camp,
  data.de_stress_event.capacity as de_stress_event,
  data.flea_market.capacity as flea_market,
  data.pet_hotels_and_resorts.capacity as pet_hotels_and_resorts,
  data.lgbtq_event.capacity as lgbtq_event,
  data.comic_con.capacity as comic_con,
  data.vegan_event.capacity as vegan_event,
  data.ski_mountain.capacity as ski_mountain,
  data.coworking.capacity as coworking,
  data.botanical_garden.capacity as botanical_garden,
  data.pumpkin_patch.capacity as pumpkin_patch,
  data.beer_tasting.capacity as beer_tasting,
  data.tailgate.capacity as tailgate,
  data.golf_tournament.capacity as golf_tournament,
  data.university_event.capacity as university_event,
  data.nightlife.capacity as nightlife,
  data.retail.capacity as retail
FROM mongodb.report_data
WHERE key = 'yearly_limited_capacity'
ORDER BY date DESC
LIMIT 1
```

### 2. Monthly Trend (Top 10 Event Types)

```sql
SELECT
  FORMAT_TIMESTAMP('%Y-%m', date) as month,
  data.sporting_event.capacity as sporting_event,
  data.youth_sports.capacity as youth_sports,
  data.student_involvement.capacity as student_involvement,
  data.travel_hospitality.capacity as travel_hospitality,
  data.family_event.capacity as family_event,
  data.social_sports.capacity as social_sports,
  data.haunted_house.capacity as haunted_house,
  data.fitness_studio.capacity as fitness_studio,
  data.food_delivery.capacity as food_delivery,
  data.festival.capacity as festival
FROM mongodb.report_data
WHERE key = 'yearly_limited_capacity'
ORDER BY date ASC
```

### 3. Total Capacity Trend (Sum of Top Categories)

```sql
SELECT
  FORMAT_TIMESTAMP('%Y-%m', date) as month,
  COALESCE(data.sporting_event.capacity, 0) +
  COALESCE(data.student_involvement.capacity, 0) +
  COALESCE(data.youth_sports.capacity, 0) +
  COALESCE(data.travel_hospitality.capacity, 0) +
  COALESCE(data.family_event.capacity, 0) +
  COALESCE(data.social_sports.capacity, 0) +
  COALESCE(data.fitness_studio.capacity, 0) +
  COALESCE(data.festival.capacity, 0) +
  COALESCE(data.haunted_house.capacity, 0) +
  COALESCE(data.food_delivery.capacity, 0) +
  COALESCE(data.healthcare.capacity, 0) +
  COALESCE(data.zoo.capacity, 0) +
  COALESCE(data.endurance_race.capacity, 0) +
  COALESCE(data.farmers_market.capacity, 0) +
  COALESCE(data.food_festival.capacity, 0) AS total_capacity
FROM mongodb.report_data
WHERE key = 'yearly_limited_capacity'
ORDER BY date ASC
```

### 4. Month-over-Month Change

```sql
WITH monthly AS (
  SELECT
    FORMAT_TIMESTAMP('%Y-%m', date) as month,
    date,
    COALESCE(data.sporting_event.capacity, 0) +
    COALESCE(data.youth_sports.capacity, 0) +
    COALESCE(data.student_involvement.capacity, 0) +
    COALESCE(data.family_event.capacity, 0) +
    COALESCE(data.travel_hospitality.capacity, 0) AS top_5_total
  FROM mongodb.report_data
  WHERE key = 'yearly_limited_capacity'
)
SELECT
  month,
  top_5_total,
  LAG(top_5_total) OVER (ORDER BY date) as prev_month,
  top_5_total - LAG(top_5_total) OVER (ORDER BY date) as change,
  ROUND((top_5_total - LAG(top_5_total) OVER (ORDER BY date)) /
        NULLIF(LAG(top_5_total) OVER (ORDER BY date), 0) * 100, 1) as pct_change
FROM monthly
ORDER BY date ASC
```

### 5. Unpivoted Format (For Stacked Charts)

```sql
SELECT
  FORMAT_TIMESTAMP('%Y-%m', date) as month,
  'sporting_event' as event_type,
  data.sporting_event.capacity as capacity
FROM mongodb.report_data WHERE key = 'yearly_limited_capacity'
UNION ALL
SELECT
  FORMAT_TIMESTAMP('%Y-%m', date),
  'youth_sports',
  data.youth_sports.capacity
FROM mongodb.report_data WHERE key = 'yearly_limited_capacity'
UNION ALL
SELECT
  FORMAT_TIMESTAMP('%Y-%m', date),
  'student_involvement',
  data.student_involvement.capacity
FROM mongodb.report_data WHERE key = 'yearly_limited_capacity'
UNION ALL
SELECT
  FORMAT_TIMESTAMP('%Y-%m', date),
  'family_event',
  data.family_event.capacity
FROM mongodb.report_data WHERE key = 'yearly_limited_capacity'
UNION ALL
SELECT
  FORMAT_TIMESTAMP('%Y-%m', date),
  'travel_hospitality',
  data.travel_hospitality.capacity
FROM mongodb.report_data WHERE key = 'yearly_limited_capacity'
ORDER BY month, event_type
```

## Supplementary: Listings Published (Already in BigQuery)

For a "listings added" metric alongside capacity:

```sql
SELECT
  primary_type,
  FORMAT_TIMESTAMP('%Y-%m', published_at) as month,
  COUNT(*) as listings_published,
  SUM(sampling_capacity) as total_daily_capacity
FROM mongodb.audience_listings
WHERE published_state = 'published'
  AND (is_omnichannel IS NULL OR is_omnichannel = FALSE)
  AND published_at >= '2025-01-01'
  AND primary_type IS NOT NULL
GROUP BY primary_type, month
ORDER BY month ASC, listings_published DESC
```

## Dashboard Metrics Summary

| Metric | Source | Query |
|--------|--------|-------|
| Total Limited Capacity | `report_data` | Sum event type capacities |
| Capacity by Event Type | `report_data` | Individual `data.{type}.capacity` |
| Month-over-Month Change | `report_data` | LAG window function |
| Listings Published | `audience_listings` | COUNT by `published_at` month |
| Daily Capacity Added | `audience_listings` | SUM of `sampling_capacity` |

## What "Yearly Limited Capacity" Means

For each event type: the total number of product samples that could be distributed across ALL published listings of that type, looking forward 1 year from the snapshot date, constrained by:
- **Availability windows** — when the venue is available
- **Min/max duration rules** — how long a brand can activate
- **Daily sampling capacity** — how many samples per day

Each monthly snapshot captures this forward-looking capacity at that point in time. The report runs automatically via Sidekiq on the 1st of each month.

---

## HubSpot Integration: Target Supply Account Attribution

### Goal

Join listings/capacity data with HubSpot to identify which came from "Target Supply Accounts" - priority accounts being actively pursued.

### HubSpot Property: `target_account___supply`

**Exists on both Contacts and Companies** with slightly different value formats:

| Object | Property Name | Type | Values |
|--------|--------------|------|--------|
| Contact | `target_account___supply` | enumeration | `"Yes"` / `"No"` |
| Company | `target_account___supply` | boolean checkbox | `"true"` / `"false"` |

**⚠️ Important:** Note the different value formats - Contact uses "Yes"/"No", Company uses "true"/"false".

### Related Contact Properties

| Property | Label | Description |
|----------|-------|-------------|
| `target_account___supply` | Target Account - Supply | Is this a priority supply account? |
| `organization_type__supply_` | Organization Type (Supply) | Maps to Recess event types (e.g., "University Housing", "Fitness Studio") |
| `priority__supply_` | Priority (Supply) | Priority level for supply contacts |

### Sample Target Supply Account Contacts

| Email | Name | Organization Type |
|-------|------|-------------------|
| haley.adams@landmarkproperties.com | Haley Adams | University Housing |
| meghanm@corespaces.com | Meghan Mcalpine | University Housing |
| payal@classpass.com | Payal Kadakia | Fitness Studio |
| cpraid@teamwass.com | Charlie Praid | Youth Sports |

### Sample Target Supply Account Companies

| Company | Domain |
|---------|--------|
| Landmark Properties, Inc. | landmarkproperties.com |
| Core Spaces | corespaces.com |
| Wasserman Media Group LLC | teamwass.com |
| SoulCycle Inc | soul-cycle.com |
| CorePower Yoga | corepoweryoga.com |

### Data Model for Join

```
Recess (MongoDB/BigQuery)              HubSpot
─────────────────────────              ───────
AudienceListing
  └── organizer_id ──────────┐
                             │
Organizer                    │
  └── member_id ─────────────┼───────┐
                             │       │
Member                       │       │
  └── email ─────────────────┼───────┼──→ Contact.email
                             │       │      └── target_account___supply
                             │       │      └── organization_type__supply_
                             │       │
                             │       └──→ Company (via contact association)
                             │              └── target_account___supply
                             │              └── domain
```

### BigQuery Join Queries

#### If HubSpot is synced to BigQuery (Fivetran)

```sql
-- Capacity added this month with Target Account attribution
WITH this_month_listings AS (
  SELECT
    al._id as listing_id,
    al.name as listing_name,
    al.primary_type,
    al.sampling_capacity,
    al.published_at,
    m.email as owner_email
  FROM mongodb.audience_listings al
  LEFT JOIN mongodb.organizers o ON al.organizer_id = o._id
  LEFT JOIN mongodb.members m ON o.member_id = m._id
  WHERE al.published_state = 'published'
    AND (al.is_omnichannel IS NULL OR al.is_omnichannel = FALSE)
    AND al.published_at >= DATE_TRUNC(CURRENT_DATE(), MONTH)
    AND al.published_at < DATE_ADD(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH)
)
SELECT
  tml.primary_type,
  COUNT(*) as listings_count,
  SUM(tml.sampling_capacity) as total_daily_capacity,
  -- Target account breakdown
  COUNT(CASE WHEN hc.target_account___supply = 'Yes' THEN 1 END) as target_account_listings,
  COUNT(CASE WHEN hc.target_account___supply != 'Yes' OR hc.target_account___supply IS NULL THEN 1 END) as non_target_listings,
  -- Capacity breakdown
  SUM(CASE WHEN hc.target_account___supply = 'Yes' THEN tml.sampling_capacity ELSE 0 END) as target_account_capacity,
  SUM(CASE WHEN hc.target_account___supply != 'Yes' OR hc.target_account___supply IS NULL THEN tml.sampling_capacity ELSE 0 END) as non_target_capacity
FROM this_month_listings tml
LEFT JOIN hubspot.contacts hc ON LOWER(tml.owner_email) = LOWER(hc.email)
GROUP BY tml.primary_type
ORDER BY total_daily_capacity DESC
```

#### Company-Level Attribution (via Contact → Company association)

```sql
-- Join through company for company-level target account flag
SELECT
  tml.primary_type,
  tml.listing_name,
  tml.owner_email,
  hc.target_account___supply as contact_is_target,
  hco.target_account___supply as company_is_target,
  hco.name as company_name
FROM this_month_listings tml
LEFT JOIN hubspot.contacts hc ON LOWER(tml.owner_email) = LOWER(hc.email)
LEFT JOIN hubspot.companies hco ON hc.associatedcompanyid = hco.id
WHERE hc.target_account___supply = 'Yes'
   OR hco.target_account___supply = 'true'
```

### Rails Console Script: This Month's Capacity with HubSpot Attribution

```ruby
# Calculate capacity added this month + flag target accounts
# Run in Rails console

require 'csv'

publish_start = Date.today.beginning_of_month
publish_end = Date.today.end_of_month
capacity_start = Date.today.beginning_of_month
capacity_end = capacity_start + 1.year

listing_types = Marketplace.listing_types.keys
scope = AudienceListing.published.not_omnichannel
          .where(published_at: publish_start..publish_end)
          .in(primary_type: listing_types)

results = []

scope.no_timeout.each do |listing|
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

  next if listing_capacity <= 0

  owner_email = listing.organizer&.member&.email

  results << {
    listing_id: listing.id.to_s,
    listing_name: listing.name,
    primary_type: listing.primary_type,
    capacity: listing_capacity,
    owner_email: owner_email,
    organizer_id: listing.organizer_id&.to_s
  }
end

# Output CSV for HubSpot join (can be joined in Google Sheets or BigQuery)
csv_output = CSV.generate do |csv|
  csv << ['listing_id', 'listing_name', 'primary_type', 'capacity', 'owner_email', 'organizer_id']
  results.each { |r| csv << r.values }
end

File.write('/tmp/this_month_capacity.csv', csv_output)
puts "Wrote #{results.count} listings to /tmp/this_month_capacity.csv"

# Summary by type
by_type = results.group_by { |r| r[:primary_type] }
puts "\nCapacity Added This Month by Type:"
by_type.sort_by { |t, listings| -listings.sum { |l| l[:capacity] } }.each do |type, listings|
  total_cap = listings.sum { |l| l[:capacity] }
  puts "  #{type}: #{listings.count} listings, #{total_cap.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} capacity"
end
```

### HubSpot API Alternative (if not in BigQuery)

Use HubSpot MCP tools to look up contacts by email:

```
Tool: hubspot-search-objects
objectType: contacts
filterGroups: [{"filters": [{"propertyName": "email", "operator": "EQ", "value": "owner@example.com"}]}]
properties: ["email", "target_account___supply", "organization_type__supply_"]
```

### Dashboard Metrics with Target Account Attribution

| Metric | Description |
|--------|-------------|
| Capacity Added (Total) | Sum of yearly limited capacity for listings published this month |
| Capacity from Target Accounts | Capacity where owner's contact has `target_account___supply = 'Yes'` |
| Capacity from Non-Target | Capacity where owner is not flagged as target account |
| Target Account % | Percentage of capacity coming from target supply accounts |
| Listings from Target Accounts | Count of listings where owner is a target account |

---

## Implementation: Rails → BigQuery Direct Sync

### Overview

The recommended stable solution is to have `YearlyReport` write listing-level capacity data directly to BigQuery, enabling joins with HubSpot data synced via Fivetran.

**See implementation plan:** `docs/plans/2026-01-28-bigquery-capacity-pipeline.md`

### Why Direct BigQuery Write?

1. **Single source of truth** - Rails calculates `limited_capacity` once, writes to BigQuery
2. **Cannot replicate in SQL** - `limited_capacity` requires `ActivationPlanService` logic (availability windows, min/max duration rules)
3. **Existing infrastructure** - `BigqueryService` already handles BigQuery writes
4. **Better joins** - BigQuery-native joins with HubSpot data (no Google Sheets export/import)

### BigQuery Table: `listings_capacity`

```sql
-- Schema (in recess_stagging dataset)
CREATE TABLE listings_capacity (
  listing_id STRING NOT NULL,
  report_month DATE NOT NULL,
  created_at DATE,
  published_at DATE,
  top_org_name STRING,
  team_name STRING,
  owner_email STRING,              -- JOIN KEY to HubSpot
  listing_name STRING,
  primary_type STRING,
  segment STRING,
  daily_capacity INT64,
  min_capacity INT64,
  min_duration INT64,
  max_capacity INT64,
  max_duration INT64,
  limited_capacity INT64,          -- The key calculated field
  unlimited_capacity INT64,
  synced_at TIMESTAMP NOT NULL
);
```

### Final Dashboard Query

```sql
-- Capacity by event type with Target Account attribution
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
WHERE lc.report_month = DATE_TRUNC(CURRENT_DATE(), MONTH)
ORDER BY lc.limited_capacity DESC
```

### Summary Query for KPI Dashboard

```sql
-- Monthly summary by event type and target account status
SELECT
  lc.report_month,
  lc.primary_type,
  CASE
    WHEN c.property_target_account___supply = 'Yes' THEN 'Yes'
    WHEN comp.property_target_account_supply = 'true' THEN 'Yes'
    ELSE 'No'
  END as is_target_account,
  COUNT(DISTINCT lc.listing_id) as listing_count,
  SUM(lc.limited_capacity) as total_limited_capacity,
  SUM(lc.daily_capacity) as total_daily_capacity
FROM `recess_stagging.listings_capacity` lc
LEFT JOIN `src_fivetran_hubspot.contact` c
  ON LOWER(lc.owner_email) = LOWER(c.property_email)
LEFT JOIN `src_fivetran_hubspot.company` comp
  ON c.property_associatedcompanyid = CAST(comp.id AS STRING)
GROUP BY 1, 2, 3
ORDER BY report_month DESC, total_limited_capacity DESC
```

### Rails Code Changes

Modified method signature:
```ruby
YearlyReport.report_for_recently_added_listings(
  date,
  spreadsheet_id,
  sync_to_bigquery: true  # NEW - defaults to true
)
```

This method now:
1. Calculates capacity for each listing (unchanged)
2. Writes to Google Sheets (unchanged)
3. **NEW:** Writes to BigQuery `listings_capacity` table

### Automated Monthly Sync

The existing Sidekiq schedule that runs `YearlyReport.fire` on the 1st of each month will automatically populate BigQuery data going forward.

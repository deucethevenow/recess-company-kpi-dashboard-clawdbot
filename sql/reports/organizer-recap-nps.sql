-- BigQuery View: App_KPI_Dashboard.organizer_recap_NPS_score
-- Purpose: Track organizer satisfaction scores from event recaps
-- Key Metrics: recess_score (NPS-style rating), supplier, event_type
-- Source: MongoDB recaps collection with nested ctx fields

SELECT
  t2.ctx.supplier.org.name AS supplier,
  t2.ctx.listing.primary_type AS event_type,
  t2.ctx.listing.title AS listing_title,
  DATE(t2.start_date) AS recap_start_date,
  t2.answers.rating_1 AS recess_score,
  t2._id AS recap_id
FROM
  `stitchdata-384118`.mongodb.recaps AS t2
WHERE
  t2.answers.rating_1 IS NOT NULL
ORDER BY recap_start_date

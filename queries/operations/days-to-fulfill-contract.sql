-- BigQuery View: App_KPI_Dashboard.Days_to_Fulfill_Contract_Program
-- Purpose: Measure contract fulfillment velocity (days between first and last accepted offer)
-- Key Metrics: days_between_first_last, first/last accepted offer dates
-- Joins: MongoDB offers → purchase_orders → HubSpot deals

WITH offers_joined AS (
  SELECT
    SAFE_CAST(deal_id_elem.value AS INT64) AS deal_id,
    off.accepted_at AS accepted_ts,
    po.owner_id AS po_owner_id,
    TO_JSON_STRING(po.ctx) AS po_ctx_json
  FROM `stitchdata-384118`.mongodb.offers AS off
  JOIN `stitchdata-384118`.mongodb.purchase_orders AS po
    ON off.purchase_order_id = po._id
  JOIN UNNEST(po.deal_ids) AS deal_id_elem
  WHERE off.accepted_at IS NOT NULL
),

offer_bounds AS (
  SELECT
    deal_id,
    MIN(accepted_ts) AS first_ts,
    MAX(accepted_ts) AS last_ts,
    ANY_VALUE(po_owner_id)  AS any_po_owner_id,
    ANY_VALUE(po_ctx_json)  AS any_po_ctx_json
  FROM offers_joined
  GROUP BY deal_id
),

deal_info AS (
  SELECT
    deal.deal_id,
    deal.property_dealname AS deal_name
  FROM `stitchdata-384118`.src_fivetran_hubspot.deal AS deal
),

brand_rep_candidates AS (
  SELECT
    SAFE_CAST(br.deal_id AS INT64) AS deal_id,
    br._id          AS rep_id,
    br.member_id    AS rep_member_id,
    TRIM(CONCAT(COALESCE(br.first_name, ''), ' ', COALESCE(br.last_name, ''))) AS brand_rep_name,
    1 AS priority
  FROM `stitchdata-384118`.mongodb.brand_reps AS br
  WHERE br.deal_id IS NOT NULL

  UNION ALL

  SELECT
    ob.deal_id,
    br._id          AS rep_id,
    br.member_id    AS rep_member_id,
    TRIM(CONCAT(COALESCE(br.first_name, ''), ' ', COALESCE(br.last_name, ''))) AS brand_rep_name,
    2 AS priority
  FROM offer_bounds ob
  JOIN `stitchdata-384118`.mongodb.brand_reps AS br
    ON br._id = ob.any_po_owner_id
),

brand_rep_picked AS (
  SELECT
    deal_id,
    ARRAY_AGG(STRUCT(rep_id, rep_member_id, brand_rep_name, priority)
              ORDER BY priority ASC, brand_rep_name DESC
              LIMIT 1)[OFFSET(0)] AS rep
  FROM brand_rep_candidates
  GROUP BY deal_id
),

sponsor_candidates AS (
  SELECT
    brd.deal_id,
    s.name AS advertiser,
    1 AS priority
  FROM brand_rep_picked brd
  JOIN `stitchdata-384118`.mongodb.brand_reps AS br
    ON br._id = brd.rep.rep_id
  JOIN `stitchdata-384118`.mongodb.sponsors AS s
    ON REGEXP_CONTAINS(
         TO_JSON_STRING(br.sponsor_ids),
         r'(?i)\b' || REGEXP_REPLACE(CAST(s._id AS STRING), r'([^\w-])', r'\\\1') || r'\b'
       )

  UNION ALL

  SELECT
    brd.deal_id,
    s.name AS advertiser,
    2 AS priority
  FROM brand_rep_picked brd
  JOIN `stitchdata-384118`.mongodb.sponsors AS s
    ON TRUE
  WHERE
    REGEXP_CONTAINS(
      TO_JSON_STRING(s.brand_rep_ids),
      r'(?i)\b' || REGEXP_REPLACE(brd.rep.rep_id, r'([^\w-])', r'\\\1') || r'\b'
    )
    OR
    REGEXP_CONTAINS(
      TO_JSON_STRING(s.brand_rep_ids),
      r'(?i)\b' || REGEXP_REPLACE(brd.rep.rep_member_id, r'([^\w-])', r'\\\1') || r'\b'
    )

  UNION ALL

  SELECT
    ob.deal_id,
    s.name AS advertiser,
    3 AS priority
  FROM offer_bounds ob
  JOIN `stitchdata-384118`.mongodb.sponsors AS s
    ON s.owner_id = ob.any_po_owner_id

  UNION ALL

  SELECT
    ob.deal_id,
    COALESCE(
      JSON_VALUE(ob.any_po_ctx_json, '$.company_name'),
      JSON_VALUE(ob.any_po_ctx_json, '$.brand_name'),
      JSON_VALUE(ob.any_po_ctx_json, '$.advertiser_name')
    ) AS advertiser,
    4 AS priority
  FROM offer_bounds ob
  WHERE COALESCE(
          JSON_VALUE(ob.any_po_ctx_json, '$.company_name'),
          JSON_VALUE(ob.any_po_ctx_json, '$.brand_name'),
          JSON_VALUE(ob.any_po_ctx_json, '$.advertiser_name')
        ) IS NOT NULL
),

sponsor_picked AS (
  SELECT
    deal_id,
    COALESCE(
      ARRAY_AGG(advertiser ORDER BY priority ASC LIMIT 1)[OFFSET(0)],
      'Unknown Advertiser'
    ) AS advertiser
  FROM sponsor_candidates
  GROUP BY deal_id
)

SELECT
  ob.deal_id,
  di.deal_name,
  DATE_DIFF(DATE(ob.last_ts), DATE(ob.first_ts), DAY) AS days_between_first_last,
  FORMAT_DATE('%Y%m%d', DATE(ob.first_ts)) AS first_accepted_offer_date_yyyymmdd,
  FORMAT_DATE('%Y%m%d', DATE(ob.last_ts))  AS last_accepted_offer_date_yyyymmdd,
  sp.advertiser,
  brd.rep.brand_rep_name AS brand_rep
FROM offer_bounds ob
LEFT JOIN deal_info di
  ON ob.deal_id = di.deal_id
LEFT JOIN brand_rep_picked brd
  ON ob.deal_id = brd.deal_id
LEFT JOIN sponsor_picked sp
  ON ob.deal_id = sp.deal_id
ORDER BY first_accepted_offer_date_yyyymmdd DESC

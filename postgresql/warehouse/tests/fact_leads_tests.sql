/*
===============================================================================
FACT LEADS — TESTS
===============================================================================

*/


-- ============================================================
-- TEST 1: Source vs warehouse row count
-- ============================================================

SELECT
    (SELECT COUNT(*)
     FROM intermediate.marketing_leads) AS intermediate_count,

    (SELECT COUNT(*)
     FROM warehouse.fact_leads) AS warehouse_count;


-- ============================================================
-- TEST 2: Duplicate lead_id
-- ============================================================

SELECT
    lead_id,
    COUNT(*) AS row_count
FROM warehouse.fact_leads
GROUP BY lead_id
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 3: Every lead has a valid date_key
-- ============================================================

SELECT
    f.lead_id,
    f.date_key
FROM warehouse.fact_leads AS f
LEFT JOIN warehouse.dim_date AS d
    ON d.date_key = f.date_key
WHERE d.date_key IS NULL;


-- ============================================================
-- TEST 4: date_key correctly represents lead created_at
-- ============================================================

SELECT
    f.lead_id,
    f.date_key,
    l.created_at,
    d.date_key AS expected_date_key
FROM warehouse.fact_leads AS f
JOIN intermediate.marketing_leads AS l
    ON l.lead_id = f.lead_id
JOIN warehouse.dim_date AS d
    ON d.full_date = l.created_at::DATE
WHERE f.date_key <> d.date_key;


-- ============================================================
-- TEST 5: Every populated order_id must exist in orders
-- ============================================================

SELECT
    f.lead_id,
    f.order_id
FROM warehouse.fact_leads AS f
LEFT JOIN warehouse.fact_orders AS o
    ON o.order_id = f.order_id
WHERE f.order_id IS NOT NULL
  AND o.order_id IS NULL;


-- ============================================================
-- TEST 6: Lead-to-order relationship matches intermediate
-- ============================================================

-- Expected: 0 rows

SELECT f.lead_id
FROM warehouse.fact_leads AS f
JOIN intermediate.orders AS o
    ON o.lead_id = f.lead_id
WHERE f.order_id <> o.order_id;


-- ============================================================
-- TEST 7: Lead score must be within valid range
-- ============================================================

SELECT
    lead_id,
    lead_score
FROM warehouse.fact_leads
WHERE lead_score < 0
   OR lead_score > 100;


-- ============================================================
-- TEST 8: Idempotency
-- ============================================================

SELECT COUNT(*) AS fact_leads_count
FROM warehouse.fact_leads;




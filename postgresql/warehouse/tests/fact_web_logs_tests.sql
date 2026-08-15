/*
===============================================================================
FACT WEB LOGS — TESTS
===============================================================================

Expected:
    TEST 1 → counts should match
    TESTS 2–6 → 0 rows
===============================================================================
*/


-- ============================================================
-- TEST 1: Source vs warehouse row count
-- ============================================================

SELECT
    (SELECT COUNT(*)
     FROM intermediate.web_logs) AS intermediate_count,

    (SELECT COUNT(*)
     FROM warehouse.fact_web_logs) AS warehouse_count;


-- ============================================================
-- TEST 2: Duplicate log_id
-- ============================================================

SELECT
    log_id,
    COUNT(*) AS row_count
FROM warehouse.fact_web_logs
GROUP BY log_id
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 3: Every log has a valid date_key
-- ============================================================

SELECT
    f.log_id,
    f.date_key
FROM warehouse.fact_web_logs AS f
LEFT JOIN warehouse.dim_date AS d
    ON d.date_key = f.date_key
WHERE d.date_key IS NULL;


-- ============================================================
-- TEST 4: Every log timestamp maps to the correct date_key
-- ============================================================

SELECT
    f.log_id,
    f.date_key,
    f.log_timestamp,
    d.date_key AS expected_date_key
FROM warehouse.fact_web_logs AS f
JOIN warehouse.dim_date AS d
    ON d.full_date = f.log_timestamp::DATE
WHERE f.date_key <> d.date_key;


-- ============================================================
-- TEST 5: HTTP status codes must be valid
-- ============================================================

SELECT
    log_id,
    status_code
FROM warehouse.fact_web_logs
WHERE status_code NOT BETWEEN 100 AND 599;


-- ============================================================
-- TEST 6: bytes_sent cannot be negative
-- ============================================================

SELECT
    log_id,
    bytes_sent
FROM warehouse.fact_web_logs
WHERE bytes_sent < 0;


-- ============================================================
-- TEST 7: Idempotency
-- Run load_fact_web_logs.sql AGAIN.
-- Expected: warehouse count remains unchanged.
-- ============================================================

SELECT COUNT(*) AS fact_web_logs_count
FROM warehouse.fact_web_logs;


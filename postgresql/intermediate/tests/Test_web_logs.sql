SELECT log_id, country, city, log_timestamp, client_ip, auth_user, session_id, http_method, request_path, status_code, bytes_sent, referer, device_type, browser, is_bot
	FROM intermediate.web_logs;


	-- ============================================================
-- FILE: test_web_logs.sql
-- PURPOSE:
-- Data-quality tests for intermediate.web_logs

-- EXPECTATION:
-- Each test should return ZERO rows.
-- ============================================================

-- ============================================================
-- TEST 1: DUPLICATE LOG IDs
-- ============================================================

SELECT
log_id,
COUNT(*) AS duplicate_count
FROM intermediate.web_logs
GROUP BY log_id
HAVING COUNT(*) > 1;

-- ============================================================
-- TEST 2: REQUIRED FIELDS
-- ============================================================

SELECT *
FROM intermediate.web_logs
WHERE log_id IS NULL
OR country IS NULL
OR city IS NULL
OR log_timestamp IS NULL
OR client_ip IS NULL
OR session_id IS NULL
OR http_method IS NULL
OR request_path IS NULL
OR status_code IS NULL
OR bytes_sent IS NULL
OR referer IS NULL
OR device_type IS NULL
OR browser IS NULL;

-- ============================================================
-- TEST 3: HTTP STATUS CODE VALIDATION
-- ============================================================

SELECT *
FROM intermediate.web_logs
WHERE status_code NOT BETWEEN 100 AND 599;

-- ============================================================
-- TEST 4: BYTES SENT VALIDATION
-- ============================================================

SELECT *
FROM intermediate.web_logs
WHERE bytes_sent < 0;

-- ============================================================
-- TEST 5: HTTP METHOD VALIDATION
-- ============================================================

SELECT *
FROM intermediate.web_logs
WHERE http_method NOT IN ('GET','POST','PUT','DELETE');





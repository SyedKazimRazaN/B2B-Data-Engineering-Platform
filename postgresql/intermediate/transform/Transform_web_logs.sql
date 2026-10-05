-- ============================================================
-- WEB LOGS TRANSFORMATION
-- staging → intermediate
-- ============================================================
-- FILE: transform_web_logs.sql
-- PURPOSE:
--     Transform staging.web_logs into intermediate.web_logs
--
-- PIPELINE:
--     staging.web_logs
--        ↓
--     latest record per log_id
--        ↓
--     cleaning / normalization
--        ↓
--     business validation
--        ↓
--     MERGE into intermediate.web_logs
--
-- DESIGN GOALS:
--     - Keep the latest source record
--     - Normalize whitespace / empty strings
--     - Handle textual missing values
--     - Validate the business rules for this table
--     - Make the load idempotent
-- ============================================================
/* ============================================================================
   10. WEB LOGS
   ============================================================================ */

-- ============================================================
-- 0. QUARANTINE: save web logs that fail validation
--    Same rules as validate_logs below, written the other way round:
--    the CASE returns the first rule the row breaks (NULL = row is valid).
--    staging.web_logs is a full CSV snapshot (one row per log),
--    ON CONFLICT DO NOTHING = a log already saved is not saved again.
-- ============================================================
INSERT INTO intermediate.rejected_records (table_name, record_id, reject_reason)
SELECT
    'web_logs',
    log_id,
    reject_reason
FROM (
    SELECT
        log_id,
        CASE
            WHEN status_code IS NULL OR status_code NOT BETWEEN 100 AND 599
                THEN 'invalid status_code'
            WHEN bytes_sent IS NULL OR bytes_sent < 0
                THEN 'invalid bytes_sent'
            WHEN NULLIF(TRIM(http_method), '') IS NULL
              OR UPPER(TRIM(http_method)) NOT IN ('GET','POST','PUT','DELETE')
                THEN 'invalid http_method'
            WHEN log_timestamp IS NULL
                THEN 'missing log_timestamp'
            WHEN NULLIF(TRIM(country), '') IS NULL
              OR NULLIF(TRIM(city), '') IS NULL
              OR NULLIF(TRIM(client_ip), '') IS NULL
              OR session_id IS NULL
              OR NULLIF(TRIM(request_path), '') IS NULL
              OR NULLIF(TRIM(referer), '') IS NULL
              OR NULLIF(TRIM(device_type), '') IS NULL
              OR NULLIF(TRIM(browser), '') IS NULL
                THEN 'missing required field'
            ELSE NULL
        END AS reject_reason
    FROM staging.web_logs
    WHERE log_id IS NOT NULL
) checked_logs
WHERE reject_reason IS NOT NULL
ON CONFLICT (table_name, record_id) DO NOTHING;


WITH latest_logs AS (
	-- ====================================================
	-- 1. DEDUPLICATION
	-- ====================================================
    SELECT
        log_id,
        country,
        city,
        log_timestamp,
        client_ip,
        auth_user,
        session_id,
        http_method,
        request_path,
        status_code,
        bytes_sent,
        referer,
        device_type,
        browser,
        is_bot,
        ROW_NUMBER() OVER (PARTITION BY log_id ORDER BY _loaded_at DESC) AS rn
    FROM staging.web_logs
    WHERE log_id IS NOT NULL
),

cleaned_logs AS (
	-- ====================================================
	-- 2. CLEANING / NORMALIZATION
	-- ====================================================
    SELECT
        log_id,
        NULLIF(TRIM(country), '') AS country,
        NULLIF(TRIM(city), '') AS city,
        log_timestamp,
        NULLIF(TRIM(client_ip), '') AS client_ip,
        NULLIF(TRIM(auth_user), '') AS auth_user,
        session_id,
        UPPER(NULLIF(TRIM(http_method), '')) AS http_method,
        NULLIF(TRIM(request_path), '') AS request_path,
        status_code,
        bytes_sent,
        NULLIF(TRIM(referer), '') AS referer,
        NULLIF(TRIM(device_type), '') AS device_type,
        NULLIF(TRIM(browser), '') AS browser,
        is_bot
    FROM latest_logs
    WHERE rn = 1
),

validate_logs AS (
	-- ====================================================
	-- 3. BUSINESS VALIDATION
	-- ====================================================
    SELECT *
    FROM cleaned_logs
    WHERE country IS NOT NULL
      AND city IS NOT NULL
      AND log_timestamp IS NOT NULL
      AND client_ip IS NOT NULL
      AND session_id IS NOT NULL
      AND http_method IN ('GET','POST','PUT','DELETE')
      AND request_path IS NOT NULL
      AND status_code BETWEEN 100 AND 599
      AND bytes_sent >= 0
      AND referer IS NOT NULL
      AND device_type IS NOT NULL
      AND browser IS NOT NULL
)

MERGE INTO intermediate.web_logs AS target
USING validate_logs AS source
ON target.log_id = source.log_id


WHEN MATCHED THEN
	UPDATE SET
	-- ============================================================
	-- 4. UPDATE EXISTING ORDER_ITEMS
	-- ============================================================
		country = source.country,
        city = source.city,
        log_timestamp = source.log_timestamp,
        client_ip = source.client_ip,
        auth_user = source.auth_user,
        session_id = source.session_id,
        http_method = source.http_method,
        request_path = source.request_path,
        status_code = source.status_code,
        bytes_sent = source.bytes_sent,
        referer = source.referer,
        device_type = source.device_type,
        browser = source.browser,
        is_bot = source.is_bot

WHEN NOT MATCHED THEN
	INSERT(
	-- ============================================================
	-- 5. INSERT NEW ORDER_ITEMS
	-- ============================================================
		log_id,
		country,
		city,
		log_timestamp,
		client_ip,
		auth_user,
		session_id,
		http_method,
		request_path,
		status_code,
		bytes_sent,
		referer,
		device_type,
		browser,
		is_bot
	)
	VALUES (
		source.log_id,
		source.country,
		source.city,
		source.log_timestamp,
		source.client_ip,
		source.auth_user,
		source.session_id,
		source.http_method,
		source.request_path,
		source.status_code,
		source.bytes_sent,
		source.referer,
		source.device_type,
		source.browser,
		source.is_bot
	);



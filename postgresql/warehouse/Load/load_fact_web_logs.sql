/*
===============================================================================
FACT WEB LOGS — WAREHOUSE LOAD
===============================================================================

Grain:
    One row per web log.

Business key:
    log_id

Primary key:
    log_id

Surrogate keys:
    date → date_key

Load strategy:
    INSERT-ONLY

Reason:
    Web logs represent individual events and should not be overwritten.

Idempotency:
    MERGE matches using log_id.
    Existing logs → no action.
    New logs → INSERT.

Execution Flow:
intermediate.web_logs
        │
        │ log_timestamp
        ▼
warehouse.dim_date
        │
        │ date_key
        ▼
extracted_logs
        │
        ▼
       MERGE
      /     \
 MATCHED   NOT MATCHED
    │          │
 no action    INSERT

===============================================================================
-- FACT WEB LOGS
-- intermediate → warehouse
===============================================================================
*/

--BEGIN;

WITH extracted_logs AS (

    -- ============================================================
    -- 1. Resolve date surrogate key
    -- ============================================================
    SELECT
        w.log_id,
        d.date_key,
        w.log_timestamp,
        w.country,
        w.city,
        w.client_ip,
        w.auth_user,
        w.session_id,
        w.http_method,
        w.request_path,
        w.status_code,
        w.bytes_sent,
        w.referer,
        w.device_type,
        w.browser,
        w.is_bot

    FROM intermediate.web_logs AS w

    INNER JOIN warehouse.dim_date AS d
        ON d.full_date = w.log_timestamp::DATE
)
-- ============================================================
-- 2. Load web logs into fact table
-- ============================================================

MERGE INTO warehouse.fact_web_logs AS target
USING extracted_logs AS source

ON target.log_id = source.log_id

WHEN NOT MATCHED THEN
-- ============================================================
-- 3. Insert new web logs
-- ============================================================
    INSERT (
        log_id,
        date_key,
        log_timestamp,
        country,
        city,
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
        source.date_key,
        source.log_timestamp,
        source.country,
        source.city,
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

--COMMIT;

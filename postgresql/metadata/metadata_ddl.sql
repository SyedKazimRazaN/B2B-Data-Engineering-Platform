/*
===============================================================================
SCHEMA: metadata
===============================================================================

Purpose
-------
The Metadata schema stores operational information required to control,
monitor, and audit data pipelines.

These tables are not business data. They are shared infrastructure used by
the ingestion and transformation pipelines.

Objects
-------
1. pipeline_watermarks
   Stores the last successfully processed source timestamp for incremental
   extraction.

2. pipeline_run_log
   Stores pipeline-level execution history, row counts, watermark usage,
   status, and error information.

Design principles
-----------------
- Metadata is separated from staging, Intermediate, and Warehouse data.
- Watermarks advance only after a successful extraction/load operation.
- Pipeline runs are recorded independently from business tables.
- The same metadata framework can be reused by multiple pipeline layers.
===============================================================================
*/


-- ============================================================================
-- Schema initialization
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS metadata
    AUTHORIZATION postgres;


-- ============================================================================
-- Pipeline Watermarks
-- ============================================================================
-- Stores the last successfully processed source timestamp for each
-- incremental pipeline.
--
-- Example:
--     pipeline_name      | last_extracted_at
--     -------------------+-------------------
--     sql_server_orders  | 2026-08-10 14:35:00
--
-- A watermark should only advance when the corresponding pipeline run
-- successfully extracts and loads the intended data.
-- ============================================================================

CREATE TABLE metadata.pipeline_watermarks (
    pipeline_name       VARCHAR(100) PRIMARY KEY,
    last_extracted_at   TIMESTAMP
);


-- ============================================================================
-- Pipeline Run Log
-- ============================================================================
-- Stores one record for each pipeline execution.
--
-- The table provides operational visibility into:
--   - When a pipeline started and ended
--   - How many rows were extracted
--   - How many rows were loaded
--   - Which watermark was used
--   - Whether the run succeeded or failed
--   - Error details when applicable
-- ============================================================================

CREATE TABLE metadata.pipeline_run_log (
    run_id           CHAR(32) PRIMARY KEY,
    pipeline_name    VARCHAR(100) NOT NULL,
    run_started_at   TIMESTAMP NOT NULL,
    run_ended_at     TIMESTAMP,
    rows_extracted   INT,
    rows_loaded      INT,
    watermark_used   TIMESTAMP,
    status           VARCHAR(20),
    error_message    TEXT,

	CONSTRAINT ck_pipeline_run_log_status
    	CHECK (
       	 	status IN ('running', 'completed', 'failed')
    		),

    CONSTRAINT ck_pipeline_run_log_row_counts
        CHECK (
            (rows_extracted IS NULL OR rows_extracted >= 0)
            AND
            (rows_loaded IS NULL OR rows_loaded >= 0)
        ),

    CONSTRAINT ck_pipeline_run_log_timestamps
        CHECK (
            run_ended_at IS NULL
            OR run_ended_at >= run_started_at
        )
);


-- ============================================================================
-- End of Metadata DDL
-- ============================================================================


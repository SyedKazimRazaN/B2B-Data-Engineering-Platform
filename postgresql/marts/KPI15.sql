/*
Data Quality & Pipeline Health
Pipeline Execution Metrics
    Load times, error rates, data freshness; CDC watermark lag
*/

WITH pipeline_runs AS (
    SELECT
        pipeline_name,
        AVG(run_ended_at - run_started_at) AS avg_load_time,
		COUNT(*) FILTER (WHERE status = 'completed') * 100.0 / NULLIF(COUNT(*), 0) AS success_rate,
        COUNT(*) FILTER (WHERE status = 'failed') * 100.0 / NULLIF(COUNT(*), 0) AS error_rate,
        MAX(run_ended_at) AS last_run_ended_at
    FROM metadata.pipeline_run_log
    WHERE run_ended_at IS NOT NULL
    GROUP BY pipeline_name
),
-- pipeline_watermarks only tracks per-table CDC cursors for sql_server_pipeline
-- (e.g. 'sql_server_orders', 'sql_server_customers'), never the 5 pipeline-level
-- names used in pipeline_run_log, so a direct name join never matches anything.
sql_server_watermark AS (
    SELECT MIN(last_extracted_at) AS oldest_watermark
    FROM metadata.pipeline_watermarks
)
-- avg_load_time/data_freshness/watermark_lag are exposed as numeric seconds
-- (EXTRACT(EPOCH ...)), not raw INTERVAL — Power BI's PostgreSQL connector does
-- not reliably import interval values into a double column.
SELECT
    r.pipeline_name,
    EXTRACT(EPOCH FROM r.avg_load_time) AS avg_load_time,
	ROUND(r.error_rate, 2) AS error_rate,
    ROUND(r.success_rate, 2) AS success_rate,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - r.last_run_ended_at)) AS data_freshness,
    CASE
        WHEN r.pipeline_name = 'sql_server_pipeline' THEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - w.oldest_watermark))
        ELSE EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - r.last_run_ended_at))
    END AS watermark_lag
FROM pipeline_runs r
CROSS JOIN sql_server_watermark w
ORDER BY r.pipeline_name;

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
        COUNT(*) FILTER (WHERE status = 'failed') * 100.0 / NULLIF(COUNT(*), 0) AS error_rate
    FROM metadata.pipeline_run_log
    WHERE run_ended_at IS NOT NULL
    GROUP BY pipeline_name
)
SELECT
    r.pipeline_name,
    r.avg_load_time,
	ROUND(r.error_rate, 2) AS error_rate,
    ROUND(r.success_rate, 2) AS success_rate,
    CURRENT_TIMESTAMP - w.last_extracted_at AS data_freshness,
    CURRENT_TIMESTAMP - w.last_extracted_at AS watermark_lag
FROM pipeline_runs r
LEFT JOIN metadata.pipeline_watermarks w
    ON w.pipeline_name = r.pipeline_name
ORDER BY r.pipeline_name;
	

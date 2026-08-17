/*
Web Activity Quality
	Error rates (4xx/5xx) by endpoint; identify problematic pages
*/

WITH errors AS (
    SELECT
        request_path,
        COUNT(*) AS total_requests,
        SUM(CASE WHEN status_code BETWEEN 400 AND 499 THEN 1 ELSE 0 END) AS error_4xx,
        SUM(CASE WHEN status_code BETWEEN 500 AND 599 THEN 1 ELSE 0 END) AS error_5xx
    FROM warehouse.fact_web_logs
    GROUP BY request_path
)
SELECT
    request_path,
    total_requests,
    error_4xx,
    error_5xx,
    ROUND(100.0 * (error_4xx + error_5xx) / total_requests, 2) AS error_rate_pct
FROM errors
ORDER BY error_rate_pct DESC;

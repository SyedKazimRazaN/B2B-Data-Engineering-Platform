/*
Traffic by Device Type 
	Desktop/Mobile/Tablet breakdown; device-specific conversion metrics
*/

WITH sessions AS (
    SELECT
        session_id,
		device_type,
        BOOL_OR(request_path = '/checkout') AS reached_checkout
    FROM warehouse.fact_web_logs
    WHERE is_bot = FALSE
    GROUP BY session_id,device_type
)
SELECT
    device_type,
    COUNT(*) AS total_sessions,
    SUM(CASE WHEN reached_checkout THEN 1 ELSE 0 END) AS converted_sessions,
	ROUND(100.0 * AVG(reached_checkout::int), 2) AS conversion_rate_pct
FROM sessions
GROUP BY device_type
ORDER BY conversion_rate_pct DESC;


	
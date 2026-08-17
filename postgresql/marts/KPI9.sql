/*
•	Geographic Web Traffic
o	Web sessions by country/IP geolocation; identify top traffic sources
*/


WITH location_traffic AS (
    SELECT 
        country, 
        referer,
		city,
        COUNT(DISTINCT session_id) AS total_sessions
    FROM warehouse.fact_web_logs
    WHERE is_bot = FALSE
    GROUP BY country, city, referer
),
ranked_locations AS (
    SELECT 
        country,
		city,
        referer, 
        total_sessions,
        RANK() OVER(PARTITION BY country, city ORDER BY total_sessions DESC) as rnk
    FROM location_traffic
)
SELECT 
    country, 
	city,
	referer, 
    total_sessions,
    CASE WHEN rnk = 1 THEN 'Top Traffic Source' ELSE 'Other Traffic Sources' END AS traffic_source_rank
FROM ranked_locations
ORDER BY country, total_sessions DESC;

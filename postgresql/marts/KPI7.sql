
/*
•	Geographic Sales
Revenue and order count by country/city; identify growth regions
*/
/*
Geographic Sales
Revenue and order count by country/city; identify growth regions
*/

WITH cte AS (
    SELECT 
        com.country,
        com.city,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COALESCE(SUM(oi.line_total), 0) AS revenue_by_location,
        ROW_NUMBER() OVER(PARTITION BY com.country ORDER BY SUM(oi.line_total) DESC) AS rnk
    FROM warehouse.fact_order_items oi
    JOIN warehouse.dim_companies com
        ON com.company_key = oi.company_key
    WHERE oi.order_status <> 'Cancelled'
    GROUP BY
        com.country,
        com.city
)
SELECT
    country,
    city,
    total_orders,
    revenue_by_location,
    CASE
        WHEN rnk = 1 THEN 'Growth Region'
        ELSE 'Remaining'
    END AS performance
FROM cte
ORDER BY 
	country,
	revenue_by_location DESC;

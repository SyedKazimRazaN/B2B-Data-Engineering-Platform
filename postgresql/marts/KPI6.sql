/*
Customer Activity 
	Orders per customer, average order value (AOV), repeat purchase rate

	AOV = total order value ÷ number of orders
	Repeat Purchase Rate = Repeat Customers / Active Customers
*/
WITH customer_activity AS (
    SELECT
        customer_key,
        COUNT(*) AS total_orders,
        ROUND(SUM(order_total) / COUNT(*), 2) AS average_order_value,
        CASE
            WHEN COUNT(*) > 1 THEN 'Repeat Customer'
            ELSE 'One-time Customer'
        END AS customer_status
    FROM warehouse.fact_orders
    WHERE order_status <> 'Cancelled'
    GROUP BY customer_key
),
customer_summary AS (
    SELECT
        COUNT(*) AS active_customers,
        COUNT(CASE WHEN total_orders > 1 THEN 1 END) AS repeat_customers
    FROM customer_activity
)
SELECT
    ca.customer_key,
    ca.total_orders,
    ca.average_order_value,
    ca.customer_status,
    ROUND(100.0 * cs.repeat_customers / cs.active_customers,2) AS repeat_purchase_rate_pct
FROM customer_activity ca
CROSS JOIN customer_summary cs
ORDER BY ca.total_orders DESC;










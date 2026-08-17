/*
Supplier Revenue 
	Orders and revenue by supplier; supplier concentration (% from top N)
*/


WITH supplier_revenue AS (
    SELECT
		s.supplier_id,
        s.supplier_name,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        SUM(oi.line_total) AS total_revenue
    FROM warehouse.fact_order_items oi
    JOIN warehouse.dim_suppliers s
        ON s.supplier_key = oi.supplier_key
    WHERE oi.order_status <> 'Cancelled'
    GROUP BY 
		s.supplier_name,
		s.supplier_id
)
SELECT
	supplier_id,
    supplier_name,
    total_orders,
    total_revenue,
    ROUND(100.0 * total_revenue / SUM(total_revenue) OVER (), 2) AS revenue_share_pct,
	ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS supplier_rank
FROM supplier_revenue
ORDER BY total_revenue DESC;


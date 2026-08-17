/*
Supplier-Product Performance 
	Which supplier-product combinations perform best
*/
WITH supplier_product AS (
    SELECT
        s.supplier_name,
        p.product_name,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        SUM(oi.quantity) AS total_quantity,
        SUM(oi.line_total) AS total_revenue
    FROM warehouse.fact_order_items oi
    JOIN warehouse.dim_suppliers s
        ON s.supplier_key = oi.supplier_key
    JOIN warehouse.dim_products p
        ON p.product_key = oi.product_key
    WHERE oi.order_status <> 'Cancelled'
    GROUP BY
        s.supplier_name,
        p.product_name
)
SELECT
    supplier_name,
    product_name,
    total_orders,
    total_quantity,
    total_revenue
FROM supplier_product
ORDER BY total_revenue DESC;


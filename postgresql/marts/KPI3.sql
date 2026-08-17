/*
Revenue by Product/Category 	
	Product performance; identify slow-movers and bestsellers
*/

with revenue_by_products as (
	SELECT
		product_id,
		p.category_name,
		p.product_name,
		COALESCE(SUM(oi.line_total), 0) AS net_revenue
	FROM warehouse.dim_products p
	LEFT JOIN warehouse.fact_order_items oi
	ON oi.product_key = p.product_key
	AND oi.order_status <> 'Cancelled'
	GROUP BY
		p.product_id,
		p.product_name,
		p.category_name
)
, product_ranking as (
	SELECT 
		product_id,
		category_name,
		product_name,
		net_revenue,
		ROW_NUMBER() OVER(ORDER BY net_revenue DESC) as product_rank,
		COUNT(*) OVER() AS total_products
	FROM revenue_by_products
)
SELECT 
	product_id,
	category_name,
	product_name,
	net_revenue,
	product_rank,
	CASE
		WHEN product_rank::NUMERIC / total_products <= 0.30
			THEN 'Best Sellers'
		WHEN product_rank::NUMERIC / total_products <= 0.70
            THEN 'Average'
		ELSE 'Slow Movers'
	END AS Performance
FROM product_ranking
ORDER BY product_rank;



	
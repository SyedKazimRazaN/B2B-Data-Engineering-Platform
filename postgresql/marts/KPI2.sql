/*
Revenue by Company 
	Top buyer companies by revenue; identify top 20% of customers (Pareto analysis)
*/

with revenue_by_companies as (
	SELECT
		company_name,
		COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS gross_revenue
	FROM warehouse.fact_order_items oi
	JOIN warehouse.dim_companies com
	ON oi.company_key = com.company_key
    WHERE com.company_type = 'Buyer'
      AND oi.order_status <> 'Cancelled'	
	GROUP BY 
		company_id,
		company_name
)
, rank_companies AS (
	SELECT 
		company_name,
		gross_revenue,
		ROW_NUMBER() OVER(ORDER BY gross_revenue DESC) as company_rank,
        COUNT(*) OVER () AS total_companies,
        SUM(gross_revenue) OVER (ORDER BY gross_revenue DESC) AS cumulative_revenue,
        SUM(gross_revenue) OVER () AS total_revenue
	FROM revenue_by_companies
)
SELECT 
	company_name,
	gross_revenue,
	company_rank,
	ROUND(cumulative_revenue / NULLIF(total_revenue, 0) * 100, 2) AS cumulative_revenue_pct,
	CASE
		WHEN company_rank::NUMERIC / total_companies <= 0.20
			THEN 'Top 20%'
		ELSE 'Remaining 80%'
	END AS Performance
FROM rank_companies

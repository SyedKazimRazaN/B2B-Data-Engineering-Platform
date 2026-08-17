/*
Monthly Revenue Trend 
	 Gross and net revenue (excluding cancelled orders) by month with MoM growth %
*/



with revenue as (
SELECT
	d.year,
	d.month_num,
	d.month_name,
	COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS gross_revenue,
	COALESCE(SUM(oi.line_total), 0) AS net_revenue
FROM warehouse.dim_date d
LEFT JOIN warehouse.fact_order_items oi
ON oi.date_key = d.date_key
AND oi.order_status <> 'Cancelled'
GROUP BY 
	d.year,
	d.month_num,
	d.month_name
)
, revenue_with_previous AS (
	SELECT 
		year,
		month_name,
		month_num,
		gross_revenue,
		net_revenue,
		LAG(net_revenue) OVER (ORDER BY year, month_num) AS previous_net_revenue,
		LAG(gross_revenue) OVER (ORDER BY year, month_num) AS previous_gross_revenue
	FROM revenue r
)
SELECT 
	year,
	month_name,
	gross_revenue,
	net_revenue,
    ROUND(((net_revenue - previous_net_revenue) / NULLIF(previous_net_revenue, 0)) * 100, 2) AS net_mom_pct,
	ROUND(((gross_revenue - previous_gross_revenue) / NULLIF(previous_gross_revenue, 0)) * 100, 2) AS gross_mom_pct
FROM revenue_with_previous
ORDER BY 
    year,
    month_num;

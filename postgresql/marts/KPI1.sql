/*
Monthly Revenue Trend
	 Gross and net revenue (excluding cancelled orders) by month with MoM growth %

	 Only complete months: the current month is still running, the first month of
	 the 2-year window is partial and dim_date runs 6 months into the future.
	 month_num / month_start let Power BI sort the axis by date.
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
WHERE d.full_date <  DATE_TRUNC('month', CURRENT_DATE)                        -- before the current month
  AND d.full_date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '23 months'  -- last 23 full months
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
	ROUND(((gross_revenue - previous_gross_revenue) / NULLIF(previous_gross_revenue, 0)) * 100, 2) AS gross_mom_pct,
	month_num,
	MAKE_DATE(year, month_num, 1) AS month_start
FROM revenue_with_previous
ORDER BY
    year,
    month_num;

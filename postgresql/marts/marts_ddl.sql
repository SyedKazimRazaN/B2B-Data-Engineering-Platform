/*
===============================================================================
SCHEMA: marts
===============================================================================

Purpose
-------
The Marts schema exposes the 15 KPI views for business reporting and Power BI
consumption. Each view wraps the query logic authored in the corresponding
postgresql/marts/KPI<N>.sql file — those files remain the readable, standalone
source of each KPI's SQL (and double as query examples for documentation);
this file is what actually registers them as queryable database objects.

Design principles
------------------
1. Plain views, not materialized — data volume is small and Power BI needs
   always-current results with no separate refresh step to orchestrate.
2. Views read only from `warehouse` and `metadata` (KPI 15), never reach back
   into `intermediate` or `staging`.
3. Naming: vw_<business_name>, ordered below to match the requirements doc's
   KPI grouping (Sales & Revenue, Customer Intelligence, Web & Traffic,
   Lead Quality & Funnel, Supplier Performance, Pipeline Health).
===============================================================================
*/

CREATE SCHEMA IF NOT EXISTS marts
    AUTHORIZATION postgres;


-- ============================================================================
-- KPI 1: Monthly Revenue Trend
-- Gross and net revenue (excluding cancelled orders) by month with MoM growth %
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_monthly_revenue_trend AS
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


-- ============================================================================
-- KPI 2: Revenue by Company
-- Top buyer companies by revenue; identify top 20% of customers (Pareto analysis)
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_revenue_by_company AS
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
	END AS performance
FROM rank_companies;


-- ============================================================================
-- KPI 3: Revenue by Product/Category
-- Product performance; identify slow-movers and bestsellers
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_revenue_by_product AS
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
	END AS performance
FROM product_ranking
ORDER BY product_rank;


-- ============================================================================
-- KPI 4: Gross Margin Analysis
-- Margin % per product/supplier; compare catalog price vs actual selling price
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_gross_margin_analysis AS
WITH supplier_product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        s.supplier_id,
        s.supplier_name,
        p.catalog_price,
        sp.supplier_price,
        oi.quantity,
        oi.line_total
    FROM warehouse.fact_order_items oi
    JOIN warehouse.dim_products p
        ON p.product_key = oi.product_key
    JOIN warehouse.dim_supplier_product sp
        ON sp.product_key = oi.product_key
       AND sp.supplier_key = oi.supplier_key
    JOIN warehouse.dim_suppliers s
        ON s.supplier_key = sp.supplier_key
    WHERE oi.order_status <> 'Cancelled'
)
SELECT
    product_name,
    supplier_name,
    catalog_price,
    ROUND(SUM(line_total) / NULLIF(SUM(quantity), 0), 2) AS actual_selling_price,
    supplier_price,
    SUM(line_total) - SUM(quantity * supplier_price) AS gross_profit,
    ROUND(((SUM(line_total) - SUM(quantity * supplier_price)) / NULLIF(SUM(line_total), 0)) * 100, 2) AS gross_margin_pct
FROM supplier_product_sales
GROUP BY
    product_id,
    product_name,
    supplier_id,
    supplier_name,
    catalog_price,
    supplier_price
ORDER BY
    product_name,
    supplier_name;


-- ============================================================================
-- KPI 5: Customer Lifetime Value
-- Total spend per buyer company; segment into cohorts
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_customer_lifetime_value AS
WITH company_first_order AS (
    SELECT d.company_id, MIN(fo.order_date_time) AS first_order_date
    FROM warehouse.fact_orders fo
    JOIN warehouse.dim_companies d ON d.company_key = fo.company_key
    GROUP BY d.company_id
),
company_spend AS (
    SELECT
        d.company_id,
        SUM(oi.line_total) AS total_spend,
        COUNT(DISTINCT oi.order_id) AS total_orders
    FROM warehouse.fact_order_items oi
    JOIN warehouse.dim_companies d ON d.company_key = oi.company_key
    WHERE oi.order_status <> 'Cancelled'
      AND d.company_type = 'Buyer'
    GROUP BY d.company_id
),
company_current AS (
    SELECT company_id, company_name, country
    FROM warehouse.dim_companies
    WHERE is_current = TRUE
)
SELECT
    cc.company_name,
    cc.country,
    cs.total_orders,
    cs.total_spend,
    TO_CHAR(fo.first_order_date, 'YYYY-MM') AS acquisition_cohort
FROM company_spend cs
JOIN company_first_order fo ON fo.company_id = cs.company_id
JOIN company_current  cc ON cc.company_id = cs.company_id
ORDER BY cs.total_spend DESC;


-- ============================================================================
-- KPI 6: Customer Activity
-- Orders per customer, average order value (AOV), repeat purchase rate
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_customer_activity AS
WITH customer_activity AS (
    SELECT
        fo.customer_key,
        dc.country,
        COUNT(*) AS total_orders,
        ROUND(SUM(fo.order_total) / COUNT(*), 2) AS average_order_value,
        CASE
            WHEN COUNT(*) > 1 THEN 'Repeat Customer'
            ELSE 'One-time Customer'
        END AS customer_status
    FROM warehouse.fact_orders fo
    LEFT JOIN warehouse.dim_companies dc
        ON fo.company_key = dc.company_key AND dc.is_current = true
    WHERE fo.order_status <> 'Cancelled'
    GROUP BY fo.customer_key, dc.country
),
customer_summary AS (
    SELECT
        COUNT(*) AS active_customers,
        COUNT(CASE WHEN total_orders > 1 THEN 1 END) AS repeat_customers
    FROM customer_activity
)
SELECT
    ca.customer_key,
    ca.country,
    ca.total_orders,
    ca.average_order_value,
    ca.customer_status,
    ROUND(100.0 * cs.repeat_customers / cs.active_customers,2) AS repeat_purchase_rate_pct
FROM customer_activity ca
CROSS JOIN customer_summary cs
ORDER BY ca.total_orders DESC;


-- ============================================================================
-- KPI 7: Geographic Sales
-- Revenue and order count by country/city; identify growth regions
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_geographic_sales AS
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


-- ============================================================================
-- KPI 8: Traffic by Device Type
-- Desktop/Mobile/Tablet breakdown; device-specific conversion metrics
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_traffic_by_device AS
WITH sessions AS (
    SELECT
        session_id,
		device_type,
        BOOL_OR(request_path = '/checkout') AS reached_checkout
    FROM warehouse.fact_web_logs
    WHERE is_bot = FALSE
    GROUP BY session_id, device_type
)
SELECT
    device_type,
    COUNT(*) AS total_sessions,
    SUM(CASE WHEN reached_checkout THEN 1 ELSE 0 END) AS converted_sessions,
	ROUND(100.0 * AVG(reached_checkout::int), 2) AS conversion_rate_pct
FROM sessions
GROUP BY device_type
ORDER BY conversion_rate_pct DESC;


-- ============================================================================
-- KPI 9: Geographic Web Traffic
-- Web sessions by country/IP geolocation; identify top traffic sources
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_geographic_web_traffic AS
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


-- ============================================================================
-- KPI 10: Web Activity Quality
-- Error rates (4xx/5xx) by endpoint; identify problematic pages
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_web_activity_quality AS
WITH errors AS (
    SELECT
        request_path,
        COUNT(*) AS total_requests,
        SUM(CASE WHEN status_code BETWEEN 400 AND 499 THEN 1 ELSE 0 END) AS error_4xx,
        SUM(CASE WHEN status_code BETWEEN 500 AND 599 THEN 1 ELSE 0 END) AS error_5xx
    FROM warehouse.fact_web_logs
    GROUP BY request_path
)
SELECT
    request_path,
    total_requests,
    error_4xx,
    error_5xx,
    ROUND(100.0 * (error_4xx + error_5xx) / total_requests, 2) AS error_rate_pct
FROM errors
ORDER BY error_rate_pct DESC;


-- ============================================================================
-- KPI 11: Lead Conversion Funnel
-- Lead source -> orders; conversion rates by campaign/channel
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_lead_conversion_funnel AS
WITH lead_funnel AS (
    SELECT
        source,
        campaign_name,
        utm_source,
        utm_medium,
        COUNT(*) AS total_leads,
        COUNT(*) FILTER (WHERE funnel_stage = 'Qualified') AS qualified_leads,
        COUNT(*) FILTER (WHERE conversion_status = 'Converted') AS converted_leads,
		COUNT(DISTINCT order_id) AS orders
    FROM warehouse.fact_leads
    GROUP BY
        source,
        campaign_name,
        utm_source,
        utm_medium
)
SELECT
    source,
    campaign_name,
    utm_source,
    utm_medium,
    total_leads,
    qualified_leads,
    converted_leads,
    orders,
    ROUND(100.0 * converted_leads/ NULLIF(total_leads, 0), 2) AS lead_conversion_rate_pct
FROM lead_funnel
ORDER BY
    lead_conversion_rate_pct DESC,
    total_leads DESC;


-- ============================================================================
-- KPI 12: Lead Quality vs Order Value
-- Correlation between lead score and actual order value
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_lead_quality_vs_order_value AS
SELECT
    COUNT(*) AS converted_leads,
    ROUND(CORR(l.lead_score, o.order_total)::NUMERIC, 4) AS lead_score_order_value_correlation
FROM warehouse.fact_leads l
JOIN warehouse.fact_orders o
    ON o.lead_id = l.lead_id
WHERE l.conversion_status = 'Converted'
  AND o.order_status <> 'Cancelled';


-- ============================================================================
-- KPI 13: Supplier Revenue
-- Orders and revenue by supplier; supplier concentration (% from top N)
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_supplier_revenue AS
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


-- ============================================================================
-- KPI 14: Supplier-Product Performance
-- Which supplier-product combinations perform best
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_supplier_product_performance AS
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


-- ============================================================================
-- KPI 15: Pipeline Execution Metrics
-- Load times, error rates, data freshness; CDC watermark lag
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_pipeline_execution_metrics AS
WITH pipeline_runs AS (
    SELECT
        pipeline_name,
        AVG(run_ended_at - run_started_at) AS avg_load_time,
		COUNT(*) FILTER (WHERE status = 'completed') * 100.0 / NULLIF(COUNT(*), 0) AS success_rate,
        COUNT(*) FILTER (WHERE status = 'failed') * 100.0 / NULLIF(COUNT(*), 0) AS error_rate,
        MAX(run_ended_at) AS last_run_ended_at
    FROM metadata.pipeline_run_log
    WHERE run_ended_at IS NOT NULL
    GROUP BY pipeline_name
),
-- pipeline_watermarks only tracks per-table CDC cursors for sql_server_pipeline
-- (e.g. 'sql_server_orders', 'sql_server_customers'), never the 5 pipeline-level
-- names used in pipeline_run_log, so a direct name join never matches anything.
sql_server_watermark AS (
    SELECT MIN(last_extracted_at) AS oldest_watermark
    FROM metadata.pipeline_watermarks
)
-- avg_load_time/data_freshness/watermark_lag are exposed as numeric seconds
-- (EXTRACT(EPOCH ...)), not raw INTERVAL — Power BI's PostgreSQL connector does
-- not reliably import interval values into a double column (they silently come
-- through as 0 or blank), so the model-declared "double" type needs real numbers.
SELECT
    r.pipeline_name,
    EXTRACT(EPOCH FROM r.avg_load_time) AS avg_load_time,
	ROUND(r.error_rate, 2) AS error_rate,
    ROUND(r.success_rate, 2) AS success_rate,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - r.last_run_ended_at)) AS data_freshness,
    CASE
        WHEN r.pipeline_name = 'sql_server_pipeline' THEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - w.oldest_watermark))
        ELSE EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - r.last_run_ended_at))
    END AS watermark_lag
FROM pipeline_runs r
CROSS JOIN sql_server_watermark w
ORDER BY r.pipeline_name;


-- ============================================================================
-- KPI 16: Pipeline Run History
-- One row per pipeline run, duration exposed as numeric seconds (not interval)
-- so Power BI can aggregate/chart it directly.
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_pipeline_run_history AS
SELECT
    run_id,
    pipeline_name,
    run_started_at AS run_timestamp,
    status,
    rows_extracted,
    rows_loaded,
    EXTRACT(EPOCH FROM (run_ended_at - run_started_at)) AS duration_seconds,
    error_message
FROM metadata.pipeline_run_log
ORDER BY run_started_at DESC;


-- ============================================================================
-- KPI 17: Pipeline Latest Run
-- Most recent run per pipeline, for a "current status by pipeline" view.
-- ============================================================================
CREATE OR REPLACE VIEW marts.vw_pipeline_latest_run AS
SELECT DISTINCT ON (pipeline_name)
    pipeline_name,
    status,
    EXTRACT(EPOCH FROM (run_ended_at - run_started_at)) AS duration_seconds,
    error_message,
    run_started_at AS run_timestamp
FROM metadata.pipeline_run_log
ORDER BY pipeline_name, run_started_at DESC;


-- ============================================================================
-- End of Marts DDL
-- ============================================================================
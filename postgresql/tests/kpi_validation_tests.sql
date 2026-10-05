-- ============================================================
-- FILE: kpi_validation_tests.sql
-- PURPOSE:
-- KPI validation (KV-01 .. KV-15): each KPI view is recalculated
-- directly from the warehouse fact tables and compared.

-- EXPECTATION:
-- Each test should return ZERO rows (a row = view and recalculation differ).
-- ============================================================

-- ============================================================
-- KV-01: MONTHLY REVENUE TREND
-- sum of the view = non-cancelled revenue of the same complete months
-- ============================================================

SELECT view_total, recalculated_total
FROM (
    SELECT
        (SELECT SUM(net_revenue) FROM marts.vw_monthly_revenue_trend) AS view_total,
        (SELECT SUM(oi.line_total)
         FROM warehouse.fact_order_items oi
         JOIN warehouse.dim_date d ON d.date_key = oi.date_key
         WHERE oi.order_status <> 'Cancelled'
           AND d.full_date <  DATE_TRUNC('month', CURRENT_DATE)
           AND d.full_date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '23 months') AS recalculated_total
) t
WHERE view_total <> recalculated_total;


-- ============================================================
-- KV-02: REVENUE BY COMPANY
-- gross revenue = SUM(quantity x unit_price) of buyer, non-cancelled lines
-- ============================================================

SELECT view_total, recalculated_total
FROM (
    SELECT
        (SELECT SUM(gross_revenue) FROM marts.vw_revenue_by_company) AS view_total,
        (SELECT SUM(oi.quantity * oi.unit_price)
         FROM warehouse.fact_order_items oi
         JOIN warehouse.dim_companies c ON c.company_key = oi.company_key
         WHERE c.company_type = 'Buyer' AND oi.order_status <> 'Cancelled') AS recalculated_total
) t
WHERE view_total <> recalculated_total;


-- ============================================================
-- KV-03 / KV-07 / KV-13 / KV-14: REVENUE SPLITS ADD UP TO TOTAL NET REVENUE
-- (by product, by location, by supplier, by supplier-product)
-- ============================================================

SELECT kpi, view_total, total_net_revenue
FROM (
    SELECT 'KV-03 revenue by product' AS kpi, (SELECT SUM(net_revenue) FROM marts.vw_revenue_by_product) AS view_total
    UNION ALL SELECT 'KV-07 geographic sales', (SELECT SUM(revenue_by_location) FROM marts.vw_geographic_sales)
    UNION ALL SELECT 'KV-13 supplier revenue', (SELECT SUM(total_revenue) FROM marts.vw_supplier_revenue)
    UNION ALL SELECT 'KV-14 supplier-product', (SELECT SUM(total_revenue) FROM marts.vw_supplier_product_performance)
) v
CROSS JOIN (
    SELECT SUM(line_total) AS total_net_revenue
    FROM warehouse.fact_order_items
    WHERE order_status <> 'Cancelled'
) t
WHERE view_total <> total_net_revenue;

-- KV-13: supplier revenue shares add up to 100 %
SELECT ROUND(SUM(revenue_share_pct)) AS total_share_pct
FROM marts.vw_supplier_revenue
HAVING ROUND(SUM(revenue_share_pct)) <> 100;


-- ============================================================
-- KV-04: GROSS MARGIN
-- gross profit = SUM(line_total - quantity x supplier_price)
-- ============================================================

SELECT view_total, recalculated_total
FROM (
    SELECT
        (SELECT SUM(gross_profit) FROM marts.vw_gross_margin_analysis) AS view_total,
        (SELECT SUM(oi.line_total - oi.quantity * sp.supplier_price)
         FROM warehouse.fact_order_items oi
         JOIN warehouse.dim_supplier_product sp
             ON sp.product_key = oi.product_key AND sp.supplier_key = oi.supplier_key
         WHERE oi.order_status <> 'Cancelled') AS recalculated_total
) t
WHERE view_total <> recalculated_total;


-- ============================================================
-- KV-05: CUSTOMER LIFETIME VALUE
-- total spend = net revenue of buyer companies
-- ============================================================

SELECT view_total, recalculated_total
FROM (
    SELECT
        (SELECT SUM(total_spend) FROM marts.vw_customer_lifetime_value) AS view_total,
        (SELECT SUM(oi.line_total)
         FROM warehouse.fact_order_items oi
         JOIN warehouse.dim_companies c ON c.company_key = oi.company_key
         WHERE c.company_type = 'Buyer' AND oi.order_status <> 'Cancelled') AS recalculated_total
) t
WHERE view_total <> recalculated_total;


-- ============================================================
-- KV-06: REPEAT PURCHASE RATE
-- customers with more than 1 order / customers with at least 1 order
-- ============================================================

SELECT view_rate, recalculated_rate
FROM (
    SELECT
        (SELECT MAX(repeat_purchase_rate_pct) FROM marts.vw_customer_activity) AS view_rate,
        (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE orders > 1) / COUNT(*), 2)
         FROM (SELECT customer_key, COUNT(*) AS orders
               FROM warehouse.fact_orders
               WHERE order_status <> 'Cancelled'
               GROUP BY customer_key) c) AS recalculated_rate
) t
WHERE view_rate <> recalculated_rate;

-- KV-06: no customer without a country
SELECT customer_key
FROM marts.vw_customer_activity
WHERE country IS NULL;


-- ============================================================
-- KV-08: TRAFFIC BY DEVICE
-- sessions = distinct (session, device) of non-bot requests
-- ============================================================

SELECT view_total, recalculated_total
FROM (
    SELECT
        (SELECT SUM(total_sessions) FROM marts.vw_traffic_by_device) AS view_total,
        (SELECT COUNT(*) FROM (SELECT DISTINCT session_id, device_type
                               FROM warehouse.fact_web_logs
                               WHERE is_bot = FALSE) s) AS recalculated_total
) t
WHERE view_total <> recalculated_total;


-- ============================================================
-- KV-09: GEOGRAPHIC WEB TRAFFIC
-- countries in the view = countries in non-bot web logs
-- ============================================================

SELECT view_countries, recalculated_countries
FROM (
    SELECT
        (SELECT COUNT(DISTINCT country) FROM marts.vw_geographic_web_traffic) AS view_countries,
        (SELECT COUNT(DISTINCT country) FROM warehouse.fact_web_logs WHERE is_bot = FALSE) AS recalculated_countries
) t
WHERE view_countries <> recalculated_countries;


-- ============================================================
-- KV-10: WEB ACTIVITY QUALITY
-- requests = all web-log rows; errors = status 400-599
-- ============================================================

SELECT view_requests, recalculated_requests, view_errors, recalculated_errors
FROM (
    SELECT
        (SELECT SUM(total_requests) FROM marts.vw_web_activity_quality) AS view_requests,
        (SELECT COUNT(*) FROM warehouse.fact_web_logs) AS recalculated_requests,
        (SELECT SUM(error_4xx + error_5xx) FROM marts.vw_web_activity_quality) AS view_errors,
        (SELECT COUNT(*) FROM warehouse.fact_web_logs WHERE status_code BETWEEN 400 AND 599) AS recalculated_errors
) t
WHERE view_requests <> recalculated_requests
   OR view_errors <> recalculated_errors;


-- ============================================================
-- KV-11: LEAD CONVERSION FUNNEL
-- converted leads = leads with conversion_status 'Converted'
-- ============================================================

SELECT view_total, recalculated_total
FROM (
    SELECT
        (SELECT SUM(converted_leads) FROM marts.vw_lead_conversion_funnel) AS view_total,
        (SELECT COUNT(*) FROM warehouse.fact_leads WHERE conversion_status = 'Converted') AS recalculated_total
) t
WHERE view_total <> recalculated_total;


-- ============================================================
-- KV-12: LEAD QUALITY VS ORDER VALUE
-- converted-lead count = independent join count
-- ============================================================

SELECT view_count, recalculated_count
FROM (
    SELECT
        (SELECT converted_leads FROM marts.vw_lead_quality_vs_order_value) AS view_count,
        (SELECT COUNT(*)
         FROM warehouse.fact_leads l
         JOIN warehouse.fact_orders o ON o.lead_id = l.lead_id
         WHERE l.conversion_status = 'Converted' AND o.order_status <> 'Cancelled') AS recalculated_count
) t
WHERE view_count <> recalculated_count;


-- ============================================================
-- KV-15: PIPELINE EXECUTION METRICS
-- one row per pipeline, data freshness filled
-- ============================================================

SELECT view_rows, pipelines_in_log, rows_with_freshness
FROM (
    SELECT
        (SELECT COUNT(*) FROM marts.vw_pipeline_execution_metrics) AS view_rows,
        (SELECT COUNT(DISTINCT pipeline_name) FROM metadata.pipeline_run_log WHERE run_ended_at IS NOT NULL) AS pipelines_in_log,
        (SELECT COUNT(data_freshness) FROM marts.vw_pipeline_execution_metrics) AS rows_with_freshness
) t
WHERE view_rows <> pipelines_in_log
   OR rows_with_freshness <> view_rows;

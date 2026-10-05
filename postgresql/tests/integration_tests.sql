-- ============================================================
-- FILE: integration_tests.sql
-- PURPOSE:
-- Integration tests across layers (IT-01 .. IT-10).
-- Run after a pipeline run (initial or incremental).

-- EXPECTATION:
-- Each test should return ZERO rows.
-- ============================================================

-- ============================================================
-- IT-01: SOURCE -> INTERMEDIATE COMPLETENESS  (manual step)
-- SQL Server and PostgreSQL are different databases, so compare
-- the counts by hand:
--   SQL Server : SELECT COUNT(*) FROM source.Orders;   (same for the other 7 tables)
--   PostgreSQL : SELECT COUNT(*) FROM intermediate.orders;
-- CSV files   : rows in the file = intermediate rows + rejected rows
--   SELECT COUNT(*) FROM intermediate.marketing_leads;
--   SELECT COUNT(*) FROM intermediate.rejected_records WHERE table_name = 'marketing_leads';
--   (same for web_logs; compare the sum with the number of rows in the CSV file)
-- ============================================================


-- ============================================================
-- IT-02: STAGING IS CLEARED AFTER A SUCCESSFUL RUN
-- (clear_staging() only truncates after every row was found in
--  intermediate or rejected_records)
-- ============================================================

SELECT table_name, staging_rows
FROM (
    SELECT 'companies' AS table_name, COUNT(*) AS staging_rows FROM staging.companies
    UNION ALL SELECT 'categories', COUNT(*) FROM staging.categories
    UNION ALL SELECT 'customers', COUNT(*) FROM staging.customers
    UNION ALL SELECT 'suppliers', COUNT(*) FROM staging.suppliers
    UNION ALL SELECT 'products', COUNT(*) FROM staging.products
    UNION ALL SELECT 'supplier_product_mapping', COUNT(*) FROM staging.supplier_product_mapping
    UNION ALL SELECT 'orders', COUNT(*) FROM staging.orders
    UNION ALL SELECT 'order_items', COUNT(*) FROM staging.order_items
    UNION ALL SELECT 'marketing_leads', COUNT(*) FROM staging.marketing_leads
    UNION ALL SELECT 'web_logs', COUNT(*) FROM staging.web_logs
) counts
WHERE staging_rows > 0;


-- ============================================================
-- IT-03: INTERMEDIATE -> WAREHOUSE ROW COUNTS
-- 5 dimensions (current rows) + 4 facts must match
-- ============================================================

SELECT table_name, intermediate_rows, warehouse_rows
FROM (
    SELECT 'companies' AS table_name,
           (SELECT COUNT(*) FROM intermediate.companies) AS intermediate_rows,
           (SELECT COUNT(*) FROM warehouse.dim_companies WHERE is_current = TRUE) AS warehouse_rows
    UNION ALL SELECT 'customers', (SELECT COUNT(*) FROM intermediate.customers), (SELECT COUNT(*) FROM warehouse.dim_customers)
    UNION ALL SELECT 'suppliers', (SELECT COUNT(*) FROM intermediate.suppliers), (SELECT COUNT(*) FROM warehouse.dim_suppliers)
    UNION ALL SELECT 'products', (SELECT COUNT(*) FROM intermediate.products), (SELECT COUNT(*) FROM warehouse.dim_products)
    UNION ALL SELECT 'supplier_product_mapping', (SELECT COUNT(*) FROM intermediate.supplier_product_mapping), (SELECT COUNT(*) FROM warehouse.dim_supplier_product)
    UNION ALL SELECT 'orders', (SELECT COUNT(*) FROM intermediate.orders), (SELECT COUNT(*) FROM warehouse.fact_orders)
    UNION ALL SELECT 'order_items', (SELECT COUNT(*) FROM intermediate.order_items), (SELECT COUNT(*) FROM warehouse.fact_order_items)
    UNION ALL SELECT 'web_logs', (SELECT COUNT(*) FROM intermediate.web_logs), (SELECT COUNT(*) FROM warehouse.fact_web_logs)
    UNION ALL SELECT 'marketing_leads', (SELECT COUNT(*) FROM intermediate.marketing_leads), (SELECT COUNT(*) FROM warehouse.fact_leads)
) counts
WHERE intermediate_rows <> warehouse_rows;


-- ============================================================
-- IT-04: CDC WATERMARKS  (manual step)
-- Each watermark should equal the source MAX(updated_at):
--   PostgreSQL : SELECT pipeline_name, last_extracted_at FROM metadata.pipeline_watermarks;
--   SQL Server : SELECT MAX(updated_at) FROM source.Orders;   (same for the other 7 tables)
-- Here we only check that all 8 watermarks exist and are filled.
-- ============================================================

SELECT 'missing or empty watermarks' AS problem, COUNT(*) AS filled_watermarks
FROM metadata.pipeline_watermarks
WHERE last_extracted_at IS NOT NULL
HAVING COUNT(*) <> 8;


-- ============================================================
-- IT-05: SCD TYPE 2 HISTORY
-- a closed version must end exactly when the next version starts
-- ============================================================

SELECT *
FROM (
    SELECT
        company_id,
        company_key,
        is_current,
        effective_end_date,
        LEAD(effective_start_date) OVER (PARTITION BY company_id ORDER BY effective_start_date) AS next_version_start
    FROM warehouse.dim_companies
) versions
WHERE is_current = FALSE
  AND effective_end_date IS DISTINCT FROM next_version_start;

-- one current version per company
SELECT company_id, COUNT(*) FILTER (WHERE is_current = TRUE) AS current_versions
FROM warehouse.dim_companies
GROUP BY company_id
HAVING COUNT(*) FILTER (WHERE is_current = TRUE) <> 1;


-- ============================================================
-- IT-06: POINT-IN-TIME COMPANY LOOKUP
-- every order points to the company version valid on the order date
-- ============================================================

SELECT f.order_id, f.order_date_time, c.effective_start_date, c.effective_end_date
FROM warehouse.fact_orders f
JOIN warehouse.dim_companies c
    ON c.company_key = f.company_key
WHERE f.order_date_time < c.effective_start_date
   OR (c.effective_end_date IS NOT NULL AND f.order_date_time >= c.effective_end_date);


-- ============================================================
-- IT-07: ORDER HEADER VS ORDER LINES
-- order_total = SUM(line_total) and item_count = number of lines
-- ============================================================

SELECT o.order_id, o.order_total, l.lines_total, o.item_count, l.lines_count
FROM warehouse.fact_orders o
JOIN (
    SELECT order_id, SUM(line_total) AS lines_total, COUNT(*) AS lines_count
    FROM warehouse.fact_order_items
    GROUP BY order_id
) l
    ON l.order_id = o.order_id
WHERE ABS(o.order_total - l.lines_total) > 0.01
   OR o.item_count <> l.lines_count;


-- ============================================================
-- IT-08: LEAD TO ORDER LINK (across sources)
-- ============================================================

-- converted leads have an order_id, not-converted leads don't
SELECT lead_id, conversion_status, order_id
FROM warehouse.fact_leads
WHERE (conversion_status = 'Converted' AND order_id IS NULL)
   OR (conversion_status <> 'Converted' AND order_id IS NOT NULL);

-- every order's lead_id exists in fact_leads
SELECT o.order_id, o.lead_id
FROM warehouse.fact_orders o
WHERE o.lead_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM warehouse.fact_leads l WHERE l.lead_id = o.lead_id);


-- ============================================================
-- IT-09: LATEST RUN OF EVERY PIPELINE STAGE COMPLETED
-- ============================================================

SELECT pipeline_name, status, run_started_at
FROM (
    SELECT DISTINCT ON (pipeline_name) pipeline_name, status, run_started_at
    FROM metadata.pipeline_run_log
    ORDER BY pipeline_name, run_started_at DESC
) latest
WHERE status <> 'completed';


-- ============================================================
-- IT-10: IDEMPOTENT RE-RUN  (manual step)
-- 1. Run the counts below and note them.
-- 2. Run: python -m python.pipelines.run_pipeline warehouse
-- 3. Run the counts again: they must be identical (each MERGE changes 0 rows).
-- ============================================================

SELECT 'fact_orders' AS table_name, COUNT(*) AS row_count FROM warehouse.fact_orders
UNION ALL SELECT 'fact_order_items', COUNT(*) FROM warehouse.fact_order_items
UNION ALL SELECT 'fact_leads', COUNT(*) FROM warehouse.fact_leads
UNION ALL SELECT 'fact_web_logs', COUNT(*) FROM warehouse.fact_web_logs;


-- ============================================================
-- SUMMARY: all automatic tests above in one result
-- one row per test, failed_rows must be 0 for every test
-- ============================================================

SELECT 'IT-02 staging cleared' AS test_name,
       (SELECT COUNT(*) FROM staging.orders) + (SELECT COUNT(*) FROM staging.order_items)
     + (SELECT COUNT(*) FROM staging.marketing_leads) + (SELECT COUNT(*) FROM staging.web_logs)
     + (SELECT COUNT(*) FROM staging.companies) + (SELECT COUNT(*) FROM staging.customers)
     + (SELECT COUNT(*) FROM staging.suppliers) + (SELECT COUNT(*) FROM staging.products)
     + (SELECT COUNT(*) FROM staging.categories) + (SELECT COUNT(*) FROM staging.supplier_product_mapping) AS failed_rows

UNION ALL
SELECT 'IT-03 orders: intermediate = warehouse',
       ABS((SELECT COUNT(*) FROM intermediate.orders) - (SELECT COUNT(*) FROM warehouse.fact_orders))

UNION ALL
SELECT 'IT-03 order_items: intermediate = warehouse',
       ABS((SELECT COUNT(*) FROM intermediate.order_items) - (SELECT COUNT(*) FROM warehouse.fact_order_items))

UNION ALL
SELECT 'IT-03 leads: intermediate = warehouse',
       ABS((SELECT COUNT(*) FROM intermediate.marketing_leads) - (SELECT COUNT(*) FROM warehouse.fact_leads))

UNION ALL
SELECT 'IT-03 web_logs: intermediate = warehouse',
       ABS((SELECT COUNT(*) FROM intermediate.web_logs) - (SELECT COUNT(*) FROM warehouse.fact_web_logs))

UNION ALL
SELECT 'IT-03 companies: intermediate = current dim rows',
       ABS((SELECT COUNT(*) FROM intermediate.companies) - (SELECT COUNT(*) FROM warehouse.dim_companies WHERE is_current = TRUE))

UNION ALL
SELECT 'IT-04 watermarks filled (8 expected)',
       8 - (SELECT COUNT(*) FROM metadata.pipeline_watermarks WHERE last_extracted_at IS NOT NULL)

UNION ALL
SELECT 'IT-05 companies without exactly 1 current version',
       (SELECT COUNT(*) FROM (SELECT company_id FROM warehouse.dim_companies
                              GROUP BY company_id
                              HAVING COUNT(*) FILTER (WHERE is_current = TRUE) <> 1) x)

UNION ALL
SELECT 'IT-06 orders linked to wrong company version',
       (SELECT COUNT(*) FROM warehouse.fact_orders f
        JOIN warehouse.dim_companies c ON c.company_key = f.company_key
        WHERE f.order_date_time < c.effective_start_date
           OR (c.effective_end_date IS NOT NULL AND f.order_date_time >= c.effective_end_date))

UNION ALL
SELECT 'IT-07 order total <> sum of lines',
       (SELECT COUNT(*) FROM warehouse.fact_orders o
        JOIN (SELECT order_id, SUM(line_total) AS lines_total, COUNT(*) AS lines_count
              FROM warehouse.fact_order_items GROUP BY order_id) l ON l.order_id = o.order_id
        WHERE ABS(o.order_total - l.lines_total) > 0.01 OR o.item_count <> l.lines_count)

UNION ALL
SELECT 'IT-08 converted lead without order (or opposite)',
       (SELECT COUNT(*) FROM warehouse.fact_leads
        WHERE (conversion_status = 'Converted' AND order_id IS NULL)
           OR (conversion_status <> 'Converted' AND order_id IS NOT NULL))

UNION ALL
SELECT 'IT-09 latest pipeline runs not completed',
       (SELECT COUNT(*) FROM (SELECT DISTINCT ON (pipeline_name) status
                              FROM metadata.pipeline_run_log
                              ORDER BY pipeline_name, run_started_at DESC) latest
        WHERE status <> 'completed');

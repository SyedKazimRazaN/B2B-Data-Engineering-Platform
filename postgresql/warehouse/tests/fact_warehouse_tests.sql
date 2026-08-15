/*
===============================================================================
WAREHOUSE — FINAL VALIDATION TESTS
===============================================================================

Expected result:
    Every test should return 0 rows.

===============================================================================
*/


-- ============================================================================
-- TEST 1: Only one current company version
-- ============================================================================

SELECT company_id
FROM warehouse.dim_companies
WHERE is_current = TRUE
GROUP BY company_id
HAVING COUNT(*) > 1;


-- ============================================================================
-- TEST 2: Company effective dates are valid
-- ============================================================================

SELECT company_id
FROM warehouse.dim_companies
WHERE effective_end_date IS NOT NULL
  AND effective_end_date <= effective_start_date;


-- ============================================================================
-- TEST 3A: Orders → Customers
-- ============================================================================

SELECT f.order_id
FROM warehouse.fact_orders AS f
LEFT JOIN warehouse.dim_customers AS c
    ON c.customer_key = f.customer_key
WHERE c.customer_key IS NULL;


-- ============================================================================
-- TEST 3B: Orders → Companies
-- ============================================================================

SELECT f.order_id
FROM warehouse.fact_orders AS f
LEFT JOIN warehouse.dim_companies AS c
    ON c.company_key = f.company_key
WHERE c.company_key IS NULL;


-- ============================================================================
-- TEST 3C: Order Items → Products
-- ============================================================================

SELECT f.order_item_id
FROM warehouse.fact_order_items AS f
LEFT JOIN warehouse.dim_products AS p
    ON p.product_key = f.product_key
WHERE p.product_key IS NULL;


-- ============================================================================
-- TEST 3D: Order Items → Suppliers
-- ============================================================================

SELECT f.order_item_id
FROM warehouse.fact_order_items AS f
LEFT JOIN warehouse.dim_suppliers AS s
    ON s.supplier_key = f.supplier_key
WHERE s.supplier_key IS NULL;


-- ============================================================================
-- TEST 3E: Web Logs → Date
-- ============================================================================

SELECT f.log_id
FROM warehouse.fact_web_logs AS f
LEFT JOIN warehouse.dim_date AS d
    ON d.date_key = f.date_key
WHERE d.date_key IS NULL;


-- ============================================================================
-- TEST 3F: Leads → Date
-- ============================================================================

SELECT f.lead_id
FROM warehouse.fact_leads AS f
LEFT JOIN warehouse.dim_date AS d
    ON d.date_key = f.date_key
WHERE d.date_key IS NULL;


-- ============================================================================
-- TEST 4: Every order has at least one order item
-- ============================================================================

SELECT o.order_id
FROM warehouse.fact_orders AS o
LEFT JOIN warehouse.fact_order_items AS oi
    ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL;


-- ============================================================================
-- TEST 5: item_count matches actual order items
-- ============================================================================

SELECT o.order_id
FROM warehouse.fact_orders AS o
JOIN warehouse.fact_order_items AS oi
    ON oi.order_id = o.order_id
GROUP BY o.order_id, o.item_count
HAVING o.item_count <> COUNT(*);



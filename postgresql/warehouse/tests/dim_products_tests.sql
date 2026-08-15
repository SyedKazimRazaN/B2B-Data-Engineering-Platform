-- ==========================================================================================================
-- TEST PRODUCTS WAREHOUSE LOAD
-- ==========================================================================================================
-- SCD TYPE:
--     Type 1
--
-- Expected:
--     - Source and warehouse row counts match
--     - No duplicate product_id
--     - Every source product exists in warehouse
--     - Product attributes match source
--     - category_name matches intermediate.categories
--     - No orphan warehouse products
-- ==========================================================================================================


-- ============================================================
-- TEST 1: Source vs Warehouse row count
-- ============================================================

SELECT
    (SELECT COUNT(*)
     FROM intermediate.products) AS source_count,

    (SELECT COUNT(*)
     FROM warehouse.dim_products) AS warehouse_count;




-- ============================================================
-- TEST 2: No duplicate product_id
-- ============================================================

SELECT
    product_id,
    COUNT(*) AS row_count
FROM warehouse.dim_products
GROUP BY product_id
HAVING COUNT(*) > 1;




-- ============================================================
-- TEST 3: Every source product exists in warehouse
-- ============================================================

SELECT
    p.product_id
FROM intermediate.products p
LEFT JOIN warehouse.dim_products d
    ON d.product_id = p.product_id
WHERE d.product_id IS NULL;


-- ============================================================
-- TEST 4: No orphan warehouse products
-- ============================================================

SELECT
    d.product_id
FROM warehouse.dim_products d
LEFT JOIN intermediate.products p
    ON p.product_id = d.product_id
WHERE p.product_id IS NULL;



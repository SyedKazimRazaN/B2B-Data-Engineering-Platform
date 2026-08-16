-- ==========================================================================================================
-- TEST SUPPLIER_PRODUCT WAREHOUSE LOAD
-- ==========================================================================================================
-- SCD TYPE:
--     Type 1
--
-- Expected:
--     - Source and warehouse row counts match
--     - No duplicate supplier_product_id
--     - Every source mapping exists in warehouse
--     - No orphan warehouse mappings
--     - supplier_key/product_key correctly resolve to dim_suppliers/dim_products
--     - supplier_price/lead_time_days/is_preferred_supplier match intermediate
--     - supplier_price and lead_time_days are non-negative
-- ==========================================================================================================


-- ============================================================
-- TEST 1: Source vs Warehouse row count
-- ============================================================

SELECT
    (SELECT COUNT(*)
     FROM intermediate.supplier_product_mapping) AS source_count,

    (SELECT COUNT(*)
     FROM warehouse.dim_supplier_product) AS warehouse_count;


-- ============================================================
-- TEST 2: No duplicate supplier_product_id
-- ============================================================

SELECT
    supplier_product_id,
    COUNT(*) AS row_count
FROM warehouse.dim_supplier_product
GROUP BY supplier_product_id
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 3: Every source mapping exists in warehouse
-- ============================================================

SELECT
    spm.supplier_product_id
FROM intermediate.supplier_product_mapping spm
LEFT JOIN warehouse.dim_supplier_product d
    ON d.supplier_product_id = spm.supplier_product_id
WHERE d.supplier_product_id IS NULL;


-- ============================================================
-- TEST 4: No orphan warehouse mappings
-- ============================================================

SELECT
    d.supplier_product_id
FROM warehouse.dim_supplier_product d
LEFT JOIN intermediate.supplier_product_mapping spm
    ON spm.supplier_product_id = d.supplier_product_id
WHERE spm.supplier_product_id IS NULL;


-- ============================================================
-- TEST 5: supplier_key correctly resolves to warehouse.dim_suppliers
-- ============================================================

SELECT
    d.supplier_product_id,
    d.supplier_id,
    d.supplier_key
FROM warehouse.dim_supplier_product d
LEFT JOIN warehouse.dim_suppliers s
    ON s.supplier_key = d.supplier_key
   AND s.supplier_id = d.supplier_id
WHERE s.supplier_key IS NULL;


-- ============================================================
-- TEST 6: product_key correctly resolves to warehouse.dim_products
-- ============================================================

SELECT
    d.supplier_product_id,
    d.product_id,
    d.product_key
FROM warehouse.dim_supplier_product d
LEFT JOIN warehouse.dim_products p
    ON p.product_key = d.product_key
   AND p.product_id = d.product_id
WHERE p.product_key IS NULL;


-- ============================================================
-- TEST 7: supplier_price and lead_time_days must be non-negative
-- ============================================================

SELECT
    supplier_product_id,
    supplier_price,
    lead_time_days
FROM warehouse.dim_supplier_product
WHERE supplier_price < 0
   OR lead_time_days < 0;


-- ============================================================
-- TEST 8: Warehouse attributes match intermediate (catches stale rows)
-- ============================================================

SELECT
    spm.supplier_product_id,
    spm.supplier_price      AS source_price,
    d.supplier_price        AS warehouse_price,
    spm.lead_time_days      AS source_lead_time,
    d.lead_time_days        AS warehouse_lead_time,
    spm.is_preferred_supplier AS source_preferred,
    d.is_preferred_supplier   AS warehouse_preferred
FROM intermediate.supplier_product_mapping spm
JOIN warehouse.dim_supplier_product d
    ON d.supplier_product_id = spm.supplier_product_id
WHERE spm.supplier_price        IS DISTINCT FROM d.supplier_price
   OR spm.lead_time_days        IS DISTINCT FROM d.lead_time_days
   OR spm.is_preferred_supplier IS DISTINCT FROM d.is_preferred_supplier;


-- ============================================================
-- TEST 9: Idempotency check
-- Run load_dim_supplier_product.sql again, then compare counts.
-- ============================================================

SELECT COUNT(*) AS dim_supplier_product_count
FROM warehouse.dim_supplier_product;
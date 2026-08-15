-- ==========================================================================================================
-- TEST SUPPLIERS WAREHOUSE LOAD
-- ==========================================================================================================
-- SCD TYPE:
--     Type 1
--
-- Expected:
--     - Source and warehouse row counts match
--     - No duplicate supplier_id
--     - One warehouse row per supplier
--     - Warehouse attributes match intermediate
--     - Every source supplier exists in warehouse
-- ==========================================================================================================


-- ============================================================
-- TEST 1: Source vs Warehouse row count
-- ============================================================

SELECT
    (SELECT COUNT(*)
     FROM intermediate.suppliers) AS source_count,

    (SELECT COUNT(*)
     FROM warehouse.dim_suppliers) AS warehouse_count;


-- ============================================================
-- TEST 2: No duplicate supplier_id
-- ============================================================

SELECT
    supplier_id,
    COUNT(*) AS row_count
FROM warehouse.dim_suppliers
GROUP BY supplier_id
HAVING COUNT(*) > 1;




-- ============================================================
-- TEST 3: One warehouse row per supplier
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT supplier_id) AS distinct_suppliers
FROM warehouse.dim_suppliers;





-- ============================================================
-- TEST 4: Every source supplier exists in warehouse
-- ============================================================

SELECT
    s.supplier_id
FROM intermediate.suppliers s
LEFT JOIN warehouse.dim_suppliers d
    ON d.supplier_id = s.supplier_id
WHERE d.supplier_id IS NULL;





-- ============================================================
-- TEST 5: No orphan warehouse suppliers
-- ============================================================

SELECT
    d.supplier_id
FROM warehouse.dim_suppliers d
LEFT JOIN intermediate.suppliers s
    ON s.supplier_id = d.supplier_id
WHERE s.supplier_id IS NULL;


































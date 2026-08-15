-- ==========================================================================================================
-- TEST CUSTOMERS WAREHOUSE LOAD
-- ==========================================================================================================
-- Purpose:
--     Validate warehouse.dim_customers after initial / incremental load.
--
-- SCD TYPE:
--     Type 1
--
-- Expected:
--     - Same number of customers as intermediate
--     - No duplicate customer_id
--     - One warehouse row per customer
--     - Current attributes match intermediate
--     - Re-running the load does not increase row count
-- ==========================================================================================================


-- ============================================================
-- TEST 1: Source vs Warehouse row count
-- ============================================================

SELECT
    (SELECT COUNT(*)
     FROM intermediate.customers) AS source_count,

    (SELECT COUNT(*)
     FROM warehouse.dim_customers) AS warehouse_count;


-- ============================================================
-- TEST 2: No duplicate customer_id
-- ============================================================

SELECT
    customer_id,
    COUNT(*) AS row_count
FROM warehouse.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;




-- ============================================================
-- TEST 3: One warehouse row per customer
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS distinct_customers
FROM warehouse.dim_customers;


-- Expected:
-- total_rows = distinct_customers


--



-- ============================================================
-- TEST 4: Every source customer exists in warehouse
-- ============================================================

SELECT
    s.customer_id
FROM intermediate.customers s
LEFT JOIN warehouse.dim_customers d
    ON d.customer_id = s.customer_id
WHERE d.customer_id IS NULL;





-- ============================================================
-- TEST 5: No orphan warehouse customers
-- ============================================================

SELECT
    d.customer_id
FROM warehouse.dim_customers d
LEFT JOIN intermediate.customers s
    ON s.customer_id = d.customer_id
WHERE s.customer_id IS NULL;



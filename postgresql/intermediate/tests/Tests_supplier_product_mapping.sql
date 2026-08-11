-- ============================================================
-- FILE: test_supplier_product_mapping.sql
-- PURPOSE:
--     Data-quality tests for
--     intermediate.supplier_product_mapping
--
-- EXPECTATION:
--     Each test should return ZERO rows.
-- ============================================================


-- ============================================================
-- TEST 1: NULL PRIMARY IDs
-- ============================================================

SELECT *
FROM intermediate.supplier_product_mapping
WHERE supplier_product_id IS NULL;


-- ============================================================
-- TEST 2: DUPLICATE SUPPLIER_PRODUCT IDs
-- ============================================================

SELECT
    supplier_product_id,
    COUNT(*) AS row_count
FROM intermediate.supplier_product_mapping
GROUP BY supplier_product_id
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 3: DUPLICATE SUPPLIER / PRODUCT COMBINATIONS
-- ============================================================

SELECT
    supplier_id,
    product_id,
    COUNT(*) AS row_count
FROM intermediate.supplier_product_mapping
GROUP BY supplier_id, product_id
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 4: REQUIRED FIELDS
-- ============================================================

SELECT *
FROM intermediate.supplier_product_mapping
WHERE supplier_product_id IS NULL
   OR supplier_id IS NULL
   OR product_id IS NULL
   OR supplier_price IS NULL
   OR lead_time_days IS NULL
   OR is_preferred_supplier IS NULL
   OR created_at IS NULL
   OR updated_at IS NULL;


-- ============================================================
-- TEST 5: SUPPLIER REFERENCE
-- Supplier must exist.
-- ============================================================

SELECT spm.*
FROM intermediate.supplier_product_mapping spm
LEFT JOIN intermediate.suppliers s
    ON spm.supplier_id = s.supplier_id
WHERE s.supplier_id IS NULL;


-- ============================================================
-- TEST 6: PRODUCT REFERENCE
-- Product must exist.
-- ============================================================

SELECT spm.*
FROM intermediate.supplier_product_mapping spm
LEFT JOIN intermediate.products p
    ON spm.product_id = p.product_id
WHERE p.product_id IS NULL;


-- ============================================================
-- TEST 7: PRICE / LEAD TIME VALIDATION
-- Rule 4:
-- Supplier price and lead time cannot be negative.
-- ============================================================

SELECT *
FROM intermediate.supplier_product_mapping
WHERE supplier_price < 0
   OR lead_time_days < 0;


-- ============================================================
-- TEST 8: TIMESTAMP VALIDATION
-- Rule 9:
-- updated_at must be >= created_at.
-- ============================================================

SELECT *
FROM intermediate.supplier_product_mapping
WHERE updated_at < created_at;

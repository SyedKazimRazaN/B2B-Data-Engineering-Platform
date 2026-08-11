-- ============================================================
-- FILE: test_products.sql
-- PURPOSE:
--     Data-quality tests for intermediate.products
--
-- EXPECTATION:
--     Each test should return ZERO rows.
-- ============================================================


-- ============================================================
-- TEST 1: NULL PRODUCT IDs
-- ============================================================

SELECT *
FROM intermediate.products
WHERE product_id IS NULL;


-- ============================================================
-- TEST 2: DUPLICATE PRODUCT IDs
-- ============================================================

SELECT
    product_id,
    COUNT(*) AS row_count
FROM intermediate.products
GROUP BY product_id
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 3: DUPLICATE SKUs
-- ============================================================

SELECT
    sku,
    COUNT(*) AS row_count
FROM intermediate.products
GROUP BY sku
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 4: REQUIRED FIELDS
-- ============================================================

SELECT *
FROM intermediate.products
WHERE product_id IS NULL
   OR sku IS NULL
   OR product_name IS NULL
   OR category_id IS NULL
   OR brand IS NULL
   OR variant IS NULL
   OR cost_price IS NULL
   OR catalog_price IS NULL
   OR is_active IS NULL
   OR created_at IS NULL
   OR updated_at IS NULL;


-- ============================================================
-- TEST 5: PRODUCT → CATEGORY
-- Rule 3:
-- Every product must reference an existing category.
-- ============================================================

SELECT p.*
FROM intermediate.products p
LEFT JOIN intermediate.categories c
    ON p.category_id = c.category_id
WHERE c.category_id IS NULL;


-- ============================================================
-- TEST 6: PRICE VALIDATION
-- Rule:
-- Prices cannot be negative and catalog price cannot be
-- lower than cost price.
-- ============================================================

SELECT *
FROM intermediate.products
WHERE cost_price <= 0
   OR catalog_price <= 0
   OR catalog_price < cost_price;


-- ============================================================
-- TEST 7: TIMESTAMP VALIDATION
-- Rule 9:
-- updated_at must be >= created_at.
-- ============================================================

SELECT *
FROM intermediate.products
WHERE updated_at < created_at;

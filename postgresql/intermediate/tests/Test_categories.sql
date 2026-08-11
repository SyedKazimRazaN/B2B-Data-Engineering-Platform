-- ============================================================
-- FILE: test_categories.sql
-- PURPOSE:
--     Data-quality tests for intermediate.categories
--
-- EXPECTATION:
--     Each test should return ZERO rows.
-- ============================================================



-- ============================================================
-- TEST 1: NULL CATEGORY IDs
-- ============================================================

SELECT *
FROM intermediate.categories
WHERE category_id IS NULL;



-- ============================================================
-- TEST 2: DUPLICATE CATEGORY IDs
-- ============================================================
SELECT
    category_id,
    COUNT(*) AS duplicate_count
FROM intermediate.categories
GROUP BY category_id
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 3: DUPLICATE CATEGORY NAMES
-- ============================================================

SELECT
    category_name,
    COUNT(*) AS row_count
FROM intermediate.categories
GROUP BY category_name
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 4: REQUIRED TEXT FIELDS
-- ============================================================
SELECT *
FROM intermediate.categories
WHERE category_name IS NULL
   OR category_name = 'n/a'





-- ============================================================
-- TEST 5: REQUIRED TIMESTAMPS
-- ============================================================
SELECT *
FROM intermediate.companies
WHERE created_at IS NULL
   OR updated_at IS NULL;

   
-- Rule 3:
-- Every product must reference an existing category.

SELECT p.*
FROM intermediate.products p
LEFT JOIN intermediate.categories c
    ON c.category_id = p.category_id
WHERE c.category_id IS NULL;



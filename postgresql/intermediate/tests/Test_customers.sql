-- ============================================================
-- FILE: test_customers.sql
-- PURPOSE:
--     Data-quality tests for intermediate.customers
--
-- EXPECTATION:
--     Each test should return ZERO rows.
-- ============================================================


-- ============================================================
-- TEST 1: NULL CUSTOMER IDs
-- ============================================================

SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM intermediate.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;



-- ============================================================
-- TEST 2: DUPLICATE CUSTOMER IDs AND EMAIL

-- ============================================================
SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM intermediate.customers
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- Duplicate Customer emails
SELECT
    email,
    COUNT(*) AS duplicate_count
FROM intermediate.customers
GROUP BY email
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 3: REQUIRED FIELDS
-- ============================================================

SELECT *
FROM intermediate.customers
WHERE customer_id IS NULL
   OR company_id IS NULL
   OR first_name IS NULL
   OR last_name IS NULL
   OR email IS NULL
   OR created_at IS NULL
   OR updated_at IS NULL;


-- ============================================================
-- TEST 4: GENDER VALIDATION
-- ============================================================
SELECT *
FROM intermediate.customers
WHERE gender IS NOT NULL
  AND gender NOT IN ('Male', 'Female');


-- ============================================================
-- TEST 5: TIMESTAMP VALIDATION
-- ============================================================

-- Rule 9:
-- updated_at must be >= created_at.

SELECT *
FROM intermediate.customers
WHERE updated_at < created_at;


-- ============================================================================
-- Test 6. CUSTOMER BUSINESS RULES
-- ============================================================================ */
-- Rule 1:
-- Customers may only belong to Buyer companies.

SELECT
    c.customer_id,
    c.company_id,
    com.company_type
FROM intermediate.customers c
JOIN intermediate.companies com
    ON c.company_id = com.company_id
WHERE com.company_type <> 'Buyer';



-- Rule 5:
-- Customer must exist in orders.

SELECT o.*
FROM intermediate.orders o
LEFT JOIN intermediate.customers c
    ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL;


-- Rule 5:
-- Order cannot exists before customer.

SELECT
    o.order_id,
    o.order_date,
    c.created_at AS customer_created_at
FROM intermediate.orders o
JOIN intermediate.customers c
    ON c.customer_id = o.customer_id
WHERE o.order_date < c.created_at;



/* ============================================================================
   TEST 7. ORPHAN CHECKS
   ============================================================================ */

-- Customer → Company

SELECT c.*
FROM intermediate.customers c
LEFT JOIN intermediate.companies company
    ON company.company_id = c.company_id
WHERE company.company_id IS NULL;







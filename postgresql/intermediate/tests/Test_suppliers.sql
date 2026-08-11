-- ============================================================
-- FILE: test_suppliers.sql
-- PURPOSE:
--     Data-quality tests for intermediate.suppliers
--
-- EXPECTATION:
--     Each test should return ZERO rows.
-- ============================================================


-- ============================================================
-- TEST 1: NULL SUPPLIER IDs
-- ============================================================

SELECT *
FROM intermediate.suppliers
WHERE supplier_id IS NULL;


-- ============================================================
-- TEST 2: DUPLICATE SUPPLIER IDs
-- ============================================================

SELECT
    supplier_id,
    COUNT(*) AS row_count
FROM intermediate.suppliers
GROUP BY supplier_id
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 3: DUPLICATE EMAILS
-- ============================================================

SELECT
    email,
    COUNT(*) AS row_count
FROM intermediate.suppliers
GROUP BY email
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 4: REQUIRED FIELDS
-- ============================================================

SELECT *
FROM intermediate.suppliers
WHERE supplier_id IS NULL
   OR company_id IS NULL
   OR supplier_name IS NULL
   OR email IS NULL
   OR created_at IS NULL
   OR updated_at IS NULL;


-- ============================================================
-- TEST 5: SUPPLIER → COMPANY
-- Rule 2:
-- Suppliers may only belong to Supplier companies.
-- ============================================================

SELECT
    s.supplier_id,
    s.company_id,
    c.company_type
FROM intermediate.suppliers s
JOIN intermediate.companies c
    ON s.company_id = c.company_id
WHERE c.company_type <> 'Supplier';


-- ============================================================
-- TEST 6: ORPHANED COMPANY REFERENCES
-- Supplier company must exist.
-- ============================================================

SELECT s.*
FROM intermediate.suppliers s
LEFT JOIN intermediate.companies c
    ON s.company_id = c.company_id
WHERE c.company_id IS NULL;


-- ============================================================
-- TEST 7: TIMESTAMP VALIDATION
-- Rule 9:
-- updated_at must be >= created_at.
-- ============================================================

SELECT *
FROM intermediate.suppliers
WHERE updated_at < created_at;

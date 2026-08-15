-- =====================================================================
-- TESTS: warehouse.dim_companies
-- SCD TYPE 2
-- =====================================================================
--
-- Purpose:
-- Validate structural integrity, completeness, constraints, and
-- SCD Type 2 current/historical row rules for dim_companies.
--
-- Expected result:
-- Each test should return 0 rows unless otherwise stated.
--
-- Initial load:
-- 500 source companies
-- 500 warehouse rows
-- 500 current rows
-- 0 historical rows
--
-- =====================================================================


-- ============================================================
-- TEST 1: Baseline row counts
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT company_id) AS distinct_companies,
    COUNT(*) FILTER (WHERE is_current = TRUE) AS current_rows,
    COUNT(*) FILTER (WHERE is_current = FALSE) AS historical_rows
FROM warehouse.dim_companies;


-- TEST 2: No company has multiple current versions
SELECT
    company_id,
    COUNT(*) AS current_versions
FROM warehouse.dim_companies
WHERE is_current = TRUE
GROUP BY company_id
HAVING COUNT(*) <> 1;


-- TEST 3: Current records must not have an effective end date
SELECT *
FROM warehouse.dim_companies
WHERE is_current = TRUE
  AND effective_end_date IS NOT NULL;


-- TEST 4: Historical records must have an effective end date
SELECT count(*)
FROM warehouse.dim_companies
WHERE is_current = FALSE
  AND effective_end_date IS NULL;  




-- TEST 5: Effective end date must be after start date
SELECT *
FROM warehouse.dim_companies
WHERE effective_end_date IS NOT NULL
  AND effective_end_date <= effective_start_date;


-- TEST 6: Every source company should exist in the warehouse dimension
SELECT s.company_id
FROM intermediate.companies s
LEFT JOIN warehouse.dim_companies d
    ON d.company_id = s.company_id
WHERE d.company_id IS NULL;

-- TEST 7: Warehouse should not contain companies absent from the source
SELECT d.company_id
FROM warehouse.dim_companies d
LEFT JOIN intermediate.companies s
    ON s.company_id = d.company_id
WHERE s.company_id IS NULL;



-- TEST 8: Required attributes must not be NULL
SELECT *
FROM warehouse.dim_companies
WHERE company_id IS NULL
   OR company_name IS NULL
   OR company_type IS NULL
   OR cuit_tax_id IS NULL
   OR rating IS NULL
   OR country IS NULL
   OR city IS NULL
   OR address IS NULL
   OR effective_start_date IS NULL
   OR is_current IS NULL;




-- TEST 9: Company type must contain only allowed values
SELECT *
FROM warehouse.dim_companies
WHERE company_type NOT IN ('Buyer', 'Supplier');




-- TEST 10: Rating must remain between 1.0 and 5.0
SELECT *
FROM warehouse.dim_companies
WHERE rating < 1.0
   OR rating > 5.0;


-- TEST 11: Initial warehouse version starts at source created_at
SELECT
    s.company_id,
    s.created_at,
    d.effective_start_date
FROM intermediate.companies s
JOIN warehouse.dim_companies d
    ON d.company_id = s.company_id
   AND d.is_current = TRUE
WHERE d.effective_start_date <> s.created_at;






-- TESTING SCD TYPE 2
-- ============================================================
-- TEST: Changed company should create a new SCD2 version
-- ============================================================
UPDATE intermediate.companies
SET
    rating = 4.9,
    updated_at = updated_at + INTERVAL '1 day'
WHERE company_id = '00aa8b49d6cb44e28d5ed457bf29cf5c';

-- executing load_dim_companies.sql

/*
BEGIN;

-- ============================================================
-- SCD TYPE 2 — Step 1
-- Expire the current warehouse version when tracked
-- attributes have changed in the source.
--
-- We intentionally use a separate UPDATE/MERGE + INSERT pattern
-- rather than forcing SCD2 into a single MERGE statement.
-- ============================================================

MERGE INTO warehouse.dim_companies AS target
USING intermediate.companies AS source
    ON target.company_id = source.company_id
   AND target.is_current = TRUE

WHEN MATCHED
AND (
       source.company_name  IS DISTINCT FROM target.company_name
    OR source.company_type  IS DISTINCT FROM target.company_type
    OR source.cuit_tax_id   IS DISTINCT FROM target.cuit_tax_id
    OR source.rating        IS DISTINCT FROM target.rating
    OR source.country       IS DISTINCT FROM target.country
    OR source.city          IS DISTINCT FROM target.city
    OR source.address       IS DISTINCT FROM target.address
)
THEN
    UPDATE SET
        effective_end_date = source.updated_at,
        is_current = FALSE;


-- ============================================================
-- SCD TYPE 2 — Step 2
-- Insert:
--   1. brand-new companies
--   2. newly created versions of changed companies
--
-- If a company has no current warehouse version after Step 1,
-- it needs a current version inserted.
-- ============================================================

INSERT INTO warehouse.dim_companies (
    company_id,
    company_name,
    company_type,
    cuit_tax_id,
    rating,
    country,
    city,
    address,
    effective_start_date,
    effective_end_date,
    is_current
)
SELECT
    s.company_id,
    s.company_name,
    s.company_type,
    s.cuit_tax_id,
    s.rating,
    s.country,
    s.city,
    s.address,
    CASE
		WHEN NOT EXISTS (
	            SELECT 1
	            FROM warehouse.dim_companies h
	            WHERE h.company_id = s.company_id
	        )
        THEN s.created_at
        ELSE s.updated_at
    END AS effective_start_date,
    NULL AS effective_end_date,
    TRUE AS is_current

FROM intermediate.companies s
LEFT JOIN warehouse.dim_companies t
    ON t.company_id = s.company_id
   AND t.is_current = TRUE
WHERE t.company_id IS NULL;


COMMIT;
*/




--validating result
SELECT
    company_id,
    company_key,
    rating,
    effective_start_date,
    effective_end_date,
    is_current
FROM warehouse.dim_companies
WHERE company_id = '00aa8b49d6cb44e28d5ed457bf29cf5c'
ORDER BY effective_start_date;

/*
"company_id"	"company_key"	"rating"	"effective_start_date"	"effective_end_date"	"is_current"
"00aa8b49d6cb44e28d5ed457bf29cf5c"	501	4.8	"2025-02-07 03:24:41"	"2026-02-13 03:05:04"	false
"00aa8b49d6cb44e28d5ed457bf29cf5c"	1001	4.9	"2026-02-13 03:05:04"		true
*/

-- again running load_dim_companies

--checking versions
SELECT
    COUNT(*) AS total_versions,
    COUNT(*) FILTER (WHERE is_current = TRUE) AS current_versions,
    COUNT(*) FILTER (WHERE is_current = FALSE) AS historical_versions
FROM warehouse.dim_companies
WHERE company_id = '00aa8b49d6cb44e28d5ed457bf29cf5c';


-- resetting 
UPDATE intermediate.companies
SET
    rating = 4.8,
    updated_at = TIMESTAMP '2026-02-12 03:05:04'
WHERE company_id = '00aa8b49d6cb44e28d5ed457bf29cf5c';


BEGIN;

-- Remove the artificial SCD2 version created by the test
DELETE FROM warehouse.dim_companies
WHERE company_key = 1001
  AND company_id = '00aa8b49d6cb44e28d5ed457bf29cf5c';

-- Restore the original warehouse version as current
UPDATE warehouse.dim_companies
SET
    effective_end_date = NULL,
    is_current = TRUE
WHERE company_key = 501
  AND company_id = '00aa8b49d6cb44e28d5ed457bf29cf5c';

COMMIT;


--checking versions
SELECT
    COUNT(*) AS total_versions,
    COUNT(*) FILTER (WHERE is_current = TRUE) AS current_versions,
    COUNT(*) FILTER (WHERE is_current = FALSE) AS historical_versions
FROM warehouse.dim_companies
WHERE company_id = '00aa8b49d6cb44e28d5ed457bf29cf5c';





















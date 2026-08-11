-- ============================================================
-- FILE: test_companies.sql
-- PURPOSE:
--     Data-quality tests for intermediate.companies
--
-- EXPECTATION:
--     Every test should return ZERO rows unless explicitly
--     documented otherwise excluding test 11 columns.
-- ============================================================


-- ============================================================
-- TEST 1: NULL COMPANY IDs
-- ============================================================

SELECT *
FROM intermediate.companies
WHERE company_id IS NULL;


-- ============================================================
-- TEST 2: DUPLICATE COMPANY IDs
--
-- ============================================================

SELECT
    company_id,
    COUNT(*) AS record_count
FROM intermediate.companies
GROUP BY company_id
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 3: DUPLICATE COMPANY NAME / TAX ID
-- ============================================================

SELECT
    company_name,
    COUNT(*) AS row_count
FROM intermediate.companies
GROUP BY company_name
HAVING COUNT(*) > 1;


SELECT
    cuit_tax_id,
    COUNT(*) AS row_count
FROM intermediate.companies
GROUP BY cuit_tax_id
HAVING COUNT(*) > 1;



-- ============================================================
-- TEST 4: REQUIRED TEXT FIELDS
--
-- These fields should not be NULL or represented by 'n/a'.
-- ============================================================

SELECT *
FROM intermediate.companies
WHERE company_name IS NULL
   OR company_name = 'n/a'

   OR company_type IS NULL
   OR company_type = 'n/a'

   OR cuit_tax_id IS NULL
   OR cuit_tax_id = 'n/a'

   OR country IS NULL
   OR country = 'n/a'

   OR city IS NULL
   OR city = 'n/a';

   OR address IS NULL
   OR address = 'n/a'
   
   OR created_at IS NULL
   OR updated_at IS NULL;




-- ============================================================
-- TEST 5: RATING
--
-- Rating must be between 1.0 and 5.0.
-- ============================================================

SELECT *
FROM intermediate.companies
WHERE rating IS NULL
   OR rating NOT BETWEEN 1.0 AND 5.0;



-- ============================================================
-- TEST 6: REQUIRED TIMESTAMPS
-- ============================================================

SELECT *
FROM intermediate.companies
WHERE created_at IS NULL
   OR updated_at IS NULL;


-- ============================================================
-- TEST 7: EMPTY / WHITESPACE VALUES
-- ============================================================

SELECT *
FROM intermediate.companies
WHERE TRIM(company_name) = ''
   OR TRIM(company_type) = ''
   OR TRIM(cuit_tax_id) = ''
   OR TRIM(country) = ''
   OR TRIM(city) = ''
   OR TRIM(address) = '';




-- ============================================================
-- TEST 8: COUNTRY DISTRIBUTION
-- ============================================================

SELECT
    country,
    COUNT(*) AS company_count
FROM intermediate.companies
GROUP BY country
ORDER BY company_count DESC;




-- ============================================================
-- TEST 9: COUNTRY / CITY COMBINATIONS
-- ============================================================

SELECT
    country,
    city,
    COUNT(*) AS company_count
FROM intermediate.companies
GROUP BY country, city
ORDER BY country, company_count DESC;



-- ============================================================
-- TEST 10: BUSINESS LOCATION VALIDATION
-- ============================================================

SELECT *
FROM intermediate.companies
WHERE NOT (
       (country = 'United States'
        AND city IN (
            'Chicago',
            'Dallas',
            'Seattle',
            'New York',
            'Austin'
        ))

    OR (country = 'United Kingdom'
        AND city IN (
            'London',
            'Manchester',
            'Birmingham'
        ))

    OR (country = 'Australia'
        AND city IN (
            'Sydney',
            'Melbourne',
            'Brisbane'
        ))
);

-- ============================================================
-- TEST 11: COMPANY TYPE
-- Rule: Company must be Buyer or Supplier.
-- ============================================================

SELECT *
FROM intermediate.companies
WHERE company_type NOT IN ('Buyer', 'Supplier');



-- ============================================================
-- TEST 11: OVERALL DATA QUALITY SUMMARY
-- ============================================================

SELECT
    COUNT(*) AS total_companies,
    COUNT(DISTINCT company_id) AS unique_company_ids,
    COUNT(*) FILTER (WHERE company_name IS NULL OR company_name = 'n/a') AS missing_company_names,
    COUNT(*) FILTER (WHERE company_type IS NULL OR company_type = 'n/a') AS missing_company_types,
    COUNT(*) FILTER (WHERE cuit_tax_id IS NULL OR cuit_tax_id = 'n/a') AS missing_tax_ids,
    COUNT(*) FILTER (WHERE rating IS NULL OR rating NOT BETWEEN 1.0 AND 5.0) AS invalid_ratings,
    COUNT(*) FILTER (WHERE country IS NULL OR country = 'n/a') AS missing_countries,
    COUNT(*) FILTER (WHERE city IS NULL OR city = 'n/a') AS missing_cities,
    COUNT(*) FILTER (WHERE created_at IS NULL) AS missing_created_at,
    COUNT(*) FILTER (WHERE updated_at IS NULL) AS missing_updated_at
FROM intermediate.companies;





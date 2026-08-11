-- ============================================================
-- COMPANIES TRANSFORMATION
-- staging → intermediate
-- ============================================================
-- FILE: transform_companies.sql
-- PURPOSE:
--     Transform staging.companies into intermediate.companies
--
-- PIPELINE:
--     staging.companies
--        ↓
--     latest record per company_id
--        ↓
--     cleaning / normalization
--        ↓
--     business validation
--        ↓
--     MERGE into intermediate.companies
--
-- DESIGN GOALS:
--     - Keep the latest source record
--     - Normalize whitespace / empty strings
--     - Handle textual missing values
--     - Validate company business rules
--     - Make the load idempotent
-- ============================================================




--	============================================================================
--   1. COMPANIES
--	============================================================================


WITH latest_companies AS (
	-- ====================================================
	-- 1. DEDUPLICATION
	-- ====================================================
	SELECT 
		company_id,
		company_name,
		company_type,
		cuit_tax_id,
		rating,
		country,
		city,
		address,
		created_at,
		updated_at,
	ROW_NUMBER() OVER(PARTITION BY company_id ORDER BY _loaded_at DESC,  updated_at DESC) rn
	FROM staging.companies
	WHERE company_id IS NOT NULL
),

cleaned_companies AS (
	-- ====================================================
	-- 2. CLEANING / NORMALIZATION
	-- ====================================================
	SELECT
	company_id,
	NULLIF(TRIM(company_name), '') AS company_name,
	NULLIF(TRIM(company_type), '') AS company_type,
	NULLIF(TRIM(cuit_tax_id), '') AS cuit_tax_id,
	rating,
	NULLIF(TRIM(country), '') AS country,
	NULLIF(TRIM(city), '') AS city,
	NULLIF(TRIM(address), '') AS address,
	created_at,
	updated_at
	FROM latest_companies
	WHERE rn = 1
),

validated_companies AS (
	-- ====================================================
	-- 3. BUSINESS VALIDATION
	-- ====================================================
	SELECT 
		company_id,
		company_name,
		company_type,
		cuit_tax_id,
		rating,
		country,
		city,
		address,
		created_at,
		updated_at
	FROM cleaned_companies
	WHERE company_name IS NOT NULL
		AND company_type IN ('Buyer', 'Supplier')
		AND cuit_tax_id IS NOT NULL
		AND rating BETWEEN 1.0 AND 5.0
		AND country IS NOT NULL
		AND city IS NOT NULL
		AND address IS NOT NULL
		AND created_at IS NOT NULL
		AND updated_at IS NOT NULL
		AND updated_at >= created_at
)

MERGE INTO intermediate.companies AS target
USING		validated_companies AS source
	ON target.company_id = source.company_id
WHEN MATCHED 
AND target.updated_at < source.updated_at THEN
-- ============================================================
-- 4. UPDATE EXISTING COMPANIES
-- ============================================================
	UPDATE SET
		company_name = source.company_name,
        company_type = source.company_type,
        cuit_tax_id = source.cuit_tax_id,
        rating = source.rating,
        country = source.country,
        city = source.city,
        address = source.address,
        created_at = source.created_at,
        updated_at = source.updated_at
		
WHEN NOT MATCHED THEN
-- ============================================================
-- 5. INSERT NEW COMPANIES
-- ============================================================
	INSERT (
		company_id,
        company_name,
        company_type,
        cuit_tax_id,
        rating,
        country,
        city,
        address,
        created_at,
        updated_at
	)
	VALUES (
		source.company_id,
        source.company_name,
        source.company_type,
        source.cuit_tax_id,
        source.rating,
        source.country,
        source.city,
        source.address,
        source.created_at,
        source.updated_at
    );




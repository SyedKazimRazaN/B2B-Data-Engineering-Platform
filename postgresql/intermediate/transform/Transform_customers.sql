-- ============================================================
-- CUSTOMERS TRANSFORMATION
-- staging → intermediate
-- ============================================================
-- FILE: transform_customers.sql
-- PURPOSE:
--     Transform staging.customers into intermediate.customers
--
-- PIPELINE:
--     staging.customers
--        ↓
--     latest record per customer_id
--        ↓
--     cleaning / normalization
--        ↓
--     business validation
--        ↓
--     MERGE into intermediate.customer
--
-- DESIGN GOALS:
--     - Keep the latest source record
--     - Normalize whitespace / empty strings
--     - Handle textual missing values
--     - Validate company business rules
--     - Make the load idempotent
-- ============================================================


--	============================================================================
--   3. CUSTOMERS
--	============================================================================

WITH latest_customers AS (
	-- ====================================================
	-- 1. DEDUPLICATION
	-- ====================================================
	SELECT 
		customer_id,
		company_id,
		first_name,
		last_name,
		email,
		phone_number,
		gender,
		date_of_birth,
		job_title,
		created_at,
		updated_at,
		ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY _loaded_at DESC, updated_at DESC) rn
	FROM staging.customers
	WHERE customer_id IS NOT NULL
),
cleaned_customers AS (
	-- ====================================================
	-- 2. CLEANING / NORMALIZATION
	-- ====================================================
	SELECT 
        customer_id,
        company_id,
        NULLIF(TRIM(first_name), '') AS first_name,
        NULLIF(TRIM(last_name), '') AS last_name,
        LOWER(NULLIF(TRIM(email), '')) AS email,
        NULLIF(TRIM(phone_number), '') AS phone_number,
        NULLIF(TRIM(gender), '') AS gender,
        date_of_birth,
        NULLIF(TRIM(job_title), '') AS job_title,
        created_at,
        updated_at
    FROM latest_customers
    WHERE rn = 1
),
validated_customers AS (
	-- ====================================================
	-- 3. BUSINESS VALIDATION
	-- ====================================================
	SELECT
		c.customer_id,
		c.company_id,
		c.first_name,
		c.last_name,
		c.email,
		c.phone_number,
		c.gender,
		c.date_of_birth,
		c.job_title,
		c.created_at,
		c.updated_at
    FROM cleaned_customers c
    INNER JOIN intermediate.companies com
        ON com.company_id = c.company_id
    WHERE c.company_id IS NOT NULL
      AND com.company_type = 'Buyer'
      AND c.first_name IS NOT NULL
      AND c.last_name IS NOT NULL
      AND c.email IS NOT NULL
      AND (c.gender IS NULL OR c.gender IN ('Male', 'Female'))
      AND c.created_at IS NOT NULL
      AND c.updated_at IS NOT NULL
      AND c.updated_at >= c.created_at
)
	
MERGE INTO intermediate.customers AS target
USING validated_customers AS source
ON target.customer_id = source.customer_id

WHEN MATCHED 
AND target.updated_at < source.updated_at THEN
	-- ============================================================
	-- 4. UPDATE EXISTING CUSTOMERS
	-- ============================================================
    UPDATE SET
        company_id = source.company_id,
        first_name = source.first_name,
        last_name = source.last_name,
        email = source.email,
        phone_number = source.phone_number,
        gender = source.gender,
        date_of_birth = source.date_of_birth,
        job_title = source.job_title,
        created_at = source.created_at,
        updated_at = source.updated_at

WHEN NOT MATCHED THEN
	-- ============================================================
	-- 5. INSERT NEW CUSTOMERS
	-- ============================================================
    INSERT (
        customer_id,
        company_id,
        first_name,
        last_name,
        email,
        phone_number,
        gender,
        date_of_birth,
        job_title,
        created_at,
        updated_at
    )
    VALUES (
        source.customer_id,
        source.company_id,
        source.first_name,
        source.last_name,
        source.email,
        source.phone_number,
        source.gender,
        source.date_of_birth,
        source.job_title,
        source.created_at,
        source.updated_at
    );





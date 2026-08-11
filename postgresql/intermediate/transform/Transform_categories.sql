
-- ============================================================
-- CATEGORIES TRANSFORMATION
-- staging → intermediate
-- ============================================================
-- FILE: transform_categories.sql
-- PURPOSE:
--     Transform staging.categories into intermediate.categories
--
-- PIPELINE:
--     staging.categories
--        ↓
--     latest record per category_id
--        ↓
--     cleaning / normalization
--        ↓
--     business validation
--        ↓
--     MERGE into intermediate.category
--
-- DESIGN GOALS:
--     - Keep the latest source record
--     - Normalize whitespace / empty strings
--     - Handle textual missing values
--     - Validate company business rules
--     - Make the load idempotent
-- ============================================================

--	============================================================================
--   2. CATEGORIES
--	============================================================================


with latest_categories as (
	-- ====================================================
	-- 1. DEDUPLICATION
	-- ====================================================
	SELECT 
		*,
		row_number () over(Partition by category_id Order by _loaded_at DESC, updated_at DESC) rn
	FROM staging.categories 
	WHERE category_id IS NOT NULL
),

cleaned_categories AS (
	-- ====================================================
	-- 2. CLEANING / NORMALIZATION
	-- ====================================================
	SELECT 
		category_id,
		NULLIF (TRIM(category_name),'') AS category_name,
		created_at,
		updated_at
	FROM latest_categories
	WHERE rn = 1
),
validated_categories AS (
	-- ====================================================
	-- 3. BUSINESS VALIDATION
	-- ====================================================
	SELECT 
		category_id,
		category_name,
		created_at,
		updated_at
	FROM cleaned_categories 
	WHERE category_name IS NOT NULL
		AND created_at IS NOT NULL
		AND updated_at IS NOT NULL
		AND updated_at >= created_at
)


MERGE INTO intermediate.categories AS target
USING validated_categories AS source
ON target.category_id = source.category_id
WHEN MATCHED 
AND target.updated_at < source.updated_at THEN
	-- ============================================================
	-- 4. UPDATE EXISTING CATEGORIES
	-- ============================================================
    UPDATE SET
        category_name = source.category_name,
        created_at = source.created_at,
        updated_at = source.updated_at

WHEN NOT MATCHED THEN
	-- ============================================================
	-- 5. INSERT NEW CATEGORIES
	-- ============================================================
    INSERT (
        category_id,
        category_name,
        created_at,
        updated_at
    )
    VALUES (
        source.category_id,
        source.category_name,
        source.created_at,
        source.updated_at
    );






-- ============================================================
-- PRODUCTS TRANSFORMATION
-- staging → intermediate
-- ============================================================
-- FILE: transform_products.sql
-- PURPOSE:
--     Transform staging.products into intermediate.products
--
-- PIPELINE:
--     staging.products
--        ↓
--     latest record per product_id
--        ↓
--     cleaning / normalization
--        ↓
--     business validation
--        ↓
--     MERGE into intermediate.products
--
-- DESIGN GOALS:
--     - Keep the latest source record
--     - Normalize whitespace / empty strings
--     - Handle textual missing values
--     - Validate company business rules
--     - Make the load idempotent
-- ============================================================

/* ============================================================================
   5. PRODUCTS
   ============================================================================ */

WITH latest_products AS (
	-- ====================================================
	-- 1. DEDUPLICATION
	-- ====================================================
    SELECT
        product_id,
        sku,
        product_name,
        category_id,
        brand,
        variant,
        cost_price,
        catalog_price,
        is_active,
        created_at,
        updated_at,
        ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY _loaded_at DESC, updated_at DESC) AS rn
    FROM staging.products
    WHERE product_id IS NOT NULL
),

cleaned_products AS (
	-- ====================================================
	-- 2. CLEANING / NORMALIZATION
	-- ====================================================
    SELECT
        product_id,
        NULLIF(TRIM(sku), '') AS sku,
        NULLIF(TRIM(product_name), '') AS product_name,
        category_id,
        NULLIF(TRIM(brand), '') AS brand,
        NULLIF(TRIM(variant), '') AS variant,
        cost_price,
        catalog_price,
        is_active,
        created_at,
        updated_at
    FROM latest_products
    WHERE rn = 1
),

validated_products AS (
	-- ====================================================
	-- 3. BUSINESS VALIDATION
	-- ====================================================
    SELECT p.product_id,
        p.sku,
        p.product_name,
        p.category_id,
        p.brand,
        p.variant,
        p.cost_price,
        p.catalog_price,
        p.is_active,
        p.created_at,
        p.updated_at
    FROM cleaned_products p
    INNER JOIN intermediate.categories c
        ON c.category_id = p.category_id
    WHERE p.sku IS NOT NULL
      AND p.product_name IS NOT NULL
      AND p.category_id IS NOT NULL
      AND p.brand IS NOT NULL
      AND p.variant IS NOT NULL
      AND p.cost_price >= 0
      AND p.catalog_price >= p.cost_price
      AND p.created_at IS NOT NULL
      AND p.updated_at IS NOT NULL
      AND p.updated_at >= p.created_at
)

MERGE INTO intermediate.products AS target
USING validated_products AS source
ON target.product_id = source.product_id

WHEN MATCHED
AND target.updated_at < source.updated_at THEN
	-- ============================================================
	-- 4. UPDATE EXISTING PRODUCTS
	-- ============================================================
    UPDATE SET
        sku = source.sku,
        product_name = source.product_name,
        category_id = source.category_id,
        brand = source.brand,
        variant = source.variant,
        cost_price = source.cost_price,
        catalog_price = source.catalog_price,
        is_active = source.is_active,
        created_at = source.created_at,
        updated_at = source.updated_at

WHEN NOT MATCHED THEN
	-- ============================================================
	-- 5. INSERT NEW PRODUCTS
	-- ============================================================
    INSERT (
        product_id,
        sku,
        product_name,
        category_id,
        brand,
        variant,
        cost_price,
        catalog_price,
        is_active,
        created_at,
        updated_at
    )
    VALUES (
        source.product_id,
        source.sku,
        source.product_name,
        source.category_id,
        source.brand,
        source.variant,
        source.cost_price,
        source.catalog_price,
        source.is_active,
        source.created_at,
        source.updated_at
    );






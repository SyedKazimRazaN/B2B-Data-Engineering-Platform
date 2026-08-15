-- ============================================================
-- PRODUCTS WAREHOUSE LOAD
-- intermediate → warehouse
-- ============================================================
-- FILE: load_dim_products.sql
--
-- PURPOSE:
--     Load intermediate.products into warehouse.dim_products
--     using SCD Type 1 behavior.
--
--     category_name is denormalized from intermediate.categories
--     because the warehouse product dimension stores both
--     category_id and category_name.
--
-- PIPELINE:
--     intermediate.products
--              ↓
--     JOIN intermediate.categories
--              ↓
--     MERGE on product_id
--              ↓
--     existing product → UPDATE
--     new product      → INSERT
--
-- DESIGN:
--     - SCD Type 1
--     - Existing records are overwritten
--     - No historical versions are maintained
--     - Initial and incremental loads use the same SQL
--     - No hash is required
--     - product_key is generated automatically by SERIAL
--     - Load is idempotent
-- ============================================================


-- BEGIN;

-- ============================================================
-- 1. MERGE PRODUCTS
-- ============================================================

MERGE INTO warehouse.dim_products AS target
USING (
    SELECT
        p.product_id,
        p.sku,
        p.product_name,
        p.category_id,
        c.category_name,
        p.brand,
        p.variant,
        p.cost_price,
        p.catalog_price,
        p.is_active,
        p.created_at,
        p.updated_at
    FROM intermediate.products AS p
    INNER JOIN intermediate.categories AS c
        ON c.category_id = p.category_id
) AS source
    ON target.product_id = source.product_id

WHEN MATCHED
AND (
       source.sku IS DISTINCT FROM target.sku
    OR source.product_name IS DISTINCT FROM target.product_name
    OR source.category_id IS DISTINCT FROM target.category_id
    OR source.category_name IS DISTINCT FROM target.category_name
    OR source.brand IS DISTINCT FROM target.brand
    OR source.variant IS DISTINCT FROM target.variant
    OR source.cost_price IS DISTINCT FROM target.cost_price
    OR source.catalog_price IS DISTINCT FROM target.catalog_price
    OR source.is_active IS DISTINCT FROM target.is_active
    OR source.created_at IS DISTINCT FROM target.created_at
    OR source.updated_at IS DISTINCT FROM target.updated_at
)

THEN
-- ============================================================
-- 2. UPDATE EXISTING PRODUCTS
-- ============================================================
    UPDATE SET
        sku           = source.sku,
        product_name  = source.product_name,
        category_id   = source.category_id,
        category_name = source.category_name,
        brand         = source.brand,
        variant       = source.variant,
        cost_price    = source.cost_price,
        catalog_price = source.catalog_price,
        is_active     = source.is_active,
        created_at    = source.created_at,
        updated_at    = source.updated_at

WHEN NOT MATCHED THEN
-- ============================================================
-- 3. INSERT NEW PRODUCTS
-- ============================================================
    INSERT (
        product_id,
        sku,
        product_name,
        category_id,
        category_name,
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
        source.category_name,
        source.brand,
        source.variant,
        source.cost_price,
        source.catalog_price,
        source.is_active,
        source.created_at,
        source.updated_at
    );

-- COMMIT;

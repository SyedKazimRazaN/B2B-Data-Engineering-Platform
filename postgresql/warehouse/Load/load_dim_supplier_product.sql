-- ============================================================
-- SUPPLIER-PRODUCT PRICING WAREHOUSE LOAD
-- intermediate → warehouse
-- ============================================================
-- FILE: load_dim_supplier_product.sql
--
-- PURPOSE:
--     Load intermediate.supplier_product_mapping into
--     warehouse.dim_supplier_product using SCD Type 1 behavior.
--
--     Resolves supplier_key/product_key surrogate keys at load time so
--     fact_order_items (which already carries supplier_key/product_key)
--     can join directly on surrogate keys to pull in the negotiated
--     supplier_price for Gross Margin Analysis.
--
-- PIPELINE:
--     intermediate.supplier_product_mapping
--        ↓
--     JOIN dim_suppliers / dim_products for surrogate keys
--        ↓
--     MERGE on supplier_product_id
--        ↓
--     existing mapping → UPDATE
--     new mapping      → INSERT
--
-- DESIGN:
--     - SCD Type 1
--     - Existing records are overwritten
--     - No historical versions are maintained
--     - Requires dim_suppliers and dim_products to be loaded first
--     - supplier_product_key is generated automatically by SERIAL
--     - Load is idempotent
--
-- CHANGE DETECTION:
--     Direct comparison of dimension attributes is used.
--     IS DISTINCT FROM is used so NULL changes are detected safely.
-- ============================================================

-- BEGIN;

MERGE INTO warehouse.dim_supplier_product AS target
USING (
    SELECT
        spm.supplier_product_id,
        spm.supplier_id,
        spm.product_id,
        s.supplier_key,
        p.product_key,
        spm.supplier_price,
        spm.lead_time_days,
        spm.is_preferred_supplier,
        spm.created_at,
        spm.updated_at
    FROM intermediate.supplier_product_mapping AS spm
    INNER JOIN warehouse.dim_suppliers AS s
        ON s.supplier_id = spm.supplier_id
    INNER JOIN warehouse.dim_products AS p
        ON p.product_id = spm.product_id
) AS source
    ON target.supplier_product_id = source.supplier_product_id

WHEN MATCHED
AND (
       source.supplier_key          IS DISTINCT FROM target.supplier_key
    OR source.product_key           IS DISTINCT FROM target.product_key
    OR source.supplier_price        IS DISTINCT FROM target.supplier_price
    OR source.lead_time_days        IS DISTINCT FROM target.lead_time_days
    OR source.is_preferred_supplier IS DISTINCT FROM target.is_preferred_supplier
)
THEN
-- ============================================================
-- UPDATE EXISTING SUPPLIER-PRODUCT PRICING
-- ============================================================
    UPDATE SET
        supplier_key           = source.supplier_key,
        product_key            = source.product_key,
        supplier_price          = source.supplier_price,
        lead_time_days          = source.lead_time_days,
        is_preferred_supplier   = source.is_preferred_supplier,
        updated_at              = source.updated_at

WHEN NOT MATCHED THEN
-- ============================================================
-- INSERT NEW SUPPLIER-PRODUCT PRICING
-- ============================================================
    INSERT (
        supplier_product_id,
        supplier_id,
        product_id,
        supplier_key,
        product_key,
        supplier_price,
        lead_time_days,
        is_preferred_supplier,
        created_at,
        updated_at
    )
    VALUES (
        source.supplier_product_id,
        source.supplier_id,
        source.product_id,
        source.supplier_key,
        source.product_key,
        source.supplier_price,
        source.lead_time_days,
        source.is_preferred_supplier,
        source.created_at,
        source.updated_at
    );

-- COMMIT;
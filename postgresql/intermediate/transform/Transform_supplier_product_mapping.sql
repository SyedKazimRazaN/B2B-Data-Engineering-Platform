
-- ============================================================
-- SUPPLIER PRODUCT MAPPING TRANSFORMATION
-- staging → intermediate
-- ============================================================
-- FILE: transform_supplier_product_mapping.sql
-- PURPOSE:
--     Transform staging.supplier_product_mapping into intermediate.supplier_product_mapping
--
-- PIPELINE:
--     staging.supplier_product_mapping
--        ↓
--     latest record per supplier_product_id
--        ↓
--     cleaning / normalization
--        ↓
--     business validation
--        ↓
--     MERGE into intermediate.supplier_product_mapping
--
-- DESIGN GOALS:
--     - Keep the latest source record
--     - Normalize whitespace / empty strings
--     - Handle textual missing values
--     - Validate company business rules
--     - Make the load idempotent
-- ============================================================

/* ============================================================================
   5. SUPPLIER PRODUCT MAPPING
   ============================================================================ */

WITH latest_spm AS (
    -- ====================================================
    -- 1. DEDUPLICATION
    -- ====================================================
    SELECT
        supplier_product_id,
        supplier_id,
        product_id,
        supplier_price,
        lead_time_days,
        is_preferred_supplier,
        created_at,
        updated_at,
        ROW_NUMBER() OVER (
            PARTITION BY supplier_product_id
            ORDER BY _loaded_at DESC, updated_at DESC
        ) AS rn
    FROM staging.supplier_product_mapping
    WHERE supplier_product_id IS NOT NULL
),

validated_spm AS (
    -- ====================================================
    -- 2. BUSINESS VALIDATION
    -- ====================================================
    SELECT
        spm.supplier_product_id,
        spm.supplier_id,
        spm.product_id,
        spm.supplier_price,
        spm.lead_time_days,
        spm.is_preferred_supplier,
        spm.created_at,
        spm.updated_at
    FROM latest_spm AS spm

    INNER JOIN intermediate.suppliers AS s
        ON s.supplier_id = spm.supplier_id

    INNER JOIN intermediate.products AS p
        ON p.product_id = spm.product_id

    WHERE spm.rn = 1
      AND spm.supplier_id IS NOT NULL
      AND spm.product_id IS NOT NULL
      AND spm.supplier_price >= 0
      AND spm.lead_time_days >= 0
      AND spm.created_at IS NOT NULL
      AND spm.updated_at IS NOT NULL
      AND spm.updated_at >= spm.created_at
)


MERGE INTO intermediate.supplier_product_mapping AS target
USING validated_spm AS source
ON target.supplier_product_id = source.supplier_product_id

WHEN MATCHED
AND target.updated_at < source.updated_at THEN
	-- ============================================================
	-- 3. UPDATE EXISTING SUPPLIER PRODUCT MAPPING
	-- ============================================================
    UPDATE SET
        supplier_id = source.supplier_id,
        product_id = source.product_id,
        supplier_price = source.supplier_price,
        lead_time_days = source.lead_time_days,
        is_preferred_supplier = source.is_preferred_supplier,
        created_at = source.created_at,
        updated_at = source.updated_at

WHEN NOT MATCHED THEN
	-- ============================================================
	-- 4. INSERT NEW SUPPLIER PRODUCT MAPPING
	-- ============================================================
    INSERT (
        supplier_product_id,
        supplier_id,
        product_id,
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
        source.supplier_price,
        source.lead_time_days,
        source.is_preferred_supplier,
        source.created_at,
        source.updated_at
    );






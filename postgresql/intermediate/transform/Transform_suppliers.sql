
-- ============================================================
-- SUPPLIERS TRANSFORMATION
-- staging → intermediate
-- ============================================================
-- FILE: transform_customers.sql
-- PURPOSE:
--     Transform staging.suppliers into intermediate.suppliers
--
-- PIPELINE:
--     staging.suppliers
--        ↓
--     latest record per supplier_id
--        ↓
--     cleaning / normalization
--        ↓
--     business validation
--        ↓
--     MERGE into intermediate.suppliers
--
-- DESIGN GOALS:
--     - Keep the latest source record
--     - Normalize whitespace / empty strings
--     - Handle textual missing values
--     - Validate company business rules
--     - Make the load idempotent
-- ============================================================

/* ============================================================================
   4. SUPPLIERS
   ============================================================================ */

WITH latest_suppliers AS (
	-- ====================================================
	-- 1. DEDUPLICATION
	-- ====================================================
    SELECT
        supplier_id,
        company_id,
        supplier_name,
        contact_name,
        email,
        phone_number,
        created_at,
        updated_at,
        ROW_NUMBER() OVER (PARTITION BY supplier_id ORDER BY _loaded_at DESC, updated_at DESC) AS rn
    FROM staging.suppliers
    WHERE supplier_id IS NOT NULL
),

cleaned_suppliers AS (
	-- ====================================================
	-- 2. CLEANING / NORMALIZATION
	-- ====================================================
    SELECT
        supplier_id,
        company_id,
        NULLIF(TRIM(supplier_name), '') AS supplier_name,
        NULLIF(TRIM(contact_name), '') AS contact_name,
        LOWER(NULLIF(TRIM(email), '')) AS email,
        NULLIF(TRIM(phone_number), '') AS phone_number,
        created_at,
        updated_at
    FROM latest_suppliers
    WHERE rn = 1
),

validated_suppliers AS (
	-- ====================================================
	-- 3. BUSINESS VALIDATION
	-- ====================================================
    SELECT s.supplier_id,
        s.company_id,
        s.supplier_name,
        s.contact_name,
        s.email,
        s.phone_number,
        s.created_at,
        s.updated_at
    FROM cleaned_suppliers s
    INNER JOIN intermediate.companies com
        ON com.company_id = s.company_id
    WHERE s.company_id IS NOT NULL
      AND com.company_type = 'Supplier'
      AND s.supplier_name IS NOT NULL
      AND s.email IS NOT NULL
      AND s.created_at IS NOT NULL
      AND s.updated_at IS NOT NULL
      AND s.updated_at >= s.created_at
)

MERGE INTO intermediate.suppliers AS target
USING validated_suppliers AS source
ON target.supplier_id = source.supplier_id

WHEN MATCHED
AND target.updated_at < source.updated_at THEN
	-- ============================================================
	-- 4. UPDATE EXISTING SUPPLIERS
	-- ============================================================
    UPDATE SET
        company_id = source.company_id,
        supplier_name = source.supplier_name,
        contact_name = source.contact_name,
        email = source.email,
        phone_number = source.phone_number,
        created_at = source.created_at,
        updated_at = source.updated_at

WHEN NOT MATCHED THEN
    INSERT (
	-- ============================================================
	-- 5. INSERT NEW SUPPLIERS
	-- ============================================================
        supplier_id,
        company_id,
        supplier_name,
        contact_name,
        email,
        phone_number,
        created_at,
        updated_at
    )
    VALUES (
        source.supplier_id,
        source.company_id,
        source.supplier_name,
        source.contact_name,
        source.email,
        source.phone_number,
        source.created_at,
        source.updated_at
    );





-- ============================================================
-- SUPPLIERS WAREHOUSE LOAD
-- intermediate → warehouse
-- ============================================================
-- FILE: load_dim_suppliers.sql
--
-- PURPOSE:
--     Load intermediate.suppliers into warehouse.dim_suppliers
--     using SCD Type 1 behavior.
--
-- PIPELINE:
--     intermediate.suppliers
--        ↓
--     MERGE on supplier_id
--        ↓
--     existing supplier → UPDATE
--     new supplier      → INSERT
--
-- DESIGN:
--     - SCD Type 1
--     - Existing records are overwritten
--     - No historical versions are maintained
--     - Initial and incremental loads use the same SQL
--     - No hash is required
--     - supplier_key is generated automatically by SERIAL
--     - Load is idempotent
-- ============================================================


-- BEGIN;

-- ============================================================
-- 1. MERGE SUPPLIERS
-- ============================================================

MERGE INTO warehouse.dim_suppliers AS target
USING intermediate.suppliers AS source
    ON target.supplier_id = source.supplier_id
WHEN MATCHED
AND (
       source.company_id IS DISTINCT FROM target.company_id
    OR source.supplier_name IS DISTINCT FROM target.supplier_name
    OR source.contact_name IS DISTINCT FROM target.contact_name
    OR source.email IS DISTINCT FROM target.email
    OR source.phone_number IS DISTINCT FROM target.phone_number
    OR source.created_at IS DISTINCT FROM target.created_at
    OR source.updated_at IS DISTINCT FROM target.updated_at
)

THEN
-- ============================================================
-- 2. UPDATE EXISTING SUPPLIERS
-- ============================================================
    UPDATE SET
        company_id    = source.company_id,
        supplier_name = source.supplier_name,
        contact_name  = source.contact_name,
        email         = source.email,
        phone_number  = source.phone_number,
        created_at    = source.created_at,
        updated_at    = source.updated_at

WHEN NOT MATCHED THEN
-- ============================================================
-- 3. INSERT NEW SUPPLIERS
-- ============================================================
    INSERT (
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


-- COMMIT;

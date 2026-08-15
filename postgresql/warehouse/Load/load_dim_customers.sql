-- ============================================================
-- CUSTOMERS WAREHOUSE LOAD
-- intermediate → warehouse
-- ============================================================
-- FILE: load_dim_customers.sql
--
-- PURPOSE:
--     Load intermediate.customers into warehouse.dim_customers
--     using SCD Type 1 behavior.
--
-- PIPELINE:
--     intermediate.customers
--        ↓
--     MERGE on customer_id
--        ↓
--     existing customer → UPDATE
--     new customer      → INSERT
--
-- DESIGN:
--     - SCD Type 1
--     - Existing records are overwritten
--     - No historical versions are maintained
--     - Initial and incremental loads use the same SQL
--     - customer_key is generated automatically by SERIAL
--     - Load is idempotent
--
-- CHANGE DETECTION:
--     Direct comparison of dimension attributes is used.
--     IS DISTINCT FROM is used so NULL changes are detected safely.
-- ============================================================


-- BEGIN;


-- ============================================================
-- 1. MERGE CUSTOMERS
-- ============================================================
MERGE INTO warehouse.dim_customers AS target
USING intermediate.customers AS source
    ON target.customer_id = source.customer_id
WHEN MATCHED
AND (source.company_id IS DISTINCT FROM target.company_id
    OR source.first_name IS DISTINCT FROM target.first_name
    OR source.last_name IS DISTINCT FROM target.last_name
    OR source.email IS DISTINCT FROM target.email
    OR source.phone_number IS DISTINCT FROM target.phone_number
    OR source.gender IS DISTINCT FROM target.gender
    OR source.date_of_birth IS DISTINCT FROM target.date_of_birth
    OR source.job_title IS DISTINCT FROM target.job_title
)
THEN
-- ============================================================
-- 2. UPDATE EXISTING CUSTOMERS
-- ============================================================
    UPDATE SET
        company_id    = source.company_id,
        first_name    = source.first_name,
        last_name     = source.last_name,
        email         = source.email,
        phone_number  = source.phone_number,
        gender        = source.gender,
        date_of_birth = source.date_of_birth,
        job_title     = source.job_title,
        created_at    = source.created_at,
        updated_at    = source.updated_at

WHEN NOT MATCHED THEN
-- ============================================================
-- 3. INSERT NEW CUSTOMERS
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


-- COMMIT;

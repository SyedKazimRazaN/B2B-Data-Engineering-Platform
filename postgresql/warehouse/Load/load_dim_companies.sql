/*
===============================================================================
DIM COMPANIES — WAREHOUSE LOAD
===============================================================================

Grain:
    One row per company version.

Business key:
    company_id

Surrogate key:
    company_key

Load strategy:
    SCD TYPE 2

Tracked attributes:
    company_name
    company_type
    cuit_tax_id
    rating
    country
    city
    address

SCD Type 2 behavior:
    - New company → INSERT as current version.
    - Changed company → expire current version and INSERT a new version.
    - Unchanged company → NO ACTION.

Effective dates:
    Initial version:
        effective_start_date = source.created_at

    New version after change:
        effective_start_date = source.updated_at

    Expired version:
        effective_end_date = source.updated_at

Current flag:
    is_current = TRUE  → active version
    is_current = FALSE → historical version

Change detection:
    IS DISTINCT FROM is used so NULL → value and value → NULL
    changes are detected correctly.

Idempotency:
    Unchanged company → no new version is created.
    Changed company → exactly one current version is maintained.

Execution Flow:

intermediate.companies
        │
        ▼
Check current warehouse version
        │
        ├── unchanged ─────────────→ NO ACTION
        │
        └── changed
              │
              ▼
        Expire current version
              │
              ▼
        Insert new current version

New company
      │
      ▼
Insert initial current version

===============================================================================
-- DIM COMPANIES
-- intermediate → warehouse
===============================================================================
*/

-- BEGIN;

-- ============================================================
-- SCD TYPE 2 — Step 1
-- Expire the current warehouse version when tracked
-- attributes have changed in the source.
--
-- We intentionally use a separate UPDATE/MERGE + INSERT pattern
-- rather than forcing SCD2 into a single MERGE statement.
-- ============================================================

MERGE INTO warehouse.dim_companies AS target
USING intermediate.companies AS source
    ON target.company_id = source.company_id
   AND target.is_current = TRUE

WHEN MATCHED
AND (
       source.company_name  IS DISTINCT FROM target.company_name
    OR source.company_type  IS DISTINCT FROM target.company_type
    OR source.cuit_tax_id   IS DISTINCT FROM target.cuit_tax_id
    OR source.rating        IS DISTINCT FROM target.rating
    OR source.country       IS DISTINCT FROM target.country
    OR source.city          IS DISTINCT FROM target.city
    OR source.address       IS DISTINCT FROM target.address
)
THEN
    UPDATE SET
        effective_end_date = source.updated_at,
        is_current = FALSE;


-- ============================================================
-- SCD TYPE 2 — Step 2
-- Insert:
--   1. brand-new companies
--   2. newly created versions of changed companies
--
-- If a company has no current warehouse version after Step 1,
-- it needs a current version inserted.
-- ============================================================

INSERT INTO warehouse.dim_companies (
    company_id,
    company_name,
    company_type,
    cuit_tax_id,
    rating,
    country,
    city,
    address,
    effective_start_date,
    effective_end_date,
    is_current
)
SELECT
    s.company_id,
    s.company_name,
    s.company_type,
    s.cuit_tax_id,
    s.rating,
    s.country,
    s.city,
    s.address,
    CASE
		WHEN NOT EXISTS (
	            SELECT 1
	            FROM warehouse.dim_companies h
	            WHERE h.company_id = s.company_id
	        )
        THEN s.created_at
        ELSE s.updated_at
    END AS effective_start_date,
    NULL AS effective_end_date,
    TRUE AS is_current

FROM intermediate.companies s
LEFT JOIN warehouse.dim_companies t
    ON t.company_id = s.company_id
   AND t.is_current = TRUE
WHERE t.company_id IS NULL;


-- COMMIT;


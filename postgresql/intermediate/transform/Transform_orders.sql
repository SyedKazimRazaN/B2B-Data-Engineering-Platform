-- ============================================================
-- ORDERS TRANSFORMATION
-- staging → intermediate
-- ============================================================
-- FILE: transform_orders.sql
-- PURPOSE:
--     Transform staging.orders into intermediate.orders
--
-- PIPELINE:
--     staging.orders
--        ↓
--     latest record per order_id
--        ↓
--     cleaning / normalization
--        ↓
--     business validation
--        ↓
--     MERGE into intermediate.orders
--
-- DESIGN GOALS:
--     - Keep the latest source record
--     - Normalize whitespace / empty strings
--     - Handle textual missing values
--     - Validate company business rules
--     - Make the load idempotent
-- ============================================================

/* ============================================================================
   7. Orders
   ============================================================================ */

WITH latest_orders AS (
    -- ====================================================
    -- 1. DEDUPLICATION
    -- ====================================================
    SELECT 
        order_id,
        customer_id,
        company_id,
        lead_id,
        order_date,
        order_status,
        payment_status,
        order_total,
        created_at,
        updated_at,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY _loaded_at DESC, updated_at DESC) AS rn
    FROM staging.orders
    WHERE order_id IS NOT NULL
),

clean_orders AS (
    -- ====================================================
    -- 2. CLEANING / NORMALIZATION
    -- ====================================================
    SELECT
        order_id,

        NULLIF(TRIM(customer_id), '') AS customer_id,
        NULLIF(TRIM(company_id), '') AS company_id,
        NULLIF(TRIM(lead_id), '') AS lead_id,

        order_date,

        NULLIF(TRIM(order_status), '') AS order_status,
        NULLIF(TRIM(payment_status), '') AS payment_status,

        order_total,

        created_at,
        updated_at

    FROM latest_orders
    WHERE rn = 1
),

validate_orders AS (
    -- ====================================================
    -- 2. BUSINESS VALIDATION
    -- ====================================================
    SELECT
        o.order_id,
        o.customer_id,
        o.company_id,
        o.lead_id,
        o.order_date,
        o.order_status,
        o.payment_status,
        o.order_total,
        o.created_at,
        o.updated_at
    FROM clean_orders o

    INNER JOIN intermediate.customers c
        ON c.customer_id = o.customer_id

    INNER JOIN intermediate.companies com
        ON com.company_id = o.company_id

    LEFT JOIN intermediate.marketing_leads m
        ON m.lead_id = o.lead_id

    WHERE o.customer_id IS NOT NULL
      AND o.company_id IS NOT NULL
      AND c.company_id = o.company_id
      AND (o.lead_id IS NULL OR m.lead_id IS NOT NULL)
      AND o.order_date IS NOT NULL
      AND o.order_status IN ('Pending','Confirmed','Processing','Shipped','Delivered','Cancelled')
      AND o.payment_status IN ('pending','paid','failed','refunded')
      AND o.order_total >= 0
      AND o.created_at IS NOT NULL
      AND o.updated_at IS NOT NULL
      AND o.updated_at >= o.created_at
      AND o.order_date >= c.created_at
)

MERGE INTO intermediate.orders AS target
USING validate_orders AS source
    ON target.order_id = source.order_id

WHEN MATCHED AND target.updated_at < source.updated_at THEN
	-- ============================================================
	-- 4. UPDATE EXISTING ORDERS
	-- ============================================================
    UPDATE SET
        customer_id = source.customer_id,
        company_id = source.company_id,
        lead_id = source.lead_id,
        order_date = source.order_date,
        order_status = source.order_status,
        payment_status = source.payment_status,
        order_total = source.order_total,
        created_at = source.created_at,
        updated_at = source.updated_at

WHEN NOT MATCHED THEN

	-- ============================================================
	-- 5. INSERT ORDERS
	-- ============================================================
    INSERT (
        order_id,
        customer_id,
        company_id,
        lead_id,
        order_date,
        order_status,
        payment_status,
        order_total,
        created_at,
        updated_at
    )
    VALUES (
        source.order_id,
        source.customer_id,
        source.company_id,
        source.lead_id,
        source.order_date,
        source.order_status,
        source.payment_status,
        source.order_total,
        source.created_at,
        source.updated_at
    );


-- ============================================================
-- 6. UPDATE MARKETING LEAD CONVERSION STATUS
-- ============================================================



UPDATE intermediate.marketing_leads AS ml
SET conversion_status = 'Converted'
FROM intermediate.orders AS o
WHERE o.lead_id = ml.lead_id
  AND ml.conversion_status = 'Not Converted';





































   
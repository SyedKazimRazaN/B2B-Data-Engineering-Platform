-- ============================================================
-- ORDER ITEMS TRANSFORMATION
-- staging → intermediate
-- ============================================================
-- FILE: transform_order_items.sql
-- PURPOSE:
--     Transform staging.order_items into intermediate.order_items
--
-- PIPELINE:
--     staging.orders
--        ↓
--     latest record per order_item_id
--        ↓
--     cleaning / normalization
--        ↓
--     business validation
--        ↓
--     MERGE into intermediate.order_item
--
-- DESIGN GOALS:
--     - Keep the latest source record
--     - Normalize whitespace / empty strings
--     - Handle textual missing values
--     - Validate company business rules
--     - Make the load idempotent
-- ============================================================

/* ============================================================================
   7. Order Items
   ============================================================================ */

   
WITH latest_order_items AS (
	-- ====================================================
	-- 1. DEDUPLICATION
	-- ====================================================
    SELECT
        order_item_id,
        order_id,
        supplier_product_id,
        quantity,
        unit_price,
        discount_amount,
        line_total,
        created_at,
        updated_at,
        ROW_NUMBER() OVER (PARTITION BY order_item_id ORDER BY _loaded_at DESC, updated_at DESC) AS rn
    FROM staging.order_items
    WHERE order_item_id IS NOT NULL
),

clean_order_items AS (
	-- ====================================================
	-- 2. CLEANING / NORMALIZATION
	-- ====================================================
    SELECT
        TRIM(order_item_id) AS order_item_id,
        TRIM(order_id) AS order_id,
        TRIM(supplier_product_id) AS supplier_product_id,
        quantity,
        unit_price,
        discount_amount,
        line_total,
        created_at,
        updated_at
    FROM latest_order_items
    WHERE rn = 1
),
validate_order_items AS (
	-- ====================================================
	-- 3. BUSINESS VALIDATION
	-- ====================================================
    SELECT oi.order_item_id,
        oi.order_id,
        oi.supplier_product_id,
        oi.quantity,
        oi.unit_price,
        oi.discount_amount,
        oi.line_total,
        oi.created_at,
        oi.updated_at
    FROM clean_order_items oi
    INNER JOIN intermediate.orders o
        ON o.order_id = oi.order_id
    INNER JOIN intermediate.supplier_product_mapping spm
        ON spm.supplier_product_id = oi.supplier_product_id
    WHERE oi.order_id IS NOT NULL
      AND oi.supplier_product_id IS NOT NULL
      AND oi.quantity > 0
      AND oi.unit_price >= 0
      AND oi.discount_amount >= 0
      AND oi.line_total >= 0
      AND oi.created_at IS NOT NULL
      AND oi.updated_at IS NOT NULL
      AND oi.updated_at >= oi.created_at
      -- Rule 7
      AND ROUND((oi.quantity * oi.unit_price) - oi.discount_amount, 2) = oi.line_total
)

MERGE INTO intermediate.order_items AS target
USING validate_order_items AS source
ON target.order_item_id = source.order_item_id

WHEN MATCHED
AND target.updated_at < source.updated_at THEN
UPDATE SET
	-- ============================================================
	-- 4. UPDATE EXISTING ORDER_ITEMS
	-- ============================================================
    order_id = source.order_id,
    supplier_product_id = source.supplier_product_id,
    quantity = source.quantity,
    unit_price = source.unit_price,
    discount_amount = source.discount_amount,
    line_total = source.line_total,
    created_at = source.created_at,
    updated_at = source.updated_at

WHEN NOT MATCHED THEN
	-- ============================================================
	-- 5. INSERT NEW ORDER_ITEMS
	-- ============================================================
    INSERT (
        order_item_id,
        order_id,
        supplier_product_id,
        quantity,
        unit_price,
        discount_amount,
        line_total,
        created_at,
        updated_at
    )
    VALUES (
        source.order_item_id,
        source.order_id,
        source.supplier_product_id,
        source.quantity,
        source.unit_price,
        source.discount_amount,
        source.line_total,
        source.created_at,
        source.updated_at
    );




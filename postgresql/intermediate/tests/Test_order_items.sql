-- ============================================================
-- FILE: test_order_items.sql
-- PURPOSE:
-- Data-quality tests for intermediate.order_items

-- EXPECTATION:
-- Each test should return ZERO rows.
-- ============================================================

-- ============================================================
-- TEST 1: DUPLICATE ORDER ITEM IDs
-- ============================================================

SELECT
order_item_id,
COUNT(*) AS duplicate_count
FROM intermediate.order_items
GROUP BY order_item_id
HAVING COUNT(*) > 1;

-- ============================================================
-- TEST 2: REQUIRED FIELDS
-- ============================================================

SELECT *
FROM intermediate.order_items
WHERE order_item_id IS NULL
OR order_id IS NULL
OR supplier_product_id IS NULL
OR quantity IS NULL
OR unit_price IS NULL
OR discount_amount IS NULL
OR line_total IS NULL
OR created_at IS NULL
OR updated_at IS NULL;

-- ============================================================
-- TEST 3: QUANTITY VALIDATION
-- ============================================================

SELECT *
FROM intermediate.order_items
WHERE quantity <= 0;

-- ============================================================
-- TEST 4: PRICE VALIDATION
-- ============================================================

SELECT *
FROM intermediate.order_items
WHERE unit_price < 0
OR discount_amount < 0
OR line_total < 0;

-- ============================================================
-- TEST 5: LINE TOTAL VALIDATION
-- ============================================================

-- line_total must equal:
-- quantity * unit_price - discount_amount.

SELECT
order_item_id,
quantity,
unit_price,
discount_amount,
line_total,
ROUND(
quantity * unit_price - discount_amount,
2
) AS expected_line_total
FROM intermediate.order_items
WHERE ROUND(
quantity * unit_price - discount_amount,
2
) <> line_total;

-- ============================================================
-- TEST 6: TIMESTAMP VALIDATION
-- ============================================================

-- updated_at must be >= created_at.

SELECT *
FROM intermediate.order_items
WHERE updated_at < created_at;

-- ============================================================
-- TEST 7: ORDER BUSINESS RULE
-- ============================================================

-- Every order item must belong to an existing order.

SELECT oi.*
FROM intermediate.order_items oi
LEFT JOIN intermediate.orders o
ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

-- ============================================================
-- TEST 8: SUPPLIER PRODUCT MAPPING
-- ============================================================

-- Every order item must reference an existing
-- supplier/product mapping.

SELECT oi.*
FROM intermediate.order_items oi
LEFT JOIN intermediate.supplier_product_mapping spm
ON spm.supplier_product_id = oi.supplier_product_id
WHERE spm.supplier_product_id IS NULL;

-- ============================================================
-- TEST 9: ORDER TOTAL RECONCILIATION
-- ============================================================

-- The sum of order-item line totals must equal
-- the corresponding order total.

SELECT
o.order_id,
o.order_total,
ROUND(SUM(oi.line_total), 2) AS calculated_order_total
FROM intermediate.orders o
JOIN intermediate.order_items oi
ON oi.order_id = o.order_id
GROUP BY
o.order_id,
o.order_total
HAVING ROUND(SUM(oi.line_total), 2) <> o.order_total;




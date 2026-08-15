/*
===============================================================================
FACT ORDER ITEMS — TESTS
===============================================================================
Expected result:
    Validation queries should return 0 rows unless otherwise stated.
===============================================================================
*/


-- ============================================================
-- TEST 1: Warehouse row count vs intermediate
-- ============================================================

SELECT
    (SELECT COUNT(*)
     FROM intermediate.order_items) AS intermediate_count,

    (SELECT COUNT(*)
     FROM warehouse.fact_order_items) AS warehouse_count;
-- "intermediate_count"	"warehouse_count"
--  96219	 96219

-- ============================================================
-- TEST 2: Duplicate order items
-- ============================================================

SELECT
    order_item_id,
    date_key,
    COUNT(*) AS row_count
FROM warehouse.fact_order_items
GROUP BY order_item_id, date_key
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 3: Every fact order item has a valid date_key
-- ============================================================

SELECT
    foi.order_item_id,
    foi.date_key
FROM warehouse.fact_order_items AS foi
LEFT JOIN warehouse.dim_date AS d
    ON d.date_key = foi.date_key
WHERE d.date_key IS NULL;


-- ============================================================
-- TEST 4: Every order item maps to a valid customer
-- ============================================================

SELECT
    foi.order_item_id,
    foi.customer_key
FROM warehouse.fact_order_items AS foi
LEFT JOIN warehouse.dim_customers AS c
    ON c.customer_key = foi.customer_key
WHERE c.customer_key IS NULL;


-- ============================================================
-- TEST 5: Every order item maps to a valid product
-- ============================================================

SELECT
    foi.order_item_id,
    foi.product_key
FROM warehouse.fact_order_items AS foi
LEFT JOIN warehouse.dim_products AS p
    ON p.product_key = foi.product_key
WHERE p.product_key IS NULL;


-- ============================================================
-- TEST 6: Every order item resolves to a valid supplier
-- ============================================================

SELECT
    foi.order_item_id,
    foi.supplier_key
FROM warehouse.fact_order_items AS foi
LEFT JOIN warehouse.dim_suppliers AS s
    ON s.supplier_key = foi.supplier_key
WHERE s.supplier_key IS NULL;


-- ============================================================
-- TEST 7: Every order item maps to a valid company
-- ============================================================

SELECT
    foi.order_item_id,
    foi.company_key
FROM warehouse.fact_order_items AS foi
LEFT JOIN warehouse.dim_companies AS c
    ON c.company_key = foi.company_key
WHERE c.company_key IS NULL;


-- ============================================================
-- TEST 8: Quantity must be positive
-- ============================================================

SELECT
    order_item_id,
    quantity
FROM warehouse.fact_order_items
WHERE quantity <= 0;


-- ============================================================
-- TEST 9: Unit price must not be negative
-- ============================================================

SELECT
    order_item_id,
    unit_price
FROM warehouse.fact_order_items
WHERE unit_price < 0;


-- ============================================================
-- TEST 10: Discount amount must not be negative
-- Expected: 0 rows
-- ============================================================

SELECT
    order_item_id,
    discount_amount
FROM warehouse.fact_order_items
WHERE discount_amount < 0;


-- ============================================================
-- TEST 11: Line total must not be negative
-- Expected: 0 rows
-- ============================================================

SELECT
    order_item_id,
    line_total
FROM warehouse.fact_order_items
WHERE line_total < 0;


-- ============================================================
-- TEST 12: Line total should equal quantity × unit price
--          adjusted for discount
-- Expected: 0 rows
-- ============================================================

SELECT *
FROM warehouse.fact_order_items
WHERE line_total != (quantity * unit_price - discount_amount);



-- ============================================================
-- TEST 13: Every order item belongs to an existing order
-- ============================================================

SELECT
    foi.order_item_id,
    foi.order_id
FROM warehouse.fact_order_items AS foi
LEFT JOIN warehouse.fact_orders AS fo
    ON fo.order_id = foi.order_id
WHERE fo.order_id IS NULL;


-- ============================================================
-- TEST 14: Every order has at least one order item
-- ============================================================

SELECT
    fo.order_id
FROM warehouse.fact_orders AS fo
LEFT JOIN warehouse.fact_order_items AS foi
    ON foi.order_id = fo.order_id
GROUP BY fo.order_id
HAVING COUNT(foi.order_item_id) = 0;


-- ============================================================
-- TEST 15: Idempotency check
-- Run load_fact_order_items.sql AGAIN, then compare counts.
-- ============================================================

SELECT COUNT(*) AS fact_order_items_count
FROM warehouse.fact_order_items;


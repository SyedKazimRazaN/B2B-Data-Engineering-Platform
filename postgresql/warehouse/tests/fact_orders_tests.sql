-- ============================================================
-- TESTS: FACT ORDERS
-- FILE: tests_fact_orders.sql
-- ============================================================


-- ============================================================
-- TEST 1: Fact row count matches intermediate orders
-- ============================================================
SELECT
    (SELECT COUNT(*)
     FROM intermediate.orders) AS intermediate_orders,

    (SELECT COUNT(*)
     FROM warehouse.fact_orders) AS warehouse_fact_orders;


-- ============================================================
-- TEST 2: No duplicate fact orders
-- Expected: 0 rows
-- ============================================================
SELECT
    order_id,
    COUNT(*) AS row_count
FROM warehouse.fact_orders
GROUP BY order_id
HAVING COUNT(*) > 1;


-- ============================================================
-- TEST 3: Every fact order has a valid date_key
-- Expected: 0 rows
-- ============================================================
SELECT f.order_id
FROM warehouse.fact_orders f
LEFT JOIN warehouse.dim_date d
    ON d.date_key = f.date_key
WHERE d.date_key IS NULL;


-- ============================================================
-- TEST 4: Every fact order has a valid customer_key
-- Expected: 0 rows
-- ============================================================
SELECT f.order_id
FROM warehouse.fact_orders f
LEFT JOIN warehouse.dim_customers c
    ON c.customer_key = f.customer_key
WHERE c.customer_key IS NULL;


-- ============================================================
-- TEST 5: Every fact order has a valid company_key
-- Expected: 0 rows
-- ============================================================
SELECT f.order_id
FROM warehouse.fact_orders f
LEFT JOIN warehouse.dim_companies c
    ON c.company_key = f.company_key
WHERE c.company_key IS NULL;


-- ============================================================
-- TEST 6: Every order contains at least one order item
-- Expected: 0 rows
-- ============================================================
SELECT
    f.order_id,
    f.item_count
FROM warehouse.fact_orders f
WHERE f.item_count <= 0;


-- ============================================================
-- TEST 7: item_count matches intermediate.order_items
-- Expected: 0 rows
-- ============================================================
WITH actual_counts AS (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM intermediate.order_items
    GROUP BY order_id
)
SELECT
    f.order_id,
    f.item_count AS fact_item_count,
    a.item_count AS actual_item_count
FROM warehouse.fact_orders f
JOIN actual_counts a
    ON a.order_id = f.order_id
WHERE f.item_count != a.item_count;


-- ============================================================
-- TEST 8: order_total cannot be negative
-- Expected: 0 rows
-- ============================================================
SELECT
    order_id,
    order_total
FROM warehouse.fact_orders
WHERE order_total < 0;


-- ============================================================
-- TEST 9: Order status contains only allowed values
-- Expected: 0 rows
-- ============================================================
SELECT
    order_id,
    order_status
FROM warehouse.fact_orders
WHERE order_status NOT IN (
    'Pending',
    'Confirmed',
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled'
);


-- ============================================================
-- TEST 10: Payment status contains only allowed values
-- Expected: 0 rows
-- ============================================================
SELECT
    order_id,
    payment_status
FROM warehouse.fact_orders
WHERE payment_status NOT IN (
    'pending',
    'paid',
    'failed',
    'refunded'
);

-- ============================================================
-- TEST 11: Fact order date matches date dimension
-- Expected: 0 rows
-- ============================================================
SELECT
    f.order_id,
    f.order_date_time,
    d.full_date
FROM warehouse.fact_orders f
JOIN warehouse.dim_date d
    ON d.date_key = f.date_key
WHERE f.order_date_time::DATE <> d.full_date;


-- ============================================================
-- TEST 12: Company surrogate key must represent the correct
-- SCD2 version for the order timestamp
-- Expected: 0 rows
-- ============================================================
SELECT
    f.order_id,
    f.company_key,
    f.order_date_time,
    c.effective_start_date,
    c.effective_end_date
FROM warehouse.fact_orders f
JOIN warehouse.dim_companies c
    ON c.company_key = f.company_key
WHERE f.order_date_time < c.effective_start_date
   OR (
        c.effective_end_date IS NOT NULL
        AND f.order_date_time >= c.effective_end_date
      );


-- ============================================================
-- TEST 13: Idempotency check
-- ============================================================

--ran load_fact_orders 2 times
--validating again
SELECT
    (SELECT COUNT(*)
     FROM intermediate.orders) AS intermediate_orders,

    (SELECT COUNT(*)
     FROM warehouse.fact_orders) AS warehouse_fact_orders;
-- same 
/* "intermediate_orders"	"warehouse_fact_orders"
32120	32120*/



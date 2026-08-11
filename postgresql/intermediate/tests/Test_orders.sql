-- ============================================================
-- FILE: test_orders.sql
-- PURPOSE:
-- Data-quality tests for intermediate.orders

-- EXPECTATION:
-- Each test should return ZERO rows.
-- ============================================================

-- ============================================================
-- TEST 1: DUPLICATE ORDER IDs
-- ============================================================

SELECT
order_id,
COUNT(*) AS duplicate_count
FROM intermediate.orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- ============================================================
-- TEST 2: REQUIRED FIELDS
-- ============================================================

SELECT *
FROM intermediate.orders
WHERE order_id IS NULL
OR customer_id IS NULL
OR company_id IS NULL
OR order_date IS NULL
OR order_status IS NULL
OR payment_status IS NULL
OR order_total IS NULL
OR created_at IS NULL
OR updated_at IS NULL;

-- ============================================================
-- TEST 3: ORDER STATUS VALIDATION
-- ============================================================

SELECT *
FROM intermediate.orders
WHERE order_status NOT IN (
'Pending',
'Confirmed',
'Processing',
'Shipped',
'Delivered',
'Cancelled'
);

-- ============================================================
-- TEST 4: PAYMENT STATUS VALIDATION
-- ============================================================

SELECT *
FROM intermediate.orders
WHERE payment_status NOT IN (
'pending',
'paid',
'failed',
'refunded'
);

-- ============================================================
-- TEST 5: ORDER TOTAL VALIDATION
-- ============================================================

SELECT *
FROM intermediate.orders
WHERE order_total < 0;

-- ============================================================
-- TEST 6: TIMESTAMP VALIDATION
-- ============================================================

-- updated_at must be >= created_at.

SELECT *
FROM intermediate.orders
WHERE updated_at < created_at;

-- ============================================================
-- TEST 7: CUSTOMER BUSINESS RULES
-- ============================================================

-- Customer must exist.

SELECT o.*
FROM intermediate.orders o
LEFT JOIN intermediate.customers c
ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL;

-- Order company must match customer's company.

SELECT
o.order_id,
o.company_id AS order_company,
c.company_id AS customer_company
FROM intermediate.orders o
JOIN intermediate.customers c
ON c.customer_id = o.customer_id
WHERE o.company_id <> c.company_id;

-- Order cannot exist before customer.

SELECT
o.order_id,
o.order_date,
c.created_at AS customer_created_at
FROM intermediate.orders o
JOIN intermediate.customers c
ON c.customer_id = o.customer_id
WHERE o.order_date < c.created_at;

-- ============================================================
-- TEST 8: COMPANY BUSINESS RULE
-- ============================================================

-- Order company must exist.

SELECT o.*
FROM intermediate.orders o
LEFT JOIN intermediate.companies c
ON c.company_id = o.company_id
WHERE c.company_id IS NULL;

-- ============================================================
-- TEST 9: MARKETING LEAD RELATIONSHIP
-- ============================================================

-- If lead_id is provided, the marketing lead must exist.

SELECT o.*
FROM intermediate.orders o
LEFT JOIN intermediate.marketing_leads l
ON l.lead_id = o.lead_id
WHERE o.lead_id IS NOT NULL
AND l.lead_id IS NULL;

-- ============================================================
-- TEST 10: ORDER ITEM RELATIONSHIP
-- ============================================================

-- Every order must have at least one order item.

SELECT
o.order_id,
COUNT(oi.order_item_id) AS item_count
FROM intermediate.orders o
LEFT JOIN intermediate.order_items oi
ON oi.order_id = o.order_id
GROUP BY o.order_id
HAVING COUNT(oi.order_item_id) = 0;

-- ============================================================
-- TEST 11: ORDER TOTAL RECONCILIATION
-- ============================================================

-- Order total must equal the sum of its order items.

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





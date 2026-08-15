/*
What is the grain?
	One order → one fact row
	
What is the business and primary key?
	business key: Order_id
	primary key: (order_id, date_key)
	
Which dimensions need surrogate-key resolution?
	    Date → date_key
   	 	Customer → customer_key
    	Company → company_key
		
Does any dimension require an SCD2 as-of join?
	Company → Yes, using order_date
    Match company_id + order_date against effective_start_date / effective_end_date

Is the fact insert-only or can existing facts change?
   Existing facts can change.

    order_status can change:
        Pending → Confirmed → Processing → Shipped → Delivered
        or → Cancelled

    payment_status can also change:
        pending → paid
        pending → failed
        paid → refunded

    Therefore:
        NOT MATCHED → INSERT
        MATCHED + changed attributes → UPDATE
        MATCHED + unchanged → NOTHING

How do we make reruns idempotent?
    MERGE matches using the fact table primary key. Primary key: (order_id, date_key)
    Same order with no changes → no action
	New order → Insert
	Existing order with changed attribute → Update
	
What validation proves the load is correct?
	    No duplicate order_id
    Every order has a valid date_key
    Every customer resolves to exactly one customer_key
    Every order resolves to exactly one valid SCD2 company_key
    item_count > 0
    order_total >= 0
    order_status satisfies allowed values
    payment_status satisfies allowed values
    item_count matches order_items
    Fact order count matches unique intermediate orders

Execution Flow:
intermediate.orders
        │
        ├──────────────→ order-level attributes
        │
        ├── order_items → COUNT(*) → item_count
        │
        ├── order_date → dim_date → date_key
        │
        ├── customer_id → dim_customers → customer_key
        │
        └── company_id + order timestamp
                         ↓
                    dim_companies
                         ↓
                  SCD2 as-of lookup
                         ↓
                    company_key
                         │
                         ▼
                    MERGE
                  /         \
             MATCHED      NOT MATCHED
                │              │
        update mutable      INSERT
          attributes


*/
-- ============================================================
-- FACT ORDERS WAREHOUSE LOAD
-- intermediate → warehouse
-- ============================================================
-- FILE: load_fact_orders.sql
--
-- PURPOSE:
--     Load intermediate.orders into warehouse.fact_orders.
--
-- DESIGN:
--     - Resolve warehouse surrogate keys
--     - Resolve company using SCD2 as-of lookup
--     - Derive item_count from order_items
--     - Idempotent MERGE
--     - Update changed orders
--     - Insert new orders
-- ============================================================

-- BEGIN;

WITH item_counts AS (
-- ============================================================
-- 1. Count order items
-- ============================================================
	SELECT
		order_id,
		COUNT(*) AS item_count
	FROM intermediate.order_items
	GROUP BY order_id
),

source_order_data AS (
-- ============================================================
-- 2. Prepare source order data
-- ============================================================
	SELECT 
		o.order_id,
        o.customer_id,
		o.company_id,
		o.lead_id,
        o.order_date,
        o.order_status,
        o.payment_status,
        ic.item_count, -- item_counts
        o.order_total
    FROM intermediate.orders AS o
	INNER JOIN item_counts AS ic
	ON ic.order_id = o.order_id
),

extracted_orders AS (
    -- ============================================================
    -- 3. Mapping warehouse surrogate keys
    -- ============================================================
    SELECT
        o.order_id,
        o.lead_id,
        d.date_key, -- dim_date
        o.order_date AS order_date_time,
        c.customer_key, -- dim_customers
        com.company_key, -- dim_company
        o.order_status,
        o.payment_status,
        o.item_count,
        o.order_total
    FROM source_order_data AS o
	INNER JOIN warehouse.dim_date d
	ON d.full_date = o.order_date::DATE

	INNER JOIN warehouse.dim_customers AS c
	ON c.customer_id = o.customer_id

	INNER JOIN warehouse.dim_companies AS com -- (AS-OF JOIN) Find the company version that was active when the order occurred
     ON com.company_id = o.company_id
     AND o.order_date >= com.effective_start_date
     AND (com.effective_end_date IS NULL OR o.order_date < com.effective_end_date)
)

MERGE INTO warehouse.fact_orders AS target
USING extracted_orders AS source
ON target.order_id = source.order_id
AND target.date_key = source.date_key

WHEN MATCHED AND (
/*NULL vs NULL → FALSE  (not different) thats why didnt used <>
NULL vs '123' → TRUE   (different) reason to use DISTINCT*/
	   source.lead_id         IS DISTINCT FROM target.lead_id 
    OR source.order_date_time      IS DISTINCT FROM target.order_date_time
    OR source.customer_key    IS DISTINCT FROM target.customer_key
    OR source.company_key     IS DISTINCT FROM target.company_key
    OR source.order_status    IS DISTINCT FROM target.order_status
    OR source.payment_status  IS DISTINCT FROM target.payment_status
    OR source.item_count      IS DISTINCT FROM target.item_count
    OR source.order_total     IS DISTINCT FROM target.order_total
)
THEN
-- ============================================================
-- UPDATE EXISTING ORDER
-- ============================================================
UPDATE SET
	lead_id          = source.lead_id,
    order_date_time  = source.order_date_time,
    customer_key     = source.customer_key,
    company_key      = source.company_key,
    order_status     = source.order_status,
    payment_status   = source.payment_status,
    item_count       = source.item_count,
    order_total      = source.order_total

WHEN NOT MATCHED THEN
-- ============================================================
-- INSERT NEW ORDERS
-- ============================================================
INSERT (
        order_id,
        lead_id,
        date_key,
        order_date_time,
        customer_key,
        company_key,
        order_status,
        payment_status,
        item_count,
        order_total
    )
    VALUES (
        source.order_id,
        source.lead_id,
        source.date_key,
        source.order_date_time,
        source.customer_key,
        source.company_key,
        source.order_status,
        source.payment_status,
        source.item_count,
        source.order_total
    );
-- COMMIT;







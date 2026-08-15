
/*
===============================================================================
FACT ORDER ITEMS — WAREHOUSE LOAD
===============================================================================
Grain:
    One row per order item.

Business key:
    order_item_id

Primary key:
    (order_item_id, date_key)

Surrogate keys:
    date      → date_key
    customer  → customer_key
    company   → company_key
    product   → product_key
    supplier  → supplier_key

SCD2 as-of:
    company → resolved using order date

Load strategy:
    INSERT for new items; UPDATE for order_status/payment_status only.

Reason:
    Order-item values represent the transaction at the time the order was
    placed. Transaction values such as quantity, unit price, discount,
    and line total are preserved and never updated. order_status and
    payment_status are denormalized from intermediate.orders and DO change
    after the item is first loaded (CDC order-status state machine,
    including cancellations) — those two columns get an update path so
    revenue KPIs that filter on order_status at line-item grain stay
    correct after a later cancellation/status change.


Idempotency:
    MERGE matches using (order_item_id, date_key).
    Existing items → update order_status/payment_status if changed.
    New items → INSERT.

Execution Flow:
intermediate.order_items
        │
        ├── supplier_product_mapping
        │       ├── product_id → dim_products → product_key
        │       └── supplier_id → dim_suppliers → supplier_key
        │
        ├── order_id → intermediate.orders
        │       ├── order_date → dim_date → date_key
        │       ├── customer_id → dim_customers → customer_key
        │       └── company_id + order timestamp
        │                         ↓
        │                    dim_companies
        │                         ↓
        │                  SCD2 as-of lookup
        │                         ↓
        │                    company_key
        │
        └── order-item attributes
                         │
                         ▼
                    MERGE
                       │
           ┌───────────┴───────────┐
           ▼                       ▼
      MATCHED +               NOT MATCHED
   status changed                  │
           │                       ▼
           ▼                    INSERT
   UPDATE status only
===============================================================================

-- ============================================================================
-- FACT ORDER ITEMS
-- intermediate → warehouse
-- ============================================================================

*/


-- BEGIN;

WITH source_order_item_data AS (
-- ============================================================
-- 1. Combine order items with supplier/product mapping
-- ============================================================
	SELECT 
		oi.order_item_id,
		oi.order_id,
		oi.supplier_product_id,
		oi.quantity,
		oi.unit_price,
		oi.discount_amount,
		oi.line_total,
		spm.supplier_id,
		spm.product_id
	FROM intermediate.order_items oi
	INNER JOIN intermediate.supplier_product_mapping spm
	ON spm.supplier_product_id = oi.supplier_product_id
),

extracted_order_items AS (
-- ============================================================
-- 2. Mapping warehouse surrogate keys
-- ============================================================
	SELECT 
		oi.order_item_id,
		oi.order_id,
		o.lead_id,
		d.date_key,
		c.customer_key,
		com.company_key,
		p.product_key,
		s.supplier_key,
		o.order_status,
		o.payment_status,
		oi.quantity,
		oi.unit_price,
		oi.discount_amount,
		oi.line_total
	FROM source_order_item_data oi
	
	INNER JOIN intermediate.orders o
	ON o.order_id = oi.order_id
	
	INNER JOIN warehouse.dim_date d
	ON d.full_date = o.order_date::DATE

	INNER JOIN warehouse.dim_customers AS c
	ON c.customer_id = o.customer_id

	INNER JOIN warehouse.dim_suppliers s
	ON s.supplier_id = oi.supplier_id
	
	INNER JOIN warehouse.dim_products p
    ON p.product_id = oi.product_id
	
	INNER JOIN warehouse.dim_companies AS com
	ON com.company_id = o.company_id
	AND o.order_date >= com.effective_start_date
	AND (com.effective_end_date IS NULL OR o.order_date < com.effective_end_date)
)


MERGE INTO warehouse.fact_order_items AS target
USING extracted_order_items AS source
ON target.order_item_id = source.order_item_id
AND target.date_key = source.date_key

WHEN MATCHED AND (
       source.order_status   IS DISTINCT FROM target.order_status
    OR source.payment_status IS DISTINCT FROM target.payment_status
)
THEN
-- ============================================================
-- UPDATE MUTABLE ORDER-LEVEL PAYMENT & ORDER STATUS
-- (quantity/price/discount/line_total are immutable transaction)
-- ============================================================
    UPDATE SET
        order_status   = source.order_status,
        payment_status = source.payment_status

WHEN NOT MATCHED THEN
-- ============================================================
-- INSERT NEW ORDER ITEMS
-- ============================================================
    INSERT (
        order_item_id,
        order_id,
        lead_id,
        date_key,
        customer_key,
        company_key,
        product_key,
        supplier_key,
        order_status,
        payment_status,
        quantity,
        unit_price,
        discount_amount,
        line_total
    )

    VALUES (
        source.order_item_id,
        source.order_id,
        source.lead_id,
        source.date_key,
        source.customer_key,
        source.company_key,
        source.product_key,
        source.supplier_key,
        source.order_status,
        source.payment_status,
        source.quantity,
        source.unit_price,
        source.discount_amount,
        source.line_total
	);
	
-- COMMIT;














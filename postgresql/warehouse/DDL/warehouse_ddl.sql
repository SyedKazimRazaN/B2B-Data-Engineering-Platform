/*
===============================================================================
SCHEMA: warehouse
===============================================================================

Purpose
-------
The warehouse uses a galaxy (fact constellation) schema with multiple fact
tables sharing conformed dimensions. It is built from the `intermediate`
schema for reporting and KPI analysis across sales, customers, traffic,
leads, suppliers, and pipeline health.

Design principles
------------------
1. Shared dimensions such as dim_date, dim_customers, and dim_companies are
   conformed across fact tables so the same dimensions can be used consistently
   across different business processes.

2. Dimension tables use SERIAL surrogate keys. Source *_id values are kept as
   CHAR(32) business keys.

3. dim_companies uses SCD Type 2 to keep historical changes such as rating and
   location. dim_customers, dim_suppliers, and dim_products use SCD Type 1.

4. Fact tables keep source business keys and use date_key in their composite
   primary keys because the fact tables are partitioned by date.

5. fact_orders stores one row per order, while fact_order_items stores one row
   per order item. Both facts are kept because they support different KPIs.

6. All fact tables are partitioned monthly by date_key to provide a
   consistent scalable design and enable partition pruning as data volume
   increases..

7. Cancelled orders are kept in the warehouse for history and audit purposes.
   KPI views decide whether cancelled orders should be included.

8. Pipeline_Watermarks and Pipeline_Run_Log stay in staging because they are
   pipeline control tables, not business facts.

9. B-tree indexes are used on business keys and fact foreign keys to support
    common joins and filters.

10. Fact-to-fact relationships such as order_id and lead_id are kept as
    business keys rather than foreign keys. They are used for analytical joins
    when needed.

All surrogate *_key columns are SERIAL (INT). All source *_id columns remain
CHAR(32), matching the UUID4 business keys generated in the staging and
intermediate layers.
===============================================================================
*/


-- ============================================================================
-- Schema initialization
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS warehouse
    AUTHORIZATION postgres;


-- ============================================================================
-- dim_date
-- ============================================================================
-- Calendar dimension used for date-based reporting and fact table partitioning.
-- Generated for the full project date range.
--
-- NOTE: Adjust v_start_date / v_end_date in line with config.py.
-- ============================================================================

CREATE TABLE warehouse.dim_date (
    date_key        INT             NOT NULL PRIMARY KEY,
    full_date       DATE            NOT NULL UNIQUE,
    day_of_month    INT             NOT NULL,
    day_of_week     INT             NOT NULL,
    day_name        VARCHAR(10)     NOT NULL,
    week_of_year    INT             NOT NULL,
    month_num       INT             NOT NULL,
    month_name      VARCHAR(10)     NOT NULL,
    quarter         INT             NOT NULL,
    year            INT             NOT NULL,
    is_weekend      BOOLEAN         NOT NULL,

    CONSTRAINT ck_dim_date_month
        CHECK (month_num BETWEEN 1 AND 12),

    CONSTRAINT ck_dim_date_quarter
        CHECK (quarter BETWEEN 1 AND 4),

    CONSTRAINT ck_dim_date_dow
        CHECK (day_of_week BETWEEN 1 AND 7)
);


-- ===========================================================================================================
-- dim_companies  (SCD Type 2)
-- ===========================================================================================================
-- Stores buyer and supplier companies. Type 2 keeps historical changes such
-- as rating and location.
--
-- Fact loads use the transaction date to resolve the correct company_key according to needed history/current.
-- ==========================================================================================================


CREATE TABLE warehouse.dim_companies (
    company_key             SERIAL          PRIMARY KEY,
    company_id              CHAR(32)        NOT NULL, --here not making company_id UNIQUE to support SCD-Type 2
    company_name            VARCHAR(200)    NOT NULL,
    company_type            VARCHAR(20)     NOT NULL,
    cuit_tax_id             VARCHAR(20)     NOT NULL,
    rating                  NUMERIC(2,1)    NOT NULL,
    country                 VARCHAR(100)    NOT NULL,
    city                    VARCHAR(100)    NOT NULL,
    address                 VARCHAR(255)    NOT NULL,
    effective_start_date    TIMESTAMP       NOT NULL,
    effective_end_date      TIMESTAMP       NULL,
    is_current              BOOLEAN         NOT NULL DEFAULT TRUE,

    CONSTRAINT ck_dim_companies_type
        CHECK (company_type IN ('Buyer', 'Supplier')),

    CONSTRAINT ck_dim_companies_rating
        CHECK (rating BETWEEN 1.0 AND 5.0),

    CONSTRAINT ck_dim_companies_dates
        CHECK (effective_end_date IS NULL OR effective_end_date > effective_start_date)
);

-- Enforces "at most one current version per company"
CREATE UNIQUE INDEX uq_dim_companies_current
    ON warehouse.dim_companies (company_id)
    WHERE is_current = TRUE;

-- ETL lookup: ELT upsert/as-of resolution matches incoming rows by company_id
CREATE INDEX idx_dim_companies_id
    ON warehouse.dim_companies (company_id);



-- ============================================================================
-- dim_customers  (SCD Type 1)
-- ============================================================================
-- Stores customer details and their company_id.
-- Type 1 updates overwrite the existing customer record.
-- ============================================================================

CREATE TABLE warehouse.dim_customers (
    customer_key    SERIAL          PRIMARY KEY,
    customer_id     CHAR(32)        NOT NULL UNIQUE,
    company_id      CHAR(32)        NOT NULL,
    first_name      VARCHAR(100)    NOT NULL,
    last_name       VARCHAR(100)    NOT NULL,
    email           VARCHAR(255)    NOT NULL,
    phone_number    VARCHAR(20)     NULL,
    gender          VARCHAR(20)     NULL,
    date_of_birth   DATE            NULL,
    job_title       VARCHAR(100)    NULL,
    created_at      TIMESTAMP       NOT NULL,
    updated_at      TIMESTAMP       NOT NULL,

    CONSTRAINT ck_dim_customers_gender
        CHECK (gender IN ('Male', 'Female'))
);


-- Supports "find all customers for this company" lookups/reports
CREATE INDEX idx_dim_customers_company
    ON warehouse.dim_customers (company_id);



-- ============================================================================
-- dim_suppliers  (SCD Type 1)
-- ============================================================================
-- Stores supplier details and their company_id.
-- Type 1 updates overwrite the existing supplier record.
-- ============================================================================


CREATE TABLE warehouse.dim_suppliers (
    supplier_key    SERIAL          PRIMARY KEY,
    supplier_id     CHAR(32)        NOT NULL UNIQUE, --here making all scd type1 tables id unique 
    company_id      CHAR(32)        NOT NULL,
    supplier_name   VARCHAR(200)    NOT NULL,
    contact_name    VARCHAR(150)    NULL,
    email           VARCHAR(255)    NOT NULL,
    phone_number    VARCHAR(20)     NULL,
    created_at      TIMESTAMP       NOT NULL,
    updated_at      TIMESTAMP       NOT NULL
);

-- Supports "find all suppliers for this company" lookups/reports
CREATE INDEX idx_dim_suppliers_company
    ON warehouse.dim_suppliers (company_id);



-- ============================================================================
-- dim_products  (SCD Type 1)
-- ============================================================================
-- Stores product details, category, and current pricing.
-- Category is kept in the product dimension because each product has one category.
-- Historical cost is stored in fact_order_items.
-- ============================================================================

CREATE TABLE warehouse.dim_products (
    product_key     SERIAL          PRIMARY KEY,
    product_id      CHAR(32)        NOT NULL UNIQUE,
    sku             VARCHAR(50)     NOT NULL,
    product_name    VARCHAR(200)    NOT NULL,
    category_id     CHAR(32)        NOT NULL,
    category_name   VARCHAR(150)    NOT NULL,
    brand           VARCHAR(100)    NOT NULL,
    variant         VARCHAR(100)    NOT NULL,
    cost_price      NUMERIC(10,2)   NOT NULL,
    catalog_price   NUMERIC(10,2)   NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL,
    updated_at      TIMESTAMP       NOT NULL,

    CONSTRAINT ck_dim_products_prices
        CHECK (
            catalog_price >= 0
            AND cost_price >= 0
            AND catalog_price >= cost_price
        )
);

-- Supports "revenue/products by category" KPI grouping and filtering
CREATE INDEX idx_dim_products_category
    ON warehouse.dim_products (category_id);




-- ============================================================================
-- fact_orders
-- ============================================================================
-- Grain: one row per order (header grain).
-- Business process: Order Fulfillment.
--
-- Stores order-level measures such as order_total and item_count, along with
-- customer, company, status, payment, and date information.
--
-- Used for order-level KPIs such as order count, AOV, and CLV.

-- Partitioned by date_key (monthly)
-- ============================================================================

CREATE TABLE warehouse.fact_orders (
    order_id            	CHAR(32)        NOT NULL,
    lead_id               	CHAR(32)        NULL,
    date_key                INT             NOT NULL,
    order_date_time         TIMESTAMP       NOT NULL,
    customer_key            INT             NOT NULL,
    company_key             INT             NOT NULL,
    order_status            VARCHAR(30)     NOT NULL,
    payment_status          VARCHAR(30)     NOT NULL,
    item_count              INT             NOT NULL,
    order_total             NUMERIC(12,2)   NOT NULL,

    CONSTRAINT pk_fact_orders
        PRIMARY KEY (order_id, date_key),

    CONSTRAINT fk_fo_date
        FOREIGN KEY (date_key) REFERENCES warehouse.dim_date (date_key),

    CONSTRAINT fk_fo_customer
        FOREIGN KEY (customer_key) REFERENCES warehouse.dim_customers (customer_key),

    CONSTRAINT fk_fo_company
        FOREIGN KEY (company_key) REFERENCES warehouse.dim_companies (company_key),

    CONSTRAINT ck_fo_status
        CHECK (order_status IN ('Pending','Confirmed','Processing','Shipped','Delivered','Cancelled')),

    CONSTRAINT ck_fo_payment
        CHECK (payment_status IN ('pending','paid','failed','refunded')),

    CONSTRAINT ck_fo_item_count
        CHECK (item_count > 0),

    CONSTRAINT ck_fo_total
        CHECK (order_total >= 0)

) PARTITION BY RANGE (date_key);


-- Monthly revenue trend / date-range filtering (KPI 1) and partition pruning
CREATE INDEX idx_fo_date      ON warehouse.fact_orders (date_key);
-- Customer Activity / CLV: orders per customer, AOV (KPI 5, 6)
CREATE INDEX idx_fo_customer  ON warehouse.fact_orders (customer_key);
-- Revenue by Company / CLV: orders per company (KPI 2, 5) — join fan-out avoided
CREATE INDEX idx_fo_company   ON warehouse.fact_orders (company_key);
-- Lead Quality vs Order Value (KPI 12): join to fact_leads on lead_id
CREATE INDEX idx_fo_lead      ON warehouse.fact_orders (lead_id);




-- ============================================================================
-- fact_order_items
-- ============================================================================
-- Grain: one row per order item (Lowest level grain)
-- Business process: Order Fulfillment
--
-- Stores line-level sales, product, supplier, pricing, and margin information.
--
-- Used for revenue, product, category, supplier, and margin analysis.
-- Partitioned by date_key (monthly)
-- ============================================================================


CREATE TABLE warehouse.fact_order_items (
    order_item_id           CHAR(32)        NOT NULL,	-- PK
    order_id                CHAR(32)        NOT NULL,	-- Business key; multiple items can belong to one order
    lead_id                 CHAR(32)        NULL,		-- again, treating as business key not a database foreign key , As per Kimball: Direct fact-to-fact joins break cardinality control and produce wrong data"
    date_key                INT             NOT NULL,	-- PK
    customer_key            INT             NOT NULL,	-- FK
    company_key             INT             NOT NULL,	-- FK
    product_key             INT             NOT NULL,	-- FK
    supplier_key            INT             NOT NULL,	
    order_status            VARCHAR(30)     NOT NULL,
    payment_status          VARCHAR(30)     NOT NULL,
    quantity                INT             NOT NULL,
    unit_price              NUMERIC(10,2)   NOT NULL,
    discount_amount         NUMERIC(10,2)   NOT NULL DEFAULT 0,
    line_total              NUMERIC(10,2)   NOT NULL,


    CONSTRAINT pk_fact_order_items
        PRIMARY KEY (order_item_id, date_key),

    CONSTRAINT uq_foi_order_supplier_product
        UNIQUE (order_id, supplier_key, product_key, date_key),

    CONSTRAINT fk_foi_date
        FOREIGN KEY (date_key) REFERENCES warehouse.dim_date (date_key),

    CONSTRAINT fk_foi_customer
        FOREIGN KEY (customer_key) REFERENCES warehouse.dim_customers (customer_key),

    CONSTRAINT fk_foi_company
        FOREIGN KEY (company_key) REFERENCES warehouse.dim_companies (company_key),

    CONSTRAINT fk_foi_product
        FOREIGN KEY (product_key) REFERENCES warehouse.dim_products (product_key),

    CONSTRAINT fk_foi_supplier
        FOREIGN KEY (supplier_key) REFERENCES warehouse.dim_suppliers (supplier_key),

    CONSTRAINT ck_foi_status
        CHECK (order_status IN ('Pending','Confirmed','Processing','Shipped','Delivered','Cancelled')),

    CONSTRAINT ck_foi_payment
        CHECK (payment_status IN ('pending','paid','failed','refunded')),

    CONSTRAINT ck_foi_quantity
        CHECK (quantity > 0),

    CONSTRAINT ck_foi_prices
        CHECK (
            unit_price >= 0
            AND discount_amount >= 0
            AND line_total >= 0
        )
) PARTITION BY RANGE (date_key);


-- Monthly revenue/margin trend (KPI 1) and partition pruning
CREATE INDEX idx_foi_date       ON warehouse.fact_order_items (date_key);
-- Customer Activity: per-customer line-item rollups (KPI 6)
CREATE INDEX idx_foi_customer   ON warehouse.fact_order_items (customer_key);
-- Revenue by Company / CLV / Geographic Sales (KPI 2, 5, 7)
CREATE INDEX idx_foi_company    ON warehouse.fact_order_items (company_key);
-- Revenue by Product/Category, Gross Margin (KPI 3, 4)
CREATE INDEX idx_foi_product    ON warehouse.fact_order_items (product_key);
-- Supplier Revenue, Supplier-Product Performance (KPI 13, 14)
CREATE INDEX idx_foi_supplier   ON warehouse.fact_order_items (supplier_key);
-- Lead Quality vs Order Value (KPI 12): join to fact_leads on lead_id
CREATE INDEX idx_foi_lead       ON warehouse.fact_order_items (lead_id);
-- Joining back to fact_orders (header grain) by order_id when needed
CREATE INDEX idx_foi_order      ON warehouse.fact_order_items (order_id);




-- ============================================================================
-- fact_web_logs
-- ============================================================================
-- Grain: one row per web request.
-- Business process: Web Traffic
--
-- Stores traffic, session, device, location, endpoint, and response details.
--
-- Used for traffic, device, geographic, and web activity analysis.
-- Partitioned by date_key (monthly)
-- ============================================================================

CREATE TABLE warehouse.fact_web_logs (
    log_id          CHAR(32)        NOT NULL,
    date_key        INT             NOT NULL,
    log_timestamp   TIMESTAMP       NOT NULL,
    country         VARCHAR(100)    NOT NULL,
    city            VARCHAR(100)    NOT NULL,
    client_ip       VARCHAR(45)     NOT NULL,
    auth_user       VARCHAR(150)    NULL,
    session_id      CHAR(32)        NOT NULL,
    http_method     VARCHAR(10)     NOT NULL,
    request_path    VARCHAR(255)    NOT NULL,
    status_code     INT             NOT NULL,
    bytes_sent      INT             NOT NULL,
    referer         VARCHAR(255)    NOT NULL,
    device_type     VARCHAR(30)     NOT NULL,
    browser         VARCHAR(50)     NOT NULL,
    is_bot          BOOLEAN         NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_fact_web_logs
        PRIMARY KEY (log_id, date_key),

    CONSTRAINT fk_fwl_date
        FOREIGN KEY (date_key) REFERENCES warehouse.dim_date (date_key),

    CONSTRAINT ck_fwl_status_code
        CHECK (status_code BETWEEN 100 AND 599),

    CONSTRAINT ck_fwl_bytes_sent
        CHECK (bytes_sent >= 0)
) PARTITION BY RANGE (date_key);


-- Geographic Web Traffic / daily trend (KPI 9) and partition pruning
CREATE INDEX idx_fwl_date     ON warehouse.fact_web_logs (date_key);
-- Session-level analysis (grouping requests into visits)
CREATE INDEX idx_fwl_session  ON warehouse.fact_web_logs (session_id);



-- ============================================================================
-- fact_leads
-- ============================================================================
-- Grain: one row per lead.
-- Business process: Lead Generation / Conversion
--
-- Stores lead source, campaign, funnel stage, score, conversion, and order information.
--
-- Used for lead conversion and lead quality analysis. order_id links converted
-- leads to their order using the source business key.
-- ============================================================================


CREATE TABLE warehouse.fact_leads (
    lead_id                     CHAR(32)        NOT NULL,
    date_key                    INT             NOT NULL,
    order_id                    CHAR(32)        NULL,
    source                      VARCHAR(100)    NOT NULL,
    campaign_name               VARCHAR(150)    NOT NULL,
    utm_source                  VARCHAR(100)    NOT NULL,
    utm_medium                  VARCHAR(100)    NOT NULL,
    utm_campaign                VARCHAR(150)    NOT NULL,
    lead_company_name           VARCHAR(200)    NOT NULL,
    company_size                VARCHAR(30)     NOT NULL,
    industry                    VARCHAR(100)    NOT NULL,
    country                     VARCHAR(100)    NOT NULL,
    city                        VARCHAR(100)    NOT NULL,
    lead_score                  INT             NOT NULL,
    estimated_order_value       NUMERIC(12,2)   NOT NULL,
    funnel_stage                VARCHAR(30)     NOT NULL,
    conversion_status           VARCHAR(30)     NOT NULL,

    CONSTRAINT pk_fact_leeds
        PRIMARY KEY (lead_id, date_key),

    CONSTRAINT fk_fl_date
        FOREIGN KEY (date_key) REFERENCES warehouse.dim_date (date_key),

    CONSTRAINT ck_fl_lead_score
        CHECK (lead_score BETWEEN 1 AND 100),

    CONSTRAINT ck_fl_order_value
        CHECK (estimated_order_value >= 0),

    CONSTRAINT ck_fl_conversion_status
        CHECK (conversion_status IN ('Converted', 'Not Converted'))
)PARTITION BY RANGE (date_key);

-- Lead Conversion Funnel: leads by month (KPI 11)
CREATE INDEX idx_fl_date    ON warehouse.fact_leads (date_key);
-- Lead Quality vs Order Value: join to fact_orders/fact_order_items (KPI 12)
CREATE INDEX idx_fl_order   ON warehouse.fact_leads (order_id);
-- Lead Conversion Funnel: grouping/filtering by funnel stage (KPI 11)
CREATE INDEX idx_fl_funnel  ON warehouse.fact_leads (funnel_stage);


-- ============================================================================
-- End of Warehouse DDL
-- ============================================================================
-- Load order:
--   1. dim_date       		(static — already populated above)
--   2. dim_companies   	(SCD2 merge from intermediate.companies)
--   3. dim_customers     	(SCD1 upsert from intermediate.customers)
--   4. dim_suppliers       (SCD1 upsert from intermediate.suppliers)
--   5. dim_products        (SCD1 upsert from intermediate.products + categories)
--   6. fact_orders         (as-of join to dim_companies; direct lookup for the rest)
--   7. fact_order_items    (same as-of join, independent of #6)
--   8. fact_web_logs
--   9. fact_leads
--
-- Transformation/load logic (SCD2 merge, as-of joins, watermark-based
-- incremental loads) is intentionally maintained separately from this
-- structural definition, same convention as intermediate_ddl.sql.
-- ============================================================================

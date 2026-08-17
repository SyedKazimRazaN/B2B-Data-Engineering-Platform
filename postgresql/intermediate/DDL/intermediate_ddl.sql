/*
===============================================================================
SCHEMA: intermediate
===============================================================================

Purpose
-------
The Intermediate layer contains the latest valid version of records
transformed from the PostgreSQL staging layer.

Unlike the raw staging layer, Intermediate enforces:
    - Primary keys
    - Foreign keys
    - Business and data-quality constraints
    - Uniqueness rules where applicable

Transformation logic such as deduplication and derived attributes is
implemented separately from this DDL.

Design principles
-----------------
1. One Intermediate table corresponds to each staging source table.
2. The staging-only `_loaded_at` ingestion metadata column is not carried
   into the Intermediate layer.
3. Primary keys identify the current record for each business entity.
4. Foreign keys enforce referential integrity between Intermediate entities.
5. CHECK constraints enforce valid business-domain values.
6. Derived attributes, such as `conversion_status`, are populated by the
   Intermediate transformation process.

All *_id columns use CHAR(32), matching:
    fake.uuid4().replace('-', '')
from the Python source-data generator.
===============================================================================
*/


-- ============================================================================
-- Schema initialization
-- ============================================================================

-- Creates the Intermediate schema if it does not already exist.
-- The schema contains cleaned, deduplicated, and validated records derived
-- from the staging layer.

CREATE SCHEMA IF NOT EXISTS intermediate
    AUTHORIZATION postgres;


-- ============================================================================
-- Companies
-- ============================================================================
-- Parent entity for customers and suppliers.
--
-- Data-quality rules:
--   * company_id uniquely identifies a company.
--   * company_name and cuit_tax_id must be unique.
--   * company_type is restricted to Buyer/Supplier.
--   * rating must be between 1.0 and 5.0.
--   * updated_at cannot precede created_at.
-- ============================================================================

CREATE TABLE intermediate.companies (
    company_id      CHAR(32)        NOT NULL PRIMARY KEY,
    company_name    VARCHAR(200)    NOT NULL UNIQUE,
    company_type    VARCHAR(20)     NOT NULL,
    cuit_tax_id     VARCHAR(20)     NOT NULL UNIQUE,
    rating          NUMERIC(2,1)    NOT NULL,
    country         VARCHAR(100)    NOT NULL,
    city            VARCHAR(100)    NOT NULL,
    address         VARCHAR(255)    NOT NULL,
    created_at      TIMESTAMP       NOT NULL,
    updated_at      TIMESTAMP       NOT NULL,

    CONSTRAINT ck_companies_type
        CHECK (company_type IN ('Buyer', 'Supplier')),

    CONSTRAINT ck_companies_rating
        CHECK (rating BETWEEN 1.0 AND 5.0),

    CONSTRAINT ck_companies_updated_after_created
        CHECK (updated_at >= created_at)
);


-- ============================================================================
-- Customers
-- ============================================================================
-- Customer records associated with a parent company.
--
-- Foreign-key dependency:
--   customers.company_id → companies.company_id
--
-- Data-quality rules:
--   * customer_id uniquely identifies a customer.
--   * email must be unique.
--   * gender, when provided, must be Male or Female.
--   * updated_at cannot precede created_at.
-- ============================================================================

CREATE TABLE intermediate.customers (
    customer_id     CHAR(32)        NOT NULL PRIMARY KEY,
    company_id      CHAR(32)        NOT NULL,
    first_name      VARCHAR(100)    NOT NULL,
    last_name       VARCHAR(100)    NOT NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    phone_number    VARCHAR(20)     NULL,
    gender          VARCHAR(20)     NULL,
    date_of_birth   DATE            NULL,
    job_title       VARCHAR(100)    NULL,
    created_at      TIMESTAMP       NOT NULL,
    updated_at      TIMESTAMP       NOT NULL,

    CONSTRAINT fk_customers_companies
        FOREIGN KEY (company_id)
        REFERENCES intermediate.companies(company_id),

    CONSTRAINT ck_customers_updatedaftercreated
        CHECK (updated_at >= created_at),

    CONSTRAINT ck_customers_gender
        CHECK (gender IN ('Male', 'Female'))
);


-- ============================================================================
-- Suppliers
-- ============================================================================
-- Supplier records associated with a parent company.
--
-- Foreign-key dependency:
--   suppliers.company_id → companies.company_id
--
-- Data-quality rules:
--   * supplier_id uniquely identifies a supplier.
--   * email must be unique.
--   * updated_at cannot precede created_at.
-- ============================================================================

CREATE TABLE intermediate.suppliers (
    supplier_id     CHAR(32)        NOT NULL PRIMARY KEY,
    company_id      CHAR(32)        NOT NULL,
    supplier_name   VARCHAR(200)    NOT NULL,
    contact_name    VARCHAR(150)    NULL,
    email           VARCHAR(255)    NOT NULL UNIQUE,
    phone_number    VARCHAR(20)     NULL,
    created_at      TIMESTAMP       NOT NULL,
    updated_at      TIMESTAMP       NOT NULL,

    CONSTRAINT fk_suppliers_companies
        FOREIGN KEY (company_id)
        REFERENCES intermediate.companies(company_id),

    CONSTRAINT ck_suppliers_updatedaftercreated
        CHECK (updated_at >= created_at)
);


-- ============================================================================
-- Categories
-- ============================================================================
-- Product classification reference table.
--
-- Data-quality rules:
--   * category_id uniquely identifies a category.
--   * category_name must be unique.
--   * updated_at cannot precede created_at.
-- ============================================================================

CREATE TABLE intermediate.categories (
    category_id     CHAR(32)        NOT NULL PRIMARY KEY,
    category_name   VARCHAR(150)    NOT NULL UNIQUE,
    created_at      TIMESTAMP       NOT NULL,
    updated_at      TIMESTAMP       NOT NULL,

    CONSTRAINT ck_categories_updatedaftercreated
        CHECK (updated_at >= created_at)
);


-- ============================================================================
-- Products
-- ============================================================================
-- Product master records associated with a product category.
--
-- Foreign-key dependency:
--   products.category_id → categories.category_id
--
-- Data-quality rules:
--   * product_id uniquely identifies a product.
--   * SKU must be unique.
--   * Prices cannot be negative.
--   * Catalog price cannot be lower than cost price.
--   * updated_at cannot precede created_at.
-- ============================================================================

CREATE TABLE intermediate.products (
    product_id      CHAR(32)        NOT NULL PRIMARY KEY,
    sku             VARCHAR(50)     NOT NULL UNIQUE,
    product_name    VARCHAR(200)    NOT NULL,
    category_id     CHAR(32)        NOT NULL,
    brand           VARCHAR(100)    NOT NULL,
    variant         VARCHAR(100)    NOT NULL,
    cost_price      NUMERIC(10,2)   NOT NULL,
    catalog_price   NUMERIC(10,2)   NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL,
    updated_at      TIMESTAMP       NOT NULL,

    CONSTRAINT fk_products_categories
        FOREIGN KEY (category_id)
        REFERENCES intermediate.categories(category_id),

    CONSTRAINT ck_products_prices
        CHECK (
            catalog_price >= 0
            AND cost_price >= 0
            AND catalog_price >= cost_price
        ),

    CONSTRAINT ck_products_updatedaftercreated
        CHECK (updated_at >= created_at)
);


-- ============================================================================
-- Supplier / Product Mapping
-- ============================================================================
-- Resolves the many-to-many relationship between suppliers and products.
--
-- Foreign-key dependencies:
--   supplier_id → suppliers.supplier_id
--   product_id  → products.product_id
--
-- Data-quality rules:
--   * Each supplier/product combination can occur only once.
--   * Supplier price cannot be negative.
--   * Lead time cannot be negative.
--   * updated_at cannot precede created_at.
-- ============================================================================

CREATE TABLE intermediate.supplier_product_mapping (
    supplier_product_id    CHAR(32)         NOT NULL PRIMARY KEY,
    supplier_id            CHAR(32)         NOT NULL,
    product_id             CHAR(32)         NOT NULL,
    supplier_price         NUMERIC(10,2)    NOT NULL,
    lead_time_days         INT              NOT NULL,
    is_preferred_supplier  BOOLEAN          NOT NULL DEFAULT FALSE,
    created_at             TIMESTAMP        NOT NULL,
    updated_at             TIMESTAMP        NOT NULL,

    CONSTRAINT fk_spm_suppliers
        FOREIGN KEY (supplier_id)
        REFERENCES intermediate.suppliers(supplier_id),

    CONSTRAINT fk_spm_products
        FOREIGN KEY (product_id)
        REFERENCES intermediate.products(product_id),

    CONSTRAINT ck_spm_price
        CHECK (supplier_price >= 0),

    CONSTRAINT ck_spm_leadtime
        CHECK (lead_time_days >= 0),

    CONSTRAINT ck_spm_updatedaftercreated
        CHECK (updated_at >= created_at),

    CONSTRAINT uq_spm_supplier_product
        UNIQUE (supplier_id, product_id)
);


-- ============================================================================
-- Marketing Leads
-- ============================================================================
-- Marketing acquisition records.
--
-- `conversion_status` is a derived Intermediate-layer attribute.
-- It is initialized to 'Not Converted' and subsequently recalculated from
-- the relationship between marketing leads and orders.
--
-- Data-quality rules:
--   * lead_score must be between 1 and 100.
--   * estimated_order_value cannot be negative.
--   * updated_at cannot precede created_at.
--   * conversion_status is restricted to the two supported business states.
-- ============================================================================

CREATE TABLE intermediate.marketing_leads (
    lead_id                 CHAR(32)        NOT NULL PRIMARY KEY,
    source                  VARCHAR(100)    NOT NULL,
    campaign_name           VARCHAR(150)    NOT NULL,
    utm_source              VARCHAR(100)    NOT NULL,
    utm_medium              VARCHAR(100)    NOT NULL,
    utm_campaign            VARCHAR(150)    NOT NULL,
    company_name            VARCHAR(200)    NOT NULL,
    company_size            VARCHAR(30)     NOT NULL,
    industry                VARCHAR(100)    NOT NULL,
    country                 VARCHAR(100)    NOT NULL,
    city                    VARCHAR(100)    NOT NULL,
    lead_score              INT             NOT NULL,
    estimated_order_value   NUMERIC(12,2)   NOT NULL,
    funnel_stage            VARCHAR(30)     NOT NULL,
    created_at              TIMESTAMP       NOT NULL,
    updated_at              TIMESTAMP       NOT NULL,
    conversion_status       VARCHAR(30)     NOT NULL
                                            DEFAULT 'Not Converted',

    CONSTRAINT ck_marketing_leads_score
        CHECK (lead_score BETWEEN 1 AND 100),

    CONSTRAINT ck_marketing_leads_order_value
        CHECK (estimated_order_value >= 0),

    CONSTRAINT ck_marketing_leads_updated_after_created
        CHECK (updated_at >= created_at),

    CONSTRAINT ck_marketing_leads_conversion_status
        CHECK (conversion_status IN ('Converted', 'Not Converted'))
);


-- ============================================================================
-- Orders
-- ============================================================================
-- Customer/company orders. An order may optionally originate from a
-- marketing lead.
--
-- Foreign-key dependencies:
--   customer_id → customers.customer_id
--   company_id  → companies.company_id
--   lead_id     → marketing_leads.lead_id
--
-- The marketing-lead relationship is enforced at the Intermediate layer
-- because both entities now reside in the same PostgreSQL database.
--
-- Data-quality rules:
--   * Order and payment statuses are restricted to supported values.
--   * Order total cannot be negative.
--   * updated_at cannot precede created_at.
-- ============================================================================

CREATE TABLE intermediate.orders (
    order_id        CHAR(32)        NOT NULL PRIMARY KEY,
    customer_id     CHAR(32)        NOT NULL,
    company_id      CHAR(32)        NOT NULL,
    lead_id         CHAR(32)        NULL,
    order_date      TIMESTAMP       NOT NULL,
    order_status    VARCHAR(30)     NOT NULL,
    payment_status  VARCHAR(30)     NOT NULL,
    order_total     NUMERIC(12,2)   NOT NULL,
    created_at      TIMESTAMP       NOT NULL,
    updated_at      TIMESTAMP       NOT NULL,

    CONSTRAINT ck_order_status
        CHECK (
            order_status IN (
                'Pending',
                'Confirmed',
                'Processing',
                'Shipped',
                'Delivered',
                'Cancelled'
            )
        ),

    CONSTRAINT ck_payment_status
        CHECK (
            payment_status IN (
                'pending',
                'paid',
                'failed',
                'refunded'
            )
        ),

    CONSTRAINT fk_orders_customers
        FOREIGN KEY (customer_id)
        REFERENCES intermediate.customers(customer_id),

    CONSTRAINT fk_orders_companies
        FOREIGN KEY (company_id)
        REFERENCES intermediate.companies(company_id),

    CONSTRAINT fk_orders_marketing_leads
        FOREIGN KEY (lead_id)
        REFERENCES intermediate.marketing_leads(lead_id),

    CONSTRAINT ck_orders_total
        CHECK (order_total >= 0),

    CONSTRAINT ck_orders_updatedaftercreated
        CHECK (updated_at >= created_at)
);


-- ============================================================================
-- Order Items
-- ============================================================================
-- Individual product lines belonging to an order.
--
-- Foreign-key dependencies:
--   order_id             → orders.order_id
--   supplier_product_id  → supplier_product_mapping.supplier_product_id
--
-- Data-quality rules:
--   * Quantity must be greater than zero.
--   * Prices and discounts cannot be negative.
--   * Each supplier/product combination can occur once per order.
--   * updated_at cannot precede created_at.
-- ============================================================================

CREATE TABLE intermediate.order_items (
    order_item_id       CHAR(32)        NOT NULL PRIMARY KEY,
    order_id            CHAR(32)        NOT NULL,
    supplier_product_id CHAR(32)        NOT NULL,
    quantity            INT             NOT NULL,
    unit_price          NUMERIC(10,2)   NOT NULL,
    discount_amount     NUMERIC(10,2)   NOT NULL DEFAULT 0,
    line_total          NUMERIC(10,2)   NOT NULL,
    created_at          TIMESTAMP       NOT NULL,
    updated_at          TIMESTAMP       NOT NULL,

    CONSTRAINT fk_orderitems_orders
        FOREIGN KEY (order_id)
        REFERENCES intermediate.orders(order_id),

    CONSTRAINT fk_orderitems_spm
        FOREIGN KEY (supplier_product_id)
        REFERENCES intermediate.supplier_product_mapping(supplier_product_id),

    CONSTRAINT ck_orderitems_quantity
        CHECK (quantity > 0),

    CONSTRAINT ck_orderitems_prices
        CHECK (
            unit_price >= 0
            AND discount_amount >= 0
            AND line_total >= 0
        ),

    CONSTRAINT ck_orderitems_updatedaftercreated
        CHECK (updated_at >= created_at),

    CONSTRAINT uq_order_product
        UNIQUE (order_id, supplier_product_id)
);


-- ============================================================================
-- Web Logs
-- ============================================================================
-- Web/application access logs.
--
-- `auth_user` is nullable because bot traffic may not have an authenticated
-- user associated with the request.
--
-- Data-quality rules:
--   * HTTP status codes must fall within the standard 100-599 range.
--   * bytes_sent cannot be negative.
-- ============================================================================

CREATE TABLE intermediate.web_logs (
    log_id          CHAR(32)        NOT NULL PRIMARY KEY,
    country         VARCHAR(100)    NOT NULL,
    city            VARCHAR(100)    NOT NULL,
    log_timestamp   TIMESTAMP       NOT NULL,
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

    CONSTRAINT ck_web_logs_status_code
        CHECK (status_code BETWEEN 100 AND 599),

    CONSTRAINT ck_web_logs_bytes_sent
        CHECK (bytes_sent >= 0)
);


-- ============================================================================
-- End of Intermediate DDL
-- ============================================================================
-- Transformation logic is intentionally maintained separately from this
-- structural definition.
--
-- Expected transformation flow:
--
--     STAGING
--        ↓
--     Deduplication / latest-record selection
--        ↓
--     Business transformations
--        ↓
--     INTERMEDIATE
--
-- ============================================================================

/*
===============================================================================
SCHEMA: staging
===============================================================================

Purpose
-------
The Staging layer is the raw landing zone for data extracted from source
systems and loaded into PostgreSQL.

Staging intentionally applies minimal transformation and validation.

Design principles
-----------------
1. Preserve source-system data as closely as practical.
2. Do not enforce primary keys or foreign keys at this layer.
3. Allow NULL values because source data may be incomplete or inconsistent.
4. Preserve duplicate records/versioned records for downstream processing.
5. Add `_loaded_at` to track when each record entered PostgreSQL staging.
6. Data cleansing, deduplication, validation, and business transformations
   are performed in the Intermediate layer.

Source systems
--------------
Source 1: SQL Server
    - Companies
    - Customers
    - Suppliers
    - Categories
    - Products
    - Supplier_Product_Mapping
    - Orders
    - Order_Items

Source 2: Web Logs
    - Snapshot-based ingestion
    - No source watermark

Source 3: Marketing Leads
    - Snapshot-based ingestion
    - No source watermark

Pipeline metadata is intentionally stored separately in the `metadata`
schema rather than inside `staging`.
===============================================================================
*/


-- ============================================================================
-- Schema initialization
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS staging
    AUTHORIZATION postgres;


-- ============================================================================
-- Source 1: SQL Server
-- ============================================================================
-- These tables receive raw/incremental records extracted from SQL Server.
--
-- No PK/FK/UNIQUE/CHECK constraints are intentionally applied here.
-- Duplicate and historical versions are preserved so that the Intermediate
-- layer can perform deterministic latest-record selection.
--
-- `_loaded_at` records the PostgreSQL ingestion timestamp and is used as
-- ingestion metadata rather than source business data.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Companies
-- ----------------------------------------------------------------------------

CREATE TABLE staging.companies (
    company_id      CHAR(32),
    company_name    VARCHAR(200),
    company_type    VARCHAR(20),
    cuit_tax_id     VARCHAR(20),
    rating          NUMERIC(2,1),
    country         VARCHAR(100),
    city            VARCHAR(100),
    address         VARCHAR(255),
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    _loaded_at      TIMESTAMP NOT NULL DEFAULT now()
);


-- ----------------------------------------------------------------------------
-- Customers
-- ----------------------------------------------------------------------------

CREATE TABLE staging.customers (
    customer_id     CHAR(32),
    company_id      CHAR(32),
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    email           VARCHAR(255),
    phone_number    VARCHAR(20),
    gender          VARCHAR(20),
    date_of_birth   DATE,
    job_title       VARCHAR(100),
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    _loaded_at      TIMESTAMP NOT NULL DEFAULT now()
);


-- ----------------------------------------------------------------------------
-- Suppliers
-- ----------------------------------------------------------------------------

CREATE TABLE staging.suppliers (
    supplier_id     CHAR(32),
    company_id      CHAR(32),
    supplier_name   VARCHAR(200),
    contact_name    VARCHAR(150),
    email           VARCHAR(255),
    phone_number    VARCHAR(20),
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    _loaded_at      TIMESTAMP NOT NULL DEFAULT now()
);


-- ----------------------------------------------------------------------------
-- Categories
-- ----------------------------------------------------------------------------

CREATE TABLE staging.categories (
    category_id     CHAR(32),
    category_name   VARCHAR(150),
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    _loaded_at      TIMESTAMP NOT NULL DEFAULT now()
);


-- ----------------------------------------------------------------------------
-- Products
-- ----------------------------------------------------------------------------

CREATE TABLE staging.products (
    product_id      CHAR(32),
    sku             VARCHAR(50),
    product_name    VARCHAR(200),
    category_id     CHAR(32),
    brand           VARCHAR(100),
    variant         VARCHAR(100),
    cost_price      NUMERIC(10,2),
    catalog_price   NUMERIC(10,2),
    is_active       BOOLEAN,
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    _loaded_at      TIMESTAMP NOT NULL DEFAULT now()
);


-- ----------------------------------------------------------------------------
-- Supplier / Product Mapping
-- ----------------------------------------------------------------------------

CREATE TABLE staging.supplier_product_mapping (
    supplier_product_id   CHAR(32),
    supplier_id           CHAR(32),
    product_id            CHAR(32),
    supplier_price        NUMERIC(10,2),
    lead_time_days        INT,
    is_preferred_supplier BOOLEAN,
    created_at             TIMESTAMP,
    updated_at             TIMESTAMP,
    _loaded_at             TIMESTAMP NOT NULL DEFAULT now()
);


-- ----------------------------------------------------------------------------
-- Orders
-- ----------------------------------------------------------------------------

CREATE TABLE staging.orders (
    order_id        CHAR(32),
    customer_id     CHAR(32),
    company_id      CHAR(32),
    lead_id         CHAR(32),
    order_date      TIMESTAMP,
    order_status    VARCHAR(30),
    payment_status  VARCHAR(30),
    order_total     NUMERIC(12,2),
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    _loaded_at      TIMESTAMP NOT NULL DEFAULT now()
);


-- ----------------------------------------------------------------------------
-- Order Items
-- ----------------------------------------------------------------------------

CREATE TABLE staging.order_items (
    order_item_id       CHAR(32),
    order_id            CHAR(32),
    supplier_product_id CHAR(32),
    quantity             INT,
    unit_price           NUMERIC(10,2),
    discount_amount      NUMERIC(10,2),
    line_total            NUMERIC(10,2),
    created_at            TIMESTAMP,
    updated_at            TIMESTAMP,
    _loaded_at            TIMESTAMP NOT NULL DEFAULT now()
);


-- ============================================================================
-- Source 2: Web Logs
-- ============================================================================
-- Web logs are loaded as snapshots rather than watermark-based incremental
-- extracts.
--
-- No source watermark is maintained for this dataset.
-- `_loaded_at` identifies when the snapshot record entered staging.
-- ============================================================================

CREATE TABLE staging.web_logs (
    log_id          CHAR(32),
    country         VARCHAR(100),
    city            VARCHAR(100),
    log_timestamp   TIMESTAMP,
    client_ip       VARCHAR(45),
    auth_user       VARCHAR(150),
    session_id      CHAR(32),
    http_method     VARCHAR(10),
    request_path    VARCHAR(255),
    status_code     INT,
    bytes_sent      INT,
    referer         VARCHAR(255),
    device_type     VARCHAR(30),
    browser         VARCHAR(50),
    is_bot          BOOLEAN,
    _loaded_at      TIMESTAMP NOT NULL DEFAULT now()
);


-- ============================================================================
-- Source 3: Marketing Leads
-- ============================================================================
-- Marketing leads are loaded as snapshots rather than watermark-based
-- incremental extracts.
--
-- `conversion_status` is intentionally absent from staging because it is
-- derived in the Intermediate layer from the relationship between leads
-- and orders.
--
-- `_loaded_at` identifies when the snapshot record entered staging.
-- ============================================================================

CREATE TABLE staging.marketing_leads (
    lead_id                 CHAR(32),
    source                  VARCHAR(100),
    campaign_name           VARCHAR(150),
    utm_source              VARCHAR(100),
    utm_medium              VARCHAR(100),
    utm_campaign            VARCHAR(150),
    company_name            VARCHAR(200),
    company_size            VARCHAR(30),
    industry                VARCHAR(100),
    country                 VARCHAR(100),
    city                    VARCHAR(100),
    lead_score              INT,
    estimated_order_value   NUMERIC(12,2),
    funnel_stage            VARCHAR(30),
    created_at              TIMESTAMP,
    updated_at              TIMESTAMP,
    _loaded_at              TIMESTAMP NOT NULL DEFAULT now()
);


-- ============================================================================
-- End of Staging DDL
-- ============================================================================


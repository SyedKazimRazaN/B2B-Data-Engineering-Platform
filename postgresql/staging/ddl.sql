-- ============================================================

-- ============================================================

CREATE SCHEMA IF NOT EXISTS staging;

-- ------------------------------------------------------------
-- Source 1 (SQL Server) — 8 tables
-- ------------------------------------------------------------

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

CREATE TABLE staging.categories (
    category_id     CHAR(32),
    category_name   VARCHAR(150),
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP,
    _loaded_at      TIMESTAMP NOT NULL DEFAULT now()
);

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

CREATE TABLE staging.supplier_product_mapping (
    supplier_product_id    CHAR(32),
    supplier_id             CHAR(32),
    product_id              CHAR(32),
    supplier_price          NUMERIC(10,2),
    lead_time_days          INT,
    is_preferred_supplier   BOOLEAN,
    created_at               TIMESTAMP,
    updated_at               TIMESTAMP,
    _loaded_at               TIMESTAMP NOT NULL DEFAULT now()
);

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

CREATE TABLE staging.order_items (
    order_item_id       CHAR(32),
    order_id             CHAR(32),
    supplier_product_id CHAR(32),
    quantity             INT,
    unit_price           NUMERIC(10,2),
    discount_amount      NUMERIC(10,2),
    line_total            NUMERIC(10,2),
    created_at            TIMESTAMP,
    updated_at            TIMESTAMP,
    _loaded_at            TIMESTAMP NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- Source 2 — Web Logs (snapshot-based, no watermark)
-- ------------------------------------------------------------

CREATE TABLE staging.web_logs (
    log_id          CHAR(32),
    country         VARCHAR(100),
    city            VARCHAR(100),
    "timestamp"     TIMESTAMP,
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

-- ------------------------------------------------------------
-- Source 3 — Marketing Leads (snapshot-based, no watermark)
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- Pipeline bookkeeping tables
-- ------------------------------------------------------------

CREATE TABLE staging.pipeline_watermarks (
    pipeline_name       VARCHAR(100) PRIMARY KEY,
    last_extracted_at   TIMESTAMP
);

CREATE TABLE staging.pipeline_run_log (
    run_id           CHAR(32) PRIMARY KEY,
    pipeline_name    VARCHAR(100),
    run_started_at   TIMESTAMP,
    run_ended_at     TIMESTAMP,
    rows_extracted   INT,
    rows_loaded      INT,
    watermark_used   TIMESTAMP,
    status           VARCHAR(20),
    error_message    TEXT
);

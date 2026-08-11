# B2B Data Platform — End-to-End ELT Pipeline

A Data Engineering internship project that implements an end-to-end **ELT data platform for a synthetic B2B e-commerce business**.

The platform simulates multiple operational data sources, continuously generates new and changed data, ingests the data into PostgreSQL, transforms it through an Intermediate layer, and will ultimately provide a dimensional Warehouse and analytical Marts for business KPIs.

The project is designed around realistic B2B e-commerce relationships including companies, customers, suppliers, products, orders, marketing leads, and web activity.

---

## Project Goal

The goal is to build a complete ELT pipeline covering:

```text
Data Generation
      ↓
Source Systems
      ↓
PostgreSQL Staging
      ↓
PostgreSQL Intermediate
      ↓
PostgreSQL Warehouse
      ↓
PostgreSQL Marts
      ↓
Business KPIs
```

The final platform is intended to support approximately **10–15 analytical KPI views** covering areas such as:

* Revenue
* Customers
* Orders
* Products
* Suppliers
* Marketing Leads
* Lead Conversion
* Web Traffic
* Operational Pipeline Performance

---

# Architecture

```text
                    PYTHON DATA GENERATORS
                            │
             ┌──────────────┼──────────────┐
             │              │              │
             ▼              ▼              ▼
        SQL Server       Web Logs      Marketing Leads
        Source 1        CSV Source       CSV Source
             │              │              │
             │              ▼              ▼
             │         Python Extract + Load
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                  PostgreSQL STAGING
                            │
                            ▼
                PostgreSQL INTERMEDIATE
                            │
                            ▼
                  PostgreSQL WAREHOUSE
                            │
                            ▼
                    PostgreSQL MARTS
                            │
                            ▼
                       KPI / Analytics
```

---

# Data Sources

The platform currently simulates three independent source systems.

## Source 1 — SQL Server

The primary operational source is SQL Server.

Data is generated using Python and persisted into SQL Server before being extracted into PostgreSQL.

### SQL Server entities

* Companies
* Customers
* Suppliers
* Categories
* Products
* Supplier Product Mapping
* Orders
* Order Items

The SQL Server source also supports simulated incremental changes through the CDC generator.

---

## Source 2 — Web Logs

Web logs are generated as CSV files by Python.

The generated records contain:

* Log ID
* Country
* City
* Timestamp
* Client IP
* Authenticated user
* Session ID
* HTTP method
* Request path
* HTTP status code
* Bytes sent
* Referer
* Device type
* Browser
* Bot indicator

Web logs are loaded directly into PostgreSQL Staging.

No downstream user-agent parsing or sessionization is required because `session_id`, `device_type`, and `browser` are generated directly at source.

---

## Source 3 — Marketing Leads

Marketing leads are generated as CSV files by Python and loaded directly into PostgreSQL Staging.

The source contains:

* Lead ID
* Source
* Campaign
* UTM information
* Company information
* Company size
* Industry
* Country
* City
* Lead score
* Estimated order value
* Funnel stage
* Created timestamp
* Updated timestamp

Leads intentionally do not contain customer/company foreign keys because a lead can exist before a corresponding customer or company record is created.

Lead conversion status is derived later in the Intermediate layer.

---

# Business Data Model

The project models the following business entities.

## Companies

Companies can represent either:

* Buyer companies
* Supplier companies

Companies are also the entity tracked historically using **SCD Type 2 in the Warehouse**.

---

## Customers

Customers belong only to Buyer companies.

```text
Company
   │
   └── Customer
```

The number of customers per company is generated within the configured business range.

---

## Suppliers

Suppliers belong only to Supplier companies.

```text
Company
   │
   └── Supplier
```

---

## Products

Each product belongs to one category.

```text
Category
   │
   └── Product
```

---

## Supplier Product Mapping

A product can have multiple suppliers.

The mapping stores supplier-specific information such as:

* Supplier price
* Lead time
* Preferred supplier indicator

```text
Supplier ─────┐
              ├── Supplier_Product_Mapping ─── Product
Product ──────┘
```

This creates the many-to-many relationship between suppliers and products.

---

## Orders

Each order belongs to one customer and one company.

Orders may optionally originate from a marketing lead.

```text
Customer
    │
    └── Order
          │
          └── Order Items
```

The `company_id` is also retained directly on Orders for query convenience.

---

## Order Items

Each order contains one or more order items.

Each order item references a supplier-product mapping.

```text
Order
  │
  └── Order Item
          │
          └── Supplier Product Mapping
```

The order total is generated from the order-item line totals.

```text
Order Total = SUM(Order Item Line Total)
```

---

## Marketing Leads

Marketing leads are initially independent of customers and companies.

A Won lead generates exactly one lead-originated order.

Therefore:

```text
Total Orders
=
Repeat Customer Orders
+
Won Lead Orders
```

Lead conversion status is calculated in the Intermediate layer by checking whether the lead has a corresponding order.

---

## Web Logs

Web logs form an independent analytical stream.

They are not directly foreign-key-linked to the core B2B transactional entities.

They are connected later at the analytical layer through dimensions and business reporting logic.

---

# Business Rules

The synthetic data generation follows the project's defined business rules.

### Rule 1 — Customers

Customers belong only to Buyer companies.

### Rule 2 — Suppliers

Suppliers belong only to Supplier companies.

### Rule 3 — Products

Each product belongs to exactly one category.

### Rule 4 — Multiple Suppliers

Products can have multiple suppliers through `Supplier_Product_Mapping`.

### Rule 5 — Orders

Each order belongs to one customer.

Orders cannot predate the customer who placed them.

### Rule 6 — Order Items

Every order contains one or more order items.

### Rule 7 — Order Total

Order totals are calculated from order-item line totals.

```text
order_total = SUM(line_total)
```

### Rule 8 — Lead Conversion

Every Won lead generates exactly one order.

Leads without a matching order are considered not converted.

Conversion status is calculated in the Intermediate layer rather than stored in Staging.

### Rule 9 — Timestamps

```text
updated_at >= created_at
```

### Rule 10 — Cancelled Orders

Cancelled orders remain available for auditability but are excluded from revenue KPIs.

### Rule 11 — Incremental Extraction

SQL Server extraction uses a watermark based on `updated_at`.

Only records changed since the previous successful extraction are processed.

### Rule 12 — Company SCD Type 2

Company historical attributes are tracked in the Warehouse using SCD Type 2.

When a tracked company attribute changes:

1. The existing current record is closed.
2. A new version is created.
3. The new version becomes the current record.

---

# Data Generation

Python is responsible for generating the synthetic operational data.

## Master Generator

The Master Generator creates the initial master datasets:

* Companies
* Categories
* Customers
* Suppliers
* Products
* Supplier Product Mapping

These datasets establish the base business relationships.

---

## Transaction Generator

The Transaction Generator produces transactional and event data:

* Marketing Leads
* Orders
* Order Items
* Web Logs

Orders and Order Items are generated using the already-persisted master data from SQL Server so that generated transactions reference real existing entities.

---

## CDC Generator

The CDC generator simulates operational changes after the initial data load.

It supports:

* New records
* Updated records
* Simulated incremental changes
* Source-system CDC behavior

The SQL Server pipeline subsequently extracts these changes using the source `updated_at` watermark.

---

# Data Generation & CDC Flow

```text
Master Generator
      │
      ▼
Initial SQL Server Data
      │
      ▼
Transaction Generator
      │
      ├── Marketing Leads
      ├── Orders
      ├── Order Items
      └── Web Logs
      │
      ▼
CDC Generator
      │
      ├── Inserts
      ├── Updates
      └── Incremental Changes
      │
      ▼
ELT Pipelines
```

---

# PostgreSQL ELT Architecture

## Staging Layer

The Staging layer receives data from the three source systems with minimal transformation.

Current Staging entities include:

* Companies
* Customers
* Suppliers
* Categories
* Products
* Supplier Product Mapping
* Orders
* Order Items
* Web Logs
* Marketing Leads

Pipeline metadata also supports the ingestion process.

---

## Intermediate Layer

The Intermediate layer is responsible for transformation and preparation of source data for analytical modeling.

Current Intermediate datasets include:

* Companies
* Customers
* Suppliers
* Categories
* Products
* Supplier Product Mapping
* Orders
* Order Items
* Web Logs
* Marketing Leads

Transformations are implemented as separate SQL scripts.

Location:

```text
postgresql/intermediate/transform/
```

Current transformation scripts include:

```text
Transform_categories.sql
Transform_companies.sql
Transform_customers.sql
Transform_marketing_leads.sql
Transform_orders.sql
Transform_order_items.sql
Transform_products.sql
Transform_suppliers.sql
Transform_supplier_product_mapping.sql
Transform_web_logs.sql
```

---

# Data Quality & Validation

Validation SQL scripts are maintained under:

```text
postgresql/intermediate/tests/
```

Tests cover:

* Companies
* Customers
* Categories
* Suppliers
* Products
* Supplier Product Mapping
* Marketing Leads
* Orders
* Order Items
* Web Logs

The Intermediate layer is validated before downstream Warehouse development.

---

# Incremental SQL Server Extraction

The SQL Server pipeline uses a watermark-based extraction strategy.

Conceptually:

```text
Last Successful Watermark
          │
          ▼
SQL Server
          │
          │ updated_at > watermark
          ▼
Changed Records
          │
          ▼
PostgreSQL Staging
          │
          ▼
Successful Load
          │
          ▼
Update Watermark
```

This allows the pipeline to process new and changed operational records without repeatedly extracting the complete SQL Server source.

---

# Pipeline Metadata

The project includes pipeline execution and watermark tracking.

Pipeline metadata is used to support:

* Pipeline execution tracking
* Row-count monitoring
* Pipeline status
* Error tracking
* Watermark management
* Basic pipeline observability

The project also maintains pipeline logs under:

```text
logs/pipeline.log
```

---

# Pipeline Execution

The current pipeline can be executed from the project root using Python module execution.

```bash
python -m python.pipelines.run_pipeline incremental
```

The incremental execution currently performs the following flow:

```text
1. Generate incremental source data
2. Apply simulated CDC updates
3. Load new source data
4. Extract SQL Server changes
5. Load SQL Server data into PostgreSQL Staging
6. Load Marketing Leads into PostgreSQL Staging
7. Load Web Logs into PostgreSQL Staging
8. Transform Staging → Intermediate
9. Validate/commit Intermediate transformations
```

---

# Project Structure

```text
B2B-Data-Platform/
│
├── .env
├── .gitignore
├── README.md
├── requirements.txt
│
├── config/
│   ├── config.py
│   └── database.py
│
├── data/
│   ├── marketing_leads/
│   │   └── marketing_leads.csv
│   │
│   └── web_logs/
│       └── web_logs.csv
│
├── docs/
│   └── project_plan.md
│
├── logs/
│   └── pipeline.log
│
├── postgresql/
│   │
│   ├── staging/
│   │   └── staging_ddl.sql
│   │
│   ├── intermediate/
│   │   ├── DDL/
│   │   │   └── intermediate_ddl.sql
│   │   ├── transform/
│   │   └── tests/
│   │
│   ├── warehouse/
│   │
│   ├── marts/
│   │
│   └── metadata/
│       └── metadata_ddl.sql
│
├── python/
│   ├── generators/
│   │   ├── master_generator.py
│   │   ├── transaction_generator.py
│   │   ├── cdc_generator.py
│   │   └── load_to_sqlserver.py
│   │
│   ├── pipelines/
│   │   ├── run_pipeline.py
│   │   ├── sql_server_pipeline.py
│   │   ├── marketing_leads_pipeline.py
│   │   └── web_logs_pipeline.py
│   │
│   └── utils/
│       ├── constants.py
│       ├── logger.py
│       ├── pipeline_utils.py
│       └── seed_manager.py
│
└── sql_server/
    ├── exploration/
    │   └── dataset_validations.sql
    │
    ├── metadata/
    │   └── ddl-metadata.sql
    │
    └── source1/
        └── ddl-source1.sql
```

---

# Technology Stack

## Programming

* Python
* Pandas

## Databases

* Microsoft SQL Server
* PostgreSQL

## Data Engineering

* ELT
* CDC simulation
* Incremental ingestion
* Watermark-based extraction
* SQL transformations
* Data quality validation
* Pipeline metadata
* Pipeline logging
* Dimensional modeling

---

# Development Milestones

## Milestone 1 — Project Setup & Source Data Generation

**Completed**

Implemented:

* Project architecture
* Centralized configuration
* Database connections
* Business constants
* Synthetic master data generation
* Transaction generation
* SQL Server master data loading
* Two-year historical backfill

Generated entities include:

* Companies
* Categories
* Customers
* Suppliers
* Products
* Supplier Product Mapping
* Marketing Leads
* Orders
* Order Items
* Web Logs

---

## Milestone 2 — CDC & Continuous Source Simulation

**Completed**

Implemented:

* CDC generator
* Incremental source changes
* New records
* Updated records
* Continuous ingestion simulation
* SQL Server source updates

---

## Milestone 3 — ELT Ingestion & Staging

**Completed**

Implemented:

* SQL Server ingestion pipeline
* Marketing Leads ingestion pipeline
* Web Logs ingestion pipeline
* PostgreSQL Staging schema
* Watermark-based SQL Server extraction
* Pipeline execution metadata
* Pipeline logging

---

## Milestone 4 — Intermediate Layer

**Completed**

Implemented:

* Staging → Intermediate transformations
* Intermediate DDL
* Transformation SQL
* Intermediate data validation
* Transformation execution through the pipeline

The current pipeline successfully populates the Intermediate layer from the three source streams.

---

## Milestone 5 — Warehouse

**IN DEVELOPMENT**

DEVELOPING:

* Dimensional warehouse design
* Dimension tables
* Fact tables
* Company SCD Type 2
* Fact/dimension relationships
* Warehouse validation
* Reconciliation against Intermediate

---

## Milestone 6 — Marts & Analytics

**Planned**

The Marts layer will provide business-facing datasets and KPI views.

Target analytical areas include:

* Revenue
* Customer performance
* Order performance
* Product/category performance
* Supplier performance
* Marketing lead performance
* Lead conversion
* Web traffic
* Pipeline execution metrics

The final KPI design will be based on the Warehouse and actual business requirements rather than duplicating Warehouse structures unnecessarily.

---



# Execution Documentation

The README currently documents the architecture and the main pipeline command.

A more detailed **execution/setup guide will be finalized near project completion**, once the Warehouse and Marts layers are implemented.

The final guide will document:

* Environment setup
* Required dependencies
* Database configuration
* SQL Server setup
* PostgreSQL setup
* Initial data generation
* Historical backfill
* Incremental execution
* Warehouse execution
* Marts/KPI execution
* Validation procedures

This avoids documenting commands that may change while the remaining milestones are being implemented.

---

# Git Milestone History

Major implementation stages are tracked through Git commits.

### July 30, 2026

**Initialize project structure**

Initial repository structure and project foundation.

### July/August 2026

**Added centralized project configuration**

Centralized project configuration.

**Create constants.py and added business constants for data generation**

Centralized business-generation constants.

**Configured SQL Server and PostgreSQL database connections**

Database connectivity established.

### August 5, 2026

**Transaction generator + SQL Server master data load**

Synthetic transaction generation and SQL Server source population implemented.

### August 6, 2026

**CDC generator + SQL Server population completed + 2years backfill + continuous ingestion complete**

Historical backfill, CDC simulation, and continuous/incremental source generation completed.

### August 7, 2026

**ELT pipelines, staging schema populated**

Source ingestion pipelines and PostgreSQL Staging layer completed.

### Current

**Milestone 4 — Intermediate Layer**

Staging-to-Intermediate transformations and validation completed.

---

# Final Target Architecture

The completed platform will follow:

```text
                    DATA SOURCES
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
      SQL Server      Web Logs      Marketing Leads
          │              │              │
          └──────────────┼──────────────┘
                         ▼
                    STAGING
                         │
                         ▼
                   INTERMEDIATE
                         │
                         ▼
                    WAREHOUSE
                         │
                         ▼
                      MARTS
                         │
                         ▼
                  KPI / ANALYTICS(Power-BI)
```

The architecture is intentionally layered so that ingestion, transformation, analytical modeling, and business reporting remain separated and independently testable.

---

# Project Objective

The final result will demonstrate a practical end-to-end Data Engineering workflow:

```text
Generate
   ↓
Ingest
   ↓
Track Changes
   ↓
Stage
   ↓
Transform
   ↓
Model
   ↓
Validate
   ↓
Aggregate
   ↓
Analyze
```

The primary focus is on building a reliable and understandable ELT platform while avoiding unnecessary architectural complexity.

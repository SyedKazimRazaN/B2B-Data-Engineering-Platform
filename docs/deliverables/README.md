# Project Deliverables — Document Set

Documents requested by the Team Lead, following the delivery flow:

```text
BRD (given) → Analyze (ISD + Source ERD) → Modeling (LDM + PDM) → SMX / SMD → Architecture → Development → Testing (Unit + Integration) → KPI
```

| # | File | Document | Figures to insert |
|---|------|----------|-------------------|
| 01 | `01_ISD_Interface_Specification.docx` | Interface Specification Document | `docs/images/08-interface-diagram-isd.png` |
| 02 | `02_Source_System_Analysis_ERD.docx` | Source System Analysis & ERD | `docs/images/05-source-system-erd.png` |
| 03 | `03_LDM_Logical_Data_Model.docx` | Logical Data Model | `docs/images/07-logical-data-model-ldm.png` |
| 04 | `04_PDM_Physical_Data_Model.docx` + `04b_Data_Dictionary.xlsx` | Physical Data Model + column dictionary | `docs/images/06-physical-data-model-pdm.png` |
| 05 | `05_SMX_Source_to_Target_Mapping.xlsx` + `05_SMD_Source_Mapping_Document.docx` | Source-to-target mapping (sheet + narrative) | `docs/images/02-data-flow-diagram.png` (optional) |
| 06 | `06_Architecture_Document.docx` | Architecture | `01-architecture-diagram.png`, `02-data-flow-diagram.png`, `04-end-to-end-flow.png` |
| 07 | `07_Development_Document.docx` | Development / technical design | screenshots below |
| 08 | `08_Test_Document.docx` + `08b_Test_Case_Register.xlsx` | Unit & integration testing | screenshots below |
| 09 | `09_KPI_Definition_Document.docx` | KPI definitions & validation | dashboard screenshots in `docs/images/` |

Grey `[Guidance: …]` text and `[ ]` placeholders are to be replaced with content. After editing in Word, right-click the table of contents → **Update Field → Update entire table**.

## Screenshots to capture (updated 30/09/2026)

Save them in `docs/images/screenshots/` with the file names below. The old S1-S15 files in that
folder are from the old data — replace them.

**Before you start:** don't run `run_pipeline incremental` again until all screenshots are taken
(it adds a new day of data and the numbers in the documents would no longer match).
The one exception is S1, which needs a run — take S1 **last**.

| # | File name | Where / how | Used in |
|---|-----------|-------------|---------|
| S1 | `s01-pipeline-run-terminal.png` | **Take last.** VS Code terminal after `python -m python.pipelines.run_pipeline incremental` — scroll to show "Every staging row is in intermediate or rejected_records", "Staging tables cleared" and "All Warehouse loads completed", plus the Windows toast | 07, 08 |
| S2 | `s02-pipeline-run-log.png` | pgAdmin/DBeaver: `SELECT pipeline_name, status, rows_extracted, rows_loaded, run_started_at, run_ended_at FROM metadata.pipeline_run_log ORDER BY run_started_at DESC LIMIT 10;` | 01, 07, 08 |
| S3 | `s03-watermarks.png` | `SELECT * FROM metadata.pipeline_watermarks ORDER BY pipeline_name;` | 01 |
| S4 | `s04-source-row-counts.png` | SSMS: run the row-count section of `sql_server/exploration/dataset_validations.sql` | 02 |
| S5 | `s05M-csv-sample.png` (marketing leads), `s05W-csv-sample.png` (web logs) | First ~15 rows of `data/marketing_leads/marketing_leads.csv` and `data/web_logs/web_logs.csv` (VS Code or Excel) | 01, 02 |
| S6 | `s06-staging-cleared.png` | **Changed:** staging is empty after a run — query "Staging cleared" below | 01, 06 |
| S7 | `s07-unit-test-intermediate.png` | Run `postgresql/intermediate/tests/Test_orders.sql` — every result grid shows 0 rows | 08 |
| S8 | `s08-unit-test-warehouse.png` | Run `postgresql/warehouse/tests/fact_warehouse_tests.sql` — 0 rows | 08 |
| S9 | `s09-layer-reconciliation.png` | **Changed:** row counts across layers incl. rejected rows — query below | 08 |
| S10 | `s10-scd2-versions.png` | `dim_companies` companies with more than one version (query below — 5 companies now) | 03, 04, 08 |
| S11 | `s11-idempotency-rerun.png` | Fact row counts (query below), then `python -m python.pipelines.run_pipeline warehouse` (re-runs only the warehouse load), then the counts again — identical, and the run log shows `rows_loaded = 0`. Don't use `run_pipeline incremental` for this: it generates a new day of data | 08 |
| S12 | `s12-partitions.png` | `SELECT inhrelid::regclass AS partition FROM pg_inherits WHERE inhparent = 'warehouse.fact_orders'::regclass ORDER BY 1;` (31 months + `fact_orders_default`) | 04 |
| S13 | `s13-kpi-query-vs-dashboard.png` | `SELECT * FROM marts.vw_monthly_revenue_trend ORDER BY year DESC, month_num DESC LIMIT 6;` beside the same month on the Power BI Executive Overview page | 09 |
| S14 | `s14-repo-structure.png` | VS Code Explorer with the top-level folders expanded one level | 07 |
| S15 | `s15-git-log.png` | `git log --oneline` (after the new commits) | 07 |
| S16 | `s16-rejected-records.png` | **New:** quarantine table — query "Rejected records" below | 03, 05, 06, 08 |
| S17 | `s17-integration-tests.png` | **New:** in `postgresql/tests/integration_tests.sql` select only the **SUMMARY** query at the bottom and run it — one grid, 12 rows, `failed_rows` = 0 on every row | 08 |

Staging cleared (S6):

```sql
SELECT 'orders' AS staging_table, COUNT(*) AS rows_left FROM staging.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM staging.order_items
UNION ALL SELECT 'marketing_leads', COUNT(*) FROM staging.marketing_leads
UNION ALL SELECT 'web_logs', COUNT(*) FROM staging.web_logs;
```

Layer reconciliation (S9) — every source row is either in intermediate or in quarantine:

```sql
SELECT 'orders' AS table_name, COUNT(*) AS intermediate_rows,
       0 AS rejected_rows, (SELECT COUNT(*) FROM warehouse.fact_orders) AS warehouse_rows
FROM intermediate.orders
UNION ALL
SELECT 'marketing_leads', (SELECT COUNT(*) FROM intermediate.marketing_leads),
       (SELECT COUNT(*) FROM intermediate.rejected_records WHERE table_name = 'marketing_leads'),
       (SELECT COUNT(*) FROM warehouse.fact_leads)
UNION ALL
SELECT 'web_logs', (SELECT COUNT(*) FROM intermediate.web_logs),
       (SELECT COUNT(*) FROM intermediate.rejected_records WHERE table_name = 'web_logs'),
       (SELECT COUNT(*) FROM warehouse.fact_web_logs);
```

Rejected records (S16):

```sql
SELECT table_name, reject_reason, COUNT(*) AS rejected_rows
FROM intermediate.rejected_records
GROUP BY table_name, reject_reason
ORDER BY table_name, reject_reason;
```

SCD Type 2 versions (S10):

```sql
SELECT company_id, company_key, rating, city, effective_start_date, effective_end_date, is_current
FROM warehouse.dim_companies
WHERE company_id IN (SELECT company_id FROM warehouse.dim_companies GROUP BY company_id HAVING COUNT(*) > 1)
ORDER BY company_id, effective_start_date
LIMIT 12;
```

Idempotency (S11) — run before and after re-running the warehouse load:

```sql
SELECT 'fact_orders' AS tbl, COUNT(*) FROM warehouse.fact_orders
UNION ALL SELECT 'fact_order_items', COUNT(*) FROM warehouse.fact_order_items
UNION ALL SELECT 'fact_leads', COUNT(*) FROM warehouse.fact_leads
UNION ALL SELECT 'fact_web_logs', COUNT(*) FROM warehouse.fact_web_logs;

-- last two warehouse runs: the re-run should show rows_loaded = 0
SELECT pipeline_name, run_started_at, status, rows_loaded
FROM metadata.pipeline_run_log
WHERE pipeline_name = 'warehouse_load'
ORDER BY run_started_at DESC
LIMIT 2;
```

import subprocess
import sys
from pathlib import Path
from python.utils.logger import get_logger
from config.database import POSTGRESQL_ENGINE
from sqlalchemy import text
from python.utils.pipeline_utils import log_run_start, log_run_end
from python.utils.notifier import notify

logger = get_logger(__name__)

"""
Execution Flow:
INITIAL
│
├── Generate master
├── Generate transactions
├── SQL Server pipeline → staging
├── Marketing pipeline → staging
├── Web logs pipeline → staging
│
├── run_transform()
│       └── staging → intermediate  (bad CSV rows → intermediate.rejected_records)
│
├── clear_staging()
│       └── check every staging row is in intermediate or rejected_records → TRUNCATE staging
│
└── run_warehouse_load()
        │
        ├── dim_companies
        ├── dim_customers
        ├── dim_suppliers
        ├── dim_products
        ├── dim_supplier_product
        │
        ├── partitioning.sql
        │
        ├── fact_orders
        ├── fact_order_items
        ├── fact_web_logs
        └── fact_leads



INCREMENTAL
│
├── cdc_generator
│      ↓
│   new/changed source data
│
├── SQL Server pipeline → staging
├── Marketing leads pipeline → staging
├── Web logs pipeline → staging
│
├── run_transform()
│      ↓
│   staging → intermediate  (bad CSV rows → intermediate.rejected_records)
│
├── clear_staging()
│      ↓
│   check every staging row is accounted for → TRUNCATE staging
│
└── run_warehouse_load()
       │
       ├── dim_companies       → SCD2
       ├── dim_customers       → SCD1
       ├── dim_suppliers       → SCD1
       ├── dim_products        → SCD1
       ├── dim_supplier_product → SCD1
       │
       ├── partitioning.sql
       │
       ├── fact_orders         → MERGE/update + insert
       ├── fact_order_items    → MERGE/update + insert (order_status, payment_status)
       ├── fact_web_logs       → insert-only
       └── fact_leads          → MERGE/update + insert (funnel stage / conversion)



WAREHOUSE
│
└── run_warehouse_load() only (no new data) → used to show a re-run changes nothing
"""


BASE_DIR = Path(__file__).resolve().parents[2]


WAREHOUSE_LOAD_DIR = BASE_DIR / "postgresql" / "warehouse" / "Load"
PARTITION_SQL = BASE_DIR / "postgresql" / "warehouse" / "PARTITIONS_SETUP" / "partitioning.sql"


def run_module(module):
    subprocess.run(
        [sys.executable, "-m", module],
        cwd=BASE_DIR,
        check=True
    )



def run_transform():

    logger.info(
        "...........................TRANSFORMING AND MERGING INTO INTERMEDIATE LAYER.............................."
    )

    pipeline_name = "intermediate_transform"
    run_id = log_run_start(pipeline_name)
    rows_loaded = 0

    sql_files = [
        "Transform_companies.sql",
        "Transform_categories.sql",
        "Transform_customers.sql",
        "Transform_suppliers.sql",
        "Transform_products.sql",
        "Transform_supplier_product_mapping.sql",
        "Transform_marketing_leads.sql",
        "Transform_orders.sql",
        "Transform_order_items.sql",
        "Transform_web_logs.sql"
    ]

    # Table each script writes into. ANALYZE it right after loading so the
    # next scripts in this transaction see real row counts and pick fast joins.
    file_to_table = {
        "Transform_companies.sql": "companies",
        "Transform_categories.sql": "categories",
        "Transform_customers.sql": "customers",
        "Transform_suppliers.sql": "suppliers",
        "Transform_products.sql": "products",
        "Transform_supplier_product_mapping.sql": "supplier_product_mapping",
        "Transform_marketing_leads.sql": "marketing_leads",
        "Transform_orders.sql": "orders",
        "Transform_order_items.sql": "order_items",
        "Transform_web_logs.sql": "web_logs",
    }

    try:

        # One transaction for the complete Intermediate transformation
        with POSTGRESQL_ENGINE.begin() as connection:

            for file_name in sql_files:

                logger.info("Executing %s", file_name)

                file_path = BASE_DIR / "postgresql" / "intermediate" / "transform"  / file_name

                with open(file_path, "r", encoding="utf-8") as file:
                    sql_script = file.read()

                result = connection.execute(text(sql_script))

                connection.execute(text(f"ANALYZE intermediate.{file_to_table[file_name]}"))

                if result.rowcount and result.rowcount > 0:
                    rows_loaded += result.rowcount

                logger.info("%s completed successfully", file_name)

        logger.info(
            "All Intermediate transformations committed successfully."
        )

        log_run_end(run_id, pipeline_name, rows_extracted=None, rows_loaded=rows_loaded,
                    watermark_used=None, status="completed")

    except Exception as e:

        logger.exception(
            "Intermediate transformation failed. "
            "Transaction rolled back."
        )

        log_run_end(run_id, pipeline_name, rows_extracted=None, rows_loaded=rows_loaded,
                    watermark_used=None, status="failed", error_message=str(e))

        raise



def clear_staging():
    """
    Staging is a temporary landing area. Once intermediate has taken the
    batch, all staging tables are truncated so staging doesn't grow forever.

    Safety check first: every staging row must be either in intermediate or
    in intermediate.rejected_records. If any row is in neither, staging is
    NOT cleared and the run fails, so no row is ever lost.
    """

    logger.info(
        "...........................CHECKING AND CLEARING STAGING.............................."
    )

    # staging table -> its id column (intermediate uses the same names)
    staging_tables = {
        "companies": "company_id",
        "categories": "category_id",
        "customers": "customer_id",
        "suppliers": "supplier_id",
        "products": "product_id",
        "supplier_product_mapping": "supplier_product_id",
        "marketing_leads": "lead_id",
        "orders": "order_id",
        "order_items": "order_item_id",
        "web_logs": "log_id",
    }

    with POSTGRESQL_ENGINE.begin() as connection:

        # --------------------------------------------------------
        # 1. Safety check: is every staging row accounted for?
        # --------------------------------------------------------
        for table_name, id_column in staging_tables.items():

            missing_rows = connection.execute(text(f"""
                SELECT COUNT(*)
                FROM staging.{table_name} s
                WHERE s.{id_column} IS NOT NULL
                  AND NOT EXISTS (SELECT 1 FROM intermediate.{table_name} i
                                  WHERE i.{id_column} = s.{id_column})
                  AND NOT EXISTS (SELECT 1 FROM intermediate.rejected_records r
                                  WHERE r.table_name = '{table_name}'
                                    AND r.record_id = s.{id_column})
            """)).scalar()

            if missing_rows > 0:
                raise ValueError(
                    f"staging.{table_name}: {missing_rows} rows are neither in intermediate "
                    f"nor in rejected_records - staging NOT cleared"
                )

        logger.info("Every staging row is in intermediate or rejected_records.")

        # --------------------------------------------------------
        # 2. Truncate all staging tables
        # --------------------------------------------------------
        for table_name in staging_tables:
            connection.execute(text(f"TRUNCATE TABLE staging.{table_name}"))

    logger.info("Staging tables cleared.")



def run_warehouse_load():

    logger.info(
        "...........................LOADING WAREHOUSE LAYER.............................."
    )

    pipeline_name = "warehouse_load"
    run_id = log_run_start(pipeline_name)
    rows_loaded = 0

    # ============================================================
    # 1. Warehouse dimension loads
    # ============================================================

    sql_files = [
        "load_dim_date.sql",
        "load_dim_companies.sql",
        "load_dim_customers.sql",
        "load_dim_suppliers.sql",
        "load_dim_products.sql",
        "load_dim_supplier_product.sql",
        "load_fact_orders.sql",
        "load_fact_order_items.sql",
        "load_fact_web_logs.sql",
        "load_fact_leads.sql"
    ]

    try:

        # --------------------------------------------------------
        # Create/verify partitions before loading fact tables
        # --------------------------------------------------------

        logger.info("Executing partitioning.sql")

        with POSTGRESQL_ENGINE.begin() as connection:

            with open(PARTITION_SQL, "r", encoding="utf-8") as file:
                sql_script = file.read()

            connection.execute(text(sql_script))

        logger.info("partitioning.sql completed successfully.")

        # --------------------------------------------------------
        # Execute warehouse loads in dependency order
        # --------------------------------------------------------

        # Table each script writes into. ANALYZE it right after loading so the
        # next script sees up-to-date row counts and picks fast joins.
        file_to_table = {
            "load_dim_date.sql": "dim_date",
            "load_dim_companies.sql": "dim_companies",
            "load_dim_customers.sql": "dim_customers",
            "load_dim_suppliers.sql": "dim_suppliers",
            "load_dim_products.sql": "dim_products",
            "load_dim_supplier_product.sql": "dim_supplier_product",
            "load_fact_orders.sql": "fact_orders",
            "load_fact_order_items.sql": "fact_order_items",
            "load_fact_web_logs.sql": "fact_web_logs",
            "load_fact_leads.sql": "fact_leads",
        }

        for file_name in sql_files:

            logger.info("Executing %s", file_name)

            file_path = WAREHOUSE_LOAD_DIR / file_name

            with POSTGRESQL_ENGINE.begin() as connection:

                with open(file_path, "r", encoding="utf-8") as file:
                    sql_script = file.read()

                result = connection.execute(text(sql_script))

                connection.execute(text(f"ANALYZE warehouse.{file_to_table[file_name]}"))

                if result.rowcount and result.rowcount > 0:
                    rows_loaded += result.rowcount

            logger.info("%s completed successfully.", file_name)

        # --------------------------------------------------------
        # Cluster dimension tables on their primary key (the surrogate
        # key the fact tables join on), so rows are stored in key order
        # --------------------------------------------------------

        dimension_tables = ["dim_date", "dim_companies", "dim_customers",
                            "dim_suppliers", "dim_products", "dim_supplier_product"]

        with POSTGRESQL_ENGINE.begin() as connection:
            for table_name in dimension_tables:
                connection.execute(text(f"CLUSTER warehouse.{table_name} USING {table_name}_pkey"))

        logger.info("Dimension tables clustered on their primary keys.")

        logger.info(
            "All Warehouse loads completed successfully."
        )

        log_run_end(run_id, pipeline_name, rows_extracted=None, rows_loaded=rows_loaded,
                    watermark_used=None, status="completed")

    except Exception as e:

        logger.exception(
            "Warehouse load failed."
        )

        log_run_end(run_id, pipeline_name, rows_extracted=None, rows_loaded=rows_loaded,
                    watermark_used=None, status="failed", error_message=str(e))

        raise



def run_initial():
    logger.info("...........................GENERATING MASTER DATASET..............................")
    run_module("python.generators.master_generator")

    logger.info("...........................GENERATING TRANSACTIONS DATASET..............................")
    run_module("python.generators.transaction_generator")

    logger.info("...........................RUNNING SOURCE 1 (SQL SERVER) PIPELINE (LOAD TO STAGGING)..............................")
    run_module("python.pipelines.sql_server_pipeline")

    logger.info("...........................RUNNING SOURCE 2 (MARKETING LEADS) PIPELINE (LOAD TO STAGGING)..............................")
    run_module("python.pipelines.marketing_leads_pipeline")

    logger.info("...........................RUNNING SOURCE 3 (WEB LOGS) PIPELINE (LOAD TO STAGGING)..............................")
    run_module("python.pipelines.web_logs_pipeline")

    logger.info("...........................RUNNING TRANSFORM (LOAD TO INTERMEDIATE)...........................................")
    run_transform()
    clear_staging()

    logger.info("...........................RUNNING WAREHOUSE LOAD...........................................")
    run_warehouse_load()



def run_incremental():

    logger.info("...........................GENERATING NEW INCREMENTAL DATASET..............................")
    run_module("python.generators.cdc_generator")

    logger.info("...........................RUNNING SOURCE 1 (SQL SERVER) PIPELINE (LOAD TO STAGGING)..............................")
    run_module("python.pipelines.sql_server_pipeline")

    logger.info("...........................RUNNING SOURCE 2 (MARKETING LEADS) PIPELINE (LOAD TO STAGGING)..............................")
    run_module("python.pipelines.marketing_leads_pipeline")

    logger.info("...........................RUNNING SOURCE 3 (WEB LOGS) PIPELINE (LOAD TO STAGGING)..............................")
    run_module("python.pipelines.web_logs_pipeline")

    logger.info("...........................RUNNING TRANSFORM (LOAD TO INTERMEDIATE)...........................................")
    run_transform()
    clear_staging()

    logger.info("...........................RUNNING WAREHOUSE LOAD...........................................")
    run_warehouse_load()


def main():

    if len(sys.argv) != 2:
        print("Usage: python -m python.pipelines.run_pipeline [initial|incremental|warehouse]")
        sys.exit(1)

    mode = sys.argv[1].lower()

    try:
        if mode == "initial":
            run_initial()

        elif mode == "incremental":
            run_incremental()

        # re-run only the warehouse load (no new data) - used to show idempotency
        elif mode == "warehouse":
            run_warehouse_load()

        else:
            print("Invalid mode. Use 'initial', 'incremental' or 'warehouse'.")
            sys.exit(1)

        notify("Pipeline Completed", f"{mode.capitalize()} pipeline run finished successfully.")

    except Exception as e:
        logger.exception(f"Pipeline execution failed. {e}")
        notify("Pipeline Failed", f"{mode.capitalize()} pipeline run failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
    
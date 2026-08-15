import subprocess
import sys
from pathlib import Path
from python.utils.logger import get_logger
from config.database import POSTGRESQL_ENGINE
from sqlalchemy import text

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
│       └── staging → intermediate
│
└── run_warehouse_load()
        │
        ├── dim_companies
        ├── dim_customers
        ├── dim_suppliers
        ├── dim_products
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
│   staging → intermediate
│
└── run_warehouse_load()
       │
       ├── dim_companies       → SCD2
       ├── dim_customers       → SCD1
       ├── dim_suppliers       → SCD1
       ├── dim_products        → SCD1
       │
       ├── partitioning.sql
       │
       ├── fact_orders         → MERGE/update + insert
       ├── fact_order_items    → insert-only
       ├── fact_web_logs       → insert-only
       └── fact_leads          → insert-only        
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

    try:

        # One transaction for the complete Intermediate transformation
        with POSTGRESQL_ENGINE.begin() as connection:

            for file_name in sql_files:

                logger.info("Executing %s", file_name)

                file_path = BASE_DIR / "postgresql" / "intermediate" / "transform"  / file_name

                with open(file_path, "r", encoding="utf-8") as file:
                    sql_script = file.read()

                connection.execute(text(sql_script))

                logger.info("%s completed successfully", file_name)

        logger.info(
            "All Intermediate transformations committed successfully."
        )

    except Exception:

        logger.exception(
            "Intermediate transformation failed. "
            "Transaction rolled back."
        )

        raise



def run_warehouse_load():

    logger.info(
        "...........................LOADING WAREHOUSE LAYER.............................."
    )

    # ============================================================
    # 1. Warehouse dimension loads
    # ============================================================

    sql_files = [
        "load_dim_companies.sql",
        "load_dim_customers.sql",
        "load_dim_suppliers.sql",
        "load_dim_products.sql",
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

        for file_name in sql_files:

            logger.info("Executing %s", file_name)

            file_path = WAREHOUSE_LOAD_DIR / file_name

            with POSTGRESQL_ENGINE.begin() as connection:

                with open(file_path, "r", encoding="utf-8") as file:
                    sql_script = file.read()

                connection.execute(text(sql_script))

            logger.info("%s completed successfully.", file_name)

        logger.info(
            "All Warehouse loads completed successfully."
        )

    except Exception:

        logger.exception(
            "Warehouse load failed."
        )

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

    logger.info("...........................RUNNING WAREHOUSE LOAD...........................................")
    run_warehouse_load()


def main():

    if len(sys.argv) != 2:
        print("Usage: python -m python.pipelines.run_pipeline [initial|incremental]")
        sys.exit(1)

    mode = sys.argv[1].lower()

    try:
        if mode == "initial":
            run_initial()

        elif mode == "incremental":
            run_incremental()

        else:
            print("Invalid mode. Use 'initial' or 'incremental'.")
            sys.exit(1)

    except Exception as e:
        logger.exception(f"Pipeline execution failed. {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
    
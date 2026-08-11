import subprocess
import sys
from pathlib import Path
from python.utils.logger import get_logger
from config.database import POSTGRESQL_ENGINE
from sqlalchemy import text
import psycopg2

logger = get_logger(__name__)

BASE_DIR = Path(__file__).resolve().parents[2]


SQL_DIR = BASE_DIR / "postgresql" / "intermediate" / "transform"




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

    except subprocess.CalledProcessError as e:
        print(f"Pipeline execution failed with exit code {e.returncode}")
        sys.exit(1)


if __name__ == "__main__":
    main()
    
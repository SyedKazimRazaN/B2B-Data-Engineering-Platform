import pandas as pd
from sqlalchemy import text
from config.config import (CHUNK_SIZE)
from config.database import POSTGRESQL_ENGINE, SQL_SERVER_ENGINE
from python.utils.logger import get_logger
from python.utils.pipeline_utils import log_run_start, log_run_end, get_last_watermark, update_watermark
from python.utils.constants import SOURCE1_QUERIES

logger = get_logger(__name__)
PIPELINE_NAME = "sql_server_pipeline"
TABLE_MAPPING = {
                    "companies"                 : "companies",
                    "categories"                : "categories",
                    "customers"                 : "customers",
                    "products"                  : "products",
                    "suppliers"                 : "suppliers",
                    "supplier_product_mapping"  : "supplier_product_mapping",
                    "orders"                    : "orders",
                    "order_items"               : "order_items"
                    }


def extracting_incremental_data(watermark):
    try:
        extracted = {}
        new_watermark = watermark

        for table_name, base_query in SOURCE1_QUERIES.items():
            if watermark is not None:
                query = text(f"{base_query} WHERE updated_at > :watermark")
                df = pd.read_sql(query, SQL_SERVER_ENGINE, params = {"watermark": watermark})

            else:
                df = pd.read_sql(base_query, SQL_SERVER_ENGINE)

            logger.info(f"{PIPELINE_NAME} extracted {len(df)} rows from {table_name}")
            extracted[table_name] = df

            if not df.empty:
                latest_updated_at = df["updated_at"].max()

                if new_watermark is None or latest_updated_at > new_watermark:
                    new_watermark = latest_updated_at


        return extracted, new_watermark

    except Exception as e:
        logger.error(f"Error extracting data from sql server{e}")
        raise



def load_to_staging(sql_server_df):
    try:
        rows_loaded = 0

        for dataset_name, table_name in TABLE_MAPPING.items():
            df = sql_server_df.get(dataset_name)

            if df is None or df.empty:
                logger.info("No rows were extracted")
                continue

            logger.info(f"Loading {dataset_name} into {table_name}")
            df.to_sql(
                table_name,
                schema="staging",
                con=POSTGRESQL_ENGINE,
                if_exists="append",
                index=False,
                chunksize = CHUNK_SIZE,
            )
            rows_loaded += len(df)
            logger.info(f"[{PIPELINE_NAME}] loaded {len(df)} rows into staging.{table_name}")

        logger.info("All available datasets loaded successfully")

        return rows_loaded

    except Exception as e:
        logger.error(f"Error loading sql_server data into staging table {e}")
        raise

def profile_dataframe(name, df):

    print("\n" + "=" * 70)
    print(f"TABLE : {name.upper()}")
    print("=" * 70)


    print("\nShape:")
    print(df.shape)


    print("\nInfo:")
    df.info()


    print("\nMissing Values:")
    print(df.isnull().sum())


def run():
    run_id = log_run_start(PIPELINE_NAME)
    rows_extracted = 0
    rows_loaded = 0
    try:
        watermark = get_last_watermark(PIPELINE_NAME)

        sql_server_df, new_watermark = extracting_incremental_data(watermark)

        rows_extracted = 0
        for df in sql_server_df.values():
            rows_extracted += len(df)


        for table_name, df in sql_server_df.items():
            profile_dataframe(table_name, df)


        rows_loaded = load_to_staging(sql_server_df)

        if new_watermark is not None and new_watermark != watermark:
            update_watermark(PIPELINE_NAME, new_watermark)

        log_run_end(run_id, PIPELINE_NAME, rows_extracted, rows_loaded, new_watermark, status = "completed")
        
    except Exception as e:
        logger.error(f"{PIPELINE_NAME} failed {e}")
        log_run_end(run_id, PIPELINE_NAME, rows_extracted, rows_loaded, watermark_used=None, status = "failed",error_message = str(e))
        raise


if __name__ == "__main__":
    run()

















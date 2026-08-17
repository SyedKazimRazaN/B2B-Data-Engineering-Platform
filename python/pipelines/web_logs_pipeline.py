"""
ELT pipeline for Source 3 (Web Logs CSV): snapshot-based, full re-read of
the CSV every run (no watermark) - truncates and reloads staging.web_logs
on every execution.

Execution Flow (run()):
    extract_source3()      # read full web_logs CSV
        -> profile_dataframe()
        -> load_to_stagging()   # TRUNCATE + append into staging.web_logs
        -> log_run_start()/log_run_end() bracket the whole run
"""

import pandas as pd
from sqlalchemy import text
from config.config import (WEB_LOGS_OUTPUT_PATH, STAGING_SCHEMA, CHUNK_SIZE)
from config.database import POSTGRESQL_ENGINE
from datetime import datetime
from python.utils.logger import get_logger
from python.utils.pipeline_utils import log_run_start, log_run_end

logger = get_logger(__name__)
PIPELINE_NAME = "web_logs_pipeline"


# --------------------------------------------------
# 1. EXTRACTING WEB LOGS (Source 3)
# --------------------------------------------------
def extract_source3():
    # Snapshot-based (no watermark) - full file re-read every run.
    try:
        logger.info("Extraction Started................")
        web_logs_df = pd.read_csv(WEB_LOGS_OUTPUT_PATH, parse_dates=["log_timestamp"])

        if not web_logs_df.empty:
            logger.info("Succesfully extracted Marketing leads dataset")
            logger.info(f"{PIPELINE_NAME} extracted {len(web_logs_df)} rows from Source 2")
            return web_logs_df
        else:
            raise ValueError("web logs data is empty")
    except Exception as e:
        logger.error(f"Error extracting web logs data{e}")
        raise



def load_to_stagging(web_logs_df):
    try:
        logger.info("Loading Started...........")
        with POSTGRESQL_ENGINE.begin() as conn:
            conn.execute(text(f"""TRUNCATE TABLE {STAGING_SCHEMA}.web_logs"""))

        web_logs_df.to_sql(
            "web_logs",
            schema="staging",
            con=POSTGRESQL_ENGINE,
            if_exists="append",
            index=False,
            chunksize = CHUNK_SIZE,
                )
        
        logger.info(f"[{PIPELINE_NAME}] loaded {len(web_logs_df)} rows into staging.web_logs")
        return len(web_logs_df)
    except Exception as e:
        logger.exception(f"Error loading web logs data into staging table {e}")
        raise


# ==================================================
# DATA PROFILING FUNCTION
# ==================================================

def profile_dataframe(web_logs_df):

    print("\n" + "=" * 70)
    print(f"TABLE : {PIPELINE_NAME}")
    print("=" * 70)


    print("\nShape:")
    print(web_logs_df.shape)


    print("\nInfo:")
    web_logs_df.info()


    print("\nMissing Values:")
    print(web_logs_df.isnull().sum())





def run():
    run_id = log_run_start(PIPELINE_NAME)
    rows_extracted = 0
    rows_loaded = 0
    try:
        web_logs_df = extract_source3()

        rows_extracted = len(web_logs_df)
        profile_dataframe(web_logs_df)
        rows_loaded = load_to_stagging(web_logs_df)
 
        log_run_end(run_id, PIPELINE_NAME, rows_extracted, rows_loaded, watermark_used=None, status = "completed")
        logger.info(f"{PIPELINE_NAME} completed")

    except Exception as e:
        logger.error(f"{PIPELINE_NAME} failed {e}")
        log_run_end(run_id, PIPELINE_NAME, rows_extracted =0, rows_loaded =0, watermark_used=None, status = "failed", error_message= str(e))
        raise


if __name__ == "__main__":
    run()


"""
ELT pipeline for Source 2 (Marketing Leads CSV): snapshot-based, full
re-read of the CSV every run (no watermark) - truncates and reloads
staging.marketing_leads on every execution.

Execution Flow (run()):
    extract_source2()      # read full marketing_leads CSV
        -> profile_dataframe()
        -> load_to_stagging()   # TRUNCATE + append into staging.marketing_leads
        -> log_run_start()/log_run_end() bracket the whole run
"""

import pandas as pd
from sqlalchemy import text
from config.config import (MARKETING_LEADS_OUTPUT_PATH, STAGING_SCHEMA, CHUNK_SIZE)
from config.database import POSTGRESQL_ENGINE
from datetime import datetime
from python.utils.logger import get_logger
from python.utils.pipeline_utils import log_run_start, log_run_end

logger = get_logger(__name__)
PIPELINE_NAME = "marketing_leads_pipeline"

# --------------------------------------------------
# 1. EXTRACTING Marketing Leads (Source 2)
# --------------------------------------------------
def extract_source2():
    # Snapshot-based (no watermark) - full file re-read every run.
    try:
        logger.info("Extraction started......")
        marketing_leads_df = pd.read_csv(MARKETING_LEADS_OUTPUT_PATH, parse_dates=["created_at","updated_at"])

        if not marketing_leads_df.empty:
            logger.info("Succesfully extracted Marketing leads dataset")
            logger.info(f"{PIPELINE_NAME} extracted {len(marketing_leads_df)} rows from Source 2")

            return marketing_leads_df
        else:
            raise ValueError("Marketing Leads data is empty")
    except Exception as e:
        logger.error(f"Error extracting Marketing Leads data{e}")
        raise



def load_to_stagging(marketing_leads_df):
    try:
        with POSTGRESQL_ENGINE.begin() as conn:
            conn.execute(text(f"""TRUNCATE TABLE {STAGING_SCHEMA}.marketing_leads"""))

        marketing_leads_df.to_sql(
            "marketing_leads",
            schema="staging",
            con=POSTGRESQL_ENGINE,
            if_exists="append",
            index=False,
            chunksize = CHUNK_SIZE,
                )
        
        logger.info(f"[{PIPELINE_NAME}] loaded {len(marketing_leads_df)} rows into staging.marketing_leads")
        return len(marketing_leads_df)
    except Exception as e:
        logger.error(f"Error loading marketing leeds data into staging table {e}")
        raise



def profile_dataframe(marketing_leads_df):

    print("\n" + "=" * 70)
    print(f"TABLE : {PIPELINE_NAME}")
    print("=" * 70)


    print("\nShape:")
    print(marketing_leads_df.shape)


    print("\nInfo:")
    marketing_leads_df.info()


    print("\nMissing Values:")
    print(marketing_leads_df.isnull().sum())



def run():
    run_id = log_run_start(PIPELINE_NAME)
    rows_extracted = 0
    rows_loaded = 0

    try:
        marketing_leads_df = extract_source2()

        rows_extracted = len(marketing_leads_df)
        profile_dataframe(marketing_leads_df)
        rows_loaded = load_to_stagging(marketing_leads_df)

        log_run_end(run_id, PIPELINE_NAME, rows_extracted, rows_loaded, watermark_used=None, status = "completed")
        logger.info(f"{PIPELINE_NAME} completed")

    except Exception as e:
        logger.error(f"{PIPELINE_NAME} failed {e}")
        log_run_end(run_id, PIPELINE_NAME, rows_extracted, rows_loaded, watermark_used=None, status = "failed",error_message = str(e))
        raise




if __name__ == "__main__":
    run()
"""
Shared metadata helpers used by every ELT pipeline:
- get_last_watermark() / update_watermark(): per-pipeline incremental
  watermark tracking in metadata.pipeline_watermarks.
- log_run_start() / log_run_end(): write a row per pipeline execution
  (status, row counts, watermark used, error message) to
  metadata.pipeline_run_log.
"""

import uuid
from datetime import datetime
from sqlalchemy import text
from config.database import POSTGRESQL_ENGINE
from python.utils.logger import get_logger

logger = get_logger(__name__)

def get_last_watermark(pipeline_name):
    try:
        with POSTGRESQL_ENGINE.begin() as conn:
            result = conn.execute(
                text("""SELECT
                            last_extracted_at
                        FROM metadata.pipeline_watermarks
                        WHERE pipeline_name = :name"""),
            {"name": pipeline_name}).fetchone()

        if result:
            watermark = result[0]
        else: 
            watermark = None

        logger.info(f"{pipeline_name} last watermark = {watermark}")
        return watermark
    except Exception as e:
        logger.exception(f"Error reading watermark for {pipeline_name}: {e}")
        raise



def update_watermark(pipeline_name, new_watermark):
    try:
        with POSTGRESQL_ENGINE.begin() as conn:
            conn.execute(
                text("""INSERT INTO
                            metadata.pipeline_watermarks
                            (pipeline_name, last_extracted_at)
                        VALUES
                            (:name, :wm)
                        ON CONFLICT (pipeline_name)
                        DO UPDATE
                        SET
                            last_extracted_at = EXCLUDED.last_extracted_at
                    """),
            {"name": pipeline_name, "wm": new_watermark})

        logger.info(f"{pipeline_name} watermark updated = {new_watermark}")
        return
    except Exception as e:
        logger.exception(f"Error updating watermark for {pipeline_name}: {e}")
        raise



def log_run_start(pipeline_name):
    try:
        run_id = uuid.uuid4().hex
        name = pipeline_name
        status = 'running'
        run_started_at = datetime.now()
        with POSTGRESQL_ENGINE.begin() as conn:
            conn.execute(
                text("""INSERT INTO
                            metadata.pipeline_run_log
                    (run_id, pipeline_name, run_started_at, status)
                VALUES
                    (:run_id, :name, :started_at, :status)
            """),
            {"run_id": run_id, "name": name, "started_at": run_started_at,"status": status}
        )
            
        logger.info(f"[{pipeline_name}] run started, run_id = {run_id}")
        return run_id
    except Exception as e:
        logger.exception(f"Error logging pipeline run start for {pipeline_name}: {e}")
        raise


def log_run_end(run_id, pipeline_name, rows_extracted,
                 rows_loaded, watermark_used, status,
                   error_message=None):
    try:       
        ended_at = datetime.now()
        with POSTGRESQL_ENGINE.begin() as conn:
            conn.execute(
            text("""
                UPDATE metadata.pipeline_run_log
                SET run_ended_at   = :ended_at,
                    rows_extracted = :rows_extracted,
                    rows_loaded    = :rows_loaded,
                    watermark_used = :watermark_used,
                    status         = :status,
                    error_message  = :error_message
                WHERE run_id = :run_id
            """),
            {
                "ended_at": datetime.now(),
                "rows_extracted": rows_extracted,
                "rows_loaded": rows_loaded,
                "watermark_used": watermark_used,
                "status": status,
                "error_message": error_message,
                "run_id": run_id
            }
        )
        logger.info(f"[{pipeline_name}] run {run_id} -> {status} (extracted rows={rows_extracted}, loaded rows={rows_loaded})")

    except Exception as e:
        logger.exception(f"Error updating logs on pipeline run end {e}")





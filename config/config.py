"""
Central project configuration: dataset volumes, generation time window
and random seed, DB schema names, output file paths, pipeline batching/
retry settings, and logging setup. Values are plain constants (with a
few environment-variable overrides) imported throughout the generators
and pipelines.
"""

import os
from pathlib import Path
from datetime import date
from dotenv import load_dotenv

load_dotenv()


# ============================================================================
# Project Information
# ============================================================================
PROJECT_NAME = "B2B Data Engineering Internship Project"
VERSION = "1.0.0"
ENVIRONMENT = os.getenv("ENVIRONMENT","production") #(Development, Production, testing)
AUTHOR = "Syed Kazim Raza"


# ============================================================================
# Dataset Volume:
# ============================================================================
NUM_COMPANIES = 2500
# Customers are generated only for Buyer companies
MIN_CUSTOMERS_PER_COMPANY = 10
MAX_CUSTOMERS_PER_COMPANY = 80
NUM_SUPPLIERS = 400
MIN_SUPPLIERS_PER_PRODUCT = 2
MAX_SUPPLIERS_PER_PRODUCT = 5
NUM_CATEGORIES = 10
NUM_ORDERS = 150000
NUM_ORDER_ITEMS = 450000
NUM_MARKETING_LEADS = 150000
NUM_WEB_LOGS = 300000
#not defining no. of NUM_SUPPLIER_PRODUCT_MAPPING  2-5 products per supplier × 250 suppliers ≈ not bounding for Rule 5
# not defining NUM_Customers (10-80) per company
# ============================================================================

# ----------------------------------------------------------------------------
# Development-mode values (kept here for record — not active)
# ----------------------------------------------------------------------------
# NUM_COMPANIES = 500
# NUM_SUPPLIERS = 150
# NUM_ORDERS = 30000
# NUM_ORDER_ITEMS = 120000          (unused elsewhere in the codebase — informational only)
# NUM_MARKETING_LEADS = 50000
# NUM_WEB_LOGS = 75000
#Time Window:
# ============================================================================
current_date = date.today()
START_DATE = current_date.replace(year=current_date.year - 2)
END_DATE = current_date


# ============================================================================
#Randomness:
# ============================================================================
RANDOM_SEED = 40


# ============================================================================
# Faker Locale
# ============================================================================
FAKER_LOCALE = "en_US"


# ============================================================================
#Database Configuration:
# ============================================================================
SQL_SERVER_DATABASE = os.getenv("SQL_SERVER_DATABASE", "b2b_source_db")
POSTGRESQL_DATABASE = os.getenv("POSTGRESQL_DATABASE", "b2b_warehouse_db")
SOURCE_SCHEMA = "source"
STAGING_SCHEMA = "staging"
INTERMEDIATE_SCHEMA = "intermediate"
WAREHOUSE_SCHEMA = "warehouse"
MART_SCHEMA = "marts"



# ============================================================================
#File Paths
# ============================================================================
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
LOGS_DIR = BASE_DIR / "logs"

WEB_LOGS_OUTPUT_PATH = DATA_DIR /"web_logs"/"web_logs.csv"  # exists in folder(data)->folder(weblogs)->.log file
MARKETING_LEADS_OUTPUT_PATH = DATA_DIR /"marketing_leads"/"marketing_leads.csv" # exists in folder(data)->folder(marketing_leads)->.csv file
PIPELINE_LOGS_PATH = LOGS_DIR / "pipeline.log" # exists in folder(logs)->.log file



# ======================================
# Pipeline Configuration
# ======================================
MAX_RETRIES = 3
RETRY_DELAY_SECONDS = 2

BATCH_SIZE = 5000

CHUNK_SIZE = 2500



# ==================================================================
#Logging Configuration
# ==================================================================
LOG_LEVEL = "INFO"

LOG_FORMAT = "%(asctime)s | %(levelname)s |%(name)s | %(lineno)d | %(message)s"


# ==================================================================
# Development-mode values (kept here for record — not active)
# ==================================================================
# ENVIRONMENT default was "development"
# LOG_LEVEL was "DEBUG" (verbose, prints every debug-level line to
#   console + logs/pipeline.log — useful while building the pipeline,
#   noisy for a normal run)




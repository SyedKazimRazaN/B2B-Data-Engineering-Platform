
import os
from pathlib import Path
from datetime import date



# ============================================================================
# Project Information
# ============================================================================
PROJECT_NAME = "B2B Data Engineering Internship Project"
VERSION = "1.0.0"
ENVIRONMENT = os.getenv("ENVIRONMENT","development") #(Development, Production, testing)
AUTHOR = "Syed Kazim Raza"


# ============================================================================
# Dataset Volume: 
# ============================================================================
NUM_COMPANIES = 500
NUM_CUSTOMERS = 10000 # Customers are generated only for Buyer companies
NUM_SUPPLIERS = 250
NUM_CATEGORIES = 10
NUM_PRODUCTS = 1200
NUM_SUPPLIER_PRODUCT_MAPPING = 4000   #3-4 suppliers per /product
NUM_ORDERS = 30000
NUM_ORDER_ITEMS = 120000
NUM_MARKETING_LEADS = 50000
NUM_WEB_LOGS = 1000000


# ============================================================================
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
POSTGRESQL_DATABASE = os.getenv("POSTGRES_DATABASE", "b2b_warehouse_db")
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

WEB_LOGS_OUTPUT_PATH = DATA_DIR /"web_logs"/"web_logs.log"  # exists in folder(data)->folder(weblogs)->.log file
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

LOG_FORMAT = "%(asctime)s | %(levelname)s | %(message)s"




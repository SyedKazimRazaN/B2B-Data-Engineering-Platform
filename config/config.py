"""
Central project configuration: dataset volumes, generation time window,
random seed and realism settings, DB schema names, output file paths,
pipeline chunking, and logging setup. Values are plain constants (with a
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
ENVIRONMENT = os.getenv("ENVIRONMENT","production")  # development / testing / production
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
# Not fixed numbers: each product gets 2-5 suppliers, each buyer company 10-80 customers (see master_generator.py)
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
# Generation Realism
# ============================================================================
# Customers of a buyer company are created within 90 days of the company
CUSTOMER_ONBOARDING_MAX_DAYS = 90
# A Won lead places its order within 90 days of the lead being created
SALES_CYCLE_MAX_DAYS = 90

# Daily CDC volumes (min, max) - same level as the 2-year backfill:
# 150,000 orders / 730 days ≈ 205 per day, 150,000 leads ≈ 205, 300,000 web logs ≈ 410
DAILY_ORDERS_RANGE = (180, 230)
DAILY_LEADS_RANGE = (180, 230)
DAILY_WEB_LOGS_RANGE = (370, 450)

# % of rows in the CSV sources (marketing leads, web logs) broken on purpose,
# because real files are messy - proves the validation + quarantine works
DIRTY_DATA_PERCENT = 1.5


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

WEB_LOGS_OUTPUT_PATH = DATA_DIR /"web_logs"/"web_logs.csv"  # data/web_logs/web_logs.csv
MARKETING_LEADS_OUTPUT_PATH = DATA_DIR /"marketing_leads"/"marketing_leads.csv"  # data/marketing_leads/marketing_leads.csv
PIPELINE_LOGS_PATH = LOGS_DIR / "pipeline.log"  # logs/pipeline.log



# ======================================
# Pipeline Configuration
# ======================================
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




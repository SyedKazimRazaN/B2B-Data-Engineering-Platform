from sqlalchemy import create_engine
from dotenv import load_dotenv
import os
load_dotenv()

# --------------------------------------------------
# 1. Create SQL Server connection
# --------------------------------------------------
SQL_SERVER_NAME = os.getenv("SQL_SERVER_NAME")
SQL_SERVER_DRIVER = os.getenv("SQL_SERVER_DRIVER")
SQL_SERVER_DATABASE = os.getenv("SQL_SERVER_DATABASE")
SQL_SERVER_AUTH = os.getenv("SQL_SERVER_AUTH")
sqlserver_connection_url = (
    f"mssql+pyodbc://@{SQL_SERVER_NAME}/{SQL_SERVER_DATABASE}?driver={SQL_SERVER_DRIVER}&{SQL_SERVER_AUTH}"
)

SQL_SERVER_ENGINE = create_engine(sqlserver_connection_url, fast_executemany=True)



# --------------------------------------------------
# 2. Create PostgreSQL connection
# --------------------------------------------------
POSTGRES_HOST = os.getenv("POSTGRES_HOST")
POSTGRES_PORT = os.getenv("POSTGRES_PORT")
POSTGRES_USER = os.getenv("POSTGRES_USER")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD")
POSTGRESQL_DATABASE = os.getenv("POSTGRESQL_DATABASE")

postgresql_connection_url = (f"postgresql+psycopg2://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRESQL_DATABASE}")
postgresql_engine = create_engine(postgresql_connection_url)


# ============================================================================
# Validate Environment Variables
# ============================================================================
required_variables = [
    SQL_SERVER_NAME,
    SQL_SERVER_DRIVER,
    SQL_SERVER_DATABASE,
    SQL_SERVER_AUTH,
    POSTGRES_HOST,
    POSTGRES_PORT,
    POSTGRES_USER,
    POSTGRES_PASSWORD,
    POSTGRESQL_DATABASE
]

if any(variable is None for variable in required_variables):
    raise ValueError("One or more required environment variables are missing. Check your .env file.")





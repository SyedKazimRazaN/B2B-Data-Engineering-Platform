from python.utils.logger import get_logger
from config.database import SQL_SERVER_ENGINE


logger = get_logger(__name__)


def load_to_sqlserver(datasets):
    try:

        logger.info("Loading datasets into SQL Server...")


        table_mapping = {
            "companies": "Companies",
            "categories": "Categories",
            "customers": "Customers",
            "products": "Products",
            "suppliers": "Suppliers",
            "supplier_product_mapping": "Supplier_Product_Mapping",
            "orders": "Orders",
            "order_items": "Order_Items"
        }


        for dataset_name, table_name in table_mapping.items():

            if dataset_name in datasets:

                logger.info(
                    f"Loading {dataset_name} into {table_name}"
                )


                datasets[dataset_name].to_sql(
                    table_name,
                    schema="source",
                    con=SQL_SERVER_ENGINE,
                    if_exists="append",
                    index=False
                )


        logger.info(
            "All available datasets loaded successfully"
        )


    except Exception as e:

        logger.error(
            f"Error loading datasets: {e}"
        )

        raise

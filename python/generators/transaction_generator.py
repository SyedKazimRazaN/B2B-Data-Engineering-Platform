import pandas as pd
from faker import Faker
from python.utils.logger import get_logger
import random
from config.database import (SQL_SERVER_ENGINE)
from python.generators.load_to_sqlserver import load_to_sqlserver
from config.config import (
NUM_WEB_LOGS,
START_DATE,
END_DATE,
RANDOM_SEED,
NUM_MARKETING_LEADS,
MARKETING_LEADS_OUTPUT_PATH,
WEB_LOGS_OUTPUT_PATH,
NUM_ORDERS
)
from python.utils.constants import (
OPERATING_LOCATIONS,
LEAD_SOURCES,
UTM_SOURCES,
UTM_MEDIUMS,
CAMPAIGNS,
COMPANY_SIZES,
COMPANY_SIZE_WEIGHTS,
ORDER_VALUE_RANGE,
FUNNEL_STAGES,
FUNNEL_STAGE_WEIGHTS,
FUNNEL_SCORE_RANGE,
INDUSTRIES,
REFERERS,
STATUS_CODES,
STATUS_CODE_WEIGHTS,
HTTP_METHODS,
REQUEST_PATHS,
BOT_USER_AGENTS,
BROWSERS,
BROWSER_WEIGHTS,
DEVICE_TYPES,
DEVICE_TYPE_WEIGHTS,
ORDER_STATUS,
ORDER_STATUS_WEIGHTS
)

# -----------------------------
# Global configuration setup
# -----------------------------
Faker.seed(RANDOM_SEED)
random.seed(RANDOM_SEED) #controlling random.choice, .choices & .uniform
logger = get_logger(__name__)
fake = Faker()



def initialize_faker_instances(): #localized faker for Company dataset
    """
    Creates separate Faker instances for each country.

    Reason:
    Different countries require different locales so generated
    names, addresses and user data match the selected country.
    """
    faker_instances = {}

    for country, details in OPERATING_LOCATIONS.items():
        faker_instances[country] = Faker(details["locale"])
        faker_instances[country].seed_instance(RANDOM_SEED)

    return faker_instances


def select_random_country():
    """
    Selecting a country based on configured probability weights.
    """

    countries = list(OPERATING_LOCATIONS.keys())
    weightage = []

    for location in OPERATING_LOCATIONS.values():
        weightage.append(location["weight"]) 

    selected_country = random.choices(countries, weights= weightage, k=1)[0]


    return selected_country



# -----------------------------
# Initialize Shared Objects
# -----------------------------

faker_instances = initialize_faker_instances()


# -----------------------------
# Data Generators
# -----------------------------

def generate_marketing_leads (num_marketing_leads=NUM_MARKETING_LEADS):
    try:
        logger.info("Generating Marketing Leads...")

        marketing_leads_dataset =[]

        for _ in range(num_marketing_leads):
            #choosing country for faker:
            selected_country = select_random_country()

            #creating faker instance according to selected country
            fake_local = faker_instances[selected_country]

            #selecting cities from selected country
            cities = OPERATING_LOCATIONS[selected_country]["cities_hq"]

            city = random.choice(cities)

            campaign = random.choice(CAMPAIGNS)
            created_at = fake.date_time_between(start_date=START_DATE, end_date=END_DATE)
            updated_at = fake.date_time_between(start_date=created_at, end_date=END_DATE)

            selected_stage = random.choices(FUNNEL_STAGES, weights=FUNNEL_STAGE_WEIGHTS, k=1)[0]

            min_score, max_score = FUNNEL_SCORE_RANGE[selected_stage]
            lead_score = random.randint(min_score, max_score)

            selected_company_size = random.choices(COMPANY_SIZES, weights= COMPANY_SIZE_WEIGHTS,k=1)[0]
            min_order_value, max_order_value = ORDER_VALUE_RANGE[selected_company_size]

            marketing_leads_dataset.append({
              	"lead_id" : fake.uuid4().replace("-",""),
                "source" : random.choice(LEAD_SOURCES),
                "campaign_name" : campaign,
                "utm_source" : random.choice(UTM_SOURCES),
                "utm_medium" : random.choice(UTM_MEDIUMS),
                "utm_campaign" : campaign.lower().replace(" ", "_"),
                "company_name" :fake.unique.company(),
                "company_size" : selected_company_size,
                "industry" : random.choice(INDUSTRIES),
                "country" : selected_country,
                "city" : city,
                "lead_score" : lead_score,
                "estimated_order_value" : round(random.uniform(min_order_value,max_order_value),2),
                "funnel_stage" : selected_stage,
                "created_at" : created_at,
                "updated_at" : updated_at

            })
        marketing_leads = pd.DataFrame(marketing_leads_dataset)
        logger.info(f"\nmarketing_leads Type Distribution:\n{marketing_leads['funnel_stage'].value_counts()}")
 
        #validation checks:

        if (
            len(marketing_leads) == num_marketing_leads
            and marketing_leads["lead_id"].is_unique
            and marketing_leads["company_name"].is_unique
            and marketing_leads["lead_score"].between(1, 100).all()
            and marketing_leads.notna().all().all()
            ):
                logger.info(f"Generated {len(marketing_leads)} marketing leads records successfully!")
                logger.info(f"\nIndustry Distribution:\n{marketing_leads['industry'].value_counts()}")

                return marketing_leads
        else:
                raise ValueError("Marketing Leads dataset validation failed")


    except Exception as e:
        logger.error(f"Error generating marketing leads dataset: {e}")
        raise



def generate_orders(companies,customers, marketing_leads, num_orders=NUM_ORDERS):
    try:
        logger.info("Generating Orders...")
        """
        Adding company country information to customers.
        This allows us to select customers from the same
        country as Won marketing leads.
        """
        customers = customers.merge(
            companies[["company_id", "country"]],
            on="company_id",
            how="left"
        ) #joining companies table (country column to customers)

        customers_list = customers.to_dict("records")

        #creating 'won' leads for generating new orders 
        won_leads = marketing_leads[marketing_leads["funnel_stage"] == "Won"].to_dict("records")

        # ----------------------------------
        # Group customers by country
        # ----------------------------------

        customers_by_country = {}

        for customer in customers_list:
            country = customer["country"]

            if country not in customers_by_country:
                customers_by_country[country] = []

            customers_by_country[country].append(customer)


        # ----------------------------------
        # Picking customers for Won Lead and creating list
        # ----------------------------------

        def picking_customers_for_leads(lead):
            lead_country = lead["country"]
            if lead_country in customers_by_country:
                selected_customer = random.choice(customers_by_country[lead_country])
                return selected_customer
            else:
                return random.choice(customers_list)
        
        # ----------------------------------
        # Build Order
        # ----------------------------------

        def build_order(selected_customer, lead = None):

            customer_created_at = pd.to_datetime(selected_customer["created_at"])

            if lead is not None:
                #new orders through leads
                lead_created_at = pd.to_datetime(lead["created_at"])
                earliest = max(lead_created_at, customer_created_at)
                order_date = fake.date_time_between(start_date=earliest, end_date=END_DATE)
                lead_id = lead["lead_id"]

            else:
                    #legacy orders
                    earliest = max(pd.to_datetime(START_DATE), customer_created_at)
                    order_date = fake.date_time_between(start_date=earliest, end_date=END_DATE)
                    lead_id = None

            order_status = random.choices(ORDER_STATUS, weights=ORDER_STATUS_WEIGHTS, k=1)[0]

            if order_status == "Cancelled":
                payment_status = "pending"
            elif order_status in ["Shipped", "Delivered"]:
                payment_status = "paid"
            else:
                payment_status = "pending"
            
            return {
                "order_id" : fake.uuid4().replace("-",""), 
                "customer_id" : selected_customer["customer_id"], 
                "company_id" : selected_customer["company_id"], 
                "lead_id" : lead_id, 
                "order_date" : order_date, 
                "order_status" : order_status,
                "payment_status" : payment_status,
                "order_total" : 0, #Will update later -> SUM(line_total) from order_items
                "created_at" : order_date,
                "updated_at" : fake.date_time_between(start_date=order_date, end_date=END_DATE)
                            
            }


        # ----------------------------------
        # Generate Orders
        # ----------------------------------
        
        orders_dataset = []

        # ----------------------------------
        # Generating legacy customer orders
        # ----------------------------------

        for _ in range(num_orders):
            selected_customer = random.choice(customers_list)
            orders_dataset.append(build_order(selected_customer))


        # ----------------------------------
        # Generate one order for each Won lead
        # ----------------------------------
        for lead in won_leads:
            selected_customer = picking_customers_for_leads(lead)
            orders_dataset.append(build_order(selected_customer, lead))



        orders = pd.DataFrame(orders_dataset)
        logger.info(f"Orders generation successfull, total no. of orders = {len(orders)}")

        # ----------------------------------
        # Validation
        # ----------------------------------
        if (len(orders) == num_orders + len(won_leads)
            and orders["order_id"].is_unique
            and orders.drop(columns=["lead_id"]).notna().all().all()):
             
            logger.info(f"Generated {num_orders} legacy customer orders and {len(won_leads)} lead-originated orders.")
            logger.info("orders data set generated succesfully")

            logger.info(f"Orders with Lead Attribution: {orders['lead_id'].notna().sum()}")

            logger.info(f"Legacy Customer Orders: {orders['lead_id'].isna().sum()}")

            logger.info("Returning Orders Data set....")
            return orders
        
        else:
            raise ValueError("Orders dataset validation failed!")
    except Exception as e:
        logger.error(f"Error generating orders: {e}")
        raise



def generate_order_items(orders,supplier_product_mapping):
    try:
        logger.info("Generating Order Items Leads...")
        orders_list = orders.to_dict("records")
        supplier_product_list = supplier_product_mapping.to_dict("records")
        order_items_dataset = []

        for selected_order in orders_list:
        # ----------------------------------
        # Selecting number of products per order
        # Each order can contain multiple products.
        # ----------------------------------        
            num_items = random.randint(1, 5)

            # Preventing assigining of additional random products than available
            num_products = min(num_items, len(supplier_product_list))

            # multiple products possible
            # no duplicate product in same order
            selected_products = random.sample(supplier_product_list, k = num_products)

            for selected_supplier_product in selected_products:
            # -----------------------------------------------------------------
            # Generate order items in range of products per order
            # -----------------------------------------------------------------    
                quantity = random.randint(1,10)
                supplier_price = float(selected_supplier_product["supplier_price"])
                unit_price = round(supplier_price * random.uniform(1.20,1.60),2)
                discount_amount = round(quantity * unit_price * random.uniform(0,0.20),2)
                line_total = round((quantity * unit_price) - discount_amount,2)
                created_at = selected_order["created_at"]
                updated_at = fake.date_time_between(start_date=created_at, end_date=END_DATE)
        
                order_items_dataset.append({
                    "order_item_id" : fake.uuid4().replace("-",""), 
                    "order_id" : selected_order['order_id'], 
                    "supplier_product_id" : selected_supplier_product["supplier_product_id"], 
                    "quantity" : quantity, 
                    "unit_price" : unit_price, 
                    "discount_amount" : discount_amount, 
                    "line_total" : line_total, 
                    "created_at" : created_at,
                    "updated_at" : updated_at 
                    })

        order_items = pd.DataFrame(order_items_dataset)

        # ----------------------------------
        # Validation
        # ----------------------------------
        if(
            order_items["order_item_id"].is_unique
            and order_items["order_id"].nunique() == len(orders_list)
            and order_items.notna().all().all()
            ):   
            logger.info(f"Generated {len(order_items)} order_items_dataset")
            logger.info("order items dataset generated succesfully")
            logger.info("Returning Order Items Dataset....")
            return order_items

        else:
            logger.info("")
            raise ValueError("Order Items dataset validation failed!")


    except Exception as e:
        logger.error(f"Error generating Order Items dataset {e}")
        raise





def populate_order_totals(orders, order_items):
    try:
        # Calculating total sales amount per order:
        logger.info("Populating order total in orders table by summing up line totals of order items")
        order_totals = (
        order_items
        .groupby("order_id")["line_total"]
        .sum()
        )   
        # Maping calculated totals back into Orders table
        orders["order_total"] = (
        orders["order_id"]
        .map(order_totals).round(2)
        )

        if order_items["order_id"].nunique() != len(orders):
            raise ValueError("Some orders do not have order items")
        else:
            logger.info("Order totals populated successfully")
            return orders
    
    except Exception as e:
        logger.error("Error Populating orders dataset")
        raise




def generate_web_logs (num_web_logs=NUM_WEB_LOGS):
    try:

        logger.info("Generating Web Logs...")
        web_logs_dataset = []

        for _ in range(num_web_logs):
            #choosing country for faker:
            selected_country = select_random_country()

            #creating faker instance according to selected country
            fake_local = faker_instances[selected_country]

            #selecting cities from selected country
            cities = OPERATING_LOCATIONS[selected_country]["cities_hq"]

            city = random.choice(cities)

            is_bot = random.choices([True, False], weights=[5,95], k=1)[0] 
            if is_bot:
                user_agent = random.choice(BOT_USER_AGENTS)
            else:
                user_agent = fake_local.user_agent()

            status_code = random.choices(STATUS_CODES, weights = STATUS_CODE_WEIGHTS, k=1)[0]
            if status_code >= 400:
                bytes_sent = random.randint(100,5000)
            else:
                bytes_sent = random.randint(1000,500000)

            auth_user = None if is_bot else fake_local.user_name()

            web_logs_dataset.append({
                    "log_id" : fake.uuid4().replace("-",""),
                    "country": selected_country,
                    "city" : city,
                    "timestamp" : fake.date_time_between(start_date=START_DATE, end_date=END_DATE),
                    "client_ip" : fake_local.ipv4(),
                    "auth_user" : auth_user,
                    "session_id" : fake.uuid4().replace("-",""),
                    "http_method" : random.choice(HTTP_METHODS),
                    "request_path" : random.choice(REQUEST_PATHS),
                    "status_code" : status_code,
                    "bytes_sent" : bytes_sent,
                    "referer" : random.choice(REFERERS),
                    "device_type": random.choices(DEVICE_TYPES, weights = DEVICE_TYPE_WEIGHTS, k=1)[0],
                    "browser":  random.choices(BROWSERS, weights = BROWSER_WEIGHTS, k=1)[0],
                    "is_bot" : is_bot
            })
 
        web_logs = pd.DataFrame(web_logs_dataset)

        if (len(web_logs)==num_web_logs
            and web_logs["log_id"].is_unique):
            logger.info(f"Succefully generated weblogs : {len(web_logs)}")
            return web_logs
        else:
            raise ValueError("Web Logs dataset validation failed")

    except Exception as e:
        logger.error(f"Error generating web logs: {e}")
        raise
        





def load_source2(marketing_leads):
    try:
        logger.info("Loading Marketing Dataset to File.csv........")
        marketing_leads.to_csv(MARKETING_LEADS_OUTPUT_PATH, index = False)
        logger.info("Successfully loaded Marketing Leads Dataset to File")
    except Exception as e:
        raise ValueError("Error loading marketing leads to file")

def load_source3(web_logs):
    try:
        logger.info("Loading Web Logs Dataset to File.csv........")
        web_logs.to_csv(WEB_LOGS_OUTPUT_PATH, index = False)
        logger.info("Successfully loaded Web logs Dataset to File")
    except Exception as e:
        raise ValueError("Error loading web_logs to file")
        

def load_customers_from_sqlserver():
    return pd.read_sql("SELECT * FROM source.Customers", SQL_SERVER_ENGINE)

def load_countries_from_sqlserver():
    return pd.read_sql("SELECT * FROM source.Companies", SQL_SERVER_ENGINE)

def load_supplier_product_mapping_from_sqlserver():
    return pd.read_sql("SELECT * FROM source.Supplier_Product_Mapping", SQL_SERVER_ENGINE)



def fetching_customer_dataset():
   
    customers = load_customers_from_sqlserver()
    return customers

def fetching_companies_dataset():
    companies = load_countries_from_sqlserver()
    return companies


def fetching_supplier_product_mapping_dataset():
    supplier_product_mapping = load_supplier_product_mapping_from_sqlserver()
    return supplier_product_mapping



def generating_orders_and_orderitems_datasets(marketing_leads):
    try:
        # -----------------------------------------------
        #       Fetching Required datasets
        # -----------------------------------------------
        logger.info("Fetching required datasets to generate orders and order_items")    
        customers = fetching_customer_dataset()
        companies = fetching_companies_dataset()
        supplier_product_mapping = fetching_supplier_product_mapping_dataset()

        orders = generate_orders(companies,customers,marketing_leads)
        order_items = generate_order_items(orders,supplier_product_mapping)
        orders = populate_order_totals(orders, order_items)

        logger.info("Returning all Datasets....")
        return {
            "orders": orders,
            "order_items": order_items,
            }
    except Exception as e:
        logger.error("Error generating datasets")
        raise


if __name__ == "__main__":


# Generating Datasets
    marketing_leads = generate_marketing_leads()
    web_logs = generate_web_logs()

    datasets = generating_orders_and_orderitems_datasets(marketing_leads)
    
# Loading Datasets to SQL SERVER
    load_to_sqlserver(datasets)
    load_source2(marketing_leads)
    load_source3(web_logs)



  
  


    
    



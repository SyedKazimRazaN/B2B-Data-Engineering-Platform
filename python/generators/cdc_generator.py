from python.generators.load_to_sqlserver import load_to_sqlserver
from python.generators.transaction_generator import (
generate_orders,
generate_order_items,
generating_orders_and_orderitems_datasets,
generate_marketing_leads,
generate_web_logs,
populate_order_totals
)
import pandas as pd
from faker import Faker
from config.database import (SQL_SERVER_ENGINE, text)
import random
from python.utils.logger import get_logger
from python.utils.seed_manager import get_live_seed
from datetime import datetime
import os
from config.config import (
RANDOM_SEED,
MARKETING_LEADS_OUTPUT_PATH,
WEB_LOGS_OUTPUT_PATH,
)
from python.utils.constants import (
OPERATING_LOCATIONS,
JOB_TITLES,
FUNNEL_STAGES,
FUNNEL_SCORE_RANGE,
DOMAINS
)

# ----------------------------------------------------------
# Global configuration setup for Daily seeding
# ----------------------------------------------------------
LIVE_SEED = get_live_seed()  # persisted to metadata.Generation_Seeds for traceability
Faker.seed(LIVE_SEED)
random.seed(LIVE_SEED)
logger = get_logger(__name__)
logger.info(f"Daily generator seeded with LIVE_SEED = {LIVE_SEED} (logged in metadata.Generation_Seeds)")

def initialize_faker_instances(): #localized faker for Company dataset
    faker_instances = {}

    for country, details in OPERATING_LOCATIONS.items():
        faker_instances[country] = Faker(details["locale"])
        faker_instances[country].seed_instance(RANDOM_SEED)

    return faker_instances

faker_instances = initialize_faker_instances()

# -----------------------------
# Data Fetching
# -----------------------------

def fetch_required_datasets():
    try:
        logger.info("fetching required Datasets....")
        companies = pd.read_sql("SELECT * FROM source.Companies", SQL_SERVER_ENGINE)
        
        customers = pd.read_sql("SELECT * FROM source.Customers", SQL_SERVER_ENGINE)
        
        #products = pd.read_sql("SELECT * FROM source.Products", SQL_SERVER_ENGINE)
        
        supplier_product_mapping = pd.read_sql("SELECT * FROM source.Supplier_Product_Mapping", SQL_SERVER_ENGINE)
        

        logger.info("Returning all Datasets....")
        return {
            "companies": companies,
            "customers": customers,
            #"products": products,
            "supplier_product_mapping": supplier_product_mapping,
        }
    except Exception as e:
        logger.error(f"Error fetching required Datasets {e}")
        raise

# -----------------------------
# Data Generators
# -----------------------------

def generate_daily_datasets(fetched_datasets):
    try:
        logger.info("Generating Daily Datasets......")
        companies = fetched_datasets["companies"]
        customers = fetched_datasets["customers"]
        supplier_product_mapping = fetched_datasets["supplier_product_mapping"]
        num_orders = random.randint(30,50)
        num_leads = random.randint(15,30)
        num_web_logs = random.randint(700, 1200)

        daily_web_logs = generate_web_logs(num_web_logs)
        daily_leads = generate_marketing_leads(num_leads)
        daily_orders = generate_orders(companies, customers, daily_leads, num_orders) 

#        sanity check for newly generated orders len
        if len(daily_orders) > num_orders + 10:
            raise ValueError(f"generate_orders() returned {len(daily_orders)} rows, expected around {num_orders}.")

        daily_order_items = generate_order_items(daily_orders,supplier_product_mapping) 
        populate_order_totals(daily_orders, daily_order_items) #filling order totals in orders from order items

        logger.info("Daily Datasets Generated Succesfully!")
        logger.info(f"Generated {len(daily_orders)} Orders")

        logger.info(f"Generated {len(daily_order_items)} Order Items")

        logger.info(f"Generated {len(daily_leads)} Leads")

        logger.info(f"Generated {len(daily_web_logs)} Web Logs")

        return {
            "web_logs" : daily_web_logs,
            "marketing_leads"    : daily_leads,
            "orders"   : daily_orders,
            "order_items" : daily_order_items
        }

    
    except Exception as e:
        logger.error(f"Error Generating daily datasets {e}")
        raise 


def generate_daily_updates():
    try:
        logger.info("Generating daily updates....")
        updates = {}

        try:
            updates["companies_updates"] = generate_and_update_companies()
        except Exception as e:
            logger.error(f"Company updates failed: {e}")
            updates["companies_updates"] = 0

        try:
            updates["customers_updates"] = generate_and_update_customers()
        except Exception as e:
            logger.error(f"Customer updates failed: {e}")
            updates["customers_updates"] = 0

        try:
            updates["orders_updates"] = generate_and_update_orders()
        except Exception as e:
            logger.error(f"Order updates failed: {e}")
            updates["orders_updates"] = 0

        try:
            updates["leads_updates"] = generate_and_update_leads()
        except Exception as e:
            logger.error(f"Lead updates failed: {e}")
            updates["leads_updates"] = 0

        try:
            updates["products_deactivated"] = generate_and_deactivate_products()
        except Exception as e:
            logger.error(f"Product deactivation failed: {e}")
            updates["products_deactivated"] = 0

        return updates

    except Exception as e:
        logger.error("Error generating daily updates {e}")
        raise




def loading_to_sources(daily_datasets):
    try:
        logger.info("Loading Daily Datasets into Sources")

        #Marketing Leads
        file_exists = os.path.exists(MARKETING_LEADS_OUTPUT_PATH)
        daily_datasets["marketing_leads"].to_csv(MARKETING_LEADS_OUTPUT_PATH, mode='a', header=not file_exists, index=False)
        logger.info("Succesfully loaded daily leads in Source 2")

        #Web Logs
        file_exists = os.path.exists(WEB_LOGS_OUTPUT_PATH)
        daily_datasets["web_logs"].to_csv(WEB_LOGS_OUTPUT_PATH, mode='a', header=not file_exists, index=False)
        logger.info("Succesfully loaded daily web logs in Source 3")

        #Orders & Order Items
        load_to_sqlserver(daily_datasets)  
        logger.info("Succesfully loaded new daily orders and its order items in Source 1")


        return
    except Exception as e:
        logger.error("Error Loading Daily Datasets into Sources {e}")
        raise
    


def generate_and_update_companies():
    try:
        logger.info("Generating company updates")
        num_companies = random.randint(1, 3)

        query = f"""
        SELECT TOP {num_companies} 
            company_id,
            company_name, 
            rating, 
            city,
            country
        FROM source.Companies
        ORDER BY NEWID()
        """

        selected_companies = pd.read_sql(query, con=SQL_SERVER_ENGINE).to_dict("records")

        for company in selected_companies:

            country = company["country"]
            fake_local = faker_instances[country]

            # Keep company name mostly stable
            company_name = company["company_name"]
            if random.random() < 0.20:
                company_name = f"{company_name} Group"

            rating = round(min(5.0, max(1.0, company["rating"] + random.uniform(-0.3, 0.3)) ), 2)

            city = random.choice(OPERATING_LOCATIONS[country]["cities_hq"])

            address = fake_local.street_address()

            with SQL_SERVER_ENGINE.begin() as conn:
                conn.execute(
                    text("""
                        UPDATE source.Companies
                        SET
                            company_name = :company_name,
                            rating = :rating,
                            city = :city,
                            address = :address,
                            updated_at = :updated_at
                        WHERE company_id = :company_id
                    """),
                    {
                        "company_name": company_name,
                        "rating": rating,
                        "city": city,
                        "address": address,
                        "updated_at": datetime.now(),
                        "company_id": company["company_id"]
                    }
            )

        logger.info(f"Successfully updated {len(selected_companies)} companies")
        return len(selected_companies)

    except Exception as e:
        logger.error(f"Error updating companies: {e}")
        raise


def generate_and_update_customers():
    try:
        logger.info("Generating customer updates")
        num_customers = random.randint(3,5)
        query = f"""SELECT TOP {num_customers} 
                        customer_id,
                        first_name,
                        last_name,
                        email,
                        phone_number,
                        job_title,
                        country 
                    FROM source.Customers c 
                    LEFT JOIN source.Companies co 
                    ON co.company_id = c.company_id
                    ORDER BY NEWID()"""
        selected_customers_dataframe = pd.read_sql(query, con=SQL_SERVER_ENGINE).to_dict("records")

        for customer in selected_customers_dataframe:
                fake_local = faker_instances[customer["country"]]
                first_name = customer["first_name"]
                last_name = customer["last_name"]
                email_username = (f"{first_name}.{last_name}+updated".lower().replace(" ","").replace("-",""))
                email = f"{email_username}{random.randint(1000,999999)}@{random.choice(DOMAINS)}"

                previous = customer["job_title"]
                available = [item for item in JOB_TITLES if item != previous]
                job_title = random.choice(available)

                phone_number = "".join(filter(str.isdigit, fake_local.phone_number()))        
                while len(phone_number) < 12:
                    phone_number += str(random.randint(0, 9))

                logger.info("Updating Customers....")
                with SQL_SERVER_ENGINE.begin() as conn:
                    conn.execute(
                        text("""
                        UPDATE source.Customers
                        SET
                            phone_number = :phone_number,
                            email = :email,
                            job_title = :job_title,
                            updated_at = :updated_at
                            WHERE customer_id = :customer_id
                        """),
                        {
                            "phone_number": phone_number,
                            "email": email,
                            "customer_id": customer["customer_id"],
                            "job_title": job_title,
                            "updated_at": datetime.now()
                            }
                    )
        logger.info("Successfully updated customers")
        return len(selected_customers_dataframe)
        
    except Exception as e:
        logger.error("Error generating and updating customers")
        raise
            

def generate_and_update_orders():
    try:
        logger.info("Generating orders updates")
        num_orders = random.randint(5,10)
        query = f"""SELECT TOP {num_orders} * FROM source.Orders ORDER BY NEWID()"""
        selected_orders_dataframe = pd.read_sql(query, con=SQL_SERVER_ENGINE).to_dict("records")

        for order in selected_orders_dataframe:
            if order["order_status"] == "Processing":
                status = random.choice(["Confirmed", "Cancelled"])
            elif order["order_status"] == "Confirmed":
                status = "Shipped"
            elif order["order_status"] == "Shipped":
                status = "Delivered"
            else:
                continue

            logger.info("Updating Orders....")
            with SQL_SERVER_ENGINE.begin() as conn:
                conn.execute(
                    text("""UPDATE source.Orders 
                        SET
                            order_status = :status,
                            updated_at = :update_time
                        WHERE order_id = :order_id
                        """),
                        {"status": status,"update_time": datetime.now(),"order_id" :order["order_id"]}
                )
        logger.info("Successfully updated Orders")
        return len(selected_orders_dataframe)
        
    except Exception as e:
        logger.error("Error generating and updating Orders")
        raise
            

def generate_and_update_leads():
    try:
        logger.info("Generating leads updates")
        num_leads = random.randint(5,8)

        leads = pd.read_csv(MARKETING_LEADS_OUTPUT_PATH)

        sample_size = num_leads

        selected_leads = leads.sample(n=min(sample_size, len(leads)))

        for index, lead in selected_leads.iterrows():
            current_stage = lead["funnel_stage"]
            remaining_stages = FUNNEL_STAGES[FUNNEL_STAGES.index(current_stage)+1:]

            if not remaining_stages:
                continue
            
            selected_stage = random.choice(remaining_stages)

            min_score, max_score = FUNNEL_SCORE_RANGE[selected_stage]

            lead_score = random.randint(min_score, max_score)

            leads.loc[index, "funnel_stage"] = selected_stage
            leads.loc[index, "lead_score"] = lead_score
            leads.loc[index, "updated_at"] = datetime.now()

        leads.to_csv(MARKETING_LEADS_OUTPUT_PATH,index=False)

        logger.info(f"Successfully updated {len(selected_leads)} marketing leads")
        return len(selected_leads)

        
    except Exception as e:
        logger.error("Error generating and updating Orders")
        raise


def generate_and_deactivate_products():
    """
    Soft-delete simulation: occasionally discontinue a small number of
    currently active products (is_active = False), per docs/project_plan.md's
    "Daily Inserts -> Daily Updates -> Daily Soft Deletes" CDC step.

    Scoped to Products because it's the only source table with an is_active
    column end-to-end (source -> staging -> intermediate -> dim_products).
    One-directional: deactivated products are never reactivated here.
    """
    try:
        logger.info("Generating product deactivations")
        num_deactivations = random.randint(0, 2)

        if num_deactivations == 0:
            logger.info("No products selected for deactivation today")
            return 0

        query = f"""
        SELECT TOP {num_deactivations} product_id, product_name
        FROM source.Products
        WHERE is_active = 1
        ORDER BY NEWID()
        """
        selected_products = pd.read_sql(query, con=SQL_SERVER_ENGINE).to_dict("records")

        for product in selected_products:
            with SQL_SERVER_ENGINE.begin() as conn:
                conn.execute(
                    text("""
                        UPDATE source.Products
                        SET
                            is_active = 0,
                            updated_at = :updated_at
                        WHERE product_id = :product_id
                    """),
                    {
                        "updated_at": datetime.now(),
                        "product_id": product["product_id"]
                    }
                )
            logger.info(f"Deactivated product: {product['product_name']}")

        logger.info(f"Successfully deactivated {len(selected_products)} products")
        return len(selected_products)

    except Exception as e:
        logger.error(f"Error deactivating products: {e}")
        raise


if __name__ == "__main__":

    fetched_datasets = fetch_required_datasets()
    daily_datasets = generate_daily_datasets(fetched_datasets)
    loading_to_sources(daily_datasets)
    
    updated_datasets = generate_daily_updates()
    logger.info("Daily ingestion and CDC simulation completed successfully.")

    logger.info(
    "Daily CDC Summary\n"
    "----------------------------\n"
    f"New Orders: {len(daily_datasets['orders'])}\n"
    f"New Order Items: {len(daily_datasets['order_items'])}\n"
    f"New Leads: {len(daily_datasets['marketing_leads'])}\n"
    f"New Web Logs: {len(daily_datasets['web_logs'])}\n\n"
    f"Updated Companies: {updated_datasets['companies_updates']}\n"
    f"Updated Customers: {updated_datasets['customers_updates']}\n"
    f"Updated Orders: {updated_datasets['orders_updates']}\n"
    f"Updated Leads: {updated_datasets['leads_updates']}\n"
    f"Deactivated Products: {updated_datasets['products_deactivated']}"
)




"""load_orders(daily_datasets["orders"])
    load_marketing_leads
    load_weblogs"""
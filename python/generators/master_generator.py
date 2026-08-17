"""
Master (Source 1) generator: builds the initial, one-time "seed" dataset
for Source 1 - Companies, Categories, Customers, Products, Suppliers, and
the Supplier_Product_Mapping - then loads it into SQL Server.

Execution Flow (__main__):
    generate_master_datasets()
        ├── generate_categories()
        ├── generate_companies()
        ├── generate_customers(companies)
        ├── generate_products(categories)
        ├── generate_suppliers(companies)
        └── generate_supplier_product_mapping(suppliers, products)
    -> load_to_sqlserver(master_datasets)

Run once to initialize Source 1; daily incremental changes afterwards are
handled by cdc_generator.py.
"""

import pandas as pd
from faker import Faker
from python.utils.logger import get_logger
import random
from python.generators.load_to_sqlserver import load_to_sqlserver
from config.config import (
    START_DATE,
    END_DATE,
    RANDOM_SEED,
    NUM_COMPANIES,
    MIN_CUSTOMERS_PER_COMPANY,
    MAX_CUSTOMERS_PER_COMPANY, 
    NUM_SUPPLIERS,
    MIN_SUPPLIERS_PER_PRODUCT,
    MAX_SUPPLIERS_PER_PRODUCT,
    NUM_CATEGORIES,
)
from python.utils.constants import (
    COMPANY_TYPES,
    OPERATING_LOCATIONS,
    DOMAINS,
    GENDERS,
    JOB_TITLES,
    PRODUCT_TEMPLATES,
    PRODUCT_BRANDS,
    PRODUCT_VARIANTS,
    PRICE_RANGES,
    ONBOARDING_MONTH_WEIGHTS,
    ONBOARDING_DOW_WEIGHTS,
)
from python.utils.date_weighting import weighted_datetime_between


Faker.seed(RANDOM_SEED)
random.seed(RANDOM_SEED) #controlling random.choice, .choices & .uniform
logger = get_logger(__name__)
fake = Faker()

# -----------------------------
# Helper Functions
# -----------------------------

def initialize_faker_instances(): #localized faker for Company dataset
    faker_instances = {}

    for country, details in OPERATING_LOCATIONS.items():
        faker_instances[country] = Faker(details["locale"])
        faker_instances[country].seed_instance(RANDOM_SEED)

    return faker_instances


def select_random_country():
    """
    Selecting a country based on configured weights
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

def generate_companies():
    logger.info("Generating Companies...")
    try:

        companies_records = []

        #company type distribution according to rule no. 
        buyer_type = COMPANY_TYPES[0]
        supplier_type = COMPANY_TYPES[1]
        company_types = (
            [supplier_type] * NUM_SUPPLIERS +
            [buyer_type] * (NUM_COMPANIES - NUM_SUPPLIERS)
        )
        random.shuffle(company_types)


        for i in range(NUM_COMPANIES):
            #choosing country for faker:
            selected_country = select_random_country()

            #creating faker instance according to selected country
            fake_local = faker_instances[selected_country]

            #selecting cities from selected country
            city = random.choice(OPERATING_LOCATIONS[selected_country]["cities_hq"])


            created_at = weighted_datetime_between(
                fake_local, START_DATE, END_DATE,
                month_weights=ONBOARDING_MONTH_WEIGHTS, dow_weights=ONBOARDING_DOW_WEIGHTS,
            )
            updated_at = weighted_datetime_between(
                fake_local, created_at, END_DATE, dow_weights=ONBOARDING_DOW_WEIGHTS,
            )

            companies_records.append({
                "company_id" : fake.uuid4().replace("-",""),    #using global fake instead of fake_locale to maintain global uniqueness
                "company_name" : fake.unique.company(),
                "company_type" : company_types[i],
                "cuit_tax_id" : fake.unique.bothify("##-########-#"),
                "rating": round(random.uniform(2.5, 5.0), 1),
                "country" : selected_country,
                "city" : city,
                "address" : fake_local.street_address(),
                "created_at" : created_at,
                "updated_at" : updated_at

            }
            )

        companies = pd.DataFrame(companies_records)
        logger.info(f"\nCompany Type Distribution:\n{companies['company_type'].value_counts()}")

        #validation checks:
        if (
            len(companies) == NUM_COMPANIES 
            and companies["company_id"].is_unique
            and companies["company_name"].is_unique
            and companies["cuit_tax_id"].is_unique
            and companies.notna().all().all()
        ):
                logger.info(f"Generated {len(companies)} company records successfully!")
                return companies
        else:
                raise ValueError("Companies dataset validation failed")
                


    except Exception as e:
        logger.error(f"Error generating companies dataset: {e}")
        raise



def generate_categories():
    logger.info("Generating Categories.....")

    try:
         
        categories_records = []
        for category in PRODUCT_TEMPLATES:
            created_at = fake.date_time_between(start_date=START_DATE, end_date=END_DATE)
            updated_at = fake.date_time_between(start_date=created_at, end_date=END_DATE)

            categories_records.append({
                "category_id" : fake.uuid4().replace("-",""),
                "category_name" : category,
                "created_at" : created_at,
                "updated_at" : updated_at
            })
        categories = pd.DataFrame(categories_records)


        #Validation Checks:
        if (
            len(categories) == NUM_CATEGORIES
            and categories["category_id"].is_unique
            and categories["category_name"].is_unique
            and categories.notna().all().all()
        ):
            logger.info(f"Generated {len(categories)} categories")
            logger.info("Categories data set generated succesfully")
            logger.info("Returning Categories Data set....")
            return categories
        else:
            raise ValueError("CATEGORIES DATASET validation failed!")

    except Exception as e:
        logger.error(f"Error Generating Categories Dataset {e}")
        raise
         




def generate_customers(companies):
    try:
        logger.info("Generating Customers.....")

        buyer_companies = companies[companies["company_type"] == "Buyer"].to_dict("records")
        customers_dataset =[]
        

        
        for company in buyer_companies: #ensuring every company gets no. of CUSTOMERS according to rule 1 
            fake_local = faker_instances[company["country"]]
            num_customers_for_this_company = random.randint(MIN_CUSTOMERS_PER_COMPANY, MAX_CUSTOMERS_PER_COMPANY)   # Rule 1 range,

            for _ in range(num_customers_for_this_company):

                created_at = weighted_datetime_between(
                    fake, company["created_at"], END_DATE,
                    month_weights=ONBOARDING_MONTH_WEIGHTS, dow_weights=ONBOARDING_DOW_WEIGHTS,
                )
                updated_at = weighted_datetime_between(
                    fake, created_at, END_DATE, dow_weights=ONBOARDING_DOW_WEIGHTS,
                )


                selected_gender = random.choice(GENDERS)
                if selected_gender == "Male":
                    first_name = fake_local.first_name_male()
                    last_name = fake_local.last_name_male()
                else:
                    first_name = fake_local.first_name_female()
                    last_name = fake_local.last_name_female()

                email_username = (f"{first_name}.{last_name}".lower().replace(" ","").replace("-",""))
                phone = "".join(filter(str.isdigit, fake_local.phone_number()))
                while len(phone) < 12:
                    phone += str(random.randint(0, 9))

                customers_dataset.append ({
                    "customer_id" : fake.uuid4().replace("-",""),
                    "company_id" : company["company_id"],
                    "first_name" : first_name,
                    "last_name" : last_name, 
                    "email": f"{email_username}{random.randint(1000,999999)}@{random.choice(DOMAINS)}",
                    "phone_number" : phone[:12], 
                    "gender" : selected_gender, 
                    "date_of_birth" : fake.date_of_birth(minimum_age=25, maximum_age=70), 
                    "job_title" : random.choice(JOB_TITLES),
                    "created_at" : created_at,
                    "updated_at" : updated_at        
                })

        customers = pd.DataFrame(customers_dataset)
        logger.debug("\nCustomers per company:\n%s",
             customers.groupby("company_id").size().describe())



        #Data validation
        total_buyer_companies = len(buyer_companies)
        minimum_expected_customers = (total_buyer_companies * MIN_CUSTOMERS_PER_COMPANY)

        maximum_expected_customers = (total_buyer_companies * MAX_CUSTOMERS_PER_COMPANY)


        if (
            minimum_expected_customers <= len(customers) <= maximum_expected_customers
            and customers["customer_id"].is_unique
            and customers["email"].is_unique
            and customers.notna().all().all()
                ):    
            logger.info(f"Generated {len(customers)} customers")
            logger.info("Customers data set generated succesfully")
            logger.info("Returning Customers Data set....")
            return customers
        else:
            raise ValueError("Customers dataset validation failed!")
    
    except Exception as e:
        logger.error(f"Error Generating Customers Dataset {e}")
        raise

def generate_products(categories):
    try:
        logger.info("Generating Products......")
                #product_name = random.choice(categories[categories["category_name"]])

        products_records = []

        for _, category in categories.iterrows():
         category_name = category["category_name"]

         for product_name in PRODUCT_TEMPLATES[category_name]:
                min_price = PRICE_RANGES[category_name][0]
                max_price = PRICE_RANGES[category_name][1]
                cost_price = round(random.uniform(min_price,max_price), 2)
                catalog_price = round(cost_price * random.uniform(1.2, 2.5), 2)
                selected_brand = random.choice(PRODUCT_BRANDS[category_name])
                selected_variant = random.choice(PRODUCT_VARIANTS)
                
                created_at = weighted_datetime_between(
                    fake, START_DATE, END_DATE,
                    month_weights=ONBOARDING_MONTH_WEIGHTS, dow_weights=ONBOARDING_DOW_WEIGHTS,
                )
                updated_at = weighted_datetime_between(
                    fake, created_at, END_DATE, dow_weights=ONBOARDING_DOW_WEIGHTS,
                )

                products_records.append({
                    "product_id" : fake.uuid4().replace("-",""), 
                    "sku" : f"{fake.unique.bothify(text='??-####').upper()}", 
                    "product_name" : product_name, 
                    "category_id" : category["category_id"], 	
                    "brand" : selected_brand,
                    "variant" : selected_variant,
                    "cost_price" : cost_price,
                    "catalog_price" :catalog_price,  
                    "is_active" : random.choices([True, False], weights=[90, 10],k=1)[0],
                    "created_at" : created_at,
                    "updated_at" : updated_at 
                    })

        products = pd.DataFrame(products_records)

        logger.info("Starting data validation")
        #Data Validation:
        if(products["product_id"].is_unique
           and products["sku"].is_unique
           and (products["catalog_price"] >= products["cost_price"]).all()
           and (products["updated_at"] >= products["created_at"]).all()
           and products.notna().all().all()):
            logger.info(f"Generated {len(products)} products")
            logger.info("Products data set generated succesfully")
            logger.info("Returning Products Data set....")
            return  products
            
        else:
            raise ValueError("Products dataset validation failed!")
    
    except Exception as e:
        logger.error(f"Error Generating Products Dataset {e}")
        raise





def generate_suppliers(companies):
    try:
        logger.info("Generating Suppliers.....")

        supplier_companies = companies[companies["company_type"] == "Supplier"].to_dict("records")
        suppliers_dataset =[]

        
        for company in supplier_companies: #ensuring every company gets no. of CUSTOMERS according to rule 1 
            fake_local = faker_instances[company["country"]]
            selected_company = company

            first_name = fake_local.first_name()
            last_name = fake_local.last_name()
            supplier_name = selected_company["company_name"]
            
            email_username = (f"{first_name}.{last_name}".lower().replace(" ","").replace("-",""))
            custom_domain = supplier_name.split()[0].lower().replace(" ","").replace("-","")

            phone = "".join(filter(str.isdigit, fake_local.phone_number()))
            while len(phone) < 12:
                phone += str(random.randint(0, 9))


            created_at = weighted_datetime_between(
                fake, selected_company["created_at"], END_DATE,
                month_weights=ONBOARDING_MONTH_WEIGHTS, dow_weights=ONBOARDING_DOW_WEIGHTS,
            )
            updated_at = weighted_datetime_between(
                fake, created_at, END_DATE, dow_weights=ONBOARDING_DOW_WEIGHTS,
            )

            suppliers_dataset.append({
                "supplier_id" : fake.uuid4().replace("-",""), 
                "company_id" : selected_company["company_id"],
                "supplier_name" : supplier_name, 
                "contact_name" : f"{first_name} {last_name}",
                "email": f"{email_username}{random.randint(1000,999999)}@{custom_domain}.com",
                "phone_number" : phone,
                "created_at" : created_at,
                "updated_at" : updated_at
                })

            suppliers = pd.DataFrame(suppliers_dataset)
        if (suppliers["supplier_id"].is_unique
            and suppliers["email"].is_unique
            and suppliers.notna().all().all()
            ):               
                    logger.info(f"Generated {len(suppliers)} suppliers")
                    logger.info("Suppliers data set generated succesfully")
                    logger.info("Returning Suppliers Data set....")
                    return suppliers
        else:
            raise ValueError("Suppliers dataset validation failed!")
            
    except Exception as e:
        logger.error(f"Error Generating Suppliers Dataset {e}")
        raise
        


def generate_supplier_product_mapping(suppliers,products):

    try:
        logger.info("Generating Supplier Product Mapping.....")

        supplier_records = suppliers.to_dict("records")
        product_records = products.to_dict("records")
        suppliers_product_mapping_dataset =[]
            
        for product in product_records:                  
            num_suppliers_for_this_product = random.randint(MIN_SUPPLIERS_PER_PRODUCT, MAX_SUPPLIERS_PER_PRODUCT)
            selected_supplier = random.sample(supplier_records,num_suppliers_for_this_product)
            preferred_supplier = random.choice(selected_supplier)
            
            for supplier in selected_supplier: #ensuring every product get min  suppliers according to Rule

                created_at = weighted_datetime_between(
                    fake, product["created_at"], END_DATE,
                    month_weights=ONBOARDING_MONTH_WEIGHTS, dow_weights=ONBOARDING_DOW_WEIGHTS,
                )
                updated_at = weighted_datetime_between(
                    fake, created_at, END_DATE, dow_weights=ONBOARDING_DOW_WEIGHTS,
                )
                supplier_price = round(product["cost_price"] * random.uniform(0.95, 1.05),2)   
                is_prefered = preferred_supplier["supplier_id"] == supplier["supplier_id"] 
                
                suppliers_product_mapping_dataset.append(
                    {
                        "supplier_product_id" : fake.uuid4().replace("-",""), 
                        "supplier_id" : supplier["supplier_id"], 
                        "product_id" : product["product_id"], 
                        "supplier_price" : supplier_price,
                        "lead_time_days" : random.randint(3,21), 
                        "is_preferred_supplier" : is_prefered, 
                        "created_at" : created_at, 
                        "updated_at" : updated_at 
                    }
                )

        total_products = len(products)
        minimum_expected_products = total_products * MIN_SUPPLIERS_PER_PRODUCT
        maximum_expected_products = total_products * MAX_SUPPLIERS_PER_PRODUCT
        suppliers_product_mapping = pd.DataFrame(suppliers_product_mapping_dataset)
        preferred_count = (suppliers_product_mapping.groupby("product_id")["is_preferred_supplier"].sum())



        if (
             minimum_expected_products <= len(suppliers_product_mapping) <= maximum_expected_products
             and suppliers_product_mapping["supplier_product_id"].is_unique
             and suppliers_product_mapping.notna().all().all()
             and (preferred_count == 1).all()
             ):    
                    logger.info(f"Generated {len(suppliers_product_mapping)} suppliers_product_mappings")
                    logger.info("suppliers_product_mapping data set generated succesfully")
                    logger.info("Returning suppliers_product_mapping Data set....")
                    return suppliers_product_mapping
        else:
            raise ValueError("Suppliers_product_mapping dataset validation failed!")
        
    except Exception as e:
        logger.error(f"Error Generating Supplier Product Mapping Dataset {e}")
        raise


def generate_master_datasets():
    logger.info("Generating all Datasets....")
    categories = generate_categories()
    companies = generate_companies()
    customers = generate_customers(companies)
    products = generate_products(categories)
    suppliers = generate_suppliers(companies)
    supplier_product_mapping = generate_supplier_product_mapping(suppliers, products)

    logger.info("Returning all Datasets....")
    return {
        "categories": categories,
        "companies": companies,
        "customers": customers,
        "products": products,
        "suppliers": suppliers,
        "supplier_product_mapping": supplier_product_mapping
    }







if __name__ == "__main__":


    master_datasets = generate_master_datasets()
    load_to_sqlserver(master_datasets)







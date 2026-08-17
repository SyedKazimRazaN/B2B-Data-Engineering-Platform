"""
Static lookup values and weighted-distribution tables shared by the
generators - operating locations/locales, product catalog templates,
lead/traffic sources, order/payment status options, and the seasonal
month/day-of-week/hour weight tables used by date_weighting.py - plus
the raw SQL queries (SOURCE1_QUERIES) used by sql_server_pipeline.py.
"""

# ======================================
# Business Constants
# =====================================

#----------------------------------------------------------------------------------------
    #Source_1 (SQL Server)
#----------------------------------------------------------------------------------------
COMPANY_TYPES = ["Buyer", "Supplier"]
COMPANY_TYPE_WEIGHTS = [70, 30]
ORDER_STATUS = ['Confirmed',"Pending","Processing","Shipped","Delivered","Cancelled"]
ORDER_STATUS_WEIGHTS = [10, 5, 10, 20, 50, 5]
PAYMENT_STATUS = ["pending", "paid", "failed", "refunded"]
PAYMENT_STATUS_WEIGHTS = [10, 82, 3, 5]
OPERATING_LOCATIONS = {                        # Used for weighted geographic distribution and Faker locale selection
    "United States": {
        "locale": "en_US",
        "weight": 70,
        "cities_hq": ["New York", "Chicago", "Dallas", "Austin", "Seattle"]
    },
    "United Kingdom": {
        "locale": "en_GB",
        "weight": 20,
        "cities_hq": ["London","Manchester","Birmingham"]
    },

    "Australia": {
        "locale": "en_AU",
        "weight": 10,
        "cities_hq": ["Sydney","Melbourne","Brisbane"]
    }
}

DOMAINS = ["gmail.com", "outlook.com", "yahoo.com", "hotmail.com"]
GENDERS = ["Male", "Female"]

JOB_TITLES = [
    "CEO",
    "CFO",
    "Procurement Manager",
    "Purchasing Officer",
    "Sales Manager",
    "Operations Manager",
    "Supply Chain Manager",
    "Warehouse Manager",
    "Inventory Manager",
    "IT Manager",
    "Finance Manager",
    "Marketing Manager",
    "HR Manager"
]


#-----------------------------------------------------------------------------------------
    #Source_2 (Web Logs)
#----------------------------------------------------------------------------------------
REFERERS = ['https://google.com', 'https://bing.com', 'https://twitter.com']
HTTP_METHODS = ["GET","POST","PUT","DELETE"]
STATUS_CODES = [200, 201, 301, 400, 401, 403, 404, 500]
STATUS_CODE_WEIGHTS = [70, 5, 5, 5, 3, 2, 8, 2]
REQUEST_PATHS = ["/", "/login", "/products", "/products/123", "/api/customers", "/api/orders", "/checkout", "/search?q=laptop"]
BOT_USER_AGENTS = ["Googlebot","Bingbot", "curl","PostmanRuntime"]


#----------------------------------------------------------------------------------------
    #Source_3 (Marketing Leads)
#----------------------------------------------------------------------------------------
# Where the business says the lead came from
LEAD_SOURCES = ["Website", "Referral", "Cold Call", "Trade Show", "Email Campaign", "Partner"]

# Digital platform that generated the visit
UTM_SOURCES = ["google", "facebook", "linkedin", "bing", "newsletter"]

# Marketing channel/type
UTM_MEDIUMS = ["organic", "cpc", "email", "social", "referral"]

CAMPAIGNS = ["Summer Sale", "Enterprise Growth", "Product Launch", "Holiday Promotion", "Free Trial Campaign", "Industry Expo", "Referral Drive"]

COMPANY_SIZES = ["1-10", "11-50", "51-200", "201-500", "500+"]
COMPANY_SIZE_WEIGHTS = [30, 30, 20, 12, 8]
ORDER_VALUE_RANGE = {
    "1-10": (1_000, 10_000),
    "11-50": (10_000, 50_000),
    "51-200": (50_000, 150_000),
    "201-500": (150_000, 500_000),
    "500+": (500_000, 2_000_000)
}

INDUSTRIES = ["Technology", "Healthcare", "Finance", "Retail", "Manufacturing", "Education","Construction","Logistics","Energy", "Hospitality"]

FUNNEL_STAGES = ["New", "Contacted", "Qualified", "Proposal", "Negotiation", "Won", "Lost"]
FUNNEL_STAGE_WEIGHTS = [35,25,15,10,8,4,3]
FUNNEL_SCORE_RANGE = {
    "New": (1, 16),
    "Contacted": (17, 32),
    "Qualified": (33, 48),
    "Proposal": (49, 64),
    "Negotiation": (65, 80),
    "Won": (81, 100),
    "Lost": (1, 80)
}


PRODUCT_TEMPLATES = {
    "Electronics" : ["Laptop", "Smartphone", "Wireless Headphones", "Keyboard", "Monitor", "Smart Watch", "Printer", "Mouse"],

    "Furniture" : ["Office Chair", "Desk", "Conference Table" ,"Bookshelf", "Office Sofa", "Dining Table", "Reception Desk", "Meeting Chair", "Workstation Desk"],

    "Clothing" : ["Polo Shirt", "T-Shirt","Lab Coat","Industrial Gloves" ,"Jeans", "Jacket", "Safety Shoes", "Hoodie", "Rain Jacket"],

    "Food" : [ "Coffee Beans","Tea", "Bottled Water", "Chocolate", "Rice", "Cooking Oil", "Sugar", "Biscuits", "Instant Noodles", "Fruit Juice"],

    "Automotive" : ["Car Battery", "Engine Oil", "Brake Pads", "Air Filter", "Oil Filter", "Spark Plug", "Coolant", "Windshield Wiper", "Transmission Fluid", "Tire"],

	"Office Supplies": ["Notebook", "Printer Paper", "Pen", "Stapler", "Whiteboard Marker", "File Folder", "Sticky Notes", "Envelope", "Desk Organizer", "Calculator"],

	"Industrial Equipment" : ["Air Compressor", "Hydraulic Pump", "Electric Motor", "Forklift", "Industrial Fan", "Conveyor Belt", "Pressure Gauge",
                              "Welding Machine", "Generator", "Power Drill"],

	"Medical" : ["Surgical Mask", "Disposable Gloves", "Digital Thermometer", "Blood Pressure Monitor", "Wheelchair", "Hospital Bed", "First Aid Kit",
                 "Syringe", "Pulse Oximeter", "Stethoscope"],

	"Hardware" : [ "SSD", "RAM", "Motherboard", "Graphics Card", "Power Supply", "CPU", "Network Switch", "Router", "Hard Drive", "Server Rack"],

	"Software" : ["CRM Software", "ERP Software", "Accounting Software", "Payroll Software", 
                  "Inventory Management Software", "HR Management Software","Cybersecurity Software",
                  "Project Management Software", "Cloud Backup Software","Business Intelligence Software"]
	}


PRODUCT_BRANDS = {

    "Electronics": ["Dell", "HP", "Lenovo", "Apple", "Asus", "MSI", "Acer", "Samsung","LG"],

    "Furniture": ["IKEA", "Herman Miller", "Steelcase", "HON", "Haworth"],

    "Clothing": ["3M", "Portwest", "Dickies", "Carhartt", "Red Kap"],

    "Food": ["Nestlé", "Unilever", "Kraft Heinz", "Mars", "PepsiCo", "Lipton"],

    "Automotive": ["Bosch", "Castrol", "Mobil", "Shell", "Bridgestone", "Goodyear", "Denso"],

    "Office Supplies": ["Staples", "3M", "Pilot", "BIC", "Fellowes", "Avery"],

    "Industrial Equipment": ["Caterpillar","Bosch","Makita","DeWalt", "Hitachi","Siemens", "ABB"],

    "Medical": ["3M","Medtronic","Philips", "GE Healthcare","Abbott","Johnson & Johnson"],

    "Hardware": ["Intel","AMD","Kingston","Samsung", "Western Digital","Seagate","Corsair","NVIDIA"],

    "Software": ["Microsoft","Oracle","SAP","Salesforce","Adobe","Atlassian","Zoho","Freshworks"]
}
   

PRODUCT_VARIANTS = ["Basic","Standard","Premium"]


PRICE_RANGES = {
    "Electronics": (300, 2500),
    "Furniture": (100, 1500),
    "Clothing": (15, 200),
    "Food": (2, 100),
    "Automotive": (20, 800),
    "Office Supplies": (1, 50),
    "Industrial Equipment": (500, 10000),
    "Medical": (5, 5000),
    "Hardware": (40, 3000),
    "Software": (50, 5000)
}


DEVICE_TYPES = ["Desktop","Mobile","Tablet"]
DEVICE_TYPE_WEIGHTS = [55, 40, 5]

BROWSERS = ["Chrome","Firefox","Edge","Safari"]
BROWSER_WEIGHTS = [65, 15, 10, 10]


BUSINESS_HOURS = {"start": 8,  "end": 18}

# Seasonal monthly weighting for order volume: Q4 peak, summer dip.
# 100 = baseline; values are illustrative starting points, tune after review.
MONTH_WEIGHTS = {
    1: 90,  2: 90,  3: 95,  4: 100, 5: 100, 6: 70,
    7: 65,  8: 70,  9: 100, 10: 130, 11: 150, 12: 160,
}

# Day-of-week weighting (Mon=0 ... Sun=6): orders skew weekday.
DOW_WEIGHTS_ORDERS = {0: 110, 1: 115, 2: 115, 3: 110, 4: 100, 5: 40, 6: 30}

# Web traffic skews weekday too, but less sharply than orders.
DOW_WEIGHTS_TRAFFIC = {0: 105, 1: 110, 2: 110, 3: 105, 4: 100, 5: 70, 6: 60}

# Hour-of-day weighting for web traffic: morning spike, using BUSINESS_HOURS
# as the rough center of mass rather than a hard filter.
HOUR_WEIGHTS_TRAFFIC = {
    0: 20, 1: 15, 2: 10, 3: 10, 4: 10, 5: 20,
    6: 40, 7: 70, 8: 130, 9: 160, 10: 150, 11: 120,
    12: 90, 13: 100, 14: 110, 15: 100, 16: 90, 17: 70,
    18: 50, 19: 40, 20: 35, 21: 30, 22: 25, 23: 20,
}

# Weighting for master/reference entity creation timestamps (company signups,
# customer registrations, supplier onboarding, product catalog additions).
# Kept separate from the transactional weights above: onboarding is a
# business/admin process, not customer purchasing behavior.
ONBOARDING_MONTH_WEIGHTS = {
    1: 130, 2: 115, 3: 105, 4: 100, 5: 95,  6: 85,
    7: 80,  8: 85,  9: 105, 10: 110, 11: 100, 12: 90,
}

# Near-zero weekend activity: nobody's onboarding a B2B company or adding a
# SKU to the catalog on a Sunday.
ONBOARDING_DOW_WEIGHTS = {0: 115, 1: 115, 2: 115, 3: 115, 4: 110, 5: 15, 6: 10}



# ------------------------------------------------
#           SQL SERVER EXTRACTION QUERIES
# ------------------------------------------------

SOURCE1_QUERIES = {

    "companies": """
        SELECT
            company_id,
            company_name,
            company_type,
            cuit_tax_id,
            rating,
            country,
            city,
            address,
            created_at,
            updated_at
        FROM source.Companies
    """,

    "customers": """
        SELECT
            customer_id,
            company_id,
            first_name,
            last_name,
            email,
            phone_number,
            gender,
            date_of_birth,
            job_title,
            created_at,
            updated_at
        FROM source.Customers
    """,

    "categories": """
        SELECT
            category_id,
            category_name,
            created_at,
            updated_at
        FROM source.Categories
    """,

    "suppliers": """
        SELECT
            supplier_id,
            company_id,
            supplier_name,
            contact_name,
            email,
            phone_number,
            created_at,
            updated_at
        FROM source.Suppliers
    """,

    "products": """
        SELECT
            product_id,
            sku,
            product_name,
            category_id,
            brand,
            variant,
            cost_price,
            catalog_price,
            is_active,
            created_at,
            updated_at
        FROM source.Products
    """,

    "supplier_product_mapping": """
        SELECT
            supplier_product_id,
            supplier_id,
            product_id,
            supplier_price,
            lead_time_days,
            is_preferred_supplier,
            created_at,
            updated_at
        FROM source.Supplier_Product_Mapping
    """,

    "orders": """
        SELECT
            order_id,
            customer_id,
            company_id,
            lead_id,
            order_date,
            order_status,
            payment_status,
            order_total,
            created_at,
            updated_at
        FROM source.Orders
    """,

    "order_items": """
        SELECT
            order_item_id,
            order_id,
            supplier_product_id,
            quantity,
            unit_price,
            discount_amount,
            line_total,
            created_at,
            updated_at
        FROM source.Order_Items
    """
}





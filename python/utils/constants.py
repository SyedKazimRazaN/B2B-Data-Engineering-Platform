
# ======================================
# Business Constants
# =====================================

#----------------------------------------------------------------------------------------
    #Source_1 (SQL Server)
#----------------------------------------------------------------------------------------
COMPANY_TYPES = ["Buyer", "Supplier", "Distributor", "Retailer", "Manufacturer"]
ORDER_STATUS = ['Confirmed',"Pending","Processing","Shipped","Delivered","Cancelled"]
ORDER_STATUS_WEIGHTS = [10, 5, 10, 20, 50, 5]
PAYMENT_STATUS = ["pending", "paid", "failed", "refunded"]
PAYMENT_STATUS_WEIGHTS = [10, 82, 3, 5]
OPERATING_LOCATIONS = {                        # Used for weighted geographic distribution and Faker locale selection
    "US": {
        "locale": "en_US",
        "weight": 70,
        "cities_hq": ["New York", "Chicago", "Dallas", "Austin", "Seattle"]
    },
    "UK": {
        "locale": "en_GB",
        "weight": 20,
        "cities_hq": ["London","Manchester","Birmingham"]
    },

    "AUS": {
        "locale": "en_AU",
        "weight": 10,
        "cities_hq": ["Sydney","Melbourne","Brisbane"]
    }
}

DOMAINS = ["gmail.com", "outlook.com", "yahoo.com", "hotmail.com"]


#-----------------------------------------------------------------------------------------
    #Source_2 (Web Logs)
#----------------------------------------------------------------------------------------
HTTP_METHODS = ["GET","POST","PUT","DELETE"]
STATUS_CODES = [200, 201, 301, 400, 401, 403, 404, 500]
STATUS_CODE_WEIGHTS = [70, 5, 5, 5, 3, 2, 8, 2]



#----------------------------------------------------------------------------------------
    #Source_3 (Marketing Leads)
#----------------------------------------------------------------------------------------
SOURCES = ["Google Ads", "Facebook Ads", "LinkedIn", "Website", "Referral", "Email Campaign"]

CAMPAIGNS = ["Summer Sale", "Enterprise Growth", "Product Launch", "Holiday Promotion", "Free Trial Campaign"]

COMPANY_SIZES = ["1-10", "11-50", "51-200", "201-500", "500+"]

INDUSTRIES = ["Technology", "Healthcare", "Finance", "Retail", "Manufacturing", "Education"]

FUNNEL_STAGES = ["New", "Contacted", "Qualified", "Proposal", "Negotiation", "Won", "Lost"]

MEDIUM = ["cpc", "email", "social", "organic"]

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
   

PRODUCT_VARIANTS = ["Standard","Business","Professional","Enterprise","Premium"]


DEVICE_TYPES = ["Desktop","Mobile","Tablet"]
DEVICE_TYPE_WEIGHTS = [55, 40, 5]

BROWSERS = ["Chrome","Firefox","Edge","Safari"]
BROWSER_WEIGHTS = [65, 15, 10, 10]


BUSINESS_HOURS = {"start": 8,  "end": 18}


BOT_USER_AGENTS = ["Googlebot","Bingbot", "curl","PostmanRuntime"]




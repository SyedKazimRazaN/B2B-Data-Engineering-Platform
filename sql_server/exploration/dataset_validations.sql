/*
=================================================
Source 1 Exploration
SQL Server Transactional Database
=================================================

Purpose:
Understand source structure,
validate data quality,
and prepare extraction strategy.
*/


USE b2b_source_db;



/*
=================================================
1. Database Tables
=================================================
*/

SELECT 
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'source' OR TABLE_SCHEMA = 'metadata';



/*
=================================================
2. Row Count Exploration
=================================================
*/

SELECT 'Companies' AS table_name, COUNT(*) AS row_count
FROM source.Companies

UNION ALL

SELECT 'Customers', COUNT(*)
FROM source.Customers

UNION ALL

SELECT 'Products', COUNT(*)
FROM source.Products

UNION ALL

SELECT 'Orders', COUNT(*)
FROM source.Orders

UNION ALL

SELECT 'Order_Items', COUNT(*)
FROM source.Order_Items;



/*
=================================================
3. Data Preview
=================================================
*/

SELECT TOP 10 *
FROM source.Companies;


SELECT TOP 10 *
FROM source.Orders;



/*
=================================================
4. Primary Key Uniqueness Checks
=================================================
*/

SELECT 
    company_id,
    COUNT(*) duplicate_count
FROM source.Companies
GROUP BY company_id
HAVING COUNT(*) > 1;


SELECT 
    company_id,
    COUNT(*) duplicate_count
FROM source.Companies
GROUP BY company_id
HAVING COUNT(*) > 1;

SELECT 
    company_id,
    COUNT(*) duplicate_count
FROM source.Companies
GROUP BY company_id
HAVING COUNT(*) > 1;

SELECT 
    company_id,
    COUNT(*) duplicate_count
FROM source.Companies
GROUP BY company_id
HAVING COUNT(*) > 1;

SELECT 
    company_id,
    COUNT(*) duplicate_count
FROM source.Companies
GROUP BY company_id
HAVING COUNT(*) > 1;

SELECT 
    company_id,
    COUNT(*) duplicate_count
FROM source.Companies
GROUP BY company_id
HAVING COUNT(*) > 1;

SELECT 
    company_id,
    COUNT(*) duplicate_count
FROM source.Companies
GROUP BY company_id
HAVING COUNT(*) > 1;

SELECT 
    company_id,
    COUNT(*) duplicate_count
FROM source.Companies
GROUP BY company_id
HAVING COUNT(*) > 1;


/*
=================================================
5. Foreign Key Integrity Checks
=================================================
*/


-- Customers without companies

SELECT COUNT(*) AS invalid_customers
FROM source.Customers c
LEFT JOIN source.Companies cp
ON c.company_id = cp.company_id
WHERE cp.company_id IS NULL;



-- Orders without customers

SELECT COUNT(*) AS invalid_orders
FROM source.Orders o
LEFT JOIN source.Customers c
ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;



-- Order items without orders

SELECT COUNT(*) AS invalid_order_items
FROM source.Order_Items oi
LEFT JOIN source.Orders o
ON oi.order_id=o.order_id
WHERE o.order_id IS NULL;



/*
=================================================
6. Business Rule Validation
=================================================
*/


-- Product pricing validation

SELECT *
FROM source.Products
WHERE catalog_price < cost_price;



-- Order total validation

SELECT
    o.order_id,
    o.order_total,
    SUM(oi.line_total) calculated_total
FROM source.Orders o
JOIN source.Order_Items oi
ON o.order_id=oi.order_id
GROUP BY 
    o.order_id,
    o.order_total
HAVING o.order_total <> SUM(oi.line_total);



/*
=================================================
7. Incremental Load Readiness
=================================================
*/


SELECT 
    MIN(created_at) earliest_record,
    MAX(updated_at) latest_update
FROM source.Orders;


--Generation_Seeds
SELECT * FROM metadata.Generation_Seeds;





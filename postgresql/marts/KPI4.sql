
/*
Gross Margin Analysis 
	 Margin % per product/supplier; compare catalog price vs actual selling price
*/

WITH supplier_product_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        s.supplier_id,
        s.supplier_name,
        p.catalog_price,
        sp.supplier_price,
        oi.quantity,
        oi.line_total
    FROM warehouse.fact_order_items oi
    JOIN warehouse.dim_products p
        ON p.product_key = oi.product_key
    JOIN warehouse.dim_supplier_product sp
        ON sp.product_key = oi.product_key
       AND sp.supplier_key = oi.supplier_key
    JOIN warehouse.dim_suppliers s
        ON s.supplier_key = sp.supplier_key
    WHERE oi.order_status <> 'Cancelled'
)
SELECT
    product_name,
    supplier_name,
    catalog_price,
    ROUND(SUM(line_total) / NULLIF(SUM(quantity), 0), 2) AS actual_selling_price,
    supplier_price,
    SUM(line_total) - SUM(quantity * supplier_price) AS gross_profit,
    ROUND(((SUM(line_total) - SUM(quantity * supplier_price)) / NULLIF(SUM(line_total), 0)) * 100, 2) AS gross_margin_pct
FROM supplier_product_sales
GROUP BY
    product_id,
    product_name,
    supplier_id,
    supplier_name,
    catalog_price,
    supplier_price
ORDER BY
    product_name,
    supplier_name;









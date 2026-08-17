/*
Customer Lifetime Value + Cohorts
    Customer lifetime value and customer cohorts
*/

WITH company_first_order AS (
    SELECT d.company_id, MIN(fo.order_date_time) AS first_order_date
    FROM warehouse.fact_orders fo
    JOIN warehouse.dim_companies d ON d.company_key = fo.company_key
    GROUP BY d.company_id
),
company_spend AS (
    SELECT
        d.company_id,
        SUM(oi.line_total) AS total_spend,
        COUNT(DISTINCT oi.order_id) AS total_orders
    FROM warehouse.fact_order_items oi
    JOIN warehouse.dim_companies d ON d.company_key = oi.company_key
    WHERE oi.order_status <> 'Cancelled'
      AND d.company_type = 'Buyer'
    GROUP BY d.company_id
),
company_current AS (
    SELECT company_id, company_name, country
    FROM warehouse.dim_companies
    WHERE is_current = TRUE
)
SELECT
    cc.company_name,
    cc.country,
    cs.total_orders,
    cs.total_spend,
    TO_CHAR(fo.first_order_date, 'YYYY-MM') AS acquisition_cohort
FROM company_spend cs
JOIN company_first_order fo ON fo.company_id = cs.company_id
JOIN company_current  cc ON cc.company_id = cs.company_id
ORDER BY cs.total_spend DESC;

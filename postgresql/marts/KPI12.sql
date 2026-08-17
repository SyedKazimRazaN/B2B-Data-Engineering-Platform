
/*
Lead Quality vs Order Value
    Correlation between lead score and actual order value
*/

SELECT
    COUNT(*) AS converted_leads,
    ROUND(CORR(l.lead_score, o.order_total)::NUMERIC, 4) AS lead_score_order_value_correlation
FROM warehouse.fact_leads l
JOIN warehouse.fact_orders o
    ON o.lead_id = l.lead_id
WHERE l.conversion_status = 'Converted'
  AND o.order_status <> 'Cancelled';



  
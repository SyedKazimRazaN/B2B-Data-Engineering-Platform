/*
Lead Conversion Funnel
    Lead source → orders; conversion rates by campaign/channel
*/

WITH lead_funnel AS (
    SELECT
        source,
        campaign_name,
        utm_source,
        utm_medium,
        COUNT(*) AS total_leads,
        COUNT(*) FILTER (WHERE funnel_stage = 'Qualified') AS qualified_leads,
        COUNT(*) FILTER (WHERE conversion_status = 'Converted') AS converted_leads,
		COUNT(DISTINCT order_id) AS orders
    FROM warehouse.fact_leads
    GROUP BY
        source,
        campaign_name,
        utm_source,
        utm_medium
)

SELECT
    source,
    campaign_name,
    utm_source,
    utm_medium,
    total_leads,
    qualified_leads,
    converted_leads,
    orders,
    ROUND(100.0 * converted_leads/ NULLIF(total_leads, 0), 2) AS lead_conversion_rate_pct
FROM lead_funnel
ORDER BY
    lead_conversion_rate_pct DESC,
    total_leads DESC;

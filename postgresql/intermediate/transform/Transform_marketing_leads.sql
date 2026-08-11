-- ============================================================
-- MARKETING LEADS TRANSFORMATION
-- staging → intermediate
-- ============================================================
-- FILE: transform_marketing_leads.sql
-- PURPOSE:
--     Transform staging.marketing_leads into intermediate.marketing_leads
--
-- PIPELINE:
--     staging.marketing_leads
--        ↓
--     latest record per lead_id
--        ↓
--     cleaning / normalization
--        ↓
--     business validation
--        ↓
--     MERGE into intermediate.marketing_leads
--
-- DESIGN GOALS:
--     - Keep the latest source record
--     - Normalize whitespace / empty strings
--     - Handle textual missing values
--     - Validate company business rules
--     - Make the load idempotent
-- ============================================================

/* ============================================================================
   6. MARKETING LEADS
   ============================================================================ */

WITH latest_leads AS (
    -- ====================================================
    -- 1. DEDUPLICATION
    -- ====================================================
    SELECT
        lead_id,
        source,
        campaign_name,
        utm_source,
        utm_medium,
        utm_campaign,
        company_name,
        company_size,
        industry,
        country,
        city,
        lead_score,
        estimated_order_value,
        funnel_stage,
        created_at,
        updated_at,
        ROW_NUMBER() OVER (PARTITION BY lead_id ORDER BY _loaded_at DESC, updated_at DESC) AS rn
    FROM staging.marketing_leads
    WHERE lead_id IS NOT NULL
),

cleaned_leads AS(
	-- ====================================================
	-- 2. CLEANING / NORMALIZATION
	-- ====================================================
	SELECT
		lead_id,
        
        NULLIF(TRIM(source), '') AS source,
        NULLIF(TRIM(campaign_name), '') AS campaign_name,
        NULLIF(TRIM(utm_source), '') AS utm_source,
        NULLIF(TRIM(utm_medium), '') AS utm_medium,
        NULLIF(TRIM(utm_campaign), '') AS utm_campaign,
        NULLIF(TRIM(company_name), '') AS company_name,
        NULLIF(TRIM(company_size), '') AS company_size,
        NULLIF(TRIM(industry), '') AS industry,
        NULLIF(TRIM(country), '') AS country,
        NULLIF(TRIM(city), '') AS city,
        lead_score,
        estimated_order_value,
        NULLIF(TRIM(funnel_stage), '') AS funnel_stage,
        created_at,
        updated_at
	FROM latest_leads
	WHERE rn =1
	),

validate_leads AS (
    -- ====================================================
    -- 3. BUSINESS VALIDATION
    -- ====================================================
	SELECT *
	FROM cleaned_leads
	    WHERE source IS NOT NULL
      AND campaign_name IS NOT NULL
      AND utm_source IS NOT NULL
      AND utm_medium IS NOT NULL
      AND utm_campaign IS NOT NULL
      AND company_name IS NOT NULL
      AND company_size IS NOT NULL
      AND industry IS NOT NULL
      AND country IS NOT NULL
      AND city IS NOT NULL
      AND lead_score BETWEEN 1 AND 100
      AND estimated_order_value >= 0
      AND funnel_stage IN ('New','Contacted','Qualified','Proposal','Negotiation','Won','Lost')
      AND created_at IS NOT NULL
      AND updated_at IS NOT NULL
      AND updated_at >= created_at
)


MERGE INTO intermediate.marketing_leads AS target
USING validate_leads AS source
ON target.lead_id = source.lead_id

WHEN MATCHED
AND target.updated_at < source.updated_at THEN
	-- ============================================================
	-- 4. UPDATE EXISTING MARKETING LEADS
	-- ============================================================
    UPDATE SET
        source = source.source,
        campaign_name = source.campaign_name,
        utm_source = source.utm_source,
        utm_medium = source.utm_medium,
        utm_campaign = source.utm_campaign,
        company_name = source.company_name,
        company_size = source.company_size,
        industry = source.industry,
        country = source.country,
        city = source.city,
        lead_score = source.lead_score,
        estimated_order_value = source.estimated_order_value,
        funnel_stage = source.funnel_stage,
        created_at = source.created_at,
        updated_at = source.updated_at

WHEN NOT MATCHED THEN
	-- ============================================================
	-- 5. INSERT NEW MARKETING LEADS
	-- ============================================================
    INSERT (
        lead_id,
        source,
        campaign_name,
        utm_source,
        utm_medium,
        utm_campaign,
        company_name,
        company_size,
        industry,
        country,
        city,
        lead_score,
        estimated_order_value,
        funnel_stage,
        created_at,
        updated_at,
        conversion_status
    )
    VALUES (
        source.lead_id,
        source.source,
        source.campaign_name,
        source.utm_source,
        source.utm_medium,
        source.utm_campaign,
        source.company_name,
        source.company_size,
        source.industry,
        source.country,
        source.city,
        source.lead_score,
        source.estimated_order_value,
        source.funnel_stage,
        source.created_at,
        source.updated_at,
        'Not Converted'		-- will be updated after orders
    );




	



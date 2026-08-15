/*
===============================================================================
FACT LEADS — WAREHOUSE LOAD
===============================================================================

Grain:
    One row per marketing lead.

Business key:
    lead_id

Primary key:
    lead_id

Surrogate keys:
    date → date_key

Order relationship:
    lead_id → order_id from intermediate.orders

Load strategy:
    INSERT for new leads; UPDATE for funnel progression, scoring,
    conversion, and the resulting order link.

Mutable vs immutable:
    source/campaign/UTM attributes, company profile, and geography are
    set at lead creation and never change.
    funnel_stage and lead_score ARE mutated later by the CDC funnel-
    advancement simulation (generate_and_update_leads), and
    conversion_status/order_id can flip from Not Converted/NULL to
    Converted/<order_id> once the lead's order is transformed into
    intermediate — both need an update path or KPI 11/12 go stale.

Idempotency:
    MERGE matches using lead_id.
    Existing leads → update funnel_stage/lead_score/conversion_status/order_id if changed.
    New leads → INSERT.

Execution Flow:
intermediate.marketing_leads
          │
          ├── created_at ──→ dim_date ──→ date_key
          │
          └── lead_id ─────→ intermediate.orders
                                  │
                                  ▼
                              order_id
                                  │
                                  ▼
                          extracted_leads
                                  │
                                  ▼
                                MERGE
                    ┌──────────┴──────────┐
                    ▼                     ▼
               MATCHED +             NOT MATCHED
          tracked fields changed          │
                    │                     ▼
                    ▼                  INSERT
          UPDATE tracked fields only

===============================================================================
-- FACT LEADS
-- intermediate → warehouse
===============================================================================
*/

-- BEGIN;

WITH extracted_leads AS (

    -- ============================================================
    -- 1. Prepare lead data and map date/order
    -- ============================================================
    SELECT
        l.lead_id,
        d.date_key,
        o.order_id,
        l.source,
        l.campaign_name,
        l.utm_source,
        l.utm_medium,
        l.utm_campaign,
        l.company_name AS lead_company_name,
        l.company_size,
        l.industry,
        l.country,
        l.city,
        l.lead_score,
        l.estimated_order_value,
        l.funnel_stage,
        l.conversion_status
    FROM intermediate.marketing_leads AS l
    INNER JOIN warehouse.dim_date AS d
        ON d.full_date = l.created_at::DATE
    LEFT JOIN intermediate.orders AS o
        ON o.lead_id = l.lead_id
)

-- ============================================================
-- 2. Load leads into fact table
-- ============================================================

MERGE INTO warehouse.fact_leads AS target
USING extracted_leads AS source
ON target.lead_id = source.lead_id

WHEN MATCHED AND (
       source.order_id          IS DISTINCT FROM target.order_id
    OR source.funnel_stage      IS DISTINCT FROM target.funnel_stage
    OR source.lead_score        IS DISTINCT FROM target.lead_score
    OR source.conversion_status IS DISTINCT FROM target.conversion_status
)
THEN
-- ==========================================================================================
-- UPDATE MUTABLE LEAD ATTRIBUTES (ORDER_ID, FUNNEL_STAGE, LEAD_SCORE, CONVERSION_STATUS)
-- (source/campaign/UTM/company profile/geography are set at lead)
-- ==========================================================================================
    UPDATE SET
        order_id          = source.order_id,
        funnel_stage       = source.funnel_stage,
        lead_score         = source.lead_score,
        conversion_status  = source.conversion_status

WHEN NOT MATCHED THEN
-- ============================================================
-- 3. Insert new leads
-- ============================================================
    INSERT (
        lead_id,
        date_key,
        order_id,
        source,
        campaign_name,
        utm_source,
        utm_medium,
        utm_campaign,
        lead_company_name,
        company_size,
        industry,
        country,
        city,
        lead_score,
        estimated_order_value,
        funnel_stage,
        conversion_status
    )

    VALUES (
        source.lead_id,
        source.date_key,
        source.order_id,
        source.source,
        source.campaign_name,
        source.utm_source,
        source.utm_medium,
        source.utm_campaign,
        source.lead_company_name,
        source.company_size,
        source.industry,
        source.country,
        source.city,
        source.lead_score,
        source.estimated_order_value,
        source.funnel_stage,
        source.conversion_status
    );

-- COMMIT;

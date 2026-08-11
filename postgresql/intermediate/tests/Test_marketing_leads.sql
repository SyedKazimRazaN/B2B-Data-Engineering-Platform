/* ============================================================================
   TESTS — MARKETING LEADS
   ============================================================================ */
-- ============================================================
-- FILE: test_marketing_leads.sql
-- PURPOSE:
--     Data-quality tests for intermediate.marketing_leads
--
-- EXPECTATION:
--     Each test should return ZERO rows.
-- ============================================================



/* ============================================================================
   1. LEAD_ID MUST BE UNIQUE
   ============================================================================ */

SELECT
    lead_id,
    COUNT(*) AS row_count
FROM intermediate.marketing_leads
GROUP BY lead_id
HAVING COUNT(*) > 1;


/* ============================================================================
   2. REQUIRED FIELDS MUST NOT BE NULL
   ============================================================================ */

SELECT *
FROM intermediate.marketing_leads
WHERE lead_id IS NULL
   OR source IS NULL
   OR campaign_name IS NULL
   OR company_name IS NULL
   OR country IS NULL
   OR city IS NULL
   OR funnel_stage IS NULL
   OR created_at IS NULL
   OR updated_at IS NULL;


/* ============================================================================
   3. LEAD SCORE MUST BE BETWEEN 1 AND 100
   ============================================================================ */

SELECT *
FROM intermediate.marketing_leads
WHERE lead_score NOT BETWEEN 1 AND 100;


/* ============================================================================
   4. ESTIMATED ORDER VALUE MUST NOT BE NEGATIVE
   ============================================================================ */

SELECT *
FROM intermediate.marketing_leads
WHERE estimated_order_value < 0;


/* ============================================================================
   5. FUNNEL STAGE MUST BE VALID
   ============================================================================ */

SELECT *
FROM intermediate.marketing_leads
WHERE funnel_stage NOT IN (
    'New',
    'Contacted',
    'Qualified',
    'Proposal',
    'Negotiation',
    'Won',
    'Lost'
);


/* ============================================================================
   6. UPDATED_AT MUST BE >= CREATED_AT
   Rule 9
   ============================================================================ */

SELECT *
FROM intermediate.marketing_leads
WHERE updated_at < created_at;

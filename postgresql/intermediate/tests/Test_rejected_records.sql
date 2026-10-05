-- ============================================================
-- FILE: test_rejected_records.sql
-- PURPOSE:
-- Data-quality tests for intermediate.rejected_records (quarantine)
-- The generators break ~1.5% of CSV rows on purpose
-- (config.DIRTY_DATA_PERCENT); these tests prove the transforms catch them.

-- EXPECTATION:
-- Each test should return ZERO rows.
-- ============================================================

-- ============================================================
-- TEST 1: QUARANTINE IS NOT EMPTY
-- dirty rows are generated on purpose, so an empty table means
-- the validation did not catch them
-- ============================================================

SELECT
'rejected_records is empty for this table' AS problem,
t.table_name
FROM (VALUES ('marketing_leads'), ('web_logs')) AS t(table_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM intermediate.rejected_records r
    WHERE r.table_name = t.table_name
);

-- ============================================================
-- TEST 2: DUPLICATE REJECTED RECORDS
-- ============================================================

SELECT
table_name,
record_id,
COUNT(*) AS duplicate_count
FROM intermediate.rejected_records
GROUP BY table_name, record_id
HAVING COUNT(*) > 1;

-- ============================================================
-- TEST 3: ONLY CSV TABLES AND KNOWN REASONS
-- ============================================================

SELECT *
FROM intermediate.rejected_records
WHERE table_name NOT IN ('marketing_leads', 'web_logs')
OR reject_reason NOT IN (
'invalid lead_score',
'invalid estimated_order_value',
'invalid funnel_stage',
'missing required field',
'invalid created_at / updated_at',
'invalid status_code',
'invalid bytes_sent',
'invalid http_method',
'missing log_timestamp'
);

-- ============================================================
-- TEST 4: REJECTED SHARE CLOSE TO THE DIRTY %
-- about 1.5% expected; outside 0.5% - 3% means the validation
-- misses dirty rows or rejects good ones
-- ============================================================

SELECT *
FROM (
    SELECT
    'marketing_leads' AS table_name,
    ROUND(100.0 * (SELECT COUNT(*) FROM intermediate.rejected_records WHERE table_name = 'marketing_leads')
          / NULLIF((SELECT COUNT(*) FROM intermediate.marketing_leads), 0), 2) AS rejected_pct
    UNION ALL
    SELECT
    'web_logs',
    ROUND(100.0 * (SELECT COUNT(*) FROM intermediate.rejected_records WHERE table_name = 'web_logs')
          / NULLIF((SELECT COUNT(*) FROM intermediate.web_logs), 0), 2)
) shares
WHERE rejected_pct NOT BETWEEN 0.5 AND 3;

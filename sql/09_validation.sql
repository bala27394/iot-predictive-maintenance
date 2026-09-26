-- =============================================================================
-- IoT Predictive Maintenance Platform
-- 09: End-to-End Validation
-- =============================================================================

USE DATABASE IOT_PREDICTIVE_MAINTENANCE;
USE WAREHOUSE IOT_ML_WH;

-- =============================================================================
-- 1. TABLE ROW COUNTS
-- =============================================================================

SELECT 'RAW.SENSOR_READINGS'        AS table_name, COUNT(*) AS row_count FROM RAW.SENSOR_READINGS
UNION ALL
SELECT 'RAW.MACHINES',               COUNT(*) FROM RAW.MACHINES
UNION ALL
SELECT 'RAW.MAINTENANCE_LOGS',       COUNT(*) FROM RAW.MAINTENANCE_LOGS
UNION ALL
SELECT 'RAW.WORK_ORDERS',            COUNT(*) FROM RAW.WORK_ORDERS
UNION ALL
SELECT 'STAGING.SENSOR_STATS_HOURLY', COUNT(*) FROM STAGING.SENSOR_STATS_HOURLY
UNION ALL
SELECT 'STAGING.MACHINE_VIBRATION_PROFILE', COUNT(*) FROM STAGING.MACHINE_VIBRATION_PROFILE
UNION ALL
SELECT 'STAGING.PERFORMANCE_BASELINE', COUNT(*) FROM STAGING.PERFORMANCE_BASELINE
UNION ALL
SELECT 'STAGING.CROSS_MACHINE_HEALTH', COUNT(*) FROM STAGING.CROSS_MACHINE_HEALTH
UNION ALL
SELECT 'ANALYTICS.DETECTED_ANOMALIES', COUNT(*) FROM ANALYTICS.DETECTED_ANOMALIES
UNION ALL
SELECT 'ANALYTICS.VIBRATION_FORECAST', COUNT(*) FROM ANALYTICS.VIBRATION_FORECAST
ORDER BY table_name;

-- =============================================================================
-- 2. DYNAMIC TABLE STATUS (all should be ACTIVE)
-- =============================================================================

SELECT name, schema_name, scheduling_state, data_timestamp
FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLES())
ORDER BY schema_name, name;

-- =============================================================================
-- 3. ML MODEL INVENTORY
-- =============================================================================

SHOW SNOWFLAKE.ML.ANOMALY_DETECTION IN SCHEMA ANALYTICS;
SHOW SNOWFLAKE.ML.FORECAST IN SCHEMA ANALYTICS;

-- =============================================================================
-- 4. VERIFY FAILING MACHINES RANK AS CRITICAL
--    Expected CRITICAL machines: MCH-0003, MCH-0012, MCH-0025, MCH-0031, MCH-0047
-- =============================================================================

SELECT machine_id, machine_type, health_score_fact, health_status, concern_rank_fact, anomalies_24h
FROM STAGING.CROSS_MACHINE_HEALTH
WHERE machine_id IN ('MCH-0003', 'MCH-0012', 'MCH-0025', 'MCH-0031', 'MCH-0047')
ORDER BY concern_rank_fact;

-- Verify all 5 are CRITICAL
SELECT
    COUNT(*) AS critical_count,
    IFF(COUNT(*) = 5, 'PASS', 'FAIL') AS test_result
FROM STAGING.CROSS_MACHINE_HEALTH
WHERE machine_id IN ('MCH-0003', 'MCH-0012', 'MCH-0025', 'MCH-0031', 'MCH-0047')
  AND health_status = 'CRITICAL';

-- =============================================================================
-- 5. ANOMALY DISTRIBUTION BY SEVERITY
-- =============================================================================

SELECT severity, COUNT(*) AS cnt,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM ANALYTICS.DETECTED_ANOMALIES
GROUP BY severity
ORDER BY
    CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 END;

-- =============================================================================
-- 6. WORK ORDER COUNT AND PRIORITY DISTRIBUTION
-- =============================================================================

SELECT COUNT(*) AS total_work_orders FROM RAW.WORK_ORDERS;

SELECT wo_priority, wo_status, COUNT(*) AS cnt
FROM RAW.WORK_ORDERS
GROUP BY wo_priority, wo_status
ORDER BY
    CASE wo_priority WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 END,
    wo_status;

-- =============================================================================
-- 7. INTEGRATION TEST: INJECT ANOMALY -> RUN SKILLS -> VERIFY WORK ORDER
-- =============================================================================

-- Find a machine that currently has NO work orders
SET test_machine = (
    SELECT m.machine_id
    FROM RAW.MACHINES m
    LEFT JOIN RAW.WORK_ORDERS w ON m.machine_id = w.machine_id
    WHERE w.work_order_id IS NULL
    ORDER BY m.machine_id
    LIMIT 1
);

SELECT $test_machine AS test_machine_id;

-- Inject a synthetic CRITICAL anomaly
INSERT INTO ANALYTICS.DETECTED_ANOMALIES (
    anomaly_id, machine_id, reading_timestamp, vibration_reading,
    anomaly_confidence, severity, anomaly_status, detected_at
)
SELECT
    'TEST-ANOMALY-001',
    $test_machine,
    DATEADD('minute', -30, CURRENT_TIMESTAMP()),
    15.5,
    0.97,
    'CRITICAL',
    'NEW',
    CURRENT_TIMESTAMP();

-- Verify the test anomaly was inserted
SELECT * FROM ANALYTICS.DETECTED_ANOMALIES WHERE anomaly_id = 'TEST-ANOMALY-001';

-- Run Skill 1: Triage anomalies
CALL ORCHESTRATION.TRIAGE_ANOMALIES();

-- Verify the test anomaly was triaged
SELECT anomaly_id, anomaly_status
FROM ANALYTICS.DETECTED_ANOMALIES
WHERE anomaly_id = 'TEST-ANOMALY-001';

-- Run Skill 2: Draft work orders for untriaged critical/high anomalies
CALL ORCHESTRATION.DRAFT_WORK_ORDERS();

-- Verify a work order was created for the test machine
SELECT work_order_id, machine_id, wo_priority, wo_status, technician
FROM RAW.WORK_ORDERS
WHERE machine_id = $test_machine
ORDER BY created_at DESC
LIMIT 1;

-- Run Skill 3: Send notifications
CALL ORCHESTRATION.SEND_MAINTENANCE_ALERTS();

-- Final pass/fail for integration test
SELECT
    IFF(COUNT(*) >= 1, 'PASS', 'FAIL') AS integration_test_result,
    COUNT(*) AS work_orders_created
FROM RAW.WORK_ORDERS
WHERE machine_id = $test_machine;

-- =============================================================================
-- 8. TEST CORTEX ANALYST SEMANTIC VIEW QUERY
-- =============================================================================

-- Query the semantic view for CRITICAL machines
SELECT *
FROM TABLE(
    SNOWFLAKE.CORTEX.SEMANTIC_VIEW_QUERY(
        'IOT_PREDICTIVE_MAINTENANCE.APP.IOT_MAINTENANCE_VIEW',
        'Which machines have CRITICAL health status? Show their health scores and anomaly counts.'
    )
);

-- =============================================================================
-- 9. CLEANUP: REMOVE TEST DATA
-- =============================================================================

DELETE FROM RAW.WORK_ORDERS WHERE machine_id = $test_machine
    AND created_at >= DATEADD('minute', -10, CURRENT_TIMESTAMP());

DELETE FROM ANALYTICS.DETECTED_ANOMALIES WHERE anomaly_id = 'TEST-ANOMALY-001';

-- Verify cleanup
SELECT
    (SELECT COUNT(*) FROM ANALYTICS.DETECTED_ANOMALIES WHERE anomaly_id = 'TEST-ANOMALY-001') AS remaining_test_anomalies,
    IFF(remaining_test_anomalies = 0, 'CLEANUP OK', 'CLEANUP FAILED') AS cleanup_status;

-- =============================================================================
-- VALIDATION COMPLETE
-- =============================================================================
SELECT 'All validation checks completed successfully.' AS status;

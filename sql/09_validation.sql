-- ============================================================
-- 09_validation.sql
-- End-to-End Validation Queries
-- Database: IOT_PREDICTIVE_MAINTENANCE | Warehouse: IOT_PM_WH
-- ============================================================

USE DATABASE IOT_PREDICTIVE_MAINTENANCE;
USE WAREHOUSE IOT_PM_WH;

-- ============================================================
-- SCENARIO 1: MCH-001 Bearing Degradation — Vibration Trend
-- Expected: early avg ~4-5, late avg ~11-12
-- ============================================================
SELECT 'SCENARIO 1: MCH-001 Vibration Trend' AS TEST,
    ROUND(AVG(CASE WHEN READING_TIMESTAMP < '2026-09-10' THEN READING_VALUE END), 2) AS EARLY_AVG,
    ROUND(AVG(CASE WHEN READING_TIMESTAMP > '2026-09-25' THEN READING_VALUE END), 2) AS LATE_AVG
FROM RAW.SENSOR_READINGS
WHERE MACHINE_ID = 'MCH-001' AND SIGNAL_TYPE = 'VIBRATION';

-- ============================================================
-- SCENARIO 2: MCH-003 Sensor Fault — Stale Readings
-- Expected: >400 STALE readings
-- ============================================================
SELECT 'SCENARIO 2: MCH-003 Sensor Fault' AS TEST, QUALITY_FLAG, COUNT(*) AS CNT
FROM STAGING.SENSOR_READINGS_CLEAN
WHERE MACHINE_ID = 'MCH-003' AND SIGNAL_TYPE = 'VIBRATION'
GROUP BY QUALITY_FLAG;

-- ============================================================
-- SCENARIO 3: MCH-006 High-Load Normal Operation
-- Expected: NOT flagged as failure (should be ROUTINE_MONITORING)
-- ============================================================
SELECT 'SCENARIO 3: MCH-006 Not False Positive' AS TEST,
    MACHINE_ID, PRIMARY_FAILURE_MODE, RECOMMENDATION
FROM ANALYTICS.FAILURE_ASSESSMENTS
WHERE MACHINE_ID = 'MCH-006';

-- ============================================================
-- SCENARIO 4: Duplicate Work Order Prevention
-- Expected: DUPLICATE message
-- ============================================================
-- Run after at least one WO exists for INC-001:
-- CALL ORCHESTRATION.DRAFT_WORK_ORDER('INC-001');

-- ============================================================
-- SCENARIO 5: All Table Row Counts
-- ============================================================
SELECT 'MACHINES' AS TBL, COUNT(*) AS ROWS_CT FROM RAW.MACHINES
UNION ALL SELECT 'SENSORS', COUNT(*) FROM RAW.SENSORS
UNION ALL SELECT 'SENSOR_READINGS', COUNT(*) FROM RAW.SENSOR_READINGS
UNION ALL SELECT 'MACHINE_EVENT_LOGS', COUNT(*) FROM RAW.MACHINE_EVENT_LOGS
UNION ALL SELECT 'MAINTENANCE_HISTORY', COUNT(*) FROM RAW.MAINTENANCE_HISTORY
UNION ALL SELECT 'PARTS_INVENTORY', COUNT(*) FROM RAW.PARTS_INVENTORY
UNION ALL SELECT 'PRODUCTION_QUALITY', COUNT(*) FROM RAW.PRODUCTION_QUALITY
UNION ALL SELECT 'SHIFT_LOGS', COUNT(*) FROM RAW.SHIFT_LOGS
UNION ALL SELECT 'WORK_ORDERS', COUNT(*) FROM RAW.WORK_ORDERS
UNION ALL SELECT 'SENSOR_READINGS_CLEAN', COUNT(*) FROM STAGING.SENSOR_READINGS_CLEAN
UNION ALL SELECT 'MACHINE_HEALTH_FEATURES', COUNT(*) FROM STAGING.MACHINE_HEALTH_FEATURES
UNION ALL SELECT 'CROSS_MACHINE_HEALTH', COUNT(*) FROM STAGING.CROSS_MACHINE_HEALTH
UNION ALL SELECT 'DETECTED_ANOMALIES', COUNT(*) FROM ANALYTICS.DETECTED_ANOMALIES
UNION ALL SELECT 'FAILURE_FORECASTS', COUNT(*) FROM ANALYTICS.FAILURE_FORECASTS
UNION ALL SELECT 'FAILURE_ASSESSMENTS', COUNT(*) FROM ANALYTICS.FAILURE_ASSESSMENTS
UNION ALL SELECT 'INCIDENTS', COUNT(*) FROM ANALYTICS.INCIDENTS
UNION ALL SELECT 'MAINTENANCE_CONTEXT', COUNT(*) FROM ANALYTICS.MAINTENANCE_CONTEXT
ORDER BY TBL;

-- ============================================================
-- SCENARIO 6: Priority Transparency
-- Expected: 4 incidents with visible priority breakdown
-- ============================================================
SELECT INCIDENT_ID, MACHINE_ID, SEVERITY, PRIORITY_SCORE,
       HEALTH_SCORE, CRITICALITY, PRODUCTION_IMPACT, RUL_DAYS, CONFIDENCE_LEVEL
FROM ANALYTICS.INCIDENTS
ORDER BY PRIORITY_SCORE DESC;

-- ============================================================
-- SCENARIO 7: OEE Data Exists
-- Expected: OEE values for production machines
-- ============================================================
SELECT MACHINE_ID, MACHINE_NAME,
    ROUND(AVG(OEE_PCT), 1) AS AVG_OEE,
    ROUND(AVG(AVAILABILITY_PCT), 1) AS AVG_AVAIL,
    ROUND(AVG(QUALITY_PCT), 1) AS AVG_QUALITY
FROM ANALYTICS.OEE_METRICS
WHERE PRODUCTION_DATE >= DATEADD('day', -7, CURRENT_DATE())
GROUP BY MACHINE_ID, MACHINE_NAME
ORDER BY AVG_OEE DESC;

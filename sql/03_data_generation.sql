-- ============================================================================
-- IOT PREDICTIVE MAINTENANCE PLATFORM
-- 03_data_generation.sql - Synthetic Data Generation
-- ============================================================================
-- Generates 90 days of synthetic IoT sensor data (June 1 - August 29, 2026)
-- for 50 machines with seeded degradation-to-failure patterns on 5 machines.
-- All inserts use INSERT...SELECT with GENERATOR / CROSS JOIN patterns.
-- ============================================================================

USE DATABASE IOT_PREDICTIVE_MAINTENANCE;
USE SCHEMA RAW;

-- ============================================================================
-- 1. MACHINES (50 rows)
-- ============================================================================
-- 6 machine types cycling, with rated specs. Every 5th machine is HIGH
-- criticality, others alternate MEDIUM/LOW.
-- IDs: MCH-0001 to MCH-0050
-- ============================================================================

INSERT INTO MACHINES (
    MACHINE_ID, MACHINE_NAME, MACHINE_TYPE, MANUFACTURER, MODEL,
    INSTALL_DATE, LOCATION, ZONE, CRITICALITY,
    RATED_POWER_KW, RATED_CURRENT_A, RATED_RPM,
    MAX_VIBRATION_MM_S, MAX_BEARING_TEMP_C, MAX_HYDRAULIC_PRESSURE_BAR,
    STATUS, LAST_MAINTENANCE_DATE, NEXT_SCHEDULED_MAINTENANCE
)
SELECT
    'MCH-' || LPAD(SEQ4() + 1, 4, '0')                             AS MACHINE_ID,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'CNC Lathe '
        WHEN 1 THEN 'Hydraulic Press '
        WHEN 2 THEN 'Conveyor '
        WHEN 3 THEN 'Injection Molder '
        WHEN 4 THEN 'Pump Station '
        WHEN 5 THEN 'Compressor '
    END || LPAD(SEQ4() + 1, 4, '0')                                 AS MACHINE_NAME,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'CNC_LATHE'
        WHEN 1 THEN 'HYDRAULIC_PRESS'
        WHEN 2 THEN 'CONVEYOR'
        WHEN 3 THEN 'INJECTION_MOLDER'
        WHEN 4 THEN 'PUMP'
        WHEN 5 THEN 'COMPRESSOR'
    END                                                              AS MACHINE_TYPE,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'Mazak'
        WHEN 1 THEN 'Schuler'
        WHEN 2 THEN 'Siemens'
        WHEN 3 THEN 'Engel'
        WHEN 4 THEN 'Grundfos'
        WHEN 5 THEN 'Atlas Copco'
    END                                                              AS MANUFACTURER,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'QTN-350'
        WHEN 1 THEN 'SP-2500'
        WHEN 2 THEN 'SC-800'
        WHEN 3 THEN 'VC-1060'
        WHEN 4 THEN 'CR-95'
        WHEN 5 THEN 'GA-75'
    END                                                              AS MODEL,
    DATEADD('day', -1 * (365 * 2 + UNIFORM(0, 730, RANDOM())), '2026-06-01')::DATE AS INSTALL_DATE,
    'Building ' || (MOD(SEQ4(), 3) + 1)                              AS LOCATION,
    'Zone-' || CHR(65 + MOD(SEQ4(), 5))                              AS ZONE,
    CASE
        WHEN MOD(SEQ4() + 1, 5) = 0 THEN 'HIGH'
        WHEN MOD(SEQ4(), 2) = 0     THEN 'MEDIUM'
        ELSE                              'LOW'
    END                                                              AS CRITICALITY,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 45.0   -- CNC_LATHE
        WHEN 1 THEN 75.0   -- HYDRAULIC_PRESS
        WHEN 2 THEN 15.0   -- CONVEYOR
        WHEN 3 THEN 55.0   -- INJECTION_MOLDER
        WHEN 4 THEN 30.0   -- PUMP
        WHEN 5 THEN 90.0   -- COMPRESSOR
    END                                                              AS RATED_POWER_KW,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 65.0
        WHEN 1 THEN 110.0
        WHEN 2 THEN 25.0
        WHEN 3 THEN 80.0
        WHEN 4 THEN 45.0
        WHEN 5 THEN 130.0
    END                                                              AS RATED_CURRENT_A,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 3500
        WHEN 1 THEN 0
        WHEN 2 THEN 1800
        WHEN 3 THEN 0
        WHEN 4 THEN 2900
        WHEN 5 THEN 3000
    END                                                              AS RATED_RPM,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 12.0
        WHEN 1 THEN 8.0
        WHEN 2 THEN 6.0
        WHEN 3 THEN 10.0
        WHEN 4 THEN 15.0
        WHEN 5 THEN 14.0
    END                                                              AS MAX_VIBRATION_MM_S,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 85.0
        WHEN 1 THEN 90.0
        WHEN 2 THEN 70.0
        WHEN 3 THEN 95.0
        WHEN 4 THEN 80.0
        WHEN 5 THEN 88.0
    END                                                              AS MAX_BEARING_TEMP_C,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 0
        WHEN 1 THEN 250.0
        WHEN 2 THEN 0
        WHEN 3 THEN 180.0
        WHEN 4 THEN 12.0
        WHEN 5 THEN 10.0
    END                                                              AS MAX_HYDRAULIC_PRESSURE_BAR,
    'RUNNING'                                                        AS STATUS,
    DATEADD('day', -1 * UNIFORM(15, 60, RANDOM()), '2026-06-01')::DATE AS LAST_MAINTENANCE_DATE,
    DATEADD('day', UNIFORM(30, 90, RANDOM()), '2026-06-01')::DATE    AS NEXT_SCHEDULED_MAINTENANCE
FROM TABLE(GENERATOR(ROWCOUNT => 50));


-- ============================================================================
-- 2. SENSORS (400 rows)
-- ============================================================================
-- 8 sensors per machine. Types: VIBRATION, TEMPERATURE, PRESSURE, FLOW,
-- CURRENT, CYCLE_COUNTER, ACOUSTIC, BEARING_TEMP.
-- IDs: SEN-XXXX-01 through SEN-XXXX-08 (XXXX = machine number)
-- ============================================================================

INSERT INTO SENSORS (
    SENSOR_ID, MACHINE_ID, SENSOR_TYPE, SENSOR_NAME,
    UNIT, MIN_THRESHOLD, MAX_THRESHOLD,
    INSTALL_DATE, CALIBRATION_DATE, STATUS
)
SELECT
    'SEN-' || LPAD(m.MCH_NUM, 4, '0') || '-' || LPAD(s.SENSOR_SEQ, 2, '0') AS SENSOR_ID,
    'MCH-' || LPAD(m.MCH_NUM, 4, '0')                                       AS MACHINE_ID,
    CASE s.SENSOR_SEQ
        WHEN 1 THEN 'VIBRATION'
        WHEN 2 THEN 'TEMPERATURE'
        WHEN 3 THEN 'PRESSURE'
        WHEN 4 THEN 'FLOW'
        WHEN 5 THEN 'CURRENT'
        WHEN 6 THEN 'CYCLE_COUNTER'
        WHEN 7 THEN 'ACOUSTIC'
        WHEN 8 THEN 'BEARING_TEMP'
    END                                                                       AS SENSOR_TYPE,
    CASE s.SENSOR_SEQ
        WHEN 1 THEN 'Vibration Sensor'
        WHEN 2 THEN 'Temperature Sensor'
        WHEN 3 THEN 'Pressure Transducer'
        WHEN 4 THEN 'Flow Meter'
        WHEN 5 THEN 'Current Transformer'
        WHEN 6 THEN 'Cycle Counter'
        WHEN 7 THEN 'Acoustic Emission Sensor'
        WHEN 8 THEN 'Bearing Temperature Probe'
    END                                                                       AS SENSOR_NAME,
    CASE s.SENSOR_SEQ
        WHEN 1 THEN 'mm/s'
        WHEN 2 THEN 'C'
        WHEN 3 THEN 'bar'
        WHEN 4 THEN 'L/min'
        WHEN 5 THEN 'A'
        WHEN 6 THEN 'count'
        WHEN 7 THEN 'dB'
        WHEN 8 THEN 'C'
    END                                                                       AS UNIT,
    CASE s.SENSOR_SEQ
        WHEN 1 THEN 0.5
        WHEN 2 THEN 15.0
        WHEN 3 THEN 0.5
        WHEN 4 THEN 1.0
        WHEN 5 THEN 5.0
        WHEN 6 THEN 0
        WHEN 7 THEN 40.0
        WHEN 8 THEN 20.0
    END                                                                       AS MIN_THRESHOLD,
    CASE s.SENSOR_SEQ
        WHEN 1 THEN 12.0
        WHEN 2 THEN 95.0
        WHEN 3 THEN 250.0
        WHEN 4 THEN 120.0
        WHEN 5 THEN 130.0
        WHEN 6 THEN 999999
        WHEN 7 THEN 95.0
        WHEN 8 THEN 85.0
    END                                                                       AS MAX_THRESHOLD,
    DATEADD('day', -1 * UNIFORM(100, 800, RANDOM()), '2026-06-01')::DATE      AS INSTALL_DATE,
    DATEADD('day', -1 * UNIFORM(1, 90, RANDOM()), '2026-06-01')::DATE         AS CALIBRATION_DATE,
    'ACTIVE'                                                                  AS STATUS
FROM
    (SELECT SEQ4() + 1 AS MCH_NUM FROM TABLE(GENERATOR(ROWCOUNT => 50))) m
    CROSS JOIN
    (SELECT SEQ4() + 1 AS SENSOR_SEQ FROM TABLE(GENERATOR(ROWCOUNT => 8))) s;


-- ============================================================================
-- 3. SENSOR_READINGS (~288,000 rows)
-- ============================================================================
-- 50 machines x 8 sensors x 90 days x 32 half-hour slots (6AM-10PM).
-- 5 machines have seeded quadratic degradation-to-failure:
--   MCH-0003 (failure day 60), MCH-0012 (day 45), MCH-0025 (day 70),
--   MCH-0031 (day 55), MCH-0047 (day 65)
-- Degradation affects VIBRATION, TEMPERATURE, CURRENT, ACOUSTIC sensors.
-- IS_ANOMALY = TRUE when degradation exceeds threshold or random spike (5%).
-- ============================================================================

INSERT INTO SENSOR_READINGS (
    READING_ID, SENSOR_ID, MACHINE_ID, READING_TIMESTAMP,
    SENSOR_TYPE, VALUE, UNIT, QUALITY_SCORE, IS_ANOMALY
)
WITH
-- Generate 90 day offsets (day 0 = June 1, day 89 = Aug 29)
DAYS AS (
    SELECT SEQ4() AS DAY_NUM
    FROM TABLE(GENERATOR(ROWCOUNT => 90))
),
-- Generate 32 half-hour time slots (6:00 AM to 9:30 PM)
SLOTS AS (
    SELECT SEQ4() AS SLOT_NUM
    FROM TABLE(GENERATOR(ROWCOUNT => 32))
),
-- 50 machines
MACHINES_GEN AS (
    SELECT SEQ4() + 1 AS MCH_NUM
    FROM TABLE(GENERATOR(ROWCOUNT => 50))
),
-- 8 sensor types
SENSOR_TYPES AS (
    SELECT SEQ4() + 1 AS SENSOR_SEQ
    FROM TABLE(GENERATOR(ROWCOUNT => 8))
),
-- Degradation machines lookup
DEGRADE AS (
    SELECT  3 AS MCH_NUM, 60 AS FAIL_DAY UNION ALL
    SELECT 12,            45              UNION ALL
    SELECT 25,            70              UNION ALL
    SELECT 31,            55              UNION ALL
    SELECT 47,            65
),
-- Cross join everything
BASE AS (
    SELECT
        d.DAY_NUM,
        sl.SLOT_NUM,
        m.MCH_NUM,
        st.SENSOR_SEQ,
        -- Timestamp: 2026-06-01 + day offset, time = 06:00 + slot*30min
        DATEADD('minute',
            sl.SLOT_NUM * 30,
            DATEADD('hour', 6,
                DATEADD('day', d.DAY_NUM, '2026-06-01'::TIMESTAMP_NTZ)
            )
        )                                                         AS TS,
        -- Failure day (NULL for non-degrading machines)
        dg.FAIL_DAY,
        -- Degradation progress: 0.0 to 1.0 quadratic ramp over last 30 days before failure
        CASE
            WHEN dg.FAIL_DAY IS NOT NULL
                 AND d.DAY_NUM >= (dg.FAIL_DAY - 30)
                 AND d.DAY_NUM <= dg.FAIL_DAY
            THEN POWER((d.DAY_NUM - (dg.FAIL_DAY - 30))::FLOAT / 30.0, 2)
            WHEN dg.FAIL_DAY IS NOT NULL
                 AND d.DAY_NUM > dg.FAIL_DAY
            THEN 1.0
            ELSE 0.0
        END                                                       AS DEGRADE_FACTOR,
        -- Deterministic hash for pseudo-random per-reading variation
        ABS(HASH(d.DAY_NUM, sl.SLOT_NUM, m.MCH_NUM, st.SENSOR_SEQ)) AS H
    FROM DAYS d
    CROSS JOIN SLOTS sl
    CROSS JOIN MACHINES_GEN m
    CROSS JOIN SENSOR_TYPES st
    LEFT JOIN DEGRADE dg ON m.MCH_NUM = dg.MCH_NUM
)
SELECT
    UUID_STRING()                                                     AS READING_ID,
    'SEN-' || LPAD(MCH_NUM, 4, '0') || '-' || LPAD(SENSOR_SEQ, 2, '0') AS SENSOR_ID,
    'MCH-' || LPAD(MCH_NUM, 4, '0')                                  AS MACHINE_ID,
    TS                                                                AS READING_TIMESTAMP,
    CASE SENSOR_SEQ
        WHEN 1 THEN 'VIBRATION'
        WHEN 2 THEN 'TEMPERATURE'
        WHEN 3 THEN 'PRESSURE'
        WHEN 4 THEN 'FLOW'
        WHEN 5 THEN 'CURRENT'
        WHEN 6 THEN 'CYCLE_COUNTER'
        WHEN 7 THEN 'ACOUSTIC'
        WHEN 8 THEN 'BEARING_TEMP'
    END                                                               AS SENSOR_TYPE,
    -- Compute sensor value: base + noise + degradation + occasional spike
    ROUND(
        CASE SENSOR_SEQ
            -- VIBRATION: base 2-4 mm/s, degrades up to +10
            WHEN 1 THEN 2.0 + (MOD(H, 200) / 100.0)
                        + DEGRADE_FACTOR * 10.0
                        + CASE WHEN MOD(H, 20) = 0 AND DEGRADE_FACTOR = 0 THEN 5.0 ELSE 0 END
            -- TEMPERATURE: base 45-65 C, degrades up to +35
            WHEN 2 THEN 45.0 + (MOD(H, 2000) / 100.0)
                        + DEGRADE_FACTOR * 35.0
                        + CASE WHEN MOD(H, 20) = 0 AND DEGRADE_FACTOR = 0 THEN 15.0 ELSE 0 END
            -- PRESSURE: base 5-8 bar, no degradation effect
            WHEN 3 THEN 5.0 + (MOD(H, 300) / 100.0)
                        + CASE WHEN MOD(H, 20) = 0 THEN 3.0 ELSE 0 END
            -- FLOW: base 40-70 L/min
            WHEN 4 THEN 40.0 + (MOD(H, 3000) / 100.0)
                        + CASE WHEN MOD(H, 20) = 0 THEN 10.0 ELSE 0 END
            -- CURRENT: base 30-50 A, degrades up to +40
            WHEN 5 THEN 30.0 + (MOD(H, 2000) / 100.0)
                        + DEGRADE_FACTOR * 40.0
                        + CASE WHEN MOD(H, 20) = 0 AND DEGRADE_FACTOR = 0 THEN 20.0 ELSE 0 END
            -- CYCLE_COUNTER: base 100-300 per slot
            WHEN 6 THEN 100.0 + MOD(H, 200)
            -- ACOUSTIC: base 55-70 dB, degrades up to +30
            WHEN 7 THEN 55.0 + (MOD(H, 1500) / 100.0)
                        + DEGRADE_FACTOR * 30.0
                        + CASE WHEN MOD(H, 20) = 0 AND DEGRADE_FACTOR = 0 THEN 12.0 ELSE 0 END
            -- BEARING_TEMP: base 35-50 C, degrades up to +40
            WHEN 8 THEN 35.0 + (MOD(H, 1500) / 100.0)
                        + DEGRADE_FACTOR * 40.0
                        + CASE WHEN MOD(H, 20) = 0 AND DEGRADE_FACTOR = 0 THEN 15.0 ELSE 0 END
        END
    , 2)                                                              AS VALUE,
    CASE SENSOR_SEQ
        WHEN 1 THEN 'mm/s'
        WHEN 2 THEN 'C'
        WHEN 3 THEN 'bar'
        WHEN 4 THEN 'L/min'
        WHEN 5 THEN 'A'
        WHEN 6 THEN 'count'
        WHEN 7 THEN 'dB'
        WHEN 8 THEN 'C'
    END                                                               AS UNIT,
    -- Quality score: 95-100 normally, degrades to 60-80 with degradation
    ROUND(GREATEST(60, 100.0 - DEGRADE_FACTOR * 35.0 - MOD(H, 500) / 100.0), 1) AS QUALITY_SCORE,
    -- IS_ANOMALY: true if degradation > 0.6 for affected sensors, or 5% random spike
    CASE
        WHEN SENSOR_SEQ IN (1, 2, 5, 7, 8) AND DEGRADE_FACTOR > 0.6 THEN TRUE
        WHEN MOD(H, 20) = 0 THEN TRUE
        ELSE FALSE
    END                                                               AS IS_ANOMALY
FROM BASE;


-- ============================================================================
-- 4. MAINTENANCE_HISTORY (~238 rows)
-- ============================================================================
-- ~4-5 historical maintenance events per machine spread over the 90-day window.
-- Failure types, root causes, resolutions, parts replaced, downtime, cost.
-- Technician IDs: TECH-001 to TECH-010
-- ============================================================================

INSERT INTO MAINTENANCE_HISTORY (
    MAINTENANCE_ID, MACHINE_ID, MAINTENANCE_TYPE, MAINTENANCE_DATE,
    FAILURE_TYPE, ROOT_CAUSE, RESOLUTION, PARTS_REPLACED,
    DOWNTIME_HOURS, COST_USD, TECHNICIAN_ID, NOTES
)
WITH
-- Generate up to 5 events per machine (250 base rows), then filter to ~238
MAINT_BASE AS (
    SELECT
        m.MCH_NUM,
        e.EVT_SEQ,
        ABS(HASH(m.MCH_NUM, e.EVT_SEQ, 42)) AS H
    FROM
        (SELECT SEQ4() + 1 AS MCH_NUM FROM TABLE(GENERATOR(ROWCOUNT => 50))) m
        CROSS JOIN
        (SELECT SEQ4() + 1 AS EVT_SEQ FROM TABLE(GENERATOR(ROWCOUNT => 5))) e
    WHERE
        -- Keep ~95% of rows to get ~238
        MOD(ABS(HASH(m.MCH_NUM, e.EVT_SEQ, 99)), 100) < 95
)
SELECT
    'MNT-' || LPAD(ROW_NUMBER() OVER (ORDER BY MCH_NUM, EVT_SEQ), 5, '0') AS MAINTENANCE_ID,
    'MCH-' || LPAD(MCH_NUM, 4, '0')                                        AS MACHINE_ID,
    CASE MOD(H, 4)
        WHEN 0 THEN 'CORRECTIVE'
        WHEN 1 THEN 'PREVENTIVE'
        WHEN 2 THEN 'PREDICTIVE'
        WHEN 3 THEN 'EMERGENCY'
    END                                                                     AS MAINTENANCE_TYPE,
    DATEADD('day', MOD(H, 90), '2026-06-01')::TIMESTAMP_NTZ                AS MAINTENANCE_DATE,
    CASE MOD(H, 8)
        WHEN 0 THEN 'BEARING_FAILURE'
        WHEN 1 THEN 'SERVO_MOTOR_BURNOUT'
        WHEN 2 THEN 'SEAL_DEGRADATION'
        WHEN 3 THEN 'HYDRAULIC_LEAK'
        WHEN 4 THEN 'OVERHEATING'
        WHEN 5 THEN 'ELECTRICAL_FAULT'
        WHEN 6 THEN 'BELT_WEAR'
        WHEN 7 THEN 'PUMP_CAVITATION'
    END                                                                     AS FAILURE_TYPE,
    CASE MOD(H, 6)
        WHEN 0 THEN 'Normal wear and tear'
        WHEN 1 THEN 'Insufficient lubrication'
        WHEN 2 THEN 'Overloading beyond rated capacity'
        WHEN 3 THEN 'Contaminated hydraulic fluid'
        WHEN 4 THEN 'Misalignment after last service'
        WHEN 5 THEN 'Voltage fluctuations in supply'
    END                                                                     AS ROOT_CAUSE,
    CASE MOD(H, 5)
        WHEN 0 THEN 'Replaced worn component'
        WHEN 1 THEN 'Recalibrated and tested'
        WHEN 2 THEN 'Full overhaul of subsystem'
        WHEN 3 THEN 'Temporary repair pending parts'
        WHEN 4 THEN 'Cleaned and relubricated'
    END                                                                     AS RESOLUTION,
    CASE MOD(H, 8)
        WHEN 0 THEN 'Bearing kit, seals'
        WHEN 1 THEN 'Servo motor assembly'
        WHEN 2 THEN 'Seal kit, O-rings'
        WHEN 3 THEN 'Hydraulic hoses, fittings'
        WHEN 4 THEN 'Cooling fan, thermal paste'
        WHEN 5 THEN 'Fuses, contactors'
        WHEN 6 THEN 'Drive belt, tensioner'
        WHEN 7 THEN 'Pump impeller, gaskets'
    END                                                                     AS PARTS_REPLACED,
    ROUND(2.0 + MOD(H, 98), 1)                                             AS DOWNTIME_HOURS,
    ROUND(500.0 + MOD(H, 14500), 2)                                        AS COST_USD,
    'TECH-' || LPAD(MOD(H, 10) + 1, 3, '0')                                AS TECHNICIAN_ID,
    'Maintenance event #' || EVT_SEQ || ' for machine MCH-' || LPAD(MCH_NUM, 4, '0') AS NOTES
FROM MAINT_BASE;


-- ============================================================================
-- 5. MACHINE_EVENT_LOGS (~1,919 rows)
-- ============================================================================
-- Daily STARTUP (6AM) and SHUTDOWN (10PM) per machine = 50*90*2 = 9000 base,
-- but we only keep ~20% of routine logs plus incident events near failure dates
-- for the 5 degrading machines.
-- ============================================================================

INSERT INTO MACHINE_EVENT_LOGS (
    EVENT_ID, MACHINE_ID, EVENT_TIMESTAMP, EVENT_TYPE,
    EVENT_CATEGORY, SEVERITY, DESCRIPTION, OPERATOR_ID
)
WITH
-- Daily events for all machines
DAILY AS (
    SELECT
        d.DAY_NUM,
        m.MCH_NUM,
        ABS(HASH(d.DAY_NUM, m.MCH_NUM, 77)) AS H
    FROM
        (SELECT SEQ4() AS DAY_NUM FROM TABLE(GENERATOR(ROWCOUNT => 90))) d
        CROSS JOIN
        (SELECT SEQ4() + 1 AS MCH_NUM FROM TABLE(GENERATOR(ROWCOUNT => 50))) m
),
-- Keep ~20% of startup/shutdown pairs
ROUTINE AS (
    SELECT
        DAY_NUM, MCH_NUM, H,
        'STARTUP' AS EVENT_TYPE,
        DATEADD('hour', 6, DATEADD('day', DAY_NUM, '2026-06-01'::TIMESTAMP_NTZ)) AS TS
    FROM DAILY
    WHERE MOD(H, 5) = 0

    UNION ALL

    SELECT
        DAY_NUM, MCH_NUM, H,
        'SHUTDOWN' AS EVENT_TYPE,
        DATEADD('hour', 22, DATEADD('day', DAY_NUM, '2026-06-01'::TIMESTAMP_NTZ)) AS TS
    FROM DAILY
    WHERE MOD(H, 5) = 0
),
-- Incident events for 5 failing machines (within 5 days of failure)
DEGRADE AS (
    SELECT  3 AS MCH_NUM, 60 AS FAIL_DAY UNION ALL
    SELECT 12,            45              UNION ALL
    SELECT 25,            70              UNION ALL
    SELECT 31,            55              UNION ALL
    SELECT 47,            65
),
INCIDENTS AS (
    SELECT
        d.DAY_NUM,
        dg.MCH_NUM,
        ABS(HASH(d.DAY_NUM, dg.MCH_NUM, 88)) AS H,
        CASE MOD(ABS(HASH(d.DAY_NUM, dg.MCH_NUM, 33)), 3)
            WHEN 0 THEN 'OVERLOAD'
            WHEN 1 THEN 'JAM'
            WHEN 2 THEN 'ERROR'
        END AS EVENT_TYPE,
        DATEADD('minute',
            360 + MOD(ABS(HASH(d.DAY_NUM, dg.MCH_NUM, 55)), 960),
            DATEADD('day', d.DAY_NUM, '2026-06-01'::TIMESTAMP_NTZ)
        ) AS TS
    FROM
        (SELECT SEQ4() AS DAY_NUM FROM TABLE(GENERATOR(ROWCOUNT => 90))) d
        INNER JOIN DEGRADE dg
            ON d.DAY_NUM BETWEEN (dg.FAIL_DAY - 5) AND dg.FAIL_DAY
),
COMBINED AS (
    SELECT DAY_NUM, MCH_NUM, H, EVENT_TYPE, TS FROM ROUTINE
    UNION ALL
    SELECT DAY_NUM, MCH_NUM, H, EVENT_TYPE, TS FROM INCIDENTS
)
SELECT
    UUID_STRING()                                              AS EVENT_ID,
    'MCH-' || LPAD(MCH_NUM, 4, '0')                           AS MACHINE_ID,
    TS                                                         AS EVENT_TIMESTAMP,
    EVENT_TYPE,
    CASE EVENT_TYPE
        WHEN 'STARTUP'  THEN 'OPERATIONAL'
        WHEN 'SHUTDOWN' THEN 'OPERATIONAL'
        WHEN 'OVERLOAD' THEN 'SAFETY'
        WHEN 'JAM'      THEN 'MECHANICAL'
        WHEN 'ERROR'    THEN 'SYSTEM'
    END                                                        AS EVENT_CATEGORY,
    CASE EVENT_TYPE
        WHEN 'STARTUP'  THEN 'INFO'
        WHEN 'SHUTDOWN' THEN 'INFO'
        WHEN 'OVERLOAD' THEN 'CRITICAL'
        WHEN 'JAM'      THEN 'WARNING'
        WHEN 'ERROR'    THEN 'ERROR'
    END                                                        AS SEVERITY,
    CASE EVENT_TYPE
        WHEN 'STARTUP'  THEN 'Machine started for shift operations'
        WHEN 'SHUTDOWN' THEN 'Machine shut down after shift'
        WHEN 'OVERLOAD' THEN 'Overload condition detected - auto-shutdown triggered'
        WHEN 'JAM'      THEN 'Material jam detected in feed mechanism'
        WHEN 'ERROR'    THEN 'System error code E-' || MOD(H, 999)
    END                                                        AS DESCRIPTION,
    'OP-' || LPAD(MOD(H, 15) + 1, 3, '0')                     AS OPERATOR_ID
FROM COMBINED;


-- ============================================================================
-- 6. PARTS_INVENTORY (10 rows)
-- ============================================================================
-- 10 part types with quantity, reorder level, lead time, cost.
-- ============================================================================

INSERT INTO PARTS_INVENTORY (
    PART_ID, PART_NAME, PART_CATEGORY, QUANTITY_ON_HAND,
    REORDER_LEVEL, REORDER_QUANTITY, LEAD_TIME_DAYS,
    UNIT_COST_USD, SUPPLIER, LAST_RESTOCK_DATE
)
SELECT
    'PRT-' || LPAD(SEQ4() + 1, 4, '0')    AS PART_ID,
    CASE SEQ4()
        WHEN 0 THEN 'Bearing Kit'
        WHEN 1 THEN 'Seal Kit'
        WHEN 2 THEN 'Hydraulic Filter'
        WHEN 3 THEN 'Servo Motor'
        WHEN 4 THEN 'Flexible Coupling'
        WHEN 5 THEN 'Drive Belt'
        WHEN 6 THEN 'Valve Assembly'
        WHEN 7 THEN 'Heater Band'
        WHEN 8 THEN 'Nozzle Tip'
        WHEN 9 THEN 'Pump Impeller'
    END                                     AS PART_NAME,
    CASE SEQ4()
        WHEN 0 THEN 'BEARINGS'
        WHEN 1 THEN 'SEALS'
        WHEN 2 THEN 'FILTERS'
        WHEN 3 THEN 'MOTORS'
        WHEN 4 THEN 'COUPLINGS'
        WHEN 5 THEN 'BELTS'
        WHEN 6 THEN 'VALVES'
        WHEN 7 THEN 'HEATING'
        WHEN 8 THEN 'NOZZLES'
        WHEN 9 THEN 'IMPELLERS'
    END                                     AS PART_CATEGORY,
    CASE SEQ4()
        WHEN 0 THEN 25
        WHEN 1 THEN 40
        WHEN 2 THEN 50
        WHEN 3 THEN 5
        WHEN 4 THEN 15
        WHEN 5 THEN 30
        WHEN 6 THEN 8
        WHEN 7 THEN 12
        WHEN 8 THEN 35
        WHEN 9 THEN 10
    END                                     AS QUANTITY_ON_HAND,
    CASE SEQ4()
        WHEN 0 THEN 5
        WHEN 1 THEN 8
        WHEN 2 THEN 10
        WHEN 3 THEN 3
        WHEN 4 THEN 4
        WHEN 5 THEN 6
        WHEN 6 THEN 3
        WHEN 7 THEN 4
        WHEN 8 THEN 7
        WHEN 9 THEN 3
    END                                     AS REORDER_LEVEL,
    CASE SEQ4()
        WHEN 0 THEN 20
        WHEN 1 THEN 30
        WHEN 2 THEN 40
        WHEN 3 THEN 5
        WHEN 4 THEN 10
        WHEN 5 THEN 20
        WHEN 6 THEN 5
        WHEN 7 THEN 10
        WHEN 8 THEN 25
        WHEN 9 THEN 8
    END                                     AS REORDER_QUANTITY,
    CASE SEQ4()
        WHEN 0 THEN 3
        WHEN 1 THEN 2
        WHEN 2 THEN 1
        WHEN 3 THEN 14
        WHEN 4 THEN 5
        WHEN 5 THEN 2
        WHEN 6 THEN 7
        WHEN 7 THEN 10
        WHEN 8 THEN 3
        WHEN 9 THEN 12
    END                                     AS LEAD_TIME_DAYS,
    CASE SEQ4()
        WHEN 0 THEN 150.00
        WHEN 1 THEN 75.00
        WHEN 2 THEN 50.00
        WHEN 3 THEN 2000.00
        WHEN 4 THEN 200.00
        WHEN 5 THEN 85.00
        WHEN 6 THEN 450.00
        WHEN 7 THEN 120.00
        WHEN 8 THEN 65.00
        WHEN 9 THEN 800.00
    END                                     AS UNIT_COST_USD,
    CASE SEQ4()
        WHEN 0 THEN 'SKF Industrial'
        WHEN 1 THEN 'Parker Hannifin'
        WHEN 2 THEN 'Donaldson'
        WHEN 3 THEN 'Siemens Drives'
        WHEN 4 THEN 'Rexnord'
        WHEN 5 THEN 'Gates Corporation'
        WHEN 6 THEN 'Emerson'
        WHEN 7 THEN 'Watlow'
        WHEN 8 THEN 'Nordson'
        WHEN 9 THEN 'Grundfos Parts'
    END                                     AS SUPPLIER,
    DATEADD('day', -1 * (SEQ4() * 3 + 5), '2026-06-01')::DATE AS LAST_RESTOCK_DATE
FROM TABLE(GENERATOR(ROWCOUNT => 10));


-- ============================================================================
-- 7. RENTAL_MACHINES (6 rows)
-- ============================================================================
-- One rental option per machine type with vendor, daily/weekly cost.
-- ============================================================================

INSERT INTO RENTAL_MACHINES (
    RENTAL_ID, MACHINE_TYPE, VENDOR_NAME,
    DAILY_COST_USD, WEEKLY_COST_USD, LEAD_TIME_DAYS,
    AVAILABILITY, CONTACT_INFO
)
SELECT
    'RNT-' || LPAD(SEQ4() + 1, 4, '0')       AS RENTAL_ID,
    CASE SEQ4()
        WHEN 0 THEN 'CNC_LATHE'
        WHEN 1 THEN 'HYDRAULIC_PRESS'
        WHEN 2 THEN 'CONVEYOR'
        WHEN 3 THEN 'INJECTION_MOLDER'
        WHEN 4 THEN 'PUMP'
        WHEN 5 THEN 'COMPRESSOR'
    END                                        AS MACHINE_TYPE,
    CASE SEQ4()
        WHEN 0 THEN 'United Rentals Industrial'
        WHEN 1 THEN 'Sunbelt Machine Rental'
        WHEN 2 THEN 'BlueLine Conveyor Rentals'
        WHEN 3 THEN 'ProMold Leasing'
        WHEN 4 THEN 'FlowServe Rentals'
        WHEN 5 THEN 'AirPower Solutions'
    END                                        AS VENDOR_NAME,
    CASE SEQ4()
        WHEN 0 THEN 350.00
        WHEN 1 THEN 500.00
        WHEN 2 THEN 150.00
        WHEN 3 THEN 450.00
        WHEN 4 THEN 200.00
        WHEN 5 THEN 300.00
    END                                        AS DAILY_COST_USD,
    CASE SEQ4()
        WHEN 0 THEN 1750.00
        WHEN 1 THEN 2500.00
        WHEN 2 THEN 750.00
        WHEN 3 THEN 2250.00
        WHEN 4 THEN 1000.00
        WHEN 5 THEN 1500.00
    END                                        AS WEEKLY_COST_USD,
    CASE SEQ4()
        WHEN 0 THEN 3
        WHEN 1 THEN 5
        WHEN 2 THEN 1
        WHEN 3 THEN 4
        WHEN 4 THEN 2
        WHEN 5 THEN 2
    END                                        AS LEAD_TIME_DAYS,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN 'AVAILABLE'
        WHEN 1 THEN 'LIMITED'
        WHEN 2 THEN 'AVAILABLE'
    END                                        AS AVAILABILITY,
    CASE SEQ4()
        WHEN 0 THEN 'sales@unitedrentals-ind.com | 800-555-0101'
        WHEN 1 THEN 'heavy@sunbelt.com | 800-555-0102'
        WHEN 2 THEN 'info@bluelineconveyors.com | 800-555-0103'
        WHEN 3 THEN 'lease@promold.com | 800-555-0104'
        WHEN 4 THEN 'rental@flowserve.com | 800-555-0105'
        WHEN 5 THEN 'solutions@airpower.com | 800-555-0106'
    END                                        AS CONTACT_INFO
FROM TABLE(GENERATOR(ROWCOUNT => 6));


-- ============================================================================
-- 8. SHIFT_LOGS (~4,183 rows)
-- ============================================================================
-- 3 shifts/day x 50 machines x 90 days = 13,500 potential. Keep ~31% for ~4,183.
-- Failing machines get escalating observation types near failure dates.
-- Normal machines get ROUTINE observations.
-- Operator IDs: OP-001 to OP-015
-- ============================================================================

INSERT INTO SHIFT_LOGS (
    LOG_ID, MACHINE_ID, SHIFT_DATE, SHIFT_NUMBER,
    OPERATOR_ID, OBSERVATION_TYPE, OBSERVATION_NOTES,
    MACHINE_CONDITION, ESCALATED
)
WITH
DEGRADE AS (
    SELECT  3 AS MCH_NUM, 60 AS FAIL_DAY UNION ALL
    SELECT 12,            45              UNION ALL
    SELECT 25,            70              UNION ALL
    SELECT 31,            55              UNION ALL
    SELECT 47,            65
),
BASE AS (
    SELECT
        d.DAY_NUM,
        m.MCH_NUM,
        sh.SHIFT_NUM,
        ABS(HASH(d.DAY_NUM, m.MCH_NUM, sh.SHIFT_NUM, 123)) AS H,
        dg.FAIL_DAY
    FROM
        (SELECT SEQ4() AS DAY_NUM FROM TABLE(GENERATOR(ROWCOUNT => 90))) d
        CROSS JOIN
        (SELECT SEQ4() + 1 AS MCH_NUM FROM TABLE(GENERATOR(ROWCOUNT => 50))) m
        CROSS JOIN
        (SELECT SEQ4() + 1 AS SHIFT_NUM FROM TABLE(GENERATOR(ROWCOUNT => 3))) sh
        LEFT JOIN DEGRADE dg ON m.MCH_NUM = dg.MCH_NUM
    WHERE
        -- ~31% sampling, but always keep logs near failure for degrading machines
        MOD(ABS(HASH(d.DAY_NUM, m.MCH_NUM, sh.SHIFT_NUM, 456)), 100) < 31
        OR (dg.FAIL_DAY IS NOT NULL AND d.DAY_NUM BETWEEN (dg.FAIL_DAY - 10) AND dg.FAIL_DAY)
)
SELECT
    UUID_STRING()                                              AS LOG_ID,
    'MCH-' || LPAD(MCH_NUM, 4, '0')                           AS MACHINE_ID,
    DATEADD('day', DAY_NUM, '2026-06-01')::DATE                AS SHIFT_DATE,
    SHIFT_NUM                                                  AS SHIFT_NUMBER,
    'OP-' || LPAD(MOD(H, 15) + 1, 3, '0')                     AS OPERATOR_ID,
    CASE
        WHEN FAIL_DAY IS NOT NULL AND DAY_NUM BETWEEN (FAIL_DAY - 2) AND FAIL_DAY
        THEN CASE MOD(H, 5)
                WHEN 0 THEN 'VIBRATION'
                WHEN 1 THEN 'NOISE'
                WHEN 2 THEN 'SMELL'
                WHEN 3 THEN 'LEAK'
                WHEN 4 THEN 'VISUAL'
             END
        WHEN FAIL_DAY IS NOT NULL AND DAY_NUM BETWEEN (FAIL_DAY - 7) AND (FAIL_DAY - 3)
        THEN CASE MOD(H, 3)
                WHEN 0 THEN 'VIBRATION'
                WHEN 1 THEN 'NOISE'
                WHEN 2 THEN 'VISUAL'
             END
        ELSE 'ROUTINE'
    END                                                        AS OBSERVATION_TYPE,
    CASE
        WHEN FAIL_DAY IS NOT NULL AND DAY_NUM BETWEEN (FAIL_DAY - 2) AND FAIL_DAY
        THEN 'Significant anomaly detected - immediate attention required'
        WHEN FAIL_DAY IS NOT NULL AND DAY_NUM BETWEEN (FAIL_DAY - 7) AND (FAIL_DAY - 3)
        THEN 'Unusual readings noted during shift - monitoring closely'
        ELSE 'Normal operations - no issues observed'
    END                                                        AS OBSERVATION_NOTES,
    CASE
        WHEN FAIL_DAY IS NOT NULL AND DAY_NUM >= FAIL_DAY      THEN 'FAILED'
        WHEN FAIL_DAY IS NOT NULL AND DAY_NUM >= (FAIL_DAY - 3) THEN 'CRITICAL'
        WHEN FAIL_DAY IS NOT NULL AND DAY_NUM >= (FAIL_DAY - 7) THEN 'DEGRADED'
        ELSE 'GOOD'
    END                                                        AS MACHINE_CONDITION,
    CASE
        WHEN FAIL_DAY IS NOT NULL AND DAY_NUM >= (FAIL_DAY - 3) THEN TRUE
        ELSE FALSE
    END                                                        AS ESCALATED
FROM BASE;


-- ============================================================================
-- 9. TOOLING_CHANGES (~157 rows)
-- ============================================================================
-- Only CNC_LATHE (mod6=0) and INJECTION_MOLDER (mod6=3) machines.
-- Tool changes every 7-14 days. Reasons: SCHEDULED_PM, WEAR_LIMIT,
-- PRODUCT_CHANGE, QUALITY_ISSUE.
-- ============================================================================

INSERT INTO TOOLING_CHANGES (
    CHANGE_ID, MACHINE_ID, CHANGE_DATE, TOOL_TYPE,
    CHANGE_REASON, OLD_TOOL_LIFE_PERCENT, NEW_TOOL_ID,
    TECHNICIAN_ID
)
WITH
-- CNC_LATHE machines: 1,7,13,19,25,31,37,43,49  (mod6=0, 1-indexed)
-- INJECTION_MOLDER: 4,10,16,22,28,34,40,46       (mod6=3, 1-indexed)
ELIGIBLE AS (
    SELECT SEQ4() + 1 AS MCH_NUM
    FROM TABLE(GENERATOR(ROWCOUNT => 50))
    WHERE MOD(SEQ4(), 6) IN (0, 3)
),
-- Generate ~10 change events per machine (spaced 7-14 days)
CHANGES AS (
    SELECT
        e.MCH_NUM,
        c.CHG_SEQ,
        ABS(HASH(e.MCH_NUM, c.CHG_SEQ, 789)) AS H
    FROM ELIGIBLE e
    CROSS JOIN (SELECT SEQ4() + 1 AS CHG_SEQ FROM TABLE(GENERATOR(ROWCOUNT => 10))) c
    WHERE
        -- Keep changes within 90-day window
        (c.CHG_SEQ - 1) * 9 < 90
)
SELECT
    'TLC-' || LPAD(ROW_NUMBER() OVER (ORDER BY MCH_NUM, CHG_SEQ), 5, '0') AS CHANGE_ID,
    'MCH-' || LPAD(MCH_NUM, 4, '0')                                        AS MACHINE_ID,
    DATEADD('day',
        LEAST((CHG_SEQ - 1) * (7 + MOD(H, 8)), 89),
        '2026-06-01'
    )::TIMESTAMP_NTZ                                                        AS CHANGE_DATE,
    CASE MOD(H, 4)
        WHEN 0 THEN 'CUTTING_INSERT'
        WHEN 1 THEN 'DRILL_BIT'
        WHEN 2 THEN 'END_MILL'
        WHEN 3 THEN 'MOLD_CORE'
    END                                                                     AS TOOL_TYPE,
    CASE MOD(H, 4)
        WHEN 0 THEN 'SCHEDULED_PM'
        WHEN 1 THEN 'WEAR_LIMIT'
        WHEN 2 THEN 'PRODUCT_CHANGE'
        WHEN 3 THEN 'QUALITY_ISSUE'
    END                                                                     AS CHANGE_REASON,
    ROUND(5.0 + MOD(H, 30), 1)                                             AS OLD_TOOL_LIFE_PERCENT,
    'TOOL-' || LPAD(MOD(H, 500) + 1, 5, '0')                               AS NEW_TOOL_ID,
    'TECH-' || LPAD(MOD(H, 10) + 1, 3, '0')                                AS TECHNICIAN_ID
FROM CHANGES;


-- ============================================================================
-- 10. PRODUCTION_QUALITY (13,500 rows)
-- ============================================================================
-- 50 machines x 90 days x 3 shifts. Parts produced (varies by machine type),
-- parts rejected (increases with degradation), cycle time (increases with
-- degradation), tolerance deviation, surface finish RA, volume vs target %.
-- ============================================================================

INSERT INTO PRODUCTION_QUALITY (
    RECORD_ID, MACHINE_ID, PRODUCTION_DATE, SHIFT_NUMBER,
    PARTS_PRODUCED, PARTS_REJECTED, REJECTION_RATE,
    CYCLE_TIME_SECONDS, TOLERANCE_DEVIATION_MM,
    SURFACE_FINISH_RA, VOLUME_VS_TARGET_PCT
)
WITH
DEGRADE AS (
    SELECT  3 AS MCH_NUM, 60 AS FAIL_DAY UNION ALL
    SELECT 12,            45              UNION ALL
    SELECT 25,            70              UNION ALL
    SELECT 31,            55              UNION ALL
    SELECT 47,            65
),
BASE AS (
    SELECT
        d.DAY_NUM,
        m.MCH_NUM,
        sh.SHIFT_NUM,
        ABS(HASH(d.DAY_NUM, m.MCH_NUM, sh.SHIFT_NUM, 555)) AS H,
        dg.FAIL_DAY,
        CASE
            WHEN dg.FAIL_DAY IS NOT NULL
                 AND d.DAY_NUM >= (dg.FAIL_DAY - 30)
                 AND d.DAY_NUM <= dg.FAIL_DAY
            THEN POWER((d.DAY_NUM - (dg.FAIL_DAY - 30))::FLOAT / 30.0, 2)
            WHEN dg.FAIL_DAY IS NOT NULL AND d.DAY_NUM > dg.FAIL_DAY
            THEN 1.0
            ELSE 0.0
        END AS DEGRADE_FACTOR,
        MOD(m.MCH_NUM - 1, 6) AS MTYPE
    FROM
        (SELECT SEQ4() AS DAY_NUM FROM TABLE(GENERATOR(ROWCOUNT => 90))) d
        CROSS JOIN
        (SELECT SEQ4() + 1 AS MCH_NUM FROM TABLE(GENERATOR(ROWCOUNT => 50))) m
        CROSS JOIN
        (SELECT SEQ4() + 1 AS SHIFT_NUM FROM TABLE(GENERATOR(ROWCOUNT => 3))) sh
        LEFT JOIN DEGRADE dg ON m.MCH_NUM = dg.MCH_NUM
)
SELECT
    UUID_STRING()                                                      AS RECORD_ID,
    'MCH-' || LPAD(MCH_NUM, 4, '0')                                   AS MACHINE_ID,
    DATEADD('day', DAY_NUM, '2026-06-01')::DATE                        AS PRODUCTION_DATE,
    SHIFT_NUM                                                          AS SHIFT_NUMBER,
    -- Parts produced: baseline by machine type, reduced by degradation
    GREATEST(1, ROUND(
        CASE MTYPE
            WHEN 0 THEN 50   -- CNC_LATHE
            WHEN 1 THEN 30   -- HYDRAULIC_PRESS
            WHEN 2 THEN 200  -- CONVEYOR (throughput)
            WHEN 3 THEN 120  -- INJECTION_MOLDER
            WHEN 4 THEN 0    -- PUMP (not applicable, use 0)
            WHEN 5 THEN 0    -- COMPRESSOR (not applicable, use 0)
        END
        * (1.0 - DEGRADE_FACTOR * 0.4)
        + MOD(H, 20) - 10
    ))                                                                 AS PARTS_PRODUCED,
    -- Parts rejected: increases with degradation
    GREATEST(0, ROUND(
        CASE MTYPE
            WHEN 0 THEN 2 + DEGRADE_FACTOR * 15
            WHEN 1 THEN 1 + DEGRADE_FACTOR * 10
            WHEN 2 THEN 3 + DEGRADE_FACTOR * 20
            WHEN 3 THEN 4 + DEGRADE_FACTOR * 25
            WHEN 4 THEN 0
            WHEN 5 THEN 0
        END
        + MOD(H, 3)
    ))                                                                 AS PARTS_REJECTED,
    -- Rejection rate computed
    ROUND(
        CASE
            WHEN CASE MTYPE WHEN 4 THEN 0 WHEN 5 THEN 0 ELSE 1 END = 0 THEN 0
            ELSE (
                GREATEST(0, ROUND(
                    CASE MTYPE
                        WHEN 0 THEN 2 + DEGRADE_FACTOR * 15
                        WHEN 1 THEN 1 + DEGRADE_FACTOR * 10
                        WHEN 2 THEN 3 + DEGRADE_FACTOR * 20
                        WHEN 3 THEN 4 + DEGRADE_FACTOR * 25
                        ELSE 0
                    END + MOD(H, 3)
                ))::FLOAT
                /
                NULLIF(GREATEST(1, ROUND(
                    CASE MTYPE
                        WHEN 0 THEN 50
                        WHEN 1 THEN 30
                        WHEN 2 THEN 200
                        WHEN 3 THEN 120
                        ELSE 1
                    END * (1.0 - DEGRADE_FACTOR * 0.4) + MOD(H, 20) - 10
                )), 0)
                * 100.0
            )
        END
    , 2)                                                               AS REJECTION_RATE,
    -- Cycle time in seconds: baseline + degradation increase
    ROUND(
        CASE MTYPE
            WHEN 0 THEN 120.0
            WHEN 1 THEN 45.0
            WHEN 2 THEN 5.0
            WHEN 3 THEN 30.0
            WHEN 4 THEN 0
            WHEN 5 THEN 0
        END
        * (1.0 + DEGRADE_FACTOR * 0.5)
        + MOD(H, 100) / 10.0
    , 2)                                                               AS CYCLE_TIME_SECONDS,
    -- Tolerance deviation in mm: increases with degradation
    ROUND(0.01 + (MOD(H, 50) / 1000.0) + DEGRADE_FACTOR * 0.15, 4)   AS TOLERANCE_DEVIATION_MM,
    -- Surface finish RA (roughness): increases with degradation
    ROUND(0.4 + (MOD(H, 80) / 100.0) + DEGRADE_FACTOR * 2.5, 2)      AS SURFACE_FINISH_RA,
    -- Volume vs target %: decreases with degradation
    ROUND(GREATEST(50.0,
        98.0
        - DEGRADE_FACTOR * 35.0
        - MOD(H, 500) / 100.0
    ), 1)                                                              AS VOLUME_VS_TARGET_PCT
FROM BASE;


-- ============================================================================
-- 11. POWER_QUALITY_LOGS (~12,597 rows)
-- ============================================================================
-- During operating hours (32 slots/day), ~15% sample rate for normal machines,
-- higher near failure for degrading machines.
-- Event types: NORMAL, VOLTAGE_SAG, VOLTAGE_SPIKE, HARMONIC_DISTORTION.
-- Nominal 480V, 60Hz.
-- ============================================================================

INSERT INTO POWER_QUALITY_LOGS (
    LOG_ID, MACHINE_ID, LOG_TIMESTAMP, EVENT_TYPE,
    VOLTAGE_V, CURRENT_A, FREQUENCY_HZ,
    POWER_FACTOR, THD_PERCENT
)
WITH
DEGRADE AS (
    SELECT  3 AS MCH_NUM, 60 AS FAIL_DAY UNION ALL
    SELECT 12,            45              UNION ALL
    SELECT 25,            70              UNION ALL
    SELECT 31,            55              UNION ALL
    SELECT 47,            65
),
BASE AS (
    SELECT
        d.DAY_NUM,
        sl.SLOT_NUM,
        m.MCH_NUM,
        ABS(HASH(d.DAY_NUM, sl.SLOT_NUM, m.MCH_NUM, 321)) AS H,
        dg.FAIL_DAY,
        CASE
            WHEN dg.FAIL_DAY IS NOT NULL
                 AND d.DAY_NUM >= (dg.FAIL_DAY - 30)
                 AND d.DAY_NUM <= dg.FAIL_DAY
            THEN POWER((d.DAY_NUM - (dg.FAIL_DAY - 30))::FLOAT / 30.0, 2)
            WHEN dg.FAIL_DAY IS NOT NULL AND d.DAY_NUM > dg.FAIL_DAY
            THEN 1.0
            ELSE 0.0
        END AS DEGRADE_FACTOR
    FROM
        (SELECT SEQ4() AS DAY_NUM FROM TABLE(GENERATOR(ROWCOUNT => 90))) d
        CROSS JOIN
        (SELECT SEQ4() AS SLOT_NUM FROM TABLE(GENERATOR(ROWCOUNT => 32))) sl
        CROSS JOIN
        (SELECT SEQ4() + 1 AS MCH_NUM FROM TABLE(GENERATOR(ROWCOUNT => 50))) m
        LEFT JOIN DEGRADE dg ON m.MCH_NUM = dg.MCH_NUM
    WHERE
        -- ~15% sample for normal, higher near failure
        MOD(ABS(HASH(d.DAY_NUM, sl.SLOT_NUM, m.MCH_NUM, 654)), 100) < 15
        OR (dg.FAIL_DAY IS NOT NULL
            AND d.DAY_NUM BETWEEN (dg.FAIL_DAY - 10) AND dg.FAIL_DAY
            AND MOD(ABS(HASH(d.DAY_NUM, sl.SLOT_NUM, m.MCH_NUM, 654)), 100) < 50)
)
SELECT
    UUID_STRING()                                                      AS LOG_ID,
    'MCH-' || LPAD(MCH_NUM, 4, '0')                                   AS MACHINE_ID,
    DATEADD('minute',
        SLOT_NUM * 30,
        DATEADD('hour', 6,
            DATEADD('day', DAY_NUM, '2026-06-01'::TIMESTAMP_NTZ)
        )
    )                                                                  AS LOG_TIMESTAMP,
    CASE
        WHEN DEGRADE_FACTOR > 0.7 AND MOD(H, 4) = 0 THEN 'VOLTAGE_SAG'
        WHEN DEGRADE_FACTOR > 0.7 AND MOD(H, 4) = 1 THEN 'VOLTAGE_SPIKE'
        WHEN DEGRADE_FACTOR > 0.5 AND MOD(H, 6) = 0 THEN 'HARMONIC_DISTORTION'
        WHEN DEGRADE_FACTOR = 0 AND MOD(H, 25) = 0  THEN 'VOLTAGE_SAG'
        WHEN DEGRADE_FACTOR = 0 AND MOD(H, 30) = 0  THEN 'VOLTAGE_SPIKE'
        ELSE 'NORMAL'
    END                                                                AS EVENT_TYPE,
    -- Voltage: nominal 480V with variation and degradation effects
    ROUND(
        480.0
        + (MOD(H, 200) - 100) / 10.0
        + CASE
            WHEN DEGRADE_FACTOR > 0.7 AND MOD(H, 4) = 0 THEN -30.0  -- sag
            WHEN DEGRADE_FACTOR > 0.7 AND MOD(H, 4) = 1 THEN 25.0   -- spike
            ELSE 0
          END
    , 1)                                                               AS VOLTAGE_V,
    -- Current: nominal based on machine, increases with degradation
    ROUND(
        40.0 + MOD(H, 3000) / 100.0
        + DEGRADE_FACTOR * 30.0
    , 2)                                                               AS CURRENT_A,
    -- Frequency: nominal 60Hz with slight variation
    ROUND(60.0 + (MOD(H, 100) - 50) / 500.0, 3)                       AS FREQUENCY_HZ,
    -- Power factor: degrades from 0.95+ to lower values
    ROUND(GREATEST(0.70,
        0.95 + (MOD(H, 50) - 25) / 500.0 - DEGRADE_FACTOR * 0.15
    ), 3)                                                              AS POWER_FACTOR,
    -- THD%: increases with degradation
    ROUND(
        2.0 + MOD(H, 300) / 100.0
        + DEGRADE_FACTOR * 8.0
        + CASE WHEN DEGRADE_FACTOR > 0.5 AND MOD(H, 6) = 0 THEN 5.0 ELSE 0 END
    , 2)                                                               AS THD_PERCENT
FROM BASE;


-- ============================================================================
-- DATA GENERATION COMPLETE
-- ============================================================================
-- Summary of generated data:
--   MACHINES:            50 rows
--   SENSORS:            400 rows
--   SENSOR_READINGS: ~1,152,000 rows (50 machines x 8 sensors x 90 days x 32 slots)
--   MAINTENANCE_HISTORY: ~238 rows
--   MACHINE_EVENT_LOGS: ~1,919 rows
--   PARTS_INVENTORY:     10 rows
--   RENTAL_MACHINES:      6 rows
--   SHIFT_LOGS:       ~4,183 rows
--   TOOLING_CHANGES:   ~157 rows
--   PRODUCTION_QUALITY: 13,500 rows
--   POWER_QUALITY_LOGS:~12,597 rows
--
-- 5 machines with seeded degradation-to-failure patterns:
--   MCH-0003 (failure day 60 = July 31)
--   MCH-0012 (failure day 45 = July 16)
--   MCH-0025 (failure day 70 = August 10)
--   MCH-0031 (failure day 55 = July 26)
--   MCH-0047 (failure day 65 = August 5)
-- ============================================================================

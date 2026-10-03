-- ============================================================
-- 03_data_generation.sql
-- Synthetic OT + ERP + Production data with seeded degradation
-- ============================================================

USE DATABASE IOT_PREDICTIVE_MAINTENANCE;
USE SCHEMA RAW;
USE WAREHOUSE IOT_PM_WH;

-- ============================================================
-- MACHINES (12 machines across 3 lines)
-- ============================================================
INSERT INTO MACHINES
    (MACHINE_ID, MACHINE_NAME, MACHINE_TYPE, LINE, STATION, LOCATION, RATED_RPM, RATED_CURRENT, RATED_PRESSURE, CRITICALITY, INSTALL_DATE, LAST_OVERHAUL_DATE, OPERATING_STATE, MANUFACTURER, MODEL_NUMBER)
VALUES
    ('MCH-001', 'CNC Lathe Alpha',      'CNC_LATHE',       'LINE-A', 'STN-01', 'Building 1, Bay 1',  3000, 45.0, NULL,   'HIGH',   '2020-03-15', '2025-06-01', 'RUNNING', 'Haas Automation', 'ST-30Y'),
    ('MCH-002', 'CNC Lathe Beta',       'CNC_LATHE',       'LINE-A', 'STN-02', 'Building 1, Bay 2',  3000, 45.0, NULL,   'HIGH',   '2021-01-10', '2025-09-15', 'RUNNING', 'Haas Automation', 'ST-30Y'),
    ('MCH-003', 'Hydraulic Press 1',    'HYDRAULIC_PRESS',  'LINE-A', 'STN-03', 'Building 1, Bay 3',  NULL, 60.0, 250.0,  'HIGH',   '2019-07-20', '2025-03-10', 'RUNNING', 'Schuler AG',      'MSD-400'),
    ('MCH-004', 'Conveyor Main',        'CONVEYOR',         'LINE-A', 'STN-04', 'Building 1, Bay 4',  1200, 15.0, NULL,   'MEDIUM', '2022-05-01', NULL,         'RUNNING', 'Siemens',         'CV-200'),
    ('MCH-005', 'CNC Mill Gamma',       'CNC_MILL',         'LINE-B', 'STN-01', 'Building 2, Bay 1',  4000, 55.0, NULL,   'HIGH',   '2020-11-01', '2025-04-20', 'RUNNING', 'DMG Mori',        'CMX-600V'),
    ('MCH-006', 'Robotic Welder 1',     'ROBOTIC_WELDER',   'LINE-B', 'STN-02', 'Building 2, Bay 2',  NULL, 80.0, NULL,   'HIGH',   '2021-08-15', '2025-07-01', 'RUNNING', 'Fanuc',           'ARC-120iC'),
    ('MCH-007', 'Assembly Robot 1',     'ASSEMBLY_ROBOT',   'LINE-B', 'STN-03', 'Building 2, Bay 3',  NULL, 35.0, NULL,   'MEDIUM', '2022-02-28', NULL,         'RUNNING', 'ABB',             'IRB-6700'),
    ('MCH-008', 'Grinding Station 1',   'GRINDER',          'LINE-B', 'STN-04', 'Building 2, Bay 4',  5000, 40.0, NULL,   'MEDIUM', '2020-06-10', '2025-01-15', 'RUNNING', 'Studer',          'S33'),
    ('MCH-009', 'Hydraulic Press 2',    'HYDRAULIC_PRESS',  'LINE-C', 'STN-01', 'Building 3, Bay 1',  NULL, 60.0, 250.0,  'HIGH',   '2018-12-01', '2024-11-20', 'RUNNING', 'Schuler AG',      'MSD-400'),
    ('MCH-010', 'Packaging Line 1',     'PACKAGING',        'LINE-C', 'STN-02', 'Building 3, Bay 2',  800,  20.0, NULL,   'LOW',    '2023-01-15', NULL,         'RUNNING', 'Bosch Packaging', 'CUC-3100'),
    ('MCH-011', 'Heat Treatment Oven',  'FURNACE',          'LINE-C', 'STN-03', 'Building 3, Bay 3',  NULL, 100.0, NULL,  'HIGH',   '2019-04-01', '2025-02-28', 'RUNNING', 'Ipsen',           'TFC-48'),
    ('MCH-012', 'Conveyor Secondary',   'CONVEYOR',         'LINE-C', 'STN-04', 'Building 3, Bay 4',  1200, 15.0, NULL,   'LOW',    '2023-06-01', NULL,         'RUNNING', 'Siemens',         'CV-200');

-- ============================================================
-- SENSORS (4 core signals per machine + extras)
-- ============================================================
INSERT INTO SENSORS (SENSOR_ID, MACHINE_ID, SIGNAL_TYPE, UNIT, MIN_THRESHOLD, MAX_THRESHOLD, WARNING_THRESHOLD, CRITICAL_THRESHOLD, SAMPLING_INTERVAL_SEC, INSTALL_DATE, IS_ACTIVE)
SELECT CONCAT(m.MACHINE_ID, '-', s.SIGNAL_TYPE), m.MACHINE_ID, s.SIGNAL_TYPE, s.UNIT,
       s.MIN_THRESHOLD, s.MAX_THRESHOLD, s.WARNING_THRESHOLD, s.CRITICAL_THRESHOLD, 60, m.INSTALL_DATE, TRUE
FROM MACHINES m
CROSS JOIN (
    SELECT 'VIBRATION'   AS SIGNAL_TYPE, 'mm/s'  AS UNIT, 0 AS MIN_THRESHOLD, 20 AS MAX_THRESHOLD, 7.0 AS WARNING_THRESHOLD, 12.0 AS CRITICAL_THRESHOLD
    UNION ALL SELECT 'TEMPERATURE', 'C', 10, 120, 75.0, 95.0
    UNION ALL SELECT 'CURRENT', 'A', 0, 150, NULL, NULL
    UNION ALL SELECT 'RPM', 'rpm', 0, 6000, NULL, NULL
) s
WHERE NOT (m.MACHINE_TYPE IN ('HYDRAULIC_PRESS','ROBOTIC_WELDER','ASSEMBLY_ROBOT','FURNACE','PACKAGING') AND s.SIGNAL_TYPE = 'RPM')
UNION ALL
SELECT CONCAT(m.MACHINE_ID, '-PRESSURE'), m.MACHINE_ID, 'PRESSURE', 'bar', 0, 300, 220, 260, 60, m.INSTALL_DATE, TRUE
FROM MACHINES m WHERE m.MACHINE_TYPE = 'HYDRAULIC_PRESS'
UNION ALL
SELECT CONCAT(m.MACHINE_ID, '-ACOUSTIC'), m.MACHINE_ID, 'ACOUSTIC', 'dB', 30, 110, 85, 95, 60, m.INSTALL_DATE, TRUE
FROM MACHINES m WHERE m.MACHINE_ID IN ('MCH-001','MCH-005','MCH-008');

-- ============================================================
-- SENSOR READINGS (135K+ rows, 30 days, 15-min intervals)
-- Seeded degradation: MCH-001 bearing, MCH-005 misalignment,
-- MCH-009 hydraulic, MCH-008 wheel imbalance, MCH-003 sensor fault
-- ============================================================
INSERT INTO SENSOR_READINGS (SENSOR_ID, MACHINE_ID, SIGNAL_TYPE, READING_VALUE, READING_TIMESTAMP, QUALITY_FLAG)
WITH time_spine AS (
    SELECT DATEADD('minute', SEQ4() * 15, '2026-09-01 00:00:00'::TIMESTAMP_NTZ) AS ts
    FROM TABLE(GENERATOR(ROWCOUNT => 2880))
),
sensor_list AS (
    SELECT s.SENSOR_ID, s.MACHINE_ID, s.SIGNAL_TYPE, s.UNIT, s.WARNING_THRESHOLD, s.CRITICAL_THRESHOLD,
           m.MACHINE_TYPE, m.RATED_RPM, m.RATED_CURRENT
    FROM SENSORS s JOIN MACHINES m ON s.MACHINE_ID = m.MACHINE_ID WHERE s.IS_ACTIVE = TRUE
),
base_readings AS (
    SELECT sl.SENSOR_ID, sl.MACHINE_ID, sl.SIGNAL_TYPE, sl.MACHINE_TYPE, sl.RATED_RPM, sl.RATED_CURRENT,
           t.ts AS READING_TIMESTAMP,
           DATEDIFF('hour', '2026-09-01', t.ts) / 720.0 AS degradation_progress,
           CASE WHEN HOUR(t.ts) BETWEEN 6 AND 14 THEN 1.1 WHEN HOUR(t.ts) BETWEEN 14 AND 22 THEN 1.0 ELSE 0.7 END AS shift_load,
           UNIFORM(-1.0::FLOAT, 1.0::FLOAT, RANDOM()) AS noise
    FROM sensor_list sl CROSS JOIN time_spine t
)
SELECT SENSOR_ID, MACHINE_ID, SIGNAL_TYPE,
    ROUND(CASE
        WHEN SIGNAL_TYPE = 'VIBRATION' THEN
            CASE WHEN MACHINE_ID = 'MCH-001' THEN 3.5 + (degradation_progress * 9.5) + (noise * 0.4 * shift_load) + (shift_load - 1) * 1.5
                 WHEN MACHINE_ID = 'MCH-005' THEN 3.0 + GREATEST(0, (degradation_progress - 0.5) * 16.0) + (noise * 0.5) + (shift_load - 1) * 1.2
                 WHEN MACHINE_ID = 'MCH-009' THEN 4.0 + GREATEST(0, (degradation_progress - 0.67) * 8.0) + (noise * 0.6) + (CASE WHEN degradation_progress > 0.67 AND MOD(HASH(READING_TIMESTAMP), 10) < 3 THEN 3.0 ELSE 0 END)
                 WHEN MACHINE_ID = 'MCH-008' THEN 4.5 + (degradation_progress * 5.0) + (noise * 0.5 * shift_load)
                 WHEN MACHINE_ID = 'MCH-006' THEN 3.0 + (shift_load - 0.7) * 3.0 + (noise * 0.3)
                 ELSE 2.5 + (shift_load - 0.7) * 1.5 + (noise * 0.4) END
        WHEN SIGNAL_TYPE = 'TEMPERATURE' THEN
            CASE WHEN MACHINE_ID = 'MCH-001' THEN 45.0 + (degradation_progress * 47.0) + (noise * 2.0) + (shift_load - 1) * 5.0
                 WHEN MACHINE_ID = 'MCH-005' THEN 42.0 + GREATEST(0, (degradation_progress - 0.5) * 70.0) + (noise * 2.5)
                 WHEN MACHINE_ID = 'MCH-011' THEN 850.0 + (noise * 15.0) + (shift_load - 0.7) * 30.0
                 WHEN MACHINE_ID = 'MCH-009' THEN 50.0 + GREATEST(0, (degradation_progress - 0.67) * 40.0) + (noise * 2.0)
                 ELSE 40.0 + (shift_load - 0.7) * 8.0 + (noise * 2.0) END
        WHEN SIGNAL_TYPE = 'CURRENT' THEN
            CASE WHEN MACHINE_ID = 'MCH-001' THEN (COALESCE(RATED_CURRENT,45) * 0.65) + (degradation_progress * COALESCE(RATED_CURRENT,45) * 0.30) + (noise * 1.5) + (shift_load - 1) * 5.0
                 WHEN MACHINE_ID = 'MCH-005' THEN (COALESCE(RATED_CURRENT,55) * 0.60) + GREATEST(0, (degradation_progress - 0.5) * COALESCE(RATED_CURRENT,55) * 0.40) + (noise * 2.0)
                 WHEN MACHINE_ID = 'MCH-006' THEN (COALESCE(RATED_CURRENT,80) * 0.70) + (shift_load - 0.7) * 15.0 + (noise * 3.0)
                 ELSE (COALESCE(RATED_CURRENT,40) * 0.60) + (shift_load - 0.7) * 5.0 + (noise * 1.5) END
        WHEN SIGNAL_TYPE = 'RPM' THEN
            CASE WHEN MACHINE_ID = 'MCH-001' THEN COALESCE(RATED_RPM,3000) * (0.85 - degradation_progress * 0.08) * shift_load + (noise * 20)
                 WHEN MACHINE_ID = 'MCH-005' THEN COALESCE(RATED_RPM,4000) * 0.80 * shift_load + (noise * (15 + GREATEST(0, (degradation_progress - 0.5) * 60)))
                 ELSE COALESCE(RATED_RPM,1500) * 0.80 * shift_load + (noise * 15) END
        WHEN SIGNAL_TYPE = 'PRESSURE' THEN
            CASE WHEN MACHINE_ID = 'MCH-009' THEN 200.0 - GREATEST(0, (degradation_progress - 0.67) * 60.0) + (noise * 5.0) + (shift_load - 0.7) * 10
                 ELSE 200.0 + (shift_load - 0.7) * 15.0 + (noise * 5.0) END
        WHEN SIGNAL_TYPE = 'ACOUSTIC' THEN
            CASE WHEN MACHINE_ID = 'MCH-001' THEN 65.0 + (degradation_progress * 25.0) + (noise * 2.0)
                 WHEN MACHINE_ID = 'MCH-005' THEN 60.0 + GREATEST(0, (degradation_progress - 0.5) * 30.0) + (noise * 2.0)
                 ELSE 60.0 + (shift_load - 0.7) * 5.0 + (noise * 2.0) END
        ELSE 0
    END, 2) AS READING_VALUE,
    READING_TIMESTAMP,
    CASE WHEN MACHINE_ID = 'MCH-003' AND SIGNAL_TYPE = 'VIBRATION' AND degradation_progress > 0.83 THEN 'STALE'
         WHEN UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.002 THEN 'SUSPECT'
         ELSE 'GOOD' END AS QUALITY_FLAG
FROM base_readings
WHERE NOT (SIGNAL_TYPE = 'RPM' AND MACHINE_TYPE IN ('HYDRAULIC_PRESS','ROBOTIC_WELDER','ASSEMBLY_ROBOT','FURNACE','PACKAGING'));

-- ============================================================
-- MACHINE EVENT LOGS
-- ============================================================
INSERT INTO MACHINE_EVENT_LOGS (MACHINE_ID, EVENT_TYPE, EVENT_CODE, EVENT_DESCRIPTION, SEVERITY, EVENT_TIMESTAMP, OPERATOR_ID)
VALUES
    ('MCH-001', 'ALARM',       'ALM-VIB-01',  'Vibration warning threshold exceeded',          'WARNING',  '2026-09-18 14:30:00', 'OP-003'),
    ('MCH-001', 'ALARM',       'ALM-VIB-01',  'Vibration warning threshold exceeded',          'WARNING',  '2026-09-22 09:15:00', 'OP-001'),
    ('MCH-001', 'ALARM',       'ALM-TEMP-01', 'Temperature approaching warning level',         'WARNING',  '2026-09-24 11:00:00', 'OP-002'),
    ('MCH-001', 'ALARM',       'ALM-VIB-02',  'Vibration critical threshold approaching',      'ERROR',    '2026-09-27 08:45:00', 'OP-001'),
    ('MCH-001', 'ALARM',       'ALM-CURR-01', 'Current draw above normal operating range',     'WARNING',  '2026-09-28 10:30:00', 'OP-003'),
    ('MCH-001', 'OVERLOAD',    'OVL-001',     'Motor overload detected - high current draw',   'ERROR',    '2026-09-29 14:00:00', 'OP-001'),
    ('MCH-005', 'ALARM',       'ALM-VIB-01',  'Vibration warning threshold exceeded',          'WARNING',  '2026-09-24 16:00:00', 'OP-004'),
    ('MCH-005', 'ALARM',       'ALM-VIB-02',  'Vibration critical threshold exceeded',         'CRITICAL', '2026-09-28 09:30:00', 'OP-004'),
    ('MCH-005', 'ALARM',       'ALM-TEMP-01', 'Temperature rising abnormally',                 'WARNING',  '2026-09-28 09:35:00', 'OP-004'),
    ('MCH-009', 'ALARM',       'ALM-PRS-01',  'Hydraulic pressure below normal',               'WARNING',  '2026-09-26 13:00:00', 'OP-006'),
    ('MCH-009', 'ALARM',       'ALM-TEMP-02', 'Hydraulic fluid temperature elevated',          'WARNING',  '2026-09-27 10:00:00', 'OP-006'),
    ('MCH-009', 'FAULT',       'FLT-HYD-01',  'Hydraulic system pressure anomaly',             'ERROR',    '2026-09-29 08:00:00', 'OP-006'),
    ('MCH-003', 'ALARM',       'ALM-SNS-01',  'Vibration sensor data stale - no update 30min', 'WARNING',  '2026-09-26 06:00:00', NULL),
    ('MCH-003', 'ERROR',       'ERR-SNS-02',  'Sensor communication lost - vibration channel', 'ERROR',    '2026-09-27 00:00:00', NULL),
    ('MCH-004', 'STARTUP',     'SYS-START',   'Machine started - shift begin',                 'INFO',     '2026-09-15 06:00:00', 'OP-002'),
    ('MCH-004', 'SHUTDOWN',    'SYS-STOP',    'Machine stopped - shift end',                   'INFO',     '2026-09-15 22:00:00', 'OP-002'),
    ('MCH-006', 'STATE_CHANGE','SC-HIGHLOAD',  'Entering high-load welding cycle',             'INFO',     '2026-09-20 08:00:00', 'OP-005'),
    ('MCH-006', 'STATE_CHANGE','SC-NORMAL',    'Returning to normal operating mode',           'INFO',     '2026-09-20 16:00:00', 'OP-005'),
    ('MCH-008', 'ALARM',       'ALM-VIB-01',  'Vibration slightly elevated - wheel wear',      'WARNING',  '2026-09-25 11:00:00', 'OP-004'),
    ('MCH-010', 'JAM',         'JAM-001',     'Packaging jam detected - auto-cleared',          'WARNING',  '2026-09-12 14:30:00', 'OP-007');

-- ============================================================
-- MAINTENANCE HISTORY (prior failures matching seeded scenarios)
-- ============================================================
INSERT INTO MAINTENANCE_HISTORY (MAINTENANCE_ID, MACHINE_ID, FAILURE_MODE, ROOT_CAUSE, ACTION_TAKEN, PARTS_REPLACED, REPAIR_DURATION_HRS, DOWNTIME_HRS, COST, TECHNICIAN_ID, MAINTENANCE_TYPE, STARTED_AT, COMPLETED_AT, NOTES)
VALUES
    ('MNT-001', 'MCH-001', 'BEARING_DEGRADATION', 'Spindle bearing wear due to prolonged high-load operation and inadequate lubrication interval',
     'Replaced spindle bearings, flushed lubrication system, recalibrated spindle alignment', 'Spindle Bearing Set (SKF-7210), Lubricant Cartridge',
     6.0, 8.0, 4500.00, 'TECH-001', 'CORRECTIVE', '2024-08-15 06:00:00', '2024-08-15 14:00:00',
     'Vibration trend showed gradual increase over 3 weeks before failure. Temperature also elevated.'),
    ('MNT-002', 'MCH-001', 'BEARING_DEGRADATION', 'Drive bearing end-of-life after extended runtime beyond recommended service interval',
     'Replaced drive bearings and seals', 'Drive Bearing (FAG-6208), Bearing Seal Kit',
     4.0, 6.0, 3200.00, 'TECH-002', 'PREVENTIVE', '2023-03-10 07:00:00', '2023-03-10 13:00:00', NULL),
    ('MNT-003', 'MCH-005', 'MISALIGNMENT', 'Spindle misalignment after heavy crash event caused frame flex',
     'Laser-aligned spindle, replaced coupling, verified runout', 'Flexible Coupling, Alignment Shims',
     8.0, 12.0, 6800.00, 'TECH-001', 'CORRECTIVE', '2024-02-20 06:00:00', '2024-02-20 18:00:00', NULL),
    ('MNT-004', 'MCH-009', 'HYDRAULIC_SEAL_FAILURE', 'Main cylinder seal degradation from contaminated hydraulic fluid',
     'Replaced cylinder seals, flushed hydraulic system, replaced fluid and filter', 'Cylinder Seal Kit, Hydraulic Filter, Hydraulic Fluid 20L',
     5.0, 7.0, 3800.00, 'TECH-003', 'CORRECTIVE', '2024-11-20 08:00:00', '2024-11-20 15:00:00', NULL),
    ('MNT-005', 'MCH-008', 'WHEEL_IMBALANCE', 'Grinding wheel imbalance after dressing tool wear',
     'Rebalanced grinding wheel, replaced dressing tool', 'Diamond Dressing Tool, Balance Weights',
     2.0, 3.0, 1200.00, 'TECH-002', 'CORRECTIVE', '2025-01-15 10:00:00', '2025-01-15 13:00:00', NULL),
    ('MNT-006', 'MCH-002', 'NONE', 'Scheduled preventive maintenance',
     'Lubrication, filter replacement, alignment check', 'Lubricant Cartridge, Air Filter',
     2.0, 3.0, 800.00, 'TECH-001', 'PREVENTIVE', '2025-09-15 06:00:00', '2025-09-15 09:00:00', NULL),
    ('MNT-007', 'MCH-003', 'NONE', 'Scheduled preventive maintenance',
     'Hydraulic fluid check, seal inspection, pressure test', 'Hydraulic Filter',
     1.5, 2.0, 600.00, 'TECH-003', 'PREVENTIVE', '2025-03-10 07:00:00', '2025-03-10 09:00:00', NULL),
    ('MNT-008', 'MCH-006', 'WIRE_FEED_JAM', 'Wire feed mechanism misalignment',
     'Realigned wire feed, cleaned nozzle, replaced contact tip', 'Contact Tip, Wire Guide',
     1.0, 1.5, 450.00, 'TECH-002', 'CORRECTIVE', '2025-05-10 14:00:00', '2025-05-10 15:30:00', NULL),
    ('MNT-009', 'MCH-011', 'HEATING_ELEMENT', 'Heating element degradation zone 3',
     'Replaced zone 3 heating element and thermocouple', 'Heating Element Z3, Thermocouple K-Type',
     4.0, 8.0, 5200.00, 'TECH-003', 'CORRECTIVE', '2025-02-28 06:00:00', '2025-02-28 14:00:00', NULL),
    ('MNT-010', 'MCH-004', 'BELT_WEAR', 'Conveyor belt edge wear from mistrack',
     'Adjusted tracking, replaced belt section', 'Conveyor Belt Section 2m',
     3.0, 4.0, 1800.00, 'TECH-001', 'CORRECTIVE', '2025-08-20 08:00:00', '2025-08-20 12:00:00', NULL);

-- ============================================================
-- PARTS INVENTORY
-- ============================================================
INSERT INTO PARTS_INVENTORY (PART_ID, PART_NAME, PART_CATEGORY, COMPATIBLE_MACHINE_TYPES, COMPATIBLE_COMPONENTS, QUANTITY_ON_HAND, REORDER_POINT, LEAD_TIME_DAYS, UNIT_COST, SUPPLIER, LAST_RESTOCKED_AT)
VALUES
    ('PRT-001', 'Spindle Bearing Set SKF-7210',  'BEARING',    'CNC_LATHE,CNC_MILL',     'SPINDLE',     3, 2, 5,  850.00, 'SKF Industrial',    '2026-08-15'),
    ('PRT-002', 'Drive Bearing FAG-6208',        'BEARING',    'CNC_LATHE,CNC_MILL',     'DRIVE',       4, 3, 4,  420.00, 'Schaeffler Group',  '2026-09-01'),
    ('PRT-003', 'Bearing Seal Kit',              'SEAL',       'CNC_LATHE,CNC_MILL',     'SPINDLE,DRIVE', 6, 4, 3, 180.00, 'SKF Industrial',   '2026-08-20'),
    ('PRT-004', 'Flexible Coupling',             'COUPLING',   'CNC_LATHE,CNC_MILL',     'SPINDLE',     2, 2, 7,  650.00, 'Rexnord',           '2026-07-10'),
    ('PRT-005', 'Alignment Shim Kit',            'ALIGNMENT',  'CNC_LATHE,CNC_MILL',     'SPINDLE',     8, 5, 2,   45.00, 'General Supply',    '2026-09-10'),
    ('PRT-006', 'Cylinder Seal Kit',             'SEAL',       'HYDRAULIC_PRESS',         'CYLINDER',    2, 2, 6,  380.00, 'Parker Hannifin',   '2026-08-01'),
    ('PRT-007', 'Hydraulic Filter',              'FILTER',     'HYDRAULIC_PRESS',         'HYDRAULIC',   5, 3, 3,   95.00, 'Parker Hannifin',   '2026-09-05'),
    ('PRT-008', 'Hydraulic Fluid 20L',           'FLUID',      'HYDRAULIC_PRESS',         'HYDRAULIC',   4, 2, 2,  120.00, 'Mobil Industrial',  '2026-09-15'),
    ('PRT-009', 'Diamond Dressing Tool',         'TOOLING',    'GRINDER',                 'WHEEL',       3, 2, 10, 320.00, 'Norton Abrasives',  '2026-07-20'),
    ('PRT-010', 'Grinding Wheel Balance Weights','TOOLING',    'GRINDER',                 'WHEEL',      10, 5, 3,   25.00, 'General Supply',    '2026-09-01'),
    ('PRT-011', 'Lubricant Cartridge',           'CONSUMABLE', 'CNC_LATHE,CNC_MILL,GRINDER','ALL',      12, 8, 2,   35.00, 'Shell Industrial',  '2026-09-20'),
    ('PRT-012', 'Contact Tip (Welding)',         'CONSUMABLE', 'ROBOTIC_WELDER',          'WIRE_FEED',  20, 10, 2,  12.00, 'Lincoln Electric',  '2026-09-10'),
    ('PRT-013', 'Conveyor Belt Section 2m',      'BELT',       'CONVEYOR',                'BELT',        1, 1, 14, 900.00, 'Continental',       '2026-06-15'),
    ('PRT-014', 'Heating Element Zone',          'HEATING',    'FURNACE',                 'HEATING',     1, 1, 21,2100.00, 'Kanthal',           '2026-05-01'),
    ('PRT-015', 'Thermocouple K-Type',           'SENSOR',     'FURNACE,HYDRAULIC_PRESS', 'TEMPERATURE', 6, 4, 3,   75.00, 'Omega Engineering', '2026-09-01');

-- ============================================================
-- PRODUCTION QUALITY (30 days x 3 shifts x 9 machines)
-- ============================================================
INSERT INTO PRODUCTION_QUALITY (MACHINE_ID, SHIFT, PRODUCTION_DATE, PLANNED_UNITS, ACTUAL_UNITS, GOOD_UNITS, REJECTED_UNITS, CYCLE_TIME_SEC, IDEAL_CYCLE_TIME_SEC, PLANNED_RUNTIME_HRS, ACTUAL_RUNTIME_HRS, DOWNTIME_HRS, QUALITY_DEVIATION, PRODUCTION_STATUS)
SELECT m.MACHINE_ID, s.SHIFT, d.PRODUCTION_DATE,
    CASE WHEN m.MACHINE_TYPE IN ('CNC_LATHE','CNC_MILL') THEN 120 WHEN m.MACHINE_TYPE = 'GRINDER' THEN 80 WHEN m.MACHINE_TYPE = 'HYDRAULIC_PRESS' THEN 200 WHEN m.MACHINE_TYPE = 'PACKAGING' THEN 500 ELSE 100 END,
    ROUND(CASE WHEN m.MACHINE_TYPE IN ('CNC_LATHE','CNC_MILL') THEN 120 WHEN m.MACHINE_TYPE = 'GRINDER' THEN 80 WHEN m.MACHINE_TYPE = 'HYDRAULIC_PRESS' THEN 200 WHEN m.MACHINE_TYPE = 'PACKAGING' THEN 500 ELSE 100 END
        * (CASE WHEN m.MACHINE_ID='MCH-001' THEN GREATEST(0.70, 1.0 - DATEDIFF('day','2026-09-01',d.PRODUCTION_DATE)/30.0 * 0.30)
                WHEN m.MACHINE_ID='MCH-005' AND d.PRODUCTION_DATE > '2026-09-15' THEN GREATEST(0.65, 1.0 - DATEDIFF('day','2026-09-15',d.PRODUCTION_DATE)/15.0 * 0.35)
                ELSE 0.95 + UNIFORM(-0.05::FLOAT, 0.05::FLOAT, RANDOM()) END)
        * (CASE WHEN s.SHIFT='DAY' THEN 1.0 WHEN s.SHIFT='SWING' THEN 0.95 ELSE 0.85 END)) AS ACTUAL_UNITS,
    NULL, NULL,
    CASE WHEN m.MACHINE_TYPE IN ('CNC_LATHE','CNC_MILL') THEN 45.0 WHEN m.MACHINE_TYPE = 'HYDRAULIC_PRESS' THEN 18.0 WHEN m.MACHINE_TYPE = 'GRINDER' THEN 60.0 ELSE 30.0 END + UNIFORM(-2::FLOAT, 5::FLOAT, RANDOM()),
    CASE WHEN m.MACHINE_TYPE IN ('CNC_LATHE','CNC_MILL') THEN 42.0 WHEN m.MACHINE_TYPE = 'HYDRAULIC_PRESS' THEN 16.0 WHEN m.MACHINE_TYPE = 'GRINDER' THEN 55.0 ELSE 28.0 END,
    8.0,
    8.0 - CASE WHEN m.MACHINE_ID='MCH-001' THEN GREATEST(0, DATEDIFF('day','2026-09-01',d.PRODUCTION_DATE)/30.0 * 1.5) ELSE UNIFORM(0::FLOAT, 0.5::FLOAT, RANDOM()) END,
    CASE WHEN m.MACHINE_ID='MCH-001' THEN GREATEST(0, DATEDIFF('day','2026-09-01',d.PRODUCTION_DATE)/30.0 * 1.5) ELSE UNIFORM(0::FLOAT, 0.5::FLOAT, RANDOM()) END,
    0,
    CASE WHEN m.MACHINE_ID='MCH-001' AND d.PRODUCTION_DATE > '2026-09-25' THEN 'DEGRADED'
         WHEN m.MACHINE_ID='MCH-005' AND d.PRODUCTION_DATE > '2026-09-25' THEN 'DEGRADED'
         WHEN m.MACHINE_ID='MCH-009' AND d.PRODUCTION_DATE > '2026-09-27' THEN 'DEGRADED'
         ELSE 'NORMAL' END
FROM MACHINES m
CROSS JOIN (SELECT 'DAY' AS SHIFT UNION ALL SELECT 'SWING' UNION ALL SELECT 'NIGHT') s
CROSS JOIN (SELECT DATEADD('day', SEQ4(), '2026-09-01')::DATE AS PRODUCTION_DATE FROM TABLE(GENERATOR(ROWCOUNT => 30))) d
WHERE m.MACHINE_TYPE NOT IN ('FURNACE','ASSEMBLY_ROBOT','ROBOTIC_WELDER');

-- Fix good/rejected units
UPDATE PRODUCTION_QUALITY SET
    REJECTED_UNITS = GREATEST(1, ROUND(ACTUAL_UNITS * UNIFORM(0.01::FLOAT, 0.03::FLOAT, RANDOM())));
UPDATE PRODUCTION_QUALITY SET
    REJECTED_UNITS = GREATEST(1, ROUND(ACTUAL_UNITS * (0.03 + DATEDIFF('day','2026-09-20', PRODUCTION_DATE)/10.0 * 0.07)))
    WHERE MACHINE_ID = 'MCH-001' AND PRODUCTION_DATE > '2026-09-20';
UPDATE PRODUCTION_QUALITY SET
    REJECTED_UNITS = GREATEST(1, ROUND(ACTUAL_UNITS * (0.04 + DATEDIFF('day','2026-09-22', PRODUCTION_DATE)/8.0 * 0.08)))
    WHERE MACHINE_ID = 'MCH-005' AND PRODUCTION_DATE > '2026-09-22';
UPDATE PRODUCTION_QUALITY SET
    GOOD_UNITS = ACTUAL_UNITS - REJECTED_UNITS,
    QUALITY_DEVIATION = ROUND(REJECTED_UNITS::FLOAT / NULLIF(ACTUAL_UNITS, 0), 4);

-- ============================================================
-- SHIFT LOGS (Operator observations)
-- ============================================================
INSERT INTO SHIFT_LOGS (MACHINE_ID, OPERATOR_ID, SHIFT, OBSERVATION_TYPE, OBSERVATION_DETAIL, SEVERITY, OBSERVED_AT)
VALUES
    ('MCH-001', 'OP-001', 'DAY',   'NOISE',     'Slight grinding noise from spindle area during high-speed operation',    'LOW',    '2026-09-16 10:00:00'),
    ('MCH-001', 'OP-003', 'SWING', 'VIBRATION', 'Noticeable vibration increase when cutting steel at full depth',         'MEDIUM', '2026-09-20 18:00:00'),
    ('MCH-001', 'OP-001', 'DAY',   'NOISE',     'Grinding noise more pronounced, audible from 2m away',                  'MEDIUM', '2026-09-24 09:30:00'),
    ('MCH-001', 'OP-002', 'NIGHT', 'VIBRATION', 'Strong vibration felt on machine body, parts showing chatter marks',    'HIGH',   '2026-09-27 02:00:00'),
    ('MCH-001', 'OP-001', 'DAY',   'SMELL',     'Slight burning smell from spindle housing area',                        'HIGH',   '2026-09-29 11:00:00'),
    ('MCH-005', 'OP-004', 'DAY',   'NOISE',     'Unusual whining sound at high RPM',                                     'LOW',    '2026-09-18 14:00:00'),
    ('MCH-005', 'OP-004', 'DAY',   'VIBRATION', 'Tool chatter during face milling, vibration at spindle',                'MEDIUM', '2026-09-25 10:00:00'),
    ('MCH-005', 'OP-004', 'DAY',   'VISUAL',    'Surface finish degrading, visible tool marks on machined parts',        'HIGH',   '2026-09-28 08:00:00'),
    ('MCH-009', 'OP-006', 'DAY',   'LEAK',      'Small hydraulic fluid seepage near main cylinder base',                 'MEDIUM', '2026-09-22 11:00:00'),
    ('MCH-009', 'OP-006', 'DAY',   'NOISE',     'Hydraulic pump sounds louder than usual, slight whine',                 'MEDIUM', '2026-09-26 09:00:00'),
    ('MCH-009', 'OP-006', 'DAY',   'VISUAL',    'Hydraulic fluid level dropping faster than normal between checks',      'HIGH',   '2026-09-28 15:00:00'),
    ('MCH-003', 'OP-002', 'NIGHT', 'OTHER',     'Vibration display on HMI shows constant value, suspect sensor frozen',  'MEDIUM', '2026-09-26 03:00:00'),
    ('MCH-006', 'OP-005', 'DAY',   'NOISE',     'Slightly louder during high-duty welding cycle, seems normal for load', 'LOW',    '2026-09-20 12:00:00'),
    ('MCH-010', 'OP-007', 'SWING', 'OTHER',     'Package alignment slightly off, adjusted guide rail',                   'LOW',    '2026-09-15 16:00:00');

-- ============================================================
-- TOOLING CHANGES
-- ============================================================
INSERT INTO TOOLING_CHANGES (MACHINE_ID, TOOL_NAME, CHANGE_REASON, PREVIOUS_TOOL_LIFE_HRS, NEW_TOOL_INSTALLED, PRODUCTION_CONTEXT, CHANGED_AT, OPERATOR_ID)
VALUES
    ('MCH-001', 'Carbide Insert CNMG-120408', 'Scheduled wear replacement',   180.5, TRUE, 'Running steel alloy job batch 2026-Q3', '2026-09-05 07:00:00', 'OP-001'),
    ('MCH-001', 'Carbide Insert CNMG-120408', 'Early wear - chatter detected', 95.0, TRUE, 'Surface finish issues detected',         '2026-09-22 14:00:00', 'OP-003'),
    ('MCH-002', 'Carbide Insert CNMG-120408', 'Scheduled wear replacement',   200.0, TRUE, 'Normal production cycle',                '2026-09-10 08:00:00', 'OP-001'),
    ('MCH-005', 'End Mill 16mm 4-Flute',      'Tool breakage',                 45.0, TRUE, 'Suspected vibration-induced breakage',   '2026-09-26 10:00:00', 'OP-004'),
    ('MCH-008', 'Grinding Wheel Norton-SG',    'Scheduled dressing/true',      320.0, TRUE, 'Wheel surface glazing observed',         '2026-09-15 06:00:00', 'OP-004');

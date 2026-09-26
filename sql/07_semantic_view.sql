-- =============================================================================
-- IoT Predictive Maintenance Platform
-- 07: Semantic View for Cortex Analyst
-- =============================================================================

USE DATABASE IOT_PREDICTIVE_MAINTENANCE;
USE SCHEMA APP;

CREATE OR REPLACE SEMANTIC VIEW IOT_MAINTENANCE_VIEW
  TABLES (
    machine_health AS IOT_PREDICTIVE_MAINTENANCE.STAGING.CROSS_MACHINE_HEALTH
      PRIMARY KEY (MACHINE_ID)
      COMMENT = 'Current health scores for all 50 machines',
    anomalies AS IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.DETECTED_ANOMALIES
      PRIMARY KEY (ANOMALY_ID)
      COMMENT = 'ML-detected anomalies with severity',
    work_orders AS IOT_PREDICTIVE_MAINTENANCE.RAW.WORK_ORDERS
      PRIMARY KEY (WORK_ORDER_ID)
      COMMENT = 'AI-drafted maintenance work orders',
    production AS IOT_PREDICTIVE_MAINTENANCE.STAGING.PERFORMANCE_BASELINE
      COMMENT = 'Per-shift production quality metrics'
  )
  RELATIONSHIPS (
    anomalies_to_health AS anomalies (MACHINE_ID) REFERENCES machine_health,
    work_orders_to_health AS work_orders (MACHINE_ID) REFERENCES machine_health,
    production_to_health AS production (MACHINE_ID) REFERENCES machine_health
  )
  FACTS (
    machine_health.health_score_fact AS HEALTH_SCORE COMMENT = 'Health score 0-100',
    machine_health.anomalies_24h AS TOTAL_ANOMALIES_24H COMMENT = 'Anomaly count last 24h',
    machine_health.concern_rank_fact AS CONCERN_RANK COMMENT = 'Rank 1 most concerning',
    anomalies.vibration_reading AS SENSOR_VALUE COMMENT = 'Anomalous vibration value',
    anomalies.anomaly_confidence AS ANOMALY_SCORE COMMENT = 'ML confidence 0 to 1',
    work_orders.est_downtime AS ESTIMATED_DOWNTIME_HOURS COMMENT = 'Estimated downtime hours',
    production.parts_produced_fact AS PARTS_PRODUCED COMMENT = 'Parts produced per shift',
    production.parts_rejected_fact AS PARTS_REJECTED COMMENT = 'Parts rejected per shift',
    production.reject_rate AS REJECT_RATE_PCT COMMENT = 'Rejection rate pct',
    production.cycle_time AS AVG_CYCLE_TIME_SEC COMMENT = 'Average cycle time seconds'
  )
  DIMENSIONS (
    machine_health.machine_id AS machine_health.MACHINE_ID COMMENT = 'Machine ID MCH-0001 to MCH-0050',
    machine_health.machine_type AS machine_health.MACHINE_TYPE COMMENT = 'Machine category',
    machine_health.health_status AS machine_health.HEALTH_STATUS COMMENT = 'CRITICAL WARNING FAIR GOOD',
    anomalies.severity AS anomalies.SEVERITY COMMENT = 'CRITICAL HIGH MEDIUM LOW',
    anomalies.reading_timestamp AS anomalies.READING_TIMESTAMP COMMENT = 'When anomaly occurred',
    anomalies.anomaly_status AS anomalies.STATUS COMMENT = 'NEW or TRIAGED',
    work_orders.wo_status AS work_orders.STATUS COMMENT = 'DRAFT ASSIGNED IN_PROGRESS RESOLVED',
    work_orders.wo_priority AS work_orders.PRIORITY COMMENT = 'Work order priority',
    work_orders.technician AS work_orders.ASSIGNED_TECHNICIAN_ID COMMENT = 'Assigned technician',
    production.shift_date AS production.SHIFT_DATE COMMENT = 'Production shift date',
    production.perf_status AS production.PERFORMANCE_STATUS COMMENT = 'HEALTHY WARNING DEGRADED'
  )
  METRICS (
    machine_health.avg_health AS AVG(machine_health.HEALTH_SCORE) COMMENT = 'Average health score',
    anomalies.total_anomalies AS COUNT(anomalies.ANOMALY_ID) COMMENT = 'Total anomalies',
    work_orders.open_orders AS COUNT(work_orders.WORK_ORDER_ID) COMMENT = 'Total work orders',
    production.avg_reject AS AVG(production.REJECT_RATE_PCT) COMMENT = 'Average rejection rate'
  )
  COMMENT = 'IoT Predictive Maintenance platform';

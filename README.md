# IoT Predictive Maintenance Platform

End-to-end predictive maintenance system built entirely on Snowflake using Cortex ML anomaly detection, AI-generated work orders, dynamic tables, and a Streamlit dashboard -- all developed via Cortex Code (CoCo) CLI.

---

## Architecture

```
  RAW LAYER (13 tables)           STAGING (5 Dynamic Tables)        ANALYTICS + ML
  ========================        ============================      ==========================
  SENSOR_READINGS (288K)  ------> SENSOR_READINGS_CLEAN (283K)
  SENSORS (400)           ---/       |
  MACHINES (50)           --/        +--> MACHINE_HEALTH_FEATURES (283K)
                                     |       |
  PRODUCTION_QUALITY (13.5K) ------> PERFORMANCE_BASELINE (13.5K)   DETECTED_ANOMALIES (3.2K)
                                     |       |                      FAILURE_FORECASTS (700)
  SHIFT_LOGS (4.1K)       --------> |       +--> CROSS_MACHINE_    TRIAGE_QUEUE (1.7K)
  POWER_QUALITY_LOGS (12.6K) -----> |            HEALTH (50)
  MAINTENANCE_HISTORY (238) ------> ANOMALY_CONTEXT (5.3K) <-------+

  ORCHESTRATION                     APP LAYER
  ==========================        ==========================
  Skill 1: Context Assembly --+     IOT_MAINTENANCE_VIEW (Semantic View)
  Skill 2: WO Drafting (AI) -+--->  IOT_MAINTENANCE_DASHBOARD (Streamlit)
  Skill 3: Dispatch + Email --+
  MAINTENANCE_PIPELINE_TASK (5 min)

  ML MODELS (8 total)
  ==========================
  7 x ANOMALY_DETECTION (per machine class + combined)
  1 x VIBRATION_FORECAST (14-day predictions)
  CORTEX.COMPLETE (llama3.1-70b) for severity + work order drafting
```

---

## Features

- **ML Anomaly Detection** -- 7 Snowflake Cortex ML anomaly detection models (one per machine class + combined) trained with supervised labels and proper 60/30-day train/test split.
- **14-Day Vibration Forecasting** -- Cortex ML Forecast model predicts vibration trends per machine with 95% confidence intervals.
- **AI-Generated Work Orders** -- Cortex AI COMPLETE (llama3.1-70b) drafts work order titles, problem descriptions, and recommended maintenance actions using context from 6 data domains.
- **Dynamic Table Pipeline** -- 5-layer auto-refreshing pipeline: sensor cleaning/normalization, rolling health features (1h/6h/24h), performance baselines, composite health scores, and anomaly context enrichment.
- **Email Alerting** -- Automated email notifications for CRITICAL and HIGH severity anomalies dispatched via SYSTEM$SEND_EMAIL.
- **Streamlit Dashboard** -- 7-view interactive dashboard deployed in Snowflake: Factory Floor Overview, Machine Detail, Anomaly Feed, Work Order Management, Maintenance History, Business Continuity, Cross-Machine Health.
- **Semantic View + Cortex Analyst** -- Natural language querying of maintenance data through a structured semantic view with facts, dimensions, metrics, and relationships.

---

## Prerequisites

- Snowflake account with **ACCOUNTADMIN** role
- **Cortex ML** enabled (Anomaly Detection and Forecast)
- **Cortex AI** enabled (AI_COMPLETE with llama3.1-70b)
- Email notification support (SYSTEM$SEND_EMAIL)
- Warehouse capacity (scripts create `IOT_ML_WH` Medium)

---

## Quick Start

Run the SQL scripts in order from Snowsight, SnowSQL, or CoCo CLI:

```
sql/01_setup.sql              -- Database, schemas, warehouse
sql/02_raw_tables.sql         -- 13 RAW table + 2 analytics table DDLs
sql/03_data_generation.sql    -- Synthetic data (320K+ rows across 11 tables)
sql/04_dynamic_tables.sql     -- Change tracking + 5 dynamic tables
sql/05_ml_pipeline.sql        -- Training views, 8 ML models, inference, severity classification
sql/06_orchestration.sql      -- 3 stored procedures, notification integration, orchestration task
sql/07_semantic_view.sql      -- Cortex Analyst semantic view
sql/08_streamlit_deploy.sql   -- Streamlit app stage + deployment
sql/09_validation.sql         -- End-to-end validation queries
```

For the Streamlit deployment (step 8), upload the app file first:

```sql
PUT 'file://<local-path>/streamlit/streamlit_app.py' @IOT_PREDICTIVE_MAINTENANCE.APP.STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
```

After running all scripts, activate the pipeline:

```sql
ALTER TASK IOT_PREDICTIVE_MAINTENANCE.ORCHESTRATION.MAINTENANCE_PIPELINE_TASK RESUME;
```

---

## Folder Structure

```
iot-predictive-maintenance/
  README.md
  .gitignore
  sql/
    01_setup.sql                -- Database, schemas, warehouse
    02_raw_tables.sql           -- All table DDLs (RAW + ANALYTICS)
    03_data_generation.sql      -- Synthetic data generation
    04_dynamic_tables.sql       -- Dynamic table pipeline
    05_ml_pipeline.sql          -- ML model training + inference
    06_orchestration.sql        -- Agentic SPs + task + notifications
    07_semantic_view.sql        -- Cortex Analyst semantic view
    08_streamlit_deploy.sql     -- Streamlit deployment
    09_validation.sql           -- E2E validation
  streamlit/
    streamlit_app.py            -- 7-view Streamlit dashboard
  docs/
    e2e_workflow.txt            -- Detailed CoCo CLI execution log
```

---

## Database Schema Overview

| Schema | Purpose | Key Objects |
|--------|---------|-------------|
| RAW | Landing zone for sensor, ERP, and human context data | 13 tables (SENSOR_READINGS, MACHINES, WORK_ORDERS, etc.) |
| STAGING | Auto-refreshing transformation pipeline | 5 dynamic tables (SENSOR_READINGS_CLEAN, MACHINE_HEALTH_FEATURES, PERFORMANCE_BASELINE, CROSS_MACHINE_HEALTH, + ANOMALY_CONTEXT in ANALYTICS) |
| ANALYTICS | ML results, triage queue, forecasts | DETECTED_ANOMALIES, TRIAGE_QUEUE, FAILURE_FORECASTS, ANOMALY_CONTEXT (DT) |
| ML_MODELS | Cortex ML objects and training views | 7 anomaly detection models, 1 forecast model, 13 views |
| ORCHESTRATION | Automation and procedures | 3 stored procedures, 1 scheduled task |
| APP | User-facing layer | 1 semantic view, 1 Streamlit app, 1 stage |

---

## Object Inventory

| Type | Count | Details |
|------|-------|---------|
| RAW tables | 13 | 11 populated with synthetic data, 2 populated by pipeline |
| Dynamic tables | 5 | All ACTIVE, FULL refresh mode |
| ML models | 8 | 7 anomaly detection + 1 vibration forecast |
| Stored procedures | 3 | Context assembly, WO drafting, dispatch/notify |
| Tasks | 1 | 5-minute pipeline (created SUSPENDED) |
| Notification integrations | 1 | Email (SYSTEM$SEND_EMAIL) |
| Semantic views | 1 | 4 tables, 10 facts, 11 dimensions, 4 metrics |
| Streamlit apps | 1 | 7-view dashboard |

---

## Key Design Decisions

- **Dynamic tables over explicit streams** -- DTs handle CDC natively via change tracking, eliminating the need for separate stream objects. Intermediate DTs use TARGET_LAG = DOWNSTREAM; only leaf DTs have time-based lag.
- **60/30-day train/test split** -- Anomaly detection models trained on first 60 days, inference on last 30 days, avoiding the timestamp overlap error inherent in Snowflake ML's DETECT_ANOMALIES.
- **AI_COMPLETE for work order drafting** -- LLM (llama3.1-70b) generates contextual titles, problem descriptions, and recommended actions rather than templated text, producing maintenance-relevant output.
- **Composite health scoring** -- Machine health uses a penalty-based 0-100 score (Z-score deviation, anomaly count, threshold breaches, variability) rather than single-metric thresholds.
- **Streamlit over React/SPCS** -- Chosen for native Snowflake integration and zero-dependency deployment via SQL (CREATE STREAMLIT), avoiding the need for the snow CLI and container infrastructure.

---

## Operational Commands

```sql
-- Activate the automated pipeline (runs every 5 minutes)
ALTER TASK IOT_PREDICTIVE_MAINTENANCE.ORCHESTRATION.MAINTENANCE_PIPELINE_TASK RESUME;

-- Suspend the pipeline
ALTER TASK IOT_PREDICTIVE_MAINTENANCE.ORCHESTRATION.MAINTENANCE_PIPELINE_TASK SUSPEND;

-- Run the pipeline manually (one-shot)
CALL IOT_PREDICTIVE_MAINTENANCE.ORCHESTRATION.SKILL1_ASSEMBLE_CONTEXT();
CALL IOT_PREDICTIVE_MAINTENANCE.ORCHESTRATION.SKILL2_DRAFT_WORK_ORDERS();
CALL IOT_PREDICTIVE_MAINTENANCE.ORCHESTRATION.SKILL3_DISPATCH_AND_NOTIFY();

-- Inject a test anomaly
INSERT INTO IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.DETECTED_ANOMALIES
  (ANOMALY_ID, MACHINE_ID, MACHINE_TYPE, READING_TIMESTAMP, SENSOR_TYPE,
   SENSOR_VALUE, IS_ANOMALY, ANOMALY_SCORE, SEVERITY, HEALTH_SCORE,
   HEALTH_STATUS, STATUS, CREATED_AT)
VALUES ('TEST-' || UUID_STRING(), 'MCH-0043', 'CONVEYOR',
  CURRENT_TIMESTAMP(), 'VIBRATION', 7.8, TRUE, 0.997, 'CRITICAL',
  32.0, 'CRITICAL', 'NEW', CURRENT_TIMESTAMP());

-- Query via Cortex Analyst
SELECT * FROM SEMANTIC_VIEW(
  IOT_PREDICTIVE_MAINTENANCE.APP.IOT_MAINTENANCE_VIEW
  FACTS machine_health.health_score_fact
  WHERE machine_health.health_status = 'CRITICAL'
);

-- Check dynamic table health
SHOW DYNAMIC TABLES IN DATABASE IOT_PREDICTIVE_MAINTENANCE;
```

---

## Built With

- **Snowflake Dynamic Tables** -- Declarative, auto-refreshing data pipeline
- **Snowflake Cortex ML** -- ANOMALY_DETECTION and FORECAST models
- **Snowflake Cortex AI** -- COMPLETE function with llama3.1-70b for severity classification and work order generation
- **Streamlit-in-Snowflake** -- Native dashboard deployment
- **Cortex Analyst Semantic Views** -- Natural language data access
- **Snowflake Tasks** -- Scheduled pipeline orchestration
- **Snowflake Email Notifications** -- SYSTEM$SEND_EMAIL for alerting

---

## Data Model

The platform simulates a 50-machine factory floor across 6 machine types over 90 days (June-August 2026). Five machines are seeded with degradation-to-failure patterns:

| Machine | Type | Failure Day | Health Score |
|---------|------|-------------|-------------|
| MCH-0003 | CONVEYOR | Day 60 | 39.2 (CRITICAL) |
| MCH-0012 | COMPRESSOR | Day 45 | 39.4 (CRITICAL) |
| MCH-0025 | CNC_LATHE | Day 70 | 38.6 (CRITICAL) |
| MCH-0031 | CNC_LATHE | Day 55 | 39.0 (CRITICAL) |
| MCH-0047 | PUMP | Day 65 | 37.7 (CRITICAL) |

---

## License

MIT

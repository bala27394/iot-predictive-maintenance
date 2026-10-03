# IOT Predictive Maintenance Command Center

Snowflake-native predictive maintenance solution built for hackathon demonstration.
Converges OT sensor signals with ERP/maintenance and production context to predict failures,
explain risk, automate governed work orders, and show OEE / production impact.

Built entirely using CoCo CLI across planning, development, execution, and testing.

---

## Architecture

```
Database: IOT_PREDICTIVE_MAINTENANCE
Warehouse: IOT_PM_WH (MEDIUM)

Schemas:
  RAW            - OT telemetry, machine events, ERP/maintenance, production, human data
  STAGING        - Cleansing, normalization, operating-state context, feature pipelines
  ANALYTICS      - Health, incidents, predictions, RCA evidence, OEE, business impact
  ML_MODELS      - Cortex ML model objects and metadata (reserved)
  ORCHESTRATION  - Tasks, stored procedures, workflow state, notifications
  APP            - Semantic views, Streamlit application, supporting objects
```

## Quick Start

Run SQL files in order against a Snowflake account:

| Step | File | What it creates |
|------|------|-----------------|
| 1 | `sql/01_setup.sql` | Database, 6 schemas, warehouse |
| 2 | `sql/02_raw_tables.sql` | 10 RAW table definitions |
| 3 | `sql/03_data_generation.sql` | Synthetic data: 135K+ sensor readings, 12 machines, 30 days |
| 4 | `sql/04_dynamic_tables.sql` | 6 Dynamic Tables (feature pipeline) |
| 5 | `sql/05_ml_pipeline.sql` | Anomaly detection, failure forecasts, assessments, incidents |
| 6 | `sql/06_orchestration.sql` | Work-order procedures, notifications, scheduled task |
| 7 | `sql/07_semantic_view.sql` | OEE metrics, production impact, command center views |
| 8 | `sql/08_streamlit_deploy.sql` | Deploy Streamlit app to Snowflake |
| 9 | `sql/09_validation.sql` | End-to-end validation queries |

## Streamlit Command Center

8-view application deployed as `APP.PREDICTIVE_MAINTENANCE_COMMAND_CENTER`:

1. **Factory Overview** - Fleet health gauges, OEE trend, station summary, machine cards
2. **Incident Triage** - Grouped incidents, severity/status filters, acknowledge/draft WO/false-positive actions
3. **Machine Detail** - Per-machine sensor trends, failure forecast, "why this alert" evidence panel
4. **Root-Cause Copilot** - Evidence summary, sensor analysis, historical similar cases, maintenance history
5. **Work Orders** - Full lifecycle: draft/approve/reject/resolve with post-repair feedback capture
6. **OEE & Production** - Availability/Performance/Quality/OEE metrics, trends, production impact
7. **Maintenance History** - Failure mode distribution, cost analysis, repeat failure patterns
8. **Data Trust** - Sensor freshness, DT pipeline status, model versions, confidence distribution

## Data Pipeline

```
RAW.SENSOR_READINGS
    -> STAGING.SENSOR_READINGS_CLEAN (quality, thresholds, spikes)
        -> STAGING.MACHINE_HEALTH_FEATURES (1h/6h/24h rolling aggregates)
            -> STAGING.CROSS_MACHINE_HEALTH (fleet health scores 0-100)
                -> ANALYTICS.MAINTENANCE_CONTEXT (enriched with history, operator obs, parts)

RAW.MACHINE_EVENT_LOGS -> STAGING.MACHINE_OPERATING_CONTEXT (state, load, suppression)
RAW.PRODUCTION_QUALITY -> STAGING.PERFORMANCE_BASELINE (shift/7-day comparisons)
```

## Key Features

- **Multi-sensor anomaly detection** - Vibration, temperature, current, RPM, pressure
- **Failure forecasting** - Confidence-qualified RUL estimates with fallback states
- **Incident correlation** - Groups repeated anomalies into single incidents
- **Transparent priority scoring** - Health risk + criticality + production impact + RUL + confidence
- **Governed work-order automation** - Human approval gates, duplicate prevention
- **OEE calculations** - Tied directly to maintenance risk and production impact
- **Post-repair feedback** - Captures actual root cause for validation

## Seeded Demo Scenarios

| Machine | Scenario | Pattern |
|---------|----------|---------|
| MCH-001 | Bearing degradation | 30-day gradual vibration+temp+current rise |
| MCH-005 | Spindle misalignment | Starts day 15, steep vibration+temp rise |
| MCH-009 | Hydraulic seal failure | Pressure drop + temp rise after day 20 |
| MCH-008 | Grinding wheel imbalance | Slow vibration rise over 30 days |
| MCH-003 | Sensor fault | Vibration sensor goes STALE after day 25 |
| MCH-006 | High-load normal operation | False-positive test (expected behavior) |

## Project Structure

```
iot-predictive-maintenance/
  sql/
    01_setup.sql              - Foundation DDL
    02_raw_tables.sql         - 10 RAW table schemas
    03_data_generation.sql    - Synthetic data with degradation scenarios
    04_dynamic_tables.sql     - 6 Dynamic Tables (feature pipeline)
    05_ml_pipeline.sql        - ML: anomalies, forecasts, assessments, incidents
    06_orchestration.sql      - Work-order SPs, notifications, task
    07_semantic_view.sql      - OEE views, command center views
    08_streamlit_deploy.sql   - Streamlit deployment
    09_validation.sql         - End-to-end validation
  streamlit/
    streamlit_app.py          - 8-view command center (641 lines)
  docs/
    build_status.txt          - Detailed build status and demo readiness
    execution_plan.md         - Full execution plan with 80+ tasks
    hackathon_story.md        - Hackathon narrative
```

## Object Inventory

| Schema | Objects | Count |
|--------|---------|-------|
| RAW | MACHINES, SENSORS, SENSOR_READINGS, MACHINE_EVENT_LOGS, MAINTENANCE_HISTORY, PARTS_INVENTORY, TOOLING_CHANGES, PRODUCTION_QUALITY, SHIFT_LOGS, WORK_ORDERS | 10 tables |
| STAGING | SENSOR_READINGS_CLEAN, MACHINE_OPERATING_CONTEXT, MACHINE_HEALTH_FEATURES, PERFORMANCE_BASELINE, CROSS_MACHINE_HEALTH | 5 Dynamic Tables |
| ANALYTICS | MAINTENANCE_CONTEXT (DT), DETECTED_ANOMALIES, FAILURE_FORECASTS, FAILURE_ASSESSMENTS, INCIDENTS, OEE_METRICS, PRODUCTION_IMPACT | 7 tables/views |
| ORCHESTRATION | DRAFT_WORK_ORDER, APPROVE_WORK_ORDER, RESOLVE_WORK_ORDER, RUN_MAINTENANCE_CYCLE (SPs), MAINTENANCE_CYCLE_TASK, NOTIFICATION_LOG | 6 objects |
| APP | COMMAND_CENTER_VIEW, FLEET_HEALTH_VIEW, PREDICTIVE_MAINTENANCE_COMMAND_CENTER (Streamlit), STREAMLIT_STAGE | 4 objects |

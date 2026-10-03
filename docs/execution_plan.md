# Predictive Maintenance Command Center - Execution Plan

**Source:** Predictive_Maintenance_Ground_Up_Proposal_Plan.txt
**Target Platform:** Snowflake (new environment, no prior dependencies)
**Database:** IOT_PREDICTIVE_MAINTENANCE
**UI:** Streamlit in Snowflake

---

## Requirement Summary

Build a ground-up Snowflake-native predictive maintenance command center that:
- Converges OT sensor signals with ERP/maintenance and production context
- Predicts failures with multi-sensor analytics and confidence-qualified assessments
- Explains risk with evidence-backed root-cause investigation
- Automates governed work orders with human-approval gates
- Shows OEE / production impact tied to maintenance risk
- Uses synthetic, referentially consistent data for full demo capability
- Demonstrates CoCo CLI usage across the complete lifecycle

---

## Architecture Overview

```
Database: IOT_PREDICTIVE_MAINTENANCE
Schemas:
  RAW            - OT telemetry, machine events, ERP/maintenance, production, human data
  STAGING        - Cleansing, normalization, operating-state context, feature pipelines
  ANALYTICS      - Health, incidents, predictions, RCA evidence, OEE, business impact
  ML_MODELS      - Cortex ML model objects and metadata
  ORCHESTRATION  - Tasks, stored procedures/skills, workflow state, notifications
  APP            - Semantic views, Streamlit application, supporting objects
```

**Data Flow:**
```
RAW OT telemetry + machine state
    -> cleaned / quality-checked signals
    -> multi-sensor features + operating-state baselines
    -> machine health / anomaly candidates
    -> maintenance + production context
    -> decision-ready incident context
    -> AI work-order draft -> human approval -> dispatch -> feedback
```

---

## Execution Steps

### Step 1: Foundation - Database, Schemas, Warehouse & Compute
**Key Deliverable:** Foundation DDL

- [ ] 1.1 Create database IOT_PREDICTIVE_MAINTENANCE
- [ ] 1.2 Create all 6 schemas: RAW, STAGING, ANALYTICS, ML_MODELS, ORCHESTRATION, APP
- [ ] 1.3 Create or validate warehouse/compute for the project
- [ ] 1.4 Set up roles and grants as needed for the demo
- [ ] 1.5 Verify clean environment with no leftover objects

### Step 2: Synthetic Data Generation - OT + ERP + Production
**Key Deliverable:** Referentially consistent demo dataset

RAW tables to create and populate:

- [ ] 2.1 RAW.MACHINES - Machine registry (ID, type, line, station, location, rated RPM/current, criticality, install date, operational states: RUNNING/IDLE/OFFLINE/FAULT/MAINTENANCE/WARM_UP)
- [ ] 2.2 RAW.SENSORS - Sensor registry by machine/signal type (VIBRATION, TEMPERATURE, RPM, CURRENT + optional PRESSURE, FLOW, ACOUSTIC, CYCLE_COUNTER)
- [ ] 2.3 RAW.SENSOR_READINGS - High-volume time-series with realistic noise, normal patterns, missing values, spikes, and synchronized degradation patterns before failure events
- [ ] 2.4 RAW.MACHINE_EVENT_LOGS - Startup/shutdown, overload, jam, alarm/error code, fault events
- [ ] 2.5 RAW.MAINTENANCE_HISTORY - Prior failures, failure mode, root cause, action, parts, repair duration, downtime, cost
- [ ] 2.6 RAW.PARTS_INVENTORY - Parts, compatible machine/component, quantity, reorder point, lead time, cost
- [ ] 2.7 RAW.TOOLING_CHANGES - Tool changes, reasons, dates, production/load context
- [ ] 2.8 RAW.PRODUCTION_QUALITY - Volume, good/rejected parts, cycle time, quality deviation, shift, status
- [ ] 2.9 RAW.SHIFT_LOGS - Operator observations (vibration, noise, smell, leak, visual issue, severity)
- [ ] 2.10 RAW.WORK_ORDERS - Full lifecycle table (DRAFT->APPROVED->ASSIGNED->IN_PROGRESS->RESOLVED/REJECTED)
- [ ] 2.11 Seed demo scenarios:
  - At least 5 machines with gradual degradation toward known failure modes
  - At least 1 scenario with correlated vibration + temperature + RPM/current
  - Historical maintenance records matching seeded failure modes
  - Production degradation signal before failure (OEE/output impact)
  - At least 1 sensor-fault scenario for data-quality fallback validation

### Step 3: Near-Real-Time Data Pipeline & Feature Engineering
**Key Deliverable:** STAGING pipeline (Dynamic Tables)

- [ ] 3.1 STAGING.SENSOR_READINGS_CLEAN - Null handling, unit normalization, threshold flags, stale-data flags, sensor-quality checks
- [ ] 3.2 STAGING.MACHINE_OPERATING_CONTEXT - Derive operating state, load/RPM context, valid comparison baseline; suppress signals during OFFLINE/MAINTENANCE
- [ ] 3.3 STAGING.MACHINE_HEALTH_FEATURES - Rolling 1h/6h/24h aggregates by machine+sensor; rate of change, variability, baseline deviation, multi-sensor correlation
- [ ] 3.4 STAGING.PERFORMANCE_BASELINE - Shift-over-shift and 7-day baselines for cycle time, output, reject rate; performance degradation vs comparable conditions
- [ ] 3.5 STAGING.CROSS_MACHINE_HEALTH - Fleet health score, status, concern rank; combine abnormal signals, anomaly frequency, threshold breaches, operating context
- [ ] 3.6 ANALYTICS.MAINTENANCE_CONTEXT - Join machine health with maintenance history, operator observations, production quality, machine events, parts availability

### Step 4: Failure Prediction & Decision Intelligence
**Key Deliverable:** ML models + analytics SQL

- [ ] 4.1 Multi-sensor anomaly detection - Train Cortex anomaly-detection models by machine class; validate against seeded degradation ground truth
  - Output: ANALYTICS.DETECTED_ANOMALIES (machine_id, timestamp, anomaly_score, affected_signals, severity, model_metadata)
- [ ] 4.2 Failure forecast - Forecast degradation trends, time-to-threshold/RUL proxy, risk horizons (24h/7d/30d), confidence + fallback states
  - Output: ANALYTICS.FAILURE_FORECASTS (predicted failure mode, risk horizon, RUL proxy, confidence, prediction timestamp, model version)
- [ ] 4.3 Failure-mode reasoning - Cortex LLM reasoning over multi-sensor evidence + machine history + operating context
  - Output: ANALYTICS.FAILURE_ASSESSMENTS (candidate modes: bearing degradation, misalignment, motor overload, hydraulic issue, sensor/data fault)
- [ ] 4.4 Prediction confidence & fallback logic - Route to MANUAL_INSPECTION_RECOMMENDED when data quality/model coverage/confidence is insufficient

### Step 5: Incident Correlation & Command-Center Triage
**Key Deliverable:** INCIDENTS + triage workflow

- [ ] 5.1 ANALYTICS.INCIDENTS - Group repeated anomaly events within configurable time window; correlate related signals; de-duplicate
  - Fields: incident_id, machine_id, time_window, suspected_failure_mode, severity, evidence_summary, health_score, RUL proxy, confidence, production_impact, owner, status
- [ ] 5.2 Incident lifecycle - NEW -> ACKNOWLEDGED -> ASSIGNED -> WORK_ORDER_PENDING -> RESOLVED / FALSE_POSITIVE
  - Track: acknowledgement timestamp, owner, SLA/age, snooze reason, escalation, resolution/false-positive reason
- [ ] 5.3 Priority calculation - Transparent scoring from: health/prediction risk, machine criticality, production impact/OEE exposure, repair urgency/RUL, evidence confidence

### Step 6: Root-Cause Investigation & Semantic Layer
**Key Deliverable:** Semantic View + Cortex Analyst/AI

- [ ] 6.1 Create APP.IOT_MAINTENANCE_VIEW semantic view covering: machine health, incidents, failure forecasts, maintenance history, production/quality, work orders, parts availability
- [ ] 6.2 Validate semantic model with natural-language questions via Cortex Analyst
- [ ] 6.3 Build copilot investigation capabilities (why critical, what changed first, which signals, prior failures, production impact, parts availability)
- [ ] 6.4 Historical similar-case retrieval (prior maintenance records with similar machine type, failure mode, signal pattern)

### Step 7: Governed Work-Order Automation
**Key Deliverable:** Orchestration stored procedures / skills

- [ ] 7.1 Skill 1 - Context Assembly: trigger from actionable incidents, assemble all evidence, store triage record
- [ ] 7.2 Skill 2 - Work-Order Drafting: Cortex AI drafts problem description, evidence summary, failure mode, repair actions, parts, duration, maintenance window; deduplicate against active work orders
  - Output: RAW.WORK_ORDERS with status=DRAFT
- [ ] 7.3 Skill 3 - Approval & Dispatch: human approval gate, status transition to APPROVED/ASSIGNED, dispatch notification, audit logging
- [ ] 7.4 Post-repair feedback capture: actual root cause, parts replaced, repair duration, technician findings, before/after health comparison

### Step 8: OEE & Production Impact Analytics
**Key Deliverable:** OEE + impact views

- [ ] 8.1 OEE calculations: Availability, Performance, Quality, OEE = A x P x Q
- [ ] 8.2 OEE outputs: current OEE by machine/line, 7-day trend, expected OEE exposure from incidents, production volume at risk, reject/scrap exposure, downtime hours at risk, downtime cost/hour
- [ ] 8.3 Maintenance decision support: compare predicted urgency with next maintenance window; surface monitor/plan/immediate action recommendation

### Step 9: Streamlit Command Center Application
**Key Deliverable:** New Streamlit-in-Snowflake app

- [ ] 9.1 View 1 - Factory Overview: fleet health, critical/warning counts, urgent machines, OEE KPIs, incident age/ownership, data freshness
- [ ] 9.2 View 2 - Incident Triage: grouped incidents, filters, acknowledge/assign/snooze/resolve/false-positive workflow, priority drivers
- [ ] 9.3 View 3 - Machine Detail & Predictive Diagnosis: synchronized sensor trends, operating-state overlay, health score, failure forecast, RUL, "why this alert" panel
- [ ] 9.4 View 4 - Root-Cause Copilot: natural-language investigation, evidence-backed answers, historical similar cases
- [ ] 9.5 View 5 - Work-Order Management: full lifecycle workflow, approval controls, AI-generated content, parts/downtime context, duplicate protection, post-repair capture
- [ ] 9.6 View 6 - OEE & Production Impact: A/P/Q/OEE, trends, production at risk, incident-to-production relationship
- [ ] 9.7 View 7 - Maintenance History & Reliability: previous failures, root causes, repeat patterns, parts/downtime/cost, similar historical cases
- [ ] 9.8 View 8 - Data/Model Trust: sensor freshness, pipeline status, model version, prediction confidence, fallback state, validation metrics

### Step 10: Notifications & Operational Automation
**Key Deliverable:** Operational workflow

- [ ] 10.1 Create Snowflake notification integration
- [ ] 10.2 Notify on high-priority incident creation and approved work-order dispatch (include machine, failure mode, evidence, priority, urgency, dashboard link)
- [ ] 10.3 Create Snowflake Task for end-to-end maintenance cycle on short demo schedule

### Step 11: CoCo Skills & Lifecycle Evidence
**Key Deliverable:** Hackathon evidence package

Reusable CoCo skills to create:
- [ ] 11.1 generate_factory_demo_data
- [ ] 11.2 build_machine_health_features
- [ ] 11.3 correlate_machine_incident
- [ ] 11.4 diagnose_machine_from_evidence
- [ ] 11.5 draft_governed_work_order
- [ ] 11.6 validate_sensor_and_prediction_quality
- [ ] 11.7 run_predictive_maintenance_e2e_test
- [ ] 11.8 Collect CoCo lifecycle evidence (planning, development, execution, testing)

### Step 12: End-to-End Validation & Demo Scenarios
**Key Deliverable:** Test results + demo script

- [ ] 12.1 Scenario 1 - Critical bearing/motor degradation: full closed-loop from rising signals -> prediction -> incident -> RCA -> work order -> approval -> notification -> repair outcome -> OEE impact
- [ ] 12.2 Scenario 2 - Sensor malfunction: flatline/stale sensor -> data-quality warning + reduced confidence + manual inspection recommendation
- [ ] 12.3 Scenario 3 - Expected high-load condition: sensor rise during known high-load state -> compare against correct baseline before alerting
- [ ] 12.4 Scenario 4 - Repeated anomaly events: multiple correlated anomalies -> single incident, no duplicate work order
- [ ] 12.5 Scenario 5 - Existing active work order: second anomaly with active WO -> update/attach existing incident, no new WO
- [ ] 12.6 Scenario 6 - Low-confidence prediction: limited/poor evidence -> low-confidence label, no overconfident claim, manual inspection route
- [ ] 12.7 Scenario 7 - Production impact: machine degradation affecting cycle time/rejects -> command center connects maintenance risk to OEE

---

## Verification Checklist

- [ ] New environment contains only objects created by this implementation
- [ ] Synthetic datasets are referentially consistent across OT, maintenance, production
- [ ] Vibration + temperature + RPM + current correlate on common machine timeline
- [ ] Operating-state context suppresses misleading readings during OFFLINE/MAINTENANCE
- [ ] ML detects seeded degradation patterns with measurable validation
- [ ] Failure assessment provides named failure mode only when sufficient evidence exists
- [ ] RUL/time-to-threshold estimates include confidence/fallback state
- [ ] Repeated anomaly events collapse into single incident
- [ ] Active work-order duplication is prevented
- [ ] Work-order generation is approval-gated and auditable
- [ ] RCA answers expose evidence used
- [ ] OEE calculations reconcile with production dataset
- [ ] Approved work orders produce notification events
- [ ] Post-repair feedback stored and compared with pre-repair health
- [ ] Sensor-quality and low-confidence edge cases behave safely
- [ ] Streamlit views load from new environment with live/refreshed data
- [ ] CoCo evidence exists for planning, development, execution, and testing

---

## Critical Objects to Create

| # | Object | Purpose |
|---|--------|---------|
| 1 | Database + Schema DDL | Foundation objects and governance boundaries |
| 2 | Synthetic data generator | Referentially consistent OT, maintenance, production data |
| 3 | Pipeline DDL | Dynamic Tables, optional Streams and Tasks |
| 4 | ML pipeline SQL | Training, inference, forecast/time-to-threshold logic, validation |
| 5 | Analytics SQL | Health, incidents, RCA evidence, OEE/production impact |
| 6 | Orchestration skills/SPs | Context assembly, WO drafting, approval/dispatch, feedback |
| 7 | Semantic model | Cortex Analyst semantic view + verified questions |
| 8 | Streamlit application | Command center (8 views) |
| 9 | Notification integration | High-priority incident/approved WO notifications |
| 10 | CoCo skills/prompts | 7 reusable skills for planning, build, diagnosis, WO, validation |
| 11 | E2E validation script | Automated demo scenarios + expected-result checks |
| 12 | Hackathon evidence package | CoCo planning/development/execution/testing evidence |

---

## Definition of Done

The application is complete when it demonstrates one coherent closed-loop story:

1. OT telemetry arrives from multiple sensors
2. System understands machine operating context and data quality
3. Multi-sensor analytics detect abnormal degradation
4. System produces confidence-qualified failure assessment/forecast
5. Related alerts grouped into one actionable incident
6. Incident explained using sensor, maintenance, and production evidence
7. System drafts non-duplicative maintenance work order
8. Human approves the action before dispatch
9. Maintenance team notified and action tracked
10. Production/OEE impact visible to plant user
11. Repair feedback captured and used for validation
12. CoCo demonstrably used across planning, development, execution, and testing

**Narrative Flow:**
```
CONVERGE OT + IT -> PREDICT FAILURE -> EXPLAIN WHY -> PRIORITIZE INCIDENT
-> DRAFT + APPROVE WORK ORDER -> TAKE MAINTENANCE ACTION
-> MEASURE OEE / PRODUCTION IMPACT -> FEED OUTCOME BACK INTO TRUST & VALIDATION
```

# Bridging the OT-IT Divide: Predictive Maintenance with Snowflake CoCo CLI

## The Hackathon Story

---

### The Problem

Manufacturers lose millions to unplanned downtime. The root cause is not a lack of data -- factories generate terabytes of sensor telemetry every day. The problem is that **OT sensor data sits in isolation**, disconnected from ERP maintenance records, operator observations, production quality metrics, and business continuity planning.

When a CNC lathe starts vibrating abnormally at 2 AM, the on-call technician sees a sensor alert but has no context: Was there a tooling change last week? Did the operator on shift 2 report a burning smell? Has this machine failed this way before? Is there a spare part in stock? Should we rent a backup machine to keep the production line running?

That context exists -- scattered across six different systems. By the time someone assembles it manually, the machine has already failed.

**We built a platform that converges all of it.**

---

### The Approach: Built Entirely in CoCo

We did not open Snowsight. We did not write a single line of code in an IDE. Every object in this platform -- every table, every dynamic table, every ML model, every stored procedure, every dashboard view -- was created through conversational interaction with Snowflake's Cortex Code CLI across three sessions.

CoCo was not just a tool we used. It was the architect, the data engineer, the ML engineer, and the DevOps team.

---

### Session 1 (September 10): Planning and Foundation

We started with a conversation. We described the manufacturing scenario: 50 machines across 6 types (CNC lathes, hydraulic presses, conveyors, injection molders, pumps, compressors), each instrumented with 7 sensor types, running 3 shifts per day in a factory that has been operating for several years.

**CoCo planned the entire architecture:**

- Designed a 6-schema data model (RAW, STAGING, ANALYTICS, ML_MODELS, ORCHESTRATION, APP) following medallion architecture principles
- Identified 13 interconnected tables spanning OT sensor data, ERP maintenance records, operator shift logs, production quality metrics, power quality monitoring, and business continuity (rental machines)
- Created the `IOT_PREDICTIVE_MAINTENANCE` database, all schemas, and a dedicated ML warehouse

**Then CoCo generated the synthetic data:**

This is where things got interesting. We needed realistic, referentially consistent data across 13 tables with deliberately seeded failure patterns. CoCo generated 320,000+ rows of synthetic data using pure SQL (GENERATOR functions, CROSS JOINs, UNIFORM/RANDOM) -- no Python, no stored procedures, no external tools.

The critical design choice: 5 machines were seeded with quadratic degradation curves that progress over 30 days toward failure. MCH-0003 fails on day 60. MCH-0012 fails on day 45. The degradation manifests differently across sensors -- vibration increases, temperature rises, current draw spikes, acoustic signatures change -- all following physically realistic patterns.

But the data goes far deeper than sensors. CoCo generated:
- **Operator shift logs** where workers near failing machines increasingly report "grinding noise," "burnt smell," and "visible wear" -- the human observations that a maintenance AI needs to correlate with sensor data
- **Production quality records** showing reject rates climbing and cycle times drifting as machines degrade
- **Power quality events** with more voltage sags and harmonics near failure dates
- **Tooling change records** with accelerated wear patterns on affected machines

This is the IT-OT convergence the hackathon demands. Not just sensor data, but the full operational picture.

---

### Session 2 (September 16): The Data Pipeline and ML Models

**CoCo built a 5-layer dynamic table pipeline:**

Starting from raw sensor readings, CoCo created a chain of dynamic tables that automatically transform, enrich, and score data as it flows through the system:

1. **SENSOR_READINGS_CLEAN** -- Null imputation via sliding-window averages, min-max normalization against sensor thresholds, breach detection. Joins with machine specs and sensor metadata.

2. **MACHINE_HEALTH_FEATURES** -- Rolling statistical features at 1-hour, 6-hour, and 24-hour windows. For every machine and every sensor type: mean, standard deviation, max, min, rate of change, and Z-score. This is the feature engineering layer that feeds ML.

3. **PERFORMANCE_BASELINE** -- Shift-over-shift production comparison. Rolling 7-day baselines for cycle time, tolerance deviation, and surface finish. Machines are flagged HEALTHY, WARNING, or DEGRADED based on deviation from their own historical performance.

4. **CROSS_MACHINE_HEALTH** -- A composite health score (0-100) for every machine on the factory floor. The score penalizes high Z-score deviations, anomaly counts, threshold breaches, and signal variability. This powers the "during a shutdown, what else should we fix?" use case.

5. **ANOMALY_CONTEXT** -- The convergence layer. For every anomalous reading, this dynamic table joins with the nearest operator observation, the production metrics from that shift, any power quality events in the same hour, the machine's maintenance history, and its cross-machine health ranking. This is the full context packet that enables intelligent triage.

The pipeline validated correctly: the 5 seeded failing machines ranked as the top 5 CRITICAL machines with health scores of 37-39 out of 100.

**CoCo trained 8 Cortex ML models:**

- 7 anomaly detection models (one per machine class + one combined) using `SNOWFLAKE.ML.ANOMALY_DETECTION` with supervised labels
- 1 vibration forecast model using `SNOWFLAKE.ML.FORECAST` for 14-day trend prediction

CoCo encountered and solved real engineering problems here. The initial models were trained on all 90 days of data, which meant the DETECT_ANOMALIES function refused to run inference (timestamps must be after training data). CoCo diagnosed the issue and restructured with a 60/30-day train/test split. The forecast model initially included exogenous features that could not be provided at prediction time; CoCo retrained with vibration-only input.

The ML results: failing machines showed 55-87% anomaly detection rates. The vibration forecast correctly projected upward trends for degrading machines.

---

### Session 3 (September 19): Agentic Orchestration, AI, and the Dashboard

This is where the platform became autonomous.

**CoCo built 3 agentic skills as stored procedures:**

**Skill 1: Context Assembly** -- When new CRITICAL or HIGH anomalies appear, this procedure assembles a complete diagnostic context packet by querying 7 data domains: operator observations, production metrics, power events, maintenance history, cross-machine health, parts inventory, and rental availability. It uses CTEs (not correlated subqueries -- CoCo hit a SQL compilation error with the initial approach and restructured automatically) to build the enriched triage record.

**Skill 2: Work Order Drafting** -- For each triaged anomaly, this procedure calls `SNOWFLAKE.CORTEX.COMPLETE` with llama3.1-70b to generate:
- A concise work order title
- A 3-sentence problem description synthesizing sensor data, operator observations, and production impact
- A 4-step recommended maintenance action list

The AI does not generate generic text. It receives the full context packet -- "MCH-0047 PUMP, health score 37.7, operator reported burnt smell, reject rate 19.6%, last failure was bearing failure" -- and produces maintenance-specific recommendations.

CoCo handled a practical issue here: the LLM responses initially exceeded Snowflake's column length limits. CoCo wrapped the COMPLETE calls in LEFT() truncation and adjusted the prompt to request concise output.

**Skill 3: Dispatch and Notification** -- Updates work order status from DRAFT to ASSIGNED and sends email notifications to the maintenance team via `SYSTEM$SEND_EMAIL`. Each email includes machine ID, priority, assigned technician, estimated downtime, rental recommendation, and the AI-generated problem description.

**CoCo chained all 3 skills into a scheduled task:**

```sql
CREATE TASK MAINTENANCE_PIPELINE_TASK
    SCHEDULE = '5 MINUTES'
AS BEGIN
    CALL SKILL1_ASSEMBLE_CONTEXT();
    CALL SKILL2_DRAFT_WORK_ORDERS();
    CALL SKILL3_DISPATCH_AND_NOTIFY();
END;
```

Every 5 minutes, the platform autonomously: detects anomalies, enriches them with cross-domain context, drafts AI work orders, and dispatches email alerts. No human in the loop for CRITICAL events.

**CoCo created a semantic view for natural language queries:**

The `IOT_MAINTENANCE_VIEW` semantic view exposes 4 logical tables, 10 facts, 11 dimensions, and 4 metrics to Cortex Analyst. A plant manager can ask "Which machines are in critical condition?" and get an accurate SQL-generated answer without knowing the schema.

We validated this with CoCo's Cortex Analyst integration:
```
cortex analyst query "Which-machines-are-critical" --view=IOT_MAINTENANCE_VIEW
```
It correctly returned the 5 CRITICAL machines with their health scores.

**CoCo built and deployed the Streamlit dashboard:**

7 views covering the full command center experience:

1. **Factory Floor Overview** -- All 50 machines with color-coded health status, KPI cards for critical/warning counts
2. **Machine Detail** -- Drill into any machine: vibration time-series, detected anomalies, 14-day vibration forecast with confidence intervals
3. **Anomaly Feed** -- Severity-filtered live feed of ML-detected anomalies with confidence scores and operator context
4. **Work Order Management** -- Priority-sorted AI-drafted work orders with full problem descriptions and recommended actions
5. **Maintenance History** -- Historical failures with root cause, downtime, and cost tracking
6. **Business Continuity** -- Rental machine availability, parts inventory, critical machines needing backup
7. **Cross-Machine Health** -- "What else should we fix during this shutdown?" -- health distribution across the fleet

CoCo wrote the entire 254-line Streamlit app, uploaded it to a Snowflake stage, and created the STREAMLIT object -- all via SQL execution.

---

### End-to-End Validation

CoCo ran the final test: inject a synthetic anomaly for MCH-0043 (a conveyor with no existing work order), then execute the full pipeline.

- Skill 1 picked up the anomaly and enriched it with context from all 7 domains
- Skill 2 drafted a work order titled "Conveyor MCH-0043 Vibration Anomaly - Critical Health Score 32/100"
- Skill 3 dispatched the work order and sent the email notification
- Deduplication correctly prevented duplicate work orders for machines already being serviced

The entire flow -- from anomaly detection to email in the maintenance team's inbox -- completed in seconds.

---

## How We Used CoCo at Every Phase

| Phase | CoCo Usage |
|-------|-----------|
| **Planning** | CoCo designed the 6-schema architecture, 13-table data model, DT pipeline topology, and ML strategy. All design decisions were made conversationally. |
| **Data Generation** | CoCo generated 320K+ rows of referentially consistent synthetic data with realistic degradation patterns using pure SQL -- no external tools. |
| **Pipeline Development** | CoCo created 5 dynamic tables with change tracking, wrote all transformation SQL, and validated the pipeline output. |
| **ML Training** | CoCo trained 8 Cortex ML models, diagnosed and fixed train/test split issues, ran inference, and populated results. |
| **AI Integration** | CoCo wired Cortex COMPLETE (llama3.1-70b) for severity classification and work order drafting, handling prompt engineering and output truncation. |
| **Orchestration** | CoCo built 3 stored procedures, created the notification integration, and set up the 5-minute scheduled task. |
| **Semantic Layer** | CoCo authored the semantic view DDL and validated it via Cortex Analyst queries. |
| **Dashboard** | CoCo wrote the 7-view Streamlit app, deployed it to Snowflake via stage upload, and created the STREAMLIT object. |
| **Testing** | CoCo ran the E2E validation: anomaly injection, pipeline execution, work order verification, Cortex Analyst query, and deduplication check. |
| **Documentation** | CoCo generated the progress tracker, E2E workflow document, and organized the full GitHub repository with 9 SQL scripts, the Streamlit app, and README. |

---

## Technical Architecture at a Glance

```
Database:           IOT_PREDICTIVE_MAINTENANCE
Schemas:            RAW | STAGING | ANALYTICS | ML_MODELS | ORCHESTRATION | APP
Warehouse:          IOT_ML_WH (Medium)
RAW tables:         13 (320K+ total rows)
Dynamic tables:     5 (all ACTIVE, auto-refreshing)
ML models:          8 (7 anomaly detection + 1 forecast)
Stored procedures:  3 (context assembly, WO drafting, dispatch)
Scheduled tasks:    1 (5-minute autonomous pipeline)
Notification:       Email via SYSTEM$SEND_EMAIL
Semantic view:      1 (Cortex Analyst compatible)
Streamlit app:      1 (7-view command center)
```

---

## Judging Criteria Alignment

**Real World Relevance:** The platform addresses the exact scenario manufacturers face -- OT sensor data disconnected from ERP context, leading to reactive maintenance. The solution converges 6 data domains (sensors, production quality, operator observations, power quality, maintenance history, business continuity) into a single decision framework. The cross-machine health scoring answers the practical question: "While this machine is down, what else should we fix?"

**Technical Execution:** 5-layer dynamic table pipeline with rolling statistical features, composite health scoring, and multi-domain context enrichment. 8 Cortex ML models with proper train/test methodology. AI-generated work orders using context-aware LLM prompts. Automated 5-minute orchestration loop. Semantic view for natural language access.

**Solution Completeness:** The platform covers the full lifecycle: data ingestion, transformation, anomaly detection, forecasting, severity classification, context assembly, work order drafting, email dispatch, dashboard visualization, and natural language querying. The E2E validation proves every link in the chain works.

**CoCo Usage:** Every object was created through CoCo CLI interaction. No Snowsight, no IDE, no external tooling. CoCo planned the architecture, generated synthetic data, built pipelines, trained ML models, authored stored procedures, created the semantic view, deployed the dashboard, ran validation, and generated documentation. The progress tracker and E2E workflow document provide a complete audit trail of CoCo's involvement across 3 sessions.

---

## The Result

From a blank Snowflake account to a fully operational predictive maintenance platform in 3 CoCo sessions:

- **50 machines monitored** with composite health scores
- **3,249 anomalies detected** by ML with severity classification
- **49 AI-drafted work orders** with context from 6 data domains
- **49 email notifications** dispatched to the maintenance team
- **5 failing machines correctly identified** as CRITICAL (health scores 37-39)
- **14-day vibration forecasts** showing upward trends for degrading machines
- **7-view command center** for alert triage and action
- **Natural language access** via Cortex Analyst semantic view

All built through conversation. All running autonomously. All on Snowflake.

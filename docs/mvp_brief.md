# Prototype/MVP Brief: IoT Predictive Maintenance Platform

## What It Is

A Snowflake-native platform that converges OT sensor data with ERP maintenance records, operator observations, production quality metrics, and business continuity data to predict machine failures, auto-generate maintenance work orders using AI, and dispatch email alerts -- all built and operated entirely through the Cortex Code (CoCo) CLI.

## The Problem It Solves

Unplanned downtime costs manufacturers an estimated $50 billion annually. The data to prevent it already exists -- vibration sensors detect bearing wear weeks before failure, operators notice unusual smells and sounds, production reject rates climb as machines degrade. But this data lives in 6 disconnected systems: SCADA historians, ERP platforms, shift log spreadsheets, MES systems, power monitoring tools, and procurement databases. No single person or system sees the full picture until after the machine has already stopped.

Our platform eliminates this blind spot by converging all 6 data domains into one unified pipeline that detects, contextualizes, and acts on failures before they happen.

## What It Does

The platform runs an autonomous loop every 4 hours:

1. **Detect** -- 5 dynamic tables auto-refresh to clean sensor readings, compute rolling statistical features (1h/6h/24h windows), score every machine's health (0-100 composite), and flag anomalies using Z-scores and threshold breaches. 8 Cortex ML models (7 anomaly detection + 1 vibration forecast) supplement this with supervised anomaly classification and 14-day trend predictions.

2. **Contextualize** -- For every CRITICAL or HIGH anomaly, a stored procedure assembles the full diagnostic picture by joining 7 data domains: the anomalous sensor readings, nearest operator shift log observations, production quality from the same shift, power quality events from the same hour, the machine's last 3 maintenance failures, spare parts inventory with stock levels, and rental machine availability for that machine type.

3. **Act** -- Cortex AI (llama3.1-70b) drafts a maintenance work order from the context packet: a concise title, a 3-sentence problem description synthesizing sensor and human observations, a 4-step recommended action checklist, estimated downtime, parts needed, and a rental backup flag. The work order is dispatched and an email notification is sent to the maintenance team automatically.

## What We Built

**Data layer:** 13 tables across 6 domains with 320,000+ rows of synthetic data. 50 machines across 6 types (CNC lathe, hydraulic press, conveyor, injection molder, pump, compressor). 5 machines seeded with realistic degradation-to-failure patterns including correlated signals across sensors, operator logs, production metrics, and power quality.

**Pipeline:** 5 dynamic tables forming a declarative, auto-refreshing transformation chain. Sensor readings are cleaned (null imputation, normalization, threshold detection), enriched with rolling statistical features, scored into composite health metrics, and joined with multi-domain context. All intermediate tables use TARGET_LAG = DOWNSTREAM; only leaf tables have time-based refresh.

**ML:** 7 anomaly detection models (one per machine class + combined) trained with supervised labels on a 60-day window, inference on the remaining 30 days. 1 vibration forecast model producing 14-day predictions with 95% confidence intervals. Results: 3,249 anomalies detected, 55-87% hit rate on known failing machines, all 5 seeded failures correctly identified as CRITICAL.

**AI orchestration:** 3 stored procedures chained by a scheduled task. Skill 1 enriches anomalies with context from 7 data domains. Skill 2 calls llama3.1-70b to draft work orders. Skill 3 dispatches and sends email notifications via SYSTEM$SEND_EMAIL. Deduplication prevents duplicate work orders for machines already being serviced.

**Semantic layer:** A Cortex Analyst semantic view with 4 logical tables, 10 facts, 11 dimensions, and 4 metrics enabling natural language queries like "which machines are critical" -- returning accurate, SQL-grounded answers.

**Dashboard:** A 7-view Streamlit app deployed natively in Snowflake:
- Factory Floor Overview -- color-coded health status for all 50 machines
- Machine Detail -- vibration time-series, anomaly history, 14-day forecast
- Anomaly Feed -- severity-filtered ML detections with operator observation correlation
- Work Order Management -- AI-drafted orders with full problem descriptions and action checklists
- Maintenance History -- historical failures with root cause, downtime, and cost tracking
- Business Continuity -- rental availability, parts inventory, critical machines needing backup
- Cross-Machine Health -- opportunistic maintenance planning during shutdown windows

## CoCo CLI Usage

Every object was created through CoCo conversations. No IDE, no Snowsight, no external tools. CoCo planned the architecture, generated synthetic data using pure SQL generators, built the dynamic table pipeline, trained ML models, authored stored procedures with AI prompts, created the semantic view, wrote and deployed the Streamlit app, ran end-to-end validation, and generated all documentation including a 717-line workflow log and 9 organized SQL scripts for the GitHub repository.

## Validated Results

End-to-end test: injected a synthetic anomaly for MCH-0043 (conveyor). Skill 1 enriched it with context from all 7 domains. Skill 2 drafted a work order titled "Conveyor MCH-0043 Vibration Anomaly - Critical Health Score 32/100." Skill 3 dispatched it and sent the email. The entire flow completed in seconds. Deduplication correctly prevented duplicate work orders. Cortex Analyst returned accurate results from natural language queries.

## What It Proves

The MVP demonstrates that a single platform on Snowflake can close the loop from raw sensor data to dispatched maintenance action -- converging IT and OT data, predicting failures with ML, generating context-aware work orders with AI, and delivering a command center experience for triage and decision-making. The architecture scales to thousands of machines with no code changes, and extends to real ERP integrations, real-time streaming via Snowpipe, and cross-tool orchestration via MCP.

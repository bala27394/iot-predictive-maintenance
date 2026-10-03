# Predictive Maintenance Command Center — Problem Statement, Solution & Demo Script

---

## 1. The Problem

### Manufacturing plants lose millions to unplanned downtime

Modern factories run hundreds of machines generating terabytes of sensor data — vibration, temperature, current, pressure, RPM — every day. Yet most plants still rely on:

- **Reactive maintenance**: Fix it when it breaks. Average cost: 3–10x more than planned repair, plus lost production.
- **Calendar-based preventive maintenance**: Replace parts on a schedule regardless of actual condition. Wastes parts and labor on healthy machines while missing failures between intervals.
- **Siloed data**: OT sensor data lives in historians, maintenance records in ERP, production data in MES, and operator observations in shift log notebooks. No single system connects "vibration is rising" to "this failure happened before" to "production rejects are increasing."

### The result

- Unplanned downtime costs manufacturers an estimated $50B/year globally
- 82% of asset failures are random, not age-related — time-based PM misses them
- Alert fatigue: anomaly systems generate thousands of uncorrelated alerts that operators learn to ignore
- No connection between predicted maintenance risk and production/business impact

### What's needed

A system that:
1. Converges OT sensor signals with maintenance history, production data, and human observations
2. Predicts failures before they happen using multi-sensor correlation, not just single-signal thresholds
3. Explains WHY a failure is predicted with traceable evidence
4. Groups alerts into actionable incidents instead of flooding operators
5. Automates work-order creation but keeps humans in the approval loop
6. Ties maintenance risk directly to OEE and production impact
7. Builds trust through transparency — showing confidence levels, data quality, and model limitations

---

## 2. How We Solved It

### Snowflake-native predictive maintenance, built entirely with CoCo CLI

We built a complete, ground-up predictive maintenance command center on Snowflake — no external tools, no separate ML platform, no additional application stack. Every component was designed, authored, debugged, and validated using CoCo CLI across the full development lifecycle.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    IOT_PREDICTIVE_MAINTENANCE                          │
│                                                                         │
│  ┌──────────┐    ┌──────────┐    ┌───────────┐    ┌──────────────────┐ │
│  │   RAW     │───>│ STAGING  │───>│ ANALYTICS │───>│       APP        │ │
│  │          │    │          │    │           │    │                  │ │
│  │ 10 tables│    │ 5 Dynamic│    │ 7 tables/ │    │ Streamlit App    │ │
│  │ 135K+    │    │ Tables   │    │ views     │    │ (8 views)        │ │
│  │ readings │    │          │    │           │    │                  │ │
│  └──────────┘    └──────────┘    └───────────┘    └──────────────────┘ │
│                                                                         │
│  ┌──────────────────┐    ┌─────────────────────────────────────────┐   │
│  │  ORCHESTRATION    │    │            ML_MODELS                    │   │
│  │ 3 SPs + Task +   │    │   (reserved for Cortex ML)              │   │
│  │ Notification Log  │    │                                         │   │
│  └──────────────────┘    └─────────────────────────────────────────┘   │
│                                                                         │
│  Warehouse: IOT_PM_WH (MEDIUM)                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Pipeline Architecture

```
                    ┌─────────────────────┐
                    │   OT Sensor Data     │
                    │  (135K+ readings)    │
                    └─────────┬───────────┘
                              │
                    ┌─────────▼───────────┐
                    │ SENSOR_READINGS_CLEAN │  DT1: Quality flags, thresholds,
                    │  (Dynamic Table)      │       spike detection, stale data
                    └─────────┬───────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
    ┌─────────▼──────┐ ┌─────▼──────┐ ┌──────▼─────────┐
    │MACHINE_OPERATING│ │MACHINE_    │ │ PERFORMANCE_   │
    │_CONTEXT (DT2)   │ │HEALTH_     │ │ BASELINE (DT4) │
    │                 │ │FEATURES    │ │                │
    │ State, load,    │ │(DT3)       │ │ Shift/7d       │
    │ suppression     │ │            │ │ comparisons    │
    └────────┬────────┘ │ 1h/6h/24h  │ └───────┬────────┘
             │          │ rolling    │         │
             │          │ aggregates │         │
             │          └─────┬──────┘         │
             │                │                │
             └────────┬───────┘                │
                      │                        │
            ┌─────────▼───────────┐            │
            │ CROSS_MACHINE_HEALTH │  DT5: Fleet health     │
            │  (Dynamic Table)     │       scores 0-100      │
            └─────────┬───────────┘            │
                      │                        │
            ┌─────────▼───────────┐            │
            │ MAINTENANCE_CONTEXT  │  DT6: Enriched with    │
            │  (Dynamic Table)     │◄──────────┘ maintenance,
            │                      │       operator obs,
            │                      │       production, parts
            └─────────┬───────────┘
                      │
        ┌─────────────┼─────────────────┐
        │             │                 │
   ┌────▼────┐  ┌────▼──────┐  ┌───────▼──────┐
   │DETECTED │  │FAILURE    │  │FAILURE       │
   │ANOMALIES│  │FORECASTS  │  │ASSESSMENTS   │
   └────┬────┘  └────┬──────┘  └───────┬──────┘
        │             │                 │
        └─────────────┼─────────────────┘
                      │
              ┌───────▼────────┐
              │   INCIDENTS     │  Correlated, prioritized,
              │                 │  with transparent scoring
              └───────┬────────┘
                      │
              ┌───────▼────────┐
              │  WORK ORDERS    │  AI-drafted, human-approved,
              │                 │  duplicate-protected
              └───────┬────────┘
                      │
              ┌───────▼────────┐
              │  NOTIFICATIONS  │  Email alerts to
              │  (Email)        │  maintenance team
              └────────────────┘
```

### What makes this different

| Traditional Approach | Our Solution |
|---------------------|--------------|
| Single-signal threshold alerts | Multi-sensor correlation (vibration + temp + current + RPM) |
| Thousands of uncorrelated alerts | Incident grouping — one incident per machine per failure mode |
| Opaque "AI score" | Transparent priority: health risk + criticality + production impact + RUL + confidence |
| Separate ML platform | Snowflake-native: Dynamic Tables + SQL analytics + stored procedures |
| Uncontrolled automation | Governed: AI drafts work orders, humans approve |
| No production context | OEE (A × P × Q) tied directly to each incident |
| No feedback loop | Post-repair outcome capture validates predictions |
| Trust the black box | Data Trust view: freshness, quality, confidence, fallback states |

---

## 3. CoCo CLI Throughout the Lifecycle

CoCo was not just used for SQL generation — it was the primary development tool across every phase.

### Planning Phase
- Analyzed the 708-line proposal document
- Created the structured execution plan (80+ tasks across 12 steps)
- Designed the database schema, data relationships, and pipeline architecture
- Defined demo scenarios and validation criteria

### Development Phase
- Created all database objects: 10 RAW tables, 6 Dynamic Tables, 7 analytics tables/views
- Generated 135K+ synthetic sensor readings with realistic degradation patterns
- Built the rolling-window feature engineering pipeline
- Authored anomaly detection, failure forecasting, and failure assessment logic
- Created 3 stored procedures for governed work-order automation
- Built the 641-line, 8-view Streamlit command center

### Debugging Phase (real issues caught and fixed via CoCo)
- `hide_index=True` not supported in SiS Streamlit version — removed from all 13 dataframes
- `st.rerun()` not available — replaced with `do_rerun()` compatibility shim
- `plotly` not installed in SiS — replaced with pure SVG gauge charts
- `SHOW DYNAMIC TABLES` column count mismatch in Snowpark — switched to INFORMATION_SCHEMA
- `ROWS` reserved keyword in SQL — quoted as `"ROWS"`
- `DuplicateWidgetID` in Work Orders view — added tab-index prefixes to all widget keys
- Snowflake `Decimal` type fails Python `:.1f` formatting — added `safe_float()` helper
- `NaN` from LEFT JOIN columns fails truthiness check — added `pd.notna()` guards

### Testing & Validation Phase
- Validated MCH-001 bearing degradation end-to-end (vibration 4.85 → 11.96 mm/s)
- Confirmed MCH-003 sensor fault detection (488 STALE readings flagged)
- Verified MCH-006 high-load normal operation not false-positive flagged
- Tested duplicate work-order prevention
- Verified all 4 incidents rank correctly with transparent priority drivers
- Confirmed OEE calculations and production impact linkage

### Deployment Phase
- Uploaded Streamlit app to Snowflake stage
- Created notification integration for email alerts
- Configured and resumed 8-hour scheduled task
- Pushed all code to GitHub repository

---

## 4. Seeded Demo Scenarios

Six scenarios are pre-loaded in the synthetic data to demonstrate different system behaviors:

| # | Machine | Scenario | What to Show |
|---|---------|----------|-------------|
| 1 | MCH-001 (CNC Lathe Alpha) | Bearing degradation | Full closed-loop: rising vibration+temp+current → prediction → incident → work order → approval → OEE impact. Historical match: MNT-001 (Aug 2024, same root cause). |
| 2 | MCH-005 (CNC Mill Gamma) | Spindle misalignment | Starts day 15, steep rise. Shows multi-signal correlation and 2.5-day RUL. |
| 3 | MCH-009 (Hydraulic Press 2) | Hydraulic seal failure | Pressure drop + temperature rise. Different failure mode, different sensor pattern. |
| 4 | MCH-008 (Grinding Station 1) | Wheel imbalance | Slow, gradual vibration rise. MEDIUM priority — shows the system doesn't over-react. |
| 5 | MCH-003 (Hydraulic Press 1) | Sensor fault | Vibration sensor goes STALE after day 25. System flags data quality issue, reduces confidence. |
| 6 | MCH-006 (Robotic Welder 1) | High-load normal operation | Sensors rise during heavy welding cycle. System correctly classifies as ROUTINE_MONITORING — no false alert. |

---

## 5. Demo Script (5-Minute Walkthrough)

### Opening (15 seconds)

> "This is a predictive maintenance command center built entirely on Snowflake using CoCo CLI. It converges OT sensor data with maintenance history and production records to predict failures, explain risk, and automate governed work orders."

### Scene 1: Factory Overview (45 seconds)

Open the Factory Overview page.

> "Here's our factory — 12 machines across 3 production lines. The OEE gauge shows current plant performance. The trend chart tracks Quality, Performance, Availability, and OEE over the last 7 days."

Point to the station summary.

> "11 of 12 machines are running, but we have 1 critical and 1 high-priority incident. MCH-001, our CNC Lathe, is the most urgent — health score 77 out of 100, flagged with bearing degradation."

Point to the machine cards.

> "Each machine has a health gauge. Green means healthy, yellow means watch, red means act now. MCH-001 is clearly in trouble."

### Scene 2: Incident Triage (60 seconds)

Navigate to Incident Triage.

> "The system detected thousands of individual anomaly events over 30 days. Instead of showing all of them, it correlates related signals — vibration, temperature, current — into a single incident per machine."

Expand INC-001.

> "INC-001 has a priority score of 77 out of 100. This isn't a black box — I can see the drivers: health risk from a score of 77, HIGH machine criticality, DEGRADED production status, the machine is past its predicted failure threshold, and the prediction has HIGH confidence."

> "The evidence panel shows exactly what sensors detected: vibration trending up at 0.31 mm/s per day, temperature rising at 1.6°C per day, and an operator reported a burning smell from the spindle housing."

### Scene 3: Machine Detail (45 seconds)

Navigate to Machine Detail, select MCH-001.

> "Here are the raw sensor trends over 30 days. Vibration started around 4 mm/s and has risen steadily to nearly 13. Temperature and current follow the same pattern — classic bearing degradation signature."

Scroll to the failure forecast.

> "The system predicts BEARING_DEGRADATION with HIGH confidence. The estimated days-to-critical-threshold is -2.5 — meaning we're already past the warning level."

Point to "Why This Alert?"

> "Every prediction comes with an evidence-backed explanation, not a generic AI response."

### Scene 4: Root-Cause Copilot (45 seconds)

Navigate to Root-Cause Copilot, select INC-001.

Click the "Historical Cases" tab.

> "This is where it gets powerful. The system found that this exact machine had the same failure — BEARING_DEGRADATION — in August 2024. The root cause was spindle bearing wear from prolonged high-load operation. The repair took 6 hours and cost $4,500."

Click the "Maintenance History" tab.

> "MCH-001 has had bearing issues twice before. That pattern, combined with the current sensor evidence, gives us high confidence this is the same failure mode recurring."

### Scene 5: Work Orders (45 seconds)

Navigate to Work Orders.

> "The system automatically drafted a work order with specific repair actions: isolate machine, inspect bearings, check lubrication, replace if worn, realign, test run. It estimated 6 hours repair time and 8 hours downtime."

Point to WO-0001 status.

> "A supervisor already approved this one. But critically — the system won't create a duplicate. If I try to draft another work order for MCH-001 bearing degradation, it blocks it."

Show WO-0003 (DRAFT).

> "WO-0003 for the hydraulic press is still in DRAFT. Let me approve it now."

Type approver name, click Approve. (Live demo of approval workflow.)

### Scene 6: OEE & Production Impact (30 seconds)

Navigate to OEE & Production.

> "Here's why maintenance matters to the business. MCH-001's reject rate has risen to 10%, with 8 hours of downtime at risk. The command center connects every predicted failure directly to production outcomes — this isn't just a maintenance tool, it's a production-protection tool."

### Scene 7: Data Trust (30 seconds)

Navigate to Data Trust.

> "Trust is everything in predictive maintenance. This page shows sensor data freshness, pipeline status — all 6 Dynamic Tables are ACTIVE — model versions, and prediction confidence. When MCH-003's vibration sensor went stale, the system flagged it and reduced confidence instead of making a false prediction. The system knows what it doesn't know."

### Closing (15 seconds)

> "This entire solution — from database design through 135,000 sensor readings, 6 Dynamic Tables, anomaly detection, failure prediction, incident correlation, work-order automation, email notifications, and this 8-view command center — was built from scratch using CoCo CLI. Every SQL statement, every Streamlit view, every debugging session ran through CoCo. That's the power of AI-assisted development on Snowflake."

---

## 6. Technical Summary

| Component | Count | Technology |
|-----------|-------|-----------|
| RAW Tables | 10 | Snowflake tables with clustering |
| Dynamic Tables | 6 | Auto-refreshing feature pipeline |
| Analytics Tables/Views | 7 | CTAS + views |
| Stored Procedures | 4 | SQL SPs with $$ delimiters |
| Scheduled Task | 1 | 8-hour cycle with email notifications |
| Notification Integration | 1 | Email to maintenance team |
| Streamlit Views | 8 | 641-line Python app in SiS |
| Sensor Readings | 135,360 | 30 days × 15-min intervals × 47 sensors |
| Machines | 12 | 8 types across 3 production lines |
| Incidents | 4 | Correlated from thousands of anomalies |
| Work Orders | 4 | 2 approved, 2 draft (demo-ready) |
| Validation Scenarios | 7 | All passing |

---

## 7. Narrative Flow

```
    CONVERGE OT + IT DATA
            ↓
    PREDICT FAILURE (multi-sensor, confidence-qualified)
            ↓
    EXPLAIN WHY (evidence-backed, traceable)
            ↓
    PRIORITIZE INCIDENT (transparent scoring)
            ↓
    DRAFT + APPROVE WORK ORDER (governed, duplicate-protected)
            ↓
    TAKE MAINTENANCE ACTION (dispatched with email notification)
            ↓
    MEASURE OEE / PRODUCTION IMPACT (tied to business outcomes)
            ↓
    FEED OUTCOME BACK INTO TRUST & VALIDATION (post-repair feedback)
```

Every step is visible in the Streamlit Command Center.
Every step was built with CoCo CLI.

# Predictive Maintenance Command Center — Dashboard Views Guide

Each view in the Streamlit Command Center maps directly to a stage in the predictive maintenance closed-loop story. Every view was built, tested, and iterated using CoCo CLI — from the SQL queries powering each panel to the Streamlit layout code itself.

---

## View 1: Factory Overview

**What it does:**
The entry point for plant supervisors and reliability engineers. Presents a manufacturing-dashboard-style layout with an overall OEE gauge, a 7-day OEE trend chart (Quality, Performance, Availability, OEE), a station summary panel, and individual machine health cards with gauges.

**Problem it solves:**
In a traditional plant, OT sensor data lives in historians, ERP maintenance data in SAP, and production data in MES — none of them talk to each other. A supervisor has no single screen that answers: "Which machines need attention right now, and what's the production impact?"

This view converges all three data domains into one real-time display. Each machine card shows a health score (0–100) computed from multi-sensor analytics, color-coded red/yellow/green, with OEE breakdown and incident status at a glance.

**Key data sources:**
- `STAGING.CROSS_MACHINE_HEALTH` — fleet health scores from the Dynamic Table pipeline
- `ANALYTICS.OEE_METRICS` — Availability × Performance × Quality per machine/day/shift
- `ANALYTICS.INCIDENTS` — active incidents overlaid on machine cards

**Built with CoCo CLI:**
- Dynamic Table pipeline designed and created through CoCo
- SVG gauge charts generated as pure HTML (no Plotly dependency — discovered and fixed via CoCo after SiS compatibility issues)
- OEE calculations validated through CoCo SQL execution

---

## View 2: Incident Triage

**What it does:**
Replaces a raw feed of anomaly alerts with grouped, prioritized incidents. Each incident is an expandable card showing health score, RUL (Remaining Useful Life), confidence level, evidence narrative, and priority drivers. Supervisors can Acknowledge, Draft a Work Order, or mark as False Positive directly from the UI.

**Problem it solves:**
Anomaly detection systems generate thousands of alerts. Without correlation, operators suffer alert fatigue — the same bearing degradation triggers separate vibration, temperature, and current alerts every hour. This view groups related anomalies from the same machine into a single incident and ranks them by a transparent priority score.

**Priority scoring is transparent, not a black box:**
- Health risk (0–30 points)
- Machine criticality (0–20 points)
- Production impact / OEE exposure (0–20 points)
- Repair urgency / RUL proxy (0–20 points)
- Evidence confidence (0–10 points)

The supervisor can see exactly why INC-001 (MCH-001, bearing degradation) scores 77/100 — it's HIGH criticality, DEGRADED production, past the predicted threshold, with HIGH confidence.

**Key data sources:**
- `ANALYTICS.INCIDENTS` — correlated incidents with priority scores
- `RAW.WORK_ORDERS` — shows if a WO already exists (prevents duplicate drafting)

**Built with CoCo CLI:**
- Incident correlation logic designed and SQL authored through CoCo
- Priority formula iterated and validated with CoCo queries
- Streamlit button actions (acknowledge, draft WO, false positive) tested through CoCo

---

## View 3: Machine Detail & Predictive Diagnosis

**What it does:**
Deep-dive into a single machine. Shows synchronized sensor trends (vibration, temperature, current, RPM) over 30 days as line charts with 24-hour rolling averages overlaid. Below the charts: failure forecast table with predicted failure mode, risk horizon, days-to-threshold, and confidence. An evidence panel explains "Why This Alert?" in plain language.

**Problem it solves:**
When an operator reports "machine sounds different," the engineer needs to quickly see: Is vibration actually trending up? Is temperature following? Is this correlated with current draw? What does the prediction say? This view puts all sensor signals on a common timeline with the prediction context, so the engineer can validate or override the system's assessment.

**Key data sources:**
- `STAGING.MACHINE_HEALTH_FEATURES` — hourly aggregates with rolling windows
- `ANALYTICS.FAILURE_FORECASTS` — trend-based predictions with RUL estimates
- `ANALYTICS.FAILURE_ASSESSMENTS` — evidence narrative and recommendation

**Built with CoCo CLI:**
- Rolling window features (6h, 24h, 7d) designed through CoCo
- Trend slope calculation (manual regression since REGR_SLOPE doesn't support sliding windows) debugged via CoCo
- Chart rendering validated — pd.to_datetime and pd.to_numeric coercions added after CoCo-identified type errors

---

## View 4: Root-Cause Copilot

**What it does:**
An investigation workspace with four tabs:
1. **Evidence Summary** — structured narrative of what sensors show, what history suggests, and what operators observed
2. **Sensor Analysis** — last 7 days of each signal with baseline deviation values
3. **Historical Cases** — prior maintenance records matching the same failure mode or machine
4. **Maintenance History** — complete repair log for the selected machine

**Problem it solves:**
Root-cause analysis traditionally requires an experienced engineer to pull data from multiple systems, compare current signals to historical patterns, and recall similar past failures. This view automates that retrieval — when investigating MCH-001's bearing degradation, it surfaces MNT-001 (August 2024, same failure mode, same root cause: spindle bearing wear from high-load operation) and MNT-002 (March 2023, preventive catch).

**Key data sources:**
- `ANALYTICS.FAILURE_ASSESSMENTS` — evidence JSON and narrative
- `STAGING.MACHINE_HEALTH_FEATURES` — recent sensor data with deviation metrics
- `RAW.MAINTENANCE_HISTORY` — historical failures, root causes, actions, costs

**Built with CoCo CLI:**
- Historical similar-case retrieval query designed through CoCo
- Evidence narrative generation built and tested via CoCo SQL
- Tab layout and data flow validated through iterative CoCo Streamlit debugging

---

## View 5: Work Order Management

**What it does:**
Full work-order lifecycle management across tabs (All, DRAFT, APPROVED, RESOLVED). Each work order shows AI-generated problem description, recommended repair actions, estimated repair hours, downtime, and maintenance window. DRAFT orders have Approve/Reject buttons with approver name input. APPROVED orders have a Resolve form capturing actual root cause, parts replaced, repair hours, and technician findings.

**Problem it solves:**
The gap between "the system predicted a failure" and "maintenance actually happens" is where most predictive maintenance projects fail. This view closes that gap with:
- **Governed automation**: work orders are drafted automatically but require human approval
- **Duplicate prevention**: the system blocks a second WO for the same machine + failure mode
- **Post-repair feedback**: capturing actual outcomes validates future predictions

**Key data sources:**
- `RAW.WORK_ORDERS` — full lifecycle table
- `ANALYTICS.INCIDENTS` — linked evidence and health scores
- `ORCHESTRATION.DRAFT_WORK_ORDER` / `APPROVE_WORK_ORDER` / `RESOLVE_WORK_ORDER` — stored procedures

**Built with CoCo CLI:**
- All three stored procedures authored and debugged through CoCo
- Duplicate prevention logic tested via CoCo procedure calls
- Widget key deduplication (DuplicateWidgetID error) fixed through CoCo after SiS testing

---

## View 6: OEE & Production Impact

**What it does:**
Connects maintenance predictions to plant-floor business outcomes. Shows:
- Fleet-wide OEE KPIs (Availability, Performance, Quality, OEE)
- OEE by machine bar chart (7-day average)
- Daily OEE trend line
- Production impact table linking each incident to current OEE, reject rate, and downtime hours at risk

**Problem it solves:**
Maintenance teams often can't answer: "If we delay this repair, what's the production cost?" This view quantifies the business impact of each predicted failure — MCH-001's bearing degradation shows a 10% reject rate and 8 hours of downtime at risk. This transforms maintenance from a cost center conversation into a production-protection conversation.

**Key data sources:**
- `ANALYTICS.OEE_METRICS` — OEE = Availability × Performance × Quality
- `ANALYTICS.PRODUCTION_IMPACT` — links incidents to OEE exposure, units at risk, downtime

**Built with CoCo CLI:**
- OEE formula (A × P × Q) implemented and validated through CoCo SQL
- Production impact view joining incidents to OEE data designed via CoCo
- Decimal/NaN type handling in Streamlit charts fixed through CoCo debugging

---

## View 7: Maintenance History & Reliability

**What it does:**
Reliability analysis dashboard showing:
- Failure mode distribution (bar chart)
- Maintenance cost by machine (bar chart)
- Full maintenance log table
- Repeat failure pattern detection (machines with >1 occurrence of the same failure mode)

**Problem it solves:**
Without historical analysis, plants repeat the same mistakes. This view surfaces patterns — MCH-001 has had BEARING_DEGRADATION twice before, costing $7,700 total with 14 hours of downtime. That pattern, combined with the current prediction, builds a compelling case for proactive bearing replacement on a schedule rather than waiting for failure.

**Key data sources:**
- `RAW.MAINTENANCE_HISTORY` — 10 historical records with root causes, costs, parts
- `RAW.MACHINES` — machine metadata for context

**Built with CoCo CLI:**
- Maintenance history data generated with realistic failure patterns through CoCo
- Repeat failure detection query authored via CoCo
- Cost aggregation validated through CoCo SQL

---

## View 8: Data & Model Trust

**What it does:**
Transparency dashboard for the predictive system itself:
- **Sensor Data Freshness** — minutes since last reading per sensor, bad quality percentage
- **Dynamic Table Pipeline Status** — all 6 DTs with scheduling state and last refresh
- **Model / Rule Versions** — which model generated each prediction
- **Prediction Confidence Distribution** — how many forecasts are HIGH/MEDIUM/LOW/INSUFFICIENT
- **Fallback Cases** — machines where the system recommends manual inspection instead of automated assessment

**Problem it solves:**
Trust is the #1 barrier to predictive maintenance adoption. If operators don't trust the predictions, they ignore them. This view makes the system's limitations visible:
- MCH-003's vibration sensor has 488 STALE readings — the system flags this and reduces prediction confidence
- When evidence is insufficient, the system routes to MANUAL_INSPECTION_RECOMMENDED instead of making an overconfident claim
- Model versions are tracked so predictions are auditable

**Key data sources:**
- `STAGING.SENSOR_READINGS_CLEAN` — freshness and quality metrics
- `IOT_PREDICTIVE_MAINTENANCE.INFORMATION_SCHEMA.DYNAMIC_TABLES()` — pipeline health
- `ANALYTICS.FAILURE_FORECASTS` — confidence distribution
- `ANALYTICS.FAILURE_ASSESSMENTS` — fallback states

**Built with CoCo CLI:**
- INFORMATION_SCHEMA query replaced SHOW DYNAMIC TABLES after CoCo identified a Snowpark column-count parsing bug
- Reserved keyword "ROWS" quoted after CoCo caught the SQL compilation error
- Sensor quality flags (STALE, SUSPECT, MISSING) designed and validated through CoCo

---

## How the Views Connect — The Closed-Loop Story

```
VIEW 1: Factory Overview     →  "MCH-001 is CRITICAL, health 77/100"
    ↓
VIEW 2: Incident Triage      →  "INC-001, priority 77, bearing degradation predicted"
    ↓
VIEW 3: Machine Detail       →  "Vibration 4→13 mm/s over 30 days, temp+current following"
    ↓
VIEW 4: Root-Cause Copilot   →  "Same failure in Aug 2024, same root cause, same machine"
    ↓
VIEW 5: Work Orders          →  "WO-0001 drafted with repair actions, approved by supervisor"
    ↓
VIEW 6: OEE & Production     →  "10% reject rate, 8h downtime at risk if we don't act"
    ↓
VIEW 7: Maintenance History  →  "Third bearing failure — time to change the PM schedule"
    ↓
VIEW 8: Data Trust           →  "All pipelines active, HIGH confidence, models versioned"
```

Every view was authored, debugged, and validated using CoCo CLI — from initial SQL design through Streamlit rendering fixes (hide_index, st.rerun, Plotly removal, Decimal type handling, DuplicateWidgetID resolution).

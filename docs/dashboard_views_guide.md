# Predictive Maintenance Command Center — Dashboard Views Guide

Each view in the Streamlit Command Center maps directly to a stage in the predictive maintenance closed-loop story. Every view was built, tested, and iterated using CoCo CLI — from the SQL queries powering each panel to the Streamlit layout code itself. AI agents (Cortex LLM and Cortex Search) are integrated at runtime across investigation, narrative generation, and work-order drafting.

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
Replaces a raw feed of anomaly alerts with grouped, prioritized incidents. Each incident is an expandable card showing health score, RUL (Remaining Useful Life), confidence level, AI-generated evidence narrative, and priority drivers. Supervisors can Acknowledge, **AI Draft a Work Order** (using Cortex LLM), or mark as False Positive directly from the UI.

**Problem it solves:**
Anomaly detection systems generate thousands of alerts. Without correlation, operators suffer alert fatigue — the same bearing degradation triggers separate vibration, temperature, and current alerts every hour. This view groups related anomalies from the same machine into a single incident and ranks them by a transparent priority score.

**Priority scoring is transparent, not a black box:**
- Health risk (0–30 points)
- Machine criticality (0–20 points)
- Production impact / OEE exposure (0–20 points)
- Repair urgency / RUL proxy (0–20 points)
- Evidence confidence (0–10 points)

**AI Agent role:**
When the supervisor clicks "AI Draft Work Order", the system calls `ORCHESTRATION.AI_DRAFT_WORK_ORDER` which uses `SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b')` to:
1. Generate a technical problem description from the sensor evidence JSON
2. Generate a step-by-step repair checklist tailored to the machine type and failure mode
The AI output replaces the previous hardcoded template strings with context-aware, specific repair guidance.

**Key data sources:**
- `ANALYTICS.INCIDENTS` — correlated incidents with priority scores
- `RAW.WORK_ORDERS` — shows if a WO already exists (prevents duplicate drafting)

**Built with CoCo CLI:**
- Incident correlation logic designed and SQL authored through CoCo
- AI work-order drafting procedure created and tested through CoCo
- Streamlit button actions (acknowledge, AI draft WO, false positive) tested through CoCo

---

## View 3: Machine Detail & Predictive Diagnosis

**What it does:**
Deep-dive into a single machine. Shows synchronized sensor trends (vibration, temperature, current, RPM) over 30 days as line charts with 24-hour rolling averages overlaid. Below the charts: failure forecast table with predicted failure mode, risk horizon, days-to-threshold, and confidence. An evidence panel explains "Why This Alert?" using an **AI-generated narrative** — not a template.

**Problem it solves:**
When an operator reports "machine sounds different," the engineer needs to quickly see: Is vibration actually trending up? Is temperature following? Is this correlated with current draw? What does the prediction say?

**AI Agent role:**
The "Why This Alert?" evidence panel displays an AI-generated narrative created by `ORCHESTRATION.AI_GENERATE_FAILURE_NARRATIVE`, which calls `SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b')` with the machine's full evidence JSON (sensor trends, maintenance history, operator observations, production status). The LLM produces a specific, data-grounded explanation — for example:

> "A bearing degradation failure mode is likely developing, as evidenced by the increasing temperature trend (1.56°C/day) and vibration trend (0.31 mm/s/day). The operator's observation of a slight burning smell from the spindle housing area supports this conclusion. The situation is urgent, with a 9.88% reject rate and temperature already at 90.94°C."

**Key data sources:**
- `STAGING.MACHINE_HEALTH_FEATURES` — hourly aggregates with rolling windows
- `ANALYTICS.FAILURE_FORECASTS` — trend-based predictions with RUL estimates
- `ANALYTICS.FAILURE_ASSESSMENTS` — AI-generated evidence narrative

**Built with CoCo CLI:**
- Rolling window features (6h, 24h, 7d) designed through CoCo
- AI narrative generation procedure authored and tested via CoCo
- `SNOWFLAKE.CORTEX.COMPLETE` integration validated with real evidence data through CoCo

---

## View 4: Root-Cause Copilot (AI-Powered)

**What it does:**
An AI-powered investigation workspace with five tabs:
1. **AI Copilot** — interactive chat where users ask free-form questions about any machine and get AI responses grounded in sensor evidence and maintenance history
2. **Evidence Summary** — AI-generated narrative of what sensors show, what history suggests, and what operators observed
3. **Sensor Analysis** — last 7 days of each signal with baseline deviation values
4. **Historical Cases** — prior maintenance records matching the same failure mode or machine (powered by Cortex Search Service)
5. **Maintenance History** — complete repair log for the selected machine

**Problem it solves:**
Root-cause analysis traditionally requires an experienced engineer to pull data from multiple systems, compare current signals to historical patterns, and recall similar past failures. This view replaces that manual process with an AI copilot that can answer natural-language questions using the machine's actual data as context.

**AI Agent role — this is the primary AI interaction point:**

The **AI Copilot tab** lets users ask questions like:
- "Why is this machine flagged as critical?"
- "What changed first before the alert?"
- "Has this failure happened before? What was the root cause?"
- "What production impact should we expect if we delay?"
- "Is the required part available?"

When the user clicks "Ask AI", the system:
1. Retrieves the machine's `EVIDENCE_JSON` from `FAILURE_ASSESSMENTS`
2. Retrieves the machine's last 3 maintenance records from `MAINTENANCE_HISTORY`
3. Constructs a structured prompt with all context
4. Calls `SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b')` to generate a grounded answer
5. Displays the AI response with specific sensor values and historical data cited

The **Historical Cases tab** is backed by `APP.MAINTENANCE_SEARCH`, a **Cortex Search Service** that provides semantic search over all maintenance records. This enables finding similar failure patterns even when the failure mode name doesn't exactly match.

**Key data sources:**
- `ANALYTICS.FAILURE_ASSESSMENTS` — evidence JSON fed to LLM as context
- `RAW.MAINTENANCE_HISTORY` — historical records fed to LLM as context
- `APP.MAINTENANCE_SEARCH` — Cortex Search Service for semantic similar-case retrieval
- `STAGING.MACHINE_HEALTH_FEATURES` — sensor data for analysis tab
- `SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b')` — LLM for interactive Q&A

**Built with CoCo CLI:**
- AI Copilot prompt engineering designed and iterated through CoCo
- Cortex Search Service created over maintenance knowledge base through CoCo
- Evidence-grounded prompting tested with multiple question types via CoCo

---

## View 5: Work Order Management

**What it does:**
Full work-order lifecycle management across tabs (All, DRAFT, APPROVED, RESOLVED). Each work order shows **AI-generated** problem description and repair checklist, estimated repair hours, downtime, and maintenance window. DRAFT orders have Approve/Reject buttons. APPROVED orders have a Resolve form capturing actual root cause, parts replaced, repair hours, and technician findings.

**Problem it solves:**
The gap between "the system predicted a failure" and "maintenance actually happens" is where most predictive maintenance projects fail. This view closes that gap with:
- **AI-powered drafting**: Cortex LLM generates technical problem descriptions and repair checklists tailored to the specific machine and failure mode
- **Governed automation**: work orders require human approval before dispatch
- **Duplicate prevention**: the system blocks a second WO for the same machine + failure mode
- **Post-repair feedback**: capturing actual outcomes validates future predictions
- **Email notifications**: approved work orders trigger email alerts to the maintenance team

**AI Agent role:**
Work orders are created by `ORCHESTRATION.AI_DRAFT_WORK_ORDER`, which makes two separate `CORTEX.COMPLETE` calls:
1. First call generates a 2-3 sentence technical problem description from the evidence
2. Second call generates a 5-7 step repair checklist specific to the machine type and failure mode

This produces work orders like:
> **Problem:** "MCH-001's spindle bearing is exhibiting accelerated wear patterns with vibration increasing at 0.31 mm/s per day and temperature at 1.56°C per day. Current readings of 12.8 mm/s vibration and 90.9°C exceed warning thresholds, consistent with the two prior bearing failures on this machine."
>
> **Actions:** "1. Lockout/tagout machine and isolate power. 2. Remove spindle housing cover and inspect bearing races for scoring. 3. Measure bearing clearance with dial indicator. 4. Replace bearings if clearance exceeds 0.05mm spec. 5. Flush and refill lubrication system. 6. Verify spindle alignment with laser tool. 7. Run test cycle at 50% then 100% load, verify vibration < 4 mm/s."

**Key data sources:**
- `RAW.WORK_ORDERS` — full lifecycle table
- `ANALYTICS.INCIDENTS` — linked evidence and health scores
- `ORCHESTRATION.AI_DRAFT_WORK_ORDER` — AI-powered stored procedure
- `ORCHESTRATION.APPROVE_WORK_ORDER` / `RESOLVE_WORK_ORDER` — approval and feedback SPs

**Built with CoCo CLI:**
- AI drafting procedure authored and tested through CoCo
- Duplicate prevention and approval logic debugged via CoCo
- Email notification integration created through CoCo

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

---

## View 7: Maintenance History & Reliability

**What it does:**
Reliability analysis dashboard showing:
- Failure mode distribution (bar chart)
- Maintenance cost by machine (bar chart)
- Full maintenance log table
- Repeat failure pattern detection (machines with >1 occurrence of the same failure mode)

**Problem it solves:**
Without historical analysis, plants repeat the same mistakes. This view surfaces patterns — MCH-001 has had BEARING_DEGRADATION twice before, costing $7,700 total with 14 hours of downtime. That pattern, combined with the current AI-generated prediction, builds a compelling case for proactive bearing replacement.

**Key data sources:**
- `RAW.MAINTENANCE_HISTORY` — 10 historical records with root causes, costs, parts
- `RAW.MACHINES` — machine metadata for context

**Built with CoCo CLI:**
- Maintenance history data generated with realistic failure patterns through CoCo
- Repeat failure detection query authored via CoCo

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
- AI-generated narratives are shown alongside the evidence JSON they were derived from, so users can verify the AI's reasoning

**Key data sources:**
- `STAGING.SENSOR_READINGS_CLEAN` — freshness and quality metrics
- `IOT_PREDICTIVE_MAINTENANCE.INFORMATION_SCHEMA.DYNAMIC_TABLES()` — pipeline health
- `ANALYTICS.FAILURE_FORECASTS` — confidence distribution
- `ANALYTICS.FAILURE_ASSESSMENTS` — fallback states

**Built with CoCo CLI:**
- INFORMATION_SCHEMA query replaced SHOW DYNAMIC TABLES after CoCo identified a Snowpark column-count parsing bug
- Sensor quality flags (STALE, SUSPECT, MISSING) designed and validated through CoCo

---

## Where AI Agents Operate — Summary

| View | AI Feature | Snowflake Component |
|------|-----------|-------------------|
| **Incident Triage** | "AI Draft Work Order" button generates LLM-written problem description + repair checklist | `CORTEX.COMPLETE('llama3.1-70b')` via `AI_DRAFT_WORK_ORDER` SP |
| **Machine Detail** | "Why This Alert?" panel shows AI-generated failure narrative from sensor evidence | `CORTEX.COMPLETE('llama3.1-70b')` via `AI_GENERATE_FAILURE_NARRATIVE` SP |
| **Root-Cause Copilot** | Interactive AI chat — ask any question, get evidence-grounded answers | `CORTEX.COMPLETE('llama3.1-70b')` called from Streamlit with structured prompt |
| **Root-Cause Copilot** | Semantic search over maintenance knowledge base for similar-case retrieval | `CORTEX SEARCH SERVICE` on `APP.MAINTENANCE_KNOWLEDGE` |
| **Work Orders** | AI-generated problem descriptions and repair checklists displayed in each WO | Created by `AI_DRAFT_WORK_ORDER` at draft time |
| **Scheduled Task** | Every 8 hours: scans incidents, sends email alerts for critical/high items | `SYSTEM$SEND_EMAIL` via `RUN_MAINTENANCE_CYCLE` SP |

---

## How the Views Connect — The Closed-Loop Story

```
VIEW 1: Factory Overview     →  "MCH-001 is CRITICAL, health 77/100"
    ↓
VIEW 2: Incident Triage      →  "INC-001, priority 77 — click AI Draft Work Order"
    ↓                              [AI generates problem description + repair steps]
VIEW 3: Machine Detail       →  "Vibration 4→13 mm/s over 30 days"
    ↓                              [AI explains: bearing degradation, 1.56°C/day rise, 9.88% rejects]
VIEW 4: Root-Cause Copilot   →  "Ask AI: Why is this critical? What failed before?"
    ↓                              [AI answers using sensor evidence + maintenance history]
VIEW 5: Work Orders          →  "WO-0001: AI-written repair checklist, supervisor approved"
    ↓                              [Email notification dispatched]
VIEW 6: OEE & Production     →  "10% reject rate, 8h downtime at risk"
    ↓
VIEW 7: Maintenance History  →  "Third bearing failure — AI pattern matches Aug 2024"
    ↓
VIEW 8: Data Trust           →  "All pipelines active, HIGH confidence, AI narratives auditable"
```

Every view was authored, debugged, and validated using CoCo CLI. AI agents (Cortex LLM and Cortex Search) are embedded at runtime in Views 2, 3, 4, and 5 — transforming the application from a rule-based dashboard into an AI-powered maintenance copilot.

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
- When AI is used, it's a black box — operators don't trust it, so they ignore it

### What's needed

A system that:
1. Converges OT sensor signals with maintenance history, production data, and human observations
2. Predicts failures using multi-sensor correlation, not just single-signal thresholds
3. **Uses AI to explain WHY a failure is predicted** with traceable, evidence-backed narratives
4. Groups alerts into actionable incidents instead of flooding operators
5. **Uses AI to draft work orders** with specific, context-aware repair actions — not templates
6. Keeps humans in the approval loop for governed action
7. **Provides an AI copilot** that engineers can interrogate in natural language
8. Ties maintenance risk directly to OEE and production impact
9. Builds trust through transparency — confidence levels, data quality, and auditable AI reasoning

---

## 2. How We Solved It

### Snowflake-native predictive maintenance with embedded AI agents, built entirely with CoCo CLI

We built a complete, ground-up predictive maintenance command center on Snowflake — no external ML platforms, no separate application stacks. **Cortex AI agents are embedded at runtime** for failure explanation, work-order generation, and interactive investigation. The entire solution was designed, authored, debugged, and validated using CoCo CLI.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    IOT_PREDICTIVE_MAINTENANCE                              │
│                                                                             │
│  ┌──────────┐    ┌──────────┐    ┌───────────┐    ┌──────────────────────┐ │
│  │   RAW     │───>│ STAGING  │───>│ ANALYTICS │───>│        APP           │ │
│  │          │    │          │    │           │    │                      │ │
│  │ 10 tables│    │ 5 Dynamic│    │ 7 tables/ │    │ Streamlit (8 views)  │ │
│  │ 135K+    │    │ Tables   │    │ views     │    │ + Cortex Search Svc  │ │
│  │ readings │    │          │    │           │    │                      │ │
│  └──────────┘    └──────────┘    └───────────┘    └──────────────────────┘ │
│                                                                             │
│  ┌────────────────────┐    ┌───────────────────────────────────────────┐   │
│  │  ORCHESTRATION      │    │          AI AGENT LAYER                   │   │
│  │ 4 SPs + Task +     │    │                                           │   │
│  │ Email Notifications │    │  CORTEX.COMPLETE('llama3.1-70b')         │   │
│  │                     │    │  → AI failure narratives                  │   │
│  │ AI_DRAFT_WORK_ORDER │    │  → AI work-order drafting                │   │
│  │ AI_GENERATE_FAILURE │    │  → Interactive AI copilot                │   │
│  │ _NARRATIVE          │    │                                           │   │
│  │                     │    │  CORTEX SEARCH SERVICE                    │   │
│  │ RUN_MAINTENANCE     │    │  → Semantic maintenance knowledge search  │   │
│  │ _CYCLE (8hr task)   │    │                                           │   │
│  └────────────────────┘    └───────────────────────────────────────────┘   │
│                                                                             │
│  Warehouse: IOT_PM_WH (MEDIUM)                                             │
└─────────────────────────────────────────────────────────────────────────────┘
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
    │ State, load,    │ │FEATURES    │ │ Shift/7d       │
    │ suppression     │ │(DT3)       │ │ comparisons    │
    └────────┬────────┘ │ 1h/6h/24h  │ └───────┬────────┘
             │          │ rolling    │         │
             │          └─────┬──────┘         │
             └────────┬───────┘                │
            ┌─────────▼───────────┐            │
            │ CROSS_MACHINE_HEALTH │  DT5: Fleet health     │
            │  (Dynamic Table)     │       scores 0-100      │
            └─────────┬───────────┘            │
            ┌─────────▼───────────┐            │
            │ MAINTENANCE_CONTEXT  │  DT6: Enriched with    │
            │  (Dynamic Table)     │◄──────────┘ history,
            └─────────┬───────────┘   operator obs, parts
                      │
        ┌─────────────┼─────────────────┐
        │             │                 │
   ┌────▼────┐  ┌────▼──────┐  ┌───────▼──────┐
   │DETECTED │  │FAILURE    │  │FAILURE       │
   │ANOMALIES│  │FORECASTS  │  │ASSESSMENTS   │
   └────┬────┘  └────┬──────┘  │ + AI NARRATIVE│
        │             │         └───────┬──────┘
        └─────────────┼─────────────────┘
              ┌───────▼────────┐
              │   INCIDENTS     │  Correlated, prioritized
              └───────┬────────┘
              ┌───────▼────────┐
              │  AI WORK ORDER  │  LLM-drafted problem +
              │  DRAFTING       │  repair checklist
              └───────┬────────┘
              ┌───────▼────────┐
              │  HUMAN APPROVAL │  Governed gate
              └───────┬────────┘
              ┌───────▼────────┐
              │  EMAIL DISPATCH  │  SYSTEM$SEND_EMAIL
              └───────┬────────┘
              ┌───────▼────────┐
              │  POST-REPAIR    │  Feedback loop
              │  FEEDBACK       │
              └────────────────┘
```

### Where AI Agents Operate at Runtime

| Component | AI Feature | Snowflake Technology |
|-----------|-----------|---------------------|
| **Failure Narratives** | LLM explains WHY a failure is predicted, citing specific sensor values, trends, operator observations, and prior failures | `SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b')` |
| **Work-Order Drafting** | LLM generates technical problem descriptions and step-by-step repair checklists specific to the machine type and failure mode | `SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b')` |
| **Interactive Copilot** | Engineers ask free-form questions about any machine — AI responds using sensor evidence + maintenance history as grounding context | `SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b')` |
| **Knowledge Search** | Semantic search over maintenance records finds similar past failures even when terminology doesn't exactly match | `CORTEX SEARCH SERVICE` |
| **Email Alerts** | Automated email dispatch for critical incidents and approved work orders | `SYSTEM$SEND_EMAIL` |

### What makes this different

| Traditional Approach | Our Solution |
|---------------------|--------------|
| Single-signal threshold alerts | Multi-sensor correlation (vibration + temp + current + RPM) |
| Thousands of uncorrelated alerts | Incident grouping — one incident per machine per failure mode |
| Opaque "AI score" | Transparent priority: health risk + criticality + production impact + RUL + confidence |
| Template work orders | **AI-generated** problem descriptions + repair checklists via Cortex LLM |
| No explanation for predictions | **AI narratives** citing specific sensor values, trends, and prior history |
| No interactive investigation | **AI Copilot** — ask questions in natural language, get evidence-grounded answers |
| Separate ML platform | Snowflake-native: Dynamic Tables + Cortex LLM + Cortex Search |
| Uncontrolled automation | Governed: AI drafts, humans approve, email dispatches |
| No production context | OEE (A × P × Q) tied directly to each incident |
| No feedback loop | Post-repair outcome capture validates predictions |

---

## 3. CoCo CLI Throughout the Lifecycle

CoCo was the primary development tool across every phase — and it built the AI integrations too.

### Planning Phase
- Analyzed the 708-line proposal document
- Created the structured execution plan (80+ tasks across 12 steps)
- Designed the database schema, pipeline architecture, and AI integration points

### Development Phase
- Created all database objects: 10 RAW tables, 6 Dynamic Tables, 7 analytics tables/views
- Generated 135K+ synthetic sensor readings with realistic degradation patterns
- Built the rolling-window feature engineering pipeline
- Authored anomaly detection, failure forecasting, and failure assessment logic
- Created AI-powered stored procedures (`AI_GENERATE_FAILURE_NARRATIVE`, `AI_DRAFT_WORK_ORDER`)
- Created Cortex Search Service over maintenance knowledge base
- Built the 668-line, 8-view Streamlit command center with embedded AI copilot

### Debugging Phase (real issues caught and fixed via CoCo)
- `hide_index=True` not supported in SiS — removed from all 13 dataframes
- `st.rerun()` not available — replaced with compatibility shim
- `plotly` not installed in SiS — replaced with pure SVG gauge charts
- `SHOW DYNAMIC TABLES` column count mismatch — switched to INFORMATION_SCHEMA
- `ROWS` reserved keyword — quoted in SQL
- `DuplicateWidgetID` — added tab-index prefixes to widget keys
- Snowflake `Decimal` type — added `safe_float()` helper
- `NaN` from LEFT JOINs — added `pd.notna()` guards

### Testing & Validation Phase
- Validated all 7 demo scenarios
- Tested AI narrative quality for MCH-001, MCH-005, MCH-009, MCH-008
- Verified AI work-order drafting produces machine-specific repair steps
- Confirmed email notification delivery
- Tested interactive AI copilot with multiple question types

---

## 4. Seeded Demo Scenarios

| # | Machine | Scenario | What to Show |
|---|---------|----------|-------------|
| 1 | MCH-001 (CNC Lathe Alpha) | Bearing degradation | Full closed-loop with AI: sensor trends → AI narrative → AI work order → approval → email → OEE impact |
| 2 | MCH-005 (CNC Mill Gamma) | Spindle misalignment | AI generates different repair checklist for misalignment vs bearing failure |
| 3 | MCH-009 (Hydraulic Press 2) | Hydraulic seal failure | Different machine type, different AI-generated actions (depressurize, inspect seals) |
| 4 | MCH-008 (Grinding Station 1) | Wheel imbalance | MEDIUM priority — AI copilot explains why this is less urgent |
| 5 | MCH-003 (Hydraulic Press 1) | Sensor fault | System reduces confidence, recommends manual inspection — AI doesn't over-claim |
| 6 | MCH-006 (Robotic Welder 1) | High-load normal | System correctly ignores — no AI narrative generated, ROUTINE_MONITORING |

---

## 5. Demo Script (5-Minute Walkthrough)

### Opening (15 seconds)

> "This is a predictive maintenance command center built on Snowflake with embedded Cortex AI agents — using CoCo CLI as the sole development tool. It converges sensor data with maintenance history and production records. What makes it different: AI doesn't just detect anomalies — it explains them, drafts repair actions, and answers engineer questions in natural language."

### Scene 1: Factory Overview (30 seconds)

Open the Factory Overview page.

> "12 machines, 3 production lines. The OEE gauge shows current plant performance at 14%. The 7-day trend tracks Quality, Performance, Availability, and OEE. The station summary shows 1 critical and 1 high-priority incident."

Point to the machine cards.

> "Each machine has a health gauge. MCH-001, our CNC Lathe, is the most urgent — health score 77, bearing degradation predicted."

### Scene 2: Incident Triage + AI Work Order (60 seconds)

Navigate to Incident Triage. Expand INC-001.

> "The system correlated thousands of anomaly events into 4 incidents. INC-001 scores 77 out of 100 — and the priority drivers are transparent: health risk, HIGH criticality, DEGRADED production, past the predicted threshold, HIGH confidence."

Point to the evidence narrative.

> "This isn't a template — it's an AI-generated assessment from Cortex LLM. It cites specific numbers: vibration at 0.31 mm/s per day, temperature at 1.56°C per day, 9.88% reject rate."

Click "AI Draft Work Order" on INC-003 or INC-004 (one that's still NEW).

> "Watch this — I'll click AI Draft Work Order. The system calls Snowflake Cortex to generate a technical problem description AND a step-by-step repair checklist tailored to this specific machine type and failure mode."

Wait for the spinner to complete, show the success message.

> "The AI drafted the work order. Let's see it in the Work Orders view."

### Scene 3: Machine Detail (30 seconds)

Navigate to Machine Detail, select MCH-001.

> "Here are the raw sensor trends over 30 days. Vibration started at 4 and has risen to nearly 13. Temperature and current follow the same pattern — classic bearing degradation."

Point to "Why This Alert?" section.

> "The AI explains: bearing degradation likely, temperature trend 1.56°C per day, operator reported burning smell, recommend immediate action. All grounded in the actual evidence."

### Scene 4: AI Copilot — The Key AI Demo (60 seconds)

Navigate to Root-Cause Copilot, select INC-001. The AI Copilot tab is first.

> "This is where the AI agent really shines. I can ask any question about this machine."

Type: "Has this failure happened before? What was the root cause and repair?"

Click "Ask AI". Wait for response.

> "The AI found the prior failure from August 2024 — same root cause: spindle bearing wear from high-load operation. It cost $4,500 and took 6 hours. The AI is grounding its answer in the actual maintenance records."

Type another question: "What production impact if we delay 3 days?"

Click "Ask AI". Wait for response.

> "The AI calculates the risk based on current reject rate trends and production volume. This is an AI copilot for maintenance engineers — it doesn't just show data, it reasons about it."

### Scene 5: Work Orders + Approval (30 seconds)

Navigate to Work Orders. Show the AI-drafted work order.

> "Here's the AI-generated work order. The problem description and repair steps were written by Cortex LLM, not a template. A supervisor reviews and approves — we never dispatch maintenance without human approval."

Approve WO-0003 or WO-0004 live.

> "Approved — and an email notification has been sent to the maintenance team."

### Scene 6: OEE + Data Trust (30 seconds)

Navigate to OEE & Production.

> "MCH-001's reject rate is at 10%, with 8 hours of downtime at risk. Every prediction connects to production impact."

Navigate to Data Trust.

> "And transparency is built in — sensor freshness, pipeline status, prediction confidence, and when the AI doesn't have enough data, it says so instead of guessing."

### Closing (15 seconds)

> "To summarize: Cortex AI agents are embedded throughout this application — generating failure explanations, drafting work orders, answering engineer questions, and searching maintenance knowledge. The entire solution — 135,000 sensor readings, 6 Dynamic Tables, AI-powered procedures, email notifications, and this 8-view command center — was built from scratch using CoCo CLI. That's AI-native predictive maintenance on Snowflake."

---

## 6. Technical Summary

| Component | Count | Technology |
|-----------|-------|-----------|
| RAW Tables | 10 | Snowflake tables with clustering |
| Dynamic Tables | 6 | Auto-refreshing feature pipeline |
| Analytics Tables/Views | 7 | CTAS + views |
| AI-Powered Stored Procedures | 2 | `CORTEX.COMPLETE('llama3.1-70b')` |
| Standard Stored Procedures | 3 | SQL SPs (approve, resolve, maintenance cycle) |
| Cortex Search Service | 1 | Semantic search over maintenance knowledge |
| Scheduled Task | 1 | 8-hour cycle with email notifications |
| Notification Integration | 1 | Email to maintenance team |
| Streamlit Views | 8 | 668-line Python app with embedded AI copilot |
| Sensor Readings | 135,360 | 30 days × 15-min intervals × 47 sensors |
| Machines | 12 | 8 types across 3 production lines |
| Incidents | 4 | Correlated from thousands of anomalies |
| Work Orders | 4 | AI-drafted, 2 approved, 2 draft (demo-ready) |
| Validation Scenarios | 7 | All passing |

---

## 7. Narrative Flow

```
    CONVERGE OT + IT DATA
            ↓
    PREDICT FAILURE (multi-sensor, confidence-qualified)
            ↓
    AI EXPLAINS WHY (Cortex LLM generates evidence-backed narrative)
            ↓
    PRIORITIZE INCIDENT (transparent scoring)
            ↓
    AI DRAFTS WORK ORDER (Cortex LLM writes problem + repair steps)
            ↓
    HUMAN APPROVES (governed gate)
            ↓
    DISPATCH + EMAIL NOTIFICATION (SYSTEM$SEND_EMAIL)
            ↓
    AI COPILOT ANSWERS QUESTIONS (interactive investigation)
            ↓
    MEASURE OEE / PRODUCTION IMPACT (tied to business outcomes)
            ↓
    FEED OUTCOME BACK (post-repair feedback validates predictions)
```

Every step is visible in the Streamlit Command Center.
Every step was built with CoCo CLI.
AI agents operate at runtime in 4 of 8 views.

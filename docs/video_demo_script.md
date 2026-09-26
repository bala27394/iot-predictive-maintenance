# Video Demo Script: IoT Predictive Maintenance Platform
# Duration: 5 minutes | Screen recording with CoCo CLI + Snowsight
# Format: [TIMESTAMP] ACTION | NARRATION

---

## PRE-RECORDING SETUP

Before hitting record:
1. Open CoCo CLI (full screen, dark theme, font size 16+)
2. Ensure connection is active: `cortex connections list` should show pa80558
3. Have Snowsight open in a browser tab (logged in, Streamlit app bookmarked)
4. Open your email (bbalamu5@ford.com) in another browser tab -- you will show a live email arriving
5. Clear the CoCo CLI screen

---

## SCRIPT

---

### [0:00 - 0:25] OPENING -- The Problem + What We Built

**NARRATION:**
"Manufacturers lose billions to unplanned downtime -- not because they lack sensor data, but because that data is disconnected from maintenance history, operator observations, and production quality. We built a platform that converges all of it -- and we built it entirely through Snowflake's CoCo CLI."

**ON SCREEN:**
Type in CoCo CLI:

```
Show me the current state of the IoT Predictive Maintenance database -- table counts and row counts across all schemas
```

**EXPECTED OUTPUT:**
CoCo runs SQL and returns all 6 schemas with object counts:
- RAW: 13 tables (320K+ rows)
- STAGING: 5 dynamic tables
- ANALYTICS: 3 tables + 1 DT
- ML_MODELS: 8 models + 13 views
- ORCHESTRATION: 3 SPs + 1 task
- APP: semantic view + Streamlit

**NARRATION (over results):**
"13 raw tables, 5 dynamic tables, 8 ML models, 3 agentic stored procedures, a Streamlit dashboard, and a semantic view. All created through CoCo conversations across 3 sessions."

---

### [0:25 - 1:00] SKILL 1 -- Dynamic Table Pipeline (Data Convergence)

**NARRATION:**
"First capability: real-time data convergence. CoCo built a 5-layer dynamic table pipeline that cleans sensor data, computes rolling health features, and scores every machine."

**ON SCREEN:**
Type:

```
Show me the health status of all machines ranked by concern level from the CROSS_MACHINE_HEALTH dynamic table
```

**EXPECTED OUTPUT:**
50 rows sorted by health score. Top 5 are CRITICAL: MCH-0047 (37.7), MCH-0025 (38.6), MCH-0031 (39.0), MCH-0003 (39.2), MCH-0012 (39.4).

**NARRATION:**
"A composite health score from 0 to 100 for every machine. The 5 machines we seeded with degradation patterns are correctly ranked as the most critical. This refreshes automatically."

**ON SCREEN:**
Type:

```
Show the anomaly context for MCH-0047 -- sensor data joined with operator observations, production metrics, and power events
```

**EXPECTED OUTPUT:**
Rows showing sensor readings alongside OPERATOR_OBSERVATION (SMELL), PERFORMANCE_STATUS (DEGRADED), POWER_EVENT (VOLTAGE_SAG), LAST_FAILURE_TYPE.

**NARRATION:**
"This is the IT-OT convergence. One row shows: vibration spiked, operator reported a burning smell, reject rate hit 19%, and a voltage sag occurred -- six data domains in one unified view."

---

### [1:00 - 1:40] SKILL 2 -- ML Detection + AI Work Order Drafting

**NARRATION:**
"Second capability: ML anomaly detection with AI work order generation."

**ON SCREEN:**
Type:

```
Show anomaly detection results for the failing machines -- how many anomalies detected and at what confidence
```

**EXPECTED OUTPUT:**
MCH-0003: 83%, MCH-0031: 87%, MCH-0025: 55%, MCH-0047: 58% anomaly rates.

**NARRATION:**
"55 to 87 percent hit rates on known failing machines. 3,249 total anomalies: 192 critical, 1,547 high, 1,510 low."

**ON SCREEN:**
Type:

```
Show the AI-generated work order for MCH-0047 -- title, problem description, and recommended actions
```

**EXPECTED OUTPUT:**
- Title: "Urgent: MCH-0047 Pump Vibration Anomaly Repair..."
- Problem: AI-written synthesis referencing health score 37.7, burnt smell, 19% reject rate
- Actions: 4-step numbered checklist
- Rental Recommended: TRUE

**NARRATION:**
"This work order was written by llama3.1-70b. It received sensor data, operator logs, production metrics, and maintenance history -- and produced a problem description referencing the burnt smell the operator reported and specific recommended actions. It even flagged that a rental pump should be arranged."

---

### [1:40 - 2:40] DASHBOARD WALKTHROUGH -- The Command Center

**NARRATION:**
"CoCo built and deployed a 7-view Streamlit dashboard as the maintenance command center. Let me walk through it."

**ON SCREEN:**
Switch to browser. Open the Streamlit dashboard in Snowsight.

---

**VIEW 1: Factory Floor Overview** (show for ~10 seconds)

**What the audience sees:**
- 4 KPI cards: Total Machines: 50 | Critical: 5 | Warning: 0 | Avg Health Score: ~65
- A color-coded table of all 50 machines sorted worst-first
- Top 5 rows in red (CRITICAL), rest in yellow (FAIR) and green (GOOD)

**NARRATION:**
"Factory Floor Overview. The plant manager sees all 50 machines at a glance -- 5 are critical, shown in red. Health scores, anomaly counts, and the most concerning sensor for each machine, all in one table."

---

**VIEW 2: Machine Detail** (select MCH-0047, show for ~15 seconds)

Click "Machine Detail" in the sidebar. Select MCH-0047 from the dropdown.

**What the audience sees:**
- 3 metric cards: Machine Type: PUMP | Health Score: 37.7 | Status: CRITICAL
- A vibration time-series line chart showing a clear upward trend -- healthy baseline around 1.3 mm/s climbing to 4.5+ mm/s
- An anomaly table showing CRITICAL-severity detections with anomaly scores of 1.0
- A 14-day forecast chart showing vibration predicted to rise from 3.81 to 4.61

**NARRATION:**
"Drill into MCH-0047. The vibration chart shows clear degradation over time. The anomaly table confirms the ML model is flagging every recent reading. And the 14-day forecast predicts vibration will keep climbing -- this machine needs maintenance now, not next week."

---

**VIEW 3: Anomaly Feed** (show for ~8 seconds)

Click "Anomaly Feed" in the sidebar. Default filter shows CRITICAL + HIGH.

**What the audience sees:**
- 3 KPI cards: Total Shown | Critical count | High count
- A full table of anomalies with columns: MACHINE_ID, MACHINE_TYPE, TIMESTAMP, SEVERITY, SENSOR_VALUE, ANOMALY_SCORE, HEALTH_SCORE, OPERATOR_OBSERVATION, PERFORMANCE_STATUS

**NARRATION:**
"The Anomaly Feed is the triage screen. Filter by severity, see every ML-detected anomaly with its confidence score. The key column is Operator Observation -- when the ML says anomaly and the operator reported a burning smell, that corroboration raises the urgency."

---

**VIEW 4: Work Order Management** (show for ~10 seconds)

Click "Work Order Management." Select a CRITICAL work order from the detail dropdown.

**What the audience sees:**
- 4 KPI cards: Total Orders: 49 | Critical: 4 | Assigned: 49 | Rental Needed: 4
- Priority-sorted table with CRITICAL orders at top
- Detail section showing AI-generated Title, Problem Description, and Recommended Actions

**NARRATION:**
"Work Order Management. 49 AI-drafted work orders, 4 at critical priority. Select any work order to see the full AI output -- problem description synthesizing sensor data and operator observations, plus a numbered action checklist. No human wrote this. The AI also flags when a rental machine is needed for production continuity."

---

**VIEW 5: Maintenance History** (show for ~5 seconds)

Click "Maintenance History."

**What the audience sees:**
- 3 KPI cards: Total Failures | Avg Downtime (hrs) | Total Cost ($)
- A machine filter dropdown
- Table with FAILURE_DATE, FAILURE_TYPE, ROOT_CAUSE, RESOLUTION, PARTS_REPLACED, DOWNTIME_HOURS, COST_USD

**NARRATION:**
"Maintenance History shows every past failure -- root cause, resolution, parts replaced, downtime, and cost. This is the ERP data that feeds into the AI's work order recommendations."

---

**VIEW 6: Business Continuity** (show for ~8 seconds)

Click "Business Continuity."

**What the audience sees:**
- Rental Machine Availability table: MACHINE_TYPE, VENDOR, DAILY_COST, AVAILABILITY, LEAD_TIME
- Critical Machines Needing Backup table: machines joined with work orders showing RENTAL_RECOMMENDED
- Parts Inventory table: PART_NAME, QUANTITY_IN_STOCK, REORDER_LEVEL, LEAD_TIME, COST

**NARRATION:**
"Business Continuity. Before authorizing a shutdown, the operations manager checks: Is a rental available? What will it cost? Are the right parts in stock or do we need to expedite? This turns a maintenance decision into an informed business decision."

---

**VIEW 7: Cross-Machine Health** (show for ~8 seconds)

Click "Cross-Machine Health."

**What the audience sees:**
- A bar chart showing health scores across all 50 machines
- 4 status KPI cards: Critical: 5 | Warning: 0 | Fair: ~25 | Good: ~20
- "Machines Needing Attention" table filtered to score < 70
- Production Impact by Machine Type table: AVG_REJECT_RATE, AVG_CYCLE_DEVIATION, DEGRADED_SHIFTS per type

**NARRATION:**
"Cross-Machine Health answers: while we have a machine down, what else should we fix? The bar chart shows the health distribution. The table below lists every machine scoring below 70. And the production impact summary shows which machine types are causing the most quality issues. This enables opportunistic maintenance -- bundling repairs into one shutdown window instead of separate outages."

---

### [2:40 - 2:55] CORTEX ANALYST -- Natural Language

**ON SCREEN:**
Switch back to CoCo CLI. Type:

```
cortex analyst query "Which-machines-are-critical" --view=IOT_PREDICTIVE_MAINTENANCE.APP.IOT_MAINTENANCE_VIEW
```

**EXPECTED OUTPUT:**
Cortex Analyst generates SQL and returns 5 CRITICAL machines with health scores.

**NARRATION:**
"CoCo also created a semantic view for Cortex Analyst. A plant manager asks 'which machines are critical' in plain English and gets an accurate, SQL-grounded answer. No schema knowledge required."

---

### [2:55 - 4:00] LIVE DEMO -- Anomaly to Email in 60 Seconds

**NARRATION:**
"Now the live demo. I am going to inject a new anomaly, run the full pipeline, and show you the actual email arriving -- all through CoCo."

---

**STEP 1: Inject the anomaly** [2:55 - 3:10]

**ON SCREEN:**
Type:

```
Inject a test CRITICAL anomaly for machine MCH-0012 (COMPRESSOR) with vibration reading 9.2, anomaly score 0.999, health score 28. Insert it into DETECTED_ANOMALIES with status NEW.
```

**EXPECTED OUTPUT:**
CoCo executes INSERT -- "1 row inserted"

**NARRATION:**
"Anomaly injected. MCH-0012, a compressor, vibration reading 9.2 -- well above normal. Severity: CRITICAL."

---

**STEP 2: Run the 3-skill pipeline** [3:10 - 3:40]

**ON SCREEN:**
Type:

```
Now run the full 3-skill maintenance pipeline: first SKILL1_ASSEMBLE_CONTEXT to enrich it with context from all data domains, then SKILL2_DRAFT_WORK_ORDERS to generate an AI work order, then SKILL3_DISPATCH_AND_NOTIFY to dispatch and send the email. Show each step's result.
```

**EXPECTED OUTPUT:**
CoCo executes sequentially:
1. `CALL SKILL1_ASSEMBLE_CONTEXT()` -- "1 anomalies enriched and queued for triage"
2. `CALL SKILL2_DRAFT_WORK_ORDERS()` -- "1 work orders drafted"
3. `CALL SKILL3_DISPATCH_AND_NOTIFY()` -- "work orders dispatched and email notifications sent"

**NARRATION (as each step completes):**
"Skill 1 pulls in context from 7 data domains -- operator observations, production quality, power events, maintenance history, parts inventory, rental availability, and vibration forecasts."

"Skill 2 calls llama3.1-70b to draft the work order -- title, problem description, and recommended actions, all generated from the context."

"Skill 3 dispatches the work order and sends the email notification. The pipeline is complete."

---

**STEP 3: Show the work order** [3:40 - 3:50]

**ON SCREEN:**
Type:

```
Show me the work order just created for MCH-0012
```

**EXPECTED OUTPUT:**
Displays:
- Title: AI-generated (e.g., "Compressor MCH-0012 Critical Vibration Anomaly...")
- Problem Description: 3-sentence AI synthesis
- Recommended Actions: 4-step checklist
- Priority: CRITICAL
- Rental Recommended: TRUE
- Status: ASSIGNED

**NARRATION:**
"There is the work order. AI-drafted with specific context about this compressor, its past failures, and what parts to bring. Status: already assigned and dispatched."

---

**STEP 4: Show the email** [3:50 - 4:10]

**ON SCREEN:**
Switch to the browser tab with your email inbox (bbalamu5@ford.com).
Refresh the inbox. The new email should appear with subject line:
`[IOT-PM] CRITICAL: MCH-0012 - Work Order WO-...`

Open the email. Show the content:
```
MAINTENANCE WORK ORDER: WO-...
================================================
Machine: MCH-0012
Priority: CRITICAL
Assigned To: TECH-...
Est. Downtime: 8 hours
Rental Needed: YES - arrange backup machine
------------------------------------------------
PROBLEM:
[AI-generated problem description]
------------------------------------------------
Generated by IoT Predictive Maintenance Platform
```

**NARRATION:**
"And there is the email. Arrived in seconds. The maintenance team gets everything they need -- machine ID, priority, assigned technician, estimated downtime, rental flag, and the full AI-generated problem description. From sensor anomaly to actionable email, fully automated."

---

**STEP 5: Note the automation** [4:10 - 4:15]

**ON SCREEN:**
Switch back to CoCo CLI. Type:

```
Show me the status of the MAINTENANCE_PIPELINE_TASK
```

**EXPECTED OUTPUT:**
Shows task state: `started`, schedule: `240 MINUTES`

**NARRATION:**
"And this entire pipeline runs autonomously every 4 hours. No human in the loop. New anomalies are detected, enriched, triaged, and dispatched -- 24/7."

---

### [4:15 - 4:30] CLOSING

**ON SCREEN:**
Stay on CoCo CLI.

**NARRATION:**
"50 machines monitored. 320,000 data points converged. 8 ML models. 3,249 anomalies detected. 49 AI-drafted work orders. 5 out of 5 failures caught. A 7-view command center dashboard. And a live email you just watched arrive. All built through Snowflake CoCo CLI -- no IDE, no Snowsight, no external tools. From sensor signal to work order, in seconds, autonomously, entirely on Snowflake."

**FADE OUT.**

---

## TIMING SUMMARY

| Segment | Duration | Content |
|---------|----------|---------|
| 0:00 - 0:25 | 25 sec | Opening: problem + platform overview |
| 0:25 - 1:00 | 35 sec | Skill 1: DT pipeline, health scores, data convergence |
| 1:00 - 1:40 | 40 sec | Skill 2: ML anomaly detection + AI work order |
| 1:40 - 2:40 | 60 sec | Dashboard: all 7 views walkthrough |
| 2:40 - 2:55 | 15 sec | Cortex Analyst natural language query |
| 2:55 - 4:15 | 80 sec | Live demo: inject anomaly, run pipeline, show email |
| 4:15 - 4:30 | 15 sec | Closing with stats |
| **TOTAL** | **4:30** | |

---

## DASHBOARD WALKTHROUGH CHEAT SHEET

Quick reference for the 7 sidebar clicks during recording:

| # | Sidebar Click | What to Point Out | Time |
|---|--------------|-------------------|------|
| 1 | Factory Floor Overview | Red/yellow/green color coding, 5 CRITICAL machines at top | 10 sec |
| 2 | Machine Detail (select MCH-0047) | Vibration chart trending up, anomaly table, 14-day forecast | 15 sec |
| 3 | Anomaly Feed | Severity filter, OPERATOR_OBSERVATION column bridging ML + human | 8 sec |
| 4 | Work Order Management (select a CRITICAL WO) | AI-generated title + problem + actions in detail pane | 10 sec |
| 5 | Maintenance History | Total cost KPI, failure types, filter by machine | 5 sec |
| 6 | Business Continuity | Rental availability, parts stock, critical machines needing backup | 8 sec |
| 7 | Cross-Machine Health | Bar chart, at-risk table, production impact by type | 8 sec |

---

## PRE-RECORDING CHECKLIST

- [ ] CoCo CLI open and connected
- [ ] Snowsight open with Streamlit app bookmarked (IOT_MAINTENANCE_DASHBOARD)
- [ ] Email inbox open (bbalamu5@ford.com) in a separate browser tab
- [ ] Make sure MCH-0012 does NOT have an existing DRAFT/ASSIGNED work order (otherwise Skill 2 will skip it due to deduplication). Run this cleanup if needed:
      ```
      DELETE FROM IOT_PREDICTIVE_MAINTENANCE.RAW.WORK_ORDERS WHERE MACHINE_ID = 'MCH-0012';
      DELETE FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.TRIAGE_QUEUE WHERE MACHINE_ID = 'MCH-0012';
      DELETE FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.DETECTED_ANOMALIES WHERE MACHINE_ID = 'MCH-0012' AND ANOMALY_ID LIKE 'TEST%';
      ```
- [ ] Test the full flow once before recording to make sure email arrives
- [ ] Font size 16+ in CoCo CLI for readability

---

## IF SOMETHING GOES WRONG

**Email does not arrive:**
- Check: `SHOW NOTIFICATION INTEGRATIONS LIKE 'IOT%'` -- should show ENABLED
- The email may take 30-60 seconds. Keep talking while it arrives.
- Fallback narration: "The email is being dispatched by Snowflake's notification service -- it typically arrives within a minute."

**Skill 2 returns "0 work orders drafted":**
- The machine already has an active work order (deduplication working correctly)
- Fix: Use a different machine ID that has no existing WO, or run the cleanup commands above

**CoCo takes too long on a query:**
- Keep narrating: "CoCo is executing the SQL against our Snowflake warehouse..."
- The ML and AI steps (Skill 2) can take 10-15 seconds -- this is normal for LLM calls

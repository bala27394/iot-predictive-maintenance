import streamlit as st
import pandas as pd
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Predictive Maintenance Command Center", layout="wide")

session = get_active_session()

def do_rerun():
    if hasattr(st, "rerun"):
        st.rerun()
    else:
        st.experimental_rerun()

def run_query(sql):
    return session.sql(sql).to_pandas()

def safe_float(val, default=0.0):
    if val is None or (isinstance(val, float) and pd.isna(val)):
        return default
    try:
        return float(val)
    except (TypeError, ValueError):
        return default

def safe_str(val, default="N/A"):
    if val is None or (isinstance(val, float) and pd.isna(val)):
        return default
    return str(val)

def make_gauge_html(value, label="", size=150):
    val = max(0, min(100, value))
    angle = 180 * val / 100
    if val >= 80:
        color = "#21BA45"
    elif val >= 60:
        color = "#FFA726"
    else:
        color = "#FF4B4B"
    import math
    rad = math.radians(180 - angle)
    nx = 50 + 40 * math.cos(rad)
    ny = 55 - 40 * math.sin(rad)
    svg = f'''<div style="text-align:center;">
    <svg width="{size}" height="{int(size*0.65)}" viewBox="0 0 100 65">
      <path d="M 10 55 A 40 40 0 0 1 90 55" fill="none" stroke="#e0e0e0" stroke-width="8" stroke-linecap="round"/>
      <path d="M 10 55 A 40 40 0 0 1 90 55" fill="none" stroke="#21BA45" stroke-width="8" stroke-linecap="round"
            stroke-dasharray="{3.14159*40}" stroke-dashoffset="{3.14159*40*(1 - min(1.0, max(val,80)/100))}"/>
      <path d="M 10 55 A 40 40 0 0 1 90 55" fill="none" stroke="#FFA726" stroke-width="8" stroke-linecap="round"
            stroke-dasharray="{3.14159*40}" stroke-dashoffset="{3.14159*40*(1 - 0.8)}"/>
      <path d="M 10 55 A 40 40 0 0 1 90 55" fill="none" stroke="#FF4B4B" stroke-width="8" stroke-linecap="round"
            stroke-dasharray="{3.14159*40}" stroke-dashoffset="{3.14159*40*(1 - 0.6)}"/>
      <line x1="50" y1="55" x2="{nx:.1f}" y2="{ny:.1f}" stroke="#333" stroke-width="2" stroke-linecap="round"/>
      <circle cx="50" cy="55" r="3" fill="#333"/>
      <text x="50" y="48" text-anchor="middle" font-size="16" font-weight="bold" fill="{color}">{val:.0f}%</text>
    </svg>
    <div style="font-size:12px;color:#666;margin-top:-5px;">{label}</div>
    </div>'''
    return svg

# --- Sidebar Navigation ---
st.sidebar.title("Command Center")
page = st.sidebar.radio("Navigate", [
    "Factory Overview",
    "Incident Triage",
    "Machine Detail",
    "Root-Cause Copilot",
    "Work Orders",
    "OEE & Production",
    "Maintenance History",
    "Data Trust"
])

# ============================================================
# VIEW 1: FACTORY OVERVIEW
# ============================================================
if page == "Factory Overview":
    st.markdown("## Predictive Maintenance Command Center")
    st.caption("Real-time production monitoring and predictive analytics")

    # --- Data Queries ---
    fleet = run_query("""
        SELECT cmh.MACHINE_ID, cmh.MACHINE_NAME, cmh.MACHINE_TYPE, cmh.LINE, cmh.CRITICALITY,
               cmh.CURRENT_STATE, cmh.HEALTH_SCORE, cmh.HEALTH_STATUS, cmh.CONCERN_RANK,
               cmh.WORST_SIGNAL_TYPE, cmh.SIGNALS_AT_RISK,
               i.INCIDENT_ID, i.SEVERITY AS INC_SEVERITY, i.SUSPECTED_FAILURE_MODE, i.RUL_DAYS
        FROM IOT_PREDICTIVE_MAINTENANCE.STAGING.CROSS_MACHINE_HEALTH cmh
        LEFT JOIN IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.INCIDENTS i ON cmh.MACHINE_ID = i.MACHINE_ID
        ORDER BY cmh.HEALTH_SCORE ASC
    """)

    oee_trend = run_query("""
        SELECT PRODUCTION_DATE,
               ROUND(AVG(AVAILABILITY_PCT),1) AS AVAILABILITY,
               ROUND(AVG(PERFORMANCE_PCT),1) AS PERFORMANCE,
               ROUND(AVG(QUALITY_PCT),1) AS QUALITY,
               ROUND(AVG(OEE_PCT),1) AS OEE
        FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.OEE_METRICS
        WHERE PRODUCTION_DATE >= DATEADD('day', -7, (SELECT MAX(PRODUCTION_DATE) FROM IOT_PREDICTIVE_MAINTENANCE.RAW.PRODUCTION_QUALITY))
        GROUP BY PRODUCTION_DATE ORDER BY PRODUCTION_DATE
    """)

    oee_by_machine = run_query("""
        SELECT MACHINE_ID, MACHINE_NAME,
               ROUND(AVG(AVAILABILITY_PCT),1) AS AVAILABILITY,
               ROUND(AVG(PERFORMANCE_PCT),1) AS PERFORMANCE,
               ROUND(AVG(QUALITY_PCT),1) AS QUALITY,
               ROUND(AVG(OEE_PCT),1) AS OEE
        FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.OEE_METRICS
        WHERE PRODUCTION_DATE >= DATEADD('day', -7, (SELECT MAX(PRODUCTION_DATE) FROM IOT_PREDICTIVE_MAINTENANCE.RAW.PRODUCTION_QUALITY))
        GROUP BY MACHINE_ID, MACHINE_NAME
    """)

    incidents = run_query("""
        SELECT INCIDENT_ID, MACHINE_ID, SEVERITY, PRIORITY_SCORE, STATUS, SUSPECTED_FAILURE_MODE, RUL_DAYS
        FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.INCIDENTS ORDER BY PRIORITY_SCORE DESC
    """)

    # --- Row 1: OEE Gauge | OEE Trend | Station Summary ---
    overall_oee = safe_float(oee_trend["OEE"].iloc[-1]) if not oee_trend.empty else 0.0
    prev_oee = safe_float(oee_trend["OEE"].iloc[-2]) if len(oee_trend) > 1 else overall_oee
    oee_delta = round(overall_oee - prev_oee, 1)

    r1c1, r1c2, r1c3 = st.columns([1, 2, 1])

    with r1c1:
        st.markdown(f"#### Current OEE &nbsp; {'↑' if oee_delta >= 0 else '↓'} {abs(oee_delta)}%")
        st.markdown(make_gauge_html(overall_oee, "OEE", size=200), unsafe_allow_html=True)
        st.caption("● OEE &nbsp;&nbsp; ● Target 74%")

    with r1c2:
        st.markdown("#### OEE Metrics (7-Day)")
        if not oee_trend.empty:
            oee_trend["PRODUCTION_DATE"] = pd.to_datetime(oee_trend["PRODUCTION_DATE"])
            chart_df = oee_trend.set_index("PRODUCTION_DATE")[["QUALITY", "PERFORMANCE", "AVAILABILITY", "OEE"]].apply(pd.to_numeric, errors="coerce")
            st.line_chart(chart_df)

    with r1c3:
        st.markdown("#### Station Summary")
        total_machines = len(fleet) if not fleet.empty else 0
        running = int(len(fleet[fleet["CURRENT_STATE"] == "RUNNING"])) if not fleet.empty else 0
        critical_count = int(len(incidents[incidents["SEVERITY"] == "CRITICAL"])) if not incidents.empty else 0
        high_count = int(len(incidents[incidents["SEVERITY"] == "HIGH"])) if not incidents.empty else 0
        machines_at_risk = int(len(fleet[fleet["HEALTH_STATUS"].isin(["CRITICAL", "DEGRADED", "WARNING"])])) if not fleet.empty else 0
        avg_quality = safe_float(oee_trend["QUALITY"].iloc[-1]) if not oee_trend.empty else 0.0

        st.markdown(f"▸ **{running}** of **{total_machines}** machines running")
        if critical_count > 0:
            st.markdown(f"▸ 🔴 **{critical_count}** critical incident{'s' if critical_count > 1 else ''}")
        if high_count > 0:
            st.markdown(f"▸ 🟠 **{high_count}** high priority incident{'s' if high_count > 1 else ''}")
        if machines_at_risk > 0:
            st.markdown(f"▸ ⚠️ **{machines_at_risk}** machine{'s' if machines_at_risk > 1 else ''} at risk")
        st.markdown(f"▸ Quality avg: **{avg_quality:.1f}%**")
        st.markdown(f"▸ Availability avg: **{safe_float(oee_trend['AVAILABILITY'].iloc[-1]) if not oee_trend.empty else 0:.1f}%**")

    st.markdown("---")

    # --- Row 2: Active Machines Cards ---
    st.markdown("#### Active Machines")

    if not fleet.empty:
        machine_rows = [fleet.iloc[i:i+4] for i in range(0, len(fleet), 4)]
        for row_batch in machine_rows:
            cols = st.columns(4)
            for col_idx, (_, m) in enumerate(row_batch.iterrows()):
                with cols[col_idx]:
                    mid = m["MACHINE_ID"]
                    mname = m["MACHINE_NAME"]
                    health = safe_float(m["HEALTH_SCORE"])
                    status = safe_str(m["HEALTH_STATUS"])
                    state = safe_str(m["CURRENT_STATE"])
                    inc_sev = m.get("INC_SEVERITY")

                    border_color = "#21BA45" if health >= 80 else ("#FFA726" if health >= 60 else "#FF4B4B")
                    if pd.notna(inc_sev):
                        if inc_sev == "CRITICAL":
                            border_color = "#FF4B4B"
                        elif inc_sev == "HIGH":
                            border_color = "#FFA726"

                    st.markdown(f"**{mname}**")

                    st.markdown(make_gauge_html(health, "", size=130), unsafe_allow_html=True)

                    # OEE breakdown for this machine
                    m_oee = oee_by_machine[oee_by_machine["MACHINE_ID"] == mid]
                    if not m_oee.empty:
                        mo = m_oee.iloc[0]
                        st.caption(f"Quality: **{safe_float(mo['QUALITY']):.0f}%** &nbsp;|&nbsp; Perf: **{safe_float(mo['PERFORMANCE']):.0f}%** &nbsp;|&nbsp; Avail: **{safe_float(mo['AVAILABILITY']):.0f}%**")
                    else:
                        st.caption("No OEE data")

                    if pd.notna(inc_sev):
                        sev_icon = {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡"}.get(str(inc_sev), "")
                        st.caption(f"{sev_icon} {safe_str(m['SUSPECTED_FAILURE_MODE'])}")
                    else:
                        st.caption(f"✅ {state}")

    st.markdown("---")

    # --- Row 3: Incidents Table ---
    st.markdown("#### Active Incidents")
    if not incidents.empty:
        st.dataframe(
            incidents[["INCIDENT_ID", "MACHINE_ID", "SEVERITY", "SUSPECTED_FAILURE_MODE", "PRIORITY_SCORE", "RUL_DAYS", "STATUS"]],
            use_container_width=True
        )
    else:
        st.success("No active incidents.")

# ============================================================
# VIEW 2: INCIDENT TRIAGE
# ============================================================
elif page == "Incident Triage":
    st.title("Incident Triage")

    incidents = run_query("""
        SELECT i.*, wo.WORK_ORDER_ID, wo.STATUS AS WO_STATUS
        FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.INCIDENTS i
        LEFT JOIN IOT_PREDICTIVE_MAINTENANCE.RAW.WORK_ORDERS wo ON i.INCIDENT_ID = wo.INCIDENT_ID
        ORDER BY PRIORITY_SCORE DESC
    """)

    if incidents.empty:
        st.info("No incidents found.")
    else:
        col1, col2 = st.columns(2)
        severity_options = [s for s in ["CRITICAL", "HIGH", "MEDIUM"] if s in incidents["SEVERITY"].values]
        status_options = incidents["STATUS"].unique().tolist()
        severity_filter = col1.multiselect("Filter by Severity", severity_options, default=severity_options)
        status_filter = col2.multiselect("Filter by Status", status_options, default=status_options)

        filtered = incidents[incidents["SEVERITY"].isin(severity_filter) & incidents["STATUS"].isin(status_filter)]

        for row_idx, (_, inc) in enumerate(filtered.iterrows()):
            severity_color = {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡"}.get(str(inc["SEVERITY"]), "⚪")
            priority = safe_float(inc["PRIORITY_SCORE"])
            with st.expander(f"{severity_color} {inc['INCIDENT_ID']} | {inc['MACHINE_NAME']} | {inc['SUSPECTED_FAILURE_MODE']} | Priority: {priority:.0f}"):
                c1, c2, c3, c4 = st.columns(4)
                c1.metric("Health Score", f"{safe_float(inc['HEALTH_SCORE']):.1f}")
                rul = inc["RUL_DAYS"]
                c2.metric("RUL (days)", f"{safe_float(rul):.1f}" if pd.notna(rul) else "N/A")
                c3.metric("Confidence", safe_str(inc["CONFIDENCE_LEVEL"]))
                c4.metric("Status", safe_str(inc["STATUS"]))

                st.markdown("**Evidence:**")
                st.write(safe_str(inc["EVIDENCE_NARRATIVE"], "No evidence available."))

                st.markdown(f"**Priority Drivers:** Score {priority:.0f}/100 based on health risk, criticality ({safe_str(inc['CRITICALITY'])}), production impact ({safe_str(inc['PRODUCTION_IMPACT'])}), RUL, and confidence.")

                wo_status = inc.get("WO_STATUS")
                if pd.notna(wo_status) and wo_status:
                    st.info(f"Work Order: {inc['WORK_ORDER_ID']} ({wo_status})")

                col_a, col_b, col_c = st.columns(3)
                if col_a.button("Acknowledge", key=f"triage_ack_{row_idx}"):
                    session.sql(f"UPDATE IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.INCIDENTS SET STATUS='ACKNOWLEDGED', UPDATED_AT=CURRENT_TIMESTAMP() WHERE INCIDENT_ID='{inc['INCIDENT_ID']}'").collect()
                    do_rerun()
                if col_b.button("Draft Work Order", key=f"triage_wo_{row_idx}"):
                    result = session.sql(f"CALL IOT_PREDICTIVE_MAINTENANCE.ORCHESTRATION.DRAFT_WORK_ORDER('{inc['INCIDENT_ID']}')").collect()
                    st.success(result[0][0])
                    do_rerun()
                if col_c.button("False Positive", key=f"triage_fp_{row_idx}"):
                    session.sql(f"UPDATE IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.INCIDENTS SET STATUS='FALSE_POSITIVE', UPDATED_AT=CURRENT_TIMESTAMP() WHERE INCIDENT_ID='{inc['INCIDENT_ID']}'").collect()
                    do_rerun()

# ============================================================
# VIEW 3: MACHINE DETAIL & PREDICTIVE DIAGNOSIS
# ============================================================
elif page == "Machine Detail":
    st.title("Machine Detail & Predictive Diagnosis")

    machines = run_query("SELECT MACHINE_ID, MACHINE_NAME FROM IOT_PREDICTIVE_MAINTENANCE.RAW.MACHINES ORDER BY MACHINE_ID")
    machine_map = dict(zip(machines["MACHINE_ID"], machines["MACHINE_NAME"]))
    selected = st.selectbox("Select Machine", machines["MACHINE_ID"].tolist(),
                            format_func=lambda x: f"{x} - {machine_map.get(x, '')}")

    if selected:
        health = run_query(f"SELECT * FROM IOT_PREDICTIVE_MAINTENANCE.STAGING.CROSS_MACHINE_HEALTH WHERE MACHINE_ID='{selected}'")
        if not health.empty:
            h = health.iloc[0]
            c1, c2, c3, c4 = st.columns(4)
            c1.metric("Health Score", f"{safe_float(h['HEALTH_SCORE']):.1f}/100")
            c2.metric("Status", safe_str(h["HEALTH_STATUS"]))
            c3.metric("State", safe_str(h["CURRENT_STATE"]))
            c4.metric("Signals at Risk", int(safe_float(h["SIGNALS_AT_RISK"])))

        st.subheader("Sensor Trends (Last 30 Days)")
        trends = run_query(f"""
            SELECT SIGNAL_TYPE, HOUR_BUCKET, AVG_VALUE, ROLLING_24H_AVG
            FROM IOT_PREDICTIVE_MAINTENANCE.STAGING.MACHINE_HEALTH_FEATURES
            WHERE MACHINE_ID='{selected}'
            ORDER BY HOUR_BUCKET
        """)
        if not trends.empty:
            for sig in trends["SIGNAL_TYPE"].unique():
                sig_data = trends[trends["SIGNAL_TYPE"] == sig].copy()
                st.markdown(f"**{sig}**")
                sig_data["HOUR_BUCKET"] = pd.to_datetime(sig_data["HOUR_BUCKET"])
                chart_data = sig_data.set_index("HOUR_BUCKET")[["AVG_VALUE", "ROLLING_24H_AVG"]].apply(pd.to_numeric, errors="coerce")
                st.line_chart(chart_data)

        st.subheader("Failure Forecast")
        forecast = run_query(f"""
            SELECT SIGNAL_TYPE, PREDICTED_FAILURE_MODE, RISK_HORIZON, ESTIMATED_DAYS_TO_THRESHOLD, CONFIDENCE_LEVEL, TREND_SLOPE_7D
            FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.FAILURE_FORECASTS
            WHERE MACHINE_ID='{selected}' AND PREDICTED_FAILURE_MODE != 'MONITORING'
        """)
        if not forecast.empty:
            st.dataframe(forecast, use_container_width=True)
        else:
            st.info("No active failure predictions for this machine.")

        assessment = run_query(f"""
            SELECT PRIMARY_FAILURE_MODE, CONFIDENCE_LEVEL, RECOMMENDATION, EVIDENCE_NARRATIVE, ASSESSMENT_STATE
            FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.FAILURE_ASSESSMENTS WHERE MACHINE_ID='{selected}'
        """)
        if not assessment.empty:
            a = assessment.iloc[0]
            st.subheader("Why This Alert?")
            st.markdown(f"**Predicted Mode:** {safe_str(a['PRIMARY_FAILURE_MODE'])}")
            st.markdown(f"**Recommendation:** {safe_str(a['RECOMMENDATION'])}")
            st.markdown(f"**Confidence:** {safe_str(a['CONFIDENCE_LEVEL'])}")
            st.markdown(f"**Evidence:** {safe_str(a['EVIDENCE_NARRATIVE'], 'No evidence available.')}")

# ============================================================
# VIEW 4: ROOT-CAUSE COPILOT
# ============================================================
elif page == "Root-Cause Copilot":
    st.title("Root-Cause Investigation Copilot")
    st.markdown("Investigate incidents with evidence, sensor analysis, and historical cases.")

    incidents = run_query("SELECT INCIDENT_ID, MACHINE_ID, MACHINE_NAME, SUSPECTED_FAILURE_MODE FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.INCIDENTS ORDER BY PRIORITY_SCORE DESC")
    if incidents.empty:
        st.info("No incidents to investigate.")
    else:
        inc_map = {}
        for _, r in incidents.iterrows():
            inc_map[r["INCIDENT_ID"]] = f"{r['INCIDENT_ID']} - {r['MACHINE_NAME']} ({r['SUSPECTED_FAILURE_MODE']})"

        selected_inc = st.selectbox("Select Incident to Investigate", list(inc_map.keys()),
                                    format_func=lambda x: inc_map[x])

        inc = incidents[incidents["INCIDENT_ID"] == selected_inc].iloc[0]
        machine_id = inc["MACHINE_ID"]
        failure_mode = inc["SUSPECTED_FAILURE_MODE"]

        tabs = st.tabs(["Evidence Summary", "Sensor Analysis", "Historical Cases", "Maintenance History"])

        with tabs[0]:
            evidence = run_query(f"SELECT EVIDENCE_NARRATIVE, EVIDENCE_JSON FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.FAILURE_ASSESSMENTS WHERE MACHINE_ID='{machine_id}'")
            if not evidence.empty:
                st.write(safe_str(evidence.iloc[0]["EVIDENCE_NARRATIVE"], "No evidence available."))
            else:
                st.info("No assessment found for this machine.")

        with tabs[1]:
            sensor_data = run_query(f"""
                SELECT SIGNAL_TYPE, HOUR_BUCKET, AVG_VALUE, BASELINE_DEVIATION_7D, RATE_OF_CHANGE_6H
                FROM IOT_PREDICTIVE_MAINTENANCE.STAGING.MACHINE_HEALTH_FEATURES
                WHERE MACHINE_ID='{machine_id}' AND HOUR_BUCKET >= DATEADD('day', -7, CURRENT_TIMESTAMP())
                ORDER BY HOUR_BUCKET
            """)
            if not sensor_data.empty:
                for sig in sensor_data["SIGNAL_TYPE"].unique():
                    sd = sensor_data[sensor_data["SIGNAL_TYPE"] == sig].copy()
                    latest_dev = safe_float(sd["BASELINE_DEVIATION_7D"].iloc[-1])
                    st.markdown(f"**{sig}** - Latest deviation from baseline: {latest_dev:.2f}")
                    sd["HOUR_BUCKET"] = pd.to_datetime(sd["HOUR_BUCKET"])
                    chart_col = sd.set_index("HOUR_BUCKET")["AVG_VALUE"].apply(pd.to_numeric, errors="coerce")
                    st.line_chart(chart_col)
            else:
                st.info("No recent sensor data available.")

        with tabs[2]:
            similar = run_query(f"""
                SELECT MAINTENANCE_ID, MACHINE_ID, FAILURE_MODE, ROOT_CAUSE, ACTION_TAKEN, PARTS_REPLACED, COMPLETED_AT
                FROM IOT_PREDICTIVE_MAINTENANCE.RAW.MAINTENANCE_HISTORY
                WHERE FAILURE_MODE = '{failure_mode}'
                   OR MACHINE_ID = '{machine_id}'
                ORDER BY COMPLETED_AT DESC LIMIT 10
            """)
            if not similar.empty:
                st.dataframe(similar, use_container_width=True)
            else:
                st.info("No similar historical cases found.")

        with tabs[3]:
            maint = run_query(f"""
                SELECT MAINTENANCE_ID, FAILURE_MODE, ROOT_CAUSE, ACTION_TAKEN, PARTS_REPLACED,
                       REPAIR_DURATION_HRS, COST, MAINTENANCE_TYPE, COMPLETED_AT
                FROM IOT_PREDICTIVE_MAINTENANCE.RAW.MAINTENANCE_HISTORY
                WHERE MACHINE_ID='{machine_id}' ORDER BY COMPLETED_AT DESC
            """)
            if not maint.empty:
                st.dataframe(maint, use_container_width=True)
            else:
                st.info("No maintenance history for this machine.")

# ============================================================
# VIEW 5: WORK ORDER MANAGEMENT
# ============================================================
elif page == "Work Orders":
    st.title("Work Order Management")

    work_orders = run_query("""
        SELECT wo.*, i.EVIDENCE_NARRATIVE, i.HEALTH_SCORE AS INCIDENT_HEALTH_SCORE
        FROM IOT_PREDICTIVE_MAINTENANCE.RAW.WORK_ORDERS wo
        LEFT JOIN IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.INCIDENTS i ON wo.INCIDENT_ID = i.INCIDENT_ID
        ORDER BY CASE wo.STATUS WHEN 'DRAFT' THEN 1 WHEN 'APPROVED' THEN 2 WHEN 'ASSIGNED' THEN 3 WHEN 'IN_PROGRESS' THEN 4 ELSE 5 END
    """)

    if work_orders.empty:
        st.info("No work orders yet. Draft one from the Incident Triage page.")
    else:
        tab_names = ["All", "DRAFT", "APPROVED", "RESOLVED"]
        status_tabs = st.tabs(tab_names)

        for tab_idx, tab in enumerate(status_tabs):
            with tab:
                status_filter = None if tab_idx == 0 else tab_names[tab_idx]
                filtered_wo = work_orders if status_filter is None else work_orders[work_orders["STATUS"] == status_filter]

                if filtered_wo.empty:
                    st.info(f"No {status_filter or ''} work orders.")
                    continue

                for wo_idx, (_, wo) in enumerate(filtered_wo.iterrows()):
                    wo_id = wo["WORK_ORDER_ID"]
                    key_prefix = f"t{tab_idx}_w{wo_idx}"

                    with st.expander(f"{wo_id} | {wo['MACHINE_ID']} | {safe_str(wo['PREDICTED_FAILURE_MODE'])} | {wo['STATUS']}"):
                        c1, c2, c3 = st.columns(3)
                        c1.markdown(f"**Priority:** {safe_str(wo['PRIORITY'])}")
                        c2.markdown(f"**Repair Est:** {safe_float(wo['ESTIMATED_REPAIR_HRS'])}h")
                        c3.markdown(f"**Downtime Est:** {safe_float(wo['ESTIMATED_DOWNTIME_HRS'])}h")

                        st.markdown(f"**Problem:** {safe_str(wo['PROBLEM_DESCRIPTION'], 'N/A')}")
                        st.markdown(f"**Actions:** {safe_str(wo['RECOMMENDED_ACTIONS'], 'N/A')}")
                        st.markdown(f"**Window:** {safe_str(wo['RECOMMENDED_WINDOW'], 'N/A')}")

                        if wo["STATUS"] == "DRAFT":
                            approver = st.text_input("Approver Name", key=f"{key_prefix}_approver")
                            c1, c2 = st.columns(2)
                            if c1.button("Approve", key=f"{key_prefix}_approve"):
                                if approver:
                                    result = session.sql(f"CALL IOT_PREDICTIVE_MAINTENANCE.ORCHESTRATION.APPROVE_WORK_ORDER('{wo_id}', '{approver}', 'APPROVE')").collect()
                                    st.success(result[0][0])
                                    do_rerun()
                                else:
                                    st.warning("Enter approver name first.")
                            if c2.button("Reject", key=f"{key_prefix}_reject"):
                                if approver:
                                    result = session.sql(f"CALL IOT_PREDICTIVE_MAINTENANCE.ORCHESTRATION.APPROVE_WORK_ORDER('{wo_id}', '{approver}', 'REJECT')").collect()
                                    st.warning(result[0][0])
                                    do_rerun()
                                else:
                                    st.warning("Enter approver name first.")

                        elif wo["STATUS"] in ("APPROVED", "ASSIGNED", "IN_PROGRESS"):
                            st.markdown("---")
                            st.markdown("**Resolve Work Order**")
                            root_cause = st.text_input("Actual Root Cause", key=f"{key_prefix}_rc")
                            parts = st.text_input("Parts Replaced", key=f"{key_prefix}_parts")
                            hours = st.number_input("Actual Repair Hours", min_value=0.0, step=0.5, key=f"{key_prefix}_hrs")
                            findings = st.text_area("Technician Findings", key=f"{key_prefix}_find")
                            if st.button("Resolve", key=f"{key_prefix}_resolve"):
                                if root_cause:
                                    result = session.sql(f"CALL IOT_PREDICTIVE_MAINTENANCE.ORCHESTRATION.RESOLVE_WORK_ORDER('{wo_id}', '{root_cause}', '{parts}', {hours}, '{findings}')").collect()
                                    st.success(result[0][0])
                                    do_rerun()
                                else:
                                    st.warning("Enter root cause first.")

# ============================================================
# VIEW 6: OEE & PRODUCTION IMPACT
# ============================================================
elif page == "OEE & Production":
    st.title("OEE & Production Impact")

    oee_summary = run_query("""
        SELECT MACHINE_ID, MACHINE_NAME, LINE,
               ROUND(AVG(AVAILABILITY_PCT),1) AS AVG_AVAILABILITY,
               ROUND(AVG(PERFORMANCE_PCT),1) AS AVG_PERFORMANCE,
               ROUND(AVG(QUALITY_PCT),1) AS AVG_QUALITY,
               ROUND(AVG(OEE_PCT),1) AS AVG_OEE,
               SUM(REJECTED_UNITS) AS TOTAL_REJECTS,
               SUM(DOWNTIME_HRS) AS TOTAL_DOWNTIME
        FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.OEE_METRICS
        WHERE PRODUCTION_DATE >= DATEADD('day', -7, CURRENT_DATE())
        GROUP BY MACHINE_ID, MACHINE_NAME, LINE
        ORDER BY AVG_OEE
    """)

    if not oee_summary.empty:
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Avg Availability", f"{safe_float(oee_summary['AVG_AVAILABILITY'].mean()):.1f}%")
        c2.metric("Avg Performance", f"{safe_float(oee_summary['AVG_PERFORMANCE'].mean()):.1f}%")
        c3.metric("Avg Quality", f"{safe_float(oee_summary['AVG_QUALITY'].mean()):.1f}%")
        c4.metric("Avg OEE", f"{safe_float(oee_summary['AVG_OEE'].mean()):.1f}%")

        st.subheader("OEE by Machine (7-Day Average)")
        chart_oee = oee_summary.set_index("MACHINE_NAME")[["AVG_AVAILABILITY", "AVG_PERFORMANCE", "AVG_QUALITY"]].apply(pd.to_numeric, errors="coerce")
        st.bar_chart(chart_oee)
    else:
        st.info("No OEE data available for the last 7 days.")

    st.subheader("OEE Trend (Daily)")
    oee_trend = run_query("""
        SELECT PRODUCTION_DATE, ROUND(AVG(OEE_PCT),2) AS DAILY_OEE
        FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.OEE_METRICS
        GROUP BY PRODUCTION_DATE ORDER BY PRODUCTION_DATE
    """)
    if not oee_trend.empty:
        oee_trend["PRODUCTION_DATE"] = pd.to_datetime(oee_trend["PRODUCTION_DATE"])
        oee_trend["DAILY_OEE"] = pd.to_numeric(oee_trend["DAILY_OEE"], errors="coerce")
        st.line_chart(oee_trend.set_index("PRODUCTION_DATE"))
    else:
        st.info("No OEE trend data available.")

    st.subheader("Production Impact from Active Incidents")
    impact = run_query("SELECT * FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.PRODUCTION_IMPACT ORDER BY PRIORITY_SCORE DESC")
    if not impact.empty:
        display_cols = [c for c in ["INCIDENT_ID", "MACHINE_NAME", "SUSPECTED_FAILURE_MODE", "CURRENT_OEE", "OEE_7D_AVG", "OEE_TREND", "DOWNTIME_HRS_AT_RISK", "CURRENT_REJECT_RATE"] if c in impact.columns]
        st.dataframe(impact[display_cols], use_container_width=True)
    else:
        st.info("No production impact data.")

# ============================================================
# VIEW 7: MAINTENANCE HISTORY & RELIABILITY
# ============================================================
elif page == "Maintenance History":
    st.title("Maintenance History & Reliability")

    maint = run_query("""
        SELECT mh.MAINTENANCE_ID, mh.MACHINE_ID, m.MACHINE_NAME, m.MACHINE_TYPE, m.LINE,
               mh.FAILURE_MODE, mh.ROOT_CAUSE, mh.ACTION_TAKEN, mh.PARTS_REPLACED,
               mh.REPAIR_DURATION_HRS, mh.DOWNTIME_HRS, mh.COST, mh.MAINTENANCE_TYPE, mh.COMPLETED_AT
        FROM IOT_PREDICTIVE_MAINTENANCE.RAW.MAINTENANCE_HISTORY mh
        JOIN IOT_PREDICTIVE_MAINTENANCE.RAW.MACHINES m ON mh.MACHINE_ID = m.MACHINE_ID
        ORDER BY mh.COMPLETED_AT DESC
    """)

    if not maint.empty:
        st.subheader("Failure Mode Distribution")
        failure_modes = maint[maint["FAILURE_MODE"] != "NONE"]
        if not failure_modes.empty:
            failure_dist = failure_modes.groupby("FAILURE_MODE").size().reset_index(name="COUNT")
            st.bar_chart(failure_dist, x="FAILURE_MODE", y="COUNT")

        st.subheader("Maintenance Cost by Machine")
        cost = maint.groupby("MACHINE_NAME")["COST"].sum().reset_index()
        cost["COST"] = pd.to_numeric(cost["COST"], errors="coerce")
        st.bar_chart(cost, x="MACHINE_NAME", y="COST")

        st.subheader("Full Maintenance Log")
        st.dataframe(maint[["MAINTENANCE_ID", "MACHINE_NAME", "FAILURE_MODE", "ROOT_CAUSE", "ACTION_TAKEN", "REPAIR_DURATION_HRS", "COST", "COMPLETED_AT"]],
                     use_container_width=True)

        st.subheader("Repeat Failure Patterns")
        repeats = maint.groupby(["MACHINE_ID", "MACHINE_NAME", "FAILURE_MODE"]).agg(
            COUNT=("MAINTENANCE_ID", "count"),
            TOTAL_COST=("COST", "sum"),
            TOTAL_DOWNTIME=("DOWNTIME_HRS", "sum")
        ).reset_index()
        repeats = repeats[repeats["COUNT"] > 1]
        if not repeats.empty:
            st.dataframe(repeats, use_container_width=True)
        else:
            st.info("No repeat failure patterns detected.")
    else:
        st.info("No maintenance history available.")

# ============================================================
# VIEW 8: DATA / MODEL TRUST
# ============================================================
elif page == "Data Trust":
    st.title("Data & Model Trust")

    st.subheader("Sensor Data Freshness")
    freshness = run_query("""
        SELECT MACHINE_ID, SIGNAL_TYPE, MAX(READING_TIMESTAMP) AS LATEST_READING,
               DATEDIFF('minute', MAX(READING_TIMESTAMP), CURRENT_TIMESTAMP()) AS MINUTES_SINCE_LAST,
               ROUND(COUNT(CASE WHEN QUALITY_FLAG != 'GOOD' THEN 1 END)::FLOAT / NULLIF(COUNT(*), 0) * 100, 2) AS BAD_QUALITY_PCT
        FROM IOT_PREDICTIVE_MAINTENANCE.STAGING.SENSOR_READINGS_CLEAN
        WHERE READING_TIMESTAMP >= DATEADD('day', -1, CURRENT_TIMESTAMP())
        GROUP BY MACHINE_ID, SIGNAL_TYPE
        ORDER BY MINUTES_SINCE_LAST DESC
    """)
    if not freshness.empty:
        st.dataframe(freshness, use_container_width=True)
    else:
        st.info("No recent sensor data found.")

    st.subheader("Dynamic Table Pipeline Status")
    try:
        pipeline = run_query("""
            SELECT NAME, SCHEMA_NAME, SCHEDULING_STATE, LAST_COMPLETED_REFRESH_STATE,
                   LATEST_DATA_TIMESTAMP, TARGET_LAG_SEC
            FROM TABLE(IOT_PREDICTIVE_MAINTENANCE.INFORMATION_SCHEMA.DYNAMIC_TABLES())
            ORDER BY SCHEMA_NAME, NAME
        """)
        if not pipeline.empty:
            st.dataframe(pipeline, use_container_width=True)
        else:
            st.info("No dynamic tables found.")
    except Exception as e:
        st.warning(f"Could not load pipeline status: {e}")

    st.subheader("Model / Rule Versions")
    models = run_query("""
        SELECT MODEL_VERSION AS VERSION, 'FAILURE_FORECAST' AS MODEL_TYPE, COUNT(*) AS PREDICTIONS
        FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.FAILURE_FORECASTS GROUP BY MODEL_VERSION
        UNION ALL
        SELECT MODEL_ID, 'ANOMALY_DETECTION', COUNT(*)
        FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.DETECTED_ANOMALIES GROUP BY MODEL_ID
    """)
    if not models.empty:
        st.dataframe(models, use_container_width=True)

    st.subheader("Prediction Confidence Distribution")
    confidence = run_query("""
        SELECT CONFIDENCE_LEVEL, COUNT(*) AS COUNT
        FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.FAILURE_FORECASTS
        GROUP BY CONFIDENCE_LEVEL
    """)
    if not confidence.empty:
        st.bar_chart(confidence, x="CONFIDENCE_LEVEL", y="COUNT")

    st.subheader("Fallback / Low-Confidence Cases")
    fallbacks = run_query("""
        SELECT MACHINE_ID, MACHINE_NAME, ASSESSMENT_STATE, CONFIDENCE_LEVEL, RECOMMENDATION
        FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.FAILURE_ASSESSMENTS
        WHERE ASSESSMENT_STATE != 'AUTOMATED_ASSESSMENT' OR CONFIDENCE_LEVEL IN ('LOW', 'INSUFFICIENT_DATA')
    """)
    if not fallbacks.empty:
        st.dataframe(fallbacks, use_container_width=True)
    else:
        st.success("All assessments are automated with adequate confidence.")

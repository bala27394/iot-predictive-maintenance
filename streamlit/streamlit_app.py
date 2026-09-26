import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="IoT Predictive Maintenance", page_icon="🏭", layout="wide")

session = get_active_session()

def run_query(sql):
    return session.sql(sql).to_pandas()

# Sidebar navigation
st.sidebar.title("IoT Predictive Maintenance")
page = st.sidebar.radio("Navigate", [
    "Factory Floor Overview",
    "Machine Detail",
    "Anomaly Feed",
    "Work Order Management",
    "Maintenance History",
    "Business Continuity",
    "Cross-Machine Health"
])

# ------- PAGE 1: Factory Floor Overview -------
if page == "Factory Floor Overview":
    st.title("Factory Floor Overview")
    
    health = run_query("""
        SELECT MACHINE_ID, MACHINE_TYPE, HEALTH_SCORE, HEALTH_STATUS, 
               TOTAL_ANOMALIES_24H, MOST_CONCERNING_SENSOR, CONCERN_RANK
        FROM IOT_PREDICTIVE_MAINTENANCE.STAGING.CROSS_MACHINE_HEALTH
        ORDER BY HEALTH_SCORE ASC
    """)
    
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Machines", len(health))
    col2.metric("Critical", len(health[health['HEALTH_STATUS'] == 'CRITICAL']), delta=None)
    col3.metric("Warning", len(health[health['HEALTH_STATUS'] == 'WARNING']), delta=None)
    col4.metric("Avg Health Score", f"{health['HEALTH_SCORE'].mean():.1f}")
    
    st.subheader("Machine Health Scores")
    
    def color_status(val):
        colors = {'CRITICAL': 'background-color: #ff4b4b', 'WARNING': 'background-color: #ffa726',
                  'FAIR': 'background-color: #ffee58', 'GOOD': 'background-color: #66bb6a'}
        return colors.get(val, '')
    
    styled = health.style.applymap(color_status, subset=['HEALTH_STATUS'])
    st.dataframe(styled, use_container_width=True, height=600)

# ------- PAGE 2: Machine Detail -------
elif page == "Machine Detail":
    st.title("Machine Detail View")
    
    machines = run_query("SELECT MACHINE_ID, MACHINE_TYPE, HEALTH_SCORE, HEALTH_STATUS FROM IOT_PREDICTIVE_MAINTENANCE.STAGING.CROSS_MACHINE_HEALTH ORDER BY HEALTH_SCORE")
    selected = st.selectbox("Select Machine", machines['MACHINE_ID'].tolist())
    
    if selected:
        info = machines[machines['MACHINE_ID'] == selected].iloc[0]
        col1, col2, col3 = st.columns(3)
        col1.metric("Machine Type", info['MACHINE_TYPE'])
        col2.metric("Health Score", f"{info['HEALTH_SCORE']:.1f}")
        col3.metric("Status", info['HEALTH_STATUS'])
        
        st.subheader("Recent Sensor Readings (Vibration)")
        readings = run_query(f"""
            SELECT READING_TIMESTAMP, CLEAN_VALUE AS VIBRATION
            FROM IOT_PREDICTIVE_MAINTENANCE.STAGING.SENSOR_READINGS_CLEAN
            WHERE MACHINE_ID = '{selected}' AND SENSOR_TYPE = 'VIBRATION'
            ORDER BY READING_TIMESTAMP DESC LIMIT 200
        """)
        if not readings.empty:
            st.line_chart(readings.set_index('READING_TIMESTAMP'))
        
        st.subheader("Detected Anomalies")
        anomalies = run_query(f"""
            SELECT READING_TIMESTAMP, SEVERITY, SENSOR_VALUE, ANOMALY_SCORE, HEALTH_STATUS
            FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.DETECTED_ANOMALIES
            WHERE MACHINE_ID = '{selected}'
            ORDER BY READING_TIMESTAMP DESC LIMIT 50
        """)
        if not anomalies.empty:
            st.dataframe(anomalies, use_container_width=True)
        else:
            st.info("No anomalies detected for this machine.")
        
        st.subheader("Vibration Forecast (14 days)")
        forecast = run_query(f"""
            SELECT TS AS FORECAST_DATE, ROUND(FORECAST, 2) AS PREDICTED_VIBRATION,
                   ROUND(LOWER_BOUND, 2) AS LOWER_95, ROUND(UPPER_BOUND, 2) AS UPPER_95
            FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.FAILURE_FORECASTS
            WHERE SERIES = '{selected}' ORDER BY TS
        """)
        if not forecast.empty:
            st.line_chart(forecast.set_index('FORECAST_DATE'))
        else:
            st.info("No forecast available for this machine.")

# ------- PAGE 3: Anomaly Feed -------
elif page == "Anomaly Feed":
    st.title("Anomaly Feed")
    
    severity_filter = st.multiselect("Filter by Severity", ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'], default=['CRITICAL', 'HIGH'])
    severity_str = ",".join([f"'{s}'" for s in severity_filter])
    
    anomalies = run_query(f"""
        SELECT MACHINE_ID, MACHINE_TYPE, READING_TIMESTAMP, SEVERITY, 
               SENSOR_VALUE, ROUND(ANOMALY_SCORE, 4) AS ANOMALY_SCORE,
               HEALTH_SCORE, HEALTH_STATUS, OPERATOR_OBSERVATION,
               PERFORMANCE_STATUS, STATUS
        FROM IOT_PREDICTIVE_MAINTENANCE.ANALYTICS.DETECTED_ANOMALIES
        WHERE SEVERITY IN ({severity_str})
        ORDER BY READING_TIMESTAMP DESC
        LIMIT 200
    """)
    
    col1, col2, col3 = st.columns(3)
    col1.metric("Total Shown", len(anomalies))
    col2.metric("Critical", len(anomalies[anomalies['SEVERITY'] == 'CRITICAL']))
    col3.metric("High", len(anomalies[anomalies['SEVERITY'] == 'HIGH']))
    
    st.dataframe(anomalies, use_container_width=True, height=500)

# ------- PAGE 4: Work Order Management -------
elif page == "Work Order Management":
    st.title("Work Order Management")
    
    work_orders = run_query("""
        SELECT WORK_ORDER_ID, MACHINE_ID, STATUS, PRIORITY,
               LEFT(TITLE, 100) AS TITLE, ASSIGNED_TECHNICIAN_ID,
               ESTIMATED_DOWNTIME_HOURS, RENTAL_RECOMMENDED, CREATED_AT
        FROM IOT_PREDICTIVE_MAINTENANCE.RAW.WORK_ORDERS
        ORDER BY CASE PRIORITY WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 ELSE 3 END,
                 CREATED_AT DESC
    """)
    
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Total Orders", len(work_orders))
    col2.metric("Critical", len(work_orders[work_orders['PRIORITY'] == 'CRITICAL']))
    col3.metric("Assigned", len(work_orders[work_orders['STATUS'] == 'ASSIGNED']))
    col4.metric("Rental Needed", len(work_orders[work_orders['RENTAL_RECOMMENDED'] == True]))
    
    st.dataframe(work_orders, use_container_width=True, height=400)
    
    st.subheader("Work Order Detail")
    if not work_orders.empty:
        wo_id = st.selectbox("Select Work Order", work_orders['WORK_ORDER_ID'].tolist())
        detail = run_query(f"""
            SELECT * FROM IOT_PREDICTIVE_MAINTENANCE.RAW.WORK_ORDERS
            WHERE WORK_ORDER_ID = '{wo_id}'
        """)
        if not detail.empty:
            row = detail.iloc[0]
            st.write(f"**Title:** {row.get('TITLE', 'N/A')}")
            st.write(f"**Problem:** {row.get('PROBLEM_DESCRIPTION', 'N/A')}")
            st.write(f"**Recommended Actions:** {row.get('RECOMMENDED_ACTIONS', 'N/A')}")

# ------- PAGE 5: Maintenance History -------
elif page == "Maintenance History":
    st.title("Maintenance History")
    
    history = run_query("""
        SELECT MACHINE_ID, FAILURE_DATE, FAILURE_TYPE, ROOT_CAUSE, 
               RESOLUTION, PARTS_REPLACED, DOWNTIME_HOURS, COST_USD,
               TECHNICIAN_ID
        FROM IOT_PREDICTIVE_MAINTENANCE.RAW.MAINTENANCE_HISTORY
        ORDER BY FAILURE_DATE DESC
    """)
    
    col1, col2, col3 = st.columns(3)
    col1.metric("Total Failures", len(history))
    col2.metric("Avg Downtime (hrs)", f"{history['DOWNTIME_HOURS'].mean():.1f}")
    col3.metric("Total Cost", f"${history['COST_USD'].sum():,.0f}")
    
    machine_filter = st.selectbox("Filter by Machine", ['All'] + sorted(history['MACHINE_ID'].unique().tolist()))
    if machine_filter != 'All':
        history = history[history['MACHINE_ID'] == machine_filter]
    
    st.dataframe(history, use_container_width=True, height=400)

# ------- PAGE 6: Business Continuity -------
elif page == "Business Continuity":
    st.title("Business Continuity Planning")
    
    st.subheader("Rental Machine Availability")
    rentals = run_query("""
        SELECT MACHINE_TYPE, VENDOR, DAILY_COST_USD, WEEKLY_COST_USD,
               AVAILABILITY, LEAD_TIME_DAYS, CAPACITY_PERCENT, LOCATION
        FROM IOT_PREDICTIVE_MAINTENANCE.RAW.RENTAL_MACHINES
        ORDER BY MACHINE_TYPE, DAILY_COST_USD
    """)
    st.dataframe(rentals, use_container_width=True)
    
    st.subheader("Critical Machines Needing Backup")
    critical = run_query("""
        SELECT cmh.MACHINE_ID, cmh.MACHINE_TYPE, cmh.HEALTH_SCORE, cmh.HEALTH_STATUS,
               wo.ESTIMATED_DOWNTIME_HOURS, wo.RENTAL_RECOMMENDED
        FROM IOT_PREDICTIVE_MAINTENANCE.STAGING.CROSS_MACHINE_HEALTH cmh
        LEFT JOIN IOT_PREDICTIVE_MAINTENANCE.RAW.WORK_ORDERS wo 
            ON cmh.MACHINE_ID = wo.MACHINE_ID AND wo.STATUS IN ('DRAFT', 'ASSIGNED')
        WHERE cmh.HEALTH_STATUS = 'CRITICAL'
        ORDER BY cmh.HEALTH_SCORE ASC
    """)
    st.dataframe(critical, use_container_width=True)
    
    st.subheader("Parts Inventory")
    parts = run_query("""
        SELECT PART_NAME, PART_CATEGORY, QUANTITY_IN_STOCK, REORDER_LEVEL,
               LEAD_TIME_DAYS, UNIT_COST_USD
        FROM IOT_PREDICTIVE_MAINTENANCE.RAW.PARTS_INVENTORY
        ORDER BY QUANTITY_IN_STOCK ASC
    """)
    st.dataframe(parts, use_container_width=True)

# ------- PAGE 7: Cross-Machine Health -------
elif page == "Cross-Machine Health":
    st.title("Cross-Machine Health Analysis")
    st.write("During a shutdown window, which other machines should be inspected?")
    
    health = run_query("""
        SELECT MACHINE_ID, MACHINE_TYPE, HEALTH_SCORE, HEALTH_STATUS,
               TOTAL_ANOMALIES_24H, TOTAL_BREACHES_24H, 
               MOST_CONCERNING_SENSOR, CONCERN_RANK
        FROM IOT_PREDICTIVE_MAINTENANCE.STAGING.CROSS_MACHINE_HEALTH
        ORDER BY HEALTH_SCORE ASC
    """)
    
    st.subheader("Health Score Distribution")
    chart_data = health[['MACHINE_ID', 'HEALTH_SCORE']].set_index('MACHINE_ID')
    st.bar_chart(chart_data)
    
    st.subheader("Machines by Status")
    status_counts = health['HEALTH_STATUS'].value_counts()
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Critical", status_counts.get('CRITICAL', 0))
    col2.metric("Warning", status_counts.get('WARNING', 0))
    col3.metric("Fair", status_counts.get('FAIR', 0))
    col4.metric("Good", status_counts.get('GOOD', 0))
    
    st.subheader("Machines Needing Attention (Score < 70)")
    at_risk = health[health['HEALTH_SCORE'] < 70]
    st.dataframe(at_risk, use_container_width=True, height=400)
    
    st.subheader("Production Impact by Machine Type")
    prod_summary = run_query("""
        SELECT MACHINE_TYPE, 
               ROUND(AVG(REJECT_RATE_PCT), 2) AS AVG_REJECT_RATE,
               ROUND(AVG(CYCLE_TIME_DEVIATION_PCT), 2) AS AVG_CYCLE_DEVIATION,
               COUNT_IF(PERFORMANCE_STATUS = 'DEGRADED') AS DEGRADED_SHIFTS
        FROM IOT_PREDICTIVE_MAINTENANCE.STAGING.PERFORMANCE_BASELINE
        GROUP BY MACHINE_TYPE
        ORDER BY AVG_REJECT_RATE DESC
    """)
    st.dataframe(prod_summary, use_container_width=True)

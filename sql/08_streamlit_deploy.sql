-- =============================================================================
-- IoT Predictive Maintenance Platform
-- 08: Streamlit Dashboard Deployment
-- =============================================================================

USE DATABASE IOT_PREDICTIVE_MAINTENANCE;
USE SCHEMA APP;

CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE;

-- Upload the streamlit app file:
-- PUT 'file://<local_path>/streamlit/streamlit_app.py' @STREAMLIT_STAGE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

CREATE OR REPLACE STREAMLIT IOT_MAINTENANCE_DASHBOARD
    ROOT_LOCATION = '@IOT_PREDICTIVE_MAINTENANCE.APP.STREAMLIT_STAGE'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = IOT_ML_WH
    COMMENT = 'IoT Predictive Maintenance Dashboard - 7 views';

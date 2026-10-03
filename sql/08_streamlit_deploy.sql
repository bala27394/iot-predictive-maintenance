-- ============================================================
-- 08_streamlit_deploy.sql
-- Deploy Streamlit Command Center to Snowflake
-- Database: IOT_PREDICTIVE_MAINTENANCE | Warehouse: IOT_PM_WH
-- ============================================================

USE DATABASE IOT_PREDICTIVE_MAINTENANCE;
USE WAREHOUSE IOT_PM_WH;

-- Create stage for Streamlit app files
CREATE STAGE IF NOT EXISTS APP.STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE);

-- Upload the Streamlit app (run from local machine or SnowSQL):
-- PUT 'file:///path/to/streamlit_app.py' @IOT_PREDICTIVE_MAINTENANCE.APP.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Create the Streamlit app object
CREATE OR REPLACE STREAMLIT APP.PREDICTIVE_MAINTENANCE_COMMAND_CENTER
    ROOT_LOCATION = '@IOT_PREDICTIVE_MAINTENANCE.APP.STREAMLIT_STAGE'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = IOT_PM_WH
    COMMENT = 'Predictive Maintenance Command Center - 8-view Streamlit application';

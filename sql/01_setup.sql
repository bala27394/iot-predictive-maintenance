-- =============================================================================
-- 01_setup.sql
-- IoT Predictive Maintenance Platform - Database, Schemas, Warehouse
-- =============================================================================

USE ROLE ACCOUNTADMIN;

CREATE DATABASE IF NOT EXISTS IOT_PREDICTIVE_MAINTENANCE;
USE DATABASE IOT_PREDICTIVE_MAINTENANCE;

CREATE SCHEMA IF NOT EXISTS RAW           COMMENT = 'Landing zone for sensor streams, machine logs, shift logs';
CREATE SCHEMA IF NOT EXISTS STAGING       COMMENT = 'Dynamic tables for cleansed/enriched data';
CREATE SCHEMA IF NOT EXISTS ANALYTICS     COMMENT = 'Aggregated views, ML feature tables, anomaly results';
CREATE SCHEMA IF NOT EXISTS ML_MODELS     COMMENT = 'Cortex ML model objects and training views';
CREATE SCHEMA IF NOT EXISTS ORCHESTRATION COMMENT = 'Tasks, stored procedures, notification integrations';
CREATE SCHEMA IF NOT EXISTS APP           COMMENT = 'Streamlit app, semantic view, stages';

CREATE WAREHOUSE IF NOT EXISTS IOT_ML_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    COMMENT = 'Dedicated warehouse for ML training, inference, and DT refreshes';

USE WAREHOUSE IOT_ML_WH;

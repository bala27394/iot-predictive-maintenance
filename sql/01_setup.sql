-- ============================================================
-- 01_setup.sql
-- Foundation: Database, Schemas, Warehouse
-- IOT Predictive Maintenance Command Center
-- ============================================================

CREATE DATABASE IF NOT EXISTS IOT_PREDICTIVE_MAINTENANCE
    COMMENT = 'Predictive Maintenance Command Center - Ground-Up Hackathon Build';

USE DATABASE IOT_PREDICTIVE_MAINTENANCE;

-- Core schemas
CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'OT telemetry, machine events, ERP/maintenance, production and human data';

CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'Cleansing, normalization, operating-state context and feature pipelines';

CREATE SCHEMA IF NOT EXISTS ANALYTICS
    COMMENT = 'Health, incidents, predictions, RCA evidence, OEE and business impact';

CREATE SCHEMA IF NOT EXISTS ML_MODELS
    COMMENT = 'Cortex ML model objects and model metadata';

CREATE SCHEMA IF NOT EXISTS ORCHESTRATION
    COMMENT = 'Tasks, stored procedures/skills, workflow state and notifications';

CREATE SCHEMA IF NOT EXISTS APP
    COMMENT = 'Semantic views, Streamlit application and supporting objects';

-- Warehouse
CREATE WAREHOUSE IF NOT EXISTS IOT_PM_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for Predictive Maintenance Command Center';

USE WAREHOUSE IOT_PM_WH;

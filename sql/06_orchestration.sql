-- ============================================================
-- 06_orchestration.sql
-- Work-Order Procedures, Notifications, Scheduled Task
-- Database: IOT_PREDICTIVE_MAINTENANCE | Warehouse: IOT_PM_WH
-- ============================================================

USE DATABASE IOT_PREDICTIVE_MAINTENANCE;
USE WAREHOUSE IOT_PM_WH;

-- ============================================================
-- NOTIFICATION LOG
-- ============================================================
CREATE OR REPLACE TABLE ORCHESTRATION.NOTIFICATION_LOG (
    NOTIFICATION_ID NUMBER AUTOINCREMENT,
    NOTIFICATION_TYPE VARCHAR(30),
    REFERENCE_ID VARCHAR(20),
    MACHINE_ID VARCHAR(20),
    SEVERITY VARCHAR(10),
    MESSAGE VARCHAR(2000),
    SENT_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    STATUS VARCHAR(20) DEFAULT 'SENT'
);

-- ============================================================
-- SP: DRAFT_WORK_ORDER
-- Generates a work order from an incident with duplicate prevention
-- ============================================================
CREATE OR REPLACE PROCEDURE ORCHESTRATION.DRAFT_WORK_ORDER(P_INCIDENT_ID VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_machine_id VARCHAR;
    v_failure_mode VARCHAR;
    v_evidence VARCHAR;
    v_severity VARCHAR;
    v_rul FLOAT;
    v_wo_id VARCHAR;
    v_existing_count INTEGER;
    v_health_score FLOAT;
    v_confidence VARCHAR;
    v_problem_desc VARCHAR;
    v_actions VARCHAR;
    v_repair_hrs FLOAT;
    v_downtime_hrs FLOAT;
    v_window VARCHAR;
BEGIN
    SELECT MACHINE_ID, SUSPECTED_FAILURE_MODE, EVIDENCE_NARRATIVE, SEVERITY, RUL_DAYS, HEALTH_SCORE, CONFIDENCE_LEVEL
    INTO :v_machine_id, :v_failure_mode, :v_evidence, :v_severity, :v_rul, :v_health_score, :v_confidence
    FROM ANALYTICS.INCIDENTS WHERE INCIDENT_ID = :P_INCIDENT_ID;

    SELECT COUNT(*) INTO :v_existing_count
    FROM RAW.WORK_ORDERS
    WHERE MACHINE_ID = :v_machine_id AND PREDICTED_FAILURE_MODE = :v_failure_mode AND STATUS NOT IN ('RESOLVED','REJECTED');

    IF (v_existing_count > 0) THEN
        RETURN CONCAT('DUPLICATE: Active WO exists for ', v_machine_id, ' - ', v_failure_mode);
    END IF;

    SELECT CONCAT('WO-', LPAD(COALESCE(MAX(REPLACE(WORK_ORDER_ID,'WO-','')::INT),0)+1,4,'0'))
    INTO :v_wo_id FROM RAW.WORK_ORDERS;

    v_problem_desc := CONCAT('Predicted ', v_failure_mode, ' on ', v_machine_id, '. Health: ', v_health_score::VARCHAR, '/100. Confidence: ', v_confidence);

    IF (v_failure_mode = 'BEARING_DEGRADATION') THEN
        v_actions := '1. Isolate machine 2. Inspect bearings 3. Check lubrication 4. Replace if worn 5. Realign 6. Test';
        v_repair_hrs := 6.0; v_downtime_hrs := 8.0;
    ELSEIF (v_failure_mode = 'MISALIGNMENT') THEN
        v_actions := '1. Stop machine 2. Laser alignment 3. Inspect coupling 4. Realign 5. Replace coupling if needed 6. Test';
        v_repair_hrs := 8.0; v_downtime_hrs := 12.0;
    ELSEIF (v_failure_mode = 'HYDRAULIC_SEAL_FAILURE') THEN
        v_actions := '1. Depressurize 2. Inspect seals 3. Check fluid 4. Replace seals+filter 5. Flush 6. Pressure test';
        v_repair_hrs := 5.0; v_downtime_hrs := 7.0;
    ELSEIF (v_failure_mode = 'OVERHEATING') THEN
        v_actions := '1. Check cooling 2. Inspect airflow 3. Check bearings 4. Verify load 5. Clean exchangers';
        v_repair_hrs := 4.0; v_downtime_hrs := 6.0;
    ELSE
        v_actions := '1. Inspect 2. Document 3. Determine corrective action';
        v_repair_hrs := 4.0; v_downtime_hrs := 6.0;
    END IF;

    IF (v_severity = 'CRITICAL') THEN v_window := 'IMMEDIATE - Next shift';
    ELSEIF (v_severity = 'HIGH') THEN v_window := 'URGENT - Within 48 hours';
    ELSE v_window := 'PLANNED - Next maintenance window';
    END IF;

    INSERT INTO RAW.WORK_ORDERS (
        WORK_ORDER_ID, INCIDENT_ID, MACHINE_ID, STATUS, PRIORITY,
        PROBLEM_DESCRIPTION, EVIDENCE_SUMMARY, PREDICTED_FAILURE_MODE,
        RECOMMENDED_ACTIONS, ESTIMATED_REPAIR_HRS, ESTIMATED_DOWNTIME_HRS, RECOMMENDED_WINDOW)
    VALUES (:v_wo_id, :P_INCIDENT_ID, :v_machine_id, 'DRAFT', :v_severity,
            :v_problem_desc, :v_evidence, :v_failure_mode,
            :v_actions, :v_repair_hrs, :v_downtime_hrs, :v_window);

    UPDATE ANALYTICS.INCIDENTS SET STATUS='WORK_ORDER_PENDING', UPDATED_AT=CURRENT_TIMESTAMP() WHERE INCIDENT_ID=:P_INCIDENT_ID;
    RETURN CONCAT('SUCCESS: Work order ', v_wo_id, ' drafted for incident ', P_INCIDENT_ID);
END;
$$;

-- ============================================================
-- SP: APPROVE_WORK_ORDER
-- Human approval gate
-- ============================================================
CREATE OR REPLACE PROCEDURE ORCHESTRATION.APPROVE_WORK_ORDER(P_WORK_ORDER_ID VARCHAR, P_APPROVER VARCHAR, P_ACTION VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_status VARCHAR;
    v_incident_id VARCHAR;
BEGIN
    SELECT STATUS, INCIDENT_ID INTO :v_status, :v_incident_id
    FROM RAW.WORK_ORDERS WHERE WORK_ORDER_ID = :P_WORK_ORDER_ID;

    IF (v_status != 'DRAFT') THEN
        RETURN CONCAT('ERROR: Work order ', P_WORK_ORDER_ID, ' is not in DRAFT status (current: ', v_status, ')');
    END IF;

    IF (:P_ACTION = 'APPROVE') THEN
        UPDATE RAW.WORK_ORDERS
        SET STATUS='APPROVED', APPROVED_BY=:P_APPROVER, APPROVED_AT=CURRENT_TIMESTAMP(), UPDATED_AT=CURRENT_TIMESTAMP()
        WHERE WORK_ORDER_ID = :P_WORK_ORDER_ID;
        UPDATE ANALYTICS.INCIDENTS SET STATUS='ASSIGNED', UPDATED_AT=CURRENT_TIMESTAMP() WHERE INCIDENT_ID=:v_incident_id;
        RETURN CONCAT('APPROVED: Work order ', P_WORK_ORDER_ID, ' approved by ', P_APPROVER);
    ELSEIF (:P_ACTION = 'REJECT') THEN
        UPDATE RAW.WORK_ORDERS
        SET STATUS='REJECTED', APPROVED_BY=:P_APPROVER, UPDATED_AT=CURRENT_TIMESTAMP()
        WHERE WORK_ORDER_ID = :P_WORK_ORDER_ID;
        UPDATE ANALYTICS.INCIDENTS SET STATUS='NEW', UPDATED_AT=CURRENT_TIMESTAMP() WHERE INCIDENT_ID=:v_incident_id;
        RETURN CONCAT('REJECTED: Work order ', P_WORK_ORDER_ID, ' rejected by ', P_APPROVER);
    ELSE
        RETURN 'ERROR: Action must be APPROVE or REJECT';
    END IF;
END;
$$;

-- ============================================================
-- SP: RESOLVE_WORK_ORDER
-- Captures post-repair feedback
-- ============================================================
CREATE OR REPLACE PROCEDURE ORCHESTRATION.RESOLVE_WORK_ORDER(
    P_WORK_ORDER_ID VARCHAR, P_ACTUAL_ROOT_CAUSE VARCHAR, P_PARTS_REPLACED VARCHAR, P_REPAIR_HRS FLOAT, P_FINDINGS VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_incident_id VARCHAR;
BEGIN
    SELECT INCIDENT_ID INTO :v_incident_id
    FROM RAW.WORK_ORDERS WHERE WORK_ORDER_ID = :P_WORK_ORDER_ID;

    UPDATE RAW.WORK_ORDERS
    SET STATUS='RESOLVED', ACTUAL_ROOT_CAUSE=:P_ACTUAL_ROOT_CAUSE, ACTUAL_PARTS_REPLACED=:P_PARTS_REPLACED,
        ACTUAL_REPAIR_HRS=:P_REPAIR_HRS, TECHNICIAN_FINDINGS=:P_FINDINGS, RESOLVED_AT=CURRENT_TIMESTAMP(), UPDATED_AT=CURRENT_TIMESTAMP()
    WHERE WORK_ORDER_ID = :P_WORK_ORDER_ID;

    UPDATE ANALYTICS.INCIDENTS SET STATUS='RESOLVED', UPDATED_AT=CURRENT_TIMESTAMP() WHERE INCIDENT_ID=:v_incident_id;
    RETURN CONCAT('RESOLVED: Work order ', P_WORK_ORDER_ID, ' completed. Root cause: ', P_ACTUAL_ROOT_CAUSE);
END;
$$;

-- ============================================================
-- SP: RUN_MAINTENANCE_CYCLE
-- End-to-end orchestration procedure
-- ============================================================
CREATE OR REPLACE PROCEDURE ORCHESTRATION.RUN_MAINTENANCE_CYCLE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_new_incidents INTEGER;
    v_notifications INTEGER DEFAULT 0;
    v_incident_id VARCHAR;
    v_machine_id VARCHAR;
    v_severity VARCHAR;
    v_failure_mode VARCHAR;
    v_evidence VARCHAR;
    c1 CURSOR FOR
        SELECT INCIDENT_ID, MACHINE_ID, SEVERITY, SUSPECTED_FAILURE_MODE, EVIDENCE_NARRATIVE
        FROM ANALYTICS.INCIDENTS WHERE STATUS = 'NEW' AND SEVERITY IN ('CRITICAL','HIGH')
        ORDER BY PRIORITY_SCORE DESC;
BEGIN
    OPEN c1;
    FOR record IN c1 DO
        v_incident_id := record.INCIDENT_ID;
        v_machine_id := record.MACHINE_ID;
        v_severity := record.SEVERITY;
        v_failure_mode := record.SUSPECTED_FAILURE_MODE;
        v_evidence := record.EVIDENCE_NARRATIVE;

        INSERT INTO ORCHESTRATION.NOTIFICATION_LOG (NOTIFICATION_TYPE, REFERENCE_ID, MACHINE_ID, SEVERITY, MESSAGE)
        VALUES ('INCIDENT_CREATED', :v_incident_id, :v_machine_id, :v_severity,
                CONCAT(:v_severity, ' incident ', :v_incident_id, ' on ', :v_machine_id, ': ', :v_failure_mode, '. ', LEFT(:v_evidence, 500)));
        v_notifications := v_notifications + 1;
    END FOR;
    CLOSE c1;

    SELECT COUNT(*) INTO :v_new_incidents FROM ANALYTICS.INCIDENTS WHERE STATUS = 'NEW';
    RETURN CONCAT('Maintenance cycle complete. Incidents: ', v_new_incidents, ' new. Notifications: ', v_notifications);
END;
$$;

-- ============================================================
-- TASK: MAINTENANCE_CYCLE_TASK (5-minute schedule, starts SUSPENDED)
-- ============================================================
CREATE OR REPLACE TASK ORCHESTRATION.MAINTENANCE_CYCLE_TASK
    WAREHOUSE = IOT_PM_WH
    SCHEDULE = '5 MINUTE'
    COMMENT = 'End-to-end predictive maintenance cycle'
AS
    CALL ORCHESTRATION.RUN_MAINTENANCE_CYCLE();

-- NOTE: Task is created SUSPENDED. Resume for demo:
-- ALTER TASK ORCHESTRATION.MAINTENANCE_CYCLE_TASK RESUME;

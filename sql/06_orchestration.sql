/*==========================================================================
  06_orchestration.sql — IoT Predictive Maintenance Platform
  Notification Integration, Stored Procedures (Skills 1-3), Pipeline Task
  Database: IOT_PREDICTIVE_MAINTENANCE
==========================================================================*/

USE DATABASE IOT_PREDICTIVE_MAINTENANCE;
USE WAREHOUSE IOT_ML_WH;

-- ========================================================================
-- NOTIFICATION INTEGRATION
-- ========================================================================

CREATE OR REPLACE NOTIFICATION INTEGRATION IOT_EMAIL_NOTIFICATIONS
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('bbalamu5@ford.com');

-- ========================================================================
-- SKILL 1: ASSEMBLE CONTEXT
-- Processes NEW CRITICAL/HIGH anomalies, enriches with 7-domain context,
-- writes to TRIAGE_QUEUE, marks anomalies as TRIAGED.
-- ========================================================================

CREATE OR REPLACE PROCEDURE ORCHESTRATION.SKILL1_ASSEMBLE_CONTEXT()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_count INTEGER DEFAULT 0;
BEGIN
    -- Enrich NEW CRITICAL/HIGH anomalies with multi-domain context and insert into TRIAGE_QUEUE
    INSERT INTO ANALYTICS.TRIAGE_QUEUE (
        TRIAGE_ID,
        ANOMALY_ID,
        MACHINE_ID,
        MACHINE_TYPE,
        MACHINE_NAME,
        LOCATION,
        CRITICALITY,
        SEVERITY,
        ANOMALY_SCORE,
        HEALTH_SCORE,
        HEALTH_STATUS,
        READING_TIMESTAMP,
        SENSOR_TYPE,
        -- Operator context
        OPERATOR_ID,
        OPERATOR_NAME,
        SHIFT,
        SHIFT_NOTES,
        -- Production context
        REJECT_RATE_PCT,
        PERFORMANCE_STATUS,
        CYCLE_TIME_DEVIATION_PCT,
        -- Power context
        VOLTAGE,
        POWER_FACTOR,
        THD_PERCENT,
        -- Maintenance context
        LAST_FAILURE_TYPE,
        LAST_ROOT_CAUSE,
        LAST_REPAIR_ACTION,
        LAST_DOWNTIME_HOURS,
        LAST_MAINTENANCE_DATE,
        -- Cross-machine context
        CONCERN_RANK,
        ANOMALY_COUNT_24H,
        BREACH_COUNT_24H,
        -- Parts and rental context
        PARTS_PRODUCED,
        PARTS_REJECTED,
        -- Forecast context
        FORECAST_VALUE,
        FORECAST_LOWER,
        FORECAST_UPPER,
        -- Metadata
        CONTEXT_SUMMARY,
        AI_REASONING,
        CREATED_AT,
        STATUS
    )
    WITH new_anomalies AS (
        SELECT *
        FROM ANALYTICS.DETECTED_ANOMALIES
        WHERE STATUS = 'NEW'
          AND SEVERITY IN ('CRITICAL', 'HIGH')
    ),
    operator_context AS (
        SELECT
            na.ANOMALY_ID,
            ac.OPERATOR_ID,
            ac.OPERATOR_NAME,
            ac.SHIFT,
            ac.SHIFT_NOTES
        FROM new_anomalies na
        LEFT JOIN ANALYTICS.ANOMALY_CONTEXT ac
            ON na.MACHINE_ID = ac.MACHINE_ID
            AND na.READING_TIMESTAMP = ac.READING_TIMESTAMP
    ),
    production_context AS (
        SELECT
            na.ANOMALY_ID,
            ac.REJECT_RATE_PCT,
            ac.PERFORMANCE_STATUS,
            ac.CYCLE_TIME_DEVIATION_PCT
        FROM new_anomalies na
        LEFT JOIN ANALYTICS.ANOMALY_CONTEXT ac
            ON na.MACHINE_ID = ac.MACHINE_ID
            AND na.READING_TIMESTAMP = ac.READING_TIMESTAMP
    ),
    power_context AS (
        SELECT
            na.ANOMALY_ID,
            ac.VOLTAGE,
            ac.POWER_FACTOR,
            ac.THD_PERCENT
        FROM new_anomalies na
        LEFT JOIN ANALYTICS.ANOMALY_CONTEXT ac
            ON na.MACHINE_ID = ac.MACHINE_ID
            AND na.READING_TIMESTAMP = ac.READING_TIMESTAMP
    ),
    maintenance_context AS (
        SELECT
            na.ANOMALY_ID,
            ac.LAST_FAILURE_TYPE,
            ac.LAST_ROOT_CAUSE,
            ac.LAST_REPAIR_ACTION,
            ac.LAST_DOWNTIME_HOURS,
            ac.LAST_MAINTENANCE_DATE
        FROM new_anomalies na
        LEFT JOIN ANALYTICS.ANOMALY_CONTEXT ac
            ON na.MACHINE_ID = ac.MACHINE_ID
            AND na.READING_TIMESTAMP = ac.READING_TIMESTAMP
    ),
    cross_machine_context AS (
        SELECT
            na.ANOMALY_ID,
            cmh.HEALTH_SCORE   AS CMH_HEALTH_SCORE,
            cmh.HEALTH_STATUS  AS CMH_HEALTH_STATUS,
            cmh.CONCERN_RANK,
            cmh.ANOMALY_COUNT_24H,
            cmh.BREACH_COUNT_24H
        FROM new_anomalies na
        LEFT JOIN STAGING.CROSS_MACHINE_HEALTH cmh
            ON na.MACHINE_ID = cmh.MACHINE_ID
    ),
    parts_context AS (
        SELECT
            na.ANOMALY_ID,
            pb.PARTS_PRODUCED,
            pb.PARTS_REJECTED
        FROM new_anomalies na
        LEFT JOIN STAGING.PERFORMANCE_BASELINE pb
            ON na.MACHINE_ID = pb.MACHINE_ID
            AND DATE(na.READING_TIMESTAMP) = pb.PRODUCTION_DATE
        QUALIFY ROW_NUMBER() OVER (PARTITION BY na.ANOMALY_ID ORDER BY pb.PRODUCTION_DATE DESC) = 1
    ),
    forecast_context AS (
        SELECT
            na.ANOMALY_ID,
            ff.FORECAST   AS FORECAST_VALUE,
            ff.LOWER      AS FORECAST_LOWER,
            ff.UPPER      AS FORECAST_UPPER
        FROM new_anomalies na
        LEFT JOIN ANALYTICS.FAILURE_FORECASTS ff
            ON na.MACHINE_ID = ff.SERIES
            AND DATE(na.READING_TIMESTAMP) = ff.TS::DATE
        QUALIFY ROW_NUMBER() OVER (PARTITION BY na.ANOMALY_ID ORDER BY ff.TS DESC) = 1
    )
    SELECT
        UUID_STRING()                  AS TRIAGE_ID,
        na.ANOMALY_ID,
        na.MACHINE_ID,
        m.MACHINE_TYPE,
        m.MACHINE_NAME,
        m.LOCATION,
        m.CRITICALITY,
        na.SEVERITY,
        na.ANOMALY_SCORE,
        na.HEALTH_SCORE,
        cmc.CMH_HEALTH_STATUS,
        na.READING_TIMESTAMP,
        na.SENSOR_TYPE,
        -- Operator
        oc.OPERATOR_ID,
        oc.OPERATOR_NAME,
        oc.SHIFT,
        oc.SHIFT_NOTES,
        -- Production
        pc.REJECT_RATE_PCT,
        pc.PERFORMANCE_STATUS,
        pc.CYCLE_TIME_DEVIATION_PCT,
        -- Power
        pwc.VOLTAGE,
        pwc.POWER_FACTOR,
        pwc.THD_PERCENT,
        -- Maintenance
        mc.LAST_FAILURE_TYPE,
        mc.LAST_ROOT_CAUSE,
        mc.LAST_REPAIR_ACTION,
        mc.LAST_DOWNTIME_HOURS,
        mc.LAST_MAINTENANCE_DATE,
        -- Cross-machine
        cmc.CONCERN_RANK,
        cmc.ANOMALY_COUNT_24H,
        cmc.BREACH_COUNT_24H,
        -- Parts
        ptc.PARTS_PRODUCED,
        ptc.PARTS_REJECTED,
        -- Forecasts
        fc.FORECAST_VALUE,
        fc.FORECAST_LOWER,
        fc.FORECAST_UPPER,
        -- Metadata
        na.CONTEXT_SUMMARY,
        na.AI_REASONING,
        CURRENT_TIMESTAMP()            AS CREATED_AT,
        'PENDING_TRIAGE'               AS STATUS
    FROM new_anomalies na
    INNER JOIN RAW.MACHINES m
        ON na.MACHINE_ID = m.MACHINE_ID
    LEFT JOIN operator_context oc     ON na.ANOMALY_ID = oc.ANOMALY_ID
    LEFT JOIN production_context pc   ON na.ANOMALY_ID = pc.ANOMALY_ID
    LEFT JOIN power_context pwc       ON na.ANOMALY_ID = pwc.ANOMALY_ID
    LEFT JOIN maintenance_context mc  ON na.ANOMALY_ID = mc.ANOMALY_ID
    LEFT JOIN cross_machine_context cmc ON na.ANOMALY_ID = cmc.ANOMALY_ID
    LEFT JOIN parts_context ptc       ON na.ANOMALY_ID = ptc.ANOMALY_ID
    LEFT JOIN forecast_context fc     ON na.ANOMALY_ID = fc.ANOMALY_ID;

    -- Mark processed anomalies as TRIAGED
    UPDATE ANALYTICS.DETECTED_ANOMALIES
    SET STATUS = 'TRIAGED'
    WHERE STATUS = 'NEW'
      AND SEVERITY IN ('CRITICAL', 'HIGH');

    SELECT COUNT(*) INTO :v_count
    FROM ANALYTICS.TRIAGE_QUEUE
    WHERE STATUS = 'PENDING_TRIAGE'
      AND CREATED_AT >= DATEADD('minute', -10, CURRENT_TIMESTAMP());

    RETURN 'Skill 1 complete: ' || :v_count || ' anomalies assembled and queued for triage.';
END;
$$;

-- ========================================================================
-- SKILL 2: DRAFT WORK ORDERS
-- Deduplicates by machine, uses Cortex AI to generate work order content,
-- assigns technician, estimates downtime, sets parts and rental needs.
-- ========================================================================

CREATE OR REPLACE PROCEDURE ORCHESTRATION.SKILL2_DRAFT_WORK_ORDERS()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_wo_count INTEGER DEFAULT 0;
    c1 CURSOR FOR
        SELECT
            TRIAGE_ID,
            MACHINE_ID,
            MACHINE_TYPE,
            MACHINE_NAME,
            LOCATION,
            CRITICALITY,
            SEVERITY,
            ANOMALY_SCORE,
            HEALTH_SCORE,
            HEALTH_STATUS,
            SENSOR_TYPE,
            READING_TIMESTAMP,
            OPERATOR_NAME,
            LAST_FAILURE_TYPE,
            LAST_ROOT_CAUSE,
            PERFORMANCE_STATUS,
            REJECT_RATE_PCT,
            CONTEXT_SUMMARY,
            AI_REASONING,
            ANOMALY_COUNT_24H,
            BREACH_COUNT_24H
        FROM ANALYTICS.TRIAGE_QUEUE
        WHERE STATUS = 'PENDING_TRIAGE'
        QUALIFY ROW_NUMBER() OVER (PARTITION BY MACHINE_ID ORDER BY SEVERITY DESC, ANOMALY_SCORE DESC) = 1;

    v_triage_id         VARCHAR;
    v_machine_id        VARCHAR;
    v_machine_type      VARCHAR;
    v_machine_name      VARCHAR;
    v_location          VARCHAR;
    v_criticality       VARCHAR;
    v_severity          VARCHAR;
    v_anomaly_score     FLOAT;
    v_health_score      FLOAT;
    v_health_status     VARCHAR;
    v_sensor_type       VARCHAR;
    v_reading_ts        TIMESTAMP_NTZ;
    v_operator          VARCHAR;
    v_last_failure      VARCHAR;
    v_last_root_cause   VARCHAR;
    v_perf_status       VARCHAR;
    v_reject_rate       FLOAT;
    v_context           VARCHAR;
    v_ai_reasoning      VARCHAR;
    v_anomaly_cnt       INTEGER;
    v_breach_cnt        INTEGER;

    v_ai_prompt         VARCHAR;
    v_ai_response       VARCHAR;
    v_wo_title          VARCHAR;
    v_problem_desc      VARCHAR;
    v_recommended_acts  VARCHAR;
    v_technician        VARCHAR;
    v_est_downtime      FLOAT;
    v_parts_needed      VARCHAR;
    v_rental_needed     BOOLEAN;
BEGIN
    OPEN c1;
    LOOP
        FETCH c1 INTO
            v_triage_id, v_machine_id, v_machine_type, v_machine_name,
            v_location, v_criticality, v_severity, v_anomaly_score,
            v_health_score, v_health_status, v_sensor_type, v_reading_ts,
            v_operator, v_last_failure, v_last_root_cause, v_perf_status,
            v_reject_rate, v_context, v_ai_reasoning, v_anomaly_cnt, v_breach_cnt;

        IF (SQLCODE != 0) THEN
            LEAVE;
        END IF;

        -- Build AI prompt for work order generation
        LET v_ai_prompt := CONCAT(
            'Generate a maintenance work order for the following anomaly. ',
            'Return EXACTLY three sections separated by "|||": TITLE ||| PROBLEM_DESCRIPTION ||| RECOMMENDED_ACTIONS\n\n',
            'Machine: ', v_machine_name, ' (', v_machine_type, ')\n',
            'Location: ', v_location, '\n',
            'Criticality: ', v_criticality, '\n',
            'Severity: ', v_severity, '\n',
            'Health Score: ', COALESCE(v_health_score::VARCHAR, 'N/A'), '\n',
            'Anomaly Score: ', v_anomaly_score::VARCHAR, '\n',
            'Sensor: ', COALESCE(v_sensor_type, 'N/A'), '\n',
            'Last Failure: ', COALESCE(v_last_failure, 'None'), '\n',
            'Last Root Cause: ', COALESCE(v_last_root_cause, 'None'), '\n',
            'Performance: ', COALESCE(v_perf_status, 'N/A'), '\n',
            'Reject Rate: ', COALESCE(v_reject_rate::VARCHAR, 'N/A'), '%\n',
            'Anomalies (24h): ', v_anomaly_cnt::VARCHAR, '\n',
            'Breaches (24h): ', v_breach_cnt::VARCHAR, '\n',
            'AI Reasoning: ', COALESCE(v_ai_reasoning, 'N/A'), '\n\n',
            'Be specific and actionable. Title should be under 200 chars. ',
            'Problem description under 2000 chars. Recommended actions under 2000 chars.'
        );

        LET v_ai_response := SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b', v_ai_prompt);

        -- Parse AI response sections
        LET v_wo_title := LEFT(TRIM(SPLIT_PART(v_ai_response, '|||', 1)), 200);
        LET v_problem_desc := LEFT(TRIM(SPLIT_PART(v_ai_response, '|||', 2)), 2000);
        LET v_recommended_acts := LEFT(TRIM(SPLIT_PART(v_ai_response, '|||', 3)), 2000);

        -- Assign technician based on machine type
        LET v_technician := CASE v_machine_type
            WHEN 'CNC_LATHE'        THEN 'TECH_CNC_01'
            WHEN 'HYDRAULIC_PRESS'  THEN 'TECH_HYD_01'
            WHEN 'CONVEYOR'         THEN 'TECH_CONV_01'
            WHEN 'COMPRESSOR'       THEN 'TECH_COMP_01'
            WHEN 'INJECTION_MOLDER' THEN 'TECH_INJ_01'
            WHEN 'PUMP'             THEN 'TECH_PUMP_01'
            ELSE 'TECH_GENERAL_01'
        END;

        -- Estimate downtime based on severity and machine criticality
        LET v_est_downtime := CASE
            WHEN v_severity = 'CRITICAL' AND v_criticality = 'HIGH' THEN 8.0
            WHEN v_severity = 'CRITICAL' THEN 6.0
            WHEN v_severity = 'HIGH' AND v_criticality = 'HIGH' THEN 4.0
            WHEN v_severity = 'HIGH' THEN 3.0
            ELSE 2.0
        END;

        -- Set parts needed based on machine type
        LET v_parts_needed := CASE v_machine_type
            WHEN 'CNC_LATHE'        THEN 'Spindle bearings, tool holders, coolant filters'
            WHEN 'HYDRAULIC_PRESS'  THEN 'Hydraulic seals, pressure valves, fluid filters'
            WHEN 'CONVEYOR'         THEN 'Drive belts, rollers, alignment sensors'
            WHEN 'COMPRESSOR'       THEN 'Air filters, valves, gaskets, lubricant'
            WHEN 'INJECTION_MOLDER' THEN 'Nozzle tips, heater bands, thermocouples'
            WHEN 'PUMP'             THEN 'Impeller, mechanical seals, shaft bearings'
            ELSE 'General maintenance kit'
        END;

        -- Flag rental for CRITICAL severity
        LET v_rental_needed := (v_severity = 'CRITICAL');

        -- Insert work order
        INSERT INTO ANALYTICS.WORK_ORDERS (
            WORK_ORDER_ID,
            TRIAGE_ID,
            MACHINE_ID,
            MACHINE_NAME,
            MACHINE_TYPE,
            LOCATION,
            SEVERITY,
            TITLE,
            PROBLEM_DESCRIPTION,
            RECOMMENDED_ACTIONS,
            ASSIGNED_TECHNICIAN,
            ESTIMATED_DOWNTIME_HOURS,
            PARTS_NEEDED,
            RENTAL_NEEDED,
            STATUS,
            CREATED_AT
        )
        VALUES (
            UUID_STRING(),
            v_triage_id,
            v_machine_id,
            v_machine_name,
            v_machine_type,
            v_location,
            v_severity,
            v_wo_title,
            v_problem_desc,
            v_recommended_acts,
            v_technician,
            v_est_downtime,
            v_parts_needed,
            v_rental_needed,
            'DRAFT',
            CURRENT_TIMESTAMP()
        );

        v_wo_count := v_wo_count + 1;

        -- Mark triage entry as processed
        UPDATE ANALYTICS.TRIAGE_QUEUE
        SET STATUS = 'WORK_ORDER_CREATED'
        WHERE TRIAGE_ID = :v_triage_id;

    END LOOP;
    CLOSE c1;

    RETURN 'Skill 2 complete: ' || :v_wo_count || ' work orders drafted.';
END;
$$;

-- ========================================================================
-- SKILL 3: DISPATCH AND NOTIFY
-- Assigns DRAFT work orders and sends email notifications.
-- ========================================================================

CREATE OR REPLACE PROCEDURE ORCHESTRATION.SKILL3_DISPATCH_AND_NOTIFY()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    v_dispatched INTEGER DEFAULT 0;
    c1 CURSOR FOR
        SELECT
            WORK_ORDER_ID,
            MACHINE_NAME,
            MACHINE_TYPE,
            LOCATION,
            SEVERITY,
            TITLE,
            PROBLEM_DESCRIPTION,
            RECOMMENDED_ACTIONS,
            ASSIGNED_TECHNICIAN,
            ESTIMATED_DOWNTIME_HOURS,
            PARTS_NEEDED,
            RENTAL_NEEDED
        FROM ANALYTICS.WORK_ORDERS
        WHERE STATUS = 'DRAFT';

    v_wo_id             VARCHAR;
    v_machine_name      VARCHAR;
    v_machine_type      VARCHAR;
    v_location          VARCHAR;
    v_severity          VARCHAR;
    v_title             VARCHAR;
    v_problem_desc      VARCHAR;
    v_recommended_acts  VARCHAR;
    v_technician        VARCHAR;
    v_est_downtime      FLOAT;
    v_parts_needed      VARCHAR;
    v_rental_needed     BOOLEAN;
    v_email_subject     VARCHAR;
    v_email_body        VARCHAR;
BEGIN
    -- Update all DRAFT work orders to ASSIGNED
    UPDATE ANALYTICS.WORK_ORDERS
    SET STATUS = 'ASSIGNED',
        ASSIGNED_AT = CURRENT_TIMESTAMP()
    WHERE STATUS = 'DRAFT';

    OPEN c1;
    LOOP
        FETCH c1 INTO
            v_wo_id, v_machine_name, v_machine_type, v_location,
            v_severity, v_title, v_problem_desc, v_recommended_acts,
            v_technician, v_est_downtime, v_parts_needed, v_rental_needed;

        IF (SQLCODE != 0) THEN
            LEAVE;
        END IF;

        LET v_email_subject := CONCAT(
            '[', v_severity, '] Maintenance Work Order: ', v_machine_name, ' - ', LEFT(v_title, 80)
        );

        LET v_email_body := CONCAT(
            '=== MAINTENANCE WORK ORDER ===\n\n',
            'Work Order ID: ', v_wo_id, '\n',
            'Machine: ', v_machine_name, ' (', v_machine_type, ')\n',
            'Location: ', v_location, '\n',
            'Severity: ', v_severity, '\n',
            'Assigned To: ', v_technician, '\n',
            'Estimated Downtime: ', v_est_downtime::VARCHAR, ' hours\n\n',
            '--- TITLE ---\n', v_title, '\n\n',
            '--- PROBLEM DESCRIPTION ---\n', v_problem_desc, '\n\n',
            '--- RECOMMENDED ACTIONS ---\n', v_recommended_acts, '\n\n',
            '--- PARTS NEEDED ---\n', v_parts_needed, '\n',
            'Rental Equipment Needed: ', IFF(v_rental_needed, 'YES', 'NO'), '\n\n',
            '=== END OF WORK ORDER ===\n',
            'Generated: ', CURRENT_TIMESTAMP()::VARCHAR
        );

        CALL SYSTEM$SEND_EMAIL(
            'IOT_EMAIL_NOTIFICATIONS',
            'bbalamu5@ford.com',
            :v_email_subject,
            :v_email_body
        );

        v_dispatched := v_dispatched + 1;

    END LOOP;
    CLOSE c1;

    RETURN 'Skill 3 complete: ' || :v_dispatched || ' work orders dispatched and notifications sent.';
END;
$$;

-- ========================================================================
-- ORCHESTRATION TASK: 5-minute pipeline
-- Calls Skill1 -> Skill2 -> Skill3 in sequence
-- Created SUSPENDED — resume manually when ready.
-- ========================================================================

CREATE OR REPLACE TASK ORCHESTRATION.MAINTENANCE_PIPELINE_TASK
    WAREHOUSE = IOT_ML_WH
    SCHEDULE = '5 MINUTES'
    COMMENT = 'IoT Predictive Maintenance pipeline: assemble context, draft work orders, dispatch and notify'
AS
BEGIN
    CALL ORCHESTRATION.SKILL1_ASSEMBLE_CONTEXT();
    CALL ORCHESTRATION.SKILL2_DRAFT_WORK_ORDERS();
    CALL ORCHESTRATION.SKILL3_DISPATCH_AND_NOTIFY();
END;

-- Task is created in SUSPENDED state by default.
-- To activate: ALTER TASK ORCHESTRATION.MAINTENANCE_PIPELINE_TASK RESUME;

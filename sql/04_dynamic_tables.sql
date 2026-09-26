/*==========================================================================
  04_dynamic_tables.sql — IoT Predictive Maintenance Platform
  Dynamic Tables for streaming transformation pipeline
  Database: IOT_PREDICTIVE_MAINTENANCE
==========================================================================*/

USE DATABASE IOT_PREDICTIVE_MAINTENANCE;
USE WAREHOUSE IOT_ML_WH;

-- ========================================================================
-- ENABLE CHANGE TRACKING ON RAW TABLES
-- ========================================================================

ALTER TABLE RAW.SENSOR_READINGS      SET CHANGE_TRACKING = TRUE;
ALTER TABLE RAW.MACHINES             SET CHANGE_TRACKING = TRUE;
ALTER TABLE RAW.SENSORS              SET CHANGE_TRACKING = TRUE;
ALTER TABLE RAW.SHIFT_LOGS           SET CHANGE_TRACKING = TRUE;
ALTER TABLE RAW.MACHINE_EVENT_LOGS   SET CHANGE_TRACKING = TRUE;
ALTER TABLE RAW.PRODUCTION_QUALITY   SET CHANGE_TRACKING = TRUE;
ALTER TABLE RAW.POWER_QUALITY_LOGS   SET CHANGE_TRACKING = TRUE;
ALTER TABLE RAW.MAINTENANCE_HISTORY  SET CHANGE_TRACKING = TRUE;

-- ========================================================================
-- DT1: STAGING.SENSOR_READINGS_CLEAN
-- Cleans, normalizes, and enriches raw sensor readings
-- ========================================================================

CREATE OR REPLACE DYNAMIC TABLE STAGING.SENSOR_READINGS_CLEAN
    TARGET_LAG = DOWNSTREAM
    REFRESH_MODE = FULL
    WAREHOUSE = IOT_ML_WH
AS
WITH raw_enriched AS (
    SELECT
        sr.READING_ID,
        sr.SENSOR_ID,
        sr.MACHINE_ID,
        sr.READING_TIMESTAMP,
        sr.SENSOR_TYPE,
        sr.READING_VALUE,
        sr.UNIT,
        sr.QUALITY_FLAG,
        sr.IS_ANOMALY,
        s.MIN_THRESHOLD,
        s.MAX_THRESHOLD,
        s.SENSOR_STATUS,
        m.MACHINE_TYPE,
        m.MACHINE_NAME,
        m.LOCATION,
        m.CRITICALITY,
        m.RATED_POWER_KW
    FROM RAW.SENSOR_READINGS sr
    INNER JOIN RAW.SENSORS s
        ON sr.SENSOR_ID = s.SENSOR_ID
    INNER JOIN RAW.MACHINES m
        ON sr.MACHINE_ID = m.MACHINE_ID
    WHERE sr.QUALITY_FLAG != 'BAD'
),
imputed AS (
    SELECT
        *,
        COALESCE(
            READING_VALUE,
            AVG(READING_VALUE) OVER (
                PARTITION BY MACHINE_ID, SENSOR_TYPE
                ORDER BY READING_TIMESTAMP
                ROWS BETWEEN 10 PRECEDING AND 10 FOLLOWING
            )
        ) AS CLEAN_VALUE
    FROM raw_enriched
)
SELECT
    READING_ID,
    SENSOR_ID,
    MACHINE_ID,
    READING_TIMESTAMP,
    SENSOR_TYPE,
    READING_VALUE       AS RAW_VALUE,
    CLEAN_VALUE,
    UNIT,
    QUALITY_FLAG,
    IS_ANOMALY,
    MIN_THRESHOLD,
    MAX_THRESHOLD,
    CASE
        WHEN (MAX_THRESHOLD - MIN_THRESHOLD) = 0 THEN NULL
        ELSE (CLEAN_VALUE - MIN_THRESHOLD) / (MAX_THRESHOLD - MIN_THRESHOLD)
    END AS NORMALIZED_VALUE,
    CASE
        WHEN CLEAN_VALUE > MAX_THRESHOLD THEN 'ABOVE_MAX'
        WHEN CLEAN_VALUE < MIN_THRESHOLD THEN 'BELOW_MIN'
        ELSE 'NORMAL'
    END AS THRESHOLD_STATUS,
    MACHINE_TYPE,
    MACHINE_NAME,
    LOCATION,
    CRITICALITY,
    RATED_POWER_KW
FROM imputed;

-- ========================================================================
-- DT2: STAGING.MACHINE_HEALTH_FEATURES
-- Rolling window aggregates for ML feature engineering
-- ========================================================================

CREATE OR REPLACE DYNAMIC TABLE STAGING.MACHINE_HEALTH_FEATURES
    TARGET_LAG = DOWNSTREAM
    REFRESH_MODE = FULL
    WAREHOUSE = IOT_ML_WH
AS
SELECT
    READING_ID,
    SENSOR_ID,
    MACHINE_ID,
    READING_TIMESTAMP,
    SENSOR_TYPE,
    CLEAN_VALUE,
    NORMALIZED_VALUE,
    THRESHOLD_STATUS,
    IS_ANOMALY,
    MACHINE_TYPE,
    MACHINE_NAME,
    LOCATION,
    CRITICALITY,
    UNIT,

    -- 1-hour rolling (2 preceding ~ 3 rows at 30-min intervals)
    ROUND(AVG(CLEAN_VALUE) OVER w_1h, 4)    AS AVG_1H,
    ROUND(STDDEV(CLEAN_VALUE) OVER w_1h, 4)  AS STDDEV_1H,
    ROUND(MAX(CLEAN_VALUE) OVER w_1h, 4)    AS MAX_1H,
    ROUND(MIN(CLEAN_VALUE) OVER w_1h, 4)    AS MIN_1H,

    -- 6-hour rolling (12 preceding)
    ROUND(AVG(CLEAN_VALUE) OVER w_6h, 4)    AS AVG_6H,
    ROUND(STDDEV(CLEAN_VALUE) OVER w_6h, 4)  AS STDDEV_6H,
    ROUND(MAX(CLEAN_VALUE) OVER w_6h, 4)    AS MAX_6H,

    -- 24-hour rolling (48 preceding)
    ROUND(AVG(CLEAN_VALUE) OVER w_24h, 4)   AS AVG_24H,
    ROUND(STDDEV(CLEAN_VALUE) OVER w_24h, 4) AS STDDEV_24H,

    -- Delta from previous reading
    ROUND(CLEAN_VALUE - LAG(CLEAN_VALUE) OVER (
        PARTITION BY MACHINE_ID, SENSOR_TYPE
        ORDER BY READING_TIMESTAMP
    ), 4) AS DELTA_PREV,

    -- Z-score relative to 24h window
    ROUND(
        CASE
            WHEN STDDEV(CLEAN_VALUE) OVER w_24h = 0 OR STDDEV(CLEAN_VALUE) OVER w_24h IS NULL
            THEN 0
            ELSE (CLEAN_VALUE - AVG(CLEAN_VALUE) OVER w_24h)
                 / STDDEV(CLEAN_VALUE) OVER w_24h
        END, 4
    ) AS Z_SCORE_24H

FROM STAGING.SENSOR_READINGS_CLEAN
WINDOW
    w_1h  AS (PARTITION BY MACHINE_ID, SENSOR_TYPE ORDER BY READING_TIMESTAMP ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
    w_6h  AS (PARTITION BY MACHINE_ID, SENSOR_TYPE ORDER BY READING_TIMESTAMP ROWS BETWEEN 12 PRECEDING AND CURRENT ROW),
    w_24h AS (PARTITION BY MACHINE_ID, SENSOR_TYPE ORDER BY READING_TIMESTAMP ROWS BETWEEN 48 PRECEDING AND CURRENT ROW);

-- ========================================================================
-- DT3: STAGING.PERFORMANCE_BASELINE
-- Production quality baselines and deviation tracking
-- ========================================================================

CREATE OR REPLACE DYNAMIC TABLE STAGING.PERFORMANCE_BASELINE
    TARGET_LAG = DOWNSTREAM
    REFRESH_MODE = FULL
    WAREHOUSE = IOT_ML_WH
AS
WITH production_enriched AS (
    SELECT
        pq.QUALITY_ID,
        pq.MACHINE_ID,
        pq.PRODUCTION_DATE,
        pq.SHIFT,
        pq.PARTS_PRODUCED,
        pq.PARTS_REJECTED,
        pq.CYCLE_TIME_SECONDS,
        pq.TOLERANCE_DEVIATION_MM,
        pq.SURFACE_FINISH_RA,
        m.MACHINE_TYPE,
        m.MACHINE_NAME,
        m.LOCATION,
        m.CRITICALITY,
        CASE
            WHEN pq.PARTS_PRODUCED = 0 THEN 0
            ELSE ROUND(pq.PARTS_REJECTED * 100.0 / pq.PARTS_PRODUCED, 4)
        END AS REJECT_RATE_PCT,
        pq.CYCLE_TIME_SECONDS - LAG(pq.CYCLE_TIME_SECONDS) OVER (
            PARTITION BY pq.MACHINE_ID
            ORDER BY pq.PRODUCTION_DATE, pq.SHIFT
        ) AS CYCLE_TIME_DELTA
    FROM RAW.PRODUCTION_QUALITY pq
    INNER JOIN RAW.MACHINES m
        ON pq.MACHINE_ID = m.MACHINE_ID
),
with_baselines AS (
    SELECT
        *,
        -- 7-day rolling baselines (21-row window ~ 3 shifts/day * 7 days)
        ROUND(AVG(CYCLE_TIME_SECONDS) OVER w_7d, 4)       AS BASELINE_CYCLE_TIME,
        ROUND(AVG(TOLERANCE_DEVIATION_MM) OVER w_7d, 4)    AS BASELINE_TOLERANCE,
        ROUND(AVG(SURFACE_FINISH_RA) OVER w_7d, 4)         AS BASELINE_SURFACE_FINISH
    FROM production_enriched
    WINDOW w_7d AS (
        PARTITION BY MACHINE_ID
        ORDER BY PRODUCTION_DATE, SHIFT
        ROWS BETWEEN 21 PRECEDING AND CURRENT ROW
    )
)
SELECT
    QUALITY_ID,
    MACHINE_ID,
    PRODUCTION_DATE,
    SHIFT,
    PARTS_PRODUCED,
    PARTS_REJECTED,
    REJECT_RATE_PCT,
    CYCLE_TIME_SECONDS,
    CYCLE_TIME_DELTA,
    TOLERANCE_DEVIATION_MM,
    SURFACE_FINISH_RA,
    MACHINE_TYPE,
    MACHINE_NAME,
    LOCATION,
    CRITICALITY,

    BASELINE_CYCLE_TIME,
    BASELINE_TOLERANCE,
    BASELINE_SURFACE_FINISH,

    -- Deviation from baseline as percentage
    ROUND(
        CASE WHEN BASELINE_CYCLE_TIME = 0 THEN 0
             ELSE ABS(CYCLE_TIME_SECONDS - BASELINE_CYCLE_TIME) / BASELINE_CYCLE_TIME * 100
        END, 4
    ) AS CYCLE_TIME_DEVIATION_PCT,
    ROUND(
        CASE WHEN BASELINE_TOLERANCE = 0 THEN 0
             ELSE ABS(TOLERANCE_DEVIATION_MM - BASELINE_TOLERANCE) / BASELINE_TOLERANCE * 100
        END, 4
    ) AS TOLERANCE_DEVIATION_PCT,
    ROUND(
        CASE WHEN BASELINE_SURFACE_FINISH = 0 THEN 0
             ELSE ABS(SURFACE_FINISH_RA - BASELINE_SURFACE_FINISH) / BASELINE_SURFACE_FINISH * 100
        END, 4
    ) AS SURFACE_FINISH_DEVIATION_PCT,

    CASE
        WHEN REJECT_RATE_PCT > 10
             OR GREATEST(CYCLE_TIME_DEVIATION_PCT,
                         TOLERANCE_DEVIATION_PCT,
                         SURFACE_FINISH_DEVIATION_PCT) > 15
        THEN 'DEGRADED'
        WHEN REJECT_RATE_PCT > 5
             OR GREATEST(CYCLE_TIME_DEVIATION_PCT,
                         TOLERANCE_DEVIATION_PCT,
                         SURFACE_FINISH_DEVIATION_PCT) > 8
        THEN 'WARNING'
        ELSE 'HEALTHY'
    END AS PERFORMANCE_STATUS

FROM with_baselines;

-- ========================================================================
-- DT4: STAGING.CROSS_MACHINE_HEALTH
-- Composite health score and fleet-wide ranking
-- ========================================================================

CREATE OR REPLACE DYNAMIC TABLE STAGING.CROSS_MACHINE_HEALTH
    TARGET_LAG = '5 minutes'
    REFRESH_MODE = FULL
    WAREHOUSE = IOT_ML_WH
AS
WITH latest_features AS (
    SELECT
        MACHINE_ID,
        MACHINE_TYPE,
        MACHINE_NAME,
        LOCATION,
        CRITICALITY,
        -- Anomaly counts in last 24h
        COUNT_IF(IS_ANOMALY = TRUE) AS ANOMALY_COUNT_24H,
        COUNT_IF(THRESHOLD_STATUS != 'NORMAL') AS BREACH_COUNT_24H,
        -- Aggregate z-score and variability metrics
        AVG(ABS(Z_SCORE_24H))  AS AVG_ABS_Z_SCORE,
        MAX(ABS(Z_SCORE_24H))  AS MAX_ABS_Z_SCORE,
        AVG(STDDEV_1H)         AS AVG_VARIABILITY,
        COUNT(*)               AS READING_COUNT
    FROM STAGING.MACHINE_HEALTH_FEATURES
    WHERE READING_TIMESTAMP >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
    GROUP BY MACHINE_ID, MACHINE_TYPE, MACHINE_NAME, LOCATION, CRITICALITY
),
scored AS (
    SELECT
        *,
        -- Composite health score (0-100)
        GREATEST(0, LEAST(100,
            100
            -- Z-score penalty (max 30): penalize high average z-scores
            - LEAST(30, AVG_ABS_Z_SCORE * 10)
            -- Anomaly penalty (max 30): penalize anomaly frequency
            - LEAST(30, ANOMALY_COUNT_24H * 3)
            -- Breach penalty (max 20): penalize threshold breaches
            - LEAST(20, BREACH_COUNT_24H * 2)
            -- Variability penalty (max 20): penalize high variability
            - LEAST(20, COALESCE(AVG_VARIABILITY, 0) * 5)
        )) AS HEALTH_SCORE
    FROM latest_features
)
SELECT
    MACHINE_ID,
    MACHINE_TYPE,
    MACHINE_NAME,
    LOCATION,
    CRITICALITY,
    ROUND(HEALTH_SCORE, 2) AS HEALTH_SCORE,
    CASE
        WHEN HEALTH_SCORE < 40  THEN 'CRITICAL'
        WHEN HEALTH_SCORE < 60  THEN 'WARNING'
        WHEN HEALTH_SCORE < 80  THEN 'FAIR'
        ELSE 'GOOD'
    END AS HEALTH_STATUS,
    RANK() OVER (ORDER BY HEALTH_SCORE ASC) AS CONCERN_RANK,
    ANOMALY_COUNT_24H,
    BREACH_COUNT_24H,
    ROUND(AVG_ABS_Z_SCORE, 4)  AS AVG_ABS_Z_SCORE,
    ROUND(MAX_ABS_Z_SCORE, 4)  AS MAX_ABS_Z_SCORE,
    ROUND(AVG_VARIABILITY, 4)  AS AVG_VARIABILITY,
    READING_COUNT,
    CURRENT_TIMESTAMP()        AS LAST_CALCULATED_AT
FROM scored;

-- ========================================================================
-- DT5: ANALYTICS.ANOMALY_CONTEXT
-- Enriched anomaly events with multi-domain context
-- ========================================================================

CREATE OR REPLACE DYNAMIC TABLE ANALYTICS.ANOMALY_CONTEXT
    TARGET_LAG = '5 minutes'
    REFRESH_MODE = FULL
    WAREHOUSE = IOT_ML_WH
AS
WITH anomalous_readings AS (
    SELECT *
    FROM STAGING.MACHINE_HEALTH_FEATURES
    WHERE IS_ANOMALY = TRUE
       OR THRESHOLD_STATUS != 'NORMAL'
       OR ABS(Z_SCORE_24H) > 2.5
),

-- Nearest shift log for each anomaly (same day)
shift_ranked AS (
    SELECT
        ar.READING_ID,
        sl.SHIFT_ID,
        sl.SHIFT,
        sl.OPERATOR_ID,
        sl.OPERATOR_NAME,
        sl.NOTES AS SHIFT_NOTES,
        ROW_NUMBER() OVER (
            PARTITION BY ar.READING_ID
            ORDER BY ABS(DATEDIFF('minute', ar.READING_TIMESTAMP, sl.SHIFT_START))
        ) AS rn
    FROM anomalous_readings ar
    LEFT JOIN RAW.SHIFT_LOGS sl
        ON ar.MACHINE_ID = sl.MACHINE_ID
        AND DATE(ar.READING_TIMESTAMP) = DATE(sl.SHIFT_START)
),
nearest_shift AS (
    SELECT * FROM shift_ranked WHERE rn = 1
),

-- Performance baseline for same date and shift
perf_ranked AS (
    SELECT
        ar.READING_ID,
        pb.REJECT_RATE_PCT,
        pb.PERFORMANCE_STATUS,
        pb.CYCLE_TIME_DEVIATION_PCT,
        pb.TOLERANCE_DEVIATION_PCT,
        pb.SURFACE_FINISH_DEVIATION_PCT,
        ROW_NUMBER() OVER (
            PARTITION BY ar.READING_ID
            ORDER BY pb.PRODUCTION_DATE DESC
        ) AS rn
    FROM anomalous_readings ar
    LEFT JOIN STAGING.PERFORMANCE_BASELINE pb
        ON ar.MACHINE_ID = pb.MACHINE_ID
        AND DATE(ar.READING_TIMESTAMP) = pb.PRODUCTION_DATE
),
nearest_perf AS (
    SELECT * FROM perf_ranked WHERE rn = 1
),

-- Power quality for same hour
power_ranked AS (
    SELECT
        ar.READING_ID,
        pql.VOLTAGE,
        pql.CURRENT_AMPS,
        pql.POWER_FACTOR,
        pql.FREQUENCY_HZ,
        pql.THD_PERCENT,
        ROW_NUMBER() OVER (
            PARTITION BY ar.READING_ID
            ORDER BY ABS(DATEDIFF('minute', ar.READING_TIMESTAMP, pql.LOG_TIMESTAMP))
        ) AS rn
    FROM anomalous_readings ar
    LEFT JOIN RAW.POWER_QUALITY_LOGS pql
        ON ar.MACHINE_ID = pql.MACHINE_ID
        AND DATE_TRUNC('hour', ar.READING_TIMESTAMP) = DATE_TRUNC('hour', pql.LOG_TIMESTAMP)
),
nearest_power AS (
    SELECT * FROM power_ranked WHERE rn = 1
),

-- Most recent failure per machine from maintenance history
maint_ranked AS (
    SELECT
        ar.READING_ID,
        mh.MAINTENANCE_ID,
        mh.FAILURE_TYPE,
        mh.ROOT_CAUSE,
        mh.REPAIR_ACTION,
        mh.DOWNTIME_HOURS,
        mh.MAINTENANCE_DATE,
        ROW_NUMBER() OVER (
            PARTITION BY ar.READING_ID
            ORDER BY mh.MAINTENANCE_DATE DESC
        ) AS rn
    FROM anomalous_readings ar
    LEFT JOIN RAW.MAINTENANCE_HISTORY mh
        ON ar.MACHINE_ID = mh.MACHINE_ID
        AND mh.MAINTENANCE_DATE <= DATE(ar.READING_TIMESTAMP)
),
nearest_maint AS (
    SELECT * FROM maint_ranked WHERE rn = 1
)

SELECT
    ar.READING_ID,
    ar.MACHINE_ID,
    ar.MACHINE_TYPE,
    ar.MACHINE_NAME,
    ar.LOCATION,
    ar.CRITICALITY,
    ar.READING_TIMESTAMP,
    ar.SENSOR_TYPE,
    ar.CLEAN_VALUE,
    ar.NORMALIZED_VALUE,
    ar.THRESHOLD_STATUS,
    ar.IS_ANOMALY,
    ar.Z_SCORE_24H,
    ar.AVG_1H,
    ar.STDDEV_1H,
    ar.AVG_24H,
    ar.STDDEV_24H,
    ar.DELTA_PREV,

    -- Shift context
    ns.SHIFT_ID,
    ns.SHIFT,
    ns.OPERATOR_ID,
    ns.OPERATOR_NAME,
    ns.SHIFT_NOTES,

    -- Performance context
    np.REJECT_RATE_PCT,
    np.PERFORMANCE_STATUS,
    np.CYCLE_TIME_DEVIATION_PCT,
    np.TOLERANCE_DEVIATION_PCT,
    np.SURFACE_FINISH_DEVIATION_PCT,

    -- Power quality context
    npw.VOLTAGE,
    npw.CURRENT_AMPS,
    npw.POWER_FACTOR,
    npw.FREQUENCY_HZ,
    npw.THD_PERCENT,

    -- Maintenance history context
    nm.MAINTENANCE_ID         AS LAST_MAINTENANCE_ID,
    nm.FAILURE_TYPE           AS LAST_FAILURE_TYPE,
    nm.ROOT_CAUSE             AS LAST_ROOT_CAUSE,
    nm.REPAIR_ACTION          AS LAST_REPAIR_ACTION,
    nm.DOWNTIME_HOURS         AS LAST_DOWNTIME_HOURS,
    nm.MAINTENANCE_DATE       AS LAST_MAINTENANCE_DATE,

    -- Cross-machine health context
    cmh.HEALTH_SCORE,
    cmh.HEALTH_STATUS,
    cmh.CONCERN_RANK,
    cmh.ANOMALY_COUNT_24H,
    cmh.BREACH_COUNT_24H

FROM anomalous_readings ar
LEFT JOIN nearest_shift ns
    ON ar.READING_ID = ns.READING_ID
LEFT JOIN nearest_perf np
    ON ar.READING_ID = np.READING_ID
LEFT JOIN nearest_power npw
    ON ar.READING_ID = npw.READING_ID
LEFT JOIN nearest_maint nm
    ON ar.READING_ID = nm.READING_ID
LEFT JOIN STAGING.CROSS_MACHINE_HEALTH cmh
    ON ar.MACHINE_ID = cmh.MACHINE_ID;

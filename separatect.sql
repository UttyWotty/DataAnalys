WITH ShotData AS (
    SELECT 
        ds.COUNTER_CODE,
        ds.SHOT_START_TIME,
        ds.SHOT_END_TIME,
        ds.SHOT_COUNT,
        ds.CONTENT,
        CAST(f.value:ct AS FLOAT) AS ct, -- Parse JSON value as float directly
        TO_CHAR(TO_TIMESTAMP(TRY_TO_NUMBER(f.value:time::STRING)), 'YYYY-MM-DD HH24:MI:SS') AS shot_time,
        ROW_NUMBER() OVER (
            PARTITION BY ds.COUNTER_CODE, ds.SHOT_START_TIME 
            ORDER BY TRY_TO_NUMBER(f.value:time::STRING) ASC
        ) AS shot_sequence
    FROM 
        DATA_SHOT ds,
        LATERAL FLATTEN(input => TRY_PARSE_JSON(ds.CONTENT)) AS f
    WHERE 
        ds.CONTENT IS NOT NULL
        AND f.value:ct IS NOT NULL
),



AverageCT AS (
    SELECT 
        COUNTER_CODE,
        SHOT_START_TIME,
        shot_sequence,
        AVG(ct) AS avg_ct
    FROM 
        ShotData
    WHERE 
        ct != 1000
    GROUP BY 
        COUNTER_CODE, 
        SHOT_START_TIME,
        shot_sequence
),
MedianCT AS (
    SELECT 
        COUNTER_CODE,
        SHOT_START_TIME,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_ct) AS Median_CT
    FROM 
        AverageCT
    GROUP BY 
        COUNTER_CODE, 
        SHOT_START_TIME
),
PercentileCT AS (
    SELECT 
        COUNTER_CODE,
        SHOT_START_TIME,
        PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY ct) AS CT_5th,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY ct) AS CT_95th
    FROM 
        ShotData
    where 
    ct != 1000
    GROUP BY 
        COUNTER_CODE, 
        SHOT_START_TIME
),
ClassifiedShotData AS (
    SELECT 
        sd.COUNTER_CODE,
        sd.SHOT_START_TIME,
        sd.SHOT_END_TIME,
        sd.SHOT_COUNT,
        sd.ct,
        sd.shot_time,
        sd.shot_sequence,
        --stats.mean_ct,
        --stats.stddev_ct,
        --CASE 
          --  WHEN sd.ct = 1000 THEN 'invalid'
           -- WHEN sd.shot_sequence = 1 THEN 'warmup_scrap'
            -- Step 3: Handle Division by Zero and Outlier Classification using Z-score
           -- WHEN stats.stddev_ct = 0 THEN 'no_variation' -- Handle cases where stddev = 0
            --WHEN ABS(sd.ct - stats.mean_ct) / NULLIF(stats.stddev_ct, 0) > 2 THEN 'outlier'  -- Avoid division by zero
            --ELSE 'valid_shot'
        pct.CT_5th,
        pct.CT_95th,
        CASE 
            WHEN sd.ct = 1000 THEN 'invalid'
            --WHEN sd.shot_sequence = 1 THEN 'warmup_scrap'
            WHEN sd.ct < pct.CT_5th THEN 'short_ct_scrap' -- Below 5th percentile
            WHEN sd.ct > pct.CT_95th THEN 'long_ct_scrap' -- Above 95th percentile
            WHEN sd.ct < (pct.CT_5th * 0.9) THEN 'short_ct_scrap'  -- Consider values within 10% of the 5th percentile as outliers
            WHEN sd.ct > (pct.CT_95th * 1.1) THEN 'long_ct_scrap' -- Consider values within 10% above the 95th percentile as outliers
            ELSE 'valid_shot'
        END AS shot_type
    FROM 
        ShotData sd
   -- LEFT JOIN Stats stats 
    --    ON sd.COUNTER_CODE = stats.COUNTER_CODE
     --   AND sd.SHOT_START_TIME = stats.SHOT_START_TIME
--),
      LEFT JOIN PercentileCT pct ON 
        sd.COUNTER_CODE = pct.COUNTER_CODE AND 
        sd.SHOT_START_TIME = pct.SHOT_START_TIME
),
FilteredShotData AS (
    SELECT 
        COUNTER_CODE,
        SHOT_START_TIME,
        SHOT_END_TIME,
        SHOT_COUNT,
        --CONTENT,
        ct,
        shot_time,
        shot_sequence
    FROM 
        ClassifiedShotData
    WHERE 
        shot_type = 'valid_shot'
),
ValidShotSummary AS (
    SELECT 
        COUNTER_CODE,
        SHOT_START_TIME,
        SHOT_END_TIME,
        SUM(ct) AS production_time  -- valid_shot의 ct 값만 합산
    FROM 
        ClassifiedShotData 
    WHERE 
        shot_type = 'valid_shot'
    GROUP BY 
        COUNTER_CODE,
        SHOT_START_TIME,
        SHOT_END_TIME
),
-- Join with MOLD data to compute thresholds and categorize each valid shot
ValidShotWithThresholds AS (
    SELECT 
        fsd.COUNTER_CODE,
        fsd.SHOT_START_TIME,
        fsd.SHOT_END_TIME,
        fsd.SHOT_COUNT,
        --fsd.CONTENT,
        fsd.ct,
        fsd.shot_time,
        fsd.shot_sequence,
        c.LAST_TERMINAL_ID,
        -- 평균 ct를 contracted_cycle_time_must로 설정
        m.contracted_cycle_time/10 AS contracted_cycle_time_must,
        m.cycle_time_limit1,
        m.cycle_time_limit1unit,
        m.cycle_time_limit2, 
        m.cycle_time_limit2unit,
        -- Adjusted Limits with /10
        CASE 
            WHEN m.cycle_time_limit1unit = 'PERCENTAGE' THEN 
                (contracted_cycle_time_must * (1 + (m.cycle_time_limit1 / 100)))
            ELSE 
                (contracted_cycle_time_must + m.cycle_time_limit1)
        END AS L1_above_adjusted,
        CASE 
            WHEN m.cycle_time_limit2unit = 'PERCENTAGE' THEN 
                (contracted_cycle_time_must * (1 + (m.cycle_time_limit2 / 100)))
            ELSE 
                (contracted_cycle_time_must + m.cycle_time_limit2)
        END AS L2_above_adjusted,
        CASE 
            WHEN m.cycle_time_limit1unit = 'PERCENTAGE' THEN 
                (contracted_cycle_time_must * (1 - (m.cycle_time_limit1 / 100)))
            ELSE 
                (contracted_cycle_time_must - m.cycle_time_limit1)
        END AS L1_below_adjusted,
        CASE 
            WHEN m.cycle_time_limit2unit = 'PERCENTAGE' THEN 
                (contracted_cycle_time_must * (1 - (m.cycle_time_limit2 / 100)))
            ELSE 
                (contracted_cycle_time_must - m.cycle_time_limit2)
        END AS L2_below_adjusted
    FROM 
        FilteredShotData fsd
    LEFT JOIN (
        SELECT DISTINCT EQUIPMENT_CODE, ID, COMPANY_ID, LAST_TERMINAL_ID
        FROM COUNTER
    ) AS c ON fsd.COUNTER_CODE = c.EQUIPMENT_CODE
    LEFT JOIN (
        SELECT DISTINCT 
            ID, COUNTER_ID, equipment_code, location_id, 
            contracted_cycle_time, weighted_average_cycle_time, 
            cycle_time_limit1, cycle_time_limit1unit, 
            cycle_time_limit2, cycle_time_limit2unit 
        FROM MOLD
    ) AS m ON c.ID = m.COUNTER_ID
),
-- Aggregate counts and average ct of 'above', 'within', and 'below' shots
ProductionSummary AS (
    SELECT 
        vswt.COUNTER_CODE,
        vswt.LAST_TERMINAL_ID,
        vswt.SHOT_START_TIME,
        vswt.SHOT_END_TIME,
        vswt.ct,
        vswt.shot_sequence,
        vswt.shot_time,
        
        MAX(vswt.SHOT_COUNT) AS shot_count,
        --MAX(vswt.CONTENT) AS content,
        COUNT(*) AS valid_shot_count,
        AVG(vswt.ct) AS avg_ct,
        -- 각 샷의 ct를 기준으로 조건에 따라 카운트
        SUM(CASE 
            WHEN vswt.ct > vswt.L1_above_adjusted THEN 1
            ELSE 0 
        END) AS above_count,
    
        SUM(CASE 
            WHEN vswt.ct < vswt.L1_below_adjusted THEN 1
            ELSE 0 
        END) AS below_count,
    
        SUM(CASE 
            WHEN vswt.ct BETWEEN vswt.L1_below_adjusted AND vswt.L1_above_adjusted THEN 1 
            ELSE 0 
        END) AS within_count,
        
        AVG(CASE 
            WHEN vswt.ct > vswt.L1_above_adjusted THEN vswt.ct
            ELSE NULL
        END) AS above_avg_ct,
        
        AVG(CASE 
            WHEN vswt.ct BETWEEN vswt.L1_below_adjusted AND vswt.L1_above_adjusted THEN vswt.ct
            ELSE NULL
        END) AS within_avg_ct,
        
        AVG(CASE 
            WHEN vswt.ct < vswt.L1_below_adjusted THEN vswt.ct
            ELSE NULL
        END) AS below_avg_ct,
        vswt.contracted_cycle_time_must,
        MAX(vswt.cycle_time_limit1) AS cycle_time_limit1,
        MAX(vswt.cycle_time_limit1unit) AS cycle_time_limit1unit,
        MAX(vswt.cycle_time_limit2) AS cycle_time_limit2,
        MAX(vswt.cycle_time_limit2unit) AS cycle_time_limit2unit,
        MAX(vswt.L1_above_adjusted) AS L1_above_adjusted,
        MAX(vswt.L2_above_adjusted) AS L2_above_adjusted,
        MAX(vswt.L1_below_adjusted) AS L1_below_adjusted,
        MAX(vswt.L2_below_adjusted) AS L2_below_adjusted
    FROM 
        ValidShotWithThresholds vswt
    GROUP BY 
        vswt.COUNTER_CODE, 
        vswt.LAST_TERMINAL_ID,
        vswt.SHOT_START_TIME, 
        vswt.SHOT_END_TIME,
        vswt.ct,
        vswt.shot_sequence,
        vswt.shot_time,
        
        vswt.contracted_cycle_time_must
),
TotalSessionTime AS (
    SELECT 
        COUNTER_CODE,
        SHOT_START_TIME,
        SHOT_END_TIME,
        SUM(CASE WHEN ct != 1000 THEN ct ELSE 0 END) AS total_session_time
    FROM 
        ShotData
    GROUP BY 
        COUNTER_CODE, 
        SHOT_START_TIME, 
        SHOT_END_TIME
)
SELECT 
    co.name AS company_name,
    lo.name AS plant_name,
    m.equipment_code,
    ps.COUNTER_CODE,
    ps.SHOT_START_TIME,
    ps.SHOT_END_TIME,
    ps.cycle_time_limit1, 
    ps.cycle_time_limit1unit, 
    ps.cycle_time_limit2,
    ps.cycle_time_limit2unit,

    -- Adjusted Limits (이미 ProductionSummary에서 계산됨)
    ps.L1_above_adjusted,
    ps.L2_above_adjusted,
    ps.L1_below_adjusted,
    ps.L2_below_adjusted,

    -- Additional columns
    ps.contracted_cycle_time_must as contracted_cycle_time,  -- 변경된 부분: 평균 ct 값으로 대체됨
   

        -- Average ct of valid shots
    ROUND(ps.avg_ct, 2) AS avg_valid_ct,
    ps.shot_count,
       -- Counts of ct categories
    ps.above_count,
    ps.within_count,
    ps.below_count,
    --ps.content,
    ps.ct,
    ps.shot_sequence,
    ps.shot_time,

    -- Average ct values for each category
    ROUND(ps.above_avg_ct, 2) AS above_avg_ct,
    ROUND(ps.within_avg_ct, 2) AS within_avg_ct,
    ROUND(ps.below_avg_ct, 2) AS below_avg_ct,
    ps.valid_shot_count AS SHOTS_MADE,
    ps.valid_shot_count,
    ROUND(vss.production_time, 2) AS production_time,
    ROUND(tst.total_session_time, 2) AS total_session_time,
        -- Formatted start and end times
    TO_CHAR(TO_TIMESTAMP_NTZ(ps.SHOT_START_TIME / 1e9), 'YYYYMMDD HH24:MI:SS') AS start_time, 
    TO_CHAR(TO_TIMESTAMP_NTZ(ps.SHOT_END_TIME / 1e9), 'YYYYMMDD HH24:MI:SS') AS end_time,
    
    -- Idle time
    CASE 
        WHEN tst.total_session_time > vss.production_time THEN 
            ROUND(tst.total_session_time - vss.production_time, 2) 
        ELSE 0 
    END AS idle_time,

    -- Uptime percentage
    CASE 
        WHEN tst.total_session_time > 0 THEN 
            ROUND(100 * (vss.production_time / tst.total_session_time), 2)
        ELSE 0 
    END AS uptime_percentage,

    -- Date and time information
    TO_CHAR(TO_TIMESTAMP_NTZ(ps.SHOT_START_TIME / 1e9), 'YYYYMMDD') AS DAY,
    TO_CHAR(DATE_TRUNC('month', TO_TIMESTAMP_NTZ(ps.SHOT_START_TIME / 1e9)), 'YYYYMM') AS month, 
    TO_CHAR(DATE_TRUNC('quarter', TO_TIMESTAMP_NTZ(ps.SHOT_START_TIME / 1e9)), 'YYYY') || 
    LPAD(TO_CHAR(DATE_PART('quarter', TO_TIMESTAMP_NTZ(ps.SHOT_START_TIME / 1e9))), 1, '0') AS quarter,
    TO_CHAR(DATE_TRUNC('year', TO_TIMESTAMP_NTZ(ps.SHOT_START_TIME / 1e9)), 'YYYY') AS year,
    TO_CHAR(YEAROFWEEKISO(TO_TIMESTAMP_NTZ(ps.SHOT_START_TIME / 1e9))) || 
    LPAD(TO_CHAR(WEEKISO(TO_TIMESTAMP_NTZ(ps.SHOT_START_TIME / 1e9))), 2, '0') AS week

FROM 
    ProductionSummary ps
    JOIN ValidShotSummary vss ON 
        ps.COUNTER_CODE = vss.COUNTER_CODE AND 
        ps.SHOT_START_TIME = vss.SHOT_START_TIME AND 
        ps.SHOT_END_TIME = vss.SHOT_END_TIME
    JOIN TotalSessionTime tst ON 
        ps.COUNTER_CODE = tst.COUNTER_CODE AND 
        ps.SHOT_START_TIME = tst.SHOT_START_TIME AND 
        ps.SHOT_END_TIME = tst.SHOT_END_TIME
    LEFT JOIN (
        SELECT DISTINCT EQUIPMENT_CODE, ID, COMPANY_ID, LAST_TERMINAL_ID
        FROM COUNTER
    ) AS c ON ps.COUNTER_CODE = c.EQUIPMENT_CODE
    LEFT JOIN (
        SELECT DISTINCT 
            ID, COUNTER_ID, equipment_code, location_id, 
            contracted_cycle_time, weighted_average_cycle_time, 
            cycle_time_limit1, cycle_time_limit1unit, 
            cycle_time_limit2, cycle_time_limit2unit 
        FROM MOLD
    ) AS m ON c.ID = m.COUNTER_ID
    LEFT JOIN (
        SELECT DISTINCT ID, name 
        FROM COMPANY
    ) AS co ON co.ID = c.COMPANY_ID
    LEFT JOIN (
        SELECT DISTINCT ID, name 
        FROM LOCATION
    ) AS lo ON lo.ID = m.location_id

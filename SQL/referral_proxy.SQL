-- fact_referral_order
DROP TABLE IF EXISTS analytics.fact_referral_order;
GO

CREATE TABLE analytics.fact_referral_order (
    referral_order_id INT IDENTITY(1,1) PRIMARY KEY,
    patient_id UNIQUEIDENTIFIER NOT NULL,
    ordering_encounter_id UNIQUEIDENTIFIER NULL,
    ordering_provider_id UNIQUEIDENTIFIER NULL,
    referral_date DATE NOT NULL,
    procedure_code NVARCHAR(4000) NULL,
    procedure_description NVARCHAR(4000) NULL
);
GO

INSERT INTO analytics.fact_referral_order (
    patient_id,
    ordering_encounter_id,
    ordering_provider_id,
    referral_date,
    procedure_code,
    procedure_description
)
SELECT
    p.patient_id,
    pr.encounter_id AS ordering_encounter_id,
    e.provider_id AS ordering_provider_id,
    CAST(pr.procedure_start_dt AS DATE) AS referral_date,
    pr.code,
    pr.description
FROM analytics.fact_procedure pr
JOIN analytics.fact_encounter e
  ON pr.encounter_id = e.encounter_id
JOIN analytics.dim_patient p
  ON pr.patient_id = p.patient_id
WHERE pr.procedure_start_dt IS NOT NULL;
GO

-- check referral volume
SELECT
    COUNT(*) AS referral_orders,
    MIN(referral_date) AS min_date,
    MAX(referral_date) AS max_date
FROM analytics.fact_referral_order;

-- CREATE THE FUNNEL TABLE

DROP TABLE IF EXISTS analytics.fact_referral_funnel;
GO

CREATE TABLE analytics.fact_referral_funnel (
    referral_order_id INT NOT NULL,
    patient_id UNIQUEIDENTIFIER NOT NULL,
    ordering_provider_id UNIQUEIDENTIFIER NULL,

    referral_date DATE NOT NULL,

    scheduled_encounter_id UNIQUEIDENTIFIER NULL,
    scheduled_date DATE NULL,

    completed_date DATE NULL,

    days_to_schedule INT NULL,
    days_to_complete INT NULL,

    CONSTRAINT PK_fact_referral_funnel PRIMARY KEY (referral_order_id)
);
GO

-- POPULATE THE FUNNEL

WITH next_encounter AS (
    SELECT
        r.referral_order_id,
        r.patient_id,
        r.ordering_provider_id,
        r.referral_date,

        e.encounter_id,
        CAST(e.start_dt AS DATE) AS encounter_start_date,
        CAST(e.stop_dt AS DATE) AS encounter_stop_date,

        ROW_NUMBER() OVER (
            PARTITION BY r.referral_order_id
            ORDER BY e.start_dt
        ) AS rn
    FROM analytics.fact_referral_order r
    LEFT JOIN analytics.fact_encounter e
      ON r.patient_id = e.patient_id
     AND e.start_dt >= r.referral_date
)
INSERT INTO analytics.fact_referral_funnel (
    referral_order_id,
    patient_id,
    ordering_provider_id,
    referral_date,
    scheduled_encounter_id,
    scheduled_date,
    completed_date,
    days_to_schedule,
    days_to_complete
)
SELECT
    referral_order_id,
    patient_id,
    ordering_provider_id,
    referral_date,

    encounter_id AS scheduled_encounter_id,
    encounter_start_date AS scheduled_date,
    encounter_stop_date AS completed_date,

    DATEDIFF(DAY, referral_date, encounter_start_date) AS days_to_schedule,
    DATEDIFF(DAY, referral_date, encounter_stop_date) AS days_to_complete
FROM next_encounter
WHERE rn = 1;
GO

-- VALIDATE THE OVERALL FUNNEL COUNTS
SELECT
    COUNT(*) AS referrals_ordered,
    SUM(CASE WHEN scheduled_date IS NOT NULL THEN 1 ELSE 0 END) AS referrals_scheduled,
    SUM(CASE WHEN completed_date IS NOT NULL THEN 1 ELSE 0 END) AS referrals_completed
FROM analytics.fact_referral_funnel;

-- expect: referrals_ordered = 83,823, scheduled < ordered, completed ≤ scheduled

-- VALIDATING TH E FUNNEL: LEAKAGE RATE
SELECT
    1.0 * SUM(CASE WHEN scheduled_date IS NULL THEN 1 ELSE 0 END)
        / COUNT(*) AS leakage_rate
FROM analytics.fact_referral_funnel;

-- TIMING DISTRIBUTION SANITY (If avg days is >0, logic is working correctly.)
SELECT
    MIN(days_to_schedule) AS min_days,
    MAX(days_to_schedule) AS max_days,
    AVG(days_to_schedule * 1.0) AS avg_days
FROM analytics.fact_referral_funnel
WHERE scheduled_date IS NOT NULL;


------------------------------------------------------------------------------------------------------
----------------------------------------DELAYS, SCHEDULING, AND BOTTLENECK ANALYSIS----------------------------------
------------------------------------------------------------------------------------------------------

--- CREATE AGING BUCKETS--------
ALTER TABLE analytics.fact_referral_funnel
ADD aging_bucket NVARCHAR(20);
GO

UPDATE analytics.fact_referral_funnel
SET aging_bucket =
    CASE
        WHEN days_to_schedule IS NULL THEN 'Unscheduled'
        WHEN days_to_schedule <= 7 THEN '0–7 days'
        WHEN days_to_schedule <= 14 THEN '8–14 days'
        WHEN days_to_schedule <= 30 THEN '15–30 days'
        ELSE '30+ days'
    END;
GO


-----------DISTRIBUTION OF DELAYS ---------------
SELECT
    aging_bucket,
    COUNT(*) AS referrals,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM analytics.fact_referral_funnel
GROUP BY aging_bucket
ORDER BY
    CASE aging_bucket
        WHEN '0–7 days' THEN 1
        WHEN '8–14 days' THEN 2
        WHEN '15–30 days' THEN 3
        WHEN '30+ days' THEN 4
        ELSE 5
    END;


------------DELAYS BY ORDERING PROVIDER----------------
SELECT
    p.name AS ordering_provider,
    COUNT(*) AS referrals,
    AVG(f.days_to_schedule * 1.0) AS avg_days_to_schedule
FROM analytics.fact_referral_funnel f
LEFT JOIN analytics.dim_provider p
  ON f.ordering_provider_id = p.provider_id
GROUP BY p.name
HAVING COUNT(*) >= 20
ORDER BY avg_days_to_schedule DESC;


-------------DELAYS BY SPECIALTY-------------------
SELECT
    p.speciality,
    COUNT(*) AS referrals,
    AVG(f.days_to_schedule * 1.0) AS avg_days_to_schedule,
    MAX(f.days_to_schedule) AS max_days_to_schedule
FROM analytics.fact_referral_funnel f
LEFT JOIN analytics.dim_provider p
  ON f.ordering_provider_id = p.provider_id
GROUP BY p.speciality
ORDER BY avg_days_to_schedule DESC;


---Creating a flag for at-risk referrals
ALTER TABLE analytics.fact_referral_funnel
ADD is_at_risk BIT;
GO

UPDATE analytics.fact_referral_funnel
SET is_at_risk =
    CASE
        WHEN days_to_schedule IS NULL THEN 1
        WHEN days_to_schedule > 14 THEN 1
        ELSE 0
    END;
GO

-- Validate at-risk volume
SELECT
    COUNT(*) AS total_referrals,
    SUM(CASE WHEN is_at_risk = 1 THEN 1 ELSE 0 END) AS at_risk_referrals,
    ROUND(100.0 * SUM(CASE WHEN is_at_risk = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS at_risk_pct
FROM analytics.fact_referral_funnel;


ALTER TABLE analytics.fact_referral_funnel
ADD scheduled_provider_id UNIQUEIDENTIFIER NULL,
    scheduled_speciality NVARCHAR(4000) NULL;
GO


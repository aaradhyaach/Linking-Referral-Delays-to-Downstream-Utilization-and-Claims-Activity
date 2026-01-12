IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'analytics')
    EXEC('CREATE SCHEMA analytics');
GO

SELECT 1 FROM sys.schemas WHERE name = 'analytics';

-- analytics.dim_patient
SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'analytics' AND TABLE_NAME = 'dim_patient';

DROP TABLE IF EXISTS analytics.dim_patient;
GO

CREATE TABLE analytics.dim_patient (
    patient_id UNIQUEIDENTIFIER NOT NULL,
    birth_date DATE NULL,
    death_date DATE NULL,
    gender NVARCHAR(50) NULL,
    race NVARCHAR(100) NULL,
    ethnicity NVARCHAR(100) NULL,
    marital NVARCHAR(50) NULL,
    city NVARCHAR(200) NULL,
    state NVARCHAR(100) NULL,
    county NVARCHAR(200) NULL,
    zip NVARCHAR(50) NULL,
    lat FLOAT NULL,
    lon FLOAT NULL,
    healthcare_expenses DECIMAL(18,2) NULL,
    healthcare_coverage DECIMAL(18,2) NULL,
    CONSTRAINT PK_dim_patient PRIMARY KEY (patient_id)
);
GO

INSERT INTO analytics.dim_patient (
    patient_id, birth_date, death_date, gender, race, ethnicity, marital,
    city, state, county, zip, lat, lon, healthcare_expenses, healthcare_coverage
)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, Id) AS patient_id,
    TRY_CONVERT(DATE, BIRTHDATE) AS birth_date,
    TRY_CONVERT(DATE, DEATHDATE) AS death_date,
    NULLIF(GENDER, '') AS gender,
    NULLIF(RACE, '') AS race,
    NULLIF(ETHNICITY, '') AS ethnicity,
    NULLIF(MARITAL, '') AS marital,
    NULLIF(CITY, '') AS city,
    NULLIF(STATE, '') AS state,
    NULLIF(COUNTY, '') AS county,
    NULLIF(ZIP, '') AS zip,
    TRY_CONVERT(FLOAT, LAT) AS lat,
    TRY_CONVERT(FLOAT, LON) AS lon,
    TRY_CONVERT(DECIMAL(18,2), HEALTHCARE_EXPENSES) AS healthcare_expenses,
    TRY_CONVERT(DECIMAL(18,2), HEALTHCARE_COVERAGE) AS healthcare_coverage
FROM raw.patients
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, Id) IS NOT NULL;


-- dim_organization
SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'analytics' AND TABLE_NAME = 'dim_organization';


DROP TABLE IF EXISTS analytics.dim_organization;
GO

CREATE TABLE analytics.dim_organization (
    organization_id UNIQUEIDENTIFIER NOT NULL,
    name NVARCHAR(4000) NULL,
    city NVARCHAR(4000) NULL,
    state NVARCHAR(4000) NULL,
    zip NVARCHAR(4000) NULL,
    lat FLOAT NULL,
    lon FLOAT NULL,
    utilization INT NULL,
    revenue DECIMAL(18,2) NULL,
    CONSTRAINT PK_dim_organization PRIMARY KEY (organization_id)
);
GO

INSERT INTO analytics.dim_organization (
    organization_id, name, city, state, zip, lat, lon, utilization, revenue
)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, Id) AS organization_id,
    NULLIF(NAME, '') AS name,
    NULLIF(CITY, '') AS city,
    NULLIF(STATE, '') AS state,
    NULLIF(ZIP, '') AS zip,
    TRY_CONVERT(FLOAT, LAT) AS lat,
    TRY_CONVERT(FLOAT, LON) AS lon,
    TRY_CONVERT(INT, UTILIZATION) AS utilization,
    TRY_CONVERT(DECIMAL(18,2), REVENUE) AS revenue
FROM raw.organizations
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, Id) IS NOT NULL;
GO

-- dim_provider
DROP TABLE IF EXISTS analytics.dim_provider;
GO

CREATE TABLE analytics.dim_provider (
    provider_id UNIQUEIDENTIFIER NOT NULL,
    organization_id UNIQUEIDENTIFIER NULL,
    name NVARCHAR(4000) NULL,
    gender NVARCHAR(100) NULL,
    speciality NVARCHAR(4000) NULL,
    city NVARCHAR(4000) NULL,
    state NVARCHAR(4000) NULL,
    zip NVARCHAR(4000) NULL,
    lat FLOAT NULL,
    lon FLOAT NULL,
    utilization INT NULL,
    CONSTRAINT PK_dim_provider PRIMARY KEY (provider_id)
);
GO

INSERT INTO analytics.dim_provider (
    provider_id, organization_id, name, gender, speciality,
    city, state, zip, lat, lon, utilization
)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, Id) AS provider_id,
    TRY_CONVERT(UNIQUEIDENTIFIER, ORGANIZATION) AS organization_id,
    NULLIF(NAME, '') AS name,
    NULLIF(GENDER, '') AS gender,
    NULLIF(SPECIALITY, '') AS speciality,
    NULLIF(CITY, '') AS city,
    NULLIF(STATE, '') AS state,
    NULLIF(ZIP, '') AS zip,
    TRY_CONVERT(FLOAT, LAT) AS lat,
    TRY_CONVERT(FLOAT, LON) AS lon,
    TRY_CONVERT(INT, UTILIZATION) AS utilization
FROM raw.providers
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, Id) IS NOT NULL;
GO

-- dim_payer
DROP TABLE IF EXISTS analytics.dim_payer;
GO

CREATE TABLE analytics.dim_payer (
    payer_id UNIQUEIDENTIFIER NOT NULL,
    name NVARCHAR(4000) NULL,
    city NVARCHAR(4000) NULL,
    state_headquartered NVARCHAR(4000) NULL,
    phone NVARCHAR(4000) NULL,
    revenue DECIMAL(18,2) NULL,
    unique_customers INT NULL,
    member_months INT NULL,
    CONSTRAINT PK_dim_payer PRIMARY KEY (payer_id)
);
GO

INSERT INTO analytics.dim_payer (
    payer_id, name, city, state_headquartered, phone, revenue, unique_customers, member_months
)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, Id) AS payer_id,
    NULLIF(NAME, '') AS name,
    NULLIF(CITY, '') AS city,
    NULLIF(STATE_HEADQUARTERED, '') AS state_headquartered,
    NULLIF(PHONE, '') AS phone,
    TRY_CONVERT(DECIMAL(18,2), REVENUE) AS revenue,
    TRY_CONVERT(INT, UNIQUE_CUSTOMERS) AS unique_customers,
    TRY_CONVERT(INT, MEMBER_MONTHS) AS member_months
FROM raw.payers
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, Id) IS NOT NULL;
GO

-- analytics.fact_encounter
DROP TABLE IF EXISTS analytics.fact_encounter;
GO

CREATE TABLE analytics.fact_encounter (
    encounter_id UNIQUEIDENTIFIER NOT NULL,
    patient_id UNIQUEIDENTIFIER NULL,
    organization_id UNIQUEIDENTIFIER NULL,
    provider_id UNIQUEIDENTIFIER NULL,
    payer_id UNIQUEIDENTIFIER NULL,
    start_dt DATETIME2(0) NULL,
    stop_dt DATETIME2(0) NULL,
    encounter_class NVARCHAR(200) NULL,
    code NVARCHAR(4000) NULL,
    description NVARCHAR(4000) NULL,
    base_encounter_cost DECIMAL(18,2) NULL,
    total_claim_cost DECIMAL(18,2) NULL,
    payer_coverage DECIMAL(18,2) NULL,
    reason_code NVARCHAR(4000) NULL,
    reason_description NVARCHAR(4000) NULL,
    CONSTRAINT PK_fact_encounter PRIMARY KEY (encounter_id)
);
GO

INSERT INTO analytics.fact_encounter (
    encounter_id, patient_id, organization_id, provider_id, payer_id,
    start_dt, stop_dt, encounter_class, code, description,
    base_encounter_cost, total_claim_cost, payer_coverage,
    reason_code, reason_description
)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, Id) AS encounter_id,
    TRY_CONVERT(UNIQUEIDENTIFIER, PATIENT) AS patient_id,
    TRY_CONVERT(UNIQUEIDENTIFIER, ORGANIZATION) AS organization_id,
    TRY_CONVERT(UNIQUEIDENTIFIER, PROVIDER) AS provider_id,
    TRY_CONVERT(UNIQUEIDENTIFIER, PAYER) AS payer_id,
    TRY_CONVERT(DATETIME2(0), START) AS start_dt,
    TRY_CONVERT(DATETIME2(0), STOP) AS stop_dt,
    NULLIF(ENCOUNTERCLASS, '') AS encounter_class,
    NULLIF(CODE, '') AS code,
    NULLIF(DESCRIPTION, '') AS description,
    TRY_CONVERT(DECIMAL(18,2), BASE_ENCOUNTER_COST) AS base_encounter_cost,
    TRY_CONVERT(DECIMAL(18,2), TOTAL_CLAIM_COST) AS total_claim_cost,
    TRY_CONVERT(DECIMAL(18,2), PAYER_COVERAGE) AS payer_coverage,
    NULLIF(REASONCODE, '') AS reason_code,
    NULLIF(REASONDESCRIPTION, '') AS reason_description
FROM raw.encounters
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, Id) IS NOT NULL;
GO

-- analytics.fact_procedure
DROP TABLE IF EXISTS analytics.fact_procedure;
GO

CREATE TABLE analytics.fact_procedure (
    procedure_start_dt DATETIME2(0) NULL,
    procedure_stop_dt DATETIME2(0) NULL,
    patient_id UNIQUEIDENTIFIER NULL,
    encounter_id UNIQUEIDENTIFIER NULL,
    code NVARCHAR(4000) NULL,
    description NVARCHAR(4000) NULL,
    base_cost DECIMAL(18,2) NULL,
    reason_code NVARCHAR(4000) NULL,
    reason_description NVARCHAR(4000) NULL
);
GO

INSERT INTO analytics.fact_procedure (
    procedure_start_dt, procedure_stop_dt, patient_id, encounter_id,
    code, description, base_cost, reason_code, reason_description
)
SELECT
    TRY_CONVERT(DATETIME2(0), START) AS procedure_start_dt,
    TRY_CONVERT(DATETIME2(0), STOP) AS procedure_stop_dt,
    TRY_CONVERT(UNIQUEIDENTIFIER, PATIENT) AS patient_id,
    TRY_CONVERT(UNIQUEIDENTIFIER, ENCOUNTER) AS encounter_id,
    NULLIF(CODE, '') AS code,
    NULLIF(DESCRIPTION, '') AS description,
    TRY_CONVERT(DECIMAL(18,2), BASE_COST) AS base_cost,
    NULLIF(REASONCODE, '') AS reason_code,
    NULLIF(REASONDESCRIPTION, '') AS reason_description
FROM raw.procedures;
GO

-- indexes for faster lookup
-- Encounters: common joins + filtering
CREATE INDEX IX_fact_encounter_patient_start
ON analytics.fact_encounter (patient_id, start_dt);

CREATE INDEX IX_fact_encounter_provider_start
ON analytics.fact_encounter (provider_id, start_dt);

-- Procedures: common joins
CREATE INDEX IX_fact_procedure_encounter
ON analytics.fact_procedure (encounter_id);

CREATE INDEX IX_fact_procedure_patient_start
ON analytics.fact_procedure (patient_id, procedure_start_dt);
GO

-- Checking validity of indexes
SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE i.name IN (
    'IX_fact_encounter_patient_start', 
    'IX_fact_encounter_provider_start', 
    'IX_fact_procedure_encounter', 
    'IX_fact_procedure_patient_start'
);

-- Sanity Check : Row Counts
SELECT 'dim_patient' AS tbl, COUNT(*) AS n FROM analytics.dim_patient
UNION ALL SELECT 'dim_provider', COUNT(*) FROM analytics.dim_provider
UNION ALL SELECT 'dim_organization', COUNT(*) FROM analytics.dim_organization
UNION ALL SELECT 'dim_payer', COUNT(*) FROM analytics.dim_payer
UNION ALL SELECT 'fact_encounter', COUNT(*) FROM analytics.fact_encounter
UNION ALL SELECT 'fact_procedure', COUNT(*) FROM analytics.fact_procedure;

-- Sanity Check : Join Health (Check if the count is close the ID in encounter and patient tables)
SELECT
  COUNT(*) AS encounter_rows,
  SUM(CASE WHEN p.patient_id IS NOT NULL THEN 1 ELSE 0 END) AS encounters_with_patient_dim
FROM analytics.fact_encounter e
LEFT JOIN analytics.dim_patient p
  ON e.patient_id = p.patient_id;

-- Building a clean analytics fact table
DROP TABLE IF EXISTS analytics.fact_claim;
GO

CREATE TABLE analytics.fact_claim (
    claim_id UNIQUEIDENTIFIER NULL,
    patient_id UNIQUEIDENTIFIER NOT NULL,
    appointment_id UNIQUEIDENTIFIER NULL,
    service_date DATE NULL,
    last_billed_date DATE NULL,
    claim_status NVARCHAR(100) NULL
);
GO

INSERT INTO analytics.fact_claim (
    claim_id,
    patient_id,
    appointment_id,
    service_date,
    last_billed_date,
    claim_status
)
SELECT
    TRY_CONVERT(UNIQUEIDENTIFIER, Id) AS claim_id,
    TRY_CONVERT(UNIQUEIDENTIFIER, PATIENTID) AS patient_id,
    TRY_CONVERT(UNIQUEIDENTIFIER, APPOINTMENTID) AS appointment_id,
    TRY_CONVERT(DATE, SERVICEDATE) AS service_date,
    TRY_CONVERT(DATE, LASTBILLEDDATE1) AS last_billed_date,
    STATUS1 AS claim_status
FROM raw.claims
WHERE TRY_CONVERT(UNIQUEIDENTIFIER, PATIENTID) IS NOT NULL;
GO

-- Validate the data inserted
SELECT
    COUNT(*) AS total_claims,
    COUNT(DISTINCT patient_id) AS unique_patients,
    MIN(service_date) AS min_service_date,
    MAX(service_date) AS max_service_date
FROM analytics.fact_claim;

-- fact referral claimfs

DROP TABLE IF EXISTS analytics.fact_referral_claims;
GO

CREATE TABLE analytics.fact_referral_claims (
    referral_order_id INT NOT NULL,
    patient_id UNIQUEIDENTIFIER NOT NULL,
    referral_date DATE NOT NULL,
    is_at_risk BIT NOT NULL,
    downstream_claim_count INT NOT NULL,
    first_claim_date DATE NULL
);
GO

INSERT INTO analytics.fact_referral_claims (
    referral_order_id,
    patient_id,
    referral_date,
    is_at_risk,
    downstream_claim_count,
    first_claim_date
)
SELECT
    f.referral_order_id,
    f.patient_id,
    f.referral_date,
    f.is_at_risk,
    COUNT(c.claim_id) AS downstream_claim_count,
    MIN(c.service_date) AS first_claim_date
FROM analytics.fact_referral_funnel f
LEFT JOIN analytics.fact_claim c
  ON f.patient_id = c.patient_id
 AND c.service_date >= f.referral_date
 AND c.service_date <= DATEADD(DAY, 90, f.referral_date)
GROUP BY
    f.referral_order_id,
    f.patient_id,
    f.referral_date,
    f.is_at_risk;
GO

-- Vadiate referral -> claims linkage
SELECT
    COUNT(*) AS referrals,
    SUM(CASE WHEN downstream_claim_count > 0 THEN 1 ELSE 0 END) AS referrals_with_claims,
    ROUND(
        100.0 * SUM(CASE WHEN downstream_claim_count > 0 THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS claim_conversion_pct
FROM analytics.fact_referral_claims;

-- Compare at risk vs. not at risk
SELECT
    is_at_risk,
    COUNT(*) AS referrals,
    AVG(downstream_claim_count * 1.0) AS avg_claims_per_referral
FROM analytics.fact_referral_claims
GROUP BY is_at_risk;

SELECT * FROM analytics.fact_referral_claims;

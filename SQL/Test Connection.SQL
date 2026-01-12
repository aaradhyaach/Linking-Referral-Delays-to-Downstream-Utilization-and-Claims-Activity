-- Simple heartbeat test (should return '1')
SELECT 1 AS ConnectionStatus;

-- Check which database you are currently in
SELECT DB_NAME() AS CurrentDatabase;

-- Check if there are any tables at all in this database
SELECT name, type_desc 
FROM sys.tables;


SELECT COUNT(Id) FROM raw.claims;

SELECT
  DB_NAME() AS database_name,
  SUM(size) * 8.0 / 1024 / 1024 AS size_gb
FROM sys.database_files;

SELECT 
  s.name AS schema_name,
  t.name AS table_name,
  SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id
WHERE s.name = 'raw'
GROUP BY s.name, t.name
ORDER BY row_count DESC;

SELECT file_id, name, type_desc, size*8/1024.0 AS size_mb
FROM sys.database_files;

EXEC sp_spaceused;

DBCC SHRINKFILE (data_0, 300);
DBCC SHRINKFILE (log, 64);


SELECT file_id, name, type_desc, size*8/1024.0 AS size_mb
FROM sys.database_files;

EXEC sp_spaceused;


-- count of rows in each table in the raw schema
SELECT
    s.name  AS schema_name,
    t.name  AS table_name,
    SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
JOIN sys.partitions p
    ON t.object_id = p.object_id
WHERE s.name = 'raw'
  AND p.index_id IN (0, 1)  -- heap or clustered index
GROUP BY s.name, t.name
ORDER BY t.name;


-- count of rows in each table in the analytics schema
SELECT
    s.name  AS schema_name,
    t.name  AS table_name,
    SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.schemas s
    ON t.schema_id = s.schema_id
JOIN sys.partitions p
    ON t.object_id = p.object_id
WHERE s.name = 'analytics'
  AND p.index_id IN (0, 1)  -- heap or clustered index
GROUP BY s.name, t.name
ORDER BY t.name;

-- get the needed csvs for Power BI visualizations
SELECT COUNT(*) FROM analytics.dim_provider;
SELECT COUNT(*) FROM analytics.fact_referral_funnel;




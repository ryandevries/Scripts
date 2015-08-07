DECLARE @SERVERNAME varchar(50)
DECLARE @INSTANCENAME varchar(50)

SET @SERVERNAME = CONVERT(varchar(50),(SELECT SERVERPROPERTY('MachineName')))
SET @INSTANCENAME = CONVERT(varchar(50),(SELECT SERVERPROPERTY('InstanceName')))

IF OBJECT_ID('tempdb..#tmpbackupdate') IS NOT NULL
   DROP TABLE #tmpbackupdate
IF OBJECT_ID('tempdb..#tmpdbsizes') IS NOT NULL
   DROP TABLE #tmpdbsizes
IF OBJECT_ID('tempdb..#tmpdbsizes2') IS NOT NULL
   DROP TABLE #tmpdbsizes2
IF OBJECT_ID('tempdb..#tmpdbinfo') IS NOT NULL
	DROP TABLE #tmpdbinfo
IF OBJECT_ID('tempdb..#tmpdbccvalue') IS NOT NULL
	DROP TABLE #tmpdbccvalue

SELECT bs.database_name AS DatabaseName, 
	MAX(CASE WHEN bs.type = 'D' THEN bs.backup_finish_date ELSE NULL END) AS LastFullBackup,
	MAX(CASE WHEN bs.type = 'I' THEN bs.backup_finish_date ELSE NULL END) AS LastDifferential,
	MAX(CASE WHEN bs.type = 'L' THEN bs.backup_finish_date ELSE NULL END) AS LastLogBackup
INTO #tmpbackupdate
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
GROUP BY bs.database_name
ORDER BY bs.database_name DESC

IF LEFT(CAST(SERVERPROPERTY('ProductVersion') As Varchar),1)='8'
BEGIN  
	SELECT dbid as database_id, NULL as log_size_mb, NULL as row_size_mb, total_size_mb = CAST(SUM(size) * 8. / 1024 AS DECIMAL(18,2))
	INTO #tmpdbsizes
	FROM master.dbo.sysaltfiles
	GROUP BY dbid

	SELECT 
		sdb.name as DatabaseName, 
		suser_sname(sdb.sid) AS Owner,
		databasepropertyex(sdb.name, 'Status') as Status, 
		sdb.cmptlevel as CompatibilityLevel, 
		databasepropertyex(sdb.name, 'Recovery') AS RecoveryMode, 
		bd.LastFullBackup,
		bd.LastDifferential,
		bd.LastLogBackup,
		NULL as LastDBCCCheckDB,
		dbs.log_size_mb as LogSizeMB,
		dbs.row_size_mb as RowSizeMB,
		dbs.total_size_mb as TotalSizeMB,
		getdate() as Timestamp
	FROM master.dbo.sysdatabases sdb
	LEFT OUTER JOIN #tmpbackupdate bd ON sdb.name = bd.DatabaseName
	LEFT OUTER JOIN #tmpdbsizes dbs ON sdb.dbid = dbs.database_id
END
ELSE
BEGIN
	SELECT
		database_id, 
		log_size_mb = CAST(SUM(CASE WHEN type_desc = 'LOG' THEN size END) * 8. / 1024 AS DECIMAL(18,2)),
		row_size_mb = CAST(SUM(CASE WHEN type_desc = 'ROWS' THEN size END) * 8. / 1024 AS DECIMAL(18,2)),
		total_size_mb = CAST(SUM(size) * 8. / 1024 AS DECIMAL(18,2))
	INTO #tmpdbsizes2
	FROM sys.master_files
	GROUP BY database_id

    CREATE TABLE #tmpdbinfo (Id INT IDENTITY(1,1), ParentObject VARCHAR(255), [Object] VARCHAR(255), Field VARCHAR(255), [Value] VARCHAR(255))
    CREATE TABLE #tmpdbccvalue  (DatabaseName VARCHAR(255), LastDBCCCheckDB DATETIME)

	EXECUTE sp_MSforeachdb '
	-- Insert results of DBCC DBINFO into temp table, transform into simpler table with database name and datetime of last known good DBCC CheckDB
	INSERT INTO #tmpdbinfo EXECUTE (''DBCC DBINFO ( ''''?'''' ) WITH TABLERESULTS'');
	INSERT INTO #tmpdbccvalue (DatabaseName, LastDBCCCheckDB)   (SELECT ''?'', [Value] FROM #tmpdbinfo WHERE Field = ''dbi_dbccLastKnownGood'');
	TRUNCATE TABLE #tmpdbinfo;
	'

	SELECT 
		db.name as DatabaseName, 
		suser_sname(db.owner_sid) AS Owner,
		db.state_desc as Status, 
		db.compatibility_level as CompatibilityLevel, 
		db.recovery_model_desc as RecoveryMode, 
		bd.LastFullBackup,
		bd.LastDifferential,
		bd.LastLogBackup,
		dv.LastDBCCCheckDB,
		dbs.log_size_mb as LogSizeMB,
		dbs.row_size_mb as RowSizeMB,
		dbs.total_size_mb as TotalSizeMB,
		getdate() as Timestamp
	FROM sys.databases db
	LEFT OUTER JOIN #tmpbackupdate bd ON db.name = bd.DatabaseName
	LEFT OUTER JOIN #tmpdbsizes2 dbs ON db.database_id = dbs.database_id
	LEFT OUTER JOIN #tmpdbccvalue dv ON db.name = dv.DatabaseName
END

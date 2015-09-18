FUNCTION Update-SqlInventory {
<# 
.SYNOPSIS 
    Updates the Server Inventory for SQL Instances
.DESCRIPTION 
    Dependendencies  : SQLPS Module
    SQL Permissions  : Read/Write on [$inventoryinstance].[$inventorydatabase], Read on all system databases on all SQL instances to be inventoried 
                       SELECT permission on object 'sysoperators', database 'msdb', schema 'dbo'
                       SELECT permission on object 'sysjobs', database 'msdb', schema 'dbo'

    Step 1     : Pull list of SQL instances and corresponding InstanceIDs from [$inventoryinstance].[$inventorydatabase].[dbo].[SQLInstances]
    Step 2     : Connect to each of the pulled SQL instances
    Step 3     : For each instance, pull information about the instance
    Step 4     : For each instance, pull information about all contained databases
    Step 5     : For each instance, pull information about all contained jobs
    Step 6     : For each instance, pull information about all contained job steps
    Step 7     : Generate Update/Insert query for each database/job with all new information, delete old databases/jobs that have been removed

    -- TODO: Add GUIDs to job and jobsteps
.PARAMETER  InventoryInstance
	The name of the instance the inventory database is on
.PARAMETER  Database
	The name of the database the inventory tables are in
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/12
    Version     : 2
.INPUTS
    [string]
#> 
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,HelpMessage="Name of the instance the inventory database is on")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
	    [string]$InventoryInstance = 'utility-db',
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Name of the database the inventory tables are in")]
        [ValidateNotNullorEmpty()]
	    [string]$InventoryDatabase = 'ServerInventory'
    )

    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        Write-Verbose "Setting up queries"
        # This query returns all the instance specific information that is tracked as well as a timestamp for a specific instance
        $get_sqlinstanceinfo_query = @"
DECLARE @SERVERINFO_BASIC_TSQL   VARCHAR(8000)
DECLARE @OSSTATS_SQL2000_TSQL    VARCHAR(8000)
DECLARE @SERVERINFO_SQL2000_TSQL VARCHAR(8000)
DECLARE @SERVERINFO_SQL2005_TSQL VARCHAR(8000)
DECLARE @SERVERINFO_TSQL         VARCHAR(8000)

SET @SERVERINFO_BASIC_TSQL = '
SELECT 
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''MachineName'')))    AS [ServerName],
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''InstanceName'')))   AS [InstanceName],
	CONVERT(VARCHAR(50),(SELECT 
		CASE (SELECT LEFT(CAST(SERVERPROPERTY(''ProductVersion'') AS VARCHAR), 4))
			WHEN ''13.0'' THEN ''SQL Server 2016''
            WHEN ''12.0'' THEN ''SQL Server 2014''
			WHEN ''11.0'' THEN ''SQL Server 2012''
			WHEN ''10.5'' THEN ''SQL Server 2008 R2''
			WHEN ''10.0'' THEN ''SQL Server 2008''
			WHEN ''9.00'' THEN ''SQL Server 2005''
			WHEN ''8.00'' THEN ''SQL Server 2000''
			ELSE ''Unknown Version'' 
		END
		)
	)                                                                AS [Version],
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''ProductLevel'')))   AS [Build],
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''ProductVersion''))) AS [BuildNumber],
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''Edition'')))        AS [Edition],
	CONVERT(VARCHAR(50),(SELECT 
		CASE (SELECT SERVERPROPERTY(''IsIntegratedSecurityOnly'')) 
			WHEN 1 THEN ''Windows'' 
			WHEN 0 THEN ''Mixed Mode'' 
		END
		)
	)                                                                AS [Authentication],
	GETDATE()                                                        AS [Timestamp],
'
SET @OSSTATS_SQL2000_TSQL = '
IF OBJECT_ID(''tempdb..##OSstats'') IS NOT NULL
	DROP TABLE ##OSstats
CREATE TABLE ##OSstats ([Index] VARCHAR(2000), [Name] VARCHAR(2000), [Internal_Value] VARCHAR(2000), [Character_Value] VARCHAR(2000)) 
INSERT INTO  ##OSstats EXEC xp_msver'

SET @SERVERINFO_SQL2000_TSQL = '
CONVERT(BIGINT,(SELECT [value] FROM [master].[dbo].[sysconfigures] WHERE [config] = ''1544'')) AS [MemoryAllocatedMB],
CONVERT(INT,   (SELECT [value] FROM [master].[dbo].[sysconfigures] WHERE [config] = ''1539'')) AS [MaxDOP],
CONVERT(INT,   (SELECT [value] FROM [master].[dbo].[sysconfigures] WHERE [config] = ''1538'')) AS [CTFP],
(SELECT [Internal_Value] FROM ##OSstats WHERE [name] = ''ProcessorCount'')                     AS [Cores],
(SELECT [Internal_Value] FROM ##OSstats WHERE [name] = ''PhysicalMemory'')                     AS [TotalMemoryMB],
(SELECT [crdate] FROM [master].[dbo].[sysdatabases] WHERE [name] = ''tempdb'')                 AS [StartupTime]'

SET @SERVERINFO_SQL2005_TSQL = '
CONVERT(BIGINT,(SELECT [value] FROM [master].[dbo].[sysconfigures] WHERE [config] = ''1544'')) AS [MemoryAllocatedMB],
CONVERT(INT,   (SELECT [value] FROM [master].[dbo].[sysconfigures] WHERE [config] = ''1539'')) AS [MaxDOP],
CONVERT(INT,   (SELECT [value] FROM [master].[dbo].[sysconfigures] WHERE [config] = ''1538'')) AS [CTFP],
(SELECT [cpu_count] FROM [master].[sys].[dm_os_sys_info])                                      AS [Cores],
(SELECT [physical_memory_in_bytes]/1024/1024 FROM [master].[sys].[dm_os_sys_info])             AS [TotalMemoryMB],
(SELECT [create_date] FROM [master].[sys].[databases] WHERE [name] = ''tempdb'')               AS [StartupTime]'

SET @SERVERINFO_TSQL = '
CONVERT(BIGINT,(SELECT [value] FROM [master].[sys].[configurations] WHERE [configuration_id] = ''1544'')) AS [MemoryAllocatedMB],
CONVERT(INT,(   SELECT [value] FROM [master].[sys].[configurations] WHERE [configuration_id] = ''1539'')) AS [MaxDOP],
CONVERT(INT,(   SELECT [value] FROM [master].[sys].[configurations] WHERE [configuration_id] = ''1538'')) AS [CTFP],
(SELECT [cpu_count] FROM [master].[sys].[dm_os_sys_info])												  AS [Cores],
(SELECT [total_physical_memory_kb]/1024 FROM [master].[sys].[dm_os_sys_memory])						      AS [TotalMemoryMB],
(SELECT [sqlserver_start_time] FROM [master].[sys].[dm_os_sys_info])									  AS [StartupTime]'

IF LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR),1)='8'
BEGIN
	EXEC (@OSSTATS_SQL2000_TSQL)
	EXEC (@SERVERINFO_BASIC_TSQL + @SERVERINFO_SQL2000_TSQL)
END
ELSE IF LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR),1)='9'
BEGIN	
	EXEC (@SERVERINFO_BASIC_TSQL + @SERVERINFO_SQL2005_TSQL) 
END
ELSE
BEGIN
	EXEC (@SERVERINFO_BASIC_TSQL + @SERVERINFO_TSQL)
END
"@
        # This query returns all the database specific information that is tracked as well as a timestamp for a specific instance
        $get_sqldatabases_query = @"
DECLARE @BACKUPINFO_TSQL     VARCHAR(8000)
DECLARE @DBSIZE_SQL2000_TSQL VARCHAR(8000)
DECLARE @DBSIZE_TSQL         VARCHAR(8000)
DECLARE @DBINFO_SQL2000_TSQL VARCHAR(8000)
DECLARE @DBINFO_TSQL         VARCHAR(8000)
DECLARE @DBCC_DBINFO_TSQL    VARCHAR(8000)

SET @BACKUPINFO_TSQL = '
IF OBJECT_ID(''tempdb..##backupdate'') IS NOT NULL
   DROP TABLE ##backupdate
SELECT 
	bs.[database_name]                                                          AS [DatabaseName], 
	MAX(CASE WHEN bs.[type] = ''D'' THEN bs.[backup_finish_date] ELSE NULL END) AS [LastFullBackup],
	MAX(CASE WHEN bs.[type] = ''I'' THEN bs.[backup_finish_date] ELSE NULL END) AS [LastDifferential],
	MAX(CASE WHEN bs.[type] = ''L'' THEN bs.[backup_finish_date] ELSE NULL END) AS [LastLogBackup]
INTO ##backupdate
FROM msdb.dbo.[backupset]         bs
JOIN msdb.dbo.[backupmediafamily] bmf ON bs.[media_set_id] = bmf.[media_set_id]
GROUP BY bs.[database_name]
ORDER BY bs.[database_name] DESC'

SET @DBSIZE_SQL2000_TSQL = '
IF OBJECT_ID(''tempdb..##dbsizes'') IS NOT NULL
   DROP TABLE ##dbsizes
SELECT 
	[dbid]                                         AS [database_id], 
	NULL                                           AS [log_size_mb], 
	NULL                                           AS [row_size_mb], 
	CAST(SUM([size]) * 8. / 1024 AS DECIMAL(18,2)) AS [total_size_mb]
INTO ##dbsizes
FROM master.dbo.[sysaltfiles]
GROUP BY [dbid]'

SET @DBINFO_SQL2000_TSQL = '
SELECT 
	sdb.[name]                                   AS [DatabaseName], 
	SUSER_SNAME(sdb.[sid])                       AS [Owner],
	DATABASEPROPERTYEX(sdb.[name], ''Status'')   AS [Status], 
	sdb.[cmptlevel]                              AS [CompatibilityLevel], 
	DATABASEPROPERTYEX(sdb.[name], ''Recovery'') AS [RecoveryMode], 
	bd.[LastFullBackup]                          AS [LastFullBackup],
	bd.[LastDifferential]                        AS [LastDifferential],
	bd.[LastLogBackup]                           AS [LastLogBackup],
	NULL                                         AS [LastDBCCCheckDB],
	dbs.[log_size_mb]                            AS [LogSizeMB],
	dbs.[row_size_mb]                            AS [RowSizeMB],
	dbs.[total_size_mb]                          AS [TotalSizeMB],
	GETDATE()                                    AS [Timestamp]
FROM master.dbo.[sysdatabases] sdb
LEFT OUTER JOIN ##backupdate   bd  ON sdb.[name] = bd.[DatabaseName]
LEFT OUTER JOIN ##dbsizes      dbs ON sdb.[dbid] = dbs.[database_id]'

SET @DBSIZE_TSQL = '
IF OBJECT_ID(''tempdb..##dbsizes'') IS NOT NULL
   DROP TABLE ##dbsizes
SELECT 
	[database_id], 
	CAST(SUM(CASE WHEN [type_desc] = ''LOG''  THEN [size] END) * 8. / 1024 AS DECIMAL(18,2)) AS [log_size_mb],
	CAST(SUM(CASE WHEN [type_desc] = ''ROWS'' THEN [size] END) * 8. / 1024 AS DECIMAL(18,2)) AS [row_size_mb],
	CAST(SUM([size]) * 8. / 1024 AS DECIMAL(18,2))                                           AS [total_size_mb]
INTO ##dbsizes
FROM sys.[master_files]
GROUP BY [database_id]'

SET @DBCC_DBINFO_TSQL = '
DECLARE @DBCC_DBINFO_TSQL VARCHAR(8000)
SET @DBCC_DBINFO_TSQL = ''
-- Insert results of DBCC DBINFO into temp table, transform into simpler table with database name and DATETIME of last known good DBCC CheckDB
INSERT INTO ##dbinfo EXECUTE (''''DBCC DBINFO ( ''''''''?'''''''' ) WITH TABLERESULTS'''');
INSERT INTO ##dbccvalue (DatabaseName, LastDBCCCheckDB)   (SELECT ''''?'''', [Value] FROM ##dbinfo WHERE Field = ''''dbi_dbccLastKnownGood'''');
TRUNCATE TABLE ##dbinfo;''

IF OBJECT_ID(''tempdb..##dbinfo'') IS NOT NULL
	DROP TABLE ##dbinfo
IF OBJECT_ID(''tempdb..##dbccvalue'') IS NOT NULL
	DROP TABLE ##dbccvalue
CREATE TABLE ##dbinfo (Id INT IDENTITY(1,1), ParentObject VARCHAR(255), [Object] VARCHAR(255), Field VARCHAR(255), [Value] VARCHAR(255))
CREATE TABLE ##dbccvalue  (DatabaseName VARCHAR(255), LastDBCCCheckDB DATETIME)
EXECUTE sp_MSforeachdb @DBCC_DBINFO_TSQL'

SET @DBINFO_TSQL = '
SELECT 
	db.[name]                   AS [DatabaseName], 
	SUSER_SNAME(db.[owner_sid]) AS [Owner],
	db.[state_desc]             AS [Status], 
	db.[compatibility_level]    AS [CompatibilityLevel], 
	db.[recovery_model_desc]    AS [RecoveryMode], 
	bd.[LastFullBackup]         AS [LastFullBackup],
	bd.[LastDifferential]       AS [LastDifferential],
	bd.[LastLogBackup]          AS [LastLogBackup],
	dv.[LastDBCCCheckDB]        AS [LastDBCCCheckDB],
	dbs.[log_size_mb]           AS [LogSizeMB],
	dbs.[row_size_mb]           AS [RowSizeMB],
	dbs.[total_size_mb]         AS [TotalSizeMB],
	GETDATE()                   AS [Timestamp]
FROM sys.databases db
LEFT OUTER JOIN ##backupdate bd  ON db.[name]        = bd.[DatabaseName]
LEFT OUTER JOIN ##dbsizes    dbs ON db.[database_id] = dbs.[database_id]
LEFT OUTER JOIN ##dbccvalue  dv  ON db.[name]        = dv.[DatabaseName]'

EXEC (@BACKUPINFO_TSQL)
IF LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR),1)='8'
BEGIN  
	EXEC (@DBSIZE_SQL2000_TSQL)
	EXEC (@DBINFO_SQL2000_TSQL)
END
ELSE
BEGIN
	EXEC (@DBSIZE_TSQL)
	EXEC (@DBCC_DBINFO_TSQL)
	EXEC (@DBINFO_TSQL)
END
"@
        # This query returns all the job specific information that is tracked as well as a timestamp for a specific instance
        $get_sqljobs_query = @"
DECLARE @LASTEXECUTION_TSQL   VARCHAR(8000)
DECLARE @JOBSCHEDULES_TSQL    VARCHAR(8000)
DECLARE @JOBINFO_PRE2008_TSQL VARCHAR(8000)
DECLARE @JOBINFO_TSQL         VARCHAR(8000)

SET @LASTEXECUTION_TSQL = '
IF OBJECT_ID(''tempdb..##lastExecution'') IS NOT NULL
	DROP TABLE ##lastExecution
SELECT 
	[job_id]           AS [job_id], 
	MAX([instance_id]) AS [last_instance_id]
INTO ##lastExecution
FROM msdb.dbo.[sysjobhistory] jh
WHERE [step_id] = 0
GROUP BY [job_id]'

SET @JOBSCHEDULES_TSQL = '
IF OBJECT_ID(''tempdb..##jobschedules'') IS NOT NULL
	DROP TABLE ##jobschedules
IF OBJECT_ID(''tempdb..##jobschedules2'') IS NOT NULL
	DROP TABLE ##jobschedules2
SELECT 
	j.[Name]             AS [Job Name],
	-- Type of Schedule
	CASE s.[freq_type] 
		WHEN 1   THEN ''One time, occurs at '' + CONVERT(VARCHAR(15), CONVERT(TIME, STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), s.[active_start_time]), 6), 3, 0, '':''), 6, 0, '':'')), 100) + '' on '' + CONVERT(VARCHAR, CONVERT(DATETIME,CONVERT(char(8), s.[active_start_date])), 101)
		WHEN 64  THEN ''When SQL Server Agent Service starts''
		WHEN 128 THEN ''When the Server is idle''
		ELSE ''''
	END +
	-- Frequency of type
	CASE
	WHEN [freq_type] = 4 THEN ''Every '' + 
		CASE s.[freq_interval] 
			WHEN 1 THEN ''day'' 
			ELSE CONVERT(VARCHAR, s.[freq_interval]) + '' day(s)'' 
		END
	WHEN s.[freq_type] = 8 THEN	''Every '' + 
		CASE s.[freq_recurrence_factor] 
			WHEN 1 THEN ''week on '' 
			ELSE CONVERT(VARCHAR, s.[freq_recurrence_factor]) + '' week(s) on '' 
		END +  
		REPLACE(RTRIM(
			CASE WHEN s.[freq_interval] & 1  = 1  THEN ''Sunday ''    ELSE '''' END +
			CASE WHEN s.[freq_interval] & 2  = 2  THEN ''Monday ''    ELSE '''' END +
			CASE WHEN s.[freq_interval] & 4  = 4  THEN ''Tuesday ''   ELSE '''' END +
			CASE WHEN s.[freq_interval] & 8  = 8  THEN ''Wednesday '' ELSE '''' END +
			CASE WHEN s.[freq_interval] & 16 = 16 THEN ''Thursday ''  ELSE '''' END +
			CASE WHEN s.[freq_interval] & 32 = 32 THEN ''Friday ''    ELSE '''' END +
			CASE WHEN s.[freq_interval] & 64 = 64 THEN ''Saturday ''  ELSE '''' END), '' '', '', '')
	WHEN s.[freq_type] = 16 THEN ''Every '' + 
		CASE s.[freq_recurrence_factor] 
			WHEN 1 THEN ''month on day '' 
			ELSE CONVERT(VARCHAR, s.[freq_recurrence_factor]) + '' month(s) on day '' 
		END + CONVERT(VARCHAR(2), s.[freq_interval])
	WHEN s.[freq_type] = 32 THEN ''Every '' + 
		CASE s.[freq_recurrence_factor] 
			WHEN 1 THEN ''month on the '' 
			ELSE CONVERT(VARCHAR, s.[freq_recurrence_factor]) + '' month(s) on the '' 
		END + 
			CASE s.[freq_relative_interval] 
				WHEN 1  THEN ''first '' 
				WHEN 2  THEN ''second '' 
				WHEN 4  THEN ''third '' 
				WHEN 8  THEN ''fourth '' 
				WHEN 16 THEN ''last '' 
			END + 
			CASE s.[freq_interval] 
				WHEN 1  THEN ''Sunday'' 
				WHEN 2  THEN ''Monday'' 
				WHEN 3  THEN ''Tuesday'' 
				WHEN 4  THEN ''Wednesday'' 
				WHEN 5  THEN ''Thursday'' 
				WHEN 6  THEN ''Friday'' 
				WHEN 7  THEN ''Saturday'' 
				WHEN 8  THEN ''day'' 
				WHEN 9  THEN ''weekday'' 
				WHEN 10 THEN ''weekend'' 
			END 
		ELSE ''''
	END +
	-- Frequency of time
	CASE s.[freq_subday_type] 
		WHEN 1 THEN '' at ''     + CONVERT(VARCHAR(15), CONVERT(TIME, STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), s.[active_start_time]), 6), 3, 0, '':''), 6, 0, '':'')), 100)
		WHEN 2 THEN '', every '' + CONVERT(VARCHAR, s.[freq_subday_interval]) + '' second(s)''
		WHEN 4 THEN '', every '' + CONVERT(VARCHAR, s.[freq_subday_interval]) + '' minute(s)''
		WHEN 8 THEN '', every '' + CONVERT(VARCHAR, s.[freq_subday_interval]) + '' hour(s)''
		ELSE ''''
	END +
	-- Time bounds
	CASE s.[freq_subday_type] 
		WHEN 0 THEN ''''
		WHEN 1 THEN ''''
		ELSE '' between '' + CONVERT(VARCHAR(15), CONVERT(TIME, STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), s.[active_start_time]),6 ),3,0,'':''),6,0,'':'')), 100) + '' and '' + CONVERT(VARCHAR(15), CONVERT(TIME, STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), s.[active_end_time]),6 ),3,0,'':''),6,0,'':'')), 100)
	END + 
	-- Date bounds
	'', starting on '' + CONVERT(VARCHAR, CONVERT(DATETIME, CONVERT(CHAR(8), s.[active_start_date])), 101) +
	CASE s.[active_end_date]
		WHEN ''99991231'' THEN '''' 
		ELSE '' and ending on '' + CONVERT(VARCHAR, CONVERT(DATETIME, CONVERT(CHAR(8), s.[active_end_date])), 101)
	END                  AS [Schedule],
	CASE js.[next_run_date] 
		WHEN 0 THEN NULL 
		ELSE CONVERT(VARCHAR, msdb.dbo.[agent_datetime](js.[next_run_date], js.[next_run_time]), 120) 
	END                  AS [Next Run Date]
INTO ##jobschedules
FROM msdb.dbo.[sysjobs]                    j
LEFT OUTER JOIN msdb.dbo.[sysjobschedules] js ON j.[job_id]       = js.[job_id]
LEFT OUTER JOIN msdb.dbo.[sysschedules]    s  ON js.[schedule_id] = s.[schedule_id]
WHERE j.[enabled] = 1 AND s.[enabled] = 1
ORDER BY j.[name] ASC

SELECT 
	j.[job_id]                    AS [job_id], 
	j.[name]                      AS [Job Name], 
	CASE 
		WHEN STUFF((
			SELECT ''; '' + s.[Schedule]
			FROM ##jobschedules s
			WHERE j.[name] = s.[Job Name]
			FOR XML PATH ('''')), 1, 2, '''')
			IS NULL THEN ''Not Scheduled'' 
		ELSE STUFF((
			SELECT ''; '' + s.[Schedule]
			FROM ##jobschedules s
			WHERE j.[name] = s.[Job Name]
			FOR XML PATH ('''')), 1, 2, '''') 
	END                            AS [Schedules],
	(SELECT MIN(s.[Next Run Date]) 
	FROM ##jobschedules s 
	WHERE j.[name] = s.[Job Name]) AS [Next Run Date]
INTO ##jobschedules2
FROM msdb.dbo.[sysjobs] j'

SET @JOBINFO_PRE2008_TSQL = '
SELECT 
	sj.[name]                                          AS [JobName], 
	CAST(									           
		CASE sj.[enabled] 					           
			WHEN 0 THEN ''Disabled'' 		           
			WHEN 1 THEN ''Enabled'' 		           
		END 								           
	AS VARCHAR(15))                                    AS [Status],
	SUSER_SNAME(sj.[owner_sid])                        AS [Owner],
	''Not available for this version of SQL''          AS [Schedules],
	CAST(
		CASE sjh.[run_status] 
			WHEN 0 THEN ''Error Failed'' 
			WHEN 1 THEN ''Succeeded'' 
			WHEN 2 THEN ''Retry'' 
			WHEN 3 THEN ''Cancelled'' 
			WHEN 4 THEN ''In Progress'' 
			ELSE ''Status Unknown'' 
		END 
	AS VARCHAR(15))                                    AS [LastRunStatus],
	CONVERT(DATETIME,CONVERT(CHAR(8), sjh.[run_date])) AS [LastRunDate],
	STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), sjh.[run_duration]), 6), 3, 0, '':''), 6, 0, '':'') AS [RunDuration],
	NULL                                               AS [NextRunDate],
	CAST(
		CASE sj.[notify_level_email] 
			WHEN 0 THEN ''Never'' 
			WHEN 1 THEN ''On Success'' 
			WHEN 2 THEN ''On Failure'' 
			WHEN 3 THEN ''On Completion'' 
		END 
	AS VARCHAR(15))                                    AS [NotifyLevel], 
	ISNULL(so.[email_address], ''N/A'')                AS [NotifyEmail],
    sj.[description]                                   AS [Description],
	GETDATE()                                          AS [Timestamp]
FROM msdb.dbo.[sysjobs]                  sj 
LEFT OUTER JOIN ##lastExecution          le  ON sj.[job_id]                   = le.[job_id]
LEFT OUTER JOIN msdb.dbo.[sysjobhistory] sjh ON le.[last_instance_id]         = sjh.[instance_id]
LEFT OUTER JOIN msdb.dbo.[sysoperators]  so  ON sj.[notify_email_operator_id] = so.[id]
ORDER BY sj.[name] ASC'

SET @JOBINFO_TSQL = '
SELECT sj.[name]                        AS [JobName],
	CAST(
		CASE sj.[enabled] 
			WHEN 0 THEN ''Disabled'' 
			WHEN 1 THEN ''Enabled'' 
		END 
	AS VARCHAR(15))                     AS [Status],
	SUSER_SNAME(sj.[owner_sid])         AS [Owner],
	js.[Schedules]                      AS [Schedules],
	CAST(
		CASE sjh.[run_status] 
			WHEN 0 THEN ''Error Failed'' 
			WHEN 1 THEN ''Succeeded'' 
			WHEN 2 THEN ''Retry'' 
			WHEN 3 THEN ''Cancelled'' 
			WHEN 4 THEN ''In Progress'' 
			ELSE ''Status Unknown'' 
		END
	AS VARCHAR(15))                     AS [LastRunStatus],
	sja.[run_requested_date]            AS [LastRunDate],
	ISNULL(STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), sjh.[run_duration]), 6), 3, 0, '':''), 6, 0, '':''), ''00:00:00'') AS [RunDuration],
	js.[Next Run Date]                  AS [NextRunDate],
	CAST(
		CASE sj.[notify_level_email] 
			WHEN 0 THEN ''Never'' 
			WHEN 1 THEN ''On Success'' 
			WHEN 2 THEN ''On Failure'' 
			WHEN 3 THEN ''On Completion'' 
		END 
	AS VARCHAR(15))                     AS [NotifyLevel], 
	ISNULL(so.[email_address], ''N/A'') AS [NotifyEmail],
	sj.[description]                    AS [Description],
	GETDATE()                           AS [Timestamp]
FROM msdb.dbo.sysjobs                     sj
LEFT OUTER JOIN ##lastExecution           le  ON sj.[job_id]                   = le.[job_id]
LEFT OUTER JOIN ##jobschedules2           js  ON sj.[job_id]                   = js.[job_id]
LEFT OUTER JOIN msdb.dbo.[sysjobhistory]  sjh ON le.[last_instance_id]         = sjh.[instance_id]
LEFT OUTER JOIN msdb.dbo.[sysjobactivity] sja ON sjh.[instance_id]             = sja.[job_history_id]
LEFT OUTER JOIN msdb.dbo.[sysoperators]   so  ON sj.[notify_email_operator_id] = so.[id]
ORDER BY sj.[name] ASC'

IF CAST(SERVERPROPERTY('Edition') AS VARCHAR) NOT LIKE 'Express%'
BEGIN
	EXEC(@LASTEXECUTION_TSQL)
	IF LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR),1)='8'
	BEGIN
		EXEC(@JOBINFO_PRE2008_TSQL)
	END
	ELSE
	BEGIN
		EXEC(@JOBSCHEDULES_TSQL)
		EXEC(@JOBINFO_TSQL)
	END
END
"@
        # This query returns all the job step specific information as well as a timestamp for a specific instance
        $get_sqljobsteps_query = @"
DECLARE @JOBHISTORY_TSQL      VARCHAR(8000)
DECLARE @JOBINFO_SQL2000_TSQL VARCHAR(8000)
DECLARE @JOBINFO_TSQL         VARCHAR(8000)

SET @JOBHISTORY_TSQL = '
IF OBJECT_ID(''tempdb..##lastinstances'') IS NOT NULL
	DROP TABLE ##lastinstances
SELECT 
	[job_id], 
	[step_id], 
	MAX([instance_id]) AS [last_instance_id]
INTO ##lastinstances
FROM msdb.dbo.sysjobhistory
WHERE [step_id] > 0
GROUP BY [job_id], [step_id]'

SET @JOBINFO_SQL2000_TSQL = '
SELECT 
	sj.[name]                             AS [JobName], 
	sjs.[step_id]                         AS [StepNumber], 
	sjs.[step_name]                       AS [StepName], 
	sjs.[SubSystem]                       AS [SubSystem],
	CASE sjs.[last_run_date] 
		WHEN 0 THEN 
			CASE sjh.[run_status]
				WHEN 0 THEN ''Failure'' 
				WHEN 1 THEN ''Success'' 
				WHEN 2 THEN ''Retry'' 
				WHEN 3 THEN ''Canceled'' 
				ELSE NULL 
			END 
		ELSE 
			CASE sjs.[last_run_outcome] 
				WHEN 0 THEN ''Failure'' 
				WHEN 1 THEN ''Success'' 
				WHEN 2 THEN ''Retry'' 
				WHEN 3 THEN ''Canceled'' 
				ELSE ''Unknown'' 
			END 
		END                               AS [LastRunStatus],
	CASE sjs.[last_run_date] 
		WHEN 0 THEN	CONVERT(DATETIME, STUFF(STUFF(CONVERT(VARCHAR(8), sjh.[run_date]), 5, 0, ''-''), 8, 0, ''-'') + '' '' + STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), sjh.[run_time]), 6), 3, 0, '':''), 6, 0, '':''))
		ELSE CONVERT(DATETIME, STUFF(STUFF(CONVERT(VARCHAR(8), sjs.[last_run_date]), 5, 0, ''-''), 8, 0, ''-'') + '' '' + STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), sjs.[last_run_time]), 6), 3, 0, '':''), 6, 0, '':'')) 
	END                                   AS [LastRunDate], 
	CASE sjs.[last_run_date] 
		WHEN 0 THEN CONVERT(VARCHAR(15), STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), sjh.[run_duration]), 6), 3, 0, '':''), 6, 0, '':''))
		ELSE CONVERT(VARCHAR(15), STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), sjs.[last_run_duration]), 6), 3, 0, '':''), 6, 0, '':'')) 
	END                                   AS [LastRunDuration], 
	''SQL Server Agent Service Account''  AS [Proxy],
	sjs.[output_file_name]                AS [LogFile],
	sjs.[Command]                         AS [Command],
	sjh.[Message]                         AS [Message],
	NEWID()                               AS [StepUID],
	GETDATE()                             AS [Timestamp]
FROM msdb.dbo.[sysjobsteps]              sjs
LEFT OUTER JOIN msdb.dbo.[sysjobs]       sj  ON sjs.[job_id]          = sj.[job_id]
LEFT OUTER JOIN ##lastinstances          li  ON sjs.[step_id]         = li.[step_id] 
                                            AND sjs.[job_id]          = li.[job_id]
LEFT OUTER JOIN msdb.dbo.[sysjobhistory] sjh ON li.[last_instance_id] = sjh.[instance_id]
ORDER BY sj.[name], sjs.[step_id]'

SET @JOBINFO_TSQL = '
SELECT sj.[name]           AS [JobName], 
	sjs.[step_id]          AS [StepNumber], 
	sjs.[step_name]        AS [StepName], 
	sjs.[SubSystem]        AS [SubSystem],
	CASE sjs.[last_run_date] 
		WHEN 0 THEN 
			CASE sjh.[run_status]
				WHEN 0 THEN ''Failure'' 
				WHEN 1 THEN ''Success'' 
				WHEN 2 THEN ''Retry'' 
				WHEN 3 THEN ''Canceled'' 
				ELSE NULL 
			END 
		ELSE 
			CASE sjs.[last_run_outcome] 
				WHEN 0 THEN ''Failure'' 
				WHEN 1 THEN ''Success'' 
				WHEN 2 THEN ''Retry'' 
				WHEN 3 THEN ''Canceled'' 
				ELSE ''Unknown'' 
			END 
		END                AS [LastRunStatus], 
	msdb.dbo.[agent_datetime](
		CASE sjs.[last_run_date] 
			WHEN 0 THEN sjh.[run_date] 
			ELSE sjs.[last_run_date]
		END, 
		CASE sjs.[last_run_date] 
			WHEN 0 THEN sjh.[run_time] 
			ELSE sjs.[last_run_time] 
		END)               AS [LastRunDate], 
	CASE sjs.[last_run_date] 
		WHEN 0 THEN CONVERT(VARCHAR(15), CONVERT(time, STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), sjh.[run_duration]), 6), 3, 0, '':''), 6, 0, '':'')), 120)
		ELSE CONVERT(VARCHAR(15), CONVERT(time, STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), sjs.[last_run_duration]), 6), 3, 0, '':''), 6, 0, '':'')), 120) 
	END                    AS [LastRunDuration], 
	CASE sjs.[subsystem]
		WHEN ''TSQL'' THEN SUSER_SNAME(sj.[owner_sid]) 
		ELSE ISNULL(c.[credential_identity],''SQL Server Agent Service Account'') 
	END                    AS [Proxy],
	sjs.[output_file_name] AS [LogFile],
	sjs.[Command]          AS [Command],
	sjh.[Message]          AS [Message],
	sjs.[step_uid]         AS [StepUID],
	GETDATE()              AS [Timestamp]
FROM msdb.dbo.[sysjobsteps]              sjs
LEFT OUTER JOIN msdb.dbo.[sysjobs]       sj   ON sjs.[job_id]          = sj.[job_id]
LEFT OUTER JOIN msdb.dbo.[sysproxies]    sp   ON sjs.[proxy_id]        = sp.[proxy_id]
LEFT OUTER JOIN msdb.sys.[credentials]   c    ON sp.[credential_id]    = c.[credential_id]
LEFT OUTER JOIN ##lastinstances          li   ON sjs.[step_id]         = li.[step_id]
                                             AND sjs.[job_id]          = li.[job_id]
LEFT OUTER JOIN msdb.dbo.[sysjobhistory] sjh  ON li.[last_instance_id] = sjh.[instance_id]
ORDER BY sj.[name], sjs.[step_id]'

IF CAST(SERVERPROPERTY('Edition') AS VARCHAR) NOT LIKE 'Express%'
BEGIN
	EXEC (@JOBHISTORY_TSQL)
	IF LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR),1)='8'
	BEGIN
		EXEC (@JOBINFO_SQL2000_TSQL)
	END
	ELSE
	BEGIN
		EXEC (@JOBINFO_TSQL)
	END
END
"@
        Write-Verbose "Initializing update/insert statements"
        # This query adds analytics information to the inventory for change over time reporting
        $insert_sqlanalytics_query = @"
USE [$inventorydatabase]
SET ANSI_WARNINGS OFF
SET NOCOUNT ON
INSERT INTO [dbo].[SQLAnalytics]
SELECT 
	'Disk Usage'                                  AS [AnalyticsType],
	[Server Name]                                 AS [ServerName],
	[Instance Name]                               AS [InstanceName],
	ISNULL([Environment], 'Unknown')              AS [Environment],
	'Per Instance Disk Usage (GB)'                AS [Property],
	ISNULL(CONVERT(INT, SUM(TotalSizeMB/1024)),0) AS [Value],
	GETDATE()                                     AS [Timestamp]
FROM dbo.[SQLDatabaseOverview]
GROUP BY [Server Name],[Instance Name],[Environment]
UNION ALL
SELECT 
	'Database Count'                 AS [AnalyticsType],
	[Server Name]                    AS [ServerName],
	[Instance Name]                  AS [InstanceName],
	ISNULL([Environment], 'Unknown') AS [Environment],
	'Total Databases'                AS [Property],
	COUNT([Database Name])           AS [Value],
	GETDATE()                        AS [Timestamp]
FROM dbo.[SQLDatabaseOverview]
GROUP BY [Server Name],[Instance Name],[Environment]
UNION ALL
SELECT 
	'Job Count'                      AS [AnalyticsType],
	[Server Name]                    AS [ServerName],
	[Instance Name]                  AS [InstanceName],
	ISNULL([Environment], 'Unknown') AS [Environment],
	'Total Jobs'                     AS [Property],
	COUNT([Job Name])                AS [Value],
	GETDATE()                        AS [Timestamp]
FROM dbo.[SQLJobOverview]
GROUP BY [Server Name],[Instance Name],[Environment]
UNION ALL
SELECT 
	'Job Step Count'                 AS [AnalyticsType],
	[Server Name]                    AS [ServerName],
	[Instance Name]                  AS [InstanceName],
	ISNULL([Environment], 'Unknown') AS [Environment],
	'Total Job Steps'                AS [Property],
	COUNT([Step Name])               AS [Value],
	GETDATE()                        AS [Timestamp]
FROM dbo.[SQLJobStepsOverview]
GROUP BY [Server Name],[Instance Name],[Environment]
UNION ALL
SELECT 
	'OS Count'                       AS [AnalyticsType],
	NULL                             AS [ServerName],
	NULL                             AS [InstanceName],
	ISNULL([Environment], 'Unknown') AS [Environment],
	[OS]                             AS [Property],
	COUNT([OS])                      AS [Value],
	GETDATE()                        AS [Timestamp]
FROM dbo.[SQLOverview]
GROUP BY [Environment],[OS]
UNION ALL
SELECT 
	'SQL Version Count'                                                                                  AS [AnalyticsType],
	NULL                                                                                                 AS [ServerName],
	NULL                                                                                                 AS [InstanceName],
	ISNULL([Environment], 'Unknown')                                                                     AS [Environment],
	ISNULL('SQL ' + [SQL Version] + ' ' + [Build] + ' ' + [Edition] + ' Instances', 'Unknown Instances') AS [Property],
	COUNT(ISNULL([SQL Version],1))                                                                       AS [Value],
	GETDATE()                                                                                            AS [Timestamp]
FROM dbo.[SQLOverview]
GROUP BY [Environment],[SQL Version],[Build],[Edition]
UNION ALL
SELECT 
	'CPU Sum'                        AS [AnalyticsType],
	NULL                             AS [ServerName],
	NULL                             AS [InstanceName],
	ISNULL([Environment], 'Unknown') AS [Environment],
	'Total Cores'                    AS [Property],
	ISNULL(SUM([Cores]), 0)          AS [Value],
	GETDATE()                        AS [Timestamp]
FROM dbo.[SQLOverview]
GROUP BY [Environment]
UNION ALL
SELECT 
	'RAM Sum'                                    AS [AnalyticsType],
	NULL                                         AS [ServerName],
	NULL                                         AS [InstanceName],
	ISNULL([Environment], 'Unknown')             AS [Environment],
	'Total Memory (GB)'                          AS [Property],
	ISNULL(CONVERT(INT, SUM([Memory in GB])), 0) AS [Value],
	GETDATE()                                    AS [Timestamp]
FROM dbo.[SQLOverview]
GROUP BY [Environment]
UNION ALL
SELECT 
	'Disk Usage Sum'                              AS [AnalyticsType],
	NULL                                          AS [ServerName],
	NULL                                          AS [InstanceName],
	ISNULL([Environment], 'Unknown')              AS [Environment],
	'Total Disk Usage (GB)'                       AS [Property],
	ISNULL(CONVERT(INT, SUM(TotalSizeMB/1024)),0) AS [Value],
	GETDATE()                                     AS [Timestamp]
FROM dbo.[SQLDatabaseOverview]
GROUP BY [Environment]
ORDER BY [AnalyticsType],[Environment],[ServerName],[InstanceName],[Property]
"@
        # This will hold all of the update queries as the script loops through instances/databases, starts by setting all codes to 1 (doesn't exist)
        $update_servers_query      = "
SET NOCOUNT ON
BEGIN TRANSACTION`n"
        $update_sqlinstances_query = "
SET NOCOUNT ON
BEGIN TRANSACTION
UPDATE [$inventorydatabase].[dbo].[SQLInstances]
SET code = 1 WHERE code = 2;`n"
        $update_sqldatabases_query = "
SET NOCOUNT ON
BEGIN TRANSACTION
UPDATE [$inventorydatabase].[dbo].[SQLDatabases]
SET code = 1 WHERE code = 2;`n"
        $update_sqljobs_query      = "
SET NOCOUNT ON
BEGIN TRANSACTION
UPDATE [$inventorydatabase].[dbo].[SQLJobs]
SET code = 1 WHERE code = 2;`n"
        $update_sqljobsteps_query  = "
SET NOCOUNT ON
BEGIN TRANSACTION
UPDATE [$inventorydatabase].[dbo].[SQLJobSteps]
SET code = 1 WHERE code = 2;

DECLARE @jobid int`n"
        $update_code               = "'2'"
    }

    process {
        Write-Verbose "Getting instances from current inventory"
        Write-Progress -Activity "Pulling instances..." -Status "Percent Complete: 0%" -PercentComplete 0
        $instances = Get-SqlInstances
        $totalstep = $instances.Count + 5
        $step      = 0
        foreach ($instance in $instances){
            Write-Verbose "Trying connection to $($instance.InstanceName)"
            $step++
            Write-Progress -Activity "Processing $($instance.InstanceName)..." -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
            $serverID   = $instance.ServerID
            $instanceID = $instance.InstanceID
            if (Test-SqlConnection -Instance $instance.InstanceName){
                Write-Verbose "Collecting instance information for $($instance.InstanceName)"
                $instanceinfo      = Invoke-Sqlcmd -serverinstance $instance.InstanceName -query $get_sqlinstanceinfo_query -connectiontimeout 5
                $version           = $instanceinfo.Version          
                $build             = $instanceinfo.Build            
                $buildnumber       = $instanceinfo.BuildNumber      
                $edition           = $instanceinfo.Edition          
                $authentication    = $instanceinfo.Authentication   
                $memoryallocatedmb = $instanceinfo.MemoryAllocatedMB
                $maxdop            = $instanceinfo.MaxDOP           
                $ctfp              = $instanceinfo.CTFP             
                $numcores          = $instanceinfo.Cores            
                $memorymb          = $instanceinfo.TotalMemoryMB    
                $startuptime       = $instanceinfo.StartupTime      
                $lastupdate        = $instanceinfo.Timestamp        
                Write-Verbose "Accounting for NULLs"
                if (          $version.GetType().Name -eq 'DBNull'){ $version           = 'NULL' } else { $version           = $version           -replace "'","''" ; $version           = "'" + $version           + "'" }
                if (            $build.GetType().Name -eq 'DBNull'){ $build             = 'NULL' } else { $build             = $build             -replace "'","''" ; $build             = "'" + $build             + "'" }
                if (      $buildnumber.GetType().Name -eq 'DBNull'){ $buildnumber       = 'NULL' } else { $buildnumber       = $buildnumber       -replace "'","''" ; $buildnumber       = "'" + $buildnumber       + "'" }
                if (          $edition.GetType().Name -eq 'DBNull'){ $edition           = 'NULL' } else { $edition           = $edition           -replace "'","''" ; $edition           = "'" + $edition           + "'" }
                if (   $authentication.GetType().Name -eq 'DBNull'){ $authentication    = 'NULL' } else { $authentication    = $authentication    -replace "'","''" ; $authentication    = "'" + $authentication    + "'" }
                if ($memoryallocatedmb.GetType().Name -eq 'DBNull'){ $memoryallocatedmb = 'NULL' } else { $memoryallocatedmb = $memoryallocatedmb -replace "'","''" ; $memoryallocatedmb = "'" + $memoryallocatedmb + "'" }
                if (           $maxdop.GetType().Name -eq 'DBNull'){ $maxdop            = 'NULL' } else { $maxdop            = $maxdop            -replace "'","''" ; $maxdop            = "'" + $maxdop            + "'" }
                if (             $ctfp.GetType().Name -eq 'DBNull'){ $ctfp              = 'NULL' } else { $ctfp              = $ctfp              -replace "'","''" ; $ctfp              = "'" + $ctfp              + "'" }
                if (         $numcores.GetType().Name -eq 'DBNull'){ $numcores          = 'NULL' } else { $numcores          = $numcores          -replace "'","''" ; $numcores          = "'" + $numcores          + "'" }
                if (         $memorymb.GetType().Name -eq 'DBNull'){ $memorymb          = 'NULL' } else { $memorymb          = $memorymb          -replace "'","''" ; $memorymb          = "'" + $memorymb          + "'" }
                if (      $startuptime.GetType().Name -eq 'DBNull'){ $startuptime       = 'NULL' } else { $startuptime       = $startuptime       -replace "'","''" ; $startuptime       = "'" + $startuptime       + "'" }
                if (       $lastupdate.GetType().Name -eq 'DBNull'){ $lastupdate        = 'NULL' } else { $lastupdate        = $lastupdate        -replace "'","''" ; $lastupdate        = "'" + $lastupdate        + "'" }
                Write-Verbose "Appending update information for instances"
                $update_sqlinstances_query += "
                UPDATE [$inventorydatabase].[dbo].[SQLInstances] 
                SET version = $version, build = $build, buildnumber = $buildnumber, edition = $edition, authentication = $authentication, memoryallocatedmb = $memoryallocatedmb, maxdop = $maxdop, ctfp = $ctfp, startuptime = $startuptime, lastupdate = $lastupdate, code = $update_code 
                WHERE instanceID = $instanceID;`n"
                Write-Verbose "Appending update information for servers"        
                $update_servers_query      += "
                UPDATE [$inventorydatabase].[dbo].[Servers] 
                SET NumCores = $numCores, MemoryMB = $memorymb, LastUpdate = $lastupdate
                WHERE serverID = $serverID;`n"
                
                Write-Verbose "Collecting database information for $($instance.InstanceName)"
                $dbs = Invoke-Sqlcmd -serverinstance $instance.InstanceName -query $get_sqldatabases_query -connectiontimeout 5
                foreach ($db in $dbs){
                    $databasename       = $db.DatabaseName       
                    $owner              = $db.Owner              
                    $status             = $db.Status             
                    $compatibilitylevel = $db.CompatibilityLevel 
                    $recoverymode       = $db.RecoveryMode   
                    $lastfullbackup     = $db.LastFullBackup
                    $lastdifferential   = $db.LastDifferential
                    $lastlogbackup      = $db.LastLogBackup
                    $lastdbcccheckdb    = $db.LastDBCCCheckDB         
                    $logsizemb          = $db.LogSizeMB          
                    $rowsizemb          = $db.RowSizeMB          
                    $totalsizemb        = $db.TotalSizeMB        
                    $lastupdate         = $db.Timestamp          
                    Write-Verbose "Accounting for NULLs"
                    if (      $databasename.GetType().Name -eq 'DBNull'){ $databasename       = 'NULL' } else { $databasename       = $databasename       -replace "'","''" ; $databasename       = "'" + $databasename       + "'" }
                    if (             $owner.GetType().Name -eq 'DBNull'){ $owner              = 'NULL' } else { $owner              = $owner              -replace "'","''" ; $owner              = "'" + $owner              + "'" }
                    if (            $status.GetType().Name -eq 'DBNull'){ $status             = 'NULL' } else { $status             = $status             -replace "'","''" ; $status             = "'" + $status             + "'" }
                    if ($compatibilitylevel.GetType().Name -eq 'DBNull'){ $compatibilitylevel = 'NULL' } else { $compatibilitylevel = $compatibilitylevel -replace "'","''" ; $compatibilitylevel = "'" + $compatibilitylevel + "'" }
                    if (      $recoverymode.GetType().Name -eq 'DBNull'){ $recoverymode       = 'NULL' } else { $recoverymode       = $recoverymode       -replace "'","''" ; $recoverymode       = "'" + $recoverymode       + "'" }
                    if (    $lastfullbackup.GetType().Name -eq 'DBNull'){ $lastfullbackup     = 'NULL' } else { $lastfullbackup     = $lastfullbackup     -replace "'","''" ; $lastfullbackup     = "'" + $lastfullbackup     + "'" }
                    if (  $lastdifferential.GetType().Name -eq 'DBNull'){ $lastdifferential   = 'NULL' } else { $lastdifferential   = $lastdifferential   -replace "'","''" ; $lastdifferential   = "'" + $lastdifferential   + "'" }
                    if (     $lastlogbackup.GetType().Name -eq 'DBNull'){ $lastlogbackup      = 'NULL' } else { $lastlogbackup      = $lastlogbackup      -replace "'","''" ; $lastlogbackup      = "'" + $lastlogbackup      + "'" }
                    if (   $lastdbcccheckdb.GetType().Name -eq 'DBNull'){ $lastdbcccheckdb    = 'NULL' } else { $lastdbcccheckdb    = $lastdbcccheckdb    -replace "'","''" ; $lastdbcccheckdb    = "'" + $lastdbcccheckdb    + "'" }
                    if (         $logsizemb.GetType().Name -eq 'DBNull'){ $logsizemb          = 'NULL' } else { $logsizemb          = $logsizemb          -replace "'","''" ; $logsizemb          = "'" + $logsizemb          + "'" }
                    if (         $rowsizemb.GetType().Name -eq 'DBNull'){ $rowsizemb          = 'NULL' } else { $rowsizemb          = $rowsizemb          -replace "'","''" ; $rowsizemb          = "'" + $rowsizemb          + "'" }
                    if (       $totalsizemb.GetType().Name -eq 'DBNull'){ $totalsizemb        = 'NULL' } else { $totalsizemb        = $totalsizemb        -replace "'","''" ; $totalsizemb        = "'" + $totalsizemb        + "'" }
                    if (        $lastupdate.GetType().Name -eq 'DBNull'){ $lastupdate         = 'NULL' } else { $lastupdate         = $lastupdate         -replace "'","''" ; $lastupdate         = "'" + $lastupdate         + "'" }
                    Write-Verbose "Appending update/insert information for databases"
                    $update_sqldatabases_query += "
                    IF EXISTS(SELECT databaseID FROM [$inventorydatabase].[dbo].[SQLDatabases] WHERE name = $databasename and instanceID = $instanceID)
	                    UPDATE [$inventorydatabase].[dbo].[SQLDatabases] 
	                    SET owner = $owner, status = $status, compatibilitylevel = $compatibilitylevel, recoverymode = $recoverymode, lastfullbackup = $lastfullbackup, lastdifferential = $lastdifferential, lastlogbackup = $lastlogbackup, lastdbcccheckdb = $lastdbcccheckdb, logsizemb = $logsizemb, rowsizemb = $rowsizemb, totalsizemb = $totalsizemb, lastupdate = $lastupdate, code = $update_code 
	                    WHERE name = $databasename and instanceID = $instanceID;
                    ELSE 
	                    INSERT INTO [$inventorydatabase].[dbo].[SQLDatabases]
                        (instanceID,name,owner,status,compatibilitylevel,recoverymode,lastfullbackup,lastdifferential,lastlogbackup,lastdbcccheckdb,logsizemb,rowsizemb,totalsizemb,lastupdate,code) VALUES
	                    ($instanceid,$databasename,$owner,$status,$compatibilitylevel,$recoverymode,$lastfullbackup,$lastdifferential,$lastlogbackup,$lastdbcccheckdb,$logsizemb,$rowsizemb,$totalsizemb,$lastupdate,$update_code);`n"
                }
                
                Write-Verbose "Collecting job information for $($instance.InstanceName)"
                $jobs = Invoke-Sqlcmd -serverinstance $instance.InstanceName -query $get_sqljobs_query -connectiontimeout 5
                foreach ($job in $jobs){
                    $jobname       = $job.JobName       
                    $status        = $job.Status        
                    $owner         = $job.Owner         
                    $notifylevel   = $job.NotifyLevel   
                    $notifyemail   = $job.NotifyEmail
                    $schedules     = $job.Schedules   
                    $lastrunstatus = $job.LastRunStatus 
                    $lastrundate   = $job.LastRunDate   
                    $runduration   = $job.RunDuration   
                    $nextrundate   = $job.NextRunDate
                    $description   = $job.Description   
                    $lastupdate    = $job.Timestamp     
                    Write-Verbose "Accounting for NULLs"
                    if (      $jobname.GetType().Name -eq 'DBNull'){ $jobname       = 'NULL' } else { $jobname       = $jobname       -replace "'","''" ; $jobname       = "'" + $jobname       + "'" }    
                    if (       $status.GetType().Name -eq 'DBNull'){ $status        = 'NULL' } else { $status        = $status        -replace "'","''" ; $status        = "'" + $status        + "'" }    
                    if (        $owner.GetType().Name -eq 'DBNull'){ $owner         = 'NULL' } else { $owner         = $owner         -replace "'","''" ; $owner         = "'" + $owner         + "'" }      
                    if (  $notifylevel.GetType().Name -eq 'DBNull'){ $notifylevel   = 'NULL' } else { $notifylevel   = $notifylevel   -replace "'","''" ; $notifylevel   = "'" + $notifylevel   + "'" }
                    if (  $notifyemail.GetType().Name -eq 'DBNull'){ $notifyemail   = 'NULL' } else { $notifyemail   = $notifyemail   -replace "'","''" ; $notifyemail   = "'" + $notifyemail   + "'" }
                    if (    $schedules.GetType().Name -eq 'DBNull'){ $schedules     = 'NULL' } else { $schedules     = $schedules     -replace "'","''" ; $schedules     = "'" + $schedules     + "'" }
                    if ($lastrunstatus.GetType().Name -eq 'DBNull'){ $lastrunstatus = 'NULL' } else { $lastrunstatus = $lastrunstatus -replace "'","''" ; $lastrunstatus = "'" + $lastrunstatus + "'" }
                    if (  $lastrundate.GetType().Name -eq 'DBNull'){ $lastrundate   = 'NULL' } else { $lastrundate   = $lastrundate   -replace "'","''" ; $lastrundate   = "'" + $lastrundate   + "'" }
                    if (  $runduration.GetType().Name -eq 'DBNull'){ $runduration   = 'NULL' } else { $runduration   = $runduration   -replace "'","''" ; $runduration   = "'" + $runduration   + "'" }
                    if (  $nextrundate.GetType().Name -eq 'DBNull'){ $nextrundate   = 'NULL' } else { $nextrundate   = $nextrundate   -replace "'","''" ; $nextrundate   = "'" + $nextrundate   + "'" }
                    if (  $description.GetType().Name -eq 'DBNull'){ $description   = 'NULL' } else { $description   = $description   -replace "'","''" ; $description   = "'" + $description   + "'" }
                    if (   $lastupdate.GetType().Name -eq 'DBNull'){ $lastupdate    = 'NULL' } else { $lastupdate    = $lastupdate    -replace "'","''" ; $lastupdate    = "'" + $lastupdate    + "'" } 
                    Write-Verbose "Appending update/insert information for jobs"
                    $update_sqljobs_query += "
                    IF EXISTS(SELECT jobID FROM [$inventorydatabase].[dbo].[SQLJobs] WHERE name = $jobname and instanceID = $instanceID)
                        UPDATE [$inventorydatabase].[dbo].[SQLJobs] 
	                    SET status = $status, owner = $owner, notifylevel = $notifylevel, notifyemail = $notifyemail, schedules = $schedules, lastrunstatus = $lastrunstatus, lastrundate = $lastrundate, runduration = $runduration, nextrundate = $nextrundate, description = $description, lastupdate = $lastupdate, code = $update_code
	                    WHERE name = $jobname and instanceID = $instanceID;
                    ELSE 
	                    INSERT INTO [$inventorydatabase].[dbo].[SQLJobs] 
                        (instanceID,name,status,owner,notifylevel,notifyemail,schedules,lastrunstatus,lastrundate,runduration,nextrundate,description,lastupdate,code) VALUES
                        ($instanceID,$jobname,$status,$owner,$notifylevel,$notifyemail,$schedules,$lastrunstatus,$lastrundate,$runduration,$nextrundate,$description,$lastupdate,$update_code);`n"
                }
                
                Write-Verbose "Collecting job step information for $($instance.InstanceName)"  
                $jobsteps = Invoke-Sqlcmd -serverinstance $instance.InstanceName -query $get_sqljobsteps_query -connectiontimeout 5
                foreach ($jobstep in $jobsteps){
                    $jobname         = $jobstep.JobName         
                    $stepnumber      = $jobstep.StepNumber      
                    $stepname        = $jobstep.StepName        
                    $subsystem       = $jobstep.SubSystem       
                    $lastrunstatus   = $jobstep.LastRunStatus   
                    $lastrundate     = $jobstep.LastRunDate     
                    $lastrunduration = $jobstep.LastRunDuration 
                    $proxy           = $jobstep.Proxy           
                    $logfile         = $jobstep.LogFile         
                    $command         = $jobstep.Command         
                    $message         = $jobstep.Message         
                    $stepuid         = $jobstep.StepUID         
                    $lastupdate      = $jobstep.Timestamp       
                    Write-Verbose "Accounting for NULLs"                                                                                                      
                    if (        $jobname.GetType().Name -eq 'DBNull'){ $jobname         = 'NULL' } else { $jobname         = $jobname         -replace "'","''" ; $jobname         = "'" + $jobname         + "'" }          
                    if (     $stepnumber.GetType().Name -eq 'DBNull'){ $stepnumber      = 'NULL' } else { $stepnumber      = $stepnumber      -replace "'","''" ; $stepnumber      = "'" + $stepnumber      + "'" }       
                    if (       $stepname.GetType().Name -eq 'DBNull'){ $stepname        = 'NULL' } else { $stepname        = $stepname        -replace "'","''" ; $stepname        = "'" + $stepname        + "'" }         
                    if (      $subsystem.GetType().Name -eq 'DBNull'){ $subsystem       = 'NULL' } else { $subsystem       = $subsystem       -replace "'","''" ; $subsystem       = "'" + $subsystem       + "'" }        
                    if (  $lastrunstatus.GetType().Name -eq 'DBNull'){ $lastrunstatus   = 'NULL' } else { $lastrunstatus   = $lastrunstatus   -replace "'","''" ; $lastrunstatus   = "'" + $lastrunstatus   + "'" }    
                    if (    $lastrundate.GetType().Name -eq 'DBNull'){ $lastrundate     = 'NULL' } else { $lastrundate     = $lastrundate     -replace "'","''" ; $lastrundate     = "'" + $lastrundate     + "'" }      
                    if ($lastrunduration.GetType().Name -eq 'DBNull'){ $lastrunduration = 'NULL' } else { $lastrunduration = $lastrunduration -replace "'","''" ; $lastrunduration = "'" + $lastrunduration + "'" }  
                    if (          $proxy.GetType().Name -eq 'DBNull'){ $proxy           = 'NULL' } else { $proxy           = $proxy           -replace "'","''" ; $proxy           = "'" + $proxy           + "'" }            
                    if (        $logfile.GetType().Name -eq 'DBNull'){ $logfile         = 'NULL' } else { $logfile         = $logfile         -replace "'","''" ; $logfile         = "'" + $logfile         + "'" }          
                    if (        $command.GetType().Name -eq 'DBNull'){ $command         = 'NULL' } else { $command         = $command         -replace "'","''" ; $command         = "'" + $command         + "'" }          
                    if (        $message.GetType().Name -eq 'DBNull'){ $message         = 'NULL' } else { $message         = $message         -replace "'","''" ; $message         = "'" + $message         + "'" }          
                    if (        $stepuid.GetType().Name -eq 'DBNull'){ $stepuid         = 'NULL' } else { $stepuid         = $stepuid         -replace "'","''" ; $stepuid         = "'" + $stepuid         + "'" }          
                    if (     $lastupdate.GetType().Name -eq 'DBNull'){ $lastupdate      = 'NULL' } else { $lastupdate      = $lastupdate      -replace "'","''" ; $lastupdate      = "'" + $lastupdate      + "'" }       
                    Write-Verbose "Appending update/insert information for job steps"
                    $update_sqljobsteps_query += "
                    SELECT @jobid = jobid FROM [$inventorydatabase].[dbo].[SQLJobs] WHERE name = $jobname and instanceID = $instanceID
                    IF EXISTS(SELECT jobStepID FROM [$inventorydatabase].[dbo].[SQLJobSteps] WHERE jobID = @jobid AND stepnumber = $stepnumber)
                        UPDATE [$inventorydatabase].[dbo].[SQLJobSteps] 
	                    SET jobid = @jobid, stepnumber = $stepnumber, stepname = $stepname, subsystem = $subsystem, lastrunstatus = $lastrunstatus, lastrundate = $lastrundate, lastrunduration = $lastrunduration, proxy = $proxy, logfile = $logfile, command = $command, message = $message, jobstepuid = $stepuid, lastupdate = $lastupdate, code = $update_code
	                    WHERE jobID = @jobid AND stepnumber = $stepnumber;
                    ELSE 
	                    INSERT INTO [$inventorydatabase].[dbo].[SQLJobSteps] 
                        (jobid,stepnumber,stepname,subsystem,lastrunstatus,lastrundate,lastrunduration,proxy,logfile,command,message,jobstepuid,lastupdate,code) VALUES
                        (@jobid,$stepnumber,$stepname,$subsystem,$lastrunstatus,$lastrundate,$lastrunduration,$proxy,$logfile,$command,$message,$stepuid,$lastupdate,$update_code);`n"
                }
            }
            else{ Write-Error "Could not connect to $($instance.InstanceName)" }
        } 
        <#
        $update_sqldatabases_query += "
        DELETE FROM [$inventorydatabase].[dbo].[SQLDatabases]
        WHERE code = 1;`n"
        $update_sqljobs_query      += "
        DELETE FROM [$inventorydatabase].[dbo].[SQLJobs]
        WHERE code = 1;`n"
        $update_sqljobsteps_query  += "
        DELETE FROM [$inventorydatabase].[dbo].[SQLJobSteps]
        WHERE code = 1;`n"
        #>
        Write-Verbose "Completing transactions"
        $update_servers_query      += "
        COMMIT TRANSACTION"
        $update_sqlinstances_query += "
        COMMIT TRANSACTION"
        $update_sqldatabases_query += "
        COMMIT TRANSACTION"
        $update_sqljobs_query      += "
        COMMIT TRANSACTION"
        $update_sqljobsteps_query  += "
        COMMIT TRANSACTION"
        Write-Verbose "Running instance update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqlinstance_query..."  -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqlinstances_query -connectiontimeout 5 -DisableVariables
        Write-Verbose "Running database update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqldatabases_query..." -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqldatabases_query -connectiontimeout 5 -DisableVariables
        Write-Verbose "Running job update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqljobs_query..."      -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqljobs_query      -connectiontimeout 5 -DisableVariables
        Write-Verbose "Running job step update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqljobsteps_query..."  -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqljobsteps_query  -connectiontimeout 5 -DisableVariables
        $step++
        Write-Progress -Activity "Executing insert_sqlanalytics_query..." -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $insert_sqlanalytics_query -connectiontimeout 5 -DisableVariables

        #Add-Content -Path "C:\Temp\update-servers.sql"      $update_servers_query
        #Add-Content -Path "C:\Temp\update-sqlinstances.sql" $update_sqlinstances_query
        #Add-Content -Path "C:\Temp\update-sqldatabases.sql" $update_sqldatabases_query
        #Add-Content -Path "C:\Temp\update-sqljobs.sql"      $update_sqljobs_query
        #Add-Content -Path "C:\Temp\update-sqljobsteps.sql"  $update_sqljobsteps_query
    }

    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}

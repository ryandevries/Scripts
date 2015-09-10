FUNCTION Get-SqlDatabaseInformation {
<#
.SYNOPSIS 
    Returns information about databases on specified instance(s)
.DESCRIPTION
	Returns the following for each database for each instance:
		- Database Name      
		- Owner             
		- Status            
		- Compatibility Level
		- Recovery Mode   
		- Last Full Backup
		- Last Differential Backup
		- Last Log Backup
		- Last DBCC CheckDB   
		- Log Size in MB         
		- Row Size in MB         
		- Total Size in MB       
		- Time stamp 
.PARAMETER  Instance
	The name of the instance(s) you wish to check.  Leaving this off will pull all instances from the inventory
.EXAMPLE
    PS C:\> Get-SqlDatabaseInformation -Instance sql01
.EXAMPLE
    PS C:\> Get-SqlDatabaseInformation -Instance (Get-Content C:\TEMP\instances.txt)
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/09/10
    Version     : 1
.INPUTS
    [string[]]
.OUTPUTS
    [array]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage="Name of the instance(s) to check, leave off for all instances")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
        [string[]]$Instance
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring 
        $results = @()
		$script  = @"
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
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''MachineName'')))  AS [ServerName], 
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''InstanceName''))) AS [InstanceName],
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
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''MachineName'')))  AS [ServerName], 
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''InstanceName''))) AS [InstanceName],
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
    }
	
	process {
        if ($instance){
            $instances  = @()
            foreach ($inst in $instance){
                Write-Verbose "Adding $inst to processing array..."
                $holder     = New-Object -TypeName PSObject
                Add-Member -InputObject $holder -MemberType NoteProperty -Name 'InstanceName' -Value $inst
                $instances += $holder
            }
        }
        else {
            Write-Verbose "Pulling instances from inventory"
            Write-Progress -id 1 -Activity "Pulling instances..." -Status "Percent Complete: 0%" -PercentComplete 0
            $instances = Get-SqlInstances
        }
        $totalstep = $instances.Count
        $stepnum   = 0
        foreach ($inst in $instances){
	        Write-Verbose "Executing against $($inst.InstanceName)"
            $stepnum++
            Write-Progress -id 1 -Activity "Processing $($inst.InstanceName)..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
            Write-Verbose "Executing query"
            try { $result = Invoke-Sqlcmd -ServerInstance $inst.InstanceName -Query $script -ConnectionTimeout 5 -ErrorAction Stop }
            catch { Write-Error "Error executing query against $($inst.InstanceName): $($_.Exception.GetBaseException().Message)" }
            $results += $result
        }
    }
    
    end { 
        Write-Verbose "Outputting results"
        $results
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}
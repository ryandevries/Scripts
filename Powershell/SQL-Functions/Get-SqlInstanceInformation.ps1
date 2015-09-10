FUNCTION Get-SqlInstanceInformation {
<#
.SYNOPSIS 
    Returns information about specified instance(s)
.DESCRIPTION
	Returns the following for each instance:
		- Server name
		- Instance name
		- SQL version
		- SQL major build (RTM, service pack)
		- SQL build number
		- SQL edition (Standard, Enterprise, Express, etc)
		- SQL authentication (Windows, mixed mode)
		- Max degrees of parallelism
		- Cost threshold for parallelism
		- Number of cores
		- Memory allocated for SQL
		- Total memory on the server
		- Latest SQL startup time
		- Time stamp
.PARAMETER  Instance
	The name of the instance(s) you wish to check.  Leaving this off will pull all instances from the inventory
.EXAMPLE
    PS C:\> Get-SqlInstanceInformation -Instance sql01
.EXAMPLE
    PS C:\> Get-SqlInstanceInformation -Instance (Get-Content C:\TEMP\instances.txt)
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
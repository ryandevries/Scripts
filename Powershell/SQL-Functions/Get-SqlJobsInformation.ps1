FUNCTION Get-SqlJobInformation {
<#
.SYNOPSIS 
    Returns information about jobs on specified instance(s)
.DESCRIPTION
	Returns the following for each job for each instance:
		- Job Name      
		- Status       
		- Owner        
		- Notify Level  
		- Notify Email
		- Schedules   
		- Last Run Status
		- Last Run Date  
		- Last Run Duration  
		- Next Run Date
		- Description  
		- Time stamp    
.PARAMETER  Instance
	The name of the instance(s) you wish to check.  Leaving this off will pull all instances from the inventory
.EXAMPLE
    PS C:\> Get-SqlJobInformation -Instance sql01
.EXAMPLE
    PS C:\> Get-SqlJobInformation -Instance (Get-Content C:\TEMP\instances.txt)
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
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''MachineName'')))  AS [ServerName], 
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''InstanceName''))) AS [InstanceName],
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
SELECT 
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''MachineName'')))  AS [ServerName], 
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''InstanceName''))) AS [InstanceName],
	sj.[name]                           AS [JobName],
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
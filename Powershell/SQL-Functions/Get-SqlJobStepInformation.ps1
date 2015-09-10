FUNCTION Get-SqlJobStepInformation {
<#
.SYNOPSIS 
    Returns information about job steps on specified instance(s)
.DESCRIPTION
	Returns the following for each step for each job for each instance:
		- Job Name        
		- Step Number     
		- Step Name       
		- Sub System      
		- Last Run Status  
		- Last Run Date    
		- Last Run Duration
		- Proxy          
		- Log File        
		- Command        
		- Message        
		- Step UID        
		- Time stamp  
.PARAMETER  Instance
	The name of the instance(s) you wish to check.  Leaving this off will pull all instances from the inventory
.EXAMPLE
    PS C:\> Get-SqlJobStepInformation -Instance sql01
.EXAMPLE
    PS C:\> Get-SqlJobStepInformation -Instance (Get-Content C:\TEMP\instances.txt)
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
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''MachineName'')))  AS [ServerName], 
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''InstanceName''))) AS [InstanceName],
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
SELECT 
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''MachineName'')))  AS [ServerName], 
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''InstanceName''))) AS [InstanceName],
	sj.[name]              AS [JobName], 
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
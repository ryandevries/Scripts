FUNCTION Get-SqlConfigValue {
<#
.SYNOPSIS 
    Returns the configured value of a specified name on specified instances
.DESCRIPTION
    Returns the configured value of a specified name on specified instances
.PARAMETER  Instance
    The name of the instance(s) you wish to check.  Leaving this off will pull all instances from the inventory
.PARAMETER  Config
    The name of the configuration in sys.configurations
.EXAMPLE
    PS C:\> Get-SqlConfigValue -Instance sql01 -Config xp_cmdshell
.EXAMPLE
    PS C:\> Get-SqlConfigValue -Instance (Get-Content C:\TEMP\instances.txt) -Config "max degree of parallelism"
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/26
    Version     : 1
.INPUTS
    [string[]],[string]
.OUTPUTS
    [array]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage="Name of the instance(s) to check, leave off for all instances")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
        [string[]]$Instance,
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Name of the config value to check")]
        [ValidateSet("%","access check cache bucket count","access check cache quota","Ad Hoc Distributed Queries","affinity I/O mask","affinity mask","affinity64 I/O mask","affinity64 mask","Agent XPs","allow updates","backup compression default","blocked process threshold (s)","c2 audit mode","clr enabled","contained database authentication","cost threshold for parallelism","cross db ownership chaining","cursor threshold","Database Mail XPs","default full-text language","default language","default trace enabled","disallow results from triggers","filestream access level","fill factor (%)","ft crawl bandwidth (max)","ft crawl bandwidth (min)","ft notify bandwidth (max)","ft notify bandwidth (min)","index create memory (KB)","in-doubt xact resolution","lightweight pooling","locks","max degree of parallelism","max full-text crawl range","max server memory (MB)","max text repl size (B)","max worker threads","media retention","min memory per query (KB)","min server memory (MB)","nested triggers","network packet size (B)","Ole Automation Procedures","open objects","optimize for ad hoc workloads","PH timeout (s)","precompute rank","priority boost","query governor cost limit","query wait (s)","recovery interval (min)","remote access","remote admin connections","remote login timeout (s)","remote proc trans","remote query timeout (s)","Replication XPs","scan for startup procs","server trigger recursion","set working set size","show advanced options","SMO and DMO XPs","transform noise words","two digit year cutoff","user connections","user options","xp_cmdshell")]
        [string]$Config = "%",
        [Parameter(Position=2,Mandatory=$false,HelpMessage="Return only non-default settings")]
        [switch]$NonDefault
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring 
        $results   = @()
        $script    = @"
DECLARE @CONFIGS_PRESQL20008_TSQL  VARCHAR(8000)
DECLARE @CONFIGS_POSTSQL20008_TSQL VARCHAR(8000)

IF OBJECT_ID('tempdb..##config_defaults') IS NOT NULL
	DROP TABLE ##config_defaults
CREATE TABLE ##config_defaults (configuration_id int, name nvarchar(35), default_value sql_variant)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1582','access check cache bucket count',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1583','access check cache quota',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('16391','Ad Hoc Distributed Queries',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1550','affinity I/O mask',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1535','affinity mask',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1551','affinity64 I/O mask',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1549','affinity64 mask',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('16384','Agent XPs',1)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('102','allow updates',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1548','awe enabled',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1579','backup compression default',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1569','blocked process threshold (s)',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('544','c2 audit mode',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1562','clr enabled',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1577','common criteria compliance enabled',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1538','cost threshold for parallelism',5)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('400','cross db ownership chaining',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1531','cursor threshold',-1)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('16386','Database Mail XPs',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1126','default full-text language',1033)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('124','default language',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1568','default trace enabled',1)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('114','disallow results from triggers',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1578','EKM provider enabled',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1580','filestream access level',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('109','fill factor (%)',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1567','ft crawl bandwidth (max)',100)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1566','ft crawl bandwidth (min)',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1565','ft notify bandwidth (max)',100)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1564','ft notify bandwidth (min)',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1505','index create memory (KB)',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1570','in-doubt xact resolution',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1546','lightweight pooling',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('106','locks',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1539','max degree of parallelism',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1563','max full-text crawl range',4)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1544','max server memory (MB)',2147483647)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1536','max text repl size (B)',65536)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('503','max worker threads',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1537','media retention',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1540','min memory per query (KB)',1024)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1543','min server memory (MB)',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('115','nested triggers',1)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('505','network packet size (B)',4096)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('16388','Ole Automation Procedures',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('107','open objects',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1581','optimize for ad hoc workloads',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1557','PH timeout (s)',60)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1556','precompute rank',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1517','priority boost',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1545','query governor cost limit',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1541','query wait (s)',-1)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('101','recovery interval (min)',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('117','remote access',1)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1576','remote admin connections',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1519','remote login timeout (s)',20)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('542','remote proc trans',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1520','remote query timeout (s)',600)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('16392','Replication XPs',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1547','scan for startup procs',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('116','server trigger recursion',1)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1532','set working set size',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('518','show advanced options',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('16387','SMO and DMO XPs',1)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('16385','SQL Mail XPs',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1555','transform noise words',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1127','two digit year cutoff',2049)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('103','user connections',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1534','user options',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('16390','xp_cmdshell',0)

SET @CONFIGS_PRESQL20008_TSQL  = 'SELECT CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''MachineName''))) AS [ServerName], CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''InstanceName''))) AS [InstanceName], d.[name] AS [ConfigName], c.[comment] AS [Description], CONVERT(INT, [value]) AS [ConfigValue], d.[default_value] AS [DefaultValue] FROM [dbo].[sysconfigures] c JOIN ##config_defaults d on c.[config] = d.[configuration_id] WHERE d.[name] LIKE ''$config'''
SET @CONFIGS_POSTSQL20008_TSQL = 'SELECT CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''MachineName''))) AS [ServerName], CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''InstanceName''))) AS [InstanceName], d.[name] AS [ConfigName], [Description], CONVERT(INT, ISNULL([value], [value_in_use])) AS [ConfigValue], d.[default_value] AS [DefaultValue] FROM [sys].[configurations] c JOIN ##config_defaults d on c.[configuration_id] = d.[configuration_id] WHERE d.[name] LIKE ''$config'''

IF LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR),1)='8'
BEGIN
	EXEC (@CONFIGS_PRESQL20008_TSQL)
END
ELSE IF LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR),1)='9'
BEGIN	
	EXEC (@CONFIGS_PRESQL20008_TSQL) 
END
ELSE
BEGIN
	EXEC (@CONFIGS_POSTSQL20008_TSQL)
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
        if ($nondefault){ $results | Where-Object {$_.ConfigValue -ne $_.DefaultValue} } else { $results }
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

FUNCTION Get-SqlFailedJobs {
<#
.SYNOPSIS 
    Returns a list of failed production SQL jobs over the last 24 hours
.DESCRIPTION
    Dependendencies  : SQL Server SMO
    SQL Permissions  : SQLAgentUserRole on each of the instances and read to ServerInventory database
.PARAMETER  Instance
    The name of the instance you wish to check jobs on
.EXAMPLE
    PS C:\> Get-SqlFailedJobs -Instances DEV-MSSQL
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/12
    Version     : 2
.INPUTS
    [string[]]
.OUTPUTS
    [boolean]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage="Name of the instance(s) to check, leave off for all production instances")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
        [string[]]$Instance,
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Number of days to go back, default of 1")]
        [ValidateNotNullorEmpty()]
        [int]$Days = 1
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $date        = Get-Date
        $today       = $date.ToShortDateString()
        $failedsteps = @()
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
            # Pull all Production SQL instances from Server Inventory
            Write-Progress -Activity "Pulling instances..." -Status "Percent Complete: 0%" -PercentComplete 0
            $instances = Get-SqlInstances -Production
        }
        $totalstep = $instances.Count
        $stepnum   = 0
        # Loop through each instance
        foreach ($inst in $instances){
            Write-Verbose "Checking $($inst.InstanceName) for failed jobs"
            $stepnum++
            Write-Progress -Activity "Processing $($inst.InstanceName)..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
            # Set up SMO server object to pull data from
            $srv = New-Object "Microsoft.SqlServer.Management.Smo.Server" $inst.InstanceName  
            # Loop through each job on the instance
            foreach ($job in $srv.Jobserver.Jobs){
                # Set up job variables
                $jobName           = $job.Name
                $jobID             = $job.JobID
                $jobEnabled        = $job.IsEnabled
                $jobLastRunOutcome = $job.LastRunOutcome
                $jobLastRun        = $job.LastRunDate                  
                # Filter out jobs that are disabled or have never run
                if ($jobEnabled -eq "true" -and $jobLastRun){  
                    # Calculate the number of days ago the job ran
                    $datediff = New-TimeSpan $jobLastRun $today
                    # Check to see if the job failed in the last 24 hours   
                    if ($datediff.days -le $days -and $jobLastRunOutcome -eq "Failed"){
                        Write-Verbose "Found failed job: $jobName on instance: $($inst.InstanceName)"
                        # Loop through each step in the job
                        foreach ($step in $job.JobSteps){
                            # Set up step variables
                            $stepName           = $step.Name
                            $stepID             = $step.ID
                            $stepLastRunOutcome = $step.LastRunOutcome
                            $stepOutputFile     = $step.OutputFileName
                            # Filter out steps that succeeded
                            if ($stepLastRunOutcome -eq "Failed"){
                                Write-Verbose "Found failed job step: $stepName on job: $jobName on instance: $($inst.InstanceName)"
                                # Get the latest message returned for the failed step
                                $stepMessage = (Invoke-Sqlcmd -ServerInstance $inst.InstanceName -Database msdb -Query "SELECT TOP 1 message FROM msdb.dbo.sysjobhistory WHERE job_id = '$jobID' AND step_id = '$stepID' ORDER BY instance_id DESC").message
                                # Filter out steps that didn't have a chance to run (have a failed status but no message)
                                if ($stepMessage.length -gt 0){
                                    # Format error messages a little bit
                                    $stepMessage = $stepMessage -replace 'Source:', "`r`n`r`nSource:"
                                    $stepMessage = $stepMessage -replace 'Description:', "`r`nDescription:"
                                    $failedstep  = New-Object -TypeName PSObject
                                    Add-Member -InputObject $failedstep -MemberType NoteProperty -Name 'Instance'   -Value $inst.InstanceName
                                    Add-Member -InputObject $failedstep -MemberType NoteProperty -Name 'JobName'    -Value $jobName
                                    Add-Member -InputObject $failedstep -MemberType NoteProperty -Name 'Outcome'    -Value $jobLastRunOutcome
                                    Add-Member -InputObject $failedstep -MemberType NoteProperty -Name 'Date'       -Value $jobLastRun
                                    Add-Member -InputObject $failedstep -MemberType NoteProperty -Name 'StepName'   -Value $stepName
                                    Add-Member -InputObject $failedstep -MemberType NoteProperty -Name 'OutputFile' -Value $stepOutputFile
                                    Add-Member -InputObject $failedstep -MemberType NoteProperty -Name 'Message'    -Value $stepMessage
                                    $failedsteps += $failedstep
                                }
                            }
                        }
                    } 
                }
            }
        }
    }
    
    end { 
        Write-Verbose "Outputting results"
        if ($failedsteps.Count -eq 0){ $failedsteps = "No outstanding failed jobs over past $days day(s)" }
        $failedsteps
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

FUNCTION Get-SqlInstances {
<#
.SYNOPSIS 
    Returns of object of SQL instances
.DESCRIPTION
	Returns of object of SQL instances that match a given environment and are accessible based on the SQL inventory, along with most inventory data about the instance
.PARAMETER  Development
    Returns all development instances
.PARAMETER  Test
    Returns all test instances
.PARAMETER  Production
    Returns all production instances
.EXAMPLE
    PS C:\> Get-SqlInstances -Development -Test
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/11
    Version     : 1
.INPUTS
    [switch]
.OUTPUTS
    [object]
#>
    [CmdletBinding()]
    Param(
	    [Parameter(Position=0,Mandatory=$false,HelpMessage="Toggles development instances")]
        [switch]$Development,
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Toggles test instances")]
        [switch]$Test,
        [Parameter(Position=2,Mandatory=$false,HelpMessage="Toggles production instances")]
        [switch]$Production
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $inventoryinstance = 'utility-db'
        $inventorydatabase = 'ServerInventory'
    }
 
    process {
        $blank  = $true
        $filter = "AND [Environment] IN ("
        if ($development) { $filter += "'Development'," ; $blank = $false }
        if ($test)        { $filter += "'Test',"        ; $blank = $false }
        if ($production)  { $filter += "'Production',"  ; $blank = $false }
        
        if ($blank) { $filter  = "" } else { $filter = $filter -replace ".$" ; $filter += ")" }
        $get_instances_query = "
        SELECT 
	        s.[ServerID], si.[InstanceID],
	        s.[Name] + CASE WHEN si.[Name] = 'Default Instance' THEN '' ELSE '\' + si.[Name] END AS [InstanceName],
	        s.[Environment], s.[OS], s.[OSEdition], si.[Version] AS [SQLVersion], si.[Build] AS [SQLBuild], si.[BuildNumber] AS [SQLBuildNumber], si.[Edition] AS [SQLEdition], si.[Authentication], si.[License], s.[NumCores] AS [Cores],
	        CASE s.[Environment] WHEN 'Production' THEN CASE WHEN s.[NumCores] < 4 AND si.[Edition] NOT LIKE 'Express%' THEN 4 WHEN s.[NumCores] >= 4 AND si.[Edition] NOT LIKE 'Express%' THEN s.[NumCores] END END AS [LicensableCores],
            s.[MemoryMB], si.[MemoryAllocatedMB], si.[NumCALs] AS [CALs], si.[MaxDOP], si.[CTFP], si.[StartupTime] AS [Startup Time], si.[InRedGate], 
	        s.[Notes] AS [Server Notes], si.[Notes] AS [Instance Notes], si.[LastUpdate] AS [Last Updated], si.[Code]
        FROM		[dbo].[Servers] AS s 
        INNER JOIN	[dbo].[SQLInstances] AS si ON si.ServerID = s.ServerID
        WHERE si.[Name] IS NOT NULL AND si.[Code] = 2 $filter 
        ORDER BY InstanceName"
        try { 
            if ($filter -eq ""){ $filter = "No filter" }
            Write-Verbose "Trying to pull instances with filter: $filter"
            $instances = Invoke-Sqlcmd -Serverinstance $inventoryinstance -Database $inventorydatabase -Query $get_instances_query -Connectiontimeout 5
            Write-Verbose "Retrieved instances"
            $instances
        }
        catch { 
            Write-Verbose "ERROR : $($_.Exception)"
            throw $_ 
        }
    }
    
    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}

FUNCTION Get-SqlLastBackups {
<#
.SYNOPSIS 
    Gets the last full, diff, and log backup datetime
.DESCRIPTION
    Gets the last full, diff, and log backup datetime, as well as the latest backup of the three types and any common issues (missing backups, old backups, no log backups in a logged recovery model)
.PARAMETER  Instance
    The name of the instance(s) you wish to check.  Leaving this off will pull all instances from the inventory
.PARAMETER  RPO
    The RPO in hours for the databases.  Specifying this will return any databases that violate this RPO
.EXAMPLE
    PS C:\> Get-SqlLastBackups -Instance sql01 -RPO 1
.EXAMPLE
    PS C:\> Get-SqlLastBackups -Instance (Get-Content C:\TEMP\instances.txt) | ft
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/23
    Version     : 1
.INPUTS
    [string[]],[int]
.OUTPUTS
    [array]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage="Name of the instance(s) to check, leave off for all instances")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
        [string[]]$Instance,
        [Parameter(Position=1,Mandatory=$false,HelpMessage="RPO in hours, will return the RPO violators")]
        [ValidateScript({$_ -gt 0})]
        [int]$RPO
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $date      = Get-Date   
        $databases = @()
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
            Write-Verbose "Checking $($inst.InstanceName) for failed jobs"
            $stepnum++
            Write-Progress -id 1 -Activity "Processing $($inst.InstanceName)..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
            Write-Verbose "Setting up SMO server object for $($inst.InstanceName) to pull data from"
            $srv        = New-Object "Microsoft.SqlServer.Management.Smo.Server" $inst.InstanceName  
            $totalstep2 = $srv.Databases.Count
            $stepnum2   = 0
            foreach ($database in $srv.Databases){
                Write-Verbose "Processing $($inst.InstanceName).$($database.Name)"
                $stepnum2++
                Write-Progress -id 2 -ParentId 1 -Activity "Processing $($inst.InstanceName).$($database.Name)..." -Status ("Percent Complete: " + [int](($stepnum2 / $totalstep2) * 100) + "%") -PercentComplete (($stepnum2 / $totalstep2) * 100)
                $dbinfo = New-Object -TypeName PSObject
                Add-Member -InputObject $dbinfo -MemberType NoteProperty -Name 'Instance'       -Value $inst.InstanceName
                Add-Member -InputObject $dbinfo -MemberType NoteProperty -Name 'Name'           -Value $database.Name
                Add-Member -InputObject $dbinfo -MemberType NoteProperty -Name 'Status'         -Value $database.Status
                Add-Member -InputObject $dbinfo -MemberType NoteProperty -Name 'SizeinMB'       -Value $database.Size
                Add-Member -InputObject $dbinfo -MemberType NoteProperty -Name 'RecoveryModel'  -Value $database.RecoveryModel
                Add-Member -InputObject $dbinfo -MemberType NoteProperty -Name 'LastFullBackup' -Value $database.LastBackupDate
                Add-Member -InputObject $dbinfo -MemberType NoteProperty -Name 'LastDiffBackup' -Value $database.LastDifferentialBackupDate
                Add-Member -InputObject $dbinfo -MemberType NoteProperty -Name 'LastLogBackup'  -Value $database.LastLogBackupDate
                Write-Verbose "Calculating the latest backup"
                $backups = @()
                $holder = New-Object -TypeName PSObject
                Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Type'           -Value "Full"
                Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Datetime'       -Value $database.LastBackupDate
                $backups += $holder                                                             
                $holder = New-Object -TypeName PSObject                                         
                Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Type'           -Value "Differential"
                Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Datetime'       -Value $database.LastDifferentialBackupDate
                $backups += $holder                                                             
                $holder = New-Object -TypeName PSObject                                         
                Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Type'           -Value "Log"
                Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Datetime'       -Value $database.LastLogBackupDate
                $backups += $holder
                $lastBackup = ($backups | Sort-Object -Property Datetime -Descending)[0]
                Add-Member -InputObject $dbinfo -MemberType NoteProperty -Name 'LastBackup'     -Value $lastBackup.Datetime
                Add-Member -InputObject $dbinfo -MemberType NoteProperty -Name 'LastBackupType' -Value $lastBackup.Type
                Write-Verbose "Detecting common issues"
                $Problem = "None"
                if ($database.RecoveryModel -ne "Simple" -and $database.LastLogBackupDate -lt $date.AddDays(-1)){ $Problem = "Database in $($database.RecoveryModel) recovery, but there are no log backups from the last day" }
                if ($lastBackup.Datetime    -lt $date.AddDays(-7))                                              { $Problem = "No Backups over the last week" }
                if ($lastBackup.Datetime    -eq "1/1/0001 12:00:00 AM")                                         { $Problem = "No Backups" }
                Add-Member -InputObject $dbinfo -MemberType NoteProperty -Name 'Issues' -Value $Problem
                Write-Verbose "Appending object to array"
                $databases += $dbinfo
            }
        }
    }
    
    end { 
        Write-Verbose "Outputting results"
        if ($RPO){ $databases | Where-Object { $_.LastBackup -lt $date.AddHours(-$RPO) } } else { $databases }
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

FUNCTION Get-SqlMaxMemory {
<#
.SYNOPSIS 
    Generates a value to be used for max memory
.DESCRIPTION
    Generates a value to be used for max memory (in MB) based on the total available RAM for the system.  Reserves 1 GB of RAM for the OS, 1 GB for each 4 GB of RAM installed from 4–16 GB, and then 1 GB for every 8 GB RAM installed above 16 GB RAM
.PARAMETER  RAM
    Requires the amount of RAM currently in the system, uses bytes if no unit is specified
.EXAMPLE
    PS C:\> Get-SqlMaxMemory -RAM 16GB
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/01
    Version     : 1
.LINK
    https://www.sqlskills.com/blogs/jonathan/how-much-memory-does-my-sql-server-actually-need/
.INPUTS
    [long]
.OUTPUTS
    [long]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory,HelpMessage="Amount of RAM in the system, uses bytes if no unit is specified",ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
        [long]$RAM
    )

    begin {
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
    }
 
    process {
        Write-Verbose "Starting with flat 1 GB reservation for OS"
        $os_memoryMB = 1024
        Write-Verbose "Converting $ram bytes to megabytes"  
        $total_memoryMB = $ram / 1MB
        if ($total_memoryMB -ge 4096) {
            Write-Verbose "Total RAM : $total_memoryMB`tMB -ge 4 GB"  
            $processed = 4096
            while ($processed -le $total_memoryMB){
                if ($processed -le 16384){
                    # Add 1 GB to reserve for every 4 GB installed between 4 and 16 GB
                    Write-Verbose "Processed : $processed`tMB -le 16 GB, adding 1 GB to OS reservation, adding 4 GB to processed"
                    $os_memoryMB += 1024
                    $processed   += 4096
                    if ($processed -gt $total_memoryMB){
                        # Add 1/4 GB per GB of total RAM % 4 GB
                        $overage = $processed - $total_memoryMB
                        $gap     = 4096 - $overage
                        if ($gap -gt 0){
                            $gap_os_memoryMB = $gap * (1024 / 4096)
                            $os_memoryMB    += $gap_os_memoryMB
                            Write-Verbose "Remainder : $gap`tMB, adding 1/4 GB for each 1 GB of remainder: $gap_os_memoryMB MB to OS reservation"
                        }
                    }
                } 
                else {
                    # Add 1 GB to reserve for every 8 GB installed over 16 GB
                    Write-Verbose "Processed : $processed`tMB -gt 16 GB, adding 1 GB to OS reservation, adding 8 GB to processed"
                    $os_memoryMB += 1024
                    $processed   += 8192
                    if ($processed -gt $total_memoryMB){
                        # Add 1/8 GB per GB of total RAM % 8 GB
                        $overage = $processed - $total_memoryMB
                        $gap     = 8192 - $overage
                        if ($gap -gt 0){
                            $gap_os_memoryMB = $gap * (1024 / 8192)
                            $os_memoryMB    += $gap_os_memoryMB
                            Write-Verbose "Remainder : $gap`tMB, adding 1/8 GB for each 1 GB of remainder: $gap_os_memoryMB MB to OS reservation"
                        }
                    }
                }
            }
            $sql_memoryMB = $total_memoryMB - $os_memoryMB
            Write-Verbose "Host RAM  : $os_memoryMB`tMB"
            Write-Verbose "SQL RAM   : $sql_memoryMB`tMB"
        }
        else {
            # Set reservation to all but 1GB for systems with < 4 GB
            Write-Verbose "Total RAM : $total_memoryMB MB -lt 4 GB.  No additional reservation for OS added"  
            $sql_memoryMB = $total_memoryMB - $os_memoryMB
            if ( $sql_memoryMB -lt 0 ){ $sql_memoryMB = 0 }
        }
        $sql_memoryMB
    }

    end { 
        Write-Verbose "Ending $($MyInvocation.Mycommand)"
        Remove-Variable sql_memoryMB -ErrorAction SilentlyContinue
    }
}

FUNCTION Get-SqlSecurity {
<#
.SYNOPSIS 
    Gets Security Information for SQL instances/databases
.DESCRIPTION
    Dependendencies  : SQLPS Module, SQL Server 2005+
    SQL Permissions  : sysadmin or maybe securityadmin on each instance

    Step 0     : Import SQLPS Module
    Step 1     : Pull list of SQL instances from [$inventoryinstance].[$inventorydatabase].[dbo].[SQLInstances]
    Step 2     : Connect to each of the pulled SQL instances
    Step 3     : Pull security information for each instance and write to CSV
    Step 4     : Write CSV report of aggregate data for all instances processed
.PARAMETER  Instance
    The name of the instance you wish to check connections to
.EXAMPLE
    PS C:\> Get-SqlSecurity -Instance DEV-MSSQL
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/16
    Version     : 2
.INPUTS
    [string]
.OUTPUTS
    [array]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage="Name of the instance(s) to check, leave off for all production instances")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
        [string[]]$Instance,
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Location to output CSV reports, leave off to only output an object")]
        [ValidateScript({Test-Path $_ -PathType Container})]
        [string]$ReportPath,
        [Parameter(Position=2,Mandatory=$false,HelpMessage="Returns an object with selected information (logins/users, role memberships, or explicit permissions)")]
        [ValidateSet("Security","Roles","Permissions")]
        [string]$Output
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $totalSecurity    = @()
        $totalRoleMembers = @()
        $totalPermissions = @()
        $date             = (get-date).ToString("yyyyMMdd_hhmmss")
        # This query returns all enabled databases on the instance
        $get_databases_query           = @"
SELECT [name] FROM sys.databases WHERE [state] = 0
"@
        # This query returns the server-level logins
        $get_serverSecurity_query      = @"
IF OBJECT_ID('tempdb..#InvalidLogins') IS NOT NULL
	DROP TABLE #InvalidLogins
CREATE TABLE #InvalidLogins ([SID] VARBINARY(85), [NT Login] sysname)
INSERT INTO #InvalidLogins
EXEC [sys].[sp_validatelogins]

SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], pe.[name] AS [UserName], sl.[name] AS [LoginName], pe.[type_desc] AS [UserType], CASE WHEN il.[sid] IS NULL THEN NULL ELSE 'Yes' END AS [Orphaned], NULL AS [DefaultSchema],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'CREATE LOGIN ' + QUOTENAME(pe.[name]) COLLATE database_default + CASE WHEN sl.[isntname] = 1 THEN ' FROM WINDOWS WITH DEFAULT_DATABASE=' + QUOTENAME(pe.[default_database_name]) COLLATE database_default ELSE ' WITH PASSWORD=N''CHANGEME'' MUST_CHANGE, DEFAULT_DATABASE=' + QUOTENAME(pe.[default_database_name]) COLLATE database_default + ', CHECK_EXPIRATION=ON, CHECK_POLICY=ON' END AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'DROP LOGIN '   + QUOTENAME(pe.[name]) COLLATE database_default AS [DropTSQL]
FROM master.sys.server_principals AS pe
LEFT JOIN master.sys.syslogins AS sl ON pe.[sid] = sl.[sid]
LEFT JOIN #InvalidLogins AS il ON pe.[sid] = il.[sid]
WHERE pe.[type] IN ('U', 'S', 'G')
ORDER BY [UserType], [UserName]
"@
        # This query returns the database-level users
        $get_databaseSecurity_query    = @"
-- Users and Groups
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], pe.[name] AS [UserName], sl.[name] AS [LoginName], pe.[type_desc] AS [UserType], CASE WHEN sl.[sid] IS NULL THEN 'True' ELSE 'False' END AS [Orphaned], pe.[default_schema_name] AS [DefaultSchema], 
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'CREATE USER ' + QUOTENAME(pe.[name]) COLLATE database_default + ' FOR LOGIN ' + QUOTENAME(sl.[name]) COLLATE database_default + CASE WHEN pe.[default_schema_name] IS NULL THEN '' ELSE ' WITH DEFAULT_SCHEMA = ' + QUOTENAME(pe.[default_schema_name]) COLLATE database_default END AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'DROP USER '   + QUOTENAME(pe.[name]) COLLATE database_default AS [DropTSQL]
FROM sys.database_principals AS pe
LEFT JOIN master.sys.syslogins AS sl ON pe.[sid] = sl.[sid]
WHERE pe.[type] IN ('U', 'S', 'G')
UNION ALL
-- Roles
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], [name] AS [UserName], NULL AS [LoginName], 'Role' AS [UserType], NULL AS [Orphaned], default_schema_name AS [DefaultSchema], 
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'CREATE ROLE '+ QUOTENAME([name]) COLLATE database_default AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'DROP ROLE '  + QUOTENAME([name]) COLLATE database_default AS [DropTSQL]
FROM sys.database_principals
WHERE [principal_id] > 4 
AND [is_fixed_role] <> 1
AND [type] = 'R'
ORDER BY [UserType], [UserName]
"@
        # This query returns the server role memberships
        $get_serverRoleMembers_query   = @"
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], spr.[name] AS [RoleName], spm.[name] AS [UserName], spm.[type_desc] AS [UserType], 
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_addsrvrolemember @rolename = '  + QUOTENAME(spr.[name], '''') COLLATE database_default + ', @membername = ' + QUOTENAME(spm.[name], '''') COLLATE database_default AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_dropsrvrolemember @rolename = ' + QUOTENAME(spr.[name], '''') COLLATE database_default + ', @membername = ' + QUOTENAME(spm.[name], '''') COLLATE database_default AS [DropTSQL]
FROM master.sys.server_role_members AS srm
JOIN master.sys.server_principals AS spr ON srm.[role_principal_id] = spr.[principal_id]
JOIN master.sys.server_principals AS spm ON srm.[member_principal_id] = spm.[principal_id]
ORDER BY [RoleName], [UserName]
"@
        # This query returns the database role memberships
        $get_databaseRoleMembers_query = @"
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], USER_NAME(rm.role_principal_id) AS [RoleName], USER_NAME(rm.member_principal_id) AS [UserName], pe.[type_desc] AS [UserType], 
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_addrolemember @rolename = '  + QUOTENAME(USER_NAME(rm.[role_principal_id]), '''') COLLATE database_default + ', @membername = ' + QUOTENAME(USER_NAME(rm.[member_principal_id]), '''') COLLATE database_default AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_droprolemember @rolename = ' + QUOTENAME(USER_NAME(rm.[role_principal_id]), '''') COLLATE database_default + ', @membername = ' + QUOTENAME(USER_NAME(rm.[member_principal_id]), '''') COLLATE database_default AS [DropTSQL]
FROM sys.database_role_members AS rm
LEFT JOIN sys.database_principals AS pe ON rm.[member_principal_id] = pe.[principal_id]
ORDER BY [RoleName], [UserName]
"@
        # This query returns the server explicit permissions
        $get_serverPermissions_query   = @"
-- Server Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], 'Instance-Level Server Permission' AS [ObjectName], NULL AS [Detail], pr.[name] AS [UserName], pr.[type_desc] AS [UserType], USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE [master]; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE [master]; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.server_permissions AS pe
INNER JOIN sys.server_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
WHERE pe.[class] = 100
UNION ALL
-- Endpoint Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], 'Instance-Level Endpoint Permission' AS [ObjectName], ep.[name] AS [Detail], pr.[name] AS [UserName], pr.[type_desc] AS [UserType], USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE [master]; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' ON ENDPOINT::' + QUOTENAME(ep.[name]) COLLATE database_default + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE [master]; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' ON ENDPOINT::' + QUOTENAME(ep.[name]) COLLATE database_default + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.server_permissions AS pe
INNER JOIN sys.server_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
INNER JOIN sys.endpoints AS ep on pe.[major_id] = ep.[endpoint_id]
WHERE pe.[class] = 105
UNION ALL
-- Server-Principle Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], 'Instance-Level Server-Principle Permission' AS [ObjectName], pr2.[name] AS [Detail], pr.[name] AS [UserName], pr.[type_desc] AS [UserType], USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE [master]; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' ON LOGIN::' + QUOTENAME(pr2.[name]) COLLATE database_default + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE [master]; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' ON LOGIN::' + QUOTENAME(pr2.[name]) COLLATE database_default + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS ' + QUOTENAME(pr.[name]) COLLATE database_default AS [RevokeTSQL]
FROM sys.server_permissions AS pe
INNER JOIN sys.server_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
INNER JOIN sys.server_principals AS pr2 ON pe.[major_id] = pr2.[principal_id]
WHERE pe.[class] = 101
ORDER BY [ObjectName],[Permission],[UserName]
"@
        # This query returns the database explicit permissions
        $get_databasePermissions_query = @"
-- Database Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], 'Database-Level Permission' AS [ObjectName], NULL AS [Detail], USER_NAME(pr.[principal_id]) AS UserName, pr.[type_desc] AS [UserType],  USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
WHERE pe.[class] = 0
UNION ALL
-- Object Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], SCHEMA_NAME(o.[schema_id]) + '.' + o.[name] AS [ObjectName], cl.[name] AS [Detail], USER_NAME(pr.[principal_id]) AS UserName, pr.[type_desc] AS [UserType],  USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + '.' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '' ELSE '(' + QUOTENAME(cl.[name]) COLLATE database_default + ')' END + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + '.' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '' ELSE '(' + QUOTENAME(cl.[name]) COLLATE database_default + ')' END + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.objects AS o ON pe.[major_id] = o.[object_id]
INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
LEFT JOIN sys.columns AS cl ON cl.column_id = pe.[minor_id] AND cl.[object_id] = pe.[major_id]
WHERE pe.[class] = 1
UNION ALL
-- Schema Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], pe.[class_desc] + '::' COLLATE database_default + QUOTENAME(SCHEMA_NAME(pe.[major_id])) AS [ObjectName], NULL AS [Detail], USER_NAME(pe.[grantee_principal_id]) AS UserName, pr.[type_desc] AS [UserType],  USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' ON ' + pe.[class_desc] + '::' + QUOTENAME(SCHEMA_NAME(pe.[major_id])) COLLATE database_default + ' TO ' + QUOTENAME(USER_NAME(pe.[grantee_principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' ON ' + pe.[class_desc] + '::' + QUOTENAME(SCHEMA_NAME(pe.[major_id])) COLLATE database_default + ' TO ' + QUOTENAME(USER_NAME(pe.[grantee_principal_id])) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.schemas s ON pe.[major_id] = s.[schema_id]
INNER JOIN sys.database_principals pr ON pe.[grantee_principal_id] = pr.[principal_id]
WHERE pe.[class] = 3
UNION ALL
-- Other Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], SCHEMA_NAME(o.[schema_id]) + '.' + o.[name] AS [ObjectName], cl.[name] AS [Detail], USER_NAME(pr.[principal_id]) AS UserName, pr.[type_desc] AS [UserType],  USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + '.' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '' ELSE '(' + QUOTENAME(cl.[name]) COLLATE database_default + ')' END + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + '.' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '' ELSE '(' + QUOTENAME(cl.[name]) COLLATE database_default + ')' END + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.objects AS o ON pe.[major_id] = o.[object_id]
INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
LEFT JOIN sys.columns AS cl ON cl.column_id = pe.[minor_id] AND cl.[object_id] = pe.[major_id]
WHERE pe.[class] > 3
ORDER BY [Permission], [ObjectName], [UserName]
"@
    }
 
    process {
        if ($instance){
            $instances  = @()
            foreach ($inst in $instance){
                Write-Verbose "Adding $inst to processing array..."
                $version    = Invoke-Sqlcmd -ServerInstance $inst -query "SELECT SERVERPROPERTY('ProductVersion') AS [SQLBuildNumber]" -connectiontimeout 5
                $holder     = New-Object -TypeName PSObject
                Add-Member -InputObject $holder -MemberType NoteProperty -Name 'InstanceName'   -Value $inst
                Add-Member -InputObject $holder -MemberType NoteProperty -Name 'SQLBuildNumber' -Value $version.SQLBuildNumber
                $instances += $holder
            }
        }
        else {
            # Pull all SQL instances from Server Inventory
            Write-Progress -Activity "Pulling instances..." -Status "Percent Complete: 0%" -PercentComplete 0
            $instances = Get-SqlInstances
        }
        $totalstep = ($instances.Count * 4) + 1
        $stepnum   = 0
        # Loop through each instance
        foreach ($inst in $instances){
            $instancename  = $inst.InstanceName
            $instancebuild = $inst.SQLBuildNumber
            Write-Verbose "Checking $instancename for compatibility..."
            $stepnum++
            Write-Progress -Activity "Processing $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
            # Breaks the full build number down into just the major build (first decimal)
            $instancebuild = [Decimal]$instancebuild.Remove(($instancebuild | select-string "\." -allmatches).matches[1].Index, $instancebuild.Length - ($instancebuild | select-string "\." -allmatches).matches[1].Index)
            # Writes error for instances that are < 2005
            if ($instancebuild -lt 9){ Write-Error -Category InvalidOperation -Message "SQL version  of $instancename - $instancebuild not supported" -TargetObject $instancename  } 
            else {
                Write-Verbose "Processing $instancename..."
                Write-Verbose "Initializing arrays for $instancename..."
                $security    = @()
                $roleMembers = @()
                $permissions = @()
                $stepnum++
                Write-Progress -Activity "Running server-level queries against $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
                # Runs server-level queries
                Write-Verbose "Retrieving databases for $instancename..."
                $databases    = Invoke-Sqlcmd -serverinstance $instancename -query $get_databases_query         -connectiontimeout 5
                Write-Verbose "Retrieving server logins for $instancename..."
                $security    += Invoke-Sqlcmd -serverinstance $instancename -query $get_serverSecurity_query    -connectiontimeout 5
                Write-Verbose "Retrieving server role membership for $instancename..."
                $roleMembers += Invoke-Sqlcmd -serverinstance $instancename -query $get_serverRoleMembers_query -connectiontimeout 5
                Write-Verbose "Retrieving server permissions for $instancename..."
                $permissions += Invoke-Sqlcmd -serverinstance $instancename -query $get_serverPermissions_query -connectiontimeout 5
                $stepnum++
                Write-Progress -Activity "Running database-level queries against $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
                # Runs database-level queries
                foreach ($database in $databases){
                    Write-Verbose "Retrieving database users for $instancename.$($database.name)..."
                    $security    += Invoke-Sqlcmd -serverinstance $instancename -database $database.name -query $get_databaseSecurity_query    -connectiontimeout 5
                    Write-Verbose "Retrieving database role membership for $instancename.$($database.name)..."
                    $roleMembers += Invoke-Sqlcmd -serverinstance $instancename -database $database.name -query $get_databaseRoleMembers_query -connectiontimeout 5
                    Write-Verbose "Retrieving database permissions for $instancename.$($database.name)..."
                    $permissions += Invoke-Sqlcmd -serverinstance $instancename -database $database.name -query $get_databasePermissions_query -connectiontimeout 5
                }
                $stepnum++
                Write-Progress -Activity "Outputting/appending results for $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
                # Writes output to CSVs if specified
                if ($reportPath){
                    $instancename = $instancename -replace "\\","_"
                    Write-Verbose "Creating directory for $instancename in $reportPath..."
                    New-Item -ItemType Directory -Force -Path "$reportPath\$instancename" > $null
                    Write-Verbose "Generating file names..."
                    $securityReportPath    = $reportPath + '\' + $instancename + '\' + $instancename + '_SecurityPrinciples_'  + $date + '.csv'
                    $roleMembersReportPath = $reportPath + '\' + $instancename + '\' + $instancename + '_RoleMemberships_'     + $date + '.csv'
                    $permissionsReportPath = $reportPath + '\' + $instancename + '\' + $instancename + '_ExplicitPermissions_' + $date + '.csv'
        
                    Write-Verbose "Exporting security results for $instancename to $securityReportPath..."
                    $security    | Export-Csv -Path $securityReportPath    -NoTypeInformation
                    Write-Verbose "Exporting role membership results for $instancename to $securityReportPath..."
                    $roleMembers | Export-Csv -Path $roleMembersReportPath -NoTypeInformation
                    Write-Verbose "Exporting permissions results for $instancename to $securityReportPath..."
                    $permissions | Export-Csv -Path $permissionsReportPath -NoTypeInformation
                }
                Write-Verbose "Appending aggregate array with $instancename results..."
                $totalSecurity    += $security
                $totalRoleMembers += $roleMembers
                $totalPermissions += $permissions
            }    
        }
    }

    end { 
        $stepnum++
        Write-Progress -Activity "Outputting/returning results..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
        if ($reportPath){
            Write-Verbose "Generating aggregate file names..."
            $securityReportPath    = $reportPath + '\SecurityPrinciples_'  + $date + '.csv'
            $roleMembersReportPath = $reportPath + '\RoleMemberships_'     + $date + '.csv'
            $permissionsReportPath = $reportPath + '\ExplicitPermissions_' + $date + '.csv'
            # Writes output to CSVs if specified
            Write-Verbose "Exporting aggregate security results to $securityReportPath..."
            $totalSecurity    | Export-Csv -Path $securityReportPath    -NoTypeInformation
            Write-Verbose "Exporting aggregate role membership results to $securityReportPath..."
            $totalRoleMembers | Export-Csv -Path $roleMembersReportPath -NoTypeInformation
            Write-Verbose "Exporting aggregate permissions results to $securityReportPath..."
            $totalPermissions | Export-Csv -Path $permissionsReportPath -NoTypeInformation
        }
        elseif ($output){
            $output = $output.ToLower()
            switch ($output){
                "security"    { $totalSecurity    }
                "roles"       { $totalRoleMembers }
                "permissions" { $totalPermissions }
            }
        }
        else { Write-Output "Specify an output source (report path or output type) and re-run" }
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

FUNCTION Import-SQLPS {
<#
.SYNOPSIS 
    Imports the SQLPS module with error checking
.DESCRIPTION
    Imports the SQLPS module if it is not already loaded, with a basic try-catch-throw to avoid executing the rest of a script as well as avoiding changing the path to SQLSERVER:\
.EXAMPLE
    PS C:\> Import-SQLPS
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/18
    Version     : 1
.INPUTS
    [string]
#>
    [CmdletBinding()]
    Param()
 
    begin {
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
    }
 
    process {
        if (!(Get-Module -Name sqlps)){ 
            try { 
                Write-Verbose "Trying to import SQLPS module"
                Push-Location
                Import-Module -Name sqlps -DisableNameChecking -ErrorAction Stop
                Pop-Location 
            } 
            catch { throw $_.Exception.GetBaseException().Message } 
        }
        else { Write-Verbose "SQLPS module already loaded" }
    }
    
    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}

FUNCTION New-ServerInventoryServer {
<# 
.SYNOPSIS 
    Adds a Server the Server Inventory for SQL Instances
.DESCRIPTION 
    Dependendencies  : SQLPS Module
    SQL Permissions  : Read/Write on [$inventoryinstance].[$inventorydatabase]
.PARAMETER  InventoryInstance
	The name of the instance the inventory database is on
.PARAMETER  InventoryDatabase
	The name of the database the inventory tables are in
.PARAMETER  ServerName
	The name of the server you are adding
.PARAMETER  InstanceName
	The name of the instance if adding a SQL Server.  Leave off for default instances
.PARAMETER  Domain
	The name of domain the server is one.  Defaults to manning-napier.com
.PARAMETER  Environment
	The name of the environment the server is in - Development, Test, or Production
.PARAMETER  OperatingSystem
	The OS of the server
.PARAMETER  OSVersion
	The version of the OS of the server
.PARAMETER  ServerType
	The type of server, pulls from dbo.ServerType
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/10/23
    Version     : 1
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
	    [string]$InventoryDatabase = 'ServerInventory',        
        [Parameter(Position=2,Mandatory=$true,HelpMessage="Name of the server")]
        [ValidateNotNullorEmpty()]
	    [string]$ServerName,
        [Parameter(Position=3,Mandatory=$false,HelpMessage="Name of the instance, not required for default instances")]
        [ValidateNotNullorEmpty()]
	    [string]$InstanceName = 'Default Instance',
        [Parameter(Position=5,Mandatory=$true,HelpMessage="Domain of server")]
        [ValidateSet('manning-napier.com','Standalone','2100Capital.com')]
	    [string]$Domain = 'manning-napier.com',
        [Parameter(Position=6,Mandatory=$true,HelpMessage="Environment of server")]
        [ValidateSet('Development','Test','Production')]
	    [string]$Environment,
        [Parameter(Position=7,Mandatory=$true,HelpMessage="Operating system of server")]
        [ValidateSet('Server 2008 R2','Server 2012','Server 2012 R2')]
	    [string]$OperatingSystem,
        [Parameter(Position=8,Mandatory=$true,HelpMessage="Operating system version of server")]
        [ValidateSet('Standard','Enterprise','Datacenter')]
	    [string]$OSEdition
    )
    DynamicParam {
        Import-SQLPS
        $servertypes = (Invoke-Sqlcmd -ServerInstance $InventoryInstance -Database $InventoryDatabase -Query "SELECT [Type] FROM [dbo].[ServerType]" -ConnectionTimeout 5 -ErrorAction Stop).Type

		# Reusable parameter setup
		$newparams  = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
		$attributes = New-Object System.Management.Automation.ParameterAttribute
		
		$attributes.ParameterSetName = "__AllParameterSets"
		$attributes.Mandatory = $true
		
		# Database list parameter setup
		if ($servertypes) { $stvalidationset = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $servertypes }
		$stattributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
		$stattributes.Add($attributes)
		if ($servertypes) { $stattributes.Add($stvalidationset) }
		$servertypesobj = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("ServerType", [String], $stattributes)
		
		$newparams.Add("ServerType", $servertypesobj)	
	
	    return $newparams
    }

    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
    }

    process {
        Write-Verbose "Converting server type into ID"
        $servertypeid = (Invoke-Sqlcmd -ServerInstance $InventoryInstance -Database $InventoryDatabase -Query "SELECT [TypeID] FROM [dbo].[ServerType] WHERE [Type] = '$($PSBoundParameters.ServerType)'" -ConnectionTimeout 5 -ErrorAction Stop).TypeID
        $server_insert_query   = "INSERT INTO [dbo].[Servers] (TypeID, Name, Domain, Environment, OS, OSEdition) VALUES ($servertypeid,'$servername','$domain','$environment','$operatingsystem','$osedition')"
        Write-Verbose "Inserting server information: $server_insert_query"
        Invoke-Sqlcmd -ServerInstance $InventoryInstance -Database $InventoryDatabase -Query $server_insert_query -ConnectionTimeout 5 -ErrorAction Stop
        $serverid = (Invoke-Sqlcmd -ServerInstance $InventoryInstance -Database $InventoryDatabase -Query "SELECT [ServerID] FROM [ServerInventory].[dbo].[Servers] WHERE [Name] = '$servername'" -ConnectionTimeout 5 -ErrorAction Stop).ServerID
        $instance_insert_query = "INSERT INTO [ServerInventory].[dbo].[SQLInstances] (ServerID,Name,Code) VALUES ($serverid,'$instancename',2)"
        Write-Verbose "Inserting instance information: $instance_insert_query"
        Invoke-Sqlcmd -ServerInstance $InventoryInstance -Database $InventoryDatabase -Query $instance_insert_query -ConnectionTimeout 5 -ErrorAction Stop
    }
    
    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}

FUNCTION Start-SqlAgentJob {
<#
.SYNOPSIS 
    Starts a SQL agent job
.DESCRIPTION
    Dependendencies  : SQL Server SMO
    SQL Permissions  : Ability to execute the job
.PARAMETER  Instance
    The name of the instance you wish to start the job on
.PARAMETER  Job
    The name of the job you wish to start
.EXAMPLE
    PS C:\> Start-SqlAgentJob -Instance DEV-MSSQL -Job "Test Job"
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/17
    Version     : 2
.INPUTS
    [string]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage="Name of the instance the job is on")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
        [string]$Instance
    )
    DynamicParam {
        if ($instance){
            Import-SQLPS
            $server = New-Object Microsoft.SqlServer.Management.Smo.Server $instance
            $server.ConnectionContext.ConnectTimeout = 2
            try { $server.ConnectionContext.Connect() } catch { return }
	
            # Populate array
            $agentjoblist = @()
            foreach ($agentjob in $server.JobServer.Jobs){ $agentjoblist += $agentjob.name }

            # Reusable parameter setup
            $newparams  = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $attributes = New-Object System.Management.Automation.ParameterAttribute
		
            $attributes.ParameterSetName = "__AllParameterSets"
            $attributes.Mandatory = $true
		
            # Database list parameter setup
            if ($agentjoblist) { $ajvalidationset = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $agentjoblist }
            $ajattributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
            $ajattributes.Add($attributes)
            if ($agentjoblist) { $ajattributes.Add($ajvalidationset) }
            $agentjobs = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("Job", [String], $ajattributes)
		
            $newparams.Add("Job", $agentjobs)			
            $server.ConnectionContext.Disconnect()
	
            return $newparams
        }
    }
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $error = $false
    }
 
    process {
        # Set up SMO server object to pull data from
        Write-Verbose "Setting up SMO for $instance"
        $srv = New-Object "Microsoft.SqlServer.Management.Smo.Server" $instance
        $job = $srv.JobServer.Jobs[$PSBoundParameters.Job]
        Write-Verbose "Checking for job named $($PSBoundParameters.Job)"
        if ($job.Name -eq $null){ Write-Error "$($PSBoundParameters.Job) does not exist" -Category InvalidArgument }
        else { 
            Write-Verbose "Trying to start job"
            try   { $job.Start() } 
            catch { 
                $error = $true 
                Write-Error $_.Exception.GetBaseException().Message -Category InvalidOperation
            }
            if (!$error){
                Write-Verbose "Starting timer"
                $elapsedTime = [system.diagnostics.stopwatch]::StartNew()
                Write-Verbose "Waiting for job status to change from executing"
                do {
                    Start-Sleep -Seconds 1
                    $job.Refresh()
                    Write-Progress -Activity "Executing $($PSBoundParameters.Job) on $instance..." -Status "$([string]::Format("Time Elapsed: {0:d2}:{1:d2}:{2:d2}", $elapsedTime.Elapsed.hours, $elapsedTime.Elapsed.minutes, $elapsedTime.Elapsed.seconds))"
                } while ($job.CurrentRunStatus -eq 'Executing')
                $elapsedTime.stop()
                $seconds = [int]$elapsedTime.Elapsed.TotalSeconds
                Write-Output "$($PSBoundParameters.Job) completed with status: $($job.LastRunOutcome) on $($job.LastRunDate) after ~$seconds seconds."
            }
        }
    }
    
    end { 
        $srv.ConnectionContext.Disconnect()
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

FUNCTION Test-SqlConnection {
<#
.SYNOPSIS 
    Test connection to SQL Instance
.DESCRIPTION
    Test connection to SQL Instance
.PARAMETER  Instance
    The name of the instance you wish to check connections to
.EXAMPLE
    PS C:\> Test-SQLConnection -Instance DEV-MSSQL
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/01
    Version     : 1
.INPUTS
    [string]
.OUTPUTS
    [boolean]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage="The name of the instance")]
        [ValidateNotNullorEmpty()]
        [string]$Instance
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
    }
 
    process {
        $srv = New-Object "Microsoft.SqlServer.Management.Smo.Server" $instance
        $srv.ConnectionContext.ConnectTimeout = 5
        try {
            Write-Verbose "Trying to connect to $instance"
            # Try and connect to server
            $srv.ConnectionContext.Connect()
            Write-Verbose "Connection successful! Disconnecting from $instance"
            $srv.ConnectionContext.Disconnect()
            return $true
        }
        catch { 
            Write-Verbose "Could not connect to $instance"
            return $false 
        }
    }
    
    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}

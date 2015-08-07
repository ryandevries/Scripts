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
        [Parameter(Position=1,Mandatory,HelpMessage="Name of the config value to check")]
        [ValidateSet("%","access check cache bucket count","access check cache quota","Ad Hoc Distributed Queries","affinity I/O mask","affinity mask","affinity64 I/O mask","affinity64 mask","Agent XPs","allow updates","backup compression default","blocked process threshold (s)","c2 audit mode","clr enabled","contained database authentication","cost threshold for parallelism","cross db ownership chaining","cursor threshold","Database Mail XPs","default full-text language","default language","default trace enabled","disallow results from triggers","filestream access level","fill factor (%)","ft crawl bandwidth (max)","ft crawl bandwidth (min)","ft notify bandwidth (max)","ft notify bandwidth (min)","index create memory (KB)","in-doubt xact resolution","lightweight pooling","locks","max degree of parallelism","max full-text crawl range","max server memory (MB)","max text repl size (B)","max worker threads","media retention","min memory per query (KB)","min server memory (MB)","nested triggers","network packet size (B)","Ole Automation Procedures","open objects","optimize for ad hoc workloads","PH timeout (s)","precompute rank","priority boost","query governor cost limit","query wait (s)","recovery interval (min)","remote access","remote admin connections","remote login timeout (s)","remote proc trans","remote query timeout (s)","Replication XPs","scan for startup procs","server trigger recursion","set working set size","show advanced options","SMO and DMO XPs","transform noise words","two digit year cutoff","user connections","user options","xp_cmdshell")]
        [string]$Config,
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
DECLARE @config_defaults TABLE (name nvarchar(35), default_value sql_variant)
INSERT INTO @config_defaults (name, default_value) VALUES ('access check cache bucket count',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('access check cache quota',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('Ad Hoc Distributed Queries',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('affinity I/O mask',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('affinity mask',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('affinity64 I/O mask',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('affinity64 mask',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('Agent XPs',1)
INSERT INTO @config_defaults (name, default_value) VALUES ('allow updates',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('awe enabled',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('backup compression default',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('blocked process threshold (s)',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('c2 audit mode',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('clr enabled',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('common criteria compliance enabled',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('cost threshold for parallelism',5)
INSERT INTO @config_defaults (name, default_value) VALUES ('cross db ownership chaining',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('cursor threshold',-1)
INSERT INTO @config_defaults (name, default_value) VALUES ('Database Mail XPs',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('default full-text language',1033)
INSERT INTO @config_defaults (name, default_value) VALUES ('default language',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('default trace enabled',1)
INSERT INTO @config_defaults (name, default_value) VALUES ('disallow results from triggers',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('EKM provider enabled',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('filestream access level',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('fill factor (%)',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('ft crawl bandwidth (max)',100)
INSERT INTO @config_defaults (name, default_value) VALUES ('ft crawl bandwidth (min)',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('ft notify bandwidth (max)',100)
INSERT INTO @config_defaults (name, default_value) VALUES ('ft notify bandwidth (min)',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('index create memory (KB)',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('in-doubt xact resolution',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('lightweight pooling',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('locks',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('max degree of parallelism',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('max full-text crawl range',4)
INSERT INTO @config_defaults (name, default_value) VALUES ('max server memory (MB)',2147483647)
INSERT INTO @config_defaults (name, default_value) VALUES ('max text repl size (B)',65536)
INSERT INTO @config_defaults (name, default_value) VALUES ('max worker threads',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('media retention',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('min memory per query (KB)',1024)
INSERT INTO @config_defaults (name, default_value) VALUES ('min server memory (MB)',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('nested triggers',1)
INSERT INTO @config_defaults (name, default_value) VALUES ('network packet size (B)',4096)
INSERT INTO @config_defaults (name, default_value) VALUES ('Ole Automation Procedures',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('open objects',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('optimize for ad hoc workloads',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('PH timeout (s)',60)
INSERT INTO @config_defaults (name, default_value) VALUES ('precompute rank',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('priority boost',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('query governor cost limit',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('query wait (s)',-1)
INSERT INTO @config_defaults (name, default_value) VALUES ('recovery interval (min)',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('remote access',1)
INSERT INTO @config_defaults (name, default_value) VALUES ('remote admin connections',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('remote login timeout (s)',20)
INSERT INTO @config_defaults (name, default_value) VALUES ('remote proc trans',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('remote query timeout (s)',600)
INSERT INTO @config_defaults (name, default_value) VALUES ('Replication XPs',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('scan for startup procs',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('server trigger recursion',1)
INSERT INTO @config_defaults (name, default_value) VALUES ('set working set size',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('show advanced options',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('SMO and DMO XPs',1)
INSERT INTO @config_defaults (name, default_value) VALUES ('SQL Mail XPs',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('transform noise words',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('two digit year cutoff',2049)
INSERT INTO @config_defaults (name, default_value) VALUES ('user connections',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('user options',0)
INSERT INTO @config_defaults (name, default_value) VALUES ('xp_cmdshell',0)
SELECT @@SERVERNAME AS [ServerName], c.[name] AS [ConfigName], [Description], CONVERT(INT, ISNULL([value], [value_in_use])) AS [ConfigValue], d.[default_value] AS [DefaultValue]
FROM [sys].[configurations] c JOIN @config_defaults d on c.[name] = d.[name] WHERE c.[name] LIKE '$config'
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
                }
                while ($job.CurrentRunStatus -eq 'Executing')
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


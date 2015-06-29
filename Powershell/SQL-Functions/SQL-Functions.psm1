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

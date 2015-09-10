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
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES (NULL,'common criteria compliance enabled',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1538','cost threshold for parallelism',5)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('400','cross db ownership chaining',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1531','cursor threshold',-1)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('16386','Database Mail XPs',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1126','default full-text language',1033)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('124','default language',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('1568','default trace enabled',1)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES ('114','disallow results from triggers',0)
INSERT INTO ##config_defaults (configuration_id, name, default_value) VALUES (NULL,'EKM provider enabled',0)
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

SET @CONFIGS_PRESQL20008_TSQL  = 'SELECT @@SERVERNAME AS [ServerName], d.[name] AS [ConfigName], c.[comment] AS [Description], CONVERT(INT, [value]) AS [ConfigValue], d.[default_value] AS [DefaultValue] FROM [dbo].[sysconfigures] c JOIN ##config_defaults d on c.[config] = d.[configuration_id] WHERE d.[name] LIKE ''$config'''
SET @CONFIGS_POSTSQL20008_TSQL = 'SELECT @@SERVERNAME AS [ServerName], d.[name] AS [ConfigName], [Description], CONVERT(INT, ISNULL([value], [value_in_use])) AS [ConfigValue], d.[default_value] AS [DefaultValue] FROM [sys].[configurations] c JOIN ##config_defaults d on c.[configuration_id] = d.[configuration_id] WHERE d.[name] LIKE ''$config'''

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

# Blogged
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

FUNCTION Write-SqlChangeLog {
<#
.SYNOPSIS 
    Writes an entry into the SQL change log
.DESCRIPTION
	Writes an entry into the SQL change log with a specified server, instance, and change
.PARAMETER  DateTime
	The date and time of the change, auto sets to current date and time if not specified
.PARAMETER  Server
	Requires the server the change was made on
.PARAMETER  Instance
	The instance the change was made on, leave unspecified if the change was at the server level
.EXAMPLE
    PS C:\> Write-SqlChangeLog -DateTime '6/4/2015 11:44AM' -Server Utility-DB -Instance 'Default Instance' -Change 'Created change log table'
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/04
    Version     : 1
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,HelpMessage="Date and time the change was made")]
        [datetime]$DateTime = $([DateTime]::Now),
        [Parameter(Position=4,Mandatory=$false,HelpMessage="The SupportDesk ticket for the change")]
        [ValidateNotNullorEmpty()]
        [string]$Ticket,
        [Parameter(Position=5,Mandatory,HelpMessage="A short description of the change that was made")]
        [ValidateNotNullorEmpty()]
        [string]$Change
    )
    DynamicParam {
        Import-SQLPS
        $inventoryinstance = 'utility-db'
        $newparams         = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $server_query      = 'SELECT [Name] FROM [ServerInventory].[dbo].[Servers] WHERE [TypeID] = 1 ORDER BY [Name]'
        $instance_query    = "SELECT s.[Name] + CASE si.[Name] WHEN 'Default Instance' THEN '' ELSE '\' + si.[Name] END AS [Name] FROM [ServerInventory].[dbo].[SQLInstances] si JOIN [ServerInventory].[dbo].[Servers] s ON si.[ServerID] = s.[ServerID] ORDER BY [Name]"
        $database_query    = "SELECT DISTINCT [Name] FROM [ServerInventory].[dbo].[SQLDatabases] ORDER BY [Name]"
        $servers           = Invoke-Sqlcmd -serverinstance $inventoryinstance -query $server_query   -connectiontimeout 5
        $instances         = Invoke-Sqlcmd -serverinstance $inventoryinstance -query $instance_query -connectiontimeout 5
        $databases         = Invoke-Sqlcmd -serverinstance $inventoryinstance -query $database_query -connectiontimeout 5
        $serverlist        = @()
        $instancelist      = @()
        $databaselist      = @()
        # Populate arrays
        foreach ($servername   in $servers.Name)  { $serverlist += $servername      }
        foreach ($instancename in $instances.Name){ $instancelist += $instancename	}
        foreach ($databasename in $databases.Name){ $databaselist += $databasename	}
        # Server parameter attribute setup		
        $attributes = New-Object System.Management.Automation.ParameterAttribute
        $attributes.ParameterSetName = "__AllParameterSets"
        $attributes.Position         = 1
        $attributes.Mandatory        = $true
        $attributes.HelpMessage      = "The server the change was made on"
        # Server list parameter setup
        if ($serverlist){ $servervalidationset = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $serverlist }
        $serverattributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $serverattributes.Add($attributes)
        if ($serverlist){ $serverattributes.Add($servervalidationset) }
        $server = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("Server", [String], $serverattributes)
        $newparams.Add("Server", $server)
        # Instance parameter attribute setup	
        $attributes = New-Object System.Management.Automation.ParameterAttribute
        $attributes.ParameterSetName = "__AllParameterSets"
        $attributes.Position         = 2
        $attributes.Mandatory        = $false
        $attributes.HelpMessage      = "The instance the change was made on, do not specify for server-level changes"
        # Instance list parameter setup
        if ($instancelist){ $instancevalidationset = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $instancelist }
        $instanceattributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $instanceattributes.Add($attributes)
        if ($instancelist){ $instanceattributes.Add($instancevalidationset) }
        $instanceob = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("Instance", [String], $instanceattributes)
        $newparams.Add("Instance", $instanceob)
        # Database parameter attribute setup	
        $attributes = New-Object System.Management.Automation.ParameterAttribute
        $attributes.ParameterSetName = "__AllParameterSets"
        $attributes.Position         = 3
        $attributes.Mandatory        = $false
        $attributes.HelpMessage      = "The database the change was made on, do not specify for server-level changes"
        # Database list parameter setup
        if ($databaselist){ $databasevalidationset = New-Object System.Management.Automation.ValidateSetAttribute -ArgumentList $databaselist }
        $databaseattributes = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $databaseattributes.Add($attributes)
        if ($databaselist){ $databaseattributes.Add($databasevalidationset) }
        $databaseob = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("Database", [String], $databaseattributes)
        $newparams.Add("Database", $databaseob) 
        
        return $newparams
    }

    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $inventoryinstance = 'utility-db'
        $server            = $PSBoundParameters.Server
        $instance          = $PSBoundParameters.Instance        
        $database          = $PSBoundParameters.Database
        $change            = $change -replace "'","''"
    }
 
    process {
        
        if ($instance){ 
            Write-Verbose $instance
            $instance = $instance -replace ($server + "\\"),""
            $instance = $instance -replace $server,"Default Instance"
            Write-Verbose $instance
        }
        else { $instance = 'Server-Level' }
        if ($database){ $database = "'" + $database + "'" } elseif ($instance -eq 'Server-Level') { $database = 'NULL' } else { $database = "'Instance-Level'" }
        if ($ticket)  { $ticket   = "'" + $ticket   + "'" } else  { $ticket = 'NULL' }
        $server        = "'" + $server       + "'"
        $instance      = "'" + $instance     + "'"
        $change        = "'" + $change       + "'"
        $username      = "'" + $env:USERNAME + "'"
        $datetimestr   = "'" + $datetime     + "'"       
        $insert_query  = "INSERT INTO [ServerInventory].[dbo].[SQLChangeLog] ([Timestamp], [User], [ServerName], [InstanceName], [DatabaseName], [Ticket], [Change]) VALUES ($datetimestr,$username,$server,$instance,$database,$ticket,$change)"
        Write-Verbose "Inserting row into [ServerInventory].[dbo].[SQLChangeLog] with Time: $datetimestr User: $username Server: $server Instance: $instance Database: $database Ticket: $ticket Change: $change"
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $insert_query -connectiontimeout 5
    }

    end { 
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

FUNCTION Get-SqlChangeLog {
<#
.SYNOPSIS 
    Reads entries from the SQL change log
.DESCRIPTION
	Reads entries from the SQL change log
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/24
    Version     : 1
#>
    [CmdletBinding()]
    Param()
    
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $inventoryinstance = 'utility-db'
        $select_query      = "SELECT [TimeStamp], [User], [ServerName] AS Server, [InstanceName] AS Instance, [DatabaseName] AS [Database], [Ticket], [Change] FROM [ServerInventory].[dbo].[SQLChangeLog]"
    }
 
    process {
        Write-Verbose "Returning changelog"
        $changes = Invoke-Sqlcmd -serverinstance $inventoryinstance -query $select_query -connectiontimeout 5
    }

    end { 
        $changes | Sort-Object -Property TimeStamp
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

# Blogged
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
# Blogged
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
# Blogged older version
FUNCTION Install-SqlMaintenance {
<#
.SYNOPSIS 
    Deploys the standard MNA maintenance solution
.DESCRIPTION
	Dependendencies  : Sysadmin access on the instances you wish to apply the solution to

    Step 0     : Create a DBAUtility database to store helpful stored procedures and maintenance logging
    Step 1     : Create the following stored procedures in the DBAUtility database
                    - Sp_whoisactive: http://sqlblog.com/blogs/adam_machanic/archive/2012/03/22/released-who-is-active-v11-11.aspx
                    - Sp_Blitz: http://www.brentozar.com/blitz/
                    - Sp_BlitzIndex: http://www.brentozar.com/blitzindex/
                    - Sp_BlitzCache: http://www.brentozar.com/blitzcache/
                    - Sp_AskBrent: http://www.brentozar.com/askbrent/
    Step 2     : Create Ola Hallengren Maintenance procedures: https://ola.hallengren.com/
    Step 3     : Create the maintenance jobs for backups, DBCC Check DBs, Index Maintenance, and maintenance cleanup 
    Step 4     : Schedule the maintenance jobs created in step 2
.PARAMETER  Instances
    Instance name(s)
.PARAMETER  Schedule
    Schedule to use
.PARAMETER  ScriptRoot
    Root path to the rest of the helper scripts, defaults to \\cyclops\groups$\IT\DBA\Ryan\Scripts\SQL\Maintenance\Ola Deploy
.PARAMETER  Production
    Returns all production instances
.EXAMPLE
    PS C:\> Install-SqlMaintenance -Instance sql01 -Schedule Test
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/11
    Version     : 1
.INPUTS
    [string[]], [string]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory,HelpMessage="Instance(s) to install the maintenance on")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
	    [string[]]$Instance,
        [Parameter(Position=0,Mandatory,HelpMessage="Schedule to use for the jobs")]
        [ValidateSet("Development","Test","Production")]
	    [string]$Schedule,
        [Parameter(Position=0,Mandatory=$false,HelpMessage="Root path of the helper SQL scripts")]
        [ValidateScript({Test-Path $_ -PathType Container})]
	    [string]$ScriptRoot = "\\cyclops\groups$\IT\DBA\Ryan\Scripts\SQL\Maintenance\Ola Deploy"
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $createDB_query    = "$scriptroot\0_Utility Database\Maintenance - Database Creation.sql"
        $createSP_queries  = "$scriptroot\1_Stored Procedures"
        $createMnt_query   = "$scriptroot\2_Maintenance Solution\MaintenanceSolution.sql"
        $createJobs_query  = "$scriptroot\2_Maintenance Solution\Maintenance - Job Creation.sql"
        $scheduleJobs_root = "$scriptroot\2_Maintenance Solution\Schedules"
    }
 
    process {
        foreach ($inst in $instance){
            if (Test-SqlConnection -Instance $instance){
                Write-Verbose "Deploying maintenance solution to $inst"
                # Determine which schedule to use
                switch ($schedule){
                    "Development" { $scheduleJobs_query = "$scheduleJobs_root\Schedules - Development.sql" }
                    "Test"        { $scheduleJobs_query = "$scheduleJobs_root\Schedules - Test.sql"        }
                    "Production"  { $scheduleJobs_query = "$scheduleJobs_root\Schedules - Production.sql"  }
                }
                # Create database
                Invoke-Sqlcmd -serverinstance $inst -inputfile $createDB_query     -connectiontimeout 5
                # Create maintenance solution stored procedures in database
                Invoke-Sqlcmd -serverinstance $inst -inputfile $createMnt_query    -connectiontimeout 5
                # Create maintenance solution jobs
                Invoke-Sqlcmd -serverinstance $inst -inputfile $createJobs_query   -connectiontimeout 5
                # Schedule maintenance solution jobs based on environment
                Invoke-Sqlcmd -serverinstance $inst -inputfile $scheduleJobs_query -connectiontimeout 5
                # Create stored procedures in database
                Get-ChildItem $createSP_queries -Filter *.sql | Foreach-Object{ Invoke-Sqlcmd -serverinstance $inst -inputfile $_.fullname -connectiontimeout 5 }
            }
            else{ Write-Error "Could not connect to $inst" }
        }
    }
    
    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}
# Blogged older version
FUNCTION Install-SqlMaintenanceFromCSV {
<#
.SYNOPSIS 
    Deploys the standard MNA maintenance solution to bulk servers using a CSV
.DESCRIPTION
	Dependendencies  : Sysadmin access on the instances you wish to apply the solution to

    Step 0     : Create a DBAUtility database to store helpful stored procedures and maintenance logging
    Step 1     : Create the following stored procedures in the DBAUtility database
                    - Sp_whoisactive: http://sqlblog.com/blogs/adam_machanic/archive/2012/03/22/released-who-is-active-v11-11.aspx
                    - Sp_Blitz: http://www.brentozar.com/blitz/
                    - Sp_BlitzIndex: http://www.brentozar.com/blitzindex/
                    - Sp_BlitzCache: http://www.brentozar.com/blitzcache/
                    - Sp_AskBrent: http://www.brentozar.com/askbrent/
    Step 2     : Create Ola Hallengren Maintenance procedures: https://ola.hallengren.com/
    Step 3     : Create the maintenance jobs for backups, DBCC Check DBs, Index Maintenance, and maintenance cleanup 
    Step 4     : Schedule the maintenance jobs created in step 2
.PARAMETER  CSV
    Path to the instances CSV, defaults to \\cyclops\groups$\IT\DBA\Ryan\Scripts\SQL\Maintenance\Ola Deploy\Instances.csv.  Should have InstanceName,Environment as the first line
.PARAMETER  ScriptRoot
    Root path to the rest of the helper scripts, defaults to \\cyclops\groups$\IT\DBA\Ryan\Scripts\SQL\Maintenance\Ola Deploy
.EXAMPLE
    PS C:\> Install-SqlMaintenanceFromCSV -CSV C:\Temp\servers.csv
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/11
    Version     : 2
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,HelpMessage="Path to the instances CSV")]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
	    [string]$CSV = "\\cyclops\groups$\IT\DBA\Ryan\Scripts\SQL\Maintenance\Ola Deploy\Instances.csv",
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Root path of the helper SQL scripts")]
        [ValidateScript({Test-Path $_ -PathType Container})]
	    [string]$ScriptRoot = "\\cyclops\groups$\IT\DBA\Ryan\Scripts\SQL\Maintenance\Ola Deploy"
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $createDB_query    = "$scriptroot\0_Utility Database\Maintenance - Database Creation.sql"
        $createSP_queries  = "$scriptroot\1_Stored Procedures"
        $createMnt_query   = "$scriptroot\2_Maintenance Solution\MaintenanceSolution.sql"
        $createJobs_query  = "$scriptroot\2_Maintenance Solution\Maintenance - Job Creation.sql"
        $scheduleJobs_root = "$scriptroot\2_Maintenance Solution\Schedules"
    }
 
    process {
        $instances = Import-CSV $csv
        foreach ($instance in $instances){
            if (Test-SqlConnection -Instance $instance.InstanceName){
                Write-Verbose "Deploying maintenance solution to $($instance.InstanceName)"
                # Determine which schedule to use
                switch ($instance.Environment){
                    "Development" { $scheduleJobs_query = "$scheduleJobs_root\Schedules - Development.sql" }
                    "Test"        { $scheduleJobs_query = "$scheduleJobs_root\Schedules - Test.sql"        }
                    "Production"  { $scheduleJobs_query = "$scheduleJobs_root\Schedules - Production.sql"  }
                }
                # Create database
                Invoke-Sqlcmd -serverinstance $instance.InstanceName -inputfile $createDB_query     -connectiontimeout 5
                # Create maintenance solution stored procedures in database
                Invoke-Sqlcmd -serverinstance $instance.InstanceName -inputfile $createMnt_query    -connectiontimeout 5
                # Create maintenance solution jobs
                Invoke-Sqlcmd -serverinstance $instance.InstanceName -inputfile $createJobs_query   -connectiontimeout 5
                # Schedule maintenance solution jobs based on environment
                Invoke-Sqlcmd -serverinstance $instance.InstanceName -inputfile $scheduleJobs_query -connectiontimeout 5
                # Create stored procedures in database
                Get-ChildItem $createSP_queries -Filter *.sql | Foreach-Object{ Invoke-Sqlcmd -serverinstance $instance.InstanceName -inputfile $_.fullname -connectiontimeout 5 }
            }
            else{ Write-Error "Could not connect to $($instance.InstanceName)" }
        }
    }
    
    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}

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
.PARAMETER  InventoryDatabase
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
	CONVERT(VARCHAR(50),(SELECT SERVERPROPERTY(''Collation'')))      AS [Collation],
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
	sdb.[name]                                    AS [DatabaseName], 
	SUSER_SNAME(sdb.[sid])                        AS [Owner],
	sdb.[crdate]								  AS [CreateDate],
	DATABASEPROPERTYEX(sdb.[name], ''Status'')    AS [Status], 
	DATABASEPROPERTYEX(sdb.[name], ''Collation'') AS [Collation], 
	sdb.[cmptlevel]                               AS [CompatibilityLevel], 
	DATABASEPROPERTYEX(sdb.[name], ''Recovery'')  AS [RecoveryMode], 
	bd.[LastFullBackup]                           AS [LastFullBackup],
	bd.[LastDifferential]                         AS [LastDifferential],
	bd.[LastLogBackup]                            AS [LastLogBackup],
	NULL                                          AS [LastDBCCCheckDB],
	dbs.[log_size_mb]                             AS [LogSizeMB],
	dbs.[row_size_mb]                             AS [RowSizeMB],
	dbs.[total_size_mb]                           AS [TotalSizeMB],
	GETDATE()                                     AS [Timestamp]
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
	db.[create_date]			AS [CreateDate],
	db.[state_desc]             AS [Status], 
	db.[collation_name]			AS [Collation],
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
	sj.[date_created]                                  AS [CreateDate],
	sj.[date_modified]                                 AS [LastModified],
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
	sj.[date_created]                   AS [CreateDate],
	sj.[date_modified]                  AS [LastModified],
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
		WHEN 0 THEN CONVERT(VARCHAR(15), STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), sjh.[run_duration]), 6), 3, 0, '':''), 6, 0, '':''), 120)
		ELSE CONVERT(VARCHAR(15), STUFF(STUFF(RIGHT(''000000'' + CONVERT(VARCHAR(6), sjs.[last_run_duration]), 6), 3, 0, '':''), 6, 0, '':''), 120) 
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
        $totalstep = $instances.Count + 6
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
                $collation         = $instanceinfo.Collation 
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
                if (        $collation.GetType().Name -eq 'DBNull'){ $collation         = 'NULL' } else { $collation         = $collation         -replace "'","''" ; $collation         = "'" + $collation         + "'" }
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
                SET version = $version, build = $build, buildnumber = $buildnumber, edition = $edition, authentication = $authentication, collation = $collation, memoryallocatedmb = $memoryallocatedmb, maxdop = $maxdop, ctfp = $ctfp, startuptime = $startuptime, lastupdate = $lastupdate, code = $update_code 
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
                    $createdate         = $db.CreateDate             
                    $status             = $db.Status  
                    $collation          = $db.Collation 
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
                    if (        $createdate.GetType().Name -eq 'DBNull'){ $createdate         = 'NULL' } else { $createdate         = $createdate         -replace "'","''" ; $createdate         = "'" + $createdate         + "'" }
                    if (            $status.GetType().Name -eq 'DBNull'){ $status             = 'NULL' } else { $status             = $status             -replace "'","''" ; $status             = "'" + $status             + "'" }
                    if (         $collation.GetType().Name -eq 'DBNull'){ $collation          = 'NULL' } else { $collation          = $collation          -replace "'","''" ; $collation          = "'" + $collation          + "'" }
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
	                    SET owner = $owner, createdate = $createdate, status = $status, collation = $collation, compatibilitylevel = $compatibilitylevel, recoverymode = $recoverymode, lastfullbackup = $lastfullbackup, lastdifferential = $lastdifferential, lastlogbackup = $lastlogbackup, lastdbcccheckdb = $lastdbcccheckdb, logsizemb = $logsizemb, rowsizemb = $rowsizemb, totalsizemb = $totalsizemb, lastupdate = $lastupdate, code = $update_code 
	                    WHERE name = $databasename and instanceID = $instanceID;
                    ELSE 
	                    INSERT INTO [$inventorydatabase].[dbo].[SQLDatabases]
                        (instanceID,name,owner,createdate,status,collation,compatibilitylevel,recoverymode,lastfullbackup,lastdifferential,lastlogbackup,lastdbcccheckdb,logsizemb,rowsizemb,totalsizemb,lastupdate,code) VALUES
	                    ($instanceid,$databasename,$owner,$createdate,$status,$collation,$compatibilitylevel,$recoverymode,$lastfullbackup,$lastdifferential,$lastlogbackup,$lastdbcccheckdb,$logsizemb,$rowsizemb,$totalsizemb,$lastupdate,$update_code);`n"
                }
                
                Write-Verbose "Collecting job information for $($instance.InstanceName)"
                $jobs = Invoke-Sqlcmd -serverinstance $instance.InstanceName -query $get_sqljobs_query -connectiontimeout 5
                foreach ($job in $jobs){
                    $jobname       = $job.JobName       
                    $status        = $job.Status        
                    $owner         = $job.Owner
                    $createdate    = $job.CreateDate
                    $lastmodified  = $job.LastModified        
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
                    if (   $createdate.GetType().Name -eq 'DBNull'){ $createdate    = 'NULL' } else { $createdate    = $createdate    -replace "'","''" ; $createdate    = "'" + $createdate    + "'" }
                    if ( $lastmodified.GetType().Name -eq 'DBNull'){ $lastmodified  = 'NULL' } else { $lastmodified  = $lastmodified  -replace "'","''" ; $lastmodified  = "'" + $lastmodified  + "'" }       
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
	                    SET status = $status, owner = $owner, createdate = $createdate, lastmodified = $lastmodified, notifylevel = $notifylevel, notifyemail = $notifyemail, schedules = $schedules, lastrunstatus = $lastrunstatus, lastrundate = $lastrundate, runduration = $runduration, nextrundate = $nextrundate, description = $description, lastupdate = $lastupdate, code = $update_code
	                    WHERE name = $jobname and instanceID = $instanceID;
                    ELSE 
	                    INSERT INTO [$inventorydatabase].[dbo].[SQLJobs] 
                        (instanceID,name,status,owner,createdate,lastmodified,notifylevel,notifyemail,schedules,lastrunstatus,lastrundate,runduration,nextrundate,description,lastupdate,code) VALUES
                        ($instanceID,$jobname,$status,$owner,$createdate,$lastmodified,$notifylevel,$notifyemail,$schedules,$lastrunstatus,$lastrundate,$runduration,$nextrundate,$description,$lastupdate,$update_code);`n"
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
        Write-Verbose "Running server update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_servers_query..."      -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_servers_query      -connectiontimeout 30 -DisableVariables
        Write-Verbose "Running instance update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqlinstance_query..."  -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqlinstances_query -connectiontimeout 30 -DisableVariables
        Write-Verbose "Running database update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqldatabases_query..." -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqldatabases_query -connectiontimeout 30 -DisableVariables
        Write-Verbose "Running job update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqljobs_query..."      -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqljobs_query      -connectiontimeout 30 -DisableVariables
        Write-Verbose "Running job step update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqljobsteps_query..."  -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqljobsteps_query  -connectiontimeout 30 -DisableVariables
        $step++
        Write-Progress -Activity "Executing insert_sqlanalytics_query..." -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $insert_sqlanalytics_query -connectiontimeout 30 -DisableVariables

        #Add-Content -Path "C:\Temp\update-servers.sql"      $update_servers_query
        #Add-Content -Path "C:\Temp\update-sqlinstances.sql" $update_sqlinstances_query
        #Add-Content -Path "C:\Temp\update-sqldatabases.sql" $update_sqldatabases_query
        #Add-Content -Path "C:\Temp\update-sqljobs.sql"      $update_sqljobs_query
        #Add-Content -Path "C:\Temp\update-sqljobsteps.sql"  $update_sqljobsteps_query
    }

    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}
# Blogged older version
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

SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], pe.[name] AS [UserName], sl.[name] AS [LoginName], pe.[type_desc] AS [UserType], CASE WHEN il.[sid] IS NULL THEN 'False' ELSE 'True' END AS [Orphaned], NULL AS [DefaultSchema],
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
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], pe.[name] AS [UserName], sl.[name] AS [LoginName], CASE WHEN DATALENGTH(pe.[sid]) = 28 AND pe.[type] = 'S' AND pe.[principal_id] > 4 THEN 'SQL_USER_NO_LOGIN' ELSE pe.[type_desc] END AS [UserType], CASE WHEN DATALENGTH(pe.[sid]) = 28 AND pe.[type] = 'S' AND pe.[principal_id] > 4 THEN 'False' WHEN pe.[principal_id] <= 4 THEN 'False' WHEN sl.[sid] IS NULL THEN 'True' ELSE 'False' END AS [Orphaned], pe.[default_schema_name] AS [DefaultSchema],
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
# Blogged
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

FUNCTION Get-SqlWeakPasswords {
<#
.SYNOPSIS 
    Gets SQL logins with weak/missing passwords
.DESCRIPTION
	Dependendencies  : SQLPS Module, SQL Server 2000+
    SQL Permissions  : sysadmin or maybe securityadmin on each instance
.PARAMETER  Instance
	The name of the instance you wish to check connections to
.PARAMETER  Passwords
	The passwords you wish to check for
.EXAMPLE
    PS C:\> Get-SqlWeakPasswords -Instance DEV-MSSQL
    PS C:\> Get-SqlWeakPasswords -Instance DEV-MSSQL -Passwords (Get-Content C:\temp\passwords.txt)
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/12/08
    Version     : 1
.INPUTS
    [string]
.OUTPUTS
    [array]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage="Name of the instance(s) to check, leave off for all instances")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
	    [string[]]$Instance,
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Passwords to check")]
        [ValidateNotNullOrEmpty()]
	    [string[]]$Passwords
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $totalLogins = @()
        # These queries return all logins with weak passwords
        $get_weakloginpasswords_query = @"
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], name AS [Login], create_date AS [Created], modify_date AS [Modified], 
CASE WHEN PWDCOMPARE('',password_hash)=1 THEN 'Blank' WHEN PWDCOMPARE(name,password_hash)=1 THEN 'Matches Name' ELSE 'Matches Simple' END AS [Reason]
FROM sys.sql_logins 
WHERE PWDCOMPARE('',password_hash)=1
OR PWDCOMPARE(name,password_hash)=1
"@
        $get_weakloginpasswords_SQL2000_query = @"
-- SQL 2000
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], name AS [Login], createdate AS [Created], updatedate AS [Modified], 
CASE WHEN password is null THEN 'Blank' WHEN PWDCOMPARE('',password)=1 THEN 'Blank' WHEN PWDCOMPARE(name,password)=1 THEN 'Matches Name' ELSE 'Matches Simple' END AS [Reason]
FROM dbo.syslogins 
WHERE isntname = 0 AND (
password IS NULL 
OR PWDCOMPARE(password,'')=1
OR PWDCOMPARE(name,password)=1
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
        if ($passwords){
            foreach ($password in $passwords){
                $password = $password.Replace("'","''")
                Write-Verbose "Adding $password to query..."
                $get_weakloginpasswords_query         += "`nOR PWDCOMPARE('$password',password_hash)=1"
                $get_weakloginpasswords_SQL2000_query += "`nOR PWDCOMPARE('$password',password)=1"
            }
            $get_weakloginpasswords_SQL2000_query += "`n)"
        }
        else {
            $get_weakloginpasswords_SQL2000_query += "`n)"
        }
        $totalstep = ($instances.Count * 2) + 1
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
            if ($instancebuild -lt 9){
                Write-Verbose "Processing $instancename..."
                Write-Progress -Activity "Running query against $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
                $totalLogins += Invoke-Sqlcmd -serverinstance $instancename -query $get_weakloginpasswords_SQL2000_query -connectiontimeout 5
            } 
            else {
                Write-Verbose "Processing $instancename..."
                $stepnum++
                Write-Progress -Activity "Running query against $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
                $totalLogins += Invoke-Sqlcmd -serverinstance $instancename -query $get_weakloginpasswords_query         -connectiontimeout 5              
            }    
        }
    }

    end { 
        $stepnum++
        Write-Progress -Activity "Outputting/returning results..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
        $totalLogins
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

FUNCTION Get-OldSqlBackupFiles {
<# 
.SYNOPSIS 
    Returns a list of manually created backup files older than a specified number of days
.DESCRIPTION 
    Searches \\exahub03\SQL_Backups\_Requests recursively for all .bak files that are older than a specified number of days
.PARAMETER  Age
	The maximum age of the backup file in days
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/12/04
    Version     : 1
.INPUTS
    [int]
#> 
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,HelpMessage="Max age of backup in days")]
        [ValidateRange(0,[int]::MaxValue)]
	    [int]$Age = 30,
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Root path to backups")]
        [ValidateScript({Test-Path $_})]
	    [string]$Path = '\\exahub03\SQL_Backups\_Requests'
    )

    begin {
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $backups = @()
    }

    process {
        $root  = $path
        $limit = (Get-Date).AddDays(-$Age)
        $files = Get-ChildItem $root -Recurse | Where-Object { -not $_.PSIsContainer -and $_.CreationTime -lt $limit -and $_.Extension -eq '.bak'}
                
        foreach ($file in $files){
            $holder    = New-Object -TypeName PSObject
            $truncated = $file.FullName.Replace($root,"")
            $server    = $truncated.Split("\")[1]
            $database  = $truncated.Split("\")[2]
            Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Server'       -Value $server
            Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Database'     -Value $database
            Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Name'         -Value $file.Name
            Add-Member -InputObject $holder -MemberType NoteProperty -Name 'CreationTime' -Value $file.CreationTime
            Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Path'         -Value $file.FullName
            Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Mbytes'       -Value ($file.Length / 1MB)
            $backups += $holder
        }
        $backups | Sort-Object Server,Database,CreationTime
    }

    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}
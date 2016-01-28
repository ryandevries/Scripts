FUNCTION Update-SqlInventoryOffline {
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
        # This will hold all of the update queries as the script loops through instances/databases, starts by setting all codes to 1 (doesn't exist)
        $update_servers_query      = "
SET NOCOUNT ON
BEGIN TRANSACTION`n"
        $update_sqlinstances_query = "
SET NOCOUNT ON
BEGIN TRANSACTION
`n"
        $update_sqldatabases_query = "
SET NOCOUNT ON
BEGIN TRANSACTION
`n"
        $update_sqljobs_query      = "
SET NOCOUNT ON
BEGIN TRANSACTION
`n"
        $update_sqljobsteps_query  = "
SET NOCOUNT ON
BEGIN TRANSACTION

DECLARE @jobid int`n"
        $update_code               = "'3'"
    }

    process {
        $instance_csv =
        $database_csv =
        $job_csv      =
        $job_step_csv =
        Write-Verbose "Collecting instance information from CSV"
        $instances = Import-Csv -Path $instance_csv
        foreach ($instance in $instances){
            if ($instance.InstanceName -eq 'NULL'){ $instanceName = 'Default Instance' } else { $instanceName = $instance.InstanceName }
            Write-Verbose "Processing $($instance.ServerName)\$instanceName"
            $serverID   = Invoke-Sqlcmd -serverinstance $inventoryinstance -query "SELECT [ServerID]   FROM [$inventorydatabase].[dbo].[Servers]      WHERE [Name]     = $($instance.ServerName)"              -connectiontimeout 5
            $instanceID = Invoke-Sqlcmd -serverinstance $inventoryinstance -query "SELECT [InstanceID] FROM [$inventorydatabase].[dbo].[SQLInstances] WHERE [ServerID] = $serverID AND [Name] = $instanceName" -connectiontimeout 5
            $version           = $instance.Version          
            $build             = $instance.Build            
            $buildnumber       = $instance.BuildNumber      
            $edition           = $instance.Edition          
            $authentication    = $instance.Authentication  
            $collation         = $instance.Collation 
            $memoryallocatedmb = $instance.MemoryAllocatedMB
            $maxdop            = $instance.MaxDOP           
            $ctfp              = $instance.CTFP             
            $numcores          = $instance.Cores            
            $memorymb          = $instance.TotalMemoryMB    
            $startuptime       = $instance.StartupTime      
            $lastupdate        = $instance.Timestamp        
            Write-Verbose "Accounting for NULLs"
            if (          $version -ne 'Null'){ $version           = $version           -replace "'","''" ; $version           = "'" + $version           + "'" }
            if (            $build -ne 'Null'){ $build             = $build             -replace "'","''" ; $build             = "'" + $build             + "'" }
            if (      $buildnumber -ne 'Null'){ $buildnumber       = $buildnumber       -replace "'","''" ; $buildnumber       = "'" + $buildnumber       + "'" }
            if (          $edition -ne 'Null'){ $edition           = $edition           -replace "'","''" ; $edition           = "'" + $edition           + "'" }
            if (   $authentication -ne 'Null'){ $authentication    = $authentication    -replace "'","''" ; $authentication    = "'" + $authentication    + "'" }
            if (        $collation -ne 'Null'){ $collation         = $collation         -replace "'","''" ; $collation         = "'" + $collation         + "'" }
            if ($memoryallocatedmb -ne 'Null'){ $memoryallocatedmb = $memoryallocatedmb -replace "'","''" ; $memoryallocatedmb = "'" + $memoryallocatedmb + "'" }
            if (           $maxdop -ne 'Null'){ $maxdop            = $maxdop            -replace "'","''" ; $maxdop            = "'" + $maxdop            + "'" }
            if (             $ctfp -ne 'Null'){ $ctfp              = $ctfp              -replace "'","''" ; $ctfp              = "'" + $ctfp              + "'" }
            if (         $numcores -ne 'Null'){ $numcores          = $numcores          -replace "'","''" ; $numcores          = "'" + $numcores          + "'" }
            if (         $memorymb -ne 'Null'){ $memorymb          = $memorymb          -replace "'","''" ; $memorymb          = "'" + $memorymb          + "'" }
            if (      $startuptime -ne 'Null'){ $startuptime       = $startuptime       -replace "'","''" ; $startuptime       = "'" + $startuptime       + "'" }
            if (       $lastupdate -ne 'Null'){ $lastupdate        = $lastupdate        -replace "'","''" ; $lastupdate        = "'" + $lastupdate        + "'" }
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
        }
        Write-Verbose "Collecting database information from CSV"
        $dbs = Import-Csv -Path $database_csv
        foreach ($db in $dbs){
            if ($db.InstanceName -eq 'NULL'){ $instanceName = 'Default Instance' } else { $instanceName = $db.InstanceName }
            $serverID           = Invoke-Sqlcmd -serverinstance $inventoryinstance -query "SELECT [ServerID]   FROM [$inventorydatabase].[dbo].[Servers]      WHERE [Name]     = $($db.ServerName)"                    -connectiontimeout 5
            $instanceID         = Invoke-Sqlcmd -serverinstance $inventoryinstance -query "SELECT [InstanceID] FROM [$inventorydatabase].[dbo].[SQLInstances] WHERE [ServerID] = $serverID AND [Name] = $instanceName" -connectiontimeout 5
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
            if (      $databasename -ne 'Null'){ $databasename       = $databasename       -replace "'","''" ; $databasename       = "'" + $databasename       + "'" }
            if (             $owner -ne 'Null'){ $owner              = $owner              -replace "'","''" ; $owner              = "'" + $owner              + "'" }
            if (        $createdate -ne 'Null'){ $createdate         = $createdate         -replace "'","''" ; $createdate         = "'" + $createdate         + "'" }
            if (            $status -ne 'Null'){ $status             = $status             -replace "'","''" ; $status             = "'" + $status             + "'" }
            if (         $collation -ne 'Null'){ $collation          = $collation          -replace "'","''" ; $collation          = "'" + $collation          + "'" }
            if ($compatibilitylevel -ne 'Null'){ $compatibilitylevel = $compatibilitylevel -replace "'","''" ; $compatibilitylevel = "'" + $compatibilitylevel + "'" }
            if (      $recoverymode -ne 'Null'){ $recoverymode       = $recoverymode       -replace "'","''" ; $recoverymode       = "'" + $recoverymode       + "'" }
            if (    $lastfullbackup -ne 'Null'){ $lastfullbackup     = $lastfullbackup     -replace "'","''" ; $lastfullbackup     = "'" + $lastfullbackup     + "'" }
            if (  $lastdifferential -ne 'Null'){ $lastdifferential   = $lastdifferential   -replace "'","''" ; $lastdifferential   = "'" + $lastdifferential   + "'" }
            if (     $lastlogbackup -ne 'Null'){ $lastlogbackup      = $lastlogbackup      -replace "'","''" ; $lastlogbackup      = "'" + $lastlogbackup      + "'" }
            if (   $lastdbcccheckdb -ne 'Null'){ $lastdbcccheckdb    = $lastdbcccheckdb    -replace "'","''" ; $lastdbcccheckdb    = "'" + $lastdbcccheckdb    + "'" }
            if (         $logsizemb -ne 'Null'){ $logsizemb          = $logsizemb          -replace "'","''" ; $logsizemb          = "'" + $logsizemb          + "'" }
            if (         $rowsizemb -ne 'Null'){ $rowsizemb          = $rowsizemb          -replace "'","''" ; $rowsizemb          = "'" + $rowsizemb          + "'" }
            if (       $totalsizemb -ne 'Null'){ $totalsizemb        = $totalsizemb        -replace "'","''" ; $totalsizemb        = "'" + $totalsizemb        + "'" }
            if (        $lastupdate -ne 'Null'){ $lastupdate         = $lastupdate         -replace "'","''" ; $lastupdate         = "'" + $lastupdate         + "'" }
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
                
        Write-Verbose "Collecting job information from CSV"
        $jobs = Import-Csv -Path $job_csv
        foreach ($job in $jobs){
            if ($job.InstanceName -eq 'NULL'){ $instanceName = 'Default Instance' } else { $instanceName = $job.InstanceName }
            $serverID      = Invoke-Sqlcmd -serverinstance $inventoryinstance -query "SELECT [ServerID]   FROM [$inventorydatabase].[dbo].[Servers]      WHERE [Name]     = $($job.ServerName)"                   -connectiontimeout 5
            $instanceID    = Invoke-Sqlcmd -serverinstance $inventoryinstance -query "SELECT [InstanceID] FROM [$inventorydatabase].[dbo].[SQLInstances] WHERE [ServerID] = $serverID AND [Name] = $instanceName" -connectiontimeout 5
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
            if (      $jobname -ne 'Null'){ $jobname       = $jobname       -replace "'","''" ; $jobname       = "'" + $jobname       + "'" }    
            if (       $status -ne 'Null'){ $status        = $status        -replace "'","''" ; $status        = "'" + $status        + "'" }    
            if (        $owner -ne 'Null'){ $owner         = $owner         -replace "'","''" ; $owner         = "'" + $owner         + "'" }
            if (   $createdate -ne 'Null'){ $createdate    = $createdate    -replace "'","''" ; $createdate    = "'" + $createdate    + "'" }
            if ( $lastmodified -ne 'Null'){ $lastmodified  = $lastmodified  -replace "'","''" ; $lastmodified  = "'" + $lastmodified  + "'" }       
            if (  $notifylevel -ne 'Null'){ $notifylevel   = $notifylevel   -replace "'","''" ; $notifylevel   = "'" + $notifylevel   + "'" }
            if (  $notifyemail -ne 'Null'){ $notifyemail   = $notifyemail   -replace "'","''" ; $notifyemail   = "'" + $notifyemail   + "'" }
            if (    $schedules -ne 'Null'){ $schedules     = $schedules     -replace "'","''" ; $schedules     = "'" + $schedules     + "'" }
            if ($lastrunstatus -ne 'Null'){ $lastrunstatus = $lastrunstatus -replace "'","''" ; $lastrunstatus = "'" + $lastrunstatus + "'" }
            if (  $lastrundate -ne 'Null'){ $lastrundate   = $lastrundate   -replace "'","''" ; $lastrundate   = "'" + $lastrundate   + "'" }
            if (  $runduration -ne 'Null'){ $runduration   = $runduration   -replace "'","''" ; $runduration   = "'" + $runduration   + "'" }
            if (  $nextrundate -ne 'Null'){ $nextrundate   = $nextrundate   -replace "'","''" ; $nextrundate   = "'" + $nextrundate   + "'" }
            if (  $description -ne 'Null'){ $description   = $description   -replace "'","''" ; $description   = "'" + $description   + "'" }
            if (   $lastupdate -ne 'Null'){ $lastupdate    = $lastupdate    -replace "'","''" ; $lastupdate    = "'" + $lastupdate    + "'" } 
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
                
        Write-Verbose "Collecting job step information from CSV"  
        $jobsteps = Import-Csv -Path $job_step_csv
        foreach ($jobstep in $jobsteps){
            if ($jobstep.InstanceName -eq 'NULL'){ $instanceName = 'Default Instance' } else { $instanceName = $jobstep.InstanceName }
            $serverID        = Invoke-Sqlcmd -serverinstance $inventoryinstance -query "SELECT [ServerID]   FROM [$inventorydatabase].[dbo].[Servers]      WHERE [Name]     = $($jobstep.ServerName)"               -connectiontimeout 5
            $instanceID      = Invoke-Sqlcmd -serverinstance $inventoryinstance -query "SELECT [InstanceID] FROM [$inventorydatabase].[dbo].[SQLInstances] WHERE [ServerID] = $serverID AND [Name] = $instanceName" -connectiontimeout 5
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
            if (        $jobname -ne 'Null'){ $jobname         = $jobname         -replace "'","''" ; $jobname         = "'" + $jobname         + "'" }          
            if (     $stepnumber -ne 'Null'){ $stepnumber      = $stepnumber      -replace "'","''" ; $stepnumber      = "'" + $stepnumber      + "'" }       
            if (       $stepname -ne 'Null'){ $stepname        = $stepname        -replace "'","''" ; $stepname        = "'" + $stepname        + "'" }         
            if (      $subsystem -ne 'Null'){ $subsystem       = $subsystem       -replace "'","''" ; $subsystem       = "'" + $subsystem       + "'" }        
            if (  $lastrunstatus -ne 'Null'){ $lastrunstatus   = $lastrunstatus   -replace "'","''" ; $lastrunstatus   = "'" + $lastrunstatus   + "'" }    
            if (    $lastrundate -ne 'Null'){ $lastrundate     = $lastrundate     -replace "'","''" ; $lastrundate     = "'" + $lastrundate     + "'" }      
            if ($lastrunduration -ne 'Null'){ $lastrunduration = $lastrunduration -replace "'","''" ; $lastrunduration = "'" + $lastrunduration + "'" }  
            if (          $proxy -ne 'Null'){ $proxy           = $proxy           -replace "'","''" ; $proxy           = "'" + $proxy           + "'" }            
            if (        $logfile -ne 'Null'){ $logfile         = $logfile         -replace "'","''" ; $logfile         = "'" + $logfile         + "'" }          
            if (        $command -ne 'Null'){ $command         = $command         -replace "'","''" ; $command         = "'" + $command         + "'" }          
            if (        $message -ne 'Null'){ $message         = $message         -replace "'","''" ; $message         = "'" + $message         + "'" }          
            if (        $stepuid -ne 'Null'){ $stepuid         = $stepuid         -replace "'","''" ; $stepuid         = "'" + $stepuid         + "'" }          
            if (     $lastupdate -ne 'Null'){ $lastupdate      = $lastupdate      -replace "'","''" ; $lastupdate      = "'" + $lastupdate      + "'" }       
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
        
        #Write-Verbose "Running server update against $inventoryinstance"
        #Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_servers_query      -connectiontimeout 5 -DisableVariables
        #Write-Verbose "Running instance update against $inventoryinstance"
        #Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqlinstances_query -connectiontimeout 5 -DisableVariables
        #Write-Verbose "Running database update against $inventoryinstance"
        #Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqldatabases_query -connectiontimeout 5 -DisableVariables
        #Write-Verbose "Running job update against $inventoryinstance"
        #Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqljobs_query      -connectiontimeout 5 -DisableVariables
        #Write-Verbose "Running job step update against $inventoryinstance"
        #Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqljobsteps_query  -connectiontimeout 5 -DisableVariables

        Add-Content -Path "C:\Temp\update-servers.sql"      $update_servers_query
        Add-Content -Path "C:\Temp\update-sqlinstances.sql" $update_sqlinstances_query
        Add-Content -Path "C:\Temp\update-sqldatabases.sql" $update_sqldatabases_query
        Add-Content -Path "C:\Temp\update-sqljobs.sql"      $update_sqljobs_query
        Add-Content -Path "C:\Temp\update-sqljobsteps.sql"  $update_sqljobsteps_query
    }

    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}
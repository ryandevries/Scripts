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
        $instances = Get-SqlInstances -IncludeInaccessible
        $totalstep = $instances.Count + 5
        $step      = 0
        foreach ($instance in $instances){
            Write-Verbose "Trying connection to $($instance.InstanceName)"
            $step++
            Write-Progress -Activity "Processing $($instance.InstanceName)..." -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
            $serverID   = $instance.ServerID
            $instanceID = $instance.InstanceID
            if (Test-SqlConnection -Instance $instance.InstanceName){
                Write-Verbose "Collecting instance information for $($instance.InstanceName)"
                $instanceinfo      = Get-SqlInstanceInformation
                $version           = $instanceinfo.Version          
                $build             = $instanceinfo.Build            
                $buildnumber       = $instanceinfo.BuildNumber      
                $edition           = $instanceinfo.Edition          
                $authentication    = $instanceinfo.Authentication   
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
                SET version = $version, build = $build, buildnumber = $buildnumber, edition = $edition, authentication = $authentication, memoryallocatedmb = $memoryallocatedmb, maxdop = $maxdop, ctfp = $ctfp, startuptime = $startuptime, lastupdate = $lastupdate, code = $update_code 
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
                    $status             = $db.Status             
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
                    if (            $status.GetType().Name -eq 'DBNull'){ $status             = 'NULL' } else { $status             = $status             -replace "'","''" ; $status             = "'" + $status             + "'" }
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
	                    SET owner = $owner, status = $status, compatibilitylevel = $compatibilitylevel, recoverymode = $recoverymode, lastfullbackup = $lastfullbackup, lastdifferential = $lastdifferential, lastlogbackup = $lastlogbackup, lastdbcccheckdb = $lastdbcccheckdb, logsizemb = $logsizemb, rowsizemb = $rowsizemb, totalsizemb = $totalsizemb, lastupdate = $lastupdate, code = $update_code 
	                    WHERE name = $databasename and instanceID = $instanceID;
                    ELSE 
	                    INSERT INTO [$inventorydatabase].[dbo].[SQLDatabases]
                        (instanceID,name,owner,status,compatibilitylevel,recoverymode,lastfullbackup,lastdifferential,lastlogbackup,lastdbcccheckdb,logsizemb,rowsizemb,totalsizemb,lastupdate,code) VALUES
	                    ($instanceid,$databasename,$owner,$status,$compatibilitylevel,$recoverymode,$lastfullbackup,$lastdifferential,$lastlogbackup,$lastdbcccheckdb,$logsizemb,$rowsizemb,$totalsizemb,$lastupdate,$update_code);`n"
                }
                
                Write-Verbose "Collecting job information for $($instance.InstanceName)"
                $jobs = Invoke-Sqlcmd -serverinstance $instance.InstanceName -query $get_sqljobs_query -connectiontimeout 5
                foreach ($job in $jobs){
                    $jobname       = $job.JobName       
                    $status        = $job.Status        
                    $owner         = $job.Owner         
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
	                    SET status = $status, owner = $owner, notifylevel = $notifylevel, notifyemail = $notifyemail, schedules = $schedules, lastrunstatus = $lastrunstatus, lastrundate = $lastrundate, runduration = $runduration, nextrundate = $nextrundate, description = $description, lastupdate = $lastupdate, code = $update_code
	                    WHERE name = $jobname and instanceID = $instanceID;
                    ELSE 
	                    INSERT INTO [$inventorydatabase].[dbo].[SQLJobs] 
                        (instanceID,name,status,owner,notifylevel,notifyemail,schedules,lastrunstatus,lastrundate,runduration,nextrundate,description,lastupdate,code) VALUES
                        ($instanceID,$jobname,$status,$owner,$notifylevel,$notifyemail,$schedules,$lastrunstatus,$lastrundate,$runduration,$nextrundate,$description,$lastupdate,$update_code);`n"
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
        Write-Verbose "Running instance update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqlinstance_query..."  -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqlinstances_query -connectiontimeout 5 -DisableVariables
        Write-Verbose "Running database update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqldatabases_query..." -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqldatabases_query -connectiontimeout 5 -DisableVariables
        Write-Verbose "Running job update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqljobs_query..."      -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqljobs_query      -connectiontimeout 5 -DisableVariables
        Write-Verbose "Running job step update against $inventoryinstance"
        $step++
        Write-Progress -Activity "Executing update_sqljobsteps_query..."  -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $update_sqljobsteps_query  -connectiontimeout 5 -DisableVariables
        $step++
        Write-Progress -Activity "Executing insert_sqlanalytics_query..." -Status ("Percent Complete: " + [int](($step / $totalstep) * 100) + "%") -PercentComplete (($step / $totalstep) * 100)
        Invoke-Sqlcmd -serverinstance $inventoryinstance -query $insert_sqlanalytics_query -connectiontimeout 5 -DisableVariables

        #Add-Content -Path "C:\Temp\update-servers.sql"      $update_servers_query
        #Add-Content -Path "C:\Temp\update-sqlinstances.sql" $update_sqlinstances_query
        #Add-Content -Path "C:\Temp\update-sqldatabases.sql" $update_sqldatabases_query
        #Add-Content -Path "C:\Temp\update-sqljobs.sql"      $update_sqljobs_query
        #Add-Content -Path "C:\Temp\update-sqljobsteps.sql"  $update_sqljobsteps_query
    }

    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}
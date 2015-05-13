<# 
.SYNOPSIS 
    Deploys standard SQL maintenance solution
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

.NOTES 
    Author     : Ryan DeVries
    Updated    : 2015-05-11
#> 

#-----------------------------------------------#
# FUNCTIONS
#-----------------------------------------------#

<#
.FUNCTION
    Test-SQLConnection
.SYNOPSIS
    Test connection to SQL Instance
.PARAMETER Instance
    The name of the instance you wish to check connections to
.EXAMPLE
    Test-SQLConnection -Instance DEV-MSSQL
.RELEASE
    1.0 2015/01/27 Ryan DeVries
#>
 
FUNCTION Test-SqlConnection {
    [CmdletBinding()]
     Param (
    # Instance to run against
    [Parameter(Mandatory=$true,
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
    [string[]]$Instance
    )
 
    BEGIN {}
 
    PROCESS {
        # Build connection String to test connection based on server name and Windows Authentication
        $connectionString = "Data Source=$Instance;Integrated Security=true;Initial Catalog=master;Connect Timeout=3;"
        TRY {
            # Try and connect to server
            $sqlConn = new-object ("Data.SqlClient.SqlConnection") $connectionString
            $sqlConn.Open()
                       
            # If connection was made to the server
            if ($sqlConn.State -eq 'Open'){
                # Close connection and return true
                $sqlConn.Close();
                return $true
            }
        }
        CATCH{ return $false }
    }
    END {}
}

#-----------------------------------------------#
# VARIABLES
#-----------------------------------------------#

$instances         = import-csv "$PSScriptRoot\instances.csv"
$createDB_query    = "$PSScriptRoot\0_Utility Database\Database Creation.sql"
$createSP_queries  = "$PSScriptRoot\1_Stored Procedures"
$createMnt_query   = "$PSScriptRoot\2_Maintenance Solution\MaintenanceSolution.sql"
$createJobs_query  = "$PSScriptRoot\2_Maintenance Solution\Job Creation.sql"
$scheduleJobs_root = "$PSScriptRoot\2_Maintenance Solution\Schedules"

#-----------------------------------------------#
# START
#-----------------------------------------------#

push-location
import-module sqlps -DisableNameChecking
pop-location

foreach($instance in $instances){
    if(test-sqlconnection -instance $instance.InstanceName){
        write-host $instance.InstanceName
        # Determine which schedule to use
        switch ($instance.Environment){
            "Development" { $scheduleJobs_query = "$scheduleJobs_root\Development.sql" }
            "Test"        { $scheduleJobs_query = "$scheduleJobs_root\Test.sql"        }
            "Production"  { $scheduleJobs_query = "$scheduleJobs_root\Production.sql"  }
        }
        # Create database
        invoke-sqlcmd -serverinstance $instance.InstanceName -inputfile $createDB_query     -connectiontimeout 5
        # Create stored procedures in database
        get-childitem $createSP_queries -Filter *.sql | foreach-object{ invoke-sqlcmd -serverinstance $instance.InstanceName -inputfile $_.fullname -connectiontimeout 5 }
        # Create maintenance solution stored procedures in database
        invoke-sqlcmd -serverinstance $instance.InstanceName -inputfile $createMnt_query    -connectiontimeout 5
        # Create maintenance solution jobs
        invoke-sqlcmd -serverinstance $instance.InstanceName -inputfile $createJobs_query   -connectiontimeout 5
        # Schedule maintenance solution jobs based on environment
        invoke-sqlcmd -serverinstance $instance.InstanceName -inputfile $scheduleJobs_query -connectiontimeout 5
    }
    else{ write-host -ForegroundColor Red "Could not connect to $($instance.InstanceName)" }
}

#-----------------------------------------------#  
# END
#-----------------------------------------------#

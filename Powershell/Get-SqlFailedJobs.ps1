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

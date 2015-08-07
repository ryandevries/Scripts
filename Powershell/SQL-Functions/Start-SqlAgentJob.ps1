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

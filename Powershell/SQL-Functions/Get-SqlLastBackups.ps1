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

FUNCTION Get-OldSqlBackupFiles {
<# 
.SYNOPSIS 
    Returns a list of manually created backup files older than a specified number of days
.DESCRIPTION 
    Searches \\exahub03_nic4\SQL_Backups\_Requests recursively for all .bak files that are older than a specified number of days
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
	    [int]$Age = 30
    )

    begin {
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
    }

    process {
        $root  = '\\exahub03_nic4\SQL_Backups\_Requests'
        $limit = (Get-Date).AddDays(-$Age)
        $files = Get-ChildItem $root -Recurse | Where-Object { -not $_.PSIsContainer -and $_.CreationTime -lt $limit -and $_.Extension -eq '.bak'}

        $backups = @()
        foreach ($file in $files){
            $holder     = New-Object -TypeName PSObject
            $truncated = $file.FullName.Replace($root,"")
            $server = $truncated.Split("\")[1]
            $database = $truncated.Split("\")[2]
            Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Server' -Value $server
            Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Database' -Value $database
            Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Name' -Value $file.Name
            Add-Member -InputObject $holder -MemberType NoteProperty -Name 'CreationTime' -Value $file.CreationTime
            Add-Member -InputObject $holder -MemberType NoteProperty -Name 'Path' -Value $file.Directory
            $backups += $holder
        }
        $backups | Sort-Object Server,Database,CreationTime | ft -AutoSize
    }

    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}
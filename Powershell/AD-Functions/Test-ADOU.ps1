FUNCTION Test-ADOU {
<#
.SYNOPSIS
    Validates an OU path
.DESCRIPTION
    Validates an OU path
.PARAMETER Path
    The path to the OU
.EXAMPLE
    PS C:\> Test-ADOU -Path "OU=Information Technology Department,OU=Departments,OU=Manning- Napier Organization,DC=Manning-Napier,DC=com"
    true
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/07/15
    Version     : 1
.INPUTS
    [string]
.OUTPUTS
    [boolean]
#>
    [CmdletBinding()]
    Param (
        [Parameter(Position=0,Mandatory,HelpMessage="Enter a first name")]
        [ValidateNotNullorEmpty()]
        [string]$Path
    )
 
    begin { # Configure environment, initialize variables
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
    }
 
    process {
        try { if ([ADSI]::Exists("LDAP://$path")){ $true } else { $false } } catch { Write-Error "Error validating $path : $($_.Exception.GetBaseException().Message)"; $false }
    }

    end { 
        if ($log){ if($newlog) { Stop-Log -Path $log } }
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

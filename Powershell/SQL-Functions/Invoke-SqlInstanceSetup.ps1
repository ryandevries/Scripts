FUNCTION Invoke-SqlInstanceSetup {
<# 
.SYNOPSIS 
    Applies standard MNA SQL setup to a new instance
.DESCRIPTION 
    Applies standard MNA SQL setup to a new instance
.PARAMETER  Instance
	The name of the instance to set up
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/12/02
    Version     : 1
.INPUTS
    [string]
#> 
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,HelpMessage="Name of the instance to configure")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
	    [string]$Instance
    )

    begin {
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        Import-SQLPS
        Import-Module NetSecurity        
    }

    process {
        # Ping
        Set-NetFirewallRule -enabled True -Profile Domain -DisplayName “File and Printer Sharing (Echo Request – ICMPv4-In)” 
        # WMI for Red Gate SQL Monitor
        Set-NetFirewallRule -enabled True -Profile Domain -DisplayGroup "Windows Management Instrumentation (WMI)"            
        # SQL Instance(s)
        Get-Service -DisplayName "SQL Server (*"      | Foreach-Object { New-NetFirewallRule -DisplayName $_.DisplayName -Direction Inbound -Action Allow -Enabled True -Profile Domain -Service $_.ServiceName }
        # SQL Browser
        Get-Service -DisplayName "SQL Server Browser" | Foreach-Object { New-NetFirewallRule -DisplayName $_.DisplayName -Direction Inbound -Action Allow -Enabled True -Profile Domain -Service $_.ServiceName }
    }

    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}
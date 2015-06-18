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

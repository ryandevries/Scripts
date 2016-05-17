FUNCTION Template-Function {
<#
.SYNOPSIS 
    Template Function
.DESCRIPTION
	This function provides a framework for integrating logging into a task
.PARAMETER  Param1
	Requires something
.PARAMETER  Param2
	Requires something
.PARAMETER  Param3
	Requires something
.PARAMETER  Log
	Optional, a path for a log file
.EXAMPLE
    PS C:\> Template-Function -Param1 one -Param2 two -Param3 three -Log C:\Temp\file.log
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/05/19
    Version     : 1
#>
    [CmdletBinding()]
    Param(
	    [Parameter(Position=0,Mandatory,HelpMessage="Whats this",ValueFromPipeline)]
        [ValidateScript({Test $_})]
	    [string]$Param1,
        [Parameter(Position=1,Mandatory,HelpMessage="Whats this")]
        [ValidateScript({Test $_})]
	    [string]$Param2,
        [Parameter(Position=2,Mandatory,HelpMessage="Whats this")]
        [ValidateNotNullorEmpty()]
	    [string]$Param3,
        [Parameter(Position=3,Mandatory=$false,HelpMessage="Enter the path of a log file to use")]
        [ValidateScript({Test-Path (Split-Path $_ -Parent) -PathType Container})]
	    [string]$Log
    )

    begin {
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $newlog = $false
        if ($log){ if (!(Test-Path $log -PathType Leaf)){ $newlog = $true } }
        if ($log){ 
            if ($newlog){ 
                Write-Verbose "Starting log at $log"
                Start-Log -Path (Split-Path $log -Parent) -Name (Split-Path $log -Leaf)
            }
            Write-Log -Path $log -Line $scriptstring
        }
    }
 
    process {}

    end { 
        if ($log){ if($newlog) { Stop-Log -Path $log } }
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}
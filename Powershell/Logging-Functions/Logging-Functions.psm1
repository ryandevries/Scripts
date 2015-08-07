FUNCTION Start-Log{
<#
.SYNOPSIS
    Creates log file
.DESCRIPTION
    Creates log file based on specified name and path, backs up existing log if exists
.PARAMETER Path
    Requires a valid path
.PARAMETER Name
    Requires a valid filename
.EXAMPLE
    PS C:\> Start-Log -Path "C:\Temp" -Name "NewLog.log"
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/05/19
    Version     : 1
#>
    [CmdletBinding()]
    Param(
	    [Parameter(Position=0,Mandatory,HelpMessage="Enter the path for the log directory")]
        [ValidateScript({Test-Path $_ -PathType Container})]
	    [string]$Path,
        [Parameter(Position=1,Mandatory,HelpMessage="Enter the name of the log",ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
	    [string]$Name
    )  

    begin {
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
    }

    process {
        try {
            $fullpath = $path + "\" + $name
            $bakpath  = $fullpath + '.bak'
            Write-Verbose "Checking for existing log at $fullpath"
            if(Test-Path -Path $fullpath){ 
                Move-Item -Path $fullpath -Destination $bakpath -Force -ErrorAction Stop
                Write-Verbose "Backed up existing log to $bakpath"
            }
            
            New-Item -Path $path -Name $name -ItemType file -ErrorAction Stop > $null
            Write-Verbose "Created log at $fullpath"
            Add-Content -Path $fullpath -Value "Log started: at [$([DateTime]::Now)] by $env:USERNAME on $env:COMPUTERNAME"
            Add-Content -Path $fullpath -Value "--------------------------------------------------------------------`n"
            Add-Content -Path $fullpath -Value "Datetime`t`tExecuting User`tMessage`n"
            Add-Content -Path $fullpath -Value "-------------------`t--------------`t----------------------------`n"
            Write-Verbose "Started Log at $fullpath"
        }
        catch { Write-Error $_ }
    }

    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}
 
FUNCTION Write-Log{
<#
.SYNOPSIS
    Writes a line to a log file
.DESCRIPTION
    Writes a line to the end of the specified log file, prepended with a timestamp
.PARAMETER Path
    Specifies a valid log path
.PARAMETER Line
    Specifies a line to add to the log
.EXAMPLE
     PS C:\> Log-Write -Path "C:\Temp\NewLog.log" -Line "Test message please ignore."
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/05/19
    Version     : 1
#>
    [CmdletBinding()]
    Param(
	    [Parameter(Position=0,Mandatory,HelpMessage="Enter the path of the log file")]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
	    [string]$Path,
        [Parameter(Position=1,Mandatory,HelpMessage="Enter the line to add to the log",ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
	    [string]$Line
    )  

    begin {
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
    }

    process{
        $timeline = "$([DateTime]::Now)" + "`t" + $env:USERNAME + "`t" + $line
        Write-Verbose "Writing $timeline to $path" 
        Add-Content -Path $path -Value $timeline
  }
}
  
FUNCTION Stop-Log{
<#
.SYNOPSIS
    Ends log file
.DESCRIPTION
    Adds a closing line to a log file
.PARAMETER Path
    Requires a valid log path
.EXAMPLE
    PS C:\> Stop-Log -Path "C:\Temp\NewLog.log"
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/05/19
    Version     : 1
#>
    [CmdletBinding()]
    Param(
	    [Parameter(Position=0,Mandatory,HelpMessage="Enter the path of the log file",ValueFromPipeline)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
	    [string]$Path
    )  

    begin {
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
    }

    process {
        Write-Verbose "Finalizing Log at $path"
        Add-Content -Path $Path -Value "`n--------------------------------------------------------------------"
        Add-Content -Path $Path -Value "Log ended:   at [$([DateTime]::Now)] by $env:USERNAME on $env:COMPUTERNAME"
    }

    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}

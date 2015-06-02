FUNCTION Test-ADUser {
<#
.SYNOPSIS
    Test an Active Directory User Account
.DESCRIPTION
    This command will test if a given Active Directory user account exists.
.PARAMETER Username
    The name of an Active Directory user account. This should be either the samAccountName or the DistinguishedName.
.PARAMETER  Log
	Optional, a path for a log file
.EXAMPLE
    PS C:\> Test-ADUser rdevries
    True
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/05/19
    Version     : 1
.LINK
    https://www.petri.com/test-active-directory-user-accounts-with-powershell
.INPUTS
    [string]
.OUTPUTS
    [Boolean]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory,HelpMessage="Enter an AD user name",ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
        [string]$Username,
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Enter the path of a log file to use")]
        [ValidateScript({Test-Path (Split-Path $_ -Parent) -PathType Container})]
	    [string]$Log
    )
 
    begin { # Configure environment, set up logging, initialize variables
        if (!(Get-Module ActiveDirectory)){ Import-Module ActiveDirectory }
        Write-Verbose "Starting $($MyInvocation.Mycommand)"  
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        Write-Verbose ($PSBoundParameters | out-string)
        $newlog = $false
        if ($log){ if(!(Test-Path $log -PathType Leaf)){ $newlog = $true } }
        if ($log){ 
            if ($newlog){ 
                Write-Verbose "Starting log at $log"
                Start-Log -Path (Split-Path $log -Parent) -Name (Split-Path $log -Leaf)
            } 
            $scriptstring = "Starting $($MyInvocation.MyCommand)"
            foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
            Write-Log -Path $log -Line $scriptstring
        }
    }
 
    process {
        Write-Verbose "Searching for user $username"
        if ($log){ Write-Log -Path $log -Line "Trying $username" }
        # Tries to get information about the specified user, returning true if found and false if it catches the specific ADIdentityNotFound exception, terminating if it finds any other error
        try {
            $user =  Get-ADUser -Identity $username -ErrorAction Stop
            if ($log){ Write-Log -Path $log -Line "Found: $(($user | out-string).TrimEnd())`r`n" }
            Write-Verbose "Found user : $(($user | out-string).TrimEnd())"
            $true
        } 
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { 
            if($log){ Write-Log -Path $log -Line "User $username does not exist" }
            Write-Verbose "User $username does not exist"
            $false
        }
        catch {
            #handle all other errors
            if ($log){ Write-Log -Path $log -Line "ERROR : $($_.Exception)" }
            Write-Verbose "ERROR : $($_.Exception)"
            throw $_
            return
        }
    }
 
    end { 
        if ($log){ if($newlog) { Stop-Log -Path $log } }
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
        Remove-Variable user -ErrorAction SilentlyContinue
    }
}

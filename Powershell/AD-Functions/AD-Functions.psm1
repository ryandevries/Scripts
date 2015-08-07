FUNCTION Copy-ADGroups {
<#
.SYNOPSIS 
    Adds a user to the same groups as another user
.DESCRIPTION
	This script pulls a list of all the groups the -like user is a member of, then adds the -username user to them, prompting for confirmation
.PARAMETER  Username
	Requires a valid SAMAccountname, the new account being granted permissions
.PARAMETER  Like
	Requires a valid SAMAccountname to use to generate the group membership
.PARAMETER  Log
	Optional, a path for a log file
.EXAMPLE
    PS C:\> Copy-ADGroups -Username rdevries -Like bneubaue
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/05/19
    Version     : 1
#>
    [CmdletBinding()]
    Param(
	    [Parameter(Position=0,Mandatory,HelpMessage="Enter the username for the new user",ValueFromPipeline)]
        [ValidateScript({Test-ADUser -Username $_})]
	    [string]$Username,
        [Parameter(Position=1,Mandatory,HelpMessage="Enter the username the user to clone, or manager if no user/role is specified")]
        [ValidateNotNullorEmpty()]
	    [string]$Like,
        [Parameter(Position=2,Mandatory=$false,HelpMessage="Enter the path of a log file to use")]
        [ValidateScript({Test-Path (Split-Path $_ -Parent) -PathType Container})]
	    [string]$Log
        
    )

    begin { # Configure environment, set up logging, initialize variables
        if (!(Get-Module ActiveDirectory)){ Import-Module ActiveDirectory }
        $newlog = $false
        if ($log){ if (!(Test-Path $log -PathType Leaf)){ $newlog = $true } }
        if ($log){ 
            if ($newlog){ 
                Write-Verbose "Starting log at $log"
                Start-Log -Path (Split-Path $log -Parent) -Name (Split-Path $log -Leaf)
            } 
        }
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
    }
 
    process {
        switch ($like){
            'manager' {
                $newaduser    = Get-ADUser -Identity $username          -Properties manager
                $targetaduser = Get-ADUser -Identity $newaduser.manager -Properties memberof
                Write-Verbose "Using $($targetaduser.SAMAccountname) as the target"
                Write-Verbose "Getting the group membership for $($targetaduser.SAMAccountname)"
                if($log){ Write-Log -Path $log -Line "Getting the group membership for $($targetaduser.SAMAccountname)" }
            }
            default   {
                if ($log) { $exists = Test-ADUser -Username $like -Log $log } else { $exists = Test-ADUser -Username $like }
                if ($exists){
                    $targetaduser = Get-ADUser -Identity $like -Properties memberof
                    Write-Verbose "Using $like as the target"
                    Write-Verbose "Getting the group membership for $like"
                    if($log){ Write-Log -Path $log -Line "Getting the group membership for $like" }
                }
                else {
                    $newaduser    = Get-ADUser -Identity $username          -Properties manager
                    $targetaduser = Get-ADUser -Identity $newaduser.manager -Properties memberof
                    Write-Verbose "$like is not a valid user, using manager($($targetaduser.SAMAccountname)) as the target"
                    Write-Verbose "Getting the group membership for $($targetaduser.SAMAccountname)"
                    if($log){ Write-Log -Path $log -Line "$like is not a valid user, getting the group membership for manager($($targetaduser.SAMAccountname))" }
                }
            }
        }
        $groups = $targetaduser.MemberOf | Get-ADGroup | Where-Object name -NotLike "Domain Users" | Sort-Object name
        if ($log){ Write-Log -Path $log -Line ("Getting listing of groups $($targetaduser.SAMAccountname) is a member of`r`n`r`nListing of groups $($targetaduser.SAMAccountname) is a member of (except Domain Users):`r`n--------------------------------------------------------------------`r`n" + ($groups.Name | Out-String)) }
        $prompt  = $true
        $yes     = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Adds the user to the group."
        $no      = New-Object System.Management.Automation.Host.ChoiceDescription "&No",  "Skips the group without adding the user."
        $all     = New-Object System.Management.Automation.Host.ChoiceDescription "&All", "Adds the user to all the remaining groups without prompting."
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $all)
        if ($log){ Write-Log -Path $log -Line "Adding $username to groups.  Full user information:$((Get-ADUser -Identity $username | out-string).TrimEnd())`r`n" }
        foreach ($group in $groups){
            try {
                if ($prompt){
                    $title   = "Add user to group"
                    $message = "Do you want to add $username to $($group.name)?"
                    $result  = $host.ui.PromptForChoice($title, $message, $options, 0)
                    switch ($result){
                        0 { 
                            Write-Verbose "Adding $username to $($group.name)" 
                            Add-ADGroupMember -Identity $group -Members $username -ErrorAction Stop
                            if ($log){ Write-Log -Path $log -Line "User: $username`t`tAction: Added  `t`tPrompt: Yes`t`tGroup: $($group.name)" }
                        }
                        1 { 
                            Write-Verbose "Skipping $($group.name)"
                            if ($log){ Write-Log -Path $log -Line "User: $username`t`tAction: Skipped`t`tPrompt: Yes`t`tGroup: $($group.name)" }
                        }
                        2 { 
                            Write-Verbose "Adding $username to $($group.name)"
                            $prompt = $false
                            if ($log){ Write-Log -Path $log -Line "User: $username`t`tAction: All    `t`tPrompt: Disabled" }
                            Add-ADGroupMember -Identity $group -Members $username
                            if ($log){ Write-Log -Path $log -Line "User: $username`t`tAction: Added  `t`tPrompt: Yes`t`tGroup: $($group.name)" }
                        }
                    }
                }
                else { 
                    Write-Verbose "Skipping prompt for $($group.name)" 
                    Add-ADGroupMember -Identity $group -Members $username
                    if ($log){ Write-Log -Path $log -Line "User: $username`t`tAction: Added  `t`tPrompt: No `t`tGroup: $($group.name)" }
                }
            }
            catch {
                if ($log){ Write-Log -Path $log -Line "ERROR ADDING $username to $($group.name) : $($_.Exception)" }
                Write-Verbose "ERROR ADDING $username to $($group.name) : $($_.Exception)"
                continue
            }
        }
        Write-Verbose "Getting the new group membership for $username"
        $newgroups = (Get-ADUser -Identity $username -Properties memberof).MemberOf | Get-ADGroup | Sort-Object name
        if ($log){ Write-Log -Path $log -Line ("Getting listing of groups $username is a member of`r`n`r`nListing of groups $username is a member of (except Domain Users):`r`n--------------------------------------------------------------------`r`n" + ($newgroups.Name | Out-String)) }
    }

    end { 
        if ($log){ if($newlog) { Stop-Log -Path $log } }
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
        Remove-Variable groups    -ErrorAction SilentlyContinue
        Remove-Variable newgroups -ErrorAction SilentlyContinue
    }
}

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
        $newlog = $false
        if ($log){ if(!(Test-Path $log -PathType Leaf)){ $newlog = $true } }
        if ($log){ 
            if ($newlog){ 
                Write-Verbose "Starting log at $log"
                Start-Log -Path (Split-Path $log -Parent) -Name (Split-Path $log -Leaf)
            } 
        }
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
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

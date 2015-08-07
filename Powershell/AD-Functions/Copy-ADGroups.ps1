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

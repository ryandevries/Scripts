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

FUNCTION Test-ADOU {
<#
.SYNOPSIS
    Validates an OU path
.DESCRIPTION
    Validates an OU path
.PARAMETER Path
    The path to the OU
.EXAMPLE
    PS C:\> Test-ADOU -Path "OU=X,OU=Y,OU=Z,DC=Domain,DC=com"
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

FUNCTION Set-ADUsername {
<#
.SYNOPSIS
    Generates a MNA username
.DESCRIPTION
    This command generates a valid MNA account name from user information, following the this policy: 
    Username = first initial plus last name, truncated to a maximum of 8 characters.  
    Special characters are omitted.  
    In the event of a hyphenated last name, the first last name is used.  
    In the event of a duplicate user name, the person’s middle initial will be used after the first initial. 
.PARAMETER Firstname
    The first name of the user.
.PARAMETER MiddleInitial
    The middle initial of the user.
.PARAMETER Lastname
    The last name of the user.
.PARAMETER Domain
    The domain name to be used for the email address.
.PARAMETER  Log
	Optional, a path for a log file
.EXAMPLE
    PS C:\> Set-ADUsername -First Ryan -Middle J -Last DeVries
    rdevries
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/05/19
    Version     : 1
.INPUTS
    [string]
.OUTPUTS
    [string]
#>
    [CmdletBinding()]
    Param (
        [Parameter(Position=0,Mandatory,HelpMessage="Enter a first name")]
        [ValidateNotNullorEmpty()]
        [Alias("First")]
        [string]$Firstname,
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Enter a middle initial")]
        [ValidateNotNullorEmpty()]
        [Alias("Middle")]
        [string]$Middleinitial,
        [Parameter(Position=2,Mandatory,HelpMessage="Enter a last name")]
        [ValidateNotNullorEmpty()]
        [Alias("Last")]
        [string]$Lastname,
        [Parameter(Position=0,Mandatory,HelpMessage="Enter a domain name",ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
        [string]$Domain,
        [Parameter(Position=3,Mandatory=$false,HelpMessage="Enter the path of a log file to use")]
        [ValidateScript({Test-Path (Split-Path $_ -Parent) -PathType Container})]
	    [string]$Log
    )
 
    begin { # Configure environment, set up logging, initialize variables
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
        $user   = New-Object -TypeName PSObject
        $domain = $domain -replace "@",""
    }
 
    process {
        # Cleans up any non-alpha characters from the first and last name, splits hyphenated names and keeps the first specified one
        Write-Verbose "Removing unsupported non-alpha characters and spliting combo last names"
        $lastname       =   ($lastname  -split "-")[0]
        $firstname      =   ($firstname -replace '[^a-zA-Z]','')
        $lastname       =   ($lastname  -replace '[^a-zA-Z]','')
        Write-Verbose "Generating SAM account name"
        # Creates the account name based on MNA specifications (First initial, Last name, max 8 characters)
        $samaccountname = if($lastname.length -le 7){ $firstname.substring(0,1)+$lastname } else{ $firstname.substring(0,1)+$lastname.substring(0,7) }
        $email          = $firstname.substring(0,1)+$lastname+"@"+$domain
        if ($log){ Write-Log -Path $log -Line "Generated $samaccountname from $firstname $lastname, testing if it is in use" }
        Write-Verbose "Testing $samaccountname"
        if ($log){ $exists = Test-ADUser -Username $samaccountname -Log $log } else { $exists = Test-ADUser -Username $samaccountname }
        # If the first username is taken, tries to add a middle initial
        if ($exists){
            if (!$middleinitial){ 
                if ($log){ Write-Log -Path $log -Line "$samaccountname exists. Middle initial not specified, prompting" }
                Write-Verbose "$samaccountname exists. Middle initial not specified, prompting" 
                $middleinitial = Read-Host "Enter a middle initial to use, $samaccountname already exists"
            }
            if ($log){ Write-Log -Path $log -Line "$samaccountname is in use, adding middle initial $middleinitial, testing if it is in use" }
            Write-Verbose "Generating SAM account name with middle initial"
            $samaccountname = if($lastname.length -le 6){ $firstname.substring(0,1)+$middleinitial.substring(0,1)+$lastname } else{ $firstname.substring(0,1)+$middleinitial.substring(0,1)+$lastname.substring(0,6) }
            $email          = $firstname.substring(0,1)+$middleinitial.substring(0,1)+$lastname+"@"+$domain
            Write-Verbose "Testing $samaccountname"
            if ($log){ $exists = Test-ADUser -Username $samaccountname -Log $log } else { $exists = Test-ADUser -Username $samaccountname }
            if ($exists){ 
                if ($log){ Write-Log -Path $log -Line "$samaccountname is also in use, returning $false" }
                $false 
            }
            else { 
                if ($log){ Write-Log -Path $log -Line "Returning $($samaccountname.ToLower()) as unique AD username" }
                Add-Member -InputObject $user -MemberType NoteProperty -Name 'SAMAccountName' -Value $samaccountname.ToLower()
                Add-Member -InputObject $user -MemberType NoteProperty -Name 'Email'          -Value $email.ToLower()
                $user
            }
        }
        else { 
            if ($log){ Write-Log -Path $log -Line "Returning $($samaccountname.ToLower()) as unique AD username" }
            Add-Member -InputObject $user -MemberType NoteProperty -Name 'SAMAccountName' -Value $samaccountname.ToLower()
            Add-Member -InputObject $user -MemberType NoteProperty -Name 'Email'          -Value $email.ToLower()
            $user
        }
    }

    end { 
        if ($log){ if($newlog) { Stop-Log -Path $log } }
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

FUNCTION Enable-SpamFilter {
<#
.SYNOPSIS 
    Adds user's email to spam filter
.DESCRIPTION
	This script emails the helpdesk as the user's email so that their SMTP address can be added to the spam filter
.PARAMETER  Username
	Requires a valid SAMAccountname, the new account being added to the spam filter
.EXAMPLE
    PS C:\> Enable-SpamFilter -Username rdevries
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/05/19
    Version     : 1
#>
    [CmdletBinding()]
    Param(
	    [Parameter(Position=0,Mandatory,HelpMessage="Enter the username for the new user",ValueFromPipeline)]
        [ValidateScript({Test-ADUser -Username $_})]
	    [string]$Username
    )

    begin {
        if (!(Get-Module ActiveDirectory)){ Import-Module ActiveDirectory }
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
    }
 
    process {
        $user           = Get-ADUser -Identity $username -Properties emailaddress
        $smtp_server    = "server.domain.com"
        $smtp_subject   = "Add $($user.EmailAddress) to Spam Filter"
        $smtp_recipient = "email@domain.com"
        Write-Verbose "Sending email to $smtp_recipient from $($user.EmailAddress)"
        try { 
            Send-MailMessage -SmtpServer $smtp_server -From $user.EmailAddress -To $smtp_recipient -Subject $smtp_subject -ErrorAction Stop
        }
        catch {
            Write-Verbose "ERROR SENDING EMAIL: $($_.Exception)"
        }
    }

    end { Write-Verbose "Ending $($MyInvocation.Mycommand)" }
}

FUNCTION Get-ADGroupApproval {
<#
.SYNOPSIS 
    Generates an approval email for a new user
.DESCRIPTION
	This script emails the person running it an approval email with a list of groups and a common message template, to be forwarded on to the account requester for approval
.PARAMETER  Username
	Requires a valid SAMAccountname, the new account being granted permissions
.PARAMETER  Approver
	Requires a valid SAMAccountname, the person who can approve of the access request
.PARAMETER  Like
	Requires a valid SAMAccountname to use to generate the group membership
.PARAMETER  Ask
	Optional, toggles whether or not the function prompts to add each group to the approval list
.PARAMETER  Log
	Optional, a path for a log file
.EXAMPLE
    PS C:\> Get-ADGroupApproval -Username rdevries -Like bneubaue -Approver tshulman
.EXAMPLE
    PS C:\> Get-ADGroupApproval -Username rdevries -Like manager -Approver tshulman
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
        [Parameter(Position=1,Mandatory,HelpMessage="Enter the username for the approver")]
        [ValidateScript({Test-ADUser -Username $_})]
	    [string]$Approver,
        [Parameter(Position=2,Mandatory,HelpMessage="Enter the username/rolename for the user/role to clone, or manager if no user/role is specified")]
        [ValidateNotNullorEmpty()]
	    [string]$Like,
        [Parameter(Position=3,Mandatory=$false,HelpMessage="Toggles prompting of groups")]
	    [switch]$Ask,
        [Parameter(Position=4,Mandatory=$false,HelpMessage="Enter the path of a log file to use")]
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
        $approvedgroups = @()
    }
 
    process {
        # Pull information about the executing user to use in the email signature
        Write-Verbose "Getting information about the executing user"
        $executingadmin  = Get-ADUser -Identity $env:USERNAME
        switch ($executingadmin.Surname){
            'REDACTED' {$nonadminuser = 'REDACTED'}
            'REDACTED' {$nonadminuser = 'REDACTED' }
            'REDACTED' {$nonadminuser = 'REDACTED'}
        }
        Write-Verbose "Setting up variables for $nonadminuser"
        $executingaduser = Get-ADUser -Identity $nonadminuser -Properties title, emailaddress, officephone
        $executingname   = $executingaduser.GivenName + " " + $executingaduser.Surname
        $executingphone  = $executingaduser.OfficePhone
        $executingtitle  = $executingaduser.Title
        $executingemail  = $executingaduser.EmailAddress
        # Pull information about the specified new user to use in the email body, and the manager for when a -like user doesn't exist, or is set to manager
        Write-Verbose "Setting up variables for $username"
        $newaduser       = Get-ADUser -Identity $username -Properties manager
        $newuserfirst    = $newaduser.GivenName
        $newusername     = $newaduser.GivenName + " " + $newaduser.Surname
        # Pull information about the specified approver to use in the email body
        Write-Verbose "Setting up variables for $approver"
        $approvaladuser  = Get-ADUser -Identity $approver -Properties emailaddress
        $approvalname    = $approvaladuser.GivenName + " " + $approvaladuser.Surname
        $approvalemail   = $approvaladuser.EmailAddress
        # Set up variables to use in the email message
        Write-Verbose "Setting up variables for email message"
        $smtp_server     = "exchange-mb1.manning-napier.com"
        $smtp_subject    = "User Account Setup for $newusername - Approval Required"
        # Sets the body message of the email, and the user who's group memmbership will be pulled based on the value of the -like parameter
        Write-Verbose "Determining what to use as the target for group membership"
        switch ($like){
            # Sets comparison user to the new user's manager
            'manager' {
                # Catch error if new user doesn't have a manager defined
                try { 
                    if ($log){ Write-Log -Path $log -Line "Using manager as the target" }
                    Write-Verbose "Using manager as the target"
                    $targetaduser = Get-ADUser -Identity $newaduser.manager -Properties memberof -ErrorAction Stop 
                }
                catch {
                    if ($log){ Write-Log -Path $log -Line "ERROR PULLING GROUP INFORMATION FOR MANAGER : $($_.Exception)" }
                    Write-Verbose "ERROR PULLING GROUP INFORMATION FOR MANAGER : $($_.Exception)"
                    throw $_
                }
                $targetfirst = $targetaduser.GivenName
                $targetname  = $targetaduser.GivenName + " " + $targetaduser.Surname
                $body        = @"
<h2 style='color:red'>Review below and forward to $approvalemail</h2>
<p>$approvalname,</p>
<p>We have received your request for an account for $newusername. Since no one was specified for $newuserfirst's account to be modeled after, I have pulled the membership of $newuserfirst's direct supervisor - $targetname.  Please review the below list of groups and mark which ones are appropriate for $newuserfirst. If you are unsure of whether an access group is appropriate for $newuserfirst then we recommend not adding them to that group at this time. This is because the groups provide access to various applications, websites, and email distribution lists.
</p>
<h3>$targetfirst's Groups:</h3>
"@
            }
            default   {
                # Sets comparison user to the new user's manager if the username specified for -like is invalid
                if ($log){ $exists = Test-ADUser -Username $like -Log $log } else { $exists = Test-ADUser -Username $like }
                if (!($exists)){
                    # Catch error if new user doesn't have a manager defined
                    try { 
                        if($log){ Write-Log -Path $log -Line "$like is not a valid user, using manager as the target" }
                        Write-Verbose "$like is not a valid user, using manager as the target"
                        $targetaduser = Get-ADUser -Identity $newaduser.manager -Properties memberof -ErrorAction Stop
                    }
                    catch {
                        if($log){ Write-Log -Path $log -Line "$like DOES NOT EXIST, ERROR PULLING GROUP INFORMATION FOR MANAGER : $($_.Exception)" }
                        Write-Verbose "$like DOES NOT EXIST, ERROR PULLING GROUP INFORMATION FOR MANAGER : $($_.Exception)"
                        throw $_
                    }
                    $targetfirst = $targetaduser.GivenName
                    $targetname  = $targetaduser.GivenName + " " + $targetaduser.Surname
                    $body        = @"
<h2 style='color:red'>Review below and forward to $approvalemail</h2>
<p>$approvalname,</p>
<p>We have received your request for an account for $newusername. Since the user specified ($like) does not exist for $newuserfirst's account to be modeled after, I have pulled the membership of $newuserfirst's direct supervisor - $targetname.  Please review the below list of groups and mark which ones are appropriate for $newuserfirst. If you are unsure of whether an access group is appropriate for $newuserfirst then we recommend not adding them to that group at this time. This is because the groups provide access to various applications, websites, and email distribution lists.
</p>
<h3>$targetfirst's Groups:</h3>
"@
                }
                # Sets comparison user to the username specified for -like
                else { 
                    if ($log){ Write-Log -Path $log -Line "Using $like as the target" }
                    Write-Verbose "Using $like as the target"
                    $targetaduser = Get-ADUser -Identity $like -Properties memberof
                    $targetfirst  = $targetaduser.GivenName
                    $targetname   = $targetaduser.GivenName + " " + $targetaduser.Surname
                    $body         = @"
<h2 style='color:red'>Review below and forward to $approvalemail</h2>
<p>$approvalname,</p>
<p>We have received your request to setup $newusername's account like $targetname. Below is a list of the access groups that $targetfirst is currently a member of. Please review this list and verify whether or not these are the groups that $newuserfirst should be a member of. If you are unsure of whether an access group is appropriate for $newuserfirst then we recommend not adding them to that group at this time. This is because the groups provide access to various applications, websites, and email distribution lists.</p>
<h3>$targetfirst's Groups:</h3>
"@
                }
            }
        }
        # Formats the HTML table with borders and padding
        $head        = @"
<style>
    TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
    TH{border-width: 1px;padding: 5px;border-style: solid;border-color: black;background-color:grey}
    TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black;}
</style>
"@
        # Adds a signature after the HTML table
        $postcontent = @"
<p>Please don't hesitate to ask if you have any questions regarding this.</p>
<p>Thank you,</p>
<span style='font-size:12.0pt;font-family:"Georgia","serif";color:#007934'>$executingname</span>
<br>
<span style='font-size:9.0pt;font-family:"Helvetica","sans-serif";color:#262626'>$executingtitle</span>
<span style='font-size:9.0pt;font-family:"Helvetica","sans-serif";color:#666666'><br><br></span>
<b><span style='font-size:9.0pt;font-family:"Helvetica","sans-serif";color:#262626'>Company</span></b>
<span style='font-size:9.0pt;font-family:"Helvetica","sans-serif";color:#666666'><br><br></span>
<span style='font-size:9.0pt;font-family:"Arial","sans-serif";color:#262626'>###-###-#### x$executingphone</span>
<span style='font-size:9.0pt;font-family:"Arial","sans-serif";color:#007934'> | </span>
<span style='font-size:9.0pt;font-family:"Arial","sans-serif";color:#262626'>phone</span>
<br>
<span style='color:#1F497D'><a href="mailto:$executingemail"><span style='font-size:9.0pt;font-family:"Helvetica","sans-serif"'>$executingemail</span></a></span>
<br>
<span style='font-size:9.0pt;font-family:"Helvetica","sans-serif";color:#007934'>
	<a href="http://www.website.com/"><span style='color:#007934;text-decoration:none'>Web</span></a>
    <span> | </span> 
    <a href="https://twitter.com/account"><span style='color:#007934;text-decoration:none'>Twitter</span></a>
    <span> | </span> 
    <a href="https://www.website.com/Blog"><span style='color:#007934;text-decoration:none'>Blog</span></a>
    <span> | </span> 
    <a href="http://www.website.com/Newsletter"><span style='color:#007934;text-decoration:none'>Newsletters</span></a>
</span>
"@
        # Pulls the group information of the comparison user, filtering out Domain Users
        if ($log){ Write-Log -Path $log -Line "Getting the group membership for $($targetaduser.SAMAccountname).  Full user information:$((Get-ADUser -Identity $targetaduser.SAMAccountname | out-string).TrimEnd())`r`n" }
        Write-Verbose "Getting the group membership for $targetname"
        $groups  = $targetaduser.MemberOf | Get-ADGroup -Properties name,description | Where-Object name -NotLike "Domain Users" | Sort-Object name | Select-Object -Property name,description
        if ($log){ Write-Log -Path $log -Line ("Getting listing of groups $($targetaduser.SAMAccountname) is a member of`r`n`r`nListing of groups $($targetaduser.SAMAccountname) is a member of (except Domain Users):`r`n--------------------------------------------------------------------`r`n" + ($groups.name | Out-String)) }
        $prompt  = $true
        $yes     = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Adds the group to the approval list."
        $no      = New-Object System.Management.Automation.Host.ChoiceDescription "&No",  "Skips the group without adding to the approval list."
        $all     = New-Object System.Management.Automation.Host.ChoiceDescription "&All", "Adds all remaining groups to the approval list."
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $all)
        if ($log){ Write-Log -Path $log -Line "Adding groups to approval list" }
        # Prompts user for confirmation on each group if -ask is specified
        if ($ask){
            if ($log){ Write-Log -Path $log -Line "-Ask specified, entering approval mode" }
            Write-Verbose "-Ask specified, entering approval mode"
            foreach ($group in $groups){
                if ($prompt){
                    $title   = "Add group to approval list"
                    $message = "Do you want to add $($group.name) to the list of groups to get approved?`r`nDescription: $($group.description)"
                    $result  = $host.ui.PromptForChoice($title, $message, $options, 0)
                    switch ($result){
                        0 { Write-Verbose "Adding $($group.name) to approval list" 
                            $approvedgroup = New-Object -TypeName PSObject
                            Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Group:'          -Value $group.Name
                            Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Description:'    -Value $group.Description
                            Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Group Required?' -Value ""
                            $approvedgroups += $approvedgroup
                            if ($log){ Write-Log -Path $log -Line "Action: Added  `t`tPrompt: Yes`t`tGroup: $($group.name)" }
                        }
                        1 { 
                            Write-Verbose "Skipping $($group.name)"
                            if ($log){ Write-Log -Path $log -Line "Action: Skipped`t`tPrompt: Yes`t`tGroup: $($group.name)" }
                        }
                        2 { Write-Verbose "Adding $($group.name) to approval list"
                            $approvedgroup = New-Object -TypeName PSObject
                            Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Group:'          -Value $group.Name
                            Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Description:'    -Value $group.Description
                            Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Group Required?' -Value ""
                            $approvedgroups += $approvedgroup
                            if ($log){ Write-Log -Path $log -Line "Action: Added  `t`tPrompt: Yes`t`tGroup: $($group.name)" }
                            $prompt = $false
                            if ($log){ Write-Log -Path $log -Line "Action: All    `t`tPrompt: Disabled" }
                        }
                    }
                }
                else { 
                    Write-Verbose "Skipping prompt for $($group.name)" 
                    $approvedgroup = New-Object -TypeName PSObject
                    Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Group:'          -Value $group.Name
                    Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Description:'    -Value $group.Description
                    Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Group Required?' -Value ""
                    $approvedgroups += $approvedgroup
                    if ($log){ Write-Log -Path $log -Line "Action: Added  `t`tPrompt: No `t`tGroup: $($group.name)" }
                }
            }
        }
        # Automatically adds all groups if -ask is not specified
        else {
            if ($log){ Write-Log -Path $log -Line "-Ask not specified, skipping approval" }
            Write-Verbose "-Ask not specified, skipping approval" 
            foreach ($group in $groups){                
                $approvedgroup = New-Object -TypeName PSObject
                Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Group:'          -Value $group.Name
                Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Description:'    -Value $group.Description
                Add-Member -InputObject $approvedgroup -MemberType NoteProperty -Name 'Group Required?' -Value ""
                $approvedgroups += $approvedgroup
                if ($log){ Write-Log -Path $log -Line "Action: Added  `t`tPrompt: No `t`tGroup: $($group.name)" }
            }
        }
        # Creates an HTML table from the approved groups and sandwiches it between a message and a signature
        Write-Verbose "Creating HTML table for selected groups:"
        Write-Verbose ($approvedgroups | Out-String)
        $html = $approvedgroups | ConvertTo-Html -Head $head -Body $body -PostContent $postcontent
        # Tries to send the approval email to the executing user for review
        Write-Verbose "Sending email from $executingemail to $executingemail for review"
        try { 
            Send-MailMessage -SmtpServer $smtp_server -From $executingemail -To $executingemail -Subject $smtp_subject -BodyAsHtml ($html | Out-String) -ErrorAction Stop
            if ($log){ Write-Log -Path $log -Line "Sent email from $executingemail to $executingemail for review" }
        }
        catch {
            if ($log){ Write-Log -Path $log -Line "ERROR SENDING EMAIL: $($_.Exception)" }
            Write-Verbose "ERROR SENDING EMAIL: $($_.Exception)"
        }
    }

    end { 
        if ($log){ if($newlog) { Stop-Log -Path $log } }
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
        Remove-Variable groups -ErrorAction SilentlyContinue
        Remove-Variable html   -ErrorAction SilentlyContinue
    }
}

FUNCTION New-HomeFolder {
<#
.SYNOPSIS 
    Creates a home folder for a user
.DESCRIPTION
	Creates a home folder for a user and assigns appropriate permissions to it.
.PARAMETER  Path
	Indicate the location, where these folders will be created.
.PARAMETER  Username
	Indicate a username
.PARAMETER  Log
	Optional, a path for a log file
.EXAMPLE
    PS C:\> New-HomeFolder -Path "c:\test" -Username "rdevries"
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/05/19
    Version     : 1
.LINK
	http://msdn.microsoft.com/en-us/library/ms147785(v=vs.90).aspx
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory,HelpMessage="Enter the root path for home directories")]
        [ValidateScript({Test-Path $_ -PathType Container})]
	    [string]$Path,
        [Parameter(Position=1,Mandatory,HelpMessage="Enter a username",ValueFromPipeline)]
        [ValidateScript({Test-ADUser -Username $_})]
        [string]$Username,
        [Parameter(Position=2,Mandatory=$false,HelpMessage="Enter the path of a log file to use")]
        [ValidateScript({Test-Path (Split-Path $_ -Parent) -PathType Container})]
	    [string]$Log
    )

    begin { # Configure environment, set up logging, initialize variables
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
        Write-Verbose "Getting ACL for $path"
	    $HomeFolderACL = (Get-Item $Path).GetAccessControl('Access')
	    $HomeFolderACL.SetAccessRuleProtection($false,$true)
		Write-Verbose "Creating $Path\$username if it doesn't exist"
        if (-not (Test-Path "$Path\$username")){ 
            try {
                New-Item -ItemType directory -Path "$Path\$username" > $null 
                if($log){ Write-Log -Path $log -Line "Created directory $Path\$username" }
            }
            catch {
                if($log){ Write-Log -Path $log -Line "ERROR CREATING DIRECTORY $Path\$username : $($_.Exception)" }
                Write-Verbose "ERROR CREATING DIRECTORY $Path\$username : $($_.Exception)"
                throw $_
            }
        }
        else { if ($log){ Write-Log -Path $log -Line "$Path\$username already exists, using existing directory" } }
		Write-Verbose "Creating new ACL"
        try {
            $ACL = New-Object System.Security.AccessControl.FileSystemAccessRule($username,"Modify","ContainerInherit,ObjectInherit","None","Allow")
		    $HomeFolderACL.AddAccessRule($ACL)
            Write-Verbose "Setting new ACL"
		    Set-Acl -Path "$Path\$username" $HomeFolderACL -ErrorAction Stop
            if($log){ Write-Log -Path $log -Line ("Applied ACL to $Path\$username :" + ($ACL | Out-String).TrimEnd()) }
        }
        catch {
            if ($log){ Write-Log -Path $log -Line "ERROR APPLYING ACL TO $Path\$username : $($_.Exception)" }
            Write-Verbose "ERROR APPLYING ACL TO $Path\$username : $($_.Exception)"
            throw $_
        }
    }

    end { 
        if ($log){ if($newlog) { Stop-Log -Path $log } }
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

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

FUNCTION New-StandardADUser {
<#
.SYNOPSIS 
    Creates a standard  User
.DESCRIPTION
    Generates a valid username, creates the AD account/Exchange mailbox, emails the helpdesk to add an exception to the spam filter, creates and assigns permissions to a home directory, generates approval email for AD groups
	Dependendencies  : Active Directory module, Exchange Snapin, permissions to create mailboxes/users, permissions to create folders at $homedirectoryroot
.PARAMETER  HomeDirectoryRoot
	Optional, when specified creates the user's home directory and assigns permissions at the specified root path
.PARAMETER  Log
	Requires a path for log files to be generated
.PARAMETER  Bulk
	Optional, if specified requires -CSVPath to be specified as well for bulk operation
.PARAMETER  CSVPath
	Requires valid CSV file path if -Bulk is specified
.EXAMPLE
    PS C:\> New-StandardADUser -Log "C:\Temp\Users" -Bulk -CSVPath "C:\Temp\Users\NewUsers.csv"
.EXAMPLE
    PS C:\> New-StandardADUser -HomeDirectoryRoot "\\file\users$" -Log "C:\Temp\Users" -Bulk -CSVPath "C:\Temp\Users\NewUsers.csv"
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/05/19
    Version     : 1
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,HelpMessage="Creates the user(s)'s home directory and assigns permissions")]
        [ValidateScript({Test-Path $_ -PathType Container})]
	    [string]$HomeDirectoryRoot,
        [Parameter(Position=1,Mandatory,HelpMessage="Enter the path of where to create log(s)")]
        [ValidateScript({Test-Path $_ -PathType Container})]
	    [string]$Log,
        [Parameter(ParameterSetName='BulkParameters',Mandatory=$false,HelpMessage="Specifies bulk create mode")]
	    [switch]$Bulk,
        [Parameter(ParameterSetName='BulkParameters',Mandatory,HelpMessage="Path to bulk load CSV file")]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
	    [string]$CSVPath
    )

    begin { # Configure environment, set up logging, initialize variables
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        if (!(Get-Module   -Name Logging-Functions)){ Import-Module Logging-Functions -ErrorAction Stop }
        if (!(Get-Module   -Name ActiveDirectory))  { Import-Module ActiveDirectory   -ErrorAction Stop }
        if ( (Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.Admin -ErrorAction SilentlyContinue) -eq $null){ Add-PsSnapin Microsoft.Exchange.Management.PowerShell.Admin }
        $processlog = "New User Creation - $(get-date -f s).log" -replace ":",""
        Write-Verbose "Starting log at $log\$processlog"
        Start-Log -Path $log -Name $processlog
        # Variables
        $addomain          = 'domain.com'
        $maildomain        = 'domain.com'
        $domaincontroller  = 'DC'
        $homedirectory     = 'F:'
        $loginscript       = 'login.bat'
        $mbxdb1            = 'MBX1'
        $mbxdb2            = 'MBX2'
    }
 
    process {
        # TODO: Add CSV validation
        if ($bulk){
            Write-Log     -Path "$log\$processlog" -Line "Entering bulk mode using CSV file : $csvpath"
            Write-Verbose "Entering bulk mode using CSV file : $csvpath"
            $users = Import-CSV $csvpath
        }
        else {
            $users = @()
            $manualuser  = New-Object -TypeName PSObject
            Write-Log     -Path "$log\$processlog" -Line "Entering single user mode, prompting for variables"
            Write-Verbose "Entering single user mode, prompting for variables"
            # Read in all variables
            $firstname      = Read-Host "First Name"
            $middleinitial  = Read-Host "Middle Initial"
            $lastname       = Read-Host "Last Name"
            $password       = Read-Host "Password" -AsSecureString
            $path           = Read-Host "Organizational Unit"
            $description    = Read-Host "Description"
            $office         = Read-Host "Office"     
            $title          = Read-Host "Title"      
            $phone          = Read-Host "Phone"      
            $department     = Read-Host "Department"
            $city           = Read-Host "City"
            $warning = ''; do { Write-Host -noNewLine $warning; $path           = Read-Host "Organizational Unit";              $warning = 'Invalid OU. ';                     } while (!(Test-ADOU   -Path     $path    ))
            $warning = ''; do { Write-Host -noNewLine $warning; $manager        = Read-Host "Manager SAM Account";              $warning = 'Invalid Manager SAM Account. ';    } while (!(Test-ADUser -Username $manager ))
            $warning = ''; do { Write-Host -noNewLine $warning; $target         = Read-Host "Target User to Clone SAM Account"; $warning = 'Invalid Target User SAM Account. ';} while (!(Test-ADUser -Username $target  ))
            $warning = ''; do { Write-Host -noNewLine $warning; $approver       = Read-Host "Approver SAM Account";             $warning = 'Invalid Approver SAM Account. ';   } while (!(Test-ADUser -Username $approver))
            Write-Verbose "Creating object with members that match the input"
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'FirstName'     -Value $firstname
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'MiddleInitial' -Value $middleinitial
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'LastName'      -Value $lastname
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'Password'      -Value $password
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'Path'          -Value $path
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'Description'   -Value $description
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'Office'        -Value $office
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'Title'         -Value $title
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'Phone'         -Value $phone
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'Department'    -Value $department
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'Manager'       -Value $manager
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'City'          -Value $city
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'Target'        -Value $target
            Add-Member -InputObject $manualuser -MemberType NoteProperty -Name 'Approver'      -Value $approver
            $users += $manualuser
        }
        # Looping through each user
        foreach ($user in $users){
            Write-Log     -Path "$log\$processlog" -Line "Processing $($user.FirstName) $($user.LastName)"
            Write-Verbose "Processing $($user.FirstName) $($user.LastName)"
            $userlog    = "$($user.FirstName) $($user.LastName) $(get-date -f s).log" -replace ":",""
            if ($user.MiddleInitial -eq ''){ 
                Write-Verbose "No middle initial specified"
                $samaccount = Set-ADUsername -Firstname $user.FirstName -Lastname $user.LastName -Domain $maildomain -Log "$log\$processlog" 
            }
            else {
                Write-Verbose "Middle initial specified"
                $samaccount = Set-ADUsername -Firstname $user.FirstName -Middleinitial $user.MiddleInitial -Lastname $user.LastName -Domain $maildomain -Log "$log\$processlog" 
            }
            # Only continue working on user if a valid account name was able to be generated
            if ($samaccount){
                Start-Log     -Path $log -Name $userlog
                Write-Log     -Path "$log\$processlog" -Line "Logging user-specific information to $userlog"
                # Validate parameters
                try {
                    # Validate OU
                    if (!(Test-ADOU   -Path     $user.Path))     { 
                        Write-Log     -Path "$log\$userlog"    -Line "Error validating parameters for $samaccountname. Invalid OU in CSV. Skipping $samaccount"
                        Write-Verbose "Error validating parameters for $samaccountname. Invalid OU in CSV. Skipping $samaccount"
                        throw         "Invalid OU $($user.Path) in CSV. Skipping $samaccount"
                    }
                    # Validate Manager SAM Account
                    if (!(Test-ADUser -Username $user.Manager))  { 
                        Write-Log     -Path "$log\$userlog"    -Line "Error validating parameters for $samaccountname. Invalid Manager SAM Account in CSV. Skipping $samaccount"
                        Write-Verbose "Error validating parameters for $samaccountname. Invalid OU in CSV. Skipping $samaccount"
                        throw         "Invalid Manager SAM Account $($user.Manager) in CSV. Skipping $samaccount"
                    }
                    # Validate Approver SAM Account
                    if (!(Test-ADUser -Username $user.Approver)) { 
                        Write-Log     -Path "$log\$userlog"    -Line "Error validating parameters for $samaccountname. Invalid Approver SAM Account in CSV. Skipping $samaccount"
                        Write-Verbose "Error validating parameters for $samaccountname. Invalid OU in CSV. Skipping $samaccount"
                        throw         "Invalid Approver SAM Account $($user.Approver) in CSV.  Skipping $samaccount"
                    }
                    # Validate Target SAM Account if not empty string
                    if (!($user.Target -eq '')) { 
                        if (!(Test-ADUser -Username $user.Target)) { 
                            Write-Log     -Path "$log\$userlog"    -Line "Error validating parameters for $samaccountname. Invalid Target User SAM Account in CSV. Skipping $samaccount"
                            Write-Verbose "Error validating parameters for $samaccountname. Invalid OU in CSV. Skipping $samaccount"
                            throw         "Invalid Target User SAM Account $($user.Target) in CSV. Skipping $samaccount"
                        }
                    }
                }
                catch {
                    Write-Error $_.Exception -Category InvalidArgument
                    Stop-Log    -Path "$log\$userlog"
                    # Continue processing users even if there is an error with one
                    continue 
                }
                Write-Log     -Path "$log\$userlog"    -Line "Processing $samaccountname"
                Write-Verbose "Processing $samaccountname"
                $samaccountname    = $samaccount.SAMAccountName
                $email             = $samaccount.Email
                $userprinciplename = $samaccountname + "@" + $addomain                    
                # Set mailbox database based on first letter of last name
                if (($user.LastName).substring(0,1) -match '[a-mA-M]'){ $database = $mbxdb1 } 
                if (($user.LastName).substring(0,1) -match '[m-zM-Z]'){ $database = $mbxdb2 }
                try {
                    $displayname = "$($user.FirstName) $($user.LastName)"
                    if ($bulk){ 
                        Write-Verbose "Converting password from CSV to secure string"
                        $password = ConvertTo-SecureString -string $user.Password -AsPlainText -Force 
                    }
                    else { $password = $user.Password }
                    # Create the user
                    Write-Verbose "Creating $samaccountname mailbox"
                    New-Mailbox                                      `
                        -DomainController         $domaincontroller  `
                        -UserPrincipalName        $userprinciplename `
                        -SamAccountName           $samaccountname    `
                        -OrganizationalUnit       $user.Path         `
                        -Database                 $database          `
                        -FirstName                $user.FirstName    `
                        -LastName                 $user.LastName     `
                        -DisplayName              $displayname       `
                        -Alias                    $samaccountname    `
                        -Name                     $samaccountname    `
                        -Password                 $password          `
                        -ResetPasswordOnNextLogon $false             `
                        -ErrorAction              Stop
                    Write-Log     -Path "$log\$userlog" -Line ("Created $samaccountname mailbox, sleeping for 60 seconds to allow for replication :" + "(Get-Mailbox -Identity $samaccountname | Out-String)")
                    Write-Verbose "Created $samaccountname mailbox, sleeping for 60 seconds to allow for replication"
                    Write-Verbose ("Get-Mailbox -Identity $samaccountname | Out-String")
                    # Sleep to allow for replication   
                    Start-Sleep -Seconds 60
                    # Set email address
                    Write-Verbose "Setting default reply for $samaccountname mailbox"
                    Set-Mailbox                                    `
                        -Identity                  $samaccountname `
                        -EmailAddressPolicyEnabled $false          `
                        -PrimarySMTPAddress        $email          `
                        -ErrorAction               Stop
                    Write-Log     -Path "$log\$userlog" -Line "Added $email as the default reply address for $samaccountname"
                    Write-Verbose "Added $email as the default reply address for $samaccountname"
                    Write-Verbose "Setting login script based on city"
                    switch ($user.City){
                        'St. Petersburg' {
                            $loginscript = 'stpetelogin.bat'
                            Write-Verbose "Location detected as St. Petersburg, using $loginscript for login script" 
                            Write-Log     -Path "$log\$userlog" -Line "Location detected as St. Petersburg, using $loginscript for login script" 
                        }
                        'Dublin'         {
                            $loginscript = 'ohiologin.bat'
                            Write-Verbose "Location detected as Dublin, using $loginscript for login script"
                            Write-Log     -Path "$log\$userlog" -Line "Location detected as Dublin, using $loginscript for login script" 
                        }
                        default          {
                            Write-Verbose "Location not identified as having a specific script, using $loginscript for login script"
                            Write-Log     -Path "$log\$userlog" -Line "Location not identified as having a specific script, using $loginscript for login script" 
                        }
                    }
                    # Set all other AD properties   
                    Write-Verbose "Setting user properties for $samaccountname"
                    Set-ADUser                         `
                        -Identity    $samaccountname   `
                        -Description $user.Description `
                        -Office      $user.Office      `
                        -Title       $user.Title       `
                        -OfficePhone $user.Phone       `
                        -Department  $user.Department  `
                        -Manager     $user.Manager     `
                        -ScriptPath  $loginscript      `
                        -City        $user.City        `
                        -ErrorAction Stop
                    Write-Log         -Path "$log\$userlog" -Line "Added user properties for $samaccountname"
                    Write-Verbose     "Added user properties for $samaccountname"
                    # Send email to helpdesk to have user's email added to spam exceptions                      
                    Enable-SpamFilter -Username $samaccountname
                    Write-Log         -Path "$log\$userlog" -Line "Emailed helpdesk to add spam exception for $email"
                    Write-Verbose     "Emailed helpdesk to add spam exception for $email"
                    # Generate email with group approvals with prompt   
                    if ($user.Target -ne ''){ 
                        Write-Log      -Path "$log\$userlog" -Line "Generating approval email for $samaccountname"
                        Write-Verbose  "Generating approval email for $samaccountname"
                        Get-ADGroupApproval -Username $samaccountname -Like $user.Target -Approver $user.Approver -Log "$log\$userlog" -Ask
                    }
                    else {
                        Write-Log      -Path "$log\$userlog" -Line "Blank target specified, skipping approval email since no access is requested"
                        Write-Verbose  "Blank target specified, skipping approval email since no access is requested"
                    }
                    # Create home directory, assign permissions, and add in AD if specified
                    if ($homedirectoryroot){ 
                        New-HomeFolder -Path $homedirectoryroot -Username $samaccountname
                        Set-ADUser     -Identity $samaccountname -HomeDrive $homedirectory -HomeDirectory "$homedirectoryroot\%username%" -ErrorAction Stop
                        Write-Log      -Path "$log\$userlog" -Line "Added home directory properties for $samaccountname"
                        Write-Verbose  "Added home directory properties for $samaccountname"
                    }
                }
                catch {
                    Write-Log   -Path "$log\$processlog" -Line "ERROR CREATING $samaccountname : $($_.Exception)"
                    Write-Log   -Path "$log\$userlog"    -Line "ERROR CREATING $samaccountname : $($_.Exception)"
                    Stop-Log    -Path "$log\$userlog"
                    Write-Error "Error creating $samaccountname : $($_.Exception)"
                    # Continue processing users even if there is an error with one
                    continue
                }
                Stop-Log -Path "$log\$userlog"
            }
            else { 
                Write-Log   -Path "$log\$processlog" -Line "ERROR GENERATING USERNAME FROM -Firstname $($user.FirstName) -Middleinitial $($user.MiddleInitial) -Lastname $($user.LastName), SKIPPING"
                Write-Error "Error generating username from -Firstname $($user.FirstName) -Middleinitial $($user.MiddleInitial) -Lastname $($user.LastName), Skipping" -Category InvalidData
            }
        }
    }

    end { 
        Stop-Log -Path "$log\$processlog"
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}
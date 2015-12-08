FUNCTION Get-SqlWeakPasswords {
<#
.SYNOPSIS 
    Gets SQL logins with weak/missing passwords
.DESCRIPTION
	Dependendencies  : SQLPS Module, SQL Server 2000+
    SQL Permissions  : sysadmin or maybe securityadmin on each instance
.PARAMETER  Instance
	The name of the instance you wish to check connections to
.PARAMETER  Passwords
	The passwords you wish to check for
.EXAMPLE
    PS C:\> Get-SqlWeakPasswords -Instance DEV-MSSQL
    PS C:\> Get-SqlWeakPasswords -Instance DEV-MSSQL -Passwords (Get-Content C:\temp\passwords.txt)
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/12/08
    Version     : 1
.INPUTS
    [string]
.OUTPUTS
    [array]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage="Name of the instance(s) to check, leave off for all instances")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
	    [string[]]$Instance,
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Passwords to check")]
        [ValidateNotNullOrEmpty()]
	    [string[]]$Passwords
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $totalLogins = @()
        # These queries return all logins with weak passwords
        $get_weakloginpasswords_query = @"
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], name AS [Login], create_date AS [Created], modify_date AS [Modified], 
CASE WHEN PWDCOMPARE('',password_hash)=1 THEN 'Blank' WHEN PWDCOMPARE(name,password_hash)=1 THEN 'Matches Name' ELSE 'Matches Simple' END AS [Reason]
FROM sys.sql_logins 
WHERE PWDCOMPARE('',password_hash)=1
OR PWDCOMPARE(name,password_hash)=1
"@
        $get_weakloginpasswords_SQL2000_query = @"
-- SQL 2000
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], name AS [Login], createdate AS [Created], updatedate AS [Modified], 
CASE WHEN password is null THEN 'Blank' WHEN PWDCOMPARE('',password)=1 THEN 'Blank' WHEN PWDCOMPARE(name,password)=1 THEN 'Matches Name' ELSE 'Matches Simple' END AS [Reason]
FROM dbo.syslogins 
WHERE isntname = 0 AND (
password IS NULL 
OR PWDCOMPARE(password,'')=1
OR PWDCOMPARE(name,password)=1
"@        
    }
 
    process {
        if ($instance){
            $instances  = @()
            foreach ($inst in $instance){
                Write-Verbose "Adding $inst to processing array..."
                $version    = Invoke-Sqlcmd -ServerInstance $inst -query "SELECT SERVERPROPERTY('ProductVersion') AS [SQLBuildNumber]" -connectiontimeout 5
                $holder     = New-Object -TypeName PSObject
                Add-Member -InputObject $holder -MemberType NoteProperty -Name 'InstanceName'   -Value $inst
                Add-Member -InputObject $holder -MemberType NoteProperty -Name 'SQLBuildNumber' -Value $version.SQLBuildNumber
                $instances += $holder
            }
        }
        else {
            # Pull all SQL instances from Server Inventory
            Write-Progress -Activity "Pulling instances..." -Status "Percent Complete: 0%" -PercentComplete 0
            $instances = Get-SqlInstances
        }
        if ($passwords){
            foreach ($password in $passwords){
                $password = $password.Replace("'","''")
                Write-Verbose "Adding $password to query..."
                $get_weakloginpasswords_query         += "`nOR PWDCOMPARE('$password',password_hash)=1"
                $get_weakloginpasswords_SQL2000_query += "`nOR PWDCOMPARE('$password',password)=1"
            }
            $get_weakloginpasswords_SQL2000_query += "`n)"
        }
        else {
            $get_weakloginpasswords_SQL2000_query += "`n)"
        }
        $totalstep = ($instances.Count * 2) + 1
        $stepnum   = 0
        # Loop through each instance
        foreach ($inst in $instances){
            $instancename  = $inst.InstanceName
            $instancebuild = $inst.SQLBuildNumber
            Write-Verbose "Checking $instancename for compatibility..."
            $stepnum++
            Write-Progress -Activity "Processing $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
            # Breaks the full build number down into just the major build (first decimal)
            $instancebuild = [Decimal]$instancebuild.Remove(($instancebuild | select-string "\." -allmatches).matches[1].Index, $instancebuild.Length - ($instancebuild | select-string "\." -allmatches).matches[1].Index)
            if ($instancebuild -lt 9){
                Write-Verbose "Processing $instancename..."
                Write-Progress -Activity "Running query against $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
                $totalLogins += Invoke-Sqlcmd -serverinstance $instancename -query $get_weakloginpasswords_SQL2000_query -connectiontimeout 5
            } 
            else {
                Write-Verbose "Processing $instancename..."
                $stepnum++
                Write-Progress -Activity "Running query against $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
                $totalLogins += Invoke-Sqlcmd -serverinstance $instancename -query $get_weakloginpasswords_query         -connectiontimeout 5              
            }    
        }
    }

    end { 
        $stepnum++
        Write-Progress -Activity "Outputting/returning results..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
        $totalLogins
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}
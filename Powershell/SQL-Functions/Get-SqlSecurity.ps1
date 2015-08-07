FUNCTION Get-SqlSecurity {
<#
.SYNOPSIS 
    Gets Security Information for SQL instances/databases
.DESCRIPTION
	Dependendencies  : SQLPS Module, SQL Server 2005+
    SQL Permissions  : sysadmin or maybe securityadmin on each instance

    Step 0     : Import SQLPS Module
    Step 1     : Pull list of SQL instances from [$inventoryinstance].[$inventorydatabase].[dbo].[SQLInstances]
    Step 2     : Connect to each of the pulled SQL instances
    Step 3     : Pull security information for each instance and write to CSV
    Step 4     : Write CSV report of aggregate data for all instances processed
.PARAMETER  Instance
	The name of the instance you wish to check connections to
.EXAMPLE
    PS C:\> Get-SqlSecurity -Instance DEV-MSSQL
.NOTES
    Author      : Ryan DeVries
    Last Updated: 2015/06/16
    Version     : 2
.INPUTS
    [string]
.OUTPUTS
    [array]
#>
    [CmdletBinding()]
    Param(
        [Parameter(Position=0,Mandatory=$false,ValueFromPipeline,ValueFromPipelineByPropertyName,HelpMessage="Name of the instance(s) to check, leave off for all production instances")]
        [ValidateScript({Test-SqlConnection -Instance $_})]
	    [string[]]$Instance,
        [Parameter(Position=1,Mandatory=$false,HelpMessage="Location to output CSV reports, leave off to only output an object")]
        [ValidateScript({Test-Path $_ -PathType Container})]
	    [string]$ReportPath,
        [Parameter(Position=2,Mandatory=$false,HelpMessage="Returns an object with selected information (logins/users, role memberships, or explicit permissions)")]
        [ValidateSet("Security","Roles","Permissions")]
	    [string]$Output
    )
 
    begin {
        Import-SQLPS
        Write-Verbose "Detected parameter set $($PSCmdlet.ParameterSetName)"
        $scriptstring = "Starting $($MyInvocation.MyCommand)"
        foreach ($param in $PSBoundParameters.GetEnumerator()){ $scriptstring += " -$($param.key) $($param.value)"}
        Write-Verbose $scriptstring
        $totalSecurity    = @()
        $totalRoleMembers = @()
        $totalPermissions = @()
        $date             = (get-date).ToString("yyyyMMdd_hhmmss")
        # This query returns all enabled databases on the instance
        $get_databases_query           = @"
SELECT [name] FROM sys.databases WHERE [state] = 0
"@
        # This query returns the server-level logins
        $get_serverSecurity_query      = @"
IF OBJECT_ID('tempdb..#InvalidLogins') IS NOT NULL
	DROP TABLE #InvalidLogins
CREATE TABLE #InvalidLogins ([SID] VARBINARY(85), [NT Login] sysname)
INSERT INTO #InvalidLogins
EXEC [sys].[sp_validatelogins]

SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], pe.[name] AS [UserName], sl.[name] AS [LoginName], pe.[type_desc] AS [UserType], CASE WHEN il.[sid] IS NULL THEN NULL ELSE 'Yes' END AS [Orphaned], NULL AS [DefaultSchema],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'CREATE LOGIN ' + QUOTENAME(pe.[name]) COLLATE database_default + CASE WHEN sl.[isntname] = 1 THEN ' FROM WINDOWS WITH DEFAULT_DATABASE=' + QUOTENAME(pe.[default_database_name]) COLLATE database_default ELSE ' WITH PASSWORD=N''CHANGEME'' MUST_CHANGE, DEFAULT_DATABASE=' + QUOTENAME(pe.[default_database_name]) COLLATE database_default + ', CHECK_EXPIRATION=ON, CHECK_POLICY=ON' END AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'DROP LOGIN '   + QUOTENAME(pe.[name]) COLLATE database_default AS [DropTSQL]
FROM master.sys.server_principals AS pe
LEFT JOIN master.sys.syslogins AS sl ON pe.[sid] = sl.[sid]
LEFT JOIN #InvalidLogins AS il ON pe.[sid] = il.[sid]
WHERE pe.[type] IN ('U', 'S', 'G')
ORDER BY [UserType], [UserName]
"@
        # This query returns the database-level users
        $get_databaseSecurity_query    = @"
-- Users and Groups
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], pe.[name] AS [UserName], sl.[name] AS [LoginName], pe.[type_desc] AS [UserType], CASE WHEN sl.[sid] IS NULL THEN 'True' ELSE 'False' END AS [Orphaned], pe.[default_schema_name] AS [DefaultSchema], 
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'CREATE USER ' + QUOTENAME(pe.[name]) COLLATE database_default + ' FOR LOGIN ' + QUOTENAME(sl.[name]) COLLATE database_default + CASE WHEN pe.[default_schema_name] IS NULL THEN '' ELSE ' WITH DEFAULT_SCHEMA = ' + QUOTENAME(pe.[default_schema_name]) COLLATE database_default END AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'DROP USER '   + QUOTENAME(pe.[name]) COLLATE database_default AS [DropTSQL]
FROM sys.database_principals AS pe
LEFT JOIN master.sys.syslogins AS sl ON pe.[sid] = sl.[sid]
WHERE pe.[type] IN ('U', 'S', 'G')
UNION ALL
-- Roles
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], [name] AS [UserName], NULL AS [LoginName], 'Role' AS [UserType], NULL AS [Orphaned], default_schema_name AS [DefaultSchema], 
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'CREATE ROLE '+ QUOTENAME([name]) COLLATE database_default AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'DROP ROLE '  + QUOTENAME([name]) COLLATE database_default AS [DropTSQL]
FROM sys.database_principals
WHERE [principal_id] > 4 
AND [is_fixed_role] <> 1
AND [type] = 'R'
ORDER BY [UserType], [UserName]
"@
        # This query returns the server role memberships
        $get_serverRoleMembers_query   = @"
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], spr.[name] AS [RoleName], spm.[name] AS [UserName], spm.[type_desc] AS [UserType], 
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_addsrvrolemember @rolename = '  + QUOTENAME(spr.[name], '''') COLLATE database_default + ', @membername = ' + QUOTENAME(spm.[name], '''') COLLATE database_default AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_dropsrvrolemember @rolename = ' + QUOTENAME(spr.[name], '''') COLLATE database_default + ', @membername = ' + QUOTENAME(spm.[name], '''') COLLATE database_default AS [DropTSQL]
FROM master.sys.server_role_members AS srm
JOIN master.sys.server_principals AS spr ON srm.[role_principal_id] = spr.[principal_id]
JOIN master.sys.server_principals AS spm ON srm.[member_principal_id] = spm.[principal_id]
ORDER BY [RoleName], [UserName]
"@
        # This query returns the database role memberships
        $get_databaseRoleMembers_query = @"
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], USER_NAME(rm.role_principal_id) AS [RoleName], USER_NAME(rm.member_principal_id) AS [UserName], pe.[type_desc] AS [UserType], 
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_addrolemember @rolename = '  + QUOTENAME(USER_NAME(rm.[role_principal_id]), '''') COLLATE database_default + ', @membername = ' + QUOTENAME(USER_NAME(rm.[member_principal_id]), '''') COLLATE database_default AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_droprolemember @rolename = ' + QUOTENAME(USER_NAME(rm.[role_principal_id]), '''') COLLATE database_default + ', @membername = ' + QUOTENAME(USER_NAME(rm.[member_principal_id]), '''') COLLATE database_default AS [DropTSQL]
FROM sys.database_role_members AS rm
LEFT JOIN sys.database_principals AS pe ON rm.[member_principal_id] = pe.[principal_id]
ORDER BY [RoleName], [UserName]
"@
        # This query returns the server explicit permissions
        $get_serverPermissions_query   = @"
-- Server Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], 'Instance-Level Server Permission' AS [ObjectName], NULL AS [Detail], pr.[name] AS [UserName], pr.[type_desc] AS [UserType], USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE [master]; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE [master]; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.server_permissions AS pe
INNER JOIN sys.server_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
WHERE pe.[class] = 100
UNION ALL
-- Endpoint Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], 'Instance-Level Endpoint Permission' AS [ObjectName], ep.[name] AS [Detail], pr.[name] AS [UserName], pr.[type_desc] AS [UserType], USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE [master]; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' ON ENDPOINT::' + QUOTENAME(ep.[name]) COLLATE database_default + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE [master]; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' ON ENDPOINT::' + QUOTENAME(ep.[name]) COLLATE database_default + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.server_permissions AS pe
INNER JOIN sys.server_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
INNER JOIN sys.endpoints AS ep on pe.[major_id] = ep.[endpoint_id]
WHERE pe.[class] = 105
UNION ALL
-- Server-Principle Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], 'Instance-Level Server-Principle Permission' AS [ObjectName], pr2.[name] AS [Detail], pr.[name] AS [UserName], pr.[type_desc] AS [UserType], USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE [master]; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' ON LOGIN::' + QUOTENAME(pr2.[name]) COLLATE database_default + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE [master]; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' ON LOGIN::' + QUOTENAME(pr2.[name]) COLLATE database_default + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS ' + QUOTENAME(pr.[name]) COLLATE database_default AS [RevokeTSQL]
FROM sys.server_permissions AS pe
INNER JOIN sys.server_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
INNER JOIN sys.server_principals AS pr2 ON pe.[major_id] = pr2.[principal_id]
WHERE pe.[class] = 101
ORDER BY [ObjectName],[Permission],[UserName]
"@
        # This query returns the database explicit permissions
        $get_databasePermissions_query = @"
-- Database Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], 'Database-Level Permission' AS [ObjectName], NULL AS [Detail], USER_NAME(pr.[principal_id]) AS UserName, pr.[type_desc] AS [UserType],  USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
WHERE pe.[class] = 0
UNION ALL
-- Object Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], SCHEMA_NAME(o.[schema_id]) + '.' + o.[name] AS [ObjectName], cl.[name] AS [Detail], USER_NAME(pr.[principal_id]) AS UserName, pr.[type_desc] AS [UserType],  USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + '.' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '' ELSE '(' + QUOTENAME(cl.[name]) COLLATE database_default + ')' END + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + '.' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '' ELSE '(' + QUOTENAME(cl.[name]) COLLATE database_default + ')' END + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.objects AS o ON pe.[major_id] = o.[object_id]
INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
LEFT JOIN sys.columns AS cl ON cl.column_id = pe.[minor_id] AND cl.[object_id] = pe.[major_id]
WHERE pe.[class] = 1
UNION ALL
-- Schema Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], pe.[class_desc] + '::' COLLATE database_default + QUOTENAME(SCHEMA_NAME(pe.[major_id])) AS [ObjectName], NULL AS [Detail], USER_NAME(pe.[grantee_principal_id]) AS UserName, pr.[type_desc] AS [UserType],  USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' ON ' + pe.[class_desc] + '::' + QUOTENAME(SCHEMA_NAME(pe.[major_id])) COLLATE database_default + ' TO ' + QUOTENAME(USER_NAME(pe.[grantee_principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' ON ' + pe.[class_desc] + '::' + QUOTENAME(SCHEMA_NAME(pe.[major_id])) COLLATE database_default + ' TO ' + QUOTENAME(USER_NAME(pe.[grantee_principal_id])) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.schemas s ON pe.[major_id] = s.[schema_id]
INNER JOIN sys.database_principals pr ON pe.[grantee_principal_id] = pr.[principal_id]
WHERE pe.[class] = 3
UNION ALL
-- Other Permissions
SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], SCHEMA_NAME(o.[schema_id]) + '.' + o.[name] AS [ObjectName], cl.[name] AS [Detail], USER_NAME(pr.[principal_id]) AS UserName, pr.[type_desc] AS [UserType],  USER_NAME(pe.grantor_principal_id) AS [Grantor],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' '                             + pe.[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + '.' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '' ELSE '(' + QUOTENAME(cl.[name]) COLLATE database_default + ')' END + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'REVOKE ' + CASE WHEN pe.[state] = 'W' THEN '/*(REVOKE WITH GRANT) GRANT OPTION FOR*/ ' ELSE '' END + pe.[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + '.' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '' ELSE '(' + QUOTENAME(cl.[name]) COLLATE database_default + ')' END + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state]  = 'W' THEN ' CASCADE' ELSE '' END + ' AS [dbo]'  AS [RevokeTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.objects AS o ON pe.[major_id] = o.[object_id]
INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
LEFT JOIN sys.columns AS cl ON cl.column_id = pe.[minor_id] AND cl.[object_id] = pe.[major_id]
WHERE pe.[class] > 3
ORDER BY [Permission], [ObjectName], [UserName]
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
        $totalstep = ($instances.Count * 4) + 1
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
            # Writes error for instances that are < 2005
            if ($instancebuild -lt 9){ Write-Error -Category InvalidOperation -Message "SQL version  of $instancename - $instancebuild not supported" -TargetObject $instancename  } 
            else {
                Write-Verbose "Processing $instancename..."
                Write-Verbose "Initializing arrays for $instancename..."
                $security    = @()
                $roleMembers = @()
                $permissions = @()
                $stepnum++
                Write-Progress -Activity "Running server-level queries against $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
                # Runs server-level queries
                Write-Verbose "Retrieving databases for $instancename..."
                $databases    = Invoke-Sqlcmd -serverinstance $instancename -query $get_databases_query         -connectiontimeout 5
                Write-Verbose "Retrieving server logins for $instancename..."
                $security    += Invoke-Sqlcmd -serverinstance $instancename -query $get_serverSecurity_query    -connectiontimeout 5
                Write-Verbose "Retrieving server role membership for $instancename..."
                $roleMembers += Invoke-Sqlcmd -serverinstance $instancename -query $get_serverRoleMembers_query -connectiontimeout 5
                Write-Verbose "Retrieving server permissions for $instancename..."
                $permissions += Invoke-Sqlcmd -serverinstance $instancename -query $get_serverPermissions_query -connectiontimeout 5
                $stepnum++
                Write-Progress -Activity "Running database-level queries against $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
                # Runs database-level queries
                foreach ($database in $databases){
                    Write-Verbose "Retrieving database users for $instancename.$($database.name)..."
                    $security    += Invoke-Sqlcmd -serverinstance $instancename -database $database.name -query $get_databaseSecurity_query    -connectiontimeout 5
                    Write-Verbose "Retrieving database role membership for $instancename.$($database.name)..."
                    $roleMembers += Invoke-Sqlcmd -serverinstance $instancename -database $database.name -query $get_databaseRoleMembers_query -connectiontimeout 5
                    Write-Verbose "Retrieving database permissions for $instancename.$($database.name)..."
                    $permissions += Invoke-Sqlcmd -serverinstance $instancename -database $database.name -query $get_databasePermissions_query -connectiontimeout 5
                }
                $stepnum++
                Write-Progress -Activity "Outputting/appending results for $instancename..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
                # Writes output to CSVs if specified
                if ($reportPath){
                    $instancename = $instancename -replace "\\","_"
                    Write-Verbose "Creating directory for $instancename in $reportPath..."
                    New-Item -ItemType Directory -Force -Path "$reportPath\$instancename" > $null
                    Write-Verbose "Generating file names..."
                    $securityReportPath    = $reportPath + '\' + $instancename + '\' + $instancename + '_SecurityPrinciples_'  + $date + '.csv'
                    $roleMembersReportPath = $reportPath + '\' + $instancename + '\' + $instancename + '_RoleMemberships_'     + $date + '.csv'
                    $permissionsReportPath = $reportPath + '\' + $instancename + '\' + $instancename + '_ExplicitPermissions_' + $date + '.csv'
        
                    Write-Verbose "Exporting security results for $instancename to $securityReportPath..."
                    $security    | Export-Csv -Path $securityReportPath    -NoTypeInformation
                    Write-Verbose "Exporting role membership results for $instancename to $securityReportPath..."
                    $roleMembers | Export-Csv -Path $roleMembersReportPath -NoTypeInformation
                    Write-Verbose "Exporting permissions results for $instancename to $securityReportPath..."
                    $permissions | Export-Csv -Path $permissionsReportPath -NoTypeInformation
                }
                Write-Verbose "Appending aggregate array with $instancename results..."
                $totalSecurity    += $security
                $totalRoleMembers += $roleMembers
                $totalPermissions += $permissions
            }    
        }
    }

    end { 
        $stepnum++
        Write-Progress -Activity "Outputting/returning results..." -Status ("Percent Complete: " + [int](($stepnum / $totalstep) * 100) + "%") -PercentComplete (($stepnum / $totalstep) * 100)
        if ($reportPath){
            Write-Verbose "Generating aggregate file names..."
            $securityReportPath    = $reportPath + '\SecurityPrinciples_'  + $date + '.csv'
            $roleMembersReportPath = $reportPath + '\RoleMemberships_'     + $date + '.csv'
            $permissionsReportPath = $reportPath + '\ExplicitPermissions_' + $date + '.csv'
            # Writes output to CSVs if specified
            Write-Verbose "Exporting aggregate security results to $securityReportPath..."
            $totalSecurity    | Export-Csv -Path $securityReportPath    -NoTypeInformation
            Write-Verbose "Exporting aggregate role membership results to $securityReportPath..."
            $totalRoleMembers | Export-Csv -Path $roleMembersReportPath -NoTypeInformation
            Write-Verbose "Exporting aggregate permissions results to $securityReportPath..."
            $totalPermissions | Export-Csv -Path $permissionsReportPath -NoTypeInformation
        }
        elseif ($output){
            $output = $output.ToLower()
            switch ($output){
                "security"    { $totalSecurity    }
                "roles"       { $totalRoleMembers }
                "permissions" { $totalPermissions }
            }
        }
        else { Write-Output "Specify an output source (report path or output type) and re-run" }
        Write-Verbose "Ending $($MyInvocation.Mycommand)" 
    }
}

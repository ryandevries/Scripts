$sourcedatabase   = 'ServerInventory'
$sourceinstance   = 'localhost'
$targetdatabase   = 'ServerInventory'
$targetinstance   = 'FNY-WS-MG005YWQ'
$stagingpath      = 'C:\Temp\SQLBackupStaging'
$ticket           = 'REQ12345'
$newbackup        = $true

$timestamp        = (Get-Date).ToString("yyyyMMdd")
$sourcebackuppath = "$($stagingpath)\$($sourceinstance)\$($sourcedatabase)\Requests"
$sourcebackupname = "$($sourcedatabase)_$($ticket)_$($timestamp).bak"
$targetbackuppath = "$($stagingpath)\$($targetinstance)\$($targetdatabase)\Requests"
$targetbackupname = "$($targetdatabase)_$($ticket)_$($timestamp).bak"

Write-Host "Checking $sourcebackuppath..."
if(!(Test-Path -Path $sourcebackuppath)){
    Write-Host "Source path not found at $sourcebackuppath, creating..."
    New-Item -ItemType Directory -Path $sourcebackuppath > $null
    Write-Host "Created directory structure to $sourcebackuppath"
}
else { Write-Host "Found $sourcebackuppath" }

Write-Host "Checking $targetbackuppath..."
if(!(Test-Path -Path $targetbackuppath)){
    Write-Host "Source path not found at $targetbackuppath, creating..."
    New-Item -ItemType Directory -Path $targetbackuppath > $null
    Write-Host "Created directory structure to $targetbackuppath"
}
else { Write-Host "Found $targetbackuppath" }

# Identify last full backup, or take new one if specified
$lastfullbackupquery = @"
SELECT TOP 1 physical_device_name, backup_start_date
FROM msdb.dbo.backupset b JOIN msdb.dbo.backupmediafamily m ON b.media_set_id = m.media_set_id
WHERE database_name = '$sourcedatabase' AND type = 'D'
ORDER BY backup_finish_date DESC
"@

# Back up existing permissions for later application
$databaseprinciplesquery = @"
-- Users and Groups
SELECT COALESCE(sl.[name], 'Login not found') AS [LoginName], pr.[name] AS [UserName], 'IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = ' + QUOTENAME(pr.[name],'''') + ') CREATE USER ' + QUOTENAME(pr.[name]) COLLATE database_default + ' FOR LOGIN ' + COALESCE(QUOTENAME(sl.[name]), 'NULL') COLLATE database_default + CASE WHEN pr.[default_schema_name] IS NULL THEN '' ELSE ' WITH DEFAULT_SCHEMA = ' + QUOTENAME(pr.[default_schema_name]) COLLATE database_default END AS [CreateTSQL]
FROM sys.database_principals AS pr
LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
WHERE pr.[type] IN ('U', 'S', 'G')
AND pr.[name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
UNION ALL
-- Roles
SELECT COALESCE(sl.[name], 'Login not found') AS [LoginName], pr.[name] AS [UserName], 'IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = ' + QUOTENAME(pr.[name],'''') + ') CREATE ROLE '+ QUOTENAME(pr.[name]) COLLATE database_default AS [CreateTSQL]
FROM sys.database_principals pr
LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
WHERE [principal_id] > 4 
AND [is_fixed_role] <> 1
AND [type] = 'R'
ORDER BY pr.[name]
"@

$rolemembershipquery = @"
--Role Membership
SELECT COALESCE(sl.[name], 'Login not found') AS [LoginName], pr.[name] AS [UserName], USER_NAME(rm.[role_principal_id]) AS [RoleName], 'EXEC sp_addrolemember @rolename = '  + QUOTENAME(USER_NAME(rm.[role_principal_id]), '''') COLLATE database_default + ', @membername = ' + QUOTENAME(USER_NAME(rm.[member_principal_id]), '''') COLLATE database_default AS [CreateTSQL]
FROM sys.database_role_members AS rm
LEFT JOIN sys.database_principals AS pr ON rm.[member_principal_id] = pr.[principal_id]
LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
WHERE pr.[name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
ORDER BY USER_NAME(rm.[role_principal_id]), pr.[name]
"@

$databasepermissionsquery = @"
-- Database Permissions
SELECT COALESCE(sl.[name], 'Login not found') AS [LoginName], pr.[name] AS [UserName], pe.[permission_name] AS [PermissionName], CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' ' + pe.[permission_name] + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
WHERE pe.[class] = 0
AND pr.[name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
UNION ALL
-- Object Permissions
SELECT COALESCE(sl.[name], 'Login not found') AS [LoginName], pr.[name] AS [UserName], pe.[permission_name] AS [PermissionName], CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' ' + pe.[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + '.' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '' ELSE '(' + QUOTENAME(cl.[name]) COLLATE database_default + ')' END + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.objects AS o ON pe.[major_id] = o.[object_id]
INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
LEFT JOIN sys.columns AS cl ON cl.column_id = pe.[minor_id] AND cl.[object_id] = pe.[major_id]
WHERE pe.[class] = 1
AND pr.[name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
UNION ALL
-- Schema Permissions
SELECT COALESCE(sl.[name], 'Login not found') AS [LoginName], pr.[name] AS [UserName], pe.[permission_name] AS [PermissionName], CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' ' + pe.[permission_name] + ' ON ' + pe.[class_desc] + '::' + QUOTENAME(SCHEMA_NAME(pe.[major_id])) COLLATE database_default + ' TO ' + QUOTENAME(USER_NAME(pe.[grantee_principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [CreateTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.schemas s ON pe.[major_id] = s.[schema_id]
INNER JOIN sys.database_principals pr ON pe.[grantee_principal_id] = pr.[principal_id]
LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
WHERE pe.[class] = 3
AND pr.[name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
UNION ALL
-- Other Permissions
SELECT COALESCE(sl.[name], 'Login not found') AS [LoginName], pr.[name] AS [UserName], pe.[permission_name] AS [PermissionName], CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' ' + pe.[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + '.' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '' ELSE '(' + QUOTENAME(cl.[name]) COLLATE database_default + ')' END + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [GrantTSQL]
FROM sys.database_permissions AS pe
INNER JOIN sys.objects AS o ON pe.[major_id] = o.[object_id]
INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
LEFT JOIN sys.columns AS cl ON cl.column_id = pe.[minor_id] AND cl.[object_id] = pe.[major_id]
WHERE pe.[class] > 3
AND pr.[name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
ORDER BY pe.[permission_name], pr.[name]
"@

if (!$newbackup){ 
    Write-Host "Identifying path of latest backup of $sourceinstance.$sourcedatabase..."
    $lastfullbackup   = Invoke-Sqlcmd -ServerInstance $sourceinstance -Query $lastfullbackupquery      -ConnectionTimeout 5 
    if (Test-Path -Path $lastfullbackup.physical_device_name){
        $sourcebackuppath = Split-Path -Parent $lastfullbackup.physical_device_name
        $sourcebackupname = Split-Path -Leaf   $lastfullbackup.physical_device_name
        $sourcebackuptime = $lastfullbackup.backup_start_date
        Write-Host "Found backup at $sourcebackuppath\$sourcebackupname from $sourcebackuptime"
    }
    else { 
        Write-Host "Unable to reach path of last backup, creating a new one at $sourcebackuppath\$sourcebackupname" 
        Backup-SqlDatabase -ServerInstance $sourceinstance -Database $sourcedatabase -CopyOnly -BackupFile $sourcebackuppath\$sourcebackupname -ConnectionTimeout 5 -Verbose -WhatIf
    }
}
else {
    Write-Host "Creating a new backup of $sourceinstance.$sourcedatabase at $sourcebackuppath\$sourcebackupname"
    Backup-SqlDatabase -ServerInstance $sourceinstance -Database $sourcedatabase -CopyOnly -BackupFile $sourcebackuppath\$sourcebackupname -ConnectionTimeout 5 -Verbose -WhatIf 
}

$databaseprinciples   = Invoke-Sqlcmd -ServerInstance $targetinstance -Query $databaseprinciplesquery  -ConnectionTimeout 5
$rolemembers          = Invoke-Sqlcmd -ServerInstance $targetinstance -Query $rolemembershipquery      -ConnectionTimeout 5
$databasepermissions  = Invoke-Sqlcmd -ServerInstance $targetinstance -Query $databasepermissionsquery -ConnectionTimeout 5



# Back up current database
Backup-SqlDatabase  -ServerInstance $targetinstance -Database $targetdatabase -CopyOnly        -BackupFile $targetbackuppath\$targetbackupname -ConnectionTimeout 5 -Verbose -WhatIf

# Restore backup, replacing current database
# Set single user mode
Restore-SqlDatabase -ServerInstance $targetinstance -Database $targetdatabase -ReplaceDatabase -BackupFile $sourcebackuppath\$sourcebackupname -ConnectionTimeout 5 -Verbose -WhatIf

# Wipe out permissions 
@"
SELECT 'DROP USER ' + QUOTENAME([name]) AS [SQL]
FROM sys.database_principals
WHERE [type] IN ('U', 'S', 'G')
AND [name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
"@

# Re-apply old permissions
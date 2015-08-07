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

--Role Membership
SELECT COALESCE(sl.[name], 'Login not found') AS [LoginName], pr.[name] AS [UserName], USER_NAME(rm.[role_principal_id]) AS [RoleName], 'EXEC sp_addrolemember @rolename = '  + QUOTENAME(USER_NAME(rm.[role_principal_id]), '''') COLLATE database_default + ', @membername = ' + QUOTENAME(USER_NAME(rm.[member_principal_id]), '''') COLLATE database_default AS [CreateTSQL]
FROM sys.database_role_members AS rm
LEFT JOIN sys.database_principals AS pr ON rm.[member_principal_id] = pr.[principal_id]
LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
WHERE pr.[name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
ORDER BY USER_NAME(rm.[role_principal_id]), pr.[name]

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

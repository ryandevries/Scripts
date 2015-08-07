/*
Permissions
Returns 6 sets
	1. System Logins
	2. Server Roles
	3. Server Permissions
	4. Database Users
	5. Database Roles
	6. Database Permissions
*/

-- Server Security

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

-- Server Role Membership

SELECT SERVERPROPERTY('ServerName') AS [InstanceName], NULL AS [DatabaseName], spr.[name] AS [RoleName], spm.[name] AS [UserName], spm.[type_desc] AS [UserType], 
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_addsrvrolemember @rolename = '  + QUOTENAME(spr.[name], '''') COLLATE database_default + ', @membername = ' + QUOTENAME(spm.[name], '''') COLLATE database_default AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_dropsrvrolemember @rolename = ' + QUOTENAME(spr.[name], '''') COLLATE database_default + ', @membername = ' + QUOTENAME(spm.[name], '''') COLLATE database_default AS [DropTSQL]
FROM master.sys.server_role_members AS srm
JOIN master.sys.server_principals AS spr ON srm.[role_principal_id] = spr.[principal_id]
JOIN master.sys.server_principals AS spm ON srm.[member_principal_id] = spm.[principal_id]
ORDER BY [RoleName], [UserName]

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

-- Database Security

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

-- Database Role Membership

SELECT SERVERPROPERTY('ServerName') AS [InstanceName], DB_NAME() AS [DatabaseName], USER_NAME(rm.role_principal_id) AS [RoleName], USER_NAME(rm.member_principal_id) AS [UserName], pe.[type_desc] AS [UserType], 
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_addrolemember @rolename = '  + QUOTENAME(USER_NAME(rm.[role_principal_id]), '''') COLLATE database_default + ', @membername = ' + QUOTENAME(USER_NAME(rm.[member_principal_id]), '''') COLLATE database_default AS [CreateTSQL],
'USE ' + QUOTENAME(DB_NAME()) COLLATE database_default + '; ' + 'EXEC sp_droprolemember @rolename = ' + QUOTENAME(USER_NAME(rm.[role_principal_id]), '''') COLLATE database_default + ', @membername = ' + QUOTENAME(USER_NAME(rm.[member_principal_id]), '''') COLLATE database_default AS [DropTSQL]
FROM sys.database_role_members AS rm
LEFT JOIN sys.database_principals AS pe ON rm.[member_principal_id] = pe.[principal_id]
ORDER BY [RoleName], [UserName]

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

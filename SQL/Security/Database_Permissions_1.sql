DECLARE @sql varchar(2048)
       ,@sort INT 
	   ,@username sysname

SET @username = '%' -- % for all users/groups

DECLARE tmp CURSOR FOR
SELECT '-- USER CLEANUP --
USE ' + QUOTENAME(DB_NAME()) + '

DECLARE @sql varchar(2048)
DECLARE tmp CURSOR FOR
	SELECT ''DROP USER '' + QUOTENAME([name]) AS [SQL]
	FROM sys.database_principals
	WHERE [type] IN (''U'', ''S'', ''G'')
	AND [name] NOT IN (''sys'', ''guest'', ''information_schema'', ''public'', ''dbo'')
OPEN tmp
FETCH NEXT FROM tmp INTO @sql
WHILE @@FETCH_STATUS = 0
BEGIN
	--EXEC(@sql)
	PRINT @sql
	FETCH NEXT FROM tmp INTO @sql    
END

CLOSE tmp
DEALLOCATE tmp

' AS [SQL], 0 AS [Order]
UNION

/*********   DB CONTEXT STATEMENT    *********/
SELECT '-- DB CONTEXT --' AS [SQL], 1 AS [Order]
UNION
SELECT 'USE ' + QUOTENAME(DB_NAME()) AS [SQL], 1 AS [Order]
UNION
SELECT '' AS [SQL], 2 AS [Order]
UNION

/*********     DB USER CREATION      *********/
SELECT '-- DB USERS --' AS [SQL], 3 AS [Order]
UNION
SELECT 'IF NOT EXISTS (SELECT [name] FROM sys.database_principals WHERE [name] = ' + QUOTENAME([name],'''') + ') 
CREATE USER ' + QUOTENAME([name]) + ' FOR LOGIN ' + QUOTENAME([name]) + CASE WHEN [default_schema_name] IS NULL THEN '' ELSE ' WITH DEFAULT_SCHEMA = ' + QUOTENAME([default_schema_name]) END AS [SQL], 4 AS [Order]
FROM sys.database_principals
WHERE [type] IN ('U', 'S', 'G')
AND [name] LIKE @username
AND [name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
UNION
SELECT '' AS [SQL], 5 AS [Order]
UNION

/*********     DB ROLE CREATION      *********/
SELECT '-- DB ROLES --' AS [SQL], 6 AS [Order]
UNION
SELECT 'IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE [name] = N' + QUOTENAME([name],'''') + ' AND [type] = ''R'')
CREATE ROLE '+ QUOTENAME([name]) AS [SQL], 7 AS [ORDER]
FROM sys.database_principals
WHERE [principal_id] > 4 
AND [is_fixed_role] <> 1
AND [type] = 'R'
UNION
SELECT '' AS [SQL], 8 AS [Order]
UNION

/*********    DB ROLE PERMISSIONS    *********/
SELECT 'EXEC sp_addrolemember @rolename = ' + QUOTENAME(USER_NAME(rm.role_principal_id), '''') + ', @membername = ' + QUOTENAME(USER_NAME(rm.member_principal_id), '''') AS [SQL], 9 AS [Order]
FROM sys.database_role_members AS rm
WHERE USER_NAME(rm.member_principal_id) IN (
	SELECT [name]
	FROM sys.database_principals
	WHERE [principal_id] > 4 and [type] IN ('G', 'S', 'U')
	AND [name] LIKE @username
	AND [name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
)
UNION
SELECT '' AS [SQL], 10 AS [Order]
UNION

/*********  OBJECT LEVEL PERMISSIONS *********/
SELECT '-- OBJECT LEVEL PERMISSIONS --' AS [SQL], 11 AS [Order]
UNION
SELECT CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' ' + pe.[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) + '.' + QUOTENAME(o.[name]) + CASE WHEN cl.[column_id] IS NULL THEN '' ELSE '(' + QUOTENAME(cl.[name]) + ')' END + ' TO ' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' WITH GRANT OPTION' END AS [SQL], 12 AS [Order]
FROM sys.database_permissions AS pe
INNER JOIN sys.objects AS o ON pe.[major_id] = o.[object_id]
INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
LEFT JOIN sys.columns AS cl ON cl.column_id = pe.[minor_id] AND cl.[object_id] = pe.[major_id]
WHERE pr.[name] NOT IN ('public','guest')
AND pr.[name] LIKE @username
AND pr.[name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
UNION
SELECT '' AS [SQL], 13 AS [Order]
UNION

/*********    DB LEVEL PERMISSIONS   *********/
SELECT '-- DB LEVEL PERMISSIONS --' AS [SQL], 14 AS [Order]
UNION
SELECT CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' ' + pe.[permission_name] + ' TO ' + '[' + USER_NAME(pr.[principal_id]) + ']' COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [SQL], 15 AS [Order]
FROM sys.database_permissions AS pe
INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
WHERE pe.[major_id] = 0 AND pr.[principal_id] > 4 AND pr.[type] IN ('G', 'S', 'U')
AND pe.[permission_name] <> 'CONNECT'
AND pr.[name] LIKE @username
AND pr.[name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')
UNION
SELECT '' AS [SQL], 16 AS [Order]
UNION 

/******   DB LEVEL SCHEMA PERMISSIONS   ******/
SELECT '-- DB LEVEL SCHEMA PERMISSIONS --' AS [SQL], 17 AS [Order]
UNION
SELECT CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' ' + pe.[permission_name] + ' ON ' + pe.[class_desc] + '::' COLLATE database_default + QUOTENAME(SCHEMA_NAME(pe.[major_id]))+ ' TO ' + QUOTENAME(USER_NAME(pe.[grantee_principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [SQL], 18 AS [Order]
FROM sys.database_permissions AS pe
INNER JOIN sys.schemas s ON pe.[major_id] = s.[schema_id]
INNER JOIN sys.database_principals pr ON pe.[grantee_principal_id] = pr.[principal_id]
WHERE pe.[class] = 3
AND pr.[name] LIKE @username
AND pr.[name] NOT IN ('sys', 'guest', 'information_schema', 'public', 'dbo')

ORDER BY [Order]

OPEN tmp
FETCH NEXT FROM tmp INTO @sql, @sort
WHILE @@FETCH_STATUS = 0
BEGIN
	PRINT @sql
	FETCH NEXT FROM tmp INTO @sql, @sort    
END

CLOSE tmp
DEALLOCATE tmp

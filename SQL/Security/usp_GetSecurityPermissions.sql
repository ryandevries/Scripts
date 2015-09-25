IF OBJECT_ID('dbo.usp_GetSecurityPermissions') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_GetSecurityPermissions AS RETURN 0;')
GO
ALTER PROCEDURE dbo.usp_GetSecurityPermissions
    @Type				VARCHAR(20)	  = 'All',
	@DatabaseName		NVARCHAR(128) = 'All',
	@OutputDatabaseName NVARCHAR(128) = NULL ,
    @OutputSchemaName	NVARCHAR(256) = NULL ,
    @OutputTableName	NVARCHAR(256) = NULL
AS
	/*
	Stored Procedure:	usp_GetSecurityPermissions
	Created by:			Ryan DeVries http://RyanDeVries.com/
	Updated:			2015-09-24
	Version:			1.0

	Parameters:
	@Type				One of the following: All, Database, Server (Defaults to All)
							All - Pulls Server Permissions and Database Permissions
							Database - Pulls just Database Permissions (See @DatabaseName parameter)
							Server - Pulls just Server Permissions
	@DatabaseName		The name of the database to target if @Type = All or Database (Defaults to All)
							All - Pulls Database Permissions for all databases using ms_foreachDB
	@OutputDatabaseName	The name of the database for the output table
	@OutputSchemaName	The name of the schema for the output table
	@OutputTableName	The name of the table for the output table

	Output code adapted from Brent Ozar's excellent stored procedures http://BrentOzar.com/

	To Do:
		- Add error checking/handling
	*/
	SET NOCOUNT ON;
	DECLARE @StringToExecute NVARCHAR(4000);
	
	IF OBJECT_ID('tempdb..#Results') IS NOT NULL 
		DROP TABLE #Results;
	CREATE TABLE #Results (
		[InstanceName] [sql_variant] NULL,
		[Type] [varchar](50) NULL,
		[DatabaseName] [nvarchar](128) NULL,
		[State] [nvarchar](128) NULL,
		[Permission] [nvarchar](128) NULL,
		[ObjectName] [nvarchar](128) NULL,
		[Detail] [nvarchar](128) NULL,
		[LoginName] [nvarchar](128) NULL,
		[UserName] [nvarchar](128) NULL,
		[Grantor] [nvarchar](128) NULL,
		[Orphaned] [bit] NULL,
		[AsOfDate] [datetime] NULL,
		[Latest] [bit] NULL,
		[CreateTSQL] [nvarchar](max) NULL);
	
	SELECT  @OutputDatabaseName = QUOTENAME(@OutputDatabaseName),
			@OutputSchemaName = QUOTENAME(@OutputSchemaName),
			@OutputTableName = QUOTENAME(@OutputTableName)
		
	IF @Type = 'All' OR @Type = 'Server'
		BEGIN
			IF OBJECT_ID('tempdb..#InvalidLogins') IS NOT NULL
				DROP TABLE #InvalidLogins;
			CREATE TABLE #InvalidLogins ([SID] VARBINARY(85), [NT Login] sysname);
			INSERT INTO #InvalidLogins EXEC [sys].[sp_validatelogins];

			INSERT INTO #Results
			-- Insert current server permissions information
			SELECT SERVERPROPERTY('ServerName') AS [InstanceName], 'Server' AS [Type], 'N/A' AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], 'Instance-Level Server Permission' AS [ObjectName], 'N/A' AS [Detail], pr.[name] AS [LoginName], 'N/A' AS [UserName], USER_NAME(pe.grantor_principal_id) AS [Grantor], CASE WHEN pr.[type] = 'R' THEN 0 WHEN il.[sid] IS NULL THEN 0 ELSE 1 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
			'USE [master]; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' ' + pe.[permission_name] + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [CreateTSQL]
			FROM sys.server_permissions AS pe
			INNER JOIN sys.server_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
			LEFT JOIN #InvalidLogins AS il ON pr.[sid] = il.[sid]
			WHERE pe.[class] = 100
			UNION ALL
			-- Endpoint Permissions
			SELECT SERVERPROPERTY('ServerName') AS [InstanceName], 'Server' AS [Type], 'N/A' AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], 'Instance-Level Endpoint Permission' AS [ObjectName], ep.[name] AS [Detail], pr.[name]  AS [LoginName], 'N/A' AS [UserName], USER_NAME(pe.grantor_principal_id) AS [Grantor], CASE WHEN pr.[type] = 'R' THEN 0 WHEN il.[sid] IS NULL THEN 0 ELSE 1 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
			'USE [master]; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' ' + pe.[permission_name] + ' ON ENDPOINT::' + QUOTENAME(ep.[name]) COLLATE database_default + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [CreateTSQL]
			FROM sys.server_permissions AS pe
			INNER JOIN sys.server_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
			INNER JOIN sys.endpoints AS ep on pe.[major_id] = ep.[endpoint_id]
			LEFT JOIN #InvalidLogins AS il ON pr.[sid] = il.[sid]
			WHERE pe.[class] = 105
			UNION ALL
			-- Server-Principle Permissions
			SELECT SERVERPROPERTY('ServerName') AS [InstanceName], 'Server' AS [Type], 'N/A' AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], 'Instance-Level Server-Principle Permission' AS [ObjectName], pr2.[name] AS [Detail], pr.[name]  AS [LoginName], 'N/A' AS [UserName], USER_NAME(pe.grantor_principal_id) AS [Grantor], CASE WHEN pr.[type] = 'R' THEN 0 WHEN il.[sid] IS NULL THEN 0 ELSE 1 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
			'USE [master]; ' + CASE WHEN pe.[state] <> 'W' THEN pe.[state_desc] ELSE 'GRANT' END + ' ' + pe.[permission_name] + ' ON LOGIN::' + QUOTENAME(pr2.[name]) COLLATE database_default + ' TO ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN pe.[state] <> 'W' THEN '' ELSE ' ' + 'WITH GRANT OPTION' END AS [CreateTSQL]
			FROM sys.server_permissions AS pe
			INNER JOIN sys.server_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
			INNER JOIN sys.server_principals AS pr2 ON pe.[major_id] = pr2.[principal_id]
			LEFT JOIN #InvalidLogins AS il ON pr.[sid] = il.[sid]
			WHERE pe.[class] = 101
			ORDER BY [Permission], [ObjectName], [UserName]
		END
	IF @Type = 'All' OR @Type = 'Database'
		BEGIN
		IF @DatabaseName = 'All'
			BEGIN
				SET @StringToExecute = N'
				USE [?];
				INSERT INTO #Results
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], ''Database-Level Permission'' AS [ObjectName], ''N/A'' AS [Detail], ISNULL(sl.[name], ''N/A'') AS [LoginName], USER_NAME(pr.[principal_id]) AS UserName, USER_NAME(pe.grantor_principal_id) AS [Grantor], CASE WHEN pr.[type] = ''R'' THEN 0 WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + CASE WHEN pe.[state] <> ''W'' THEN pe.[state_desc] ELSE ''GRANT'' END + '' '' + pe.[permission_name] + '' TO '' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> ''W'' THEN '''' ELSE '' '' + ''WITH GRANT OPTION'' END AS [CreateTSQL]
				FROM sys.database_permissions AS pe
				INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
				LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
				WHERE pe.[class] = 0
				ORDER BY [Permission], [ObjectName], [UserName]';
				EXEC master.sys.sp_MSforeachdb @StringToExecute
				SET @StringToExecute = N'
				USE [?];
				INSERT INTO #Results
				-- Object Permissions
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], SCHEMA_NAME(o.[schema_id]) + ''.'' + o.[name] AS [ObjectName], ISNULL(cl.[name], ''N/A'') AS [Detail], ISNULL(sl.[name], ''N/A'') AS [LoginName], USER_NAME(pr.[principal_id]) AS UserName, USER_NAME(pe.grantor_principal_id) AS [Grantor], CASE WHEN pr.[type] = ''R'' THEN 0 WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + CASE WHEN pe.[state] <> ''W'' THEN pe.[state_desc] ELSE ''GRANT'' END + '' '' + pe.[permission_name] + '' ON '' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + ''.'' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '''' ELSE ''('' + QUOTENAME(cl.[name]) COLLATE database_default + '')'' END + '' TO '' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> ''W'' THEN '''' ELSE '' '' + ''WITH GRANT OPTION'' END AS [CreateTSQL]
				FROM sys.database_permissions AS pe
				INNER JOIN sys.objects AS o ON pe.[major_id] = o.[object_id]
				INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
				LEFT JOIN sys.columns AS cl ON cl.column_id = pe.[minor_id] AND cl.[object_id] = pe.[major_id]
				LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
				WHERE pe.[class] = 1
				ORDER BY [Permission], [ObjectName], [UserName]';
				EXEC master.sys.sp_MSforeachdb @StringToExecute
				SET @StringToExecute = N'
				USE [?];
				INSERT INTO #Results
				-- Schema Permissions
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type],DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], pe.[class_desc] + ''::'' COLLATE database_default + QUOTENAME(SCHEMA_NAME(pe.[major_id])) AS [ObjectName], ''N/A'' AS [Detail], ISNULL(sl.[name], ''N/A'') AS [LoginName], USER_NAME(pe.[grantee_principal_id]) AS UserName, USER_NAME(pe.grantor_principal_id) AS [Grantor], CASE WHEN pr.[type] = ''R'' THEN 0 WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + CASE WHEN pe.[state] <> ''W'' THEN pe.[state_desc] ELSE ''GRANT'' END + '' '' + pe.[permission_name] + '' ON '' + pe.[class_desc] + ''::'' + QUOTENAME(SCHEMA_NAME(pe.[major_id])) COLLATE database_default + '' TO '' + QUOTENAME(USER_NAME(pe.[grantee_principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> ''W'' THEN '''' ELSE '' '' + ''WITH GRANT OPTION'' END AS [CreateTSQL]
				FROM sys.database_permissions AS pe
				INNER JOIN sys.schemas s ON pe.[major_id] = s.[schema_id]
				INNER JOIN sys.database_principals pr ON pe.[grantee_principal_id] = pr.[principal_id]
				LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
				WHERE pe.[class] = 3
				ORDER BY [Permission], [ObjectName], [UserName]';
				EXEC master.sys.sp_MSforeachdb @StringToExecute
				SET @StringToExecute = N'
				USE [?];
				INSERT INTO #Results
				-- Other Permissions
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type],DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], SCHEMA_NAME(o.[schema_id]) + ''.'' + o.[name] AS [ObjectName], ''N/A'' AS [Detail], ISNULL(sl.[name], ''N/A'') AS [LoginName], USER_NAME(pr.[principal_id]) AS UserName, USER_NAME(pe.grantor_principal_id) AS [Grantor], CASE WHEN pr.[type] = ''R'' THEN 0 WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + CASE WHEN pe.[state] <> ''W'' THEN pe.[state_desc] ELSE ''GRANT'' END + '' '' + pe.[permission_name] + '' ON '' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + ''.'' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '''' ELSE ''('' + QUOTENAME(cl.[name]) COLLATE database_default + '')'' END + '' TO '' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> ''W'' THEN '''' ELSE '' '' + ''WITH GRANT OPTION'' END AS [CreateTSQL]
				FROM sys.database_permissions AS pe
				INNER JOIN sys.objects AS o ON pe.[major_id] = o.[object_id]
				INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
				LEFT JOIN sys.columns AS cl ON cl.column_id = pe.[minor_id] AND cl.[object_id] = pe.[major_id]
				LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
				WHERE pe.[class] > 3
				ORDER BY [Permission], [ObjectName], [UserName]';
				EXEC master.sys.sp_MSforeachdb @StringToExecute
			END
		ELSE
			BEGIN
				SET @StringToExecute = N'
				USE [?];
				INSERT INTO #Results
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], ''Database-Level Permission'' AS [ObjectName], ''N/A'' AS [Detail], ISNULL(sl.[name], ''N/A'') AS [LoginName], USER_NAME(pr.[principal_id]) AS UserName, USER_NAME(pe.grantor_principal_id) AS [Grantor], CASE WHEN pr.[type] = ''R'' THEN 0 WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + CASE WHEN pe.[state] <> ''W'' THEN pe.[state_desc] ELSE ''GRANT'' END + '' '' + pe.[permission_name] + '' TO '' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> ''W'' THEN '''' ELSE '' '' + ''WITH GRANT OPTION'' END AS [CreateTSQL]
				FROM sys.database_permissions AS pe
				INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
				LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
				WHERE pe.[class] = 0
				ORDER BY [Permission], [ObjectName], [UserName]';
				EXEC master.sys.sp_MSforeachdb @StringToExecute
				SET @StringToExecute = N'
				USE [?];
				INSERT INTO #Results
				-- Object Permissions
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type], DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], SCHEMA_NAME(o.[schema_id]) + ''.'' + o.[name] AS [ObjectName], ISNULL(cl.[name], ''N/A'') AS [Detail], ISNULL(sl.[name], ''N/A'') AS [LoginName], USER_NAME(pr.[principal_id]) AS UserName, USER_NAME(pe.grantor_principal_id) AS [Grantor], CASE WHEN pr.[type] = ''R'' THEN 0 WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + CASE WHEN pe.[state] <> ''W'' THEN pe.[state_desc] ELSE ''GRANT'' END + '' '' + pe.[permission_name] + '' ON '' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + ''.'' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '''' ELSE ''('' + QUOTENAME(cl.[name]) COLLATE database_default + '')'' END + '' TO '' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> ''W'' THEN '''' ELSE '' '' + ''WITH GRANT OPTION'' END AS [CreateTSQL]
				FROM sys.database_permissions AS pe
				INNER JOIN sys.objects AS o ON pe.[major_id] = o.[object_id]
				INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
				LEFT JOIN sys.columns AS cl ON cl.column_id = pe.[minor_id] AND cl.[object_id] = pe.[major_id]
				LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
				WHERE pe.[class] = 1
				ORDER BY [Permission], [ObjectName], [UserName]';
				EXEC master.sys.sp_MSforeachdb @StringToExecute
				SET @StringToExecute = N'
				USE [?];
				INSERT INTO #Results
				-- Schema Permissions
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type],DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], pe.[class_desc] + ''::'' COLLATE database_default + QUOTENAME(SCHEMA_NAME(pe.[major_id])) AS [ObjectName], ''N/A'' AS [Detail], ISNULL(sl.[name], ''N/A'') AS [LoginName], USER_NAME(pe.[grantee_principal_id]) AS UserName, USER_NAME(pe.grantor_principal_id) AS [Grantor], CASE WHEN pr.[type] = ''R'' THEN 0 WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + CASE WHEN pe.[state] <> ''W'' THEN pe.[state_desc] ELSE ''GRANT'' END + '' '' + pe.[permission_name] + '' ON '' + pe.[class_desc] + ''::'' + QUOTENAME(SCHEMA_NAME(pe.[major_id])) COLLATE database_default + '' TO '' + QUOTENAME(USER_NAME(pe.[grantee_principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> ''W'' THEN '''' ELSE '' '' + ''WITH GRANT OPTION'' END AS [CreateTSQL]
				FROM sys.database_permissions AS pe
				INNER JOIN sys.schemas s ON pe.[major_id] = s.[schema_id]
				INNER JOIN sys.database_principals pr ON pe.[grantee_principal_id] = pr.[principal_id]
				LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
				WHERE pe.[class] = 3
				ORDER BY [Permission], [ObjectName], [UserName]';
				EXEC master.sys.sp_MSforeachdb @StringToExecute
				SET @StringToExecute = N'
				USE [?];
				INSERT INTO #Results
				-- Other Permissions
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type],DB_NAME() AS [DatabaseName], pe.[state_desc] AS [State], pe.[permission_name] AS [Permission], SCHEMA_NAME(o.[schema_id]) + ''.'' + o.[name] AS [ObjectName], ''N/A'' AS [Detail], ISNULL(sl.[name], ''N/A'') AS [LoginName], USER_NAME(pr.[principal_id]) AS UserName, USER_NAME(pe.grantor_principal_id) AS [Grantor], CASE WHEN pr.[type] = ''R'' THEN 0 WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + CASE WHEN pe.[state] <> ''W'' THEN pe.[state_desc] ELSE ''GRANT'' END + '' '' + pe.[permission_name] + '' ON '' + QUOTENAME(SCHEMA_NAME(o.[schema_id])) COLLATE database_default + ''.'' + QUOTENAME(o.[name]) COLLATE database_default + CASE WHEN cl.[column_id] IS NULL THEN '''' ELSE ''('' + QUOTENAME(cl.[name]) COLLATE database_default + '')'' END + '' TO '' + QUOTENAME(USER_NAME(pr.[principal_id])) COLLATE database_default + CASE WHEN pe.[state] <> ''W'' THEN '''' ELSE '' '' + ''WITH GRANT OPTION'' END AS [CreateTSQL]
				FROM sys.database_permissions AS pe
				INNER JOIN sys.objects AS o ON pe.[major_id] = o.[object_id]
				INNER JOIN sys.database_principals AS pr ON pe.[grantee_principal_id] = pr.[principal_id]
				LEFT JOIN sys.columns AS cl ON cl.column_id = pe.[minor_id] AND cl.[object_id] = pe.[major_id]
				LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
				WHERE pe.[class] > 3
				ORDER BY [Permission], [ObjectName], [UserName]';
				EXEC master.sys.sp_MSforeachdb @StringToExecute
			END
		END
	
	IF @OutputDatabaseName IS NOT NULL
		AND @OutputSchemaName IS NOT NULL
		AND @OutputTableName IS NOT NULL
		AND EXISTS ( SELECT * FROM sys.databases WHERE QUOTENAME([name]) = @OutputDatabaseName)
		BEGIN
			SET @StringToExecute = 'USE ' + @OutputDatabaseName	+ '; 
			IF EXISTS(SELECT * FROM ' + @OutputDatabaseName + '.INFORMATION_SCHEMA.SCHEMATA WHERE QUOTENAME(SCHEMA_NAME) = ''' + @OutputSchemaName + ''') 
			AND NOT EXISTS (SELECT * FROM '	+ @OutputDatabaseName + '.INFORMATION_SCHEMA.TABLES WHERE QUOTENAME(TABLE_SCHEMA) = ''' + @OutputSchemaName + ''' AND QUOTENAME(TABLE_NAME) = ''' + @OutputTableName + ''') 
			CREATE TABLE ' + @OutputSchemaName + '.' + @OutputTableName	+ ' (
				[InstanceName] [sql_variant] NULL,
				[Type] [varchar](50) NULL,
				[DatabaseName] [nvarchar](128) NULL,
				[State] [nvarchar](128) NULL,
				[Permission] [nvarchar](128) NULL,
				[ObjectName] [nvarchar](128) NULL,
				[Detail] [nvarchar](128) NULL,
				[LoginName] [nvarchar](128) NULL,
				[UserName] [nvarchar](128) NULL,
				[Grantor] [nvarchar](128) NULL,
				[Orphaned] [bit] NULL,
				[AsOfDate] [datetime] NULL,
				[Latest] [bit] NULL,
				[CreateTSQL] [nvarchar](max) NULL);'
			EXEC(@StringToExecute);
			SET @StringToExecute = N' IF EXISTS(SELECT * FROM '	+ @OutputDatabaseName + '.INFORMATION_SCHEMA.SCHEMATA WHERE QUOTENAME(SCHEMA_NAME) = ''' + @OutputSchemaName + ''') 
			UPDATE ' + @OutputDatabaseName + '.' + @OutputSchemaName + '.' + @OutputTableName + '
			SET [Latest] = 0 WHERE [Type] LIKE ''' + CASE @Type WHEN 'All' THEN '%' ELSE @Type END + '''
			INSERT ' + @OutputDatabaseName + '.' + @OutputSchemaName + '.' + @OutputTableName + ' (InstanceName, Type, DatabaseName, State, Permission, ObjectName, Detail, LoginName, UserName, Grantor, Orphaned, AsOfDate, Latest, CreateTSQL) 
			SELECT InstanceName, Type, DatabaseName, State, Permission, ObjectName, Detail, LoginName, UserName, Grantor, Orphaned, AsOfDate, Latest, CreateTSQL FROM #Results 
			ORDER BY [Type],[DatabaseName],[State],[Permission],[ObjectName],[LoginName],[UserName]';
			EXEC(@StringToExecute);
		END
	ELSE IF (SUBSTRING(@OutputTableName, 2, 2) = '##')
		BEGIN
			SET @StringToExecute = N' IF (OBJECT_ID(''tempdb..'	+ @OutputTableName + ''') IS NOT NULL) DROP TABLE ' + @OutputTableName + ';
			CREATE TABLE ' + @OutputTableName + ' (
				[InstanceName] [sql_variant] NULL,
				[Type] [varchar](50) NULL,
				[DatabaseName] [nvarchar](128) NULL,
				[State] [nvarchar](128) NULL,
				[Permission] [nvarchar](128) NULL,
				[ObjectName] [nvarchar](128) NULL,
				[Detail] [nvarchar](128) NULL,
				[LoginName] [nvarchar](128) NULL,
				[UserName] [nvarchar](128) NULL,
				[Grantor] [nvarchar](128) NULL,
				[Orphaned] [bit] NULL,
				[AsOfDate] [datetime] NULL,
				[Latest] [bit] NULL,
				[CreateTSQL] [nvarchar](max) NULL);
			INSERT ' + @OutputTableName	+ ' (InstanceName, Type, DatabaseName, State, Permission, ObjectName, Detail, LoginName, UserName, Grantor, Orphaned, AsOfDate, Latest, CreateTSQL) 
			SELECT InstanceName, Type, DatabaseName, State, Permission, ObjectName, Detail, LoginName, UserName, Grantor, Orphaned, AsOfDate, Latest, CreateTSQL FROM #Results
			ORDER BY [Type],[DatabaseName],[State],[Permission],[ObjectName],[LoginName],[UserName]';
			EXEC(@StringToExecute);
		END
	ELSE IF (SUBSTRING(@OutputTableName, 2, 1) = '#')
		BEGIN
			RAISERROR('Due to the nature of Dymamic SQL, only global (i.e. double pound (##)) temp tables are supported for @OutputTableName', 16, 0)
		END
	ELSE 
		BEGIN
			SELECT InstanceName, Type, DatabaseName, State, Permission, ObjectName, Detail, LoginName, UserName, Grantor, Orphaned, AsOfDate, Latest, CreateTSQL FROM #Results
			ORDER BY [Type],[DatabaseName],[State],[Permission],[ObjectName],[LoginName],[UserName]
		END
	DROP TABLE #Results
GO

dbo.usp_GetSecurityPermissions @OutputDatabaseName = 'DBAUtility', @OutputSchemaName = 'dbo', @OutputTableName = 'Testing3'
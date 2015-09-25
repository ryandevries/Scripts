IF OBJECT_ID('dbo.usp_GetSecurityPrinciples') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_GetSecurityPrinciples AS RETURN 0;')
GO
ALTER PROCEDURE dbo.usp_GetSecurityPrinciples
    @Type				VARCHAR(20)	  = 'All',
	@DatabaseName		NVARCHAR(128) = 'All',
	@OutputDatabaseName NVARCHAR(128) = NULL ,
    @OutputSchemaName	NVARCHAR(256) = NULL ,
    @OutputTableName	NVARCHAR(256) = NULL
AS
	/*
	Stored Procedure:	usp_GetSecurityPrinciples
	Created by:			Ryan DeVries http://RyanDeVries.com/
	Updated:			2015-09-24
	Version:			1.0

	Parameters:
	@Type				One of the following: All, Database, Server (Defaults to All)
							All - Pulls Server Logins and Database Users
							Database - Pulls just Database Users (See @DatabaseName parameter)
							Server - Pulls just Server Logins
	@DatabaseName		The name of the database to target if @Type = All or Database (Defaults to All)
							All - Pulls Database Users for all databases using ms_foreachDB
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
		[LoginName] [nvarchar](128) NULL,
		[UserName] [nvarchar](128) NULL,
		[PrincipleType] [nvarchar](128) NULL,
		[Orphaned] [bit] NULL,
		[DefaultSchema] [nvarchar](128) NULL,
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
			SELECT SERVERPROPERTY('ServerName') AS [InstanceName], 'Server' AS [Type], 'N/A' AS [DatabaseName], sl.[name] AS [LoginName], 'N/A' AS [UserName], pr.[type_desc] AS [PrincipleType], CASE WHEN il.[sid] IS NULL THEN 0 ELSE 1 END AS [Orphaned], 'N/A' AS [DefaultSchema], GETDATE() AS [AsOfDate], 1 AS [Latest],
			'USE [master]; ' + 'CREATE LOGIN ' + QUOTENAME(pr.[name]) COLLATE database_default + CASE WHEN sl.[isntname] = 1 THEN ' FROM WINDOWS WITH DEFAULT_DATABASE=' + QUOTENAME(pr.[default_database_name]) COLLATE database_default ELSE ' WITH PASSWORD=N''CHANGEME'' MUST_CHANGE, DEFAULT_DATABASE=' + QUOTENAME(pr.[default_database_name]) COLLATE database_default + ', CHECK_EXPIRATION=ON, CHECK_POLICY=ON' END AS [CreateTSQL]
			FROM master.sys.server_principals AS pr
			LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
			LEFT JOIN #InvalidLogins AS il ON pr.[sid] = il.[sid]
			WHERE pr.[type] IN ('U', 'S', 'G');
		END
	IF @Type = 'All' OR @Type = 'Database'
		BEGIN
		IF @DatabaseName = 'All'
			BEGIN
				SET @StringToExecute = N'
				USE [?];
				INSERT INTO #Results
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type], DB_NAME() AS [DatabaseName], sl.[name] AS [LoginName], pr.[name] AS [UserName], pr.[type_desc] AS [PrincipleType], CASE WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], pr.[default_schema_name] AS [DefaultSchema], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + ''CREATE USER '' + QUOTENAME(pr.[name]) COLLATE database_default + '' FOR LOGIN '' + QUOTENAME(sl.[name]) COLLATE database_default + CASE WHEN pr.[default_schema_name] IS NULL THEN '''' ELSE '' WITH DEFAULT_SCHEMA = '' + QUOTENAME(pr.[default_schema_name]) COLLATE database_default END AS [CreateTSQL]
				FROM sys.database_principals AS pr
				LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
				WHERE pr.[type] IN (''U'', ''S'', ''G'')
				UNION ALL
				-- Roles
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type], DB_NAME() AS [DatabaseName], ''N/A'' AS [LoginName], [name] AS [UserName], ''Role'' AS [PrincipleType], 0 AS [Orphaned], ''N/A'' AS [DefaultSchema], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + ''CREATE ROLE '' + QUOTENAME([name]) COLLATE database_default AS [CreateTSQL]
				FROM sys.database_principals
				WHERE [principal_id] > 4 
				AND [is_fixed_role] <> 1
				AND [type] = ''R''
				ORDER BY [PrincipleType], [UserName]';
				EXEC master.sys.sp_MSforeachdb @StringToExecute
			END
		ELSE
			BEGIN
				SET @StringToExecute = N'
				USE ' + QUOTENAME(@DatabaseName) + N'
				INSERT INTO #Results
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type], DB_NAME() AS [DatabaseName], sl.[name] AS [LoginName], pr.[name] AS [UserName], pr.[type_desc] AS [PrincipleType], CASE WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], pr.[default_schema_name] AS [DefaultSchema], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + ''CREATE USER '' + QUOTENAME(pr.[name]) COLLATE database_default + '' FOR LOGIN '' + QUOTENAME(sl.[name]) COLLATE database_default + CASE WHEN pr.[default_schema_name] IS NULL THEN '''' ELSE '' WITH DEFAULT_SCHEMA = '' + QUOTENAME(pr.[default_schema_name]) COLLATE database_default END AS [CreateTSQL]
				FROM sys.database_principals AS pr
				LEFT JOIN master.sys.syslogins AS sl ON pr.[sid] = sl.[sid]
				WHERE pr.[type] IN (''U'', ''S'', ''G'')
				UNION ALL
				-- Roles
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type], DB_NAME() AS [DatabaseName], ''N/A'' AS [LoginName], [name] AS [UserName], ''Role'' AS [PrincipleType], 0 AS [Orphaned], ''N/A'' AS [DefaultSchema], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + ''CREATE ROLE '' + QUOTENAME([name]) COLLATE database_default AS [CreateTSQL]
				FROM sys.database_principals
				WHERE [principal_id] > 4 
				AND [is_fixed_role] <> 1
				AND [type] = ''R''
				ORDER BY [PrincipleType], [UserName]';
				EXEC(@StringToExecute);
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
				[LoginName] [nvarchar](128) NULL,
				[UserName] [nvarchar](128) NULL,
				[PrincipleType] [nvarchar](128) NULL,
				[Orphaned] [bit] NULL,
				[DefaultSchema] [nvarchar](128) NULL,
				[AsOfDate] [datetime] NULL,
				[Latest] [bit] NULL,
				[CreateTSQL] [nvarchar](max) NULL);'
			EXEC(@StringToExecute);
			SET @StringToExecute = N' IF EXISTS(SELECT * FROM '	+ @OutputDatabaseName + '.INFORMATION_SCHEMA.SCHEMATA WHERE QUOTENAME(SCHEMA_NAME) = ''' + @OutputSchemaName + ''') 
			UPDATE ' + @OutputDatabaseName + '.' + @OutputSchemaName + '.' + @OutputTableName + '
			SET [Latest] = 0 WHERE [Type] LIKE ''' + CASE @Type WHEN 'All' THEN '%' ELSE @Type END + '''
			INSERT ' + @OutputDatabaseName + '.' + @OutputSchemaName + '.' + @OutputTableName + ' (InstanceName, Type, DatabaseName, LoginName, UserName, PrincipleType, Orphaned, DefaultSchema, AsOfDate, Latest, CreateTSQL) 
			SELECT InstanceName, Type, DatabaseName, LoginName, UserName, PrincipleType, Orphaned, DefaultSchema, AsOfDate, Latest, CreateTSQL FROM #Results 
			ORDER BY [PrincipleType], [LoginName]';
			EXEC(@StringToExecute);
		END
	ELSE IF (SUBSTRING(@OutputTableName, 2, 2) = '##')
		BEGIN
			SET @StringToExecute = N' IF (OBJECT_ID(''tempdb..'	+ @OutputTableName + ''') IS NOT NULL) DROP TABLE ' + @OutputTableName + ';
			CREATE TABLE ' + @OutputTableName + ' (
				[InstanceName] [sql_variant] NULL,
				[Type] [varchar](50) NULL,
				[DatabaseName] [nvarchar](128) NULL,
				[LoginName] [nvarchar](128) NULL,
				[UserName] [nvarchar](128) NULL,
				[PrincipleType] [nvarchar](128) NULL,
				[Orphaned] [bit] NULL,
				[DefaultSchema] [nvarchar](128) NULL,
				[AsOfDate] [datetime] NULL,
				[Latest] [bit] NULL,
				[CreateTSQL] [nvarchar](max) NULL);
			INSERT ' + @OutputTableName	+ ' (InstanceName, Type, DatabaseName, LoginName, UserName, PrincipleType, Orphaned, DefaultSchema, AsOfDate, Latest, CreateTSQL) 
			SELECT InstanceName, Type, DatabaseName, LoginName, UserName, PrincipleType, Orphaned, DefaultSchema, AsOfDate, Latest, CreateTSQL FROM #Results
			ORDER BY [Type],[DatabaseName],[PrincipleType], [LoginName]';
			EXEC(@StringToExecute);
		END
	ELSE IF (SUBSTRING(@OutputTableName, 2, 1) = '#')
		BEGIN
			RAISERROR('Due to the nature of Dymamic SQL, only global (i.e. double pound (##)) temp tables are supported for @OutputTableName', 16, 0)
		END
	ELSE 
		BEGIN
			SELECT InstanceName, Type, DatabaseName, LoginName, UserName, PrincipleType, Orphaned, DefaultSchema, AsOfDate, Latest, CreateTSQL FROM #Results
			ORDER BY [Type],[DatabaseName],[PrincipleType], [LoginName]
		END
	DROP TABLE #Results
GO

dbo.usp_GetSecurityPrinciples @OutputDatabaseName = 'DBAUtility', @OutputSchemaName = 'dbo', @OutputTableName = 'Testing'
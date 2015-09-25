IF OBJECT_ID('dbo.usp_GetSecurityRoles') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_GetSecurityRoles AS RETURN 0;')
GO
ALTER PROCEDURE dbo.usp_GetSecurityRoles
    @Type				VARCHAR(20)	  = 'All',
	@DatabaseName		NVARCHAR(128) = 'All',
	@OutputDatabaseName NVARCHAR(128) = NULL ,
    @OutputSchemaName	NVARCHAR(256) = NULL ,
    @OutputTableName	NVARCHAR(256) = NULL
AS
	/*
	Stored Procedure:	usp_GetSecurityRoles
	Created by:			Ryan DeVries http://RyanDeVries.com/
	Updated:			2015-09-24
	Version:			1.0

	Parameters:
	@Type				One of the following: All, Database, Server (Defaults to All)
							All - Pulls Server Roles and Database Roles
							Database - Pulls just Database Roles (See @DatabaseName parameter)
							Server - Pulls just Server Roles
	@DatabaseName		The name of the database to target if @Type = All or Database (Defaults to All)
							All - Pulls Database Roles for all databases using ms_foreachDB
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
		[RoleName] [nvarchar](128) NULL,
		[LoginName] [nvarchar](128) NULL,
		[UserName] [nvarchar](128) NULL,
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
			SELECT SERVERPROPERTY('ServerName') AS [InstanceName], 'Server' AS [Type], 'N/A' AS [DatabaseName], spr.[name] AS [RoleName], spm.[name] AS [LoginName], 'N/A' AS [UserName], CASE WHEN spm.[type] = 'R' THEN 0 WHEN il.[sid] IS NULL THEN 0 ELSE 1 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
			'USE [master]; ' + 'EXEC sp_addsrvrolemember @rolename = '  + QUOTENAME(spr.[name], '''') COLLATE database_default + ', @membername = ' + QUOTENAME(spm.[name], '''') COLLATE database_default AS [CreateTSQL]
			FROM master.sys.server_role_members AS srm
			INNER JOIN master.sys.server_principals AS spr ON srm.[role_principal_id] = spr.[principal_id]
			INNER JOIN master.sys.server_principals AS spm ON srm.[member_principal_id] = spm.[principal_id]
			LEFT JOIN #InvalidLogins AS il ON spm.[sid] = il.[sid]
			ORDER BY [Type],[DatabaseName],[RoleName],[LoginName],[UserName];
		END
	IF @Type = 'All' OR @Type = 'Database'
		BEGIN
		IF @DatabaseName = 'All'
			BEGIN
				SET @StringToExecute = N'
				USE [?];
				INSERT INTO #Results
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type], DB_NAME() AS [DatabaseName], dpr.[name] AS [RoleName], ISNULL(sl.[name],''N/A'') AS [LoginName], dpm.[name] AS [UserName], CASE WHEN dpm.[type] = ''R'' THEN 0 WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + ''EXEC sp_addrolemember @rolename = ''  + QUOTENAME(dpr.[name], '''''''') COLLATE database_default + '', @membername = '' + QUOTENAME(dpm.[name], '''''''') COLLATE database_default AS [CreateTSQL]
				FROM sys.database_role_members AS drm
				LEFT JOIN sys.database_principals AS dpr ON drm.[role_principal_id] = dpr.[principal_id]
				LEFT JOIN sys.database_principals AS dpm ON drm.[member_principal_id] = dpm.[principal_id]
				LEFT JOIN sys.syslogins AS sl ON dpm.[sid] = sl.[sid]
				ORDER BY [RoleName], [UserName]';
				EXEC master.sys.sp_MSforeachdb @StringToExecute
			END
		ELSE
			BEGIN
				SET @StringToExecute = N'
				USE ' + QUOTENAME(@DatabaseName) + N';
				INSERT INTO #Results
				SELECT SERVERPROPERTY(''ServerName'') AS [InstanceName], ''Database'' AS [Type], DB_NAME() AS [DatabaseName], dpr.[name] AS [RoleName], ISNULL(sl.[name],''N/A'') AS [LoginName], dpm.[name] AS [UserName], CASE WHEN dpm.[type] = ''R'' THEN 0 WHEN sl.[sid] IS NULL THEN 1 ELSE 0 END AS [Orphaned], GETDATE() AS [AsOfDate], 1 AS [Latest],
				''USE '' + QUOTENAME(DB_NAME()) COLLATE database_default + ''; '' + ''EXEC sp_addrolemember @rolename = ''  + QUOTENAME(dpr.[name], '''''''') COLLATE database_default + '', @membername = '' + QUOTENAME(dpm.[name], '''''''') COLLATE database_default AS [CreateTSQL]
				FROM sys.database_role_members AS drm
				LEFT JOIN sys.database_principals AS dpr ON drm.[role_principal_id] = dpr.[principal_id]
				LEFT JOIN sys.database_principals AS dpm ON drm.[member_principal_id] = dpm.[principal_id]
				LEFT JOIN sys.syslogins AS sl ON dpm.[sid] = sl.[sid]
				ORDER BY [RoleName], [UserName]';
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
				[RoleName] [nvarchar](128) NULL,
				[LoginName] [nvarchar](128) NULL,
				[UserName] [nvarchar](128) NULL,
				[Orphaned] [bit] NULL,
				[AsOfDate] [datetime] NULL,
				[Latest] [bit] NULL,
				[CreateTSQL] [nvarchar](max) NULL);'
			EXEC(@StringToExecute);
			SET @StringToExecute = N' IF EXISTS(SELECT * FROM '	+ @OutputDatabaseName + '.INFORMATION_SCHEMA.SCHEMATA WHERE QUOTENAME(SCHEMA_NAME) = ''' + @OutputSchemaName + ''') 
			UPDATE ' + @OutputDatabaseName + '.' + @OutputSchemaName + '.' + @OutputTableName + '
			SET [Latest] = 0 WHERE [Type] LIKE ''' + CASE @Type WHEN 'All' THEN '%' ELSE @Type END + '''
			INSERT ' + @OutputDatabaseName + '.' + @OutputSchemaName + '.' + @OutputTableName + ' (InstanceName, Type, DatabaseName, RoleName, LoginName, UserName, Orphaned, AsOfDate, Latest, CreateTSQL) 
			SELECT InstanceName, Type, DatabaseName, RoleName, LoginName, UserName, Orphaned, AsOfDate, Latest, CreateTSQL FROM #Results 
			ORDER BY [Type],[DatabaseName],[RoleName],[LoginName],[UserName]';
			EXEC(@StringToExecute);
		END
	ELSE IF (SUBSTRING(@OutputTableName, 2, 2) = '##')
		BEGIN
			SET @StringToExecute = N' IF (OBJECT_ID(''tempdb..'	+ @OutputTableName + ''') IS NOT NULL) DROP TABLE ' + @OutputTableName + ';
			CREATE TABLE ' + @OutputTableName + ' (
				[InstanceName] [sql_variant] NULL,
				[Type] [varchar](50) NULL,
				[DatabaseName] [nvarchar](128) NULL,
				[RoleName] [nvarchar](128) NULL,
				[LoginName] [nvarchar](128) NULL,
				[UserName] [nvarchar](128) NULL,
				[Orphaned] [bit] NULL,
				[AsOfDate] [datetime] NULL,
				[Latest] [bit] NULL,
				[CreateTSQL] [nvarchar](max) NULL);
			INSERT ' + @OutputTableName	+ ' (InstanceName, Type, DatabaseName, RoleName, LoginName, UserName, Orphaned, AsOfDate, Latest, CreateTSQL) 
			SELECT InstanceName, Type, DatabaseName, RoleName, LoginName, UserName, Orphaned, AsOfDate, Latest, CreateTSQL FROM #Results
			ORDER BY [Type],[DatabaseName],[RoleName],[LoginName],[UserName]';
			EXEC(@StringToExecute);
		END
	ELSE IF (SUBSTRING(@OutputTableName, 2, 1) = '#')
		BEGIN
			RAISERROR('Due to the nature of Dymamic SQL, only global (i.e. double pound (##)) temp tables are supported for @OutputTableName', 16, 0)
		END
	ELSE 
		BEGIN
			SELECT InstanceName, Type, DatabaseName, RoleName, LoginName, UserName, Orphaned, AsOfDate, Latest, CreateTSQL FROM #Results
			ORDER BY [Type],[DatabaseName],[RoleName],[LoginName],[UserName]
		END
	DROP TABLE #Results
GO

dbo.usp_GetSecurityRoles @OutputDatabaseName = 'DBAUtility', @OutputSchemaName = 'dbo', @OutputTableName = 'Testing2'
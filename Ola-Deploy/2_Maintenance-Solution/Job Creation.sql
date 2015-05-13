-- Ola Hallengren-based Job Creation
SET NOCOUNT ON
IF SERVERPROPERTY('EngineEdition') <> 4
BEGIN
	-- All the variables needed for creating the jobs
	DECLARE @BackupDirectory nvarchar(max), @CleanupTime  int,           @OutputFileDirectory nvarchar(max), @LogToTable   nvarchar(max), @DatabaseName nvarchar(max), @Version           numeric(18,10)
	DECLARE @JobDescription  nvarchar(max), @JobCategory  nvarchar(max), @JobOwner            nvarchar(max)
	DECLARE @TokenServer     nvarchar(max), @TokenJobID   nvarchar(max), @TokenStepID         nvarchar(max), @TokenDate    nvarchar(max), @TokenTime    nvarchar(max), @TokenLogDirectory nvarchar(max)
	DECLARE @JobName01       nvarchar(max), @JobName02    nvarchar(max), @JobName03           nvarchar(max), @JobName04    nvarchar(max), @JobName05    nvarchar(max), @JobName06         nvarchar(max), @JobName07    nvarchar(max), @JobName08    nvarchar(max), @JobName09    nvarchar(max), @JobName10    nvarchar(max), @JobName11    nvarchar(max)
	DECLARE @JobCommand01    nvarchar(max), @JobCommand02 nvarchar(max), @JobCommand03        nvarchar(max), @JobCommand04 nvarchar(max), @JobCommand05 nvarchar(max), @JobCommand06      nvarchar(max), @JobCommand07 nvarchar(max), @JobCommand08 nvarchar(max), @JobCommand09 nvarchar(max), @JobCommand10 nvarchar(max), @JobCommand11 nvarchar(max)
	DECLARE @OutputFile01    nvarchar(max), @OutputFile02 nvarchar(max), @OutputFile03        nvarchar(max), @OutputFile04 nvarchar(max), @OutputFile05 nvarchar(max), @OutputFile06      nvarchar(max), @OutputFile07 nvarchar(max), @OutputFile08 nvarchar(max), @OutputFile09 nvarchar(max), @OutputFile10 nvarchar(max), @OutputFile11 nvarchar(max)
	-- Common job parameters
	SET @DatabaseName        =  'DBAUtility'
	SET @BackupDirectory     = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\Backup' --\\exahub03_nic4\SQL_Backups
	SET @CleanupTime         =  '168'
	SET @OutputFileDirectory =   NULL
	SET @LogToTable          =  'Y'
	SET @JobDescription      =  'MNA Standard Database Maintenance, Source: https://ola.hallengren.com'
	SET @JobCategory         =  'Database Maintenance'
	SET @JobOwner            =   SUSER_SNAME(0x01)
	-- Convert version to use for version-specific sections
	SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))
	-- Set output directory to default log path if not specified
	IF @OutputFileDirectory IS NULL AND @Version < 12
	BEGIN
		IF @Version >= 11
		BEGIN
			SELECT @OutputFileDirectory = [path]
			FROM sys.dm_os_server_diagnostics_log_configurations
		END
		ELSE
		BEGIN
			SELECT @OutputFileDirectory = LEFT(CAST(SERVERPROPERTY('ErrorLogFileName') AS nvarchar(max)),LEN(CAST(SERVERPROPERTY('ErrorLogFileName') AS nvarchar(max))) - CHARINDEX('\',REVERSE(CAST(SERVERPROPERTY('ErrorLogFileName') AS nvarchar(max)))))
		END
	END
	-- Set up tokens to be used in output path
	IF @Version >= 9.002047
	BEGIN
		SET @TokenServer = '$' + '(ESCAPE_SQUOTE(SRVR))'
		SET @TokenJobID  = '$' + '(ESCAPE_SQUOTE(JOBID))'
		SET @TokenStepID = '$' + '(ESCAPE_SQUOTE(STEPID))'
		SET @TokenDate   = '$' + '(ESCAPE_SQUOTE(STRTDT))'
		SET @TokenTime   = '$' + '(ESCAPE_SQUOTE(STRTTM))'
	END
	ELSE
	BEGIN
		SET @TokenServer = '$' + '(SRVR)'
		SET @TokenJobID  = '$' + '(JOBID)'
		SET @TokenStepID = '$' + '(STEPID)'
		SET @TokenDate   = '$' + '(STRTDT)'
		SET @TokenTime   = '$' + '(STRTTM)'
	END
	IF @Version >= 12
	BEGIN
		SET @TokenLogDirectory = '$' + '(ESCAPE_SQUOTE(SQLLOGDIR))'
	END
	-- Set job names
	SET @JobName01    = 'Maintenance - Backups - SYSTEM - FULL'
	SET @JobName02    = 'Maintenance - Backups - USER - FULL'
	SET @JobName03    = 'Maintenance - Backups - USER - DIFF'
	SET @JobName04    = 'Maintenance - Backups - USER - LOG'
	SET @JobName05    = 'Maintenance - DatabaseIntegrityCheck - USER'
	SET @JobName06    = 'Maintenance - DatabaseIntegrityCheck - SYSTEM'
	SET @JobName07    = 'Maintenance - IndexOptimize - USER'
	SET @JobName08    = 'Maintenance - CommandLog Cleanup'
	SET @JobName09    = 'Maintenance - Output File Cleanup'
	SET @JobName10    = 'Maintenance - sp_delete_backuphistory'
	SET @JobName11    = 'Maintenance - sp_purge_jobhistory'
	-- Set job commands
	SET @JobCommand01 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''SYSTEM_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ', @CheckSum = ''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand02 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ', @CheckSum = ''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand03 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''DIFF'', @ChangeBackupType = ''Y'', @Verify = ''Y'', @CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ', @CheckSum = ''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand04 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''LOG'', @ChangeBackupType = ''Y'', @Verify = ''Y'', @CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ', @CheckSum = ''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand05 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''USER_DATABASES''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand06 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''SYSTEM_DATABASES''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand07 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[IndexOptimize] @Databases = ''USER_DATABASES'', @FragmentationLevel1 = 10%, @FragmentationLevel2 = 50%, @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE'', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @UpdateStatistics = ''ALL'', @OnlyModifiedStatistics = ''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand08 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "DELETE FROM [dbo].[CommandLog] WHERE StartTime < DATEADD(dd,-30,GETDATE())" -b'
	SET @JobCommand09 = 'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '" /m *_*_*_*.txt /d -30 2^>^&1'') do if EXIST "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '"\%v echo del "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '"\%v& del "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '"\%v"'
	SET @JobCommand10 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + 'msdb' + ' -Q "DECLARE @CleanupDate datetime SET @CleanupDate = DATEADD(dd,-30,GETDATE()) EXECUTE dbo.sp_delete_backuphistory @oldest_date = @CleanupDate" -b'
	SET @JobCommand11 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + 'msdb' + ' -Q "DECLARE @CleanupDate datetime SET @CleanupDate = DATEADD(dd,-30,GETDATE()) EXECUTE dbo.sp_purge_jobhistory @oldest_date = @CleanupDate" -b'
	-- Set output file path
	SET @OutputFile01 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'MntBackupSysF_'          + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	SET @OutputFile02 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'MntBackupUsrF_'          + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	SET @OutputFile03 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'MntBackupUsrD_'          + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	SET @OutputFile04 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'MntBackupUsrL_'          + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	SET @OutputFile05 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'MntIntegrityCheckUsr_'   + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	SET @OutputFile06 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'MntIntegrityCheckSys_'   + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	SET @OutputFile07 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'MntIndexOptimize_'       + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	SET @OutputFile08 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'MntCommandLogCleanup_'   + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	SET @OutputFile09 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'MntOutputFileCleanup_'   + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	SET @OutputFile10 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'Mntspdeletebackuphist_'  + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	SET @OutputFile11 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'Mntsppurgejobhistory_'   + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	-- Get rid of identifier if output file path is too long	
	IF LEN(@OutputFile01) > 200 SET @OutputFile01 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFile02) > 200 SET @OutputFile02 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFile03) > 200 SET @OutputFile03 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFile04) > 200 SET @OutputFile04 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFile05) > 200 SET @OutputFile05 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFile06) > 200 SET @OutputFile06 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFile07) > 200 SET @OutputFile07 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFile08) > 200 SET @OutputFile08 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFile09) > 200 SET @OutputFile09 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFile10) > 200 SET @OutputFile10 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFile11) > 200 SET @OutputFile11 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
	-- Null output file path if it is still too long
	IF LEN(@OutputFile01) > 200 SET @OutputFile01 = NULL
	IF LEN(@OutputFile02) > 200 SET @OutputFile02 = NULL
	IF LEN(@OutputFile03) > 200 SET @OutputFile03 = NULL
	IF LEN(@OutputFile04) > 200 SET @OutputFile04 = NULL
	IF LEN(@OutputFile05) > 200 SET @OutputFile05 = NULL
	IF LEN(@OutputFile06) > 200 SET @OutputFile06 = NULL
	IF LEN(@OutputFile07) > 200 SET @OutputFile07 = NULL
	IF LEN(@OutputFile08) > 200 SET @OutputFile08 = NULL
	IF LEN(@OutputFile09) > 200 SET @OutputFile09 = NULL
	IF LEN(@OutputFile10) > 200 SET @OutputFile10 = NULL
	IF LEN(@OutputFile11) > 200 SET @OutputFile11 = NULL
	-- Create the jobs
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName01)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName01, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName01, @step_name   = @JobName01,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand01, @output_file_name = @OutputFile01
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName01
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName02)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName02, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName02, @step_name   = @JobName02,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand02, @output_file_name = @OutputFile02
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName02
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName03)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName03, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName03, @step_name   = @JobName03,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand03, @output_file_name = @OutputFile03
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName03
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName04)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName04, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName04, @step_name   = @JobName04,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand04, @output_file_name = @OutputFile04
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName04
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName05)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName05, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName05, @step_name   = @JobName05,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand05, @output_file_name = @OutputFile05
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName05
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName06)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName06, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName06, @step_name   = @JobName06,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand06, @output_file_name = @OutputFile06
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName06
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName07)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName07, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName07, @step_name   = @JobName07,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand07, @output_file_name = @OutputFile07
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName07
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName08)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName08, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName08, @step_name   = @JobName08,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand08, @output_file_name = @OutputFile08
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName08
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName09)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName09, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName09, @step_name   = @JobName09,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand09, @output_file_name = @OutputFile09
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName09
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName10)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName10, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName10, @step_name   = @JobName10,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand10, @output_file_name = @OutputFile10
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName10
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName11)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName11, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName11, @step_name   = @JobName11,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand11, @output_file_name = @OutputFile11
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName11
	END
END
GO

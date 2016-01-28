-- Ola Hallengren-based Job Creation
SET NOCOUNT ON
IF SERVERPROPERTY('EngineEdition') <> 4
BEGIN
	-- All the variables needed for creating the jobs
	DECLARE @BackupDirectory nvarchar(max), @CleanupTime  int,           @OutputFileDirectory nvarchar(max), @LogToTable   nvarchar(max), @DatabaseName nvarchar(max), @Version           numeric(18,10)
	DECLARE @JobDescription  nvarchar(max), @JobCategory  nvarchar(max), @JobOwner            nvarchar(max), @NotifyEmail  nvarchar(max), @ServerType   char(1)
	DECLARE @TokenServer     nvarchar(max), @TokenJobID   nvarchar(max), @TokenStepID         nvarchar(max), @TokenDate    nvarchar(max), @TokenTime    nvarchar(max), @TokenLogDirectory nvarchar(max)
	DECLARE @JobName01       nvarchar(max), @JobName02    nvarchar(max), @JobName03           nvarchar(max), @JobName04    nvarchar(max), @JobName05    nvarchar(max), @JobName06         nvarchar(max), @JobName07    nvarchar(max), @JobName08    nvarchar(max), @JobName09    nvarchar(max), @JobName10    nvarchar(max), @JobName11    nvarchar(max), @JobName12    nvarchar(max)
	DECLARE @JobCommand01    nvarchar(max), @JobCommand02 nvarchar(max), @JobCommand03        nvarchar(max), @JobCommand04 nvarchar(max), @JobCommand05 nvarchar(max), @JobCommand06      nvarchar(max), @JobCommand07 nvarchar(max), @JobCommand08 nvarchar(max), @JobCommand09 nvarchar(max), @JobCommand10 nvarchar(max), @JobCommand11 nvarchar(max), @JobCommand12 nvarchar(max)
	DECLARE @OutputFile01    nvarchar(max), @OutputFile02 nvarchar(max), @OutputFile03        nvarchar(max), @OutputFile04 nvarchar(max), @OutputFile05 nvarchar(max), @OutputFile06      nvarchar(max), @OutputFile07 nvarchar(max), @OutputFile08 nvarchar(max), @OutputFile09 nvarchar(max), @OutputFile10 nvarchar(max), @OutputFile11 nvarchar(max), @OutputFile12 nvarchar(max)

--  ##################################################################################################################################
	-- Common job parameters
	SET @ServerType          = 'P'                            -- Server type (for scheduling): (D)evelopment, (T)est, or (P)roduction	
	SET @DatabaseName        = 'DBAUtility'                   -- Name of database the Maintenance Solution was installed into
	SET @BackupDirectory     = N'\\server\SQL_Backups'        -- Root path to the backups, Server-named will be created automatically 
	SET @CleanupTime         = '336'                          -- Amount of time in hours before database backups are deleted
	SET @OutputFileDirectory = NULL                           -- Path to write output files from job steps, defaults to local log path
	SET @LogToTable          = 'Y'                            -- Logs to CommandLog table
	SET @JobCategory         = 'Database Maintenance'         -- Categorizes all the jobs
	SET @JobOwner            = SUSER_SNAME(0x01)              -- Sets owner to SA account
	SET @NotifyEmail         = N'SQL Alerts'                  -- Name of the operator to use for notifications
	SET @JobDescription      = 'Company Standard Database Maintenance, Source: https://ola.hallengren.com'
--  ##################################################################################################################################

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
	SET @JobName12    = 'Maintenance - Backups - SYSTEM - LOG'
	-- Set job commands
	SET @JobCommand01 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''SYSTEM_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ', @CheckSum = ''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand02 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ', @CheckSum = ''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand03 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''DIFF'', @ChangeBackupType = ''Y'', @Verify = ''Y'', @CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ', @CheckSum = ''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand04 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''LOG'', @ChangeBackupType = ''Y'', @Verify = ''Y'', @CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ', @CheckSum = ''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand05 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''USER_DATABASES''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand06 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''SYSTEM_DATABASES''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand07 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[IndexOptimize] @Databases = ''USER_DATABASES'', @FragmentationLevel1 = 10, @FragmentationLevel2 = 50, @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE'', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @UpdateStatistics = ''ALL'', @OnlyModifiedStatistics = ''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
	SET @JobCommand08 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "DELETE FROM [dbo].[CommandLog] WHERE StartTime < DATEADD(dd,-30,GETDATE())" -b'
	SET @JobCommand09 = 'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '" /m *_*_*_*.txt /d -30 2^>^&1'') do if EXIST "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '"\%v echo del "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '"\%v& del "' + COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '"\%v"'
	SET @JobCommand10 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + 'msdb' + ' -Q "DECLARE @CleanupDate datetime SET @CleanupDate = DATEADD(dd,-30,GETDATE()) EXECUTE dbo.sp_delete_backuphistory @oldest_date = @CleanupDate" -b'
	SET @JobCommand11 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + 'msdb' + ' -Q "DECLARE @CleanupDate datetime SET @CleanupDate = DATEADD(dd,-90,GETDATE()) EXECUTE dbo.sp_purge_jobhistory @oldest_date = @CleanupDate" -b'
	SET @JobCommand12 = 'sqlcmd -E -S ' + @TokenServer + ' -d ' + @DatabaseName + ' -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''SYSTEM_DATABASES'', @Directory = ' + ISNULL('N''' + REPLACE(@BackupDirectory,'''','''''') + '''','NULL') + ', @BackupType = ''LOG'', @ChangeBackupType = ''Y'', @Verify = ''Y'', @CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL') + ', @CheckSum = ''Y''' + CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + '" -b'
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
	SET @OutputFile12 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'MntBackupSysL_'          + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
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
	IF LEN(@OutputFile12) > 200 SET @OutputFile12 = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
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
	IF LEN(@OutputFile12) > 200 SET @OutputFile12 = NULL
	-- Create the jobs
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName01)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName01, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName01, @step_name   = @JobName01,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand01, @output_file_name = @OutputFile01
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName01
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName02)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName02, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName02, @step_name   = @JobName02,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand02, @output_file_name = @OutputFile02
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName02
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName03)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName03, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName03, @step_name   = @JobName03,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand03, @output_file_name = @OutputFile03
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName03
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName04)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName04, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName04, @step_name   = @JobName04,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand04, @output_file_name = @OutputFile04
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName04
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName05)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName05, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName05, @step_name   = @JobName05,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand05, @output_file_name = @OutputFile05
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName05
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName06)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName06, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName06, @step_name   = @JobName06,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand06, @output_file_name = @OutputFile06
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName06
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName07)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName07, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName07, @step_name   = @JobName07,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand07, @output_file_name = @OutputFile07
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName07
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName08)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName08, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName08, @step_name   = @JobName08,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand08, @output_file_name = @OutputFile08
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName08
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName09)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName09, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName09, @step_name   = @JobName09,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand09, @output_file_name = @OutputFile09
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName09
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName10)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName10, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName10, @step_name   = @JobName10,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand10, @output_file_name = @OutputFile10
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName10
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName11)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName11, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName11, @step_name   = @JobName11,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand11, @output_file_name = @OutputFile11
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName11
	END
	IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobName12)
	BEGIN
		EXECUTE msdb.dbo.sp_add_job       @job_name = @JobName12, @description = @JobDescription, @category_name = @JobCategory, @owner_login_name = @JobOwner,     @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
		EXECUTE msdb.dbo.sp_add_jobstep   @job_name = @JobName12, @step_name   = @JobName12,      @subsystem     = 'CMDEXEC',    @command          = @JobCommand12, @output_file_name = @OutputFile12
		EXECUTE msdb.dbo.sp_add_jobserver @job_name = @JobName12
	END
	IF EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = N'syspolicy_purge_history')
	BEGIN
		EXECUTE msdb.dbo.sp_update_job    @job_name=N'syspolicy_purge_history', @new_name=N'Maintenance - syspolicy_purge_history', @notify_email_operator_name = @NotifyEmail, @notify_level_email = 2
	END

	-- All the variables needed for creating the schedules and adding them to the jobs
	DECLARE @CreateSch     bit
	DECLARE @SchOwner      nvarchar(max)
	DECLARE @SchName01     nvarchar(max), @SchName02     nvarchar(max), @SchName03     nvarchar(max), @SchName04     nvarchar(max), @SchName05     nvarchar(max), @SchName06     nvarchar(max), @SchName07     nvarchar(max), @SchName08     nvarchar(max), @SchName09     nvarchar(max)
	DECLARE @SchFreqType01 int,           @SchFreqType02 int,           @SchFreqType03 int,           @SchFreqType04 int,           @SchFreqType05 int,           @SchFreqType06 int,           @SchFreqType07 int,           @SchFreqType08 int,           @SchFreqType09 int
	DECLARE @SchFreqInt01  int,           @SchFreqInt02  int,           @SchFreqInt03  int,           @SchFreqInt04  int,           @SchFreqInt05  int,           @SchFreqInt06  int,           @SchFreqInt07  int,           @SchFreqInt08  int,           @SchFreqInt09  int
	DECLARE @SchSubType01  int,           @SchSubType02  int,           @SchSubType03  int,           @SchSubType04  int,           @SchSubType05  int,           @SchSubType06  int,           @SchSubType07  int,           @SchSubType08  int,           @SchSubType09  int
	DECLARE @SchSubInt01   int,           @SchSubInt02   int,           @SchSubInt03   int,           @SchSubInt04   int,           @SchSubInt05   int,           @SchSubInt06   int,           @SchSubInt07   int,           @SchSubInt08   int,           @SchSubInt09   int
	DECLARE @SchRelInt01   int,           @SchRelInt02   int,           @SchRelInt03   int,           @SchRelInt04   int,           @SchRelInt05   int,           @SchRelInt06   int,           @SchRelInt07   int,           @SchRelInt08   int,           @SchRelInt09   int
	DECLARE @SchFreqRec01  int,           @SchFreqRec02  int,           @SchFreqRec03  int,           @SchFreqRec04  int,           @SchFreqRec05  int,           @SchFreqRec06  int,           @SchFreqRec07  int,           @SchFreqRec08  int,           @SchFreqRec09  int
	DECLARE @SchStart01    int,           @SchStart02    int,           @SchStart03    int,           @SchStart04    int,           @SchStart05    int,           @SchStart06    int,           @SchStart07    int,           @SchStart08    int,           @SchStart09    int
	DECLARE @SchEnd01      int,           @SchEnd02      int,           @SchEnd03      int,           @SchEnd04      int,           @SchEnd05      int,           @SchEnd06      int,           @SchEnd07      int,           @SchEnd08      int,           @SchEnd09      int
	DECLARE @SchEnable01   tinyint,       @SchEnable02   tinyint,       @SchEnable03   tinyint,       @SchEnable04   tinyint,       @SchEnable05   tinyint,       @SchEnable06   tinyint,       @SchEnable07   tinyint,       @SchEnable08   tinyint,       @SchEnable09   tinyint

	-- Set SA account as schedule owner
	SET @SchOwner  = SUSER_SNAME(0x01)
	
	IF @ServerType = 'D'
	BEGIN
		-- Schedule Names
		SET @SchName01 = 'Development System Full Backups - Daily 7:30PM'
		SET @SchName02 = 'Development User Full Backups - Sunday 3AM'
		SET @SchName03 = 'Development User Diff Backups - MTWThFSa 3AM'
		SET @SchName04 = 'Development User TLog Backups - Hourly 4AM-2AM'
		SET @SchName05 = 'Development User CheckDB - Sunday 2AM'
		SET @SchName06 = 'Development System CheckDB - Daily 7PM'
		SET @SchName07 = 'Development Index Maintenance - Sunday 1AM'
		SET @SchName08 = 'Development Cleanup - Sunday 11:45PM'
		SET @SchName09 = 'Development System TLog Backups - Hourly 8:30PM-6:30PM'
		
		-- Frequency Type: 1 = Once, 4 = Daily, 8 = Weekly, 16 = Monthly, 32 = Monthly relativity to freq_interval, 64 = When the agent starts, 128 = When idle
		-- Frequency Interval, depends on freq_type: 
			-- 1  : Unused
			-- 4  : Every specified number of days
			-- 8  : Logical OR, 1 = Sunday, 2 = Monday, 4 = Tuesday, 8 = Wednesday, 16 = Thursday, 32 = Friday, 64 = Saturday
			-- 16 : On the specified day of the month
			-- 32 : 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday, 7 = Saturday, 8 = Day, 9 = Weekday, 10 = Weekend day
			-- 64 : Unused
			-- 128: Unused
		-- Frequency Subday Type, units for freq_subday_interval: 1 = At the specified time, 2 = Seconds, 4 = Minutes, 8 = Hours
		-- Frequency Subday Interval, number of freq_subday_type periods to occur between each execution
		-- Frequency Relative Interval, only used for freq_interval of 32: 1 = First, 2 = Second, 4 = Third, 8 = Fourth, 16 = Last
		-- Frequency Recurrence Factor, only used for freq_type of 8, 16, or 32: Number of weeks or months between each execution
		-- Start Time on the 24 hr clock
		-- End Time on the 24 hr clock
		SELECT @SchFreqType01 = 4,      @SchFreqType02 = 8,      @SchFreqType03 = 8,      @SchFreqType04 = 4,     @SchFreqType05 = 8,      @SchFreqType06 = 4,      @SchFreqType07 = 8,      @SchFreqType08 = 8,      @SchFreqType09 = 4 
		SELECT @SchFreqInt01  = 1,      @SchFreqInt02  = 1,      @SchFreqInt03  = 126,    @SchFreqInt04  = 1,     @SchFreqInt05  = 1,      @SchFreqInt06  = 1,      @SchFreqInt07  = 1,      @SchFreqInt08  = 1,      @SchFreqInt09  = 1  
		SELECT @SchSubType01  = 1,      @SchSubType02  = 1,      @SchSubType03  = 1,      @SchSubType04  = 8,     @SchSubType05  = 1,      @SchSubType06  = 1,      @SchSubType07  = 1,      @SchSubType08  = 1,      @SchSubType09  = 8 
		SELECT @SchSubInt01   = 0,      @SchSubInt02   = 0,      @SchSubInt03   = 0,      @SchSubInt04   = 1,     @SchSubInt05   = 0,      @SchSubInt06   = 0,      @SchSubInt07   = 0,      @SchSubInt08   = 0,      @SchSubInt09   = 1  
		SELECT @SchRelInt01   = 0,      @SchRelInt02   = 0,      @SchRelInt03   = 0,      @SchRelInt04   = 0,     @SchRelInt05   = 0,      @SchRelInt06   = 0,      @SchRelInt07   = 0,      @SchRelInt08   = 0,      @SchRelInt09   = 0  
		SELECT @SchFreqRec01  = 1,      @SchFreqRec02  = 1,      @SchFreqRec03  = 1,      @SchFreqRec04  = 1,     @SchFreqRec05  = 1,      @SchFreqRec06  = 1,      @SchFreqRec07  = 1,      @SchFreqRec08  = 1,      @SchFreqRec09  = 1 
		SELECT @SchStart01    = 193000, @SchStart02    = 30000,  @SchStart03    = 30000,  @SchStart04    = 40000, @SchStart05    = 20000,  @SchStart06    = 190000, @SchStart07    = 10000,  @SchStart08    = 234500, @SchStart09    = 203000
		SELECT @SchEnd01      = 235959, @SchEnd02      = 235959, @SchEnd03      = 235959, @SchEnd04      = 15959, @SchEnd05      = 235959, @SchEnd06      = 235959, @SchEnd07      = 235959, @SchEnd08      = 235959, @SchEnd09      = 182959
		SELECT @SchEnable01   = 1,      @SchEnable02   = 1,      @SchEnable03   = 1,      @SchEnable04   = 1,     @SchEnable05   = 1,      @SchEnable06   = 1,      @SchEnable07   = 1,      @SchEnable08   = 1,      @SchEnable09   = 1   
	
		SET @CreateSch = 1
	END

	ELSE IF @ServerType = 'T'
	BEGIN
		-- Schedule Names
		SET @SchName01 = 'Test System Full Backups - Daily 8:30PM'
		SET @SchName02 = 'Test User Full Backups - Sunday 1:30AM'
		SET @SchName03 = 'Test User Diff Backups - MTWThFSa 1:30AM'
		SET @SchName04 = 'Test User TLog Backups - Hourly 2:30AM-12:30AM'
		SET @SchName05 = 'Test User CheckDB - Sunday 12:30AM'
		SET @SchName06 = 'Test System CheckDB - Daily 8PM'
		SET @SchName07 = 'Test Index Maintenance - Saturday 11:30PM'
		SET @SchName08 = 'Test Cleanup - Sunday 11:45PM'
		SET @SchName09 = 'Test System TLog Backups - Hourly 9:30PM-7:30PM'

		-- Frequency Type: 1 = Once, 4 = Daily, 8 = Weekly, 16 = Monthly, 32 = Monthly relativity to freq_interval, 64 = When the agent starts, 128 = When idle
		-- Frequency Interval, depends on freq_type: 
			-- 1  : Unused
			-- 4  : Every specified number of days
			-- 8  : Logical OR, 1 = Sunday, 2 = Monday, 4 = Tuesday, 8 = Wednesday, 16 = Thursday, 32 = Friday, 64 = Saturday
			-- 16 : On the specified day of the month
			-- 32 : 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday, 7 = Saturday, 8 = Day, 9 = Weekday, 10 = Weekend day
			-- 64 : Unused
			-- 128: Unused
		-- Frequency Subday Type, units for freq_subday_interval: 1 = At the specified time, 2 = Seconds, 4 = Minutes, 8 = Hours
		-- Frequency Subday Interval, number of freq_subday_type periods to occur between each execution
		-- Frequency Relative Interval, only used for freq_interval of 32: 1 = First, 2 = Second, 4 = Third, 8 = Fourth, 16 = Last
		-- Frequency Recurrence Factor, only used for freq_type of 8, 16, or 32: Number of weeks or months between each execution
		-- Start Time on the 24 hr clock
		-- End Time on the 24 hr clock
		SELECT @SchFreqType01 = 4,      @SchFreqType02 = 8,      @SchFreqType03 = 8,      @SchFreqType04 = 4,     @SchFreqType05 = 8,      @SchFreqType06 = 4,      @SchFreqType07 = 8,      @SchFreqType08 = 8,      @SchFreqType09 = 4 
		SELECT @SchFreqInt01  = 1,      @SchFreqInt02  = 1,      @SchFreqInt03  = 126,    @SchFreqInt04  = 1,     @SchFreqInt05  = 1,      @SchFreqInt06  = 1,      @SchFreqInt07  = 64,     @SchFreqInt08  = 1,      @SchFreqInt09  = 1  
		SELECT @SchSubType01  = 1,      @SchSubType02  = 1,      @SchSubType03  = 1,      @SchSubType04  = 8,     @SchSubType05  = 1,      @SchSubType06  = 1,      @SchSubType07  = 1,      @SchSubType08  = 1,      @SchSubType09  = 8 
		SELECT @SchSubInt01   = 0,      @SchSubInt02   = 0,      @SchSubInt03   = 0,      @SchSubInt04   = 1,     @SchSubInt05   = 0,      @SchSubInt06   = 0,      @SchSubInt07   = 0,      @SchSubInt08   = 0,      @SchSubInt09   = 1  
		SELECT @SchRelInt01   = 0,      @SchRelInt02   = 0,      @SchRelInt03   = 0,      @SchRelInt04   = 0,     @SchRelInt05   = 0,      @SchRelInt06   = 0,      @SchRelInt07   = 0,      @SchRelInt08   = 0,      @SchRelInt09   = 0  
		SELECT @SchFreqRec01  = 1,      @SchFreqRec02  = 1,      @SchFreqRec03  = 1,      @SchFreqRec04  = 1,     @SchFreqRec05  = 1,      @SchFreqRec06  = 1,      @SchFreqRec07  = 1,      @SchFreqRec08  = 1,      @SchFreqRec09  = 1 
		SELECT @SchStart01    = 203000, @SchStart02    = 13000,  @SchStart03    = 13000,  @SchStart04    = 23000, @SchStart05    = 3000,   @SchStart06    = 200000, @SchStart07    = 233000, @SchStart08    = 234500, @SchStart09    = 213000
		SELECT @SchEnd01      = 235959, @SchEnd02      = 235959, @SchEnd03      = 235959, @SchEnd04      = 2959,  @SchEnd05      = 235959, @SchEnd06      = 235959, @SchEnd07      = 235959, @SchEnd08      = 235959, @SchEnd09      = 192959
		SELECT @SchEnable01   = 1,      @SchEnable02   = 1,      @SchEnable03   = 1,      @SchEnable04   = 1,     @SchEnable05   = 1,      @SchEnable06   = 1,      @SchEnable07   = 1,      @SchEnable08   = 1,      @SchEnable09   = 1   
		
		SET @CreateSch = 1
	END
	
	ELSE IF @ServerType = 'P'
	BEGIN
		-- Schedule Names
		SET @SchName01 = 'Production System Full Backups - Daily 9:30PM'
		SET @SchName02 = 'Production User Full Backups - Daily 12AM'
		SET @SchName03 = 'Production User Diff Backups - MTWThFSa 12AM'
		SET @SchName04 = 'Production User TLog Backups - Hourly 1AM-10PM'
		SET @SchName05 = 'Production User CheckDB - MWF 10PM'
		SET @SchName06 = 'Production System CheckDB - Daily 9PM'
		SET @SchName07 = 'Production Index Maintenance - TThSa 10PM'
		SET @SchName08 = 'Production Cleanup - Sunday 11:45PM'
		SET @SchName09 = 'Production System TLog Backups - Hourly 10:30PM-8:30PM'

		-- Frequency Type: 1 = Once, 4 = Daily, 8 = Weekly, 16 = Monthly, 32 = Monthly relativity to freq_interval, 64 = When the agent starts, 128 = When idle
		-- Frequency Interval, depends on freq_type: 
			-- 1  : Unused
			-- 4  : Every specified number of days
			-- 8  : Logical OR, 1 = Sunday, 2 = Monday, 4 = Tuesday, 8 = Wednesday, 16 = Thursday, 32 = Friday, 64 = Saturday
			-- 16 : On the specified day of the month
			-- 32 : 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday, 5 = Thursday, 6 = Friday, 7 = Saturday, 8 = Day, 9 = Weekday, 10 = Weekend day
			-- 64 : Unused
			-- 128: Unused
		-- Frequency Subday Type, units for freq_subday_interval: 1 = At the specified time, 2 = Seconds, 4 = Minutes, 8 = Hours
		-- Frequency Subday Interval, number of freq_subday_type periods to occur between each execution
		-- Frequency Relative Interval, only used for freq_interval of 32: 1 = First, 2 = Second, 4 = Third, 8 = Fourth, 16 = Last
		-- Frequency Recurrence Factor, only used for freq_type of 8, 16, or 32: Number of weeks or months between each execution
		-- Start Time on the 24 hr clock
		-- End Time on the 24 hr clock
		SELECT @SchFreqType01 = 4,      @SchFreqType02 = 4,      @SchFreqType03 = 8,      @SchFreqType04 = 4,      @SchFreqType05 = 8,      @SchFreqType06 = 4,      @SchFreqType07 = 8,      @SchFreqType08 = 8,      @SchFreqType09 = 4 
		SELECT @SchFreqInt01  = 1,      @SchFreqInt02  = 1,      @SchFreqInt03  = 126,    @SchFreqInt04  = 1,      @SchFreqInt05  = 42,     @SchFreqInt06  = 1,      @SchFreqInt07  = 84,     @SchFreqInt08  = 1,      @SchFreqInt09  = 1  
		SELECT @SchSubType01  = 1,      @SchSubType02  = 1,      @SchSubType03  = 1,      @SchSubType04  = 8,      @SchSubType05  = 1,      @SchSubType06  = 1,      @SchSubType07  = 1,      @SchSubType08  = 1,      @SchSubType09  = 8 
		SELECT @SchSubInt01   = 0,      @SchSubInt02   = 0,      @SchSubInt03   = 0,      @SchSubInt04   = 1,      @SchSubInt05   = 0,      @SchSubInt06   = 0,      @SchSubInt07   = 0,      @SchSubInt08   = 0,      @SchSubInt09   = 1  
		SELECT @SchRelInt01   = 0,      @SchRelInt02   = 0,      @SchRelInt03   = 0,      @SchRelInt04   = 0,      @SchRelInt05   = 0,      @SchRelInt06   = 0,      @SchRelInt07   = 0,      @SchRelInt08   = 0,      @SchRelInt09   = 0  
		SELECT @SchFreqRec01  = 1,      @SchFreqRec02  = 1,      @SchFreqRec03  = 1,      @SchFreqRec04  = 1,      @SchFreqRec05  = 1,      @SchFreqRec06  = 1,      @SchFreqRec07  = 1,      @SchFreqRec08  = 1,      @SchFreqRec09  = 1 
		SELECT @SchStart01    = 213000, @SchStart02    = 0,      @SchStart03    = 0,      @SchStart04    = 10000,  @SchStart05    = 220000, @SchStart06    = 210000, @SchStart07    = 220000, @SchStart08    = 234500, @SchStart09    = 223000
		SELECT @SchEnd01      = 235959, @SchEnd02      = 235959, @SchEnd03      = 235959, @SchEnd04      = 215959, @SchEnd05      = 235959, @SchEnd06      = 235959, @SchEnd07      = 235959, @SchEnd08      = 235959, @SchEnd09      = 202959
		SELECT @SchEnable01   = 1,      @SchEnable02   = 1,      @SchEnable03   = 0,      @SchEnable04   = 1,      @SchEnable05   = 1,      @SchEnable06   = 1,      @SchEnable07   = 1,      @SchEnable08   = 1,      @SchEnable09   = 1   
	
		SET @CreateSch = 1
	END

	ELSE
	BEGIN
		SET @CreateSch = 0
	END

	IF @CreateSch = 1
	BEGIN
		-- Create Schedules
		IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName01) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName01, @enabled = @SchEnable01, @freq_type = @SchFreqType01, @freq_interval = @SchFreqInt01, @freq_subday_type = @SchSubType01, @freq_subday_interval = @SchSubInt01, @freq_relative_interval = @SchRelInt01, @freq_recurrence_factor = @SchFreqRec01, @active_start_time = @SchStart01, @active_end_time = @SchEnd01, @owner_login_name = @SchOwner;
		IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName02) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName02, @enabled = @SchEnable02, @freq_type = @SchFreqType02, @freq_interval = @SchFreqInt02, @freq_subday_type = @SchSubType02, @freq_subday_interval = @SchSubInt02, @freq_relative_interval = @SchRelInt02, @freq_recurrence_factor = @SchFreqRec02, @active_start_time = @SchStart02, @active_end_time = @SchEnd02, @owner_login_name = @SchOwner;
		IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName03) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName03, @enabled = @SchEnable03, @freq_type = @SchFreqType03, @freq_interval = @SchFreqInt03, @freq_subday_type = @SchSubType03, @freq_subday_interval = @SchSubInt03, @freq_relative_interval = @SchRelInt03, @freq_recurrence_factor = @SchFreqRec03, @active_start_time = @SchStart03, @active_end_time = @SchEnd03, @owner_login_name = @SchOwner;
		IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName04) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName04, @enabled = @SchEnable04, @freq_type = @SchFreqType04, @freq_interval = @SchFreqInt04, @freq_subday_type = @SchSubType04, @freq_subday_interval = @SchSubInt04, @freq_relative_interval = @SchRelInt04, @freq_recurrence_factor = @SchFreqRec04, @active_start_time = @SchStart04, @active_end_time = @SchEnd04, @owner_login_name = @SchOwner;
		IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName05) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName05, @enabled = @SchEnable05, @freq_type = @SchFreqType05, @freq_interval = @SchFreqInt05, @freq_subday_type = @SchSubType05, @freq_subday_interval = @SchSubInt05, @freq_relative_interval = @SchRelInt05, @freq_recurrence_factor = @SchFreqRec05, @active_start_time = @SchStart05, @active_end_time = @SchEnd05, @owner_login_name = @SchOwner;
		IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName06) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName06, @enabled = @SchEnable06, @freq_type = @SchFreqType06, @freq_interval = @SchFreqInt06, @freq_subday_type = @SchSubType06, @freq_subday_interval = @SchSubInt06, @freq_relative_interval = @SchRelInt06, @freq_recurrence_factor = @SchFreqRec06, @active_start_time = @SchStart06, @active_end_time = @SchEnd06, @owner_login_name = @SchOwner;
		IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName07) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName07, @enabled = @SchEnable07, @freq_type = @SchFreqType07, @freq_interval = @SchFreqInt07, @freq_subday_type = @SchSubType07, @freq_subday_interval = @SchSubInt07, @freq_relative_interval = @SchRelInt07, @freq_recurrence_factor = @SchFreqRec07, @active_start_time = @SchStart07, @active_end_time = @SchEnd07, @owner_login_name = @SchOwner;
		IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName08) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName08, @enabled = @SchEnable08, @freq_type = @SchFreqType08, @freq_interval = @SchFreqInt08, @freq_subday_type = @SchSubType08, @freq_subday_interval = @SchSubInt08, @freq_relative_interval = @SchRelInt08, @freq_recurrence_factor = @SchFreqRec08, @active_start_time = @SchStart08, @active_end_time = @SchEnd08, @owner_login_name = @SchOwner;
		IF NOT EXISTS (SELECT * FROM msdb.dbo.sysschedules WHERE [name] = @SchName09) EXEC msdb.dbo.sp_add_schedule @schedule_name = @SchName09, @enabled = @SchEnable09, @freq_type = @SchFreqType09, @freq_interval = @SchFreqInt09, @freq_subday_type = @SchSubType09, @freq_subday_interval = @SchSubInt09, @freq_relative_interval = @SchRelInt09, @freq_recurrence_factor = @SchFreqRec09, @active_start_time = @SchStart09, @active_end_time = @SchEnd09, @owner_login_name = @SchOwner;
		-- Assign Schedules to Jobs
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName01) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName01, @schedule_name = @SchName01;
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName02) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName02, @schedule_name = @SchName02;
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName03) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName03, @schedule_name = @SchName03;
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName04) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName04, @schedule_name = @SchName04;
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName05) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName05, @schedule_name = @SchName05;
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName06) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName06, @schedule_name = @SchName06;
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName07) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName07, @schedule_name = @SchName07;
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName08) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName08, @schedule_name = @SchName08;
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName09) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName09, @schedule_name = @SchName08;
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName10) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName10, @schedule_name = @SchName08;
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName11) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName11, @schedule_name = @SchName08;
		IF EXISTS     (SELECT * FROM msdb.dbo.sysjobs      WHERE [name] = @JobName12) EXEC msdb.dbo.sp_attach_schedule @job_name = @JobName12, @schedule_name = @SchName09;
	END
END
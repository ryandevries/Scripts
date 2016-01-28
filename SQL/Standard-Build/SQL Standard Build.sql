-- SQL Standard Build
SET NOCOUNT ON;
USE [master];
DECLARE @MaxDOP INT, @CTFP INT, @MaxMemory INT, @FullRecovery BIT, @profile_name sysname, @account_name sysname, @SMTP_servername sysname, @email_address NVARCHAR(128), @display_name NVARCHAR(128), @operator_name NVARCHAR(128), @operator_email NVARCHAR(128), @TempDBSizeMB INT;

--  ##################################################################################################################################
	-- Server settings
	SET @MaxDOP				= NULL; -- Override calculated MaxDOP
	SET @CTFP				= NULL; -- Override default CTFP of 50
	SET @MaxMemory			= NULL; -- Override calculated MaxMemory
	SET @FullRecovery       = 1;    -- 0 for SIMPLE recovery on model
	SET @TempDBSizeMB       = 8192; -- Aggregate size of TempDB data files in MB
	-- Database Mail settings
	SET @profile_name		= 'DatabaseAlerts';
	SET @account_name		= 'DatabaseAlerts';
	SET @SMTP_servername	= 'email.domain.com';
	SET @email_address		= 'sqlalerts@domain.com';
	SET @display_name		= CONCAT(@@SERVERNAME, ' ', 'SQL Alerts');
	-- SQL Agent settings
	SET @operator_name      = 'SQL Alerts'
	SET @operator_email		= 'sqlalerts@domain.com';
--  ##################################################################################################################################

-- Calculate MaxDOP
IF @MaxDOP IS NULL
BEGIN
	PRINT 'Maximum Degree of Parallelism not defined, calculating...'
	DECLARE @hyperthreadingRatio BIT, @logicalCPUs INT, @HTEnabled INT, @physicalCPU INT, @SOCKET INT, @logicalCPUPerNuma INT, @NoOfNUMA INT
	SELECT @logicalCPUs       = cpu_count, @hyperthreadingRatio = hyperthread_ratio, @physicalCPU = cpu_count / hyperthread_ratio, @HTEnabled = CASE WHEN cpu_count > hyperthread_ratio THEN 1 ELSE 0 END FROM sys.dm_os_sys_info
	SELECT @logicalCPUPerNuma = COUNT(parent_node_id) FROM sys.dm_os_schedulers WHERE [status] = 'VISIBLE ONLINE' AND parent_node_id < 64 GROUP BY parent_node_id
	SELECT @NoOfNUMA          = COUNT(DISTINCT parent_node_id) FROM sys.dm_os_schedulers WHERE [status] = 'VISIBLE ONLINE' AND parent_node_id < 64
	SELECT @MaxDOP	          = CASE 
		WHEN @logicalCPUs  < 8 AND @HTEnabled = 0 THEN @logicalCPUs
		WHEN @logicalCPUs  < 8 AND @HTEnabled = 1 THEN @logicalCPUs
		WHEN @logicalCPUs >= 8 AND @HTEnabled = 0 THEN 8
		WHEN @logicalCPUs >= 8 AND @HTEnabled = 1 AND @NoofNUMA = 1 THEN @logicalCPUPerNuma / @physicalCPU
		WHEN @logicalCPUs >= 8 AND @HTEnabled = 1 AND @NoofNUMA > 1 THEN @logicalCPUPerNuma / @physicalCPU
		ELSE 0 END
	PRINT 'Maximum Degree of Parallelism calculated to: ' + CONVERT(VARCHAR, @MaxDOP)
END

-- Set CTFP to default value
IF @CTFP IS NULL 
BEGIN
	PRINT 'Cost Threshold for Parallelism not defined, setting to: 50'
	SET @CTFP = 50
END

-- Calculate Max Memory
IF @MaxMemory IS NULL
BEGIN
	PRINT 'Maximum memory not defined, calculating...'
	DECLARE @TotalMemory INT, @OSMemory INT, @Processed INT, @Overage INT, @Gap INT, @GapOSMemory INT
	SELECT @TotalMemory = CEILING([total_physical_memory_kb] / 1024.0) FROM [master].[sys].[dm_os_sys_memory]
    SET @OSMemory = 1024
    IF @TotalMemory >= 4096
	BEGIN
        SET @Processed = 4096
        WHILE @Processed <= @TotalMemory
		BEGIN
            IF @Processed <= 16384
			BEGIN
                SET @OSMemory  += 1024
                SET @Processed += 4096
                IF @Processed > @TotalMemory
				BEGIN
                    SET @Overage = @Processed - @TotalMemory
                    SET @Gap     = 4096 - @Overage
                    IF @Gap > 0
					BEGIN
                        SET @GapOSMemory = CEILING(@Gap * .25)
						SELECT @GapOSMemory
                        SET @OSMemory   += @GapOSMemory
                    END
                END
            END 
            ELSE
			BEGIN
                SET @OSMemory  += 1024
                SET @Processed += 8192
                IF @Processed > @TotalMemory
				BEGIN
                    SET @Overage = @Processed - @TotalMemory
                    SET @Gap     = 8192 - @Overage
                    IF @Gap > 0
					BEGIN
                        SET @GapOSMemory = CEILING(@Gap * .125)
                        SET @OSMemory   += @GapOSMemory
					END
                END
            END
        END
        SET @MaxMemory = @TotalMemory - @OSMemory
    END
    ELSE
	BEGIN
        SET @MaxMemory = @TotalMemory - @OSMemory
        IF @MaxMemory < 0 SET @MaxMemory = 0
    END
	PRINT 'Maximum memory calculated to: ' + CONVERT(VARCHAR, @MaxMemory) + 'MB'
END

-- Configurations
PRINT 'Turning on advanced configuration options...'
EXEC dbo.sp_configure 'show advanced options', 1;
RECONFIGURE;
PRINT 'RECONFIGURE ran'
PRINT 'Setting Max Degree of Parallelism to ' + CONVERT(VARCHAR, @MaxDOP) + '...'
EXEC dbo.sp_configure 'max degree of parallelism', @MaxDOP;
RECONFIGURE;
PRINT 'RECONFIGURE ran'
PRINT 'Setting Cost Threshold for Parallelism to ' + CONVERT(VARCHAR, @CTFP) + '...'
EXEC dbo.sp_configure 'cost threshold for parallelism', @CTFP;
RECONFIGURE;
PRINT 'RECONFIGURE ran'
PRINT 'Setting maximum memory to ' + CONVERT(VARCHAR, @MaxMemory) + '...'
EXEC dbo.sp_configure 'max server memory (MB)', @MaxMemory;
RECONFIGURE;
PRINT 'RECONFIGURE ran'
PRINT 'Turning on backup compression default...'
EXEC dbo.sp_configure 'backup compression default', 1;
RECONFIGURE;
PRINT 'RECONFIGURE ran'
PRINT 'Turning on Remote Admin Connections...'
EXEC dbo.sp_configure 'remote admin connections', 1;
RECONFIGURE;
PRINT 'RECONFIGURE ran'
PRINT 'Turning on Database Mail...'
EXEC dbo.sp_configure 'Database Mail XPs',1;
RECONFIGURE;
PRINT 'RECONFIGURE ran'
PRINT 'Turning off advanced configuration options...'
EXEC dbo.sp_configure 'show advanced options', 0;
RECONFIGURE;
PRINT 'RECONFIGURE ran'

-- Rename/Disable SA
PRINT 'Renaming sa to MNA and disabling account...'
ALTER LOGIN SA WITH NAME = MNA;
ALTER LOGIN MNA DISABLE;

-- Turn on auditing for failed and successful logins
PRINT 'Enabling auditing for failed and successful logins...'
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'AuditLevel', REG_DWORD, 3;

-- DB Mail
PRINT 'Creating Database Mail profile ' + CONVERT(VARCHAR, @profile_name) + '...'
	-- Verify the specified account and profile do not already exist.
IF EXISTS (SELECT * FROM msdb.dbo.sysmail_profile WHERE name = @profile_name)
BEGIN
	PRINT 'Database Mail profile ' + CONVERT(VARCHAR, @profile_name) + ' already exists'
	RAISERROR('The specified Database Mail profile already exists.', 16, 1);
	GOTO done;
END;
IF EXISTS (SELECT * FROM msdb.dbo.sysmail_account WHERE name = @account_name )
BEGIN
	PRINT 'Database Mail account ' + CONVERT(VARCHAR, @account_name) + ' already exists'
	RAISERROR('The specified Database Mail account already exists.', 16, 1) ;
	GOTO done;
END;
	-- Start a transaction before adding the account and the profile
BEGIN TRANSACTION;
DECLARE @rv INT;
	-- Add the account
PRINT 'Creating Database Mail account ' + CONVERT(VARCHAR, @account_name) + ' with email: ' + CONVERT(VARCHAR, @email_address) + ', display name: ' + CONVERT(VARCHAR, @display_name) + ', and mail server: ' + CONVERT(VARCHAR(128), @SMTP_servername) + '...'
EXECUTE @rv=msdb.dbo.sysmail_add_account_sp	@account_name = @account_name,	@email_address = @email_address, @display_name = @display_name,	@mailserver_name = @SMTP_servername;
IF @rv<>0
BEGIN
	PRINT 'Failed to create Database Mail account ' + CONVERT(VARCHAR, @account_name)
	RAISERROR('Failed to create the specified Database Mail account.', 16, 1) ;
	GOTO done;
END
	-- Add the profile
PRINT 'Creating Database Mail profile ' + CONVERT(VARCHAR, @profile_name)
EXECUTE @rv=msdb.dbo.sysmail_add_profile_sp	@profile_name = @profile_name;
IF @rv<>0
BEGIN
	PRINT 'Failed to create Database Mail profile ' + CONVERT(VARCHAR, @profile_name)
	RAISERROR('Failed to create the specified Database Mail profile.', 16, 1);
	ROLLBACK TRANSACTION;
	GOTO done;
END;
	-- Associate the account with the profile.
PRINT 'Associating the Database Mail account ' + CONVERT(VARCHAR, @account_name) + ' with the profile ' + CONVERT(VARCHAR, @profile_name) + '...'
EXECUTE @rv=msdb.dbo.sysmail_add_profileaccount_sp	@profile_name = @profile_name, @account_name = @account_name, @sequence_number = 1;
IF @rv<>0
BEGIN
	PRINT 'Failed to associate the Database Mail account ' + CONVERT(VARCHAR, @account_name) + ' with the profile ' + CONVERT(VARCHAR, @profile_name)
	RAISERROR('Failed to associate the speficied profile with the specified account.', 16, 1) ;
	ROLLBACK TRANSACTION;
	GOTO done;
END;
COMMIT TRANSACTION;
done:

-- SQL Agent DB Mail
PRINT 'Enabling Database Mail profile ' + CONVERT(VARCHAR, @profile_name) + ' for SQL Agent...'
EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder=1, @databasemail_profile=@profile_name, @use_databasemail=1

-- Operator
PRINT 'Creating Operator ' + CONVERT(VARCHAR, @operator_name) + ' for SQL Agent...'
EXEC msdb.dbo.sp_add_operator @name=@operator_name, @enabled=1, @pager_days=0, @email_address=@operator_email

-- Set operators as fail-safe
PRINT 'Setting Operator ' + CONVERT(VARCHAR, @operator_name) + ' as failsafe operator for SQL Agent...'
EXEC master.dbo.sp_MSsetalertinfo @failsafeoperator=@operator_name, @notificationmethod=1

-- Set up alerts
PRINT 'Creating Alerts for Severity 16-25, and Errors 823, 824, and 825...'
EXEC msdb.dbo.sp_add_alert @name=N'Severity 016',@message_id=0,@severity=16,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000';
EXEC msdb.dbo.sp_add_alert @name=N'Severity 017',@message_id=0,@severity=17,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000';
EXEC msdb.dbo.sp_add_alert @name=N'Severity 018',@message_id=0,@severity=18,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000';
EXEC msdb.dbo.sp_add_alert @name=N'Severity 019',@message_id=0,@severity=19,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000';
EXEC msdb.dbo.sp_add_alert @name=N'Severity 020',@message_id=0,@severity=20,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000';
EXEC msdb.dbo.sp_add_alert @name=N'Severity 021',@message_id=0,@severity=21,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000';
EXEC msdb.dbo.sp_add_alert @name=N'Severity 022',@message_id=0,@severity=22,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000';
EXEC msdb.dbo.sp_add_alert @name=N'Severity 023',@message_id=0,@severity=23,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000';
EXEC msdb.dbo.sp_add_alert @name=N'Severity 024',@message_id=0,@severity=24,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000';
EXEC msdb.dbo.sp_add_alert @name=N'Severity 025',@message_id=0,@severity=25,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000';
EXEC msdb.dbo.sp_add_alert @name=N'Error Number 823',@message_id=823,@severity=0,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000'
EXEC msdb.dbo.sp_add_alert @name=N'Error Number 824',@message_id=824,@severity=0,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000'
EXEC msdb.dbo.sp_add_alert @name=N'Error Number 825',@message_id=825,@severity=0,@enabled=1,@delay_between_responses=60,@include_event_description_in=1,@job_id=N'00000000-0000-0000-0000-000000000000'

-- Set up notifications for alerts
PRINT 'Setting Alert notifications to go to Operator ' + CONVERT(VARCHAR, @operator_name) + '...'
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 016', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 017', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 018', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 019', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 020', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 021', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 022', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 023', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 024', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 025', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Error Number 823', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Error Number 824', @operator_name=@operator_name, @notification_method = 1;
EXEC msdb.dbo.sp_add_notification @alert_name=N'Error Number 825', @operator_name=@operator_name, @notification_method = 1;

-- Test alerts
PRINT 'Generating a test email alert of Severity 18...'
RAISERROR('Testing email alerts',18,1) WITH LOG;

-- Configure model
PRINT 'Configuring the model database...'
IF @FullRecovery = 1 
BEGIN
	PRINT 'Setting Recovery Model to FULL'
	ALTER DATABASE model SET RECOVERY FULL;
END
ELSE 
BEGIN
	PRINT 'Setting Recovery Model to SIMPLE'
	ALTER DATABASE model SET RECOVERY SIMPLE;
END
PRINT 'Setting up file autogrowth on model (256MB for data file, 128MB for log file)'
ALTER DATABASE model MODIFY FILE (NAME='modeldev', FILEGROWTH = 256MB);
ALTER DATABASE model MODIFY FILE (NAME='modellog', FILEGROWTH = 128MB);

-- Configure tempDB
IF (SELECT COUNT(1) FROM tempdb.sys.database_files) = 2
BEGIN
	DECLARE @NoOfTempDB INT, @TempDBDataPath NVARCHAR(128), @TempDBDataName NVARCHAR(128), @TempDBDataRoot NVARCHAR(128), @TempDBLogPath NVARCHAR(128), @TempDBLogName NVARCHAR(128), @FileNumber INT, @SQL NVARCHAR(MAX);
	SET @FileNumber    = 1;
	SELECT @NoOfTempDB = CASE WHEN cpu_count > 8 THEN 8 ELSE cpu_count END FROM sys.dm_os_sys_info;

	SELECT @TempDBDataPath = physical_name, @TempDBDataName = name FROM tempdb.sys.database_files WHERE file_id = 1;
	SELECT @TempDBLogPath  = physical_name, @TempDBLogName  = name FROM tempdb.sys.database_files WHERE file_id = 2;
	SELECT @TempDBDataRoot = LEFT(@TempDBDataPath, LEN(@TempDBDataPath) - CHARINDEX('\', REVERSE(@TempDBDataPath)) + 1);

	IF OBJECT_ID('tempdb..#TempDBCommands') IS NOT NULL
		DROP TABLE #TempDBCommands;
	CREATE TABLE #TempDBCommands ([Statement] NVARCHAR(MAX));

	INSERT INTO #TempDBCommands VALUES ('ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N''' + @TempDBDataName + ''', SIZE = ' + CONVERT(NVARCHAR, (@TempDBSizeMB / @NoOfTempDB ))+ 'MB, FILEGROWTH = 256MB )');
	INSERT INTO #TempDBCommands VALUES ('ALTER DATABASE [tempdb] MODIFY FILE ( NAME = N''' + @TempDBLogName  + ''', SIZE = ' + CONVERT(NVARCHAR, (@TempDBSizeMB / 4 )) + 'MB, FILEGROWTH = 128MB )');

	WHILE @FileNumber < @NoOfTempDB
	BEGIN
		SET @FileNumber += 1;
		INSERT INTO #TempDBCommands VALUES ('ALTER DATABASE [tempdb] ADD FILE ( NAME = N''' + @TempDBDataName + CONVERT(NVARCHAR, @FileNumber) + ''', FILENAME = N''' + CONVERT(NVARCHAR(128), @TempDBDataRoot) + 'tempdb' + CONVERT(NVARCHAR, @FileNumber) + '.mdf'', SIZE = ' + CONVERT(NVARCHAR, (@TempDBSizeMB / @NoOfTempDB ))+ 'MB, FILEGROWTH = 256MB )');
	END

	DECLARE TempDBCursor CURSOR FOR SELECT [Statement] FROM #TempDBCommands
	OPEN TempDBCursor
	FETCH NEXT FROM TempDBCursor INTO @SQL
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--PRINT @SQL
		EXEC sp_executesql @SQL;
		FETCH NEXT FROM TempDBCursor INTO @SQL
	END 
	CLOSE TempDBCursor;
	DEALLOCATE TempDBCursor;
	DROP TABLE #TempDBCommands;
END

-- Build database for stored procs/maintenance
IF DB_ID('DBAUtility') IS NULL
BEGIN
	PRINT 'Creating database DBAUtility...'
	CREATE DATABASE [DBAUtility]
	DECLARE @DBOwner nvarchar(max)
	SET     @DBOwner = SUSER_SNAME(0x01)
	EXEC DBAUtility.dbo.sp_changedbowner @loginame = @DBOwner
	ALTER DATABASE [DBAUtility] MODIFY FILE ( NAME = N'DBAUtility', FILEGROWTH = 256MB )
	ALTER DATABASE [DBAUtility] MODIFY FILE ( NAME = N'DBAUtility_log', FILEGROWTH = 128MB )
	PRINT 'Created database DBAUtility'
END
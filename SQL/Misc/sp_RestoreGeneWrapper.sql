USE [DBAUtility]; 
GO 
IF NOT EXISTS ( SELECT  *
                FROM    [INFORMATION_SCHEMA].[ROUTINES]
                WHERE   [ROUTINE_NAME] = 'sp_RestoreGeneWrapper' )
    EXEC ('CREATE PROC dbo.sp_RestoreGeneWrapper AS SELECT ''stub version, to be replaced'''); 
GO
-- =============================================
-- Author:		Ryan DeVries
-- Create date: 2016-09-07
-- Description:	This is a wrapper function for Paul Brewer's sp_RestoreGene (https://paulbrewer.wordpress.com/sp_restoregene/)
--				It is designed to be executed using SQLCMD as an agent job step after backups are performed, and output a restoration script to the Output file specified in the agent job step.
--              Example: sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d DBAUtility -Q "EXECUTE [dbo].[sp_RestoreGeneWrapper] @WithRecovery = 1, @WithReplace = 1" -b
--                       Output File: \\backups\Restore Scripts\RestoreScript_$(ESCAPE_SQUOTE(SRVR))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).sql
--              It also logs the restore information to a table in the DBAUtility database for reference, keeping one week's worth of restore scripts.
--				It supports most of the same parameters as sp_RestoreGene, minus the ones that don't make sense for this application.
--             
--              Enhancements to sp_RestoreGene:
--					- Table logging
--					- Script comment with custom warning message
--					- Listing of restore point datetime for each database
-- ChangeLog:
-- 2016-09-07 - v1.0 - Release
-- =============================================
ALTER PROCEDURE [dbo].[sp_RestoreGeneWrapper]
    (
      @Database sysname = NULL ,
      @TargetDatabase sysname = NULL ,
      @WithMoveDataFiles VARCHAR(2000) = NULL ,
      @WithMoveLogFile VARCHAR(2000) = NULL ,
      @WithMoveFileStreamFile VARCHAR(2000) = NULL ,
      @FromFileFullUNC VARCHAR(2000) = NULL ,
      @FromFileDiffUNC VARCHAR(2000) = NULL ,
      @FromFileLogUNC VARCHAR(2000) = NULL ,
      @StopAt DATETIME = NULL ,
      @StandbyMode BIT = 0 ,
      @IncludeSystemDBs BIT = 0 ,
      @WithRecovery BIT = 0 ,
      @WithCHECKDB BIT = 0 ,
      @WithReplace BIT = 0 ,
      @Log_Reference VARCHAR(250) = NULL ,
      @BlobCredential VARCHAR(255) = NULL , --Credential used for Azure blob access 
      @RestoreScriptReplaceThis NVARCHAR(255) = NULL ,
      @RestoreScriptWithThis NVARCHAR(255) = NULL ,
      @SuppressWithMove BIT = 1 ,
      @PivotWithMove BIT = 0
    )
AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @GeneDate DATETIME2 ,
            @TSQL NVARCHAR(4000) ,
            @MaxDBNameLength INT ,
            @ScriptComment NVARCHAR(MAX);
    
        SET @GeneDate = SYSDATETIME();
        SET @ScriptComment = 'This script is automatically generated after each backup.  It will restore each selected database to the most recent restore point. 
	- It is only intended for use in catastrophic server failure.  
	- If msdb is still available, use that to generate the restore script using [DBAUtility].[dbo].[sp_RestoreGene] instead, and take a backup of the log tail(s) first to avoid data loss.
	- Make sure no connections are made to the databases before executing.  You may need to put the databases in Single_user mode first, or kill existing connections.
	- Master is excluded, as it required special recovery procedures.
	- If you wish to restore msdb as well, stop the SQL Agent first.
	- Do not blindly run this, it will overwrite all of your databases!  Make sure you know what you are doing!';
	
        IF OBJECT_ID('[dbo].[RestoreGene]') IS NULL
            CREATE TABLE [dbo].[RestoreGene]
                (
                  [ID] [BIGINT] IDENTITY(1, 1)
                                NOT NULL ,
                  [GeneDate] [DATETIME2](7) NOT NULL ,
                  [Latest] [BIT] NOT NULL ,
                  [TSQL] [NVARCHAR](4000) NOT NULL ,
                  [BackupDate] [DATETIME2](7) NULL ,
                  [BackupDevice] [NVARCHAR](260) NULL ,
                  [last_lsn] [DECIMAL](25, 0) NULL ,
                  [database_name] [NVARCHAR](128) NULL ,
                  [SortSequence] [BIGINT] NOT NULL ,
                  CONSTRAINT [PK_RestoreGene] PRIMARY KEY CLUSTERED
                    ( [ID] ASC )
                );
	
        IF OBJECT_ID('tempdb..#RestoreGene') IS NOT NULL
            DROP TABLE [#RestoreGene];
	
        CREATE TABLE [#RestoreGene]
            (
              [TSQL] NVARCHAR(MAX) ,
              [BackupDate] DATETIME ,
              [BackupDevice] NVARCHAR(260) ,
              [last_lsn] DECIMAL(25, 0) ,
              [database_name] NVARCHAR(128) ,
              [SortSequence] BIGINT
            );
	
        INSERT  INTO [#RestoreGene]
                EXEC [dbo].[sp_RestoreGene] @Database = @Database,
                    @TargetDatabase = @TargetDatabase,
                    @WithMoveDataFiles = @WithMoveDataFiles,
                    @WithMoveLogFile = @WithMoveLogFile,
                    @WithMoveFileStreamFile = @WithMoveFileStreamFile,
                    @FromFileFullUNC = @FromFileFullUNC,
                    @FromFileDiffUNC = @FromFileDiffUNC,
                    @FromFileLogUNC = @FromFileLogUNC, @StopAt = @StopAt,
                    @StandbyMode = @StandbyMode,
                    @IncludeSystemDBs = @IncludeSystemDBs,
                    @WithRecovery = @WithRecovery, @WithCHECKDB = @WithCHECKDB,
                    @WithReplace = @WithReplace,
                    @Log_Reference = @Log_Reference,
                    @BlobCredential = @BlobCredential,
                    @RestoreScriptReplaceThis = @RestoreScriptReplaceThis,
                    @RestoreScriptWithThis = @RestoreScriptWithThis,
                    @SuppressWithMove = @SuppressWithMove,
                    @PivotWithMove = @PivotWithMove;

        SELECT  @MaxDBNameLength = MAX(LEN([database_name]))
        FROM    [#RestoreGene]
        WHERE   [BackupDevice] <> '';

        UPDATE  [dbo].[RestoreGene]
        SET     [Latest] = 0
        WHERE   [Latest] = 1;

        INSERT  INTO [dbo].[RestoreGene]
                ( [GeneDate] ,
                  [Latest] ,
                  [TSQL] ,
                  [BackupDate] ,
                  [BackupDevice] ,
                  [last_lsn] ,
                  [database_name] ,
                  [SortSequence]
                )
        VALUES  ( @GeneDate ,
                  1 ,
                  '/*' + CHAR(10) + @ScriptComment + CHAR(10)
                  + 'Latest restore points: ' ,
                  @GeneDate ,
                  '' ,
                  0 ,
                  'master' ,
                  0
                );
		
        INSERT  INTO [dbo].[RestoreGene]
                ( [GeneDate] ,
                  [Latest] ,
                  [TSQL] ,
                  [BackupDate] ,
                  [BackupDevice] ,
                  [last_lsn] ,
                  [database_name] ,
                  [SortSequence]
                )
        VALUES  ( @GeneDate ,
                  1 ,
                  CHAR(9) + 'Database' + REPLICATE(' ', @MaxDBNameLength - 6)
                  + 'Restore Point' + REPLICATE(' ', 8) + 'Recovery Model' ,
                  @GeneDate ,
                  '' ,
                  0 ,
                  'master' ,
                  0
                );

        INSERT  INTO [dbo].[RestoreGene]
                ( [GeneDate] ,
                  [Latest] ,
                  [TSQL] ,
                  [BackupDate] ,
                  [BackupDevice] ,
                  [last_lsn] ,
                  [database_name] ,
                  [SortSequence]
                )
        VALUES  ( @GeneDate ,
                  1 ,
                  CHAR(9) + REPLICATE('-', @MaxDBNameLength + 37) ,
                  @GeneDate ,
                  '' ,
                  0 ,
                  'master' ,
                  0
                );

        INSERT  INTO [dbo].[RestoreGene]
                ( [GeneDate] ,
                  [Latest] ,
                  [TSQL] ,
                  [BackupDate] ,
                  [BackupDevice] ,
                  [last_lsn] ,
                  [database_name] ,
                  [SortSequence]
                )
        SELECT  @GeneDate AS [GeneDate] ,
                1 ,
                CHAR(9) + [rg].[database_name] + REPLICATE(' ',
                                                           @MaxDBNameLength
                                                           - LEN([rg].[database_name])
                                                           + 2)
                + CONVERT(VARCHAR(19), MAX([rg].[BackupDate]), 120) + '  '
                + CASE MAX([db].[recovery_model])
                    WHEN 1 THEN 'FULL'
                    WHEN 2 THEN 'BULK LOGGED'
                    WHEN 3 THEN 'SIMPLE'
                  END ,
                @GeneDate ,
                '' ,
                0 ,
                'master' ,
                0
        FROM    [#RestoreGene] [rg]
        JOIN    [master].[sys].[databases] [db] ON [rg].[database_name] = [db].[name]
        WHERE   [rg].[BackupDevice] <> ''
                AND [rg].[database_name] <> 'master'
        GROUP BY [rg].[database_name];

        INSERT  INTO [dbo].[RestoreGene]
                ( [GeneDate] ,
                  [Latest] ,
                  [TSQL] ,
                  [BackupDate] ,
                  [BackupDevice] ,
                  [last_lsn] ,
                  [database_name] ,
                  [SortSequence]
                )
        VALUES  ( @GeneDate ,
                  1 ,
                  'Restore scripts were not generated for the following database(s):' ,
                  @GeneDate ,
                  '' ,
                  0 ,
                  'master' ,
                  0
                );	

        INSERT  INTO [dbo].[RestoreGene]
                ( [GeneDate] ,
                  [Latest] ,
                  [TSQL] ,
                  [BackupDate] ,
                  [BackupDevice] ,
                  [last_lsn] ,
                  [database_name] ,
                  [SortSequence]
                )
        SELECT  @GeneDate AS [GeneDate] ,
                1 ,
                CHAR(9) + [name] ,
                @GeneDate ,
                '' ,
                0 ,
                'master' ,
                0
        FROM    [master].[sys].[databases]
        WHERE   [name] NOT IN ( SELECT DISTINCT
                                        [database_name]
                                FROM    [#RestoreGene] )
                AND [database_id] <> 2;

        INSERT  INTO [dbo].[RestoreGene]
                ( [GeneDate] ,
                  [Latest] ,
                  [TSQL] ,
                  [BackupDate] ,
                  [BackupDevice] ,
                  [last_lsn] ,
                  [database_name] ,
                  [SortSequence]
                )
        VALUES  ( @GeneDate ,
                  1 ,
                  '*/' + CHAR(10) + ';USE [master]' ,
                  @GeneDate ,
                  '' ,
                  0 ,
                  'master' ,
                  0
                );				

        INSERT  INTO [dbo].[RestoreGene]
                ( [GeneDate] ,
                  [Latest] ,
                  [TSQL] ,
                  [BackupDate] ,
                  [BackupDevice] ,
                  [last_lsn] ,
                  [database_name] ,
                  [SortSequence]
                )
        SELECT  @GeneDate AS [GeneDate] ,
                1 ,
                [TSQL] ,
                [BackupDate] ,
                [BackupDevice] ,
                [last_lsn] ,
                [database_name] ,
                [SortSequence]
        FROM    [#RestoreGene]
        WHERE   [database_name] <> 'master';

        DECLARE [db_cursor] CURSOR
        FOR
            SELECT  [TSQL]
            FROM    [dbo].[RestoreGene]
            WHERE   [Latest] = 1
            ORDER BY [SortSequence] ASC;

        OPEN [db_cursor];   
        FETCH NEXT FROM [db_cursor] INTO @TSQL;   

        WHILE @@FETCH_STATUS = 0
            BEGIN   
                PRINT @TSQL;
                FETCH NEXT FROM [db_cursor] INTO @TSQL;   
            END;

        CLOSE [db_cursor];   
        DEALLOCATE [db_cursor];

        DELETE  FROM [dbo].[RestoreGene]
        WHERE   [GeneDate] < DATEADD(wk, -1, @GeneDate);
        SET NOCOUNT OFF;
    END;
GO
USE [DBAUtility] 
GO 
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'sp_RestoreGeneWrapper') 
EXEC ('CREATE PROC dbo.sp_RestoreGeneWrapper AS SELECT ''stub version, to be replaced''') 
GO
-- =============================================
-- Author:		Ryan DeVries
-- Create date: 2016-09-07
-- Description:	This is a wrapper function for Paul Brewer's sp_RestoreGene (https://paulbrewer.wordpress.com/sp_restoregene/)
--				It is designed to be executed using SQLCMD as an agent job step after backups are performed, and output a restoration script to the Output file specified in the agent job step.
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
ALTER PROCEDURE sp_RestoreGeneWrapper
(
    @Database SYSNAME = NULL,
    @TargetDatabase SYSNAME = NULL,
    @WithMoveDataFiles VARCHAR(2000) = NULL,
    @WithMoveLogFile  VARCHAR(2000) = NULL,
    @WithMoveFileStreamFile VARCHAR(2000) = NULL,
    @FromFileFullUNC VARCHAR(2000) = NULL,
    @FromFileDiffUNC VARCHAR(2000) = NULL,
    @FromFileLogUNC VARCHAR(2000) = NULL,
    @StopAt DATETIME = NULL,
    @StandbyMode BIT = 0,
    @IncludeSystemDBs BIT = 0,
    @WithRecovery BIT = 0,
    @WithCHECKDB BIT = 0,
    @WithReplace BIT = 0,
    @Log_Reference VARCHAR (250) = NULL,
    @BlobCredential VARCHAR(255) = NULL, --Credential used for Azure blob access 
    @RestoreScriptReplaceThis NVARCHAR(255) = NULL,
    @RestoreScriptWithThis NVARCHAR(255) = NULL,
    @SuppressWithMove BIT = 1,
    @PivotWithMove BIT = 0
)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @GeneDate datetime2, @TSQL nvarchar(4000), @RestoreDate datetime2, @MaxDBNameLength INT, @ScriptComment NVARCHAR(MAX)
    
	SET @GeneDate = SYSDATETIME()
	SET @ScriptComment = 'This script is automatically generated after each backup.  It will restore each selected database to the most recent restore point. 
	- It is only intended for use in catastrophic server failure.  
	- If msdb is still available, use that to generate the restore script using [DBAUtility].[dbo].[sp_RestoreGene] instead, and take a backup of the log tail(s) first to avoid data loss.
	- Make sure no connections are made to the databases before executing.  You may need to put the databases in Single_user mode first, or kill existing connections.
	- Do not blindly run this, it will overwrite all of your databases!  Make sure you know what you are doing!'
	
	IF OBJECT_ID('[dbo].[RestoreGene]') IS NULL
		CREATE TABLE [dbo].[RestoreGene] (
			[ID] [BIGINT] IDENTITY(1,1) NOT NULL, 
			[GeneDate] [DATETIME2](7) NOT NULL,
			[Latest] [BIT] NOT NULL, 
			[TSQL] [NVARCHAR](4000) NOT NULL,
			[BackupDate] [DATETIME2](7) NULL,
			[BackupDevice] [NVARCHAR](260) NULL,
			[last_lsn] [DECIMAL](25, 0) NULL,
			[database_name] [NVARCHAR](128) NULL,
			[SortSequence] [BIGINT] NOT NULL,
			CONSTRAINT [PK_RestoreGene] PRIMARY KEY CLUSTERED ([ID] ASC) 
		);
	
	IF OBJECT_ID('tempdb..#RestoreGene') IS NOT NULL
		DROP TABLE #RestoreGene;
	
	CREATE TABLE #RestoreGene ( 
		[TSQL] nvarchar(4000), 
		[BackupDate] datetime, 
		[BackupDevice] nvarchar(260), 
		[last_lsn] decimal(25,0), 
		[database_name] nvarchar(128), 
		[SortSequence] bigint 
	);
	
	INSERT INTO #RestoreGene EXEC dbo.[sp_RestoreGene] @Database  = @Database,
		@TargetDatabase = @TargetDatabase,
		@WithMoveDataFiles = @WithMoveDataFiles,
		@WithMoveLogFile = @WithMoveLogFile,
		@WithMoveFileStreamFile = @WithMoveFileStreamFile,
		@FromFileFullUNC = @FromFileFullUNC,
		@FromFileDiffUNC = @FromFileDiffUNC,
		@FromFileLogUNC = @FromFileLogUNC,
		@StopAt = @StopAt,
		@StandbyMode = @StandbyMode,
		@IncludeSystemDBs = @IncludeSystemDBs,
		@WithRecovery = @WithRecovery,
		@WithCHECKDB = @WithCHECKDB,
		@WithReplace = @WithReplace,
		@Log_Reference = @Log_Reference,
		@BlobCredential = @BlobCredential,
		@RestoreScriptReplaceThis = @RestoreScriptReplaceThis,
		@RestoreScriptWithThis = @RestoreScriptWithThis,
		@SuppressWithMove = @SuppressWithMove,
		@PivotWithMove = @PivotWithMove

	SELECT @RestoreDate = MAX(BackupDate) FROM #RestoreGene WHERE [BackupDevice] <> '';
	SELECT @MaxDBNameLength = MAX(LEN([database_name])) FROM #RestoreGene WHERE [BackupDevice] <> '';

	UPDATE [RestoreGene] SET [Latest] = 0 WHERE [Latest] = 1;
	INSERT INTO [RestoreGene] ( [GeneDate], [Latest], [TSQL], [BackupDate], [BackupDevice], [last_lsn], [database_name], [SortSequence] )
	VALUES (@GeneDate, 1, '/*' + CHAR(10) + @ScriptComment + CHAR(10) + 'Latest restore points: ' + (SELECT (SELECT CHAR(10) + CHAR(9) + [database_name] + ': ' + REPLICATE(' ',@MaxDBNameLength - LEN([database_name])) + CONVERT(VARCHAR(20), MAX([BackupDate]), 100) FROM #RestoreGene WHERE [BackupDevice] <> '' GROUP BY [database_name] FOR XML PATH(''))) + CHAR(10) + '*/' + CHAR(10) + ';USE [master]', @GeneDate, '', 0, 'master', 0);

	INSERT INTO [RestoreGene] ( [GeneDate], [Latest], [TSQL], [BackupDate], [BackupDevice], [last_lsn], [database_name], [SortSequence] )
	SELECT @GeneDate AS [GeneDate], 1, [TSQL], [BackupDate], [BackupDevice], [last_lsn], [database_name], [SortSequence] FROM [#RestoreGene];

	DECLARE db_cursor CURSOR FOR 
	SELECT [TSQL] FROM [RestoreGene] WHERE [Latest] = 1 ORDER BY [SortSequence] ASC;

	OPEN db_cursor   
	FETCH NEXT FROM db_cursor INTO @TSQL   

	WHILE @@FETCH_STATUS = 0   
	BEGIN   
		   PRINT @TSQL
		   FETCH NEXT FROM db_cursor INTO @TSQL   
	END

	CLOSE db_cursor   
	DEALLOCATE db_cursor

	DELETE FROM [RestoreGene] WHERE [GeneDate] < DATEADD(wk, -1, @GeneDate);
	SET NOCOUNT OFF;
END
GO
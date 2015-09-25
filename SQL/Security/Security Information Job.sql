USE [msdb]
GO

/****** Object:  Job [Daily Security Documentation]    Script Date: 9/25/2015 1:56:52 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

DECLARE @jobId BINARY(16)
SELECT @jobId = job_id FROM msdb.dbo.sysjobs WHERE (name = N'Daily Security Documentation')
IF (@jobId is NULL)
BEGIN
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Daily Security Documentation', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Documents the current instance- and database-level security daily to the DBAUtility.dbo.Security_* tables', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Populate Tables', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET NOCOUNT ON

EXEC dbo.usp_GetSecurityPrinciples	@OutputDatabaseName = ''DBAUtility'', @OutputSchemaName = ''dbo'', @OutputTableName = ''Security_Logins''
EXEC dbo.usp_GetSecurityRoles	@OutputDatabaseName = ''DBAUtility'', @OutputSchemaName = ''dbo'', @OutputTableName = ''Security_Roles''
EXEC dbo.usp_GetSecurityPermissions	@OutputDatabaseName = ''DBAUtility'', @OutputSchemaName = ''dbo'', @OutputTableName = ''Security_Permissions''

DELETE FROM [DBAUtility].[dbo].[Security_Logins]         	WHERE [AsOfDate] < DATEADD(mm, -1, GETDATE())
DELETE FROM [DBAUtility].[dbo].[Security_Roles]          	WHERE [AsOfDate] < DATEADD(mm, -1, GETDATE())
DELETE FROM [DBAUtility].[dbo].[Security_Permissions]	WHERE [AsOfDate] < DATEADD(mm, -1, GETDATE())

SET NOCOUNT OFF', 
		@database_name=N'DBAUtility', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO
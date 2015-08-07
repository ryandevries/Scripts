DECLARE @SERVERNAME varchar(50)
DECLARE @INSTANCENAME varchar(50)

SET @SERVERNAME = CONVERT(varchar(50),(SELECT SERVERPROPERTY('MachineName')))
SET @INSTANCENAME = CONVERT(varchar(50),(SELECT SERVERPROPERTY('InstanceName')))

IF OBJECT_ID('tempdb..#lastExecution') IS NOT NULL
	DROP TABLE #lastExecution
IF OBJECT_ID('tempdb..#lastExecution2') IS NOT NULL
	DROP TABLE #lastExecution2

IF CAST(SERVERPROPERTY('Edition') AS varchar) NOT LIKE 'Express%'
BEGIN
	IF LEFT(CAST(SERVERPROPERTY('ProductVersion') AS varchar),1)='8'
	BEGIN
		SELECT job_id, 
			MAX(instance_id) AS last_instance_id
		INTO #lastExecution
		FROM msdb.dbo.sysjobhistory jh
		WHERE step_id = 0
		GROUP BY job_id
		SELECT 
			sj.name AS JobName, 
			CAST(CASE sj.enabled WHEN 0 THEN 'Disabled' WHEN 1 THEN 'Enabled' END AS varchar(15)) AS Status,
			suser_sname(sj.owner_sid) AS Owner,
			CAST(CASE sjh.run_status WHEN 0 THEN 'Error Failed' WHEN 1 THEN 'Succeeded' WHEN 2 THEN 'Retry' WHEN 3 THEN 'Cancelled' WHEN 4 THEN 'In Progress' ELSE 'Status Unknown' END AS varchar(15)) AS LastRunStatus,
			ISNULL(CONVERT(datetime,CONVERT(char(8), sjh.run_date)), '1900-01-01 00:00:00.000') AS LastRunDate,
			ISNULL(STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6), sjh.run_duration), 6), 3, 0, ':'), 6, 0, ':'), '00:00:00') AS RunDuration,
			'1900-01-01 00:00:00.000' AS NextRunDate,
			CAST(CASE sj.notify_level_email WHEN 0 THEN 'Never' WHEN 1 THEN 'On Success' WHEN 2 THEN 'On Failure' WHEN 3 THEN 'On Completion' END AS varchar(15)) AS NotifyLevel, 
			ISNULL(so.email_address, 'N/A') AS NotifyEmail,
			getdate() as Timestamp
		FROM msdb.dbo.sysjobs sj 
		LEFT OUTER JOIN #lastExecution AS le ON sj.job_id = le.job_id
		LEFT OUTER JOIN msdb.dbo.sysjobhistory AS sjh ON le.last_instance_id = sjh.instance_id
		LEFT OUTER JOIN msdb.dbo.sysoperators so ON sj.notify_email_operator_id = so.id
		ORDER BY sj.name ASC
	END
	ELSE
	BEGIN
		SELECT job_id, 
			MAX(instance_id) AS last_instance_id
		INTO #lastExecution2
		FROM msdb.dbo.sysjobhistory jh
		WHERE step_id = 0
		GROUP BY job_id
		SELECT sj.name AS JobName,
			CAST(CASE sj.enabled WHEN 0 THEN 'Disabled' WHEN 1 THEN 'Enabled' END AS varchar(15)) AS Status,
			suser_sname(sj.owner_sid) AS Owner,
			CAST(CASE sjh.run_status WHEN 0 THEN 'Error Failed' WHEN 1 THEN 'Succeeded' WHEN 2 THEN 'Retry' WHEN 3 THEN 'Cancelled' WHEN 4 THEN 'In Progress' ELSE 'Status Unknown' END AS varchar(15)) AS LastRunStatus,
			ISNULL(sja.run_requested_date, '1900-01-01 00:00:00.000') AS LastRunDate,
			ISNULL(STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6), sjh.run_duration), 6), 3, 0, ':'), 6, 0, ':'), '00:00:00') AS RunDuration,
			ISNULL(sja.next_scheduled_run_date, '1900-01-01 00:00:00.000') AS NextRunDate,
			CAST(CASE sj.notify_level_email WHEN 0 THEN 'Never' WHEN 1 THEN 'On Success' WHEN 2 THEN 'On Failure' WHEN 3 THEN 'On Completion' END AS varchar(15)) AS NotifyLevel, 
			ISNULL(so.email_address, 'N/A') AS NotifyEmail,
			getdate() as Timestamp
		FROM msdb.dbo.sysjobs AS sj
		LEFT OUTER JOIN #lastExecution2 AS le ON sj.job_id = le.job_id
		LEFT OUTER JOIN msdb.dbo.sysjobhistory AS sjh ON le.last_instance_id = sjh.instance_id
		LEFT OUTER JOIN msdb.dbo.sysjobactivity AS sja on sjh.instance_id = sja.job_history_id
		LEFT OUTER JOIN msdb.dbo.sysoperators so ON sj.notify_email_operator_id = so.id
		ORDER BY sj.name ASC
	END
END

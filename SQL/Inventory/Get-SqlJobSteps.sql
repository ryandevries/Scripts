IF CAST(SERVERPROPERTY('Edition') As Varchar) NOT LIKE 'Express%'
BEGIN
	IF OBJECT_ID('tempdb..#tmplastinstances') IS NOT NULL
	   DROP TABLE #tmplastinstances

	SELECT job_id, step_id, MAX(instance_id) AS last_instance_id
	INTO #tmplastinstances
	FROM msdb.dbo.sysjobhistory
	WHERE step_id > 0
	GROUP BY job_id, step_id
	IF LEFT(CAST(SERVERPROPERTY('ProductVersion') AS varchar),1)='8'
	BEGIN
		-- SQL 2000
		SELECT sj.name AS [JobName], 
			sjs.step_id AS [StepNumber], 
			sjs.step_name AS [StepName], 
			sjs.SubSystem,
			CASE sjs.last_run_date WHEN 0 THEN 
				CASE sjh.run_status WHEN 0 THEN 'Failure' WHEN 1 THEN 'Success' WHEN 2 THEN 'Retry' WHEN 3 THEN 'Canceled' ELSE NULL END ELSE 
				CASE sjs.last_run_outcome WHEN 0 THEN 'Failure' WHEN 1 THEN 'Success' WHEN 2 THEN 'Retry' WHEN 3 THEN 'Canceled' ELSE 'Unknown' END END AS [LastRunStatus],
			CASE sjs.last_run_date WHEN 0 THEN
				CONVERT(datetime, STUFF(STUFF(CONVERT(varchar(8), sjh.run_date), 5, 0, '-'), 8, 0, '-') + 
				' ' + 
				STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6), sjh.run_time), 6), 3, 0, ':'), 6, 0, ':'))
				ELSE 
				CONVERT(datetime, STUFF(STUFF(CONVERT(varchar(8), sjs.last_run_date), 5, 0, '-'), 8, 0, '-') + 
				' ' + 
				STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6), sjs.last_run_time), 6), 3, 0, ':'), 6, 0, ':')) END AS [LastRunDate], 
			CASE sjs.last_run_date WHEN 0 THEN 
				CONVERT(varchar(15), STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6), sjh.run_duration), 6), 3, 0, ':'), 6, 0, ':'))
				ELSE 
				CONVERT(varchar(15), STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6), sjs.last_run_duration), 6), 3, 0, ':'), 6, 0, ':')) END AS [LastRunDuration], 
			'SQL Server Agent Service Account' AS [Proxy],
			sjs.output_file_name AS [LogFile],
			sjs.Command,
			sjh.Message,
			newid() AS [StepUID],
			getdate() as Timestamp
		FROM msdb.dbo.sysjobsteps sjs
		LEFT OUTER JOIN msdb.dbo.sysjobs sj ON sjs.job_id = sj.job_id
		LEFT OUTER JOIN #tmplastinstances li ON sjs.step_id = li.step_id AND sjs.job_id = li.job_id
		LEFT OUTER JOIN msdb.dbo.sysjobhistory sjh ON li.last_instance_id = sjh.instance_id
		ORDER BY sj.name, sjs.step_id
	END
	ELSE
	BEGIN
		-- Not SQL 2000
		SELECT sj.name AS [JobName], 
			sjs.step_id AS [StepNumber], 
			sjs.step_name AS [StepName], 
			sjs.SubSystem,
			CASE sjs.last_run_date WHEN 0 THEN 
				CASE sjh.run_status WHEN 0 THEN 'Failure' WHEN 1 THEN 'Success' WHEN 2 THEN 'Retry' WHEN 3 THEN 'Canceled' ELSE NULL END ELSE 
				CASE sjs.last_run_outcome WHEN 0 THEN 'Failure' WHEN 1 THEN 'Success' WHEN 2 THEN 'Retry' WHEN 3 THEN 'Canceled' ELSE 'Unknown' END END AS [LastRunStatus], 
			msdb.dbo.agent_datetime(
				CASE sjs.last_run_date WHEN 0 THEN sjh.run_date ELSE sjs.last_run_date END, 
				CASE sjs.last_run_date WHEN 0 THEN sjh.run_time ELSE sjs.last_run_time END) AS [LastRunDate], 
			CASE sjs.last_run_date WHEN 0 THEN 
				CONVERT(varchar(15), CONVERT(time, STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6), sjh.run_duration), 6), 3, 0, ':'), 6, 0, ':')), 120)
				ELSE 
				CONVERT(varchar(15), CONVERT(time, STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6), sjs.last_run_duration), 6), 3, 0, ':'), 6, 0, ':')), 120) END AS [LastRunDuration], 
			CASE sjs.subsystem WHEN 'TSQL' THEN SUSER_SNAME(sj.owner_sid) ELSE ISNULL(c.credential_identity,'SQL Server Agent Service Account') END AS [Proxy],
			sjs.output_file_name AS [LogFile],
			sjs.Command,
			sjh.Message,
			sjs.step_uid AS [StepUID],
			getdate() as Timestamp
		FROM msdb.dbo.sysjobsteps sjs
		LEFT OUTER JOIN msdb.dbo.sysjobs sj ON sjs.job_id = sj.job_id
		LEFT OUTER JOIN msdb.dbo.sysproxies sp ON sjs.proxy_id = sp.proxy_id
		LEFT OUTER JOIN msdb.sys.credentials c ON sp.credential_id = c.credential_id
		LEFT OUTER JOIN #tmplastinstances li ON sjs.step_id = li.step_id AND sjs.job_id = li.job_id
		LEFT OUTER JOIN msdb.dbo.sysjobhistory sjh ON li.last_instance_id = sjh.instance_id
		ORDER BY sj.name, sjs.step_id
	END
END

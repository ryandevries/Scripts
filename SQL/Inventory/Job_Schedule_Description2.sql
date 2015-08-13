-- Returns all enabled schedules and their descriptions for all enabled jobs
IF OBJECT_ID('tempdb..#tmpjobschedules') IS NOT NULL
   DROP TABLE #tmpjobschedules

SELECT @@SERVERNAME as [Server], j.Name as [Job Name],
	-- Type of Schedule
	CASE freq_type 
	WHEN 1 THEN 'One time, occurs at ' + CONVERT(varchar(15), CONVERT(time, STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6), active_start_time), 6), 3, 0, ':'), 6, 0, ':')), 100) + ' on ' + CONVERT(varchar, CONVERT(datetime,CONVERT(char(8), s.active_start_date)), 101)
	WHEN 64 THEN 'When SQL Server Agent Service starts'
	WHEN 128 THEN 'When the Server is idle'
	ELSE ''
	END +
	-- Frequency of type
	CASE
	WHEN freq_type = 4 THEN 'Every ' + 
		CASE s.freq_interval 
		WHEN 1 THEN 'day' 
		ELSE CONVERT(varchar, s.freq_interval) + ' day(s)' 
		END
	WHEN freq_type = 8 THEN	'Every ' + 
		CASE s.freq_recurrence_factor 
		WHEN 1 THEN 'week on ' 
		ELSE CONVERT(varchar, s.freq_recurrence_factor) + ' week(s) on ' 
		END +  
		REPLACE(RTRIM(
			CASE WHEN s.freq_interval & 1 = 1 THEN 'Sunday ' ELSE '' END +
			CASE WHEN s.freq_interval & 2 = 2 THEN 'Monday ' ELSE '' END	+
			CASE WHEN s.freq_interval & 4 = 4 THEN 'Tuesday ' ELSE '' END +
			CASE WHEN s.freq_interval & 8 = 8 THEN 'Wednesday ' ELSE ''	END +
			CASE WHEN s.freq_interval & 16 = 16 THEN 'Thursday ' ELSE '' END +
			CASE WHEN s.freq_interval & 32 = 32 THEN 'Friday ' ELSE '' END	+
			CASE WHEN s.freq_interval & 64 = 64 THEN 'Saturday ' ELSE '' END), ' ', ', ')
	WHEN freq_type = 16 THEN 'Every ' + 
		CASE s.freq_recurrence_factor 
		WHEN 1 THEN 'month on day ' 
		ELSE CONVERT(varchar, s.freq_recurrence_factor) + ' month(s) on day ' 
		END + CONVERT(varchar(2), s.freq_interval)
	WHEN freq_type = 32 THEN 'Every ' + 
		CASE s.freq_recurrence_factor 
		WHEN 1 THEN 'month on the ' 
		ELSE CONVERT(varchar, s.freq_recurrence_factor) + ' month(s) on the ' 
		END + 
			CASE s.freq_relative_interval WHEN 1 THEN 'first ' WHEN 2 THEN 'second ' WHEN 4 THEN 'third ' WHEN 8 THEN 'fourth ' WHEN 16 THEN 'last ' END + 
			CASE s.freq_interval WHEN 1 THEN 'Sunday' WHEN 2 THEN 'Monday' WHEN 3 THEN 'Tuesday' WHEN 4 THEN 'Wednesday' WHEN 5 THEN 'Thursday' WHEN 6 THEN 'Friday' WHEN 7 THEN 'Saturday' WHEN 8 THEN 'day' WHEN 9 THEN 'weekday' WHEN 10 THEN 'weekend' END 
	ELSE ''
	END +
	-- Frequency of time
	CASE s.freq_subday_type 
	WHEN 1 THEN ' at ' + CONVERT(varchar(15), CONVERT(time, STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6), active_start_time), 6), 3, 0, ':'), 6, 0, ':')), 100)
	WHEN 2 THEN ', every ' + CONVERT(varchar, freq_subday_interval) + ' second(s)'
	WHEN 4 THEN ', every ' + CONVERT(varchar, freq_subday_interval) + ' minute(s)'
	WHEN 8 THEN ', every ' + CONVERT(varchar, freq_subday_interval) + ' hour(s)'
	ELSE ''
	END +
	-- Time bounds
	CASE s.freq_subday_type 
	WHEN 0 THEN ''
	WHEN 1 THEN ''
	ELSE ' between ' + CONVERT(varchar(15), CONVERT(time, STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6),s.active_start_time),6 ),3,0,':'),6,0,':')), 100) + ' and ' + CONVERT(varchar(15), CONVERT(time, STUFF(STUFF(RIGHT('000000' + CONVERT(varchar(6),active_end_time),6 ),3,0,':'),6,0,':')), 100)
	END + 
	-- Date bounds
	', starting on ' + CONVERT(varchar, CONVERT(datetime,CONVERT(char(8), s.active_start_date)), 101) +
	CASE active_end_date
	WHEN '99991231' THEN '' 
	ELSE ' and ending on ' + CONVERT(varchar, CONVERT(datetime,CONVERT(char(8), s.active_end_date)), 101)
	END AS [Schedule],
	CONVERT(varchar, msdb.dbo.agent_datetime(js.next_run_date, js.next_run_time), 120) AS [Next Run Date]
INTO #tmpjobschedules
FROM msdb.dbo.sysjobs j
LEFT OUTER JOIN msdb.dbo.sysjobschedules js on j.job_id = js.job_id
LEFT OUTER JOIN msdb.dbo.sysschedules s on js.schedule_id = s.schedule_id
WHERE j.enabled = 1 and s.enabled = 1
ORDER BY j.name ASC

SELECT j.[name] AS [Job Name], CASE 
	WHEN STUFF((
		SELECT '; ' + s.Schedule
		FROM #tmpjobschedules s
		WHERE j.[name] = s.[Job Name]
		FOR XML PATH ('')), 1, 2, '')
		IS NULL THEN 'Not Scheduled' 
	ELSE STUFF((
		SELECT '; ' + s.Schedule
		FROM #tmpjobschedules s
		WHERE j.[name] = s.[Job Name]
		FOR XML PATH ('')), 1, 2, '') END AS [Schedules],
	(SELECT MIN(s.[Next Run Date]) FROM #tmpjobschedules s WHERE j.[name] = s.[Job Name]) AS [Next Run Date]
FROM msdb.dbo.sysjobs j

DROP TABLE #tmpjobschedules
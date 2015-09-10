DECLARE @SQLDECLARE varchar(8000)
	, @SQLSET1 varchar(8000)
	, @SQLSET2 varchar(8000)
	, @SQLSELECT varchar(8000)

SET @SQLDECLARE = '
DECLARE @VERSION varchar(50)
	, @BUILD varchar(50)
	, @BUILDNUMBER varchar(50)
	, @EDITION varchar(50)
	, @AUTHENTICATION varchar(50)
	, @SERVERNAME varchar(50)
	, @INSTANCENAME varchar(50)
	, @MEMORYALLOCATEDMB bigint
	, @MAXDOP int
	, @CTFP int
	, @CORES int
	, @TOTALMEMORYMB bigint
	, @STARTUPTIME datetime'

SET @SQLSET1 = '
SET @SERVERNAME = CONVERT(varchar(50),(SELECT SERVERPROPERTY(''MachineName'')))
	SET @INSTANCENAME = CONVERT(varchar(50),(SELECT SERVERPROPERTY(''InstanceName'')))
	SET @VERSION = CONVERT(varchar(50),(SELECT CASE (SELECT LEFT(CAST(SERVERPROPERTY(''ProductVersion'') AS VARCHAR), 4))
		WHEN ''13.0'' THEN ''SQL Server 2016''
		WHEN ''12.0'' THEN ''SQL Server 2014''
		WHEN ''11.0'' THEN ''SQL Server 2012''
		WHEN ''10.5'' THEN ''SQL Server 2008 R2''
		WHEN ''10.0'' THEN ''SQL Server 2008''
		WHEN ''9.00'' THEN ''SQL Server 2005''
		WHEN ''8.00'' THEN ''SQL Server 2000''
		ELSE ''ERROR'' END)) 
	SET @BUILD = CONVERT(varchar(50),(SELECT SERVERPROPERTY(''ProductLevel'')))
	SET @BUILDNUMBER = CONVERT(varchar(50),(SELECT SERVERPROPERTY(''ProductVersion'')))
	SET @EDITION = CONVERT(varchar(50),(SELECT SERVERPROPERTY(''Edition'')))
	SET @AUTHENTICATION = CONVERT(varchar(50),(SELECT CASE (SELECT SERVERPROPERTY(''IsIntegratedSecurityOnly'')) WHEN 1 THEN ''Windows'' WHEN 0 THEN ''Mixed Mode'' END))'

IF LEFT(CAST(SERVERPROPERTY('ProductVersion') AS varchar),1)='8'
BEGIN	
    SET @SQLSET2 = '
	IF OBJECT_ID(''tempdb..#tmpOSstats'') IS NOT NULL
		DROP TABLE #tmpOSstats
	CREATE TABLE #tmpOSstats ([Index] VARCHAR(2000), [Name] VARCHAR(2000), [Internal_Value] VARCHAR(2000), [Character_Value] VARCHAR(2000)) 
	INSERT INTO #tmpOSstats EXEC xp_msver
	
	SET @MEMORYALLOCATEDMB = CONVERT(bigint,(SELECT value FROM [master].[dbo].[sysconfigures] WHERE config = ''1544''))
    SET @MAXDOP = CONVERT(int,(SELECT value FROM [master].[dbo].[sysconfigures] WHERE config = ''1539''))
    SET @CTFP = CONVERT(int,(SELECT value FROM [master].[dbo].[sysconfigures] WHERE config = ''1538''))
	SET @CORES = (SELECT Internal_Value FROM #tmpOSstats WHERE Name = ''ProcessorCount'')
	SET @TOTALMEMORYMB = (SELECT Internal_Value FROM #tmpOSstats WHERE Name = ''PhysicalMemory'')
	SET @STARTUPTIME = (SELECT crdate FROM [master].[dbo].[sysdatabases] WHERE name = ''tempdb'')'
END
ELSE IF LEFT(CAST(SERVERPROPERTY('ProductVersion') AS varchar),1)='9'
BEGIN	
    SET @SQLSET2 = '
	SET @MEMORYALLOCATEDMB = CONVERT(bigint,(SELECT value FROM [master].[dbo].[sysconfigures] WHERE config = ''1544''))
    SET @MAXDOP = CONVERT(int,(SELECT value FROM [master].[dbo].[sysconfigures] WHERE config = ''1539''))
    SET @CTFP = CONVERT(int,(SELECT value FROM [master].[dbo].[sysconfigures] WHERE config = ''1538''))
	SET @CORES = (SELECT cpu_count FROM [master].[sys].[dm_os_sys_info])
	SET @TOTALMEMORYMB = (SELECT physical_memory_in_bytes/1024/1024 FROM [master].[sys].[dm_os_sys_info])
	SET @STARTUPTIME = (SELECT create_date FROM [master].[sys].[databases] WHERE name = ''tempdb'')'
END
ELSE
BEGIN
	SET @SQLSET2 = '
	SET @MEMORYALLOCATEDMB = CONVERT(bigint,(SELECT value FROM [master].[sys].[configurations] WHERE configuration_id = ''1544''))
    SET @MAXDOP = CONVERT(int,(SELECT value FROM [master].[sys].[configurations] WHERE configuration_id = ''1539''))
    SET @CTFP = CONVERT(int,(SELECT value FROM [master].[sys].[configurations] WHERE configuration_id = ''1538''))
	SET @CORES = (SELECT cpu_count FROM [master].[sys].[dm_os_sys_info])
	SET @TOTALMEMORYMB = (SELECT [total_physical_memory_kb]/1024 FROM [master].[sys].[dm_os_sys_memory])
	SET @STARTUPTIME = (SELECT sqlserver_start_time FROM [master].[sys].[dm_os_sys_info])'
END

SET @SQLSELECT = '
SELECT @SERVERNAME AS ServerName, @INSTANCENAME AS InstanceName, @VERSION AS Version, @BUILD AS Build, @BUILDNUMBER AS BuildNumber, @EDITION AS Edition, @AUTHENTICATION AS Authentication, @CORES AS Cores, @TOTALMEMORYMB AS TotalMemoryMB, @MEMORYALLOCATEDMB AS MemoryAllocatedMB, @MAXDOP AS MaxDOP, @CTFP AS CTFP, @STARTUPTIME AS StartupTime, getdate() AS Timestamp'

EXEC (@SQLDECLARE + @SQLSET1 + @SQLSET2 + @SQLSELECT)

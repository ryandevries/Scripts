-- Pull the last DBCC CheckDB, in number of hours ago for a specific DB

IF OBJECT_ID('tempdb..#DBInfo') IS NOT NULL
	DROP TABLE #DBInfo
IF OBJECT_ID('tempdb..#Value') IS NOT NULL
	DROP TABLE #Value
CREATE TABLE #DBInfo (Id INT IDENTITY(1,1), ParentObject VARCHAR(255), [Object] VARCHAR(255), Field VARCHAR(255), [Value] VARCHAR(255))
CREATE TABLE #Value  (DatabaseName VARCHAR(255), LastDBCCCheckDB DATETIME)
INSERT INTO #DBInfo EXECUTE ('DECLARE @DBName NVARCHAR(128); SET @DBName = DB_NAME(); DBCC DBINFO ( @DBName ) WITH TABLERESULTS');
INSERT INTO #Value (DatabaseName)   (SELECT       [Value] FROM #DBInfo WHERE Field = 'dbi_dbname');
UPDATE #Value SET LastDBCCCheckDB = (SELECT TOP 1 [Value] FROM #DBInfo WHERE Field = 'dbi_dbccLastKnownGood') WHERE LastDBCCCheckDB IS NULL;
SELECT DatabaseName, CASE DatabaseName WHEN 'tempdb' THEN '0' ELSE DATEDIFF(HOUR, (SELECT LastDBCCCheckDB FROM #Value), GETDATE()) END AS HoursSinceDBCCCheckDB FROM #Value
DROP TABLE #DBInfo
DROP TABLE #Value

-- Pull the last DBCC CheckDB for all DBs

IF OBJECT_ID('tempdb..#DBInfo') IS NOT NULL
	DROP TABLE #DBInfo
IF OBJECT_ID('tempdb..#Value') IS NOT NULL
	DROP TABLE #Value
CREATE TABLE #DBInfo (ParentObject VARCHAR(255), [Object] VARCHAR(255), Field VARCHAR(255), [Value] VARCHAR(255))
CREATE TABLE #Value  (DatabaseName VARCHAR(255), LastDBCCCheckDB DATETIME)
EXECUTE sp_MSforeachdb '
-- Insert results of DBCC DBINFO into temp table, transform into simpler table with database name and datetime of last known good DBCC CheckDB
INSERT INTO #DBInfo EXECUTE (''DBCC DBINFO ( ''''?'''' ) WITH TABLERESULTS'');
INSERT INTO #Value (DatabaseName, LastDBCCCheckDB)   (SELECT ''?'', [Value] FROM #DBInfo WHERE Field = ''dbi_dbccLastKnownGood'');
TRUNCATE TABLE #DBInfo;
'
SELECT * FROM #Value
DROP TABLE #DBInfo
DROP TABLE #Value

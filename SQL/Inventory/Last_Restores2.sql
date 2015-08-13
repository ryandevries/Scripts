WITH restore_date_cte AS ( 
	SELECT   d.name AS DatabaseName
			, rh.restore_date AS BackUpRestoredDatetime
			, ISNULL(rh.user_name, 'No Restore') AS RestoredBy
			, bs.name AS BackUpName
			, bs.user_name AS BackupCreatedBy
			, bs.backup_finish_date AS backupCompletedDatetime
			, bs.database_name AS BackupSourceDB
			, bs.server_name AS BackupSourceSQLInstance
			, ROW_NUMBER() OVER --get the most recent
			( PARTITION BY d.name ORDER BY rh.restore_date DESC ) AS RestoreOrder
	FROM sys.databases AS d
	LEFT JOIN msdb.dbo.restorehistory AS rh
				ON d.name = rh.destination_database_name
	LEFT JOIN msdb.dbo.BackupSet AS bs
				ON rh.backup_set_id = bs.backup_set_id
)
SELECT  rdc.DatabaseName
        , rdc.BackUpRestoredDatetime
        , rdc.RestoredBy
        , rdc.BackUpName
        , rdc.BackupCreatedBy
        , rdc.backupCompletedDatetime
        , rdc.BackupSourceDB
        , rdc.BackupSourceSQLInstance
        , rdc.RestoreOrder
FROM    restore_date_cte AS rdc
WHERE   RestoreOrder = 1
ORDER BY rdc.DatabaseName
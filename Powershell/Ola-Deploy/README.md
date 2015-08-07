To Run:
- Populate the Instances.csv with your instance names/environments
- Run the Deploy-SQLMaintenance.ps1 PowerShell script

Configurations:
- Utility database: 0_Utility Database\Maintenance - Database Creation.sql
- Stored Procedures: 1_Stored Procedures, change USE statement in each of the stored procedures to reflect your desired database if you change the name of the Utility database
- Ola database: 2_Maintenance Solution\Maintenance - Job Creation.sql @DatabaseName
- Backup directory: 2_Maintenance Solution\Maintenance - Job Creation.sql @BackupDirectory
- Cleanup time: 2_Maintenance Solution\Maintenance - Job Creation.sql @CleanupTime
- Job description: 2_Maintenance Solution\Maintenance - Job Creation.sql @JobDescription
- Schedules: 2_Maintenance Solution\Schedules

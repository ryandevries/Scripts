SET NOCOUNT ON

EXEC dbo.usp_GetSecurityPrinciples	@OutputDatabaseName = 'DBAUtility', @OutputSchemaName = 'dbo', @OutputTableName = 'Security_Logins'
EXEC dbo.usp_GetSecurityRoles		@OutputDatabaseName = 'DBAUtility', @OutputSchemaName = 'dbo', @OutputTableName = 'Security_Roles'
EXEC dbo.usp_GetSecurityPermissions @OutputDatabaseName = 'DBAUtility', @OutputSchemaName = 'dbo', @OutputTableName = 'Security_Permissions'

DELETE FROM [DBAUtility].[dbo].[Security_Logins]      WHERE [AsOfDate] < DATEADD(mm, -1, GETDATE())
DELETE FROM [DBAUtility].[dbo].[Security_Roles]       WHERE [AsOfDate] < DATEADD(mm, -1, GETDATE())
DELETE FROM [DBAUtility].[dbo].[Security_Permissions] WHERE [AsOfDate] < DATEADD(mm, -1, GETDATE())

SET NOCOUNT OFF
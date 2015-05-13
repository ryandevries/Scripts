CREATE DATABASE [DBAUtility]
GO
USE     [DBAUtility]
DECLARE @DBOwner nvarchar(max)
SET     @DBOwner = SUSER_SNAME(0x01)
EXEC    dbo.sp_changedbowner @loginame = @DBOwner

-- =============================================
-- Author:		Sharon
-- Create date: 09/04/2017
-- Update date: 
-- Description:	Upload image to DB
-- =============================================
CREATE PROCEDURE [Utility].[usp_UploadImagetoDatabase] (@Path VARCHAR(512),@Name sysname)
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @cmd NVARCHAR(max);
	SELECT @cmd = N'INSERT [Configuration].[Images] SELECT	@Name,(SELECT * FROM OPENROWSET (BULK ''' + @Path + ''', SINGLE_BLOB) my);';

	EXEC sp_executesql @cmd, N'@Name sysname',@Name = @Name;

END
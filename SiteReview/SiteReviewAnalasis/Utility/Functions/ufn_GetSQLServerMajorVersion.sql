-- =============================================
-- Author:		Sharon Rimer
-- Create date: 2017/07/10
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [Utility].[ufn_GetSQLServerMajorVersion]
(
	@Version NVARCHAR(MAX)
)
RETURNS INT
AS
BEGIN
	DECLARE @FullMajor INT = 140;
	SELECT	TOP 1 @FullMajor = FullMajor
	FROM	Configuration.SQLServerMajorBuild
	WHERE	@Version LIKE 'Microsoft SQL Server ' + Name + '%';
	
	IF @FullMajor IS NULL
		SET @FullMajor = 140;
	
	RETURN @FullMajor;
END;
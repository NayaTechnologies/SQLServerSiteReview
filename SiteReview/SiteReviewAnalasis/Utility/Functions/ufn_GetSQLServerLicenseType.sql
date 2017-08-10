-- =============================================
-- Author:		Sharon Rimer
-- Create date: 2017/07/10
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION Utility.ufn_GetSQLServerLicenseType
(
	@Version NVARCHAR(MAX)
)
RETURNS sysname
AS
BEGIN
	RETURN CASE 
WHEN @Version LIKE '%Enterprise%' AND @Version LIKE '%Core-based%' THEN 'Enterprise Core Based'
WHEN @Version LIKE '%Enterprise%' THEN 'Enterprise Server + CAL'
WHEN @Version LIKE '%Web%' THEN 'Web'
WHEN @Version LIKE '%Express%' THEN 'Express'
WHEN @Version LIKE '%Developer%' THEN 'Developer'
WHEN @Version LIKE '%Business Intelligence%' THEN 'Business Intelligence'
WHEN @Version LIKE '%Standard%' THEN 'Standard'
ELSE 'Enterprise Server + CAL' END

END
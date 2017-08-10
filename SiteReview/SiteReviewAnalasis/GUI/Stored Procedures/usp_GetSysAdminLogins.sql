-- =============================================
-- Author:		Sharon
-- Create date: 11/05/2017
-- Description:	Get sys Admin
-- =============================================
CREATE PROCEDURE [GUI].[usp_GetSysAdminLogins] @Guid UNIQUEIDENTIFIER = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	SELECT	SA.name [Name],Utility.ufn_Util_clr_Conc(DISTINCT IIF(SA.ParentGroup = '','User',SA.ParentGroup)) [Groups]
	FROM	Client.SysAdmin SA
	WHERE	SA.guid = @Guid
			AND SA.name NOT IN('sa','','','','','','','')
			AND SA.name NOT LIKE 'NT SERVICE%'
			AND SA.name NOT LIKE 'NT AUTHORITY%'
	GROUP BY SA.name
	ORDER BY 2 ASC;

END
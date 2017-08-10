-- =============================================
-- Author:		Sharon
-- Create date: 11/05/2017
-- Description:	Get Heavy Queries
-- =============================================
CREATE PROCEDURE [GUI].[usp_GetHeavyQueries] @Guid UNIQUEIDENTIFIER = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	SELECT	TOP 10 Utility.ufn_Util_clr_Conc(DISTINCT CheckType) [Type],database_name,LEFT(query_text,100)[Query],AVG(AvgDuration)AvgDuration,AVG(AvgScore)[AvgScore],SUM(execution_count)[ExecutionCount],MAX(last_execution_time)[LastExecutionTime]
	FROM	[Client].[HeavyQueries]
	WHERE	guid = @Guid
	GROUP BY LEFT(query_text,100),database_name
	ORDER BY 6 DESC,7 DESC;

END
-- =============================================
-- Author:		Sharon
-- Create date: 19/05/2017
-- Description:	Get Database file Size Chart in GB
-- =============================================
CREATE PROCEDURE [GUI].[usp_GetDatabaseSizeChart] @Guid UNIQUEIDENTIFIER = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	SELECT	TOP 10 DF.database_id,
			DF.Database_Name,
			SUM(DF.Total_Size)/1024[DataSize],
			LDF.Size [LogSize],
			LDF.Size + (SUM(DF.Total_Size)/1024) [Total]
	FROM	Client.DatabaseFiles DF
			CROSS APPLY (SELECT	SUM(LDF.Total_Size)/1024[Size]
			             FROM	Client.DatabaseFiles LDF
						 WHERE  LDF.database_id = DF.database_id
								AND LDF.guid = DF.guid
								AND LDF.File_Type = 'Log'
						GROUP BY LDF.database_id,
								 LDF.guid,
								 LDF.File_Type)LDF
	WHERE	DF.database_id IS NOT NULL
			AND DF.guid = @Guid
			AND DF.File_Type = 'Data'
	GROUP BY DF.database_id,DF.Database_Name,LDF.Size
	HAVING LDF.Size + (SUM(DF.Total_Size)/1024) > 0
	ORDER BY SUM(DF.Total_Size) DESC;

END
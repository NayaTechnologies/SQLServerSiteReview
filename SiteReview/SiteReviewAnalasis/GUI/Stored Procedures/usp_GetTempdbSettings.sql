-- =============================================
-- Author:		Sharon
-- Create date: 2016
-- Update date: 2016/06/08 Sharon
--				2016/07/21 Sharon Utility.ufn_Util_clr_RegexReplace(Version,'Microsoft SQL Server [\d]+ \- ([\d]+\.[\d]+\.[\d]+\.[\d]+)[\W\w]*','$1',0)
--				2017/05/17 Sharon Add @PathDevide for linux support.
-- Description:	
-- =============================================
CREATE PROCEDURE [GUI].[usp_GetTempdbSettings] @guid UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	DECLARE @FilePath NVARCHAR(4000);
	DECLARE @NumberOfDataFiles INT;
	DECLARE @NumberOfCPU INT;
	DECLARE @PathDevide CHAR(1) = '\';

	SELECT	@FilePath = df.Physical_Name
	FROM	[Client].[DatabaseFiles] df 
	WHERE	df.guid = @Guid
			AND df.Database_Name = 'tempdb'
			AND df.File_Type = 'Data'
			AND df.file_id = 1;
	IF charindex('/',@FilePath) > 0
		SET @PathDevide = '/';
	SELECT	@NumberOfDataFiles = COUNT(1)
	FROM	[Client].[DatabaseFiles] df 
	WHERE	df.guid = @Guid
			AND df.Database_Name = 'tempdb'
			AND df.File_Type = 'Data';

	SELECT	@NumberOfCPU = SP.logicalCPU
	FROM	Client.ServerProporties SP
	WHERE	SP.guid = @Guid;
			

	SELECT	Num.n [ID],
			CASE I.[ImageID] 
			WHEN 1 THEN 'File is OK' 
			WHEN 2 THEN P.[FileName]
			WHEN 3 THEN 'Change file size' 
			ELSE NULL END [Description],
			Im.img,
			ISNULL(RDF.[File_Name]+ CONCAT(' (',RDF.file_id,')'),'<font color =Orange><B>Add file at</B></font>') [FileName]
	INTO	#TempFiles
	FROM	(SELECT	v.number n
	    	 FROM	master..spt_values v
			 WHERE	v.type = 'p'
					AND v.number <= 
					CASE WHEN @NumberOfDataFiles >= @NumberOfCPU THEN @NumberOfDataFiles
					WHEN @NumberOfDataFiles >= 8 THEN @NumberOfDataFiles
					WHEN @NumberOfDataFiles <= @NumberOfCPU AND @NumberOfCPU <= 4 THEN @NumberOfCPU
					WHEN @NumberOfDataFiles <= @NumberOfCPU AND @NumberOfCPU > 4 AND @NumberOfCPU < 8 THEN @NumberOfCPU
					WHEN @NumberOfDataFiles <= @NumberOfCPU AND @NumberOfCPU >= 8 THEN 8
					ELSE @NumberOfDataFiles
					END
					)Num
			LEFT JOIN (SELECT	*,ROW_NUMBER() OVER (ORDER BY df.file_id) RN
					   FROM		[Client].[DatabaseFiles] df 
						WHERE	df.guid = @Guid
								AND df.Database_Name = 'tempdb'
								AND df.File_Type = 'Data')RDF ON Num.n = RDF.RN

			CROSS JOIN(SELECT	TOP 1 Sdf.Total_Size,COUNT(1) Num
					   FROM		[Client].[DatabaseFiles] Sdf 
						WHERE	Sdf.guid = @Guid
								AND Sdf.Database_Name = 'tempdb'
								AND Sdf.File_Type = 'Data'
						GROUP BY	Sdf.Total_Size
						ORDER BY COUNT(1) DESC,Sdf.Total_Size DESC)S
			CROSS APPLY(SELECT	CASE 
					WHEN RDF.Database_Name IS NULL THEN 2 
					ELSE CASE WHEN RDF.Total_Size = S.Total_Size THEN 1 ELSE 3 END
					END [ImageID])I
			CROSS APPLY(select top 1 
			CASE WHEN RDF.Database_Name IS NOT NULL THEN @FilePath ELSE 
			LEFT(@FilePath,LEN(@FilePath) - charindex(@PathDevide,reverse(@FilePath),1) + 1) + REPLACE(REVERSE(LEFT(REVERSE(@FilePath),CHARINDEX(@PathDevide, REVERSE(@FilePath), 1) - 1)),'.mdf',
									convert(varchar(3),Num.n) +'.ndf') END FileName)P
			INNER JOIN Configuration.Images Im ON Im.ID = I.ImageID
	--WHERE	Num.n <= (select case when SP.logicalCPU > 8 then 8 else SP.logicalCPU end from Client.ServerProporties SP WHERE SP.guid = @Guid)


	--Display
	SELECT	TF.ID ,
            TF.Description ,
            TF.img,
			TF.FileName,
			TF2.ID ID2,
            TF2.Description Description2,
            TF2.img img2,
			TF2.FileName [FileName2],
			TF3.ID ID3,
            TF3.Description Description3,
            TF3.img img3,
			TF3.FileName [FileName3],
			TF4.ID ID4,
            TF4.Description Description4,
            TF4.img img4,
			TF4.FileName [FileName4]
	FROM	#TempFiles TF
			LEFT JOIN #TempFiles TF2 ON TF2.ID = TF.ID + 1
			LEFT JOIN #TempFiles TF3 ON TF3.ID = TF2.ID + 1
			LEFT JOIN #TempFiles TF4 ON TF4.ID = TF3.ID + 1
	WHERE	TF.ID % 4 = 1
	ORDER BY TF.ID ASC;
END


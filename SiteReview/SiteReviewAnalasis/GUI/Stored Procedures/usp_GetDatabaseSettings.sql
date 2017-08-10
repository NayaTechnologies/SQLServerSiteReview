-- =============================================
-- Author:		Sharon
-- Create date: 2016
-- Update date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [GUI].[usp_GetDatabaseSettings] @guid UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Img VARBINARY(MAX);
	DECLARE @Collation sysname;
	DECLARE @compatibility_level INT;
	DECLARE @Ver NVARCHAR(128);

	SELECT	@Collation = Collation,
			@Ver = ISNULL(ProductVersion,Utility.ufn_Util_clr_RegexReplace(Version,'([\W\w]*)\- ([\d]+\.[\d]+\.[\d]+\.[\d]+)[\W\w]*','$2',0))
	FROM	Client.[MachineSettings]
    WHERE   guid = @guid;
	SELECT	@compatibility_level = TRY_CONVERT(INT,PARSENAME(CONVERT(VARCHAR(32), @Ver), 4)+ LEFT(PARSENAME(CONVERT(VARCHAR(32), @Ver), 3),1))
	SELECT	@Img = img
	FROM	[Configuration].[Images]
	WHERE	ID = 16;--DB Image
	DECLARE @Ignore TABLE([Type] sysname);
	IF EXISTS(SELECT TOP 1 1 FROM Client.Software S WHERE S.Status = 1 AND S.guid = @guid)
	INSERT @Ignore VALUES  ('Auto Create Statistics'),('Auto Updtae Statistics');

	
	DECLARE @NumberOfDataFiles INT;
	DECLARE @NumberOfCPU INT;
	
	SELECT	@NumberOfDataFiles = COUNT(1)
	FROM	[Client].[DatabaseFiles] df 
	WHERE	df.guid = @Guid
			AND df.Database_Name = 'tempdb'
			AND df.File_Type = 'Data';

	SELECT	@NumberOfCPU = SP.logicalCPU
	FROM	Client.ServerProporties SP
	WHERE	SP.guid = @Guid;
			



	SELECT	D.database_id,D.name,ISNULL(OA.img,@Img)img
	INTO	#Img
	FROM	Client.Databases D
			LEFT JOIN [Configuration].[Database] ED ON ED.DatabaseName = D.name
			OUTER APPLY (SELECT TOP 1 i.img FROM [Configuration].[Images] i WHERE 
			(D.database_id BETWEEN 1 AND 4 AND i.ID = 11)
			OR (D.IsBizTalk = 1 AND i.ID = 12)
			OR (D.IsCRMDynamics = 1 AND i.ID = 13)
			OR (D.IsSharePoint = 1 AND i.ID = 15)
			OR (D.IsSAP = 1 AND i.ID = 14)
			OR (D.IsTFS = 1 AND i.ID = 22)
			OR (D.name LIKE '%ReportServer%' AND i.ID = 18)
			OR (D.name = 'SSIS' AND i.ID = 19)
			OR (ED.TypeID = 2 AND i.ID = 20)
			)OA
	WHERE	D.guid = @guid;

	SELECT	DISTINCT [Utility].[ufn_CapitalizeFirstLetter](DP.Type) [Type] ,
			DP.DatabaseName ,
			i.img [Image],
			DP.Note,
			D.database_id
	FROM	Client.DatabaseProperties DP
			INNER JOIN Client.Databases D ON D.guid = DP.guid
				AND D.name = DP.DatabaseName
			INNER JOIN #Img i ON i.database_id = D.database_id
	WHERE	DP.guid = @guid
			AND DP.[Type] NOT IN (SELECT [Type] FROM @Ignore)
	UNION ALL 

	SELECT	'Collation',D.name,
			i.img [Image],'Databases have diffarent Collation from the server configuration',
			D.database_id
	FROM	Client.Databases D
			INNER JOIN #Img i ON i.database_id = D.database_id
	WHERE	D.guid = @guid
			AND D.collation_name != @Collation
			AND D.name NOT IN ('ReportServer','ReportServerTempdb')
	UNION ALL 
	SELECT	'Auto Close',D.name,
			i.img [Image],'Databases have is_auto_close proporty on. this is not recommended',
			D.database_id
	FROM	Client.Databases D
			INNER JOIN #Img i ON i.database_id = D.database_id
	WHERE	D.guid = @guid
			AND D.is_auto_close_on = 1
	UNION ALL 
	SELECT	'Auto Shrink',D.name,
			i.img [Image],'Databases have is_auto_shrink proporty on. this is not recommended',
			D.database_id
	FROM	Client.Databases D
			INNER JOIN #Img i ON i.database_id = D.database_id
	WHERE	D.guid = @guid
			AND D.is_auto_shrink_on = 1
	UNION ALL
	SELECT	'Compatibility Level',D.name,
			i.img [Image],'Databases have compatibility_level(' + TRY_CONVERT(VARCHAR(5),D.compatibility_level) + ') lower then the server(' + CONVERT(VARCHAR(5),@compatibility_level) + '). this is not recommanded',
			D.database_id
	FROM	Client.Databases D
			INNER JOIN #Img i ON i.database_id = D.database_id
	WHERE	D.guid = @guid
			AND D.compatibility_level != IIF(@compatibility_level = 105,100,@compatibility_level)
	UNION ALL 
	SELECT	'Log File',DF.Database_Name,
			i.img [Image],CONCAT('Log file size [(Log) ' , CONVERT(NVARCHAR(1000),L.Size) , 'MB / ' , CONVERT(NVARCHAR(1000),SUM(DF.Total_Size)) , 'MB (Data)] is ' , CONVERT(INT,ROUND((L.Size / (SUM(DF.Total_Size)*1.0) * 100),0)) , '% then Database size'),
			DF.database_id
	FROM	Client.DatabaseFiles DF
			CROSS APPLY (SELECT SUM(iDF.Total_Size) Size FROM Client.DatabaseFiles iDF WHERE iDF.guid = @guid AND iDF.File_Type = 'Log' AND iDF.Database_Name = DF.Database_Name)L
			INNER JOIN #Img i ON i.database_id = DF.database_id
	WHERE	DF.guid = @guid
			AND DF.File_Type = 'Data'
	GROUP BY DF.Database_Name,L.Size,i.img,
			DF.database_id
	HAVING	L.Size / SUM(DF.Total_Size) > 0.3
			OR L.Size > SUM(DF.Total_Size)
	UNION ALL 
	SELECT	'Database File',DF.Database_Name,
			i.img [Image],CONCAT('Data file size [', CONVERT(NVARCHAR(1000),SUM(DF.Total_Size)) , 'MB (Data)] is large. Check for more reasons.'),
			DF.database_id
	FROM	Client.DatabaseFiles DF
			INNER JOIN #Img i ON i.database_id = DF.database_id
	WHERE	DF.guid = @guid
			AND DF.File_Type = 'Data'
			AND DF.database_id = 4 --msdb
	GROUP BY DF.Database_Name,DF.database_id,i.img
	HAVING	SUM(DF.Total_Size) > 2000
	UNION ALL 
	SELECT	'Database File',DF.Database_Name,
			im.img [Image],CONCAT('Data file is locate with ', Utility.ufn_Util_clr_Conc(i.File_Type) , ' file. Please choose diffrent drive for etch file type.'),
			DF.database_id
	FROM	Client.DatabaseFiles DF
			CROSS APPLY (SELECT DISTINCT LEFT(iDF.Physical_Name,3) Volume,iDF.File_Type FROM Client.DatabaseFiles iDF WHERE iDF.guid = @guid AND iDF.file_id != 1)i
			INNER JOIN #Img im ON im.database_id = DF.database_id
	WHERE	DF.guid = @guid
			AND DF.file_id = 1
			AND LEFT(DF.Physical_Name,3) = i.Volume
			AND DF.database_id > 4
	GROUP BY DF.Database_Name,DF.database_id,im.img
	UNION ALL 
	SELECT	'Database File','tempdb',im.img [Image],CONCAT('Add ',COUNT(1) - 1,' more data files to database.'	),2
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
			INNER JOIN #Img im ON im.database_id = 2
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
	WHERE RDF.[File_Name] IS NULL
	GROUP BY im.img
	HAVING (COUNT(1) -1) > 0
	UNION ALL 
	SELECT	B.FindingsGroup,B.DatabaseName,im.img [Image],CONCAT(B.Finding,'-',B.Details) [Message],im.database_id
	FROM	Client.Blitz B
			INNER JOIN #Img im ON im.name = B.DatabaseName
	WHERE	B.guid = @Guid
			AND B.Finding NOT IN ('High VLF Count')
			AND B.FindingsGroup NOT IN ('Wait Stats','Rundate','Server Info','Informational','Licensing','Non-Default Server Config')
			AND B.DatabaseName IS NOT NULL
	UNION ALL 
	SELECT	'Database File',DF.Database_Name,
			im.img [Image],'TempDB files are located with other database files. Please choose diffrent drive for TempDB files.',
			DF.database_id
	FROM	Client.DatabaseFiles DF
			CROSS APPLY (SELECT DISTINCT LEFT(iDF.Physical_Name,3) Volume,iDF.File_Type FROM Client.DatabaseFiles iDF WHERE iDF.guid = @guid AND iDF.database_id != 2 AND LEFT(DF.Physical_Name,3) = LEFT(iDF.Physical_Name,3))i
			INNER JOIN #Img im ON im.database_id = DF.database_id
	WHERE	DF.guid = @guid
			AND DF.file_id = 1
			AND LEFT(DF.Physical_Name,3) = i.Volume
			AND DF.database_id = 2
	GROUP BY DF.Database_Name,DF.database_id,im.img
	ORDER BY database_id ASC,2 ASC;
END
-- =============================================
-- Author:		Dror
-- Create date: 2012
-- Update date: 2016/06/08 Sharon
--				2016/07/21 Sharon Utility.ufn_Util_clr_RegexReplace(Version,'Microsoft SQL Server [\d]+ \- ([\d]+\.[\d]+\.[\d]+\.[\d]+)[\W\w]*','$1',0)
-- Description:	
-- =============================================
CREATE PROCEDURE [GUI].[usp_GetMachineSQLSettings] @guid UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Ver NVARCHAR(128) ;
	DECLARE @Edition NVARCHAR(MAX) ;
	DECLARE @ServicePack NVARCHAR(MAX) ;
	DECLARE @PhysicalMemory NVARCHAR(MAX);
	DECLARE @Collation NVARCHAR(MAX);
	DECLARE @CollationRed NVARCHAR(MAX);
	DECLARE @DiffCollation INT ;
	DECLARE @Running INT = 1;
	DECLARE @Comment NVARCHAR(MAX) = '';
	
	SELECT  @Edition = Edition ,
            @ServicePack = ProductLevel  ,
            @Ver = ISNULL(ProductVersion,Utility.ufn_Util_clr_RegexReplace(Version,'([\W\w]*)\- ([\d]+\.[\d]+\.[\d]+\.[\d]+)[\W\w]*','$2',0)),
			@PhysicalMemory = CONVERT(NVARCHAR(MAX),CONVERT(INT,ROUND(TRY_CONVERT(BIGINT,LEFT(ISNULL(PhysicalMemory, ''),
                             CHARINDEX(' ', PhysicalMemory) - 1))/1024.0,0))) + ' GB',
			@Collation = Collation
    FROM      Client.[MachineSettings]
    WHERE     guid = @guid;

	DECLARE @MinServerMemory INT;
	DECLARE @MaxServerMemory INT;
	DECLARE @linkTable TABLE ([name] sysname,[value] NVARCHAR(max),link NVARCHAR(max),Red NVARCHAR(max));
	INSERT @linkTable VALUES  ( 'SQLAgentAccount', N'LocalSystem', N'https://msdn.microsoft.com/en-us/library/ms191543.aspx',N' (Change account)');
	SELECT TOP 1 @MinServerMemory = S.value
	FROM	Client.spconfigure S 
	WHERE	S.guid = @guid AND S.name = 'min server memory (MB)'
	
	SELECT TOP 1 @MaxServerMemory = S.value
	FROM	Client.spconfigure S 
	WHERE	S.guid = @guid AND S.name = 'max server memory (MB)'

	SELECT	@DiffCollation = COUNT(1)
	FROM	Client.Databases D
	WHERE	guid = @guid
			AND D.collation_name != @Collation;
	IF @DiffCollation > 0
		INSERT @linkTable VALUES  ( 'Collation', @Collation, N'http://stackoverflow.com/questions/6031582/complications-with-sql-server-database-having-different-collation-than-the-serve',' (' + CONVERT(NVARCHAR(25),@DiffCollation) + ' DB has different Collation from server configuration)');
		
	SELECT @Running = COUNT(1) FROM Client.Registery R WHERE R.guid = @guid AND R.Service = 'SQL Server Engine State' AND R.Value = 'Running';
	DECLARE @SP TABLE(Build VARCHAR(25),[Description] VARCHAR(MAX),ReleaseDate VARCHAR(35),ShortName VARCHAR(25));
	DECLARE	@NewSP NVARCHAR(MAX) = N'Service Pack ';
	INSERT @SP
	EXEC [GUI].[usp_GetRecommandedSP] @guid;
	
	DECLARE @Build VARCHAR(25), @Description VARCHAR(MAX);
	SELECT	TOP 1 @Description = S.Description
			,@Build = REPLACE(CONCAT(S.Build,'.0'),'.00.','.0.')
	FROM	@SP S
	WHERE	S.ShortName = 'SP';
	 
	IF @Description LIKE '%Service Pack 1%' OR @Description LIKE '% SP1 %' SET @NewSP += N'1'
	ELSE IF @Description LIKE '%Service Pack 2%' OR @Description LIKE '% SP2 %' SET @NewSP += N'2'
	ELSE IF @Description LIKE '%Service Pack 3%' OR @Description LIKE '% SP3 %' SET @NewSP += N'3'
	ELSE IF @Description LIKE '%Service Pack 4%' OR @Description LIKE '% SP4 %' SET @NewSP += N'4'
	ELSE IF @Description LIKE '%Service Pack 5%' OR @Description LIKE '% SP5 %' SET @NewSP += N'5'
	ELSE IF @Description LIKE '%Service Pack 6%' OR @Description LIKE '% SP6 %' SET @NewSP += N'6'
	ELSE IF @Description LIKE '%Service Pack 7%' OR @Description LIKE '% SP7 %' SET @NewSP += N'7'
	ELSE IF @Description LIKE '%Service Pack 8%' OR @Description LIKE '% SP8 %' SET @NewSP += N'8'
	ELSE IF @Description LIKE '%Service Pack 9%' OR @Description LIKE '% SP9 %' SET @NewSP += N'9'
	ELSE SET @NewSP = N'';
	IF EXISTS(SELECT TOP 1 1 FROM [Utility].[ufn_GetSupportEndDate](@Edition,@Ver) WHERE SupportEndDate < GETDATE())
	BEGIN
		
		SET @Comment +=N'<br><font color =Black>Please download and install <B>' + @NewSP + N'</B>.';
		SELECT	TOP 1 @Comment += CONCAT(N'<br>Then you can download and install - ',S.Description)
		FROM	@SP S
		ORDER BY S.Build DESC
		SET @Comment += N'<br>It will change your end of life to - <B>'
		SELECT	@Comment += SupportEndDate
		FROM	[Utility].[ufn_GetSupportEndDate](@Edition,@Build) 
		SET @Comment += N'</B></font>'
	END

	IF [Utility].[ufn_GetSQLServerServicePack](@Ver,@ServicePack,@Ver) LIKE '%' + @NewSP + '%' SET @NewSP = '';
    SELECT  unpvt.name , unpvt.value,IIF(lt.link IS NULL,'Black','Blue') Color, lt.link [Link],lt.[Red],'<font color = ' + IIF(lt.link IS NULL,'Black','Blue') + '>' + IIF(lt.link IS NOT NULL,CONCAT('<HRef="',lt.link,'"><U>'),'') + unpvt.value + IIF(lt.link IS NOT NULL,'</U></A>','') + '</font>' + IIF(lt.Red IS NOT NULL,'<font color = red><B>' + lt.Red + '</B></font>','')[HTML]
    FROM    ( SELECT    ISNULL(Instance, '') Instance ,
                        ISNULL(SQLAccount, '') SQLAccount ,
                        ISNULL(SQLAgentAccount, '') SQLAgentAccount ,
                        ISNULL(AuthenticationnMode, '') AuthenticationnMode ,
                        ISNULL(Edition, '') Edition ,
                        ISNULL(@Collation, '') Collation 
              FROM      Client.[MachineSettings]
              WHERE     guid = @guid
            ) p UNPIVOT
	( value FOR name IN ( Instance,SQLAccount, SQLAgentAccount,AuthenticationnMode, Edition, Collation) ) AS unpvt
	LEFT JOIN @linkTable lt ON lt.name = unpvt.name AND lt.value = unpvt.value
    WHERE   unpvt.value <> ''
	UNION ALL 
	SELECT	  'Version',[Version],'Black',NULL,NULL,CONCAT('<font color =Black><B>',SUBSTRING([Version],1,CHARINDEX('-',[Version])-1),'</B>',SUBSTRING([Version],CHARINDEX('-',[Version]),len([Version])),'</font>')
	FROM      Client.[MachineSettings]
    WHERE     guid = @guid
	UNION ALL SELECT 'Full Edition by MS:',[Utility].[ufn_GetSQLServerEdition](@Ver,@Edition,@Ver),'Black' Color, NULL [Link],NULL [Red],'<font color = Black>' + @Edition + '</font>'
	UNION ALL SELECT 'Full Service Pack by MS:',[Utility].[ufn_GetSQLServerServicePack](@Ver,@ServicePack,@Ver),'Black' Color, NULL [Link],NULL [Red],'<font color = ' + IIF(@NewSP != N'',N'Red',N'Black') + N'>' + 
	CASE WHEN @ServicePack LIKE '%SP%' THEN CONCAT('Service Pack ',RIGHT(@ServicePack,1))
	ELSE @ServicePack END + IIF(@NewSP != N'',N'</font>. (There is "<B>' + @NewSP + N'</B>" out there).','</font>')
	UNION ALL SELECT 'Memory Configured:',CONCAT('(Min)',(SELECT TOP 1 CONVERT(NVARCHAR(4000),@MinServerMemory/1024) + 'GB'),'/',
	(SELECT TOP 1 IIF(@MaxServerMemory = 2147483647,@PhysicalMemory,CONVERT(NVARCHAR(MAX),@MaxServerMemory/1024)+ 'GB')),'(Max) From: ',@PhysicalMemory),
	CASE 
		WHEN @MinServerMemory = 0 THEN 'Orange'
		WHEN @MaxServerMemory = 2147483647 OR @MinServerMemory = 2147483647 OR @MinServerMemory = 0 THEN 'Red' 
		ELSE 'Black' 
	END Color, NULL [Link],NULL [Red],CONCAT('<font color =Black>(Min) </font><font color = ',
		CASE WHEN @MinServerMemory = 0 THEN 'Orange'
			 WHEN @MinServerMemory = 2147483647 THEN 'Red'
			 ELSE 'Black' 
		END,'>', CONVERT(NVARCHAR(4000),@MinServerMemory/1024) + 'GB</font><font color =Black>/</font><font color = ' + 
		CASE WHEN @MaxServerMemory = 2147483647 THEN 'Red'
			 ELSE 'Black' 
		END,'>',IIF(@MaxServerMemory = 2147483647,@PhysicalMemory,CONVERT(NVARCHAR(MAX),@MaxServerMemory/1024)+ 'GB</font><font color =Black>'),' (Max) From: ',@PhysicalMemory+ '</font>')
	UNION ALL 
	SELECT	TOP 1 'End of Life cycle Microsoft support',T.SupportEndDate,
			CASE WHEN T.SupportEndDate BETWEEN DATEADD(DAY,-365,GETDATE()) AND DATEADD(DAY,-183,GETDATE()) THEN 'Orange' 
				 WHEN T.SupportEndDate < DATEADD(DAY,-183,GETDATE()) THEN 'Red' ELSE 'Green' END Color, 'https://support.microsoft.com/lifecycle'/*'https://support.microsoft.com/en-us/lifecycle?C2=1044&forceorigin=esmc&wa=wsignin1.0'*/ [Link],NULL [Red],
			CONCAT('<font color =' + CASE WHEN T.SupportEndDate BETWEEN DATEADD(DAY,-365,GETDATE()) AND DATEADD(DAY,-183,GETDATE()) THEN 'Orange' 
				 WHEN T.SupportEndDate < DATEADD(DAY,-183,GETDATE()) THEN 'Red' ELSE 'Green' END + '><B>' + T.SupportEndDate + '</B></font>',@Comment)
	FROM	[Utility].[ufn_GetSupportEndDate](@Edition,@Ver) T
	UNION ALL 
	SELECT TOP 1 'Number of instance installed on the server',
			TRY_CONVERT(NVARCHAR(35),IIF(COUNT(1)=0,1,COUNT(1))) + 
			' installed. ' + TRY_CONVERT(NVARCHAR(35),IIF(@Running = 0 ,1,@Running)) + 
			' Active. ' ,
			CASE WHEN COUNT(1) > 1 THEN 'Orange' ELSE 'Black' END, NULL [Link],NULL [Red],
			'<font color =' + CASE WHEN COUNT(1) > 1 THEN 'Orange' ELSE 'Black' END + '>' + TRY_CONVERT(NVARCHAR(35),COUNT(1)) + 
			' installed. ' + TRY_CONVERT(NVARCHAR(35),IIF(@Running = 0 ,1,@Running)) + 
			' Active. </font>'
	FROM	Client.Registery R WHERE R.guid = @guid AND R.Service = 'SQL Server Engine'
	UNION ALL 
	SELECT	TOP 1 'Number Of Deadlocks',CONCAT(CONVERT(NVARCHAR(MAX),deadlock_monitor_serial_number),' Since - ',CONVERT(NVARCHAR(MAX),SP.sqlserver_start_time,13)), 'Black',NULL [Link],NULL [Red],
	'<font color =' + IIF(deadlock_monitor_serial_number>10,'red','black') + '> ' + CONCAT(CONVERT(NVARCHAR(MAX),deadlock_monitor_serial_number),'</font><font color =black> Since - ',CONVERT(NVARCHAR(MAX),SP.sqlserver_start_time,13)) + '</font>'
	FROM	Client.ServerProporties SP
	WHERE	SP.guid = @guid
	UNION ALL 
	SELECT	TOP 1 'SQL Server Start Time',CONVERT(NVARCHAR(MAX),SP.sqlserver_start_time,13), 'Black',NULL [Link],NULL [Red],'<font color =black>' + CONVERT(NVARCHAR(MAX),SP.sqlserver_start_time,13) + '</font>'
	FROM	Client.ServerProporties SP
	WHERE	SP.guid = @guid
	UNION ALL 
	SELECT	'Average Page Life Expectancy (PLE)',CONVERT(NVARCHAR(MAX),Utility.[ufn_ConvertTimeToHHMMSS](SP.PLE,'s')), IIF(SP.PLE < 300,'Red','Black'),NULL [Link],NULL [Red],'<font color = ' + IIF(SP.PLE < 300,'Red','Black') + '>' + CONVERT(NVARCHAR(MAX),Utility.[ufn_ConvertTimeToHHMMSS](SP.PLE,'s')) + '</font>'
	FROM	Client.ServerProporties SP
	WHERE	SP.guid = @guid
			AND SP.PLE IS NOT NULL
	UNION ALL 
	SELECT 'Volumes',NULL,'red',NULL,'Server have only one drive. Please add drive for Data, Log, TempDB and Backup files for best performance.' [Red],'<font color = red>Server have only one drive. Please add drive for Data, Log, TempDB and Backup files for best performance.</font>'
	WHERE 1= (SELECT	COUNT(*)FROM Client.Volumes V WHERE	V.guid = @guid)
	UNION ALL 	 
	SELECT	'HADR: AlwaysOn feature','Active', 'Black',NULL [Link],NULL [Red],'<font color = Black>Active</font>'
	FROM	Client.HADRServices HS
	WHERE	hs.Guid = @guid
			AND AlwaysOn = 1
	UNION ALL 
	SELECT	'HADR: Replication feature','Active', 'Black',NULL [Link],NULL [Red],'<font color = Black>Active</font>'
	FROM	Client.HADRServices HS
	WHERE	hs.Guid = @guid
			AND [Replication] = 1
	UNION ALL 
	SELECT	'HADR: LogShipping feature','Active', 'Black',NULL [Link],NULL [Red],'<font color = Black>Active</font>'
	FROM	Client.HADRServices HS
	WHERE	hs.Guid = @guid
			AND LogShipping = 1
	UNION ALL 
	SELECT	'HADR: Mirror feature','Active', 'Black',NULL [Link],NULL [Red],'<font color = Black>Active</font>'
	FROM	Client.HADRServices HS
	WHERE	hs.Guid = @guid
			AND Mirror = 1
	UNION ALL 
	SELECT	'HADR: Cluster feature','Active', 'Black',NULL [Link],NULL [Red],'<font color = Black>Active</font>'
	FROM	Client.HADRServices HS
	WHERE	hs.Guid = @guid
			AND HS.Cluster = 1
	UNION ALL 
	SELECT	B.FindingsGroup,CONCAT(B.Finding,'-',B.Details), 'Black',NULL [Link],NULL [Red],CONCAT('<font color = Black>',B.Finding,'-',B.Details,'</font>')
	FROM	Client.Blitz B
	WHERE	B.guid = @Guid
			AND B.Finding NOT IN ('High VLF Count')
			AND B.FindingsGroup NOT IN ('Wait Stats','Rundate','Server Info','Informational','Licensing','Non-Default Server Config')
			AND B.DatabaseName IS NULL
END
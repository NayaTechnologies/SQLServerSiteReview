-- =============================================
-- Author:		Sharon
-- Create date: 11/06/2016
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [GUI].[usp_GetSettingConfiguration] @guid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE @hyperthreadingRatio BIT;
	DECLARE @logicalCPUs INT;
	DECLARE @HTEnabled INT;
	DECLARE @physicalCPU INT;
	DECLARE @SOCKET INT;
	DECLARE @logicalCPUPerNuma INT;
	DECLARE @NoOfNUMA INT;
	DECLARE @MaxDOP INT;
	DECLARE @CurentMaxDOP INT;
	DECLARE @PhysicalMemory INT ;
	DECLARE @OSBit INT;
	
	-- find NO OF NUMA Nodes 
	SELECT  @NoOfNUMA = COUNT(DISTINCT OS.parent_node_id)
	FROM    Client.os_schedulers OS
	WHERE	OS.guid = @Guid
			AND OS.status = 'VISIBLE ONLINE'
			AND OS.parent_node_id < 64;

	SELECT  @logicalCPUs = SP.logicalCPU -- [Logical CPU Count]
			,@hyperthreadingRatio = hyperthread_ratio --  [Hyperthread Ratio]
			,@physicalCPU = SP.CPU_Core -- [Physical CPU Count]
			,@HTEnabled = CASE WHEN SP.logicalCPU > hyperthread_ratio THEN 1
							  ELSE 0
						END -- HTEnabled
			,@OSBit = SP.OS_bit
	FROM    [Client].[ServerProporties] SP
	WHERE	SP.guid = @Guid;

	SELECT  @logicalCPUPerNuma = COUNT(OS.parent_node_id) -- [NumberOfLogicalProcessorsPerNuma]
	FROM    Client.os_schedulers OS
	WHERE	OS.guid = @Guid
			AND OS.[status] = 'VISIBLE ONLINE'
			AND OS.parent_node_id < 64
	GROUP BY OS.parent_node_id;

	IF NOT EXISTS (SELECT TOP 1 1 FROM Client.Software S WHERE S.guid = @guid AND S.Status = 1)
	BEGIN
		IF @NoOfNUMA = 1
		BEGIN
			   IF @logicalCPUPerNuma > 8 
			   BEGIN
				   IF EXISTS(SELECT TOP 1 1 FROM sys.dm_os_sys_info OS WHERE OS.virtual_machine_type = 1) --Virtual
					  BEGIN
							 SET @NoOfNUMA = 2;
							 --PRINT 'On this VM "Hot Plug" is enabled';
							 SET @MaxDOP = 8;
					  END
			   END
			   ELSE 
			   BEGIN
				   SET @MaxDOP = @logicalCPUPerNuma;
			   END
		END
		ELSE
		BEGIN
			   IF @logicalCPUPerNuma > 8 
			   BEGIN
				   SET @MaxDOP = 8;
			   END
			   ELSE 
			   BEGIN
				   SET @MaxDOP = @logicalCPUPerNuma; 
			   END
		END
	END
	ELSE
    BEGIN
        SET @MaxDOP = 1;
    END

--https://support.microsoft.com/en-us/kb/2806535
--https://www.brentozar.com/archive/2014/11/many-cpus-parallel-query-using-sql-server/
--https://www.littlekendra.com/2016/07/14/max-degree-of-parallelism-cost-threshold-for-parallelism/
--https://blogs.msdn.microsoft.com/sqlsakthi/p/maxdop-calculator-sqlserver/


DECLARE @Ver NVARCHAR(128)
	SELECT	TOP 1 @PhysicalMemory = CONVERT(INT,ROUND(TRY_CONVERT(BIGINT,LEFT(ISNULL(PhysicalMemory, ''),
                             CHARINDEX(' ', PhysicalMemory) - 1)),0)),
			@Ver = LEFT(PARSENAME(CONVERT(VARCHAR(32), ISNULL(ProductVersion,Utility.ufn_Util_clr_RegexReplace(Version,'([\W\w]*)\- ([\d]+\.[\d]+\.[\d]+\.[\d]+)[\W\w]*','$2',0))), 4)
 + PARSENAME(CONVERT(VARCHAR(32), ISNULL(ProductVersion,Utility.ufn_Util_clr_RegexReplace(Version,'([\W\w]*)\- ([\d]+\.[\d]+\.[\d]+\.[\d]+)[\W\w]*','$2',0))), 3),3)
	FROM	[Client].[MachineSettings]
    WHERE     guid = @guid;
	
	SELECT @PhysicalMemory = CASE 
	WHEN @PhysicalMemory <= 8000 THEN 6000
	ELSE @PhysicalMemory * 0.9 END
	--5120 0.9
	DECLARE @Ignore TABLE(name sysname NOT NULL);
	INSERT @Ignore
	VALUES  ( 'max worker threads'),('show advanced options'),('cost threshold for parallelism'),('max degree of parallelism');

	IF EXISTS(SELECT TOP 1 1 FROM Client.MachineSettings MS WHERE MS.Edition LIKE '%Express Edition%' AND MS.guid = @guid)
	BEGIN
	    INSERT @Ignore VALUES ('Agent XPs');
	END
    SELECT  cSP.[name] ,
            cSP.[value] value ,
            c.[Default] ,
            CASE WHEN cSP.[name] = 'max server memory (MB)' THEN @PhysicalMemory
			WHEN cSP.[name] = 'min server memory (MB)' THEN CONVERT(INT,@PhysicalMemory * 0.8)
			ELSE c.BestPractice END BestPractice,
            c.BedPractice BadPractice,
			c.[Link],
			IIF(c.[Link] IS NOT NULL,'Blue','Black')[Color]
    FROM    [Client].[spconfigure] cSP
            INNER JOIN [Configuration].[sp_configurations] c ON cSP.name LIKE c.Name + '%' 
                                                            AND ( ISNULL(c.BestPractice,c.[Default]) != c.[Default]
                                                            --OR c.BedPractice IS NOT NULL
                                                            )
                                                            AND ( cSP.value != ISNULL(c.BestPractice,cSP.value)
                                                            OR cSP.value = ISNULL(c.BedPractice,-1)
                                                            )
    WHERE   cSP.guid = @guid
            AND cSP.name NOT IN ( 'max worker threads','show advanced options','cost threshold for parallelism','max degree of parallelism')
	UNION ALL 
	SELECT  'min = max server memory (MB)' [name] ,
            cSP.[value] value ,
            0 [Default] ,
            CONVERT(INT,@PhysicalMemory * 0.8) BestPractice,
            cSP.[value],
			NULL [Link],
			'Black' [Color]
    FROM    [Client].[spconfigure] cSP
			CROSS APPLY (SELECT value FROM [Client].[spconfigure] IC WHERE IC.guid = @guid AND IC.name = 'max server memory (MB)')MI
	WHERE   cSP.guid = @guid
			AND cSP.name = 'min server memory (MB)'
			AND MI.value = cSP.value
	UNION ALL
	SELECT  cSP.[name] ,
            cSP.[value]  ,
            c.[Default] ,
            c.BestPractice,
            c.BedPractice BadPractice,
			c.[Link],
			IIF(c.[Link] IS NOT NULL,'Blue','Black')[Color]
    FROM    [Client].[spconfigure] cSP
            INNER JOIN [Configuration].[sp_configurations] c ON cSP.name LIKE c.Name + '%' 
                                                            AND ( ISNULL(c.BestPractice,c.[Default]) != c.[Default]
                                                            --OR c.BedPractice IS NOT NULL
                                                            )
                                                            AND ( cSP.value != ISNULL(c.BestPractice,cSP.value)
                                                            OR cSP.value = ISNULL(c.BedPractice,-1)
                                                            )
    WHERE   cSP.guid = @guid
            AND cSP.name = 'cost threshold for parallelism'
			AND cSP.value <= 5
	UNION ALL 
	SELECT  cSP.name [name] ,
            cSP.[value] value ,
            0 [Default] ,
            @MaxDOP BestPractice,
            cSP.[value],
			ISNULL(ca.Link,'https://support.microsoft.com/en-us/kb/2806535')[Link],
			'Blue'[Color]
    FROM    [Client].[spconfigure] cSP
			OUTER APPLY (SELECT TOP 1 'https://msdn.microsoft.com/en-us/library/dd979074(v=crm.6).aspx' [Link] FROM Client.Software S WHERE S.guid = @guid AND S.Software = 'CRMDynamics' AND S.Status = 1)ca
	WHERE   cSP.guid = @guid
			AND cSP.name = 'max degree of parallelism'
			AND @MaxDOP != cSP.value
	UNION ALL 
	SELECT  cSP.name [name] ,
            cSP.[value] value ,
            0 [Default] ,
            T.Recco BestPractice,
            cSP.[value],
			CONCAT('https://msdn.microsoft.com/en-us/library/ms190219(v=sql.',IIF(@Ver>'105',@Ver,'110'),').aspx')[Link],
			'Blue'[Color]
    FROM    [Client].[spconfigure] cSP
			CROSS APPLY (SELECT TOP 1 IIF(@OSBit = 64,[64],[32])Recco FROM [Configuration].[MaxWorkerThread] WHERE @logicalCPUs > LogicalCPU_From AND @logicalCPUs <= LogicalCPU_Till)T
	WHERE   cSP.guid = @guid
			AND cSP.name = 'max worker threads'
			AND 0 = cSP.value
END
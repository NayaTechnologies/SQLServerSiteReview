/*
 =============================================
 Author:			Sharon Rimer
 M@il:				sharonr@naya-tech.co.il
 Create date:		1/1/2016
 Update date: 
 Description:	
 Input Parameters:  @Client						: Haeder Name for your report.
					@Allow_Weak_Password_Check	: If checked password will collect to find Weak passwords.
					@debug						: Show proccess output messages on screen.
					@Display					: To show output into screen.
					@Mask						: will scramble IP and Server name before sending.
 ============================================================================
DISCLAIMER: 
	This code and information are provided "AS IS" without warranty of any kind,
	either expressed or implied, including but not limited to the implied 
	warranties or merchantability and/or fitness for a particular purpose.
 ============================================================================
LICENSE: 
	This script is free to download and use for personal, educational, 
	and internal corporate purposes, provided that this header is preserved. 
	Redistribution or sale of this script, in whole or in part, is 
	prohibited without the author's express written consent.
 ============================================================================
 TODO:
	Suport for SQL Server 2017
 ============================================================================*/
ALTER PROCEDURE [dbo].[sp_SiteReview] ( @Client NVARCHAR(255) = N'General Client',@Allow_Weak_Password_Check BIT = 0,@debug BIT = 0,@Display BIT = 0,@Mask BIT = 1,@Help BIT = 0)
AS
BEGIN
	SET NOCOUNT ON;
	SET FMTONLY OFF;
	SET ANSI_WARNINGS ON;
	SET ANSI_PADDING ON;
	SET ANSI_NULLS ON;
	SET ARITHABORT ON;
	SET QUOTED_IDENTIFIER ON;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	DECLARE @ClientVersion NVARCHAR(15);
	DECLARE @ThankYou NVARCHAR(4000);
	DECLARE @Print NVARCHAR(4000);
	SET @ClientVersion = '1.500';
	SET @ThankYou = 'Thank you for using this our SQL Server Site Review.
--------------------------------------------------------------------------------
Find out more in our site - www.NAYA-Technologies.com
--------------------------------------------------------------------------------
@ClientVersion				:' + @ClientVersion;
	IF @Help = 1
	BEGIN
		SET	 @Print = @ThankYou + '
@ClientVersion				:' + @ClientVersion + '
Input Parameters:
--------------------------------------------------------------------------------
@Client						: Haeder Name for your report.
@Allow_Weak_Password_Check	: If checked password will collect to find Weak passwords.
@debug						: Show proccess output messages on screen.
@Display					: To show output into screen.
@Mask						: will scramble IP and Server name before sending.
		';
		PRINT @Print;
		RETURN;
	END
	RAISERROR (@ThankYou,0,1) WITH NOWAIT;
	IF @debug = 1 RAISERROR ('*** @debug Mode is ON ***',0,1) WITH NOWAIT;
	
	DECLARE @DebugStartTime DATETIME;
	DECLARE @TotalStartTime DATETIME;
	DECLARE @DebugError TABLE ([Subject] sysname,Error NVARCHAR(2048) NULL,[Duration] BIGINT NULL);
	
	IF OBJECT_ID('master.dbo.SiteReview') IS NOT NULL DROP TABLE master.dbo.SiteReview;
	CREATE TABLE master.dbo.SiteReview ( Col XML) ;
	DECLARE @LogPath VARCHAR(2000);
	SELECT @LogPath = CONVERT(VARCHAR(2000),SERVERPROPERTY('ErrorLogFileName'))

	SELECT @LogPath = SUBSTRING (@LogPath,CHARINDEX('''',@LogPath)+1, LEN(@LogPath)+1 - CHARINDEX('''',@LogPath)-CHARINDEX('\',REVERSE(@LogPath)))
    DECLARE @showadvanced INT ,
			@cmdshell INT, 
			@olea INT;
	DECLARE @PS VARCHAR(4000);
	DECLARE @Command VARCHAR(4000);
	DECLARE @ErrorLog VARCHAR(2048);
	DECLARE @Filename VARCHAR(1000);
	DECLARE @FilePath VARCHAR(1000);	
	DECLARE @cmd NVARCHAR(MAX);
    SELECT  @showadvanced = 0 ,
            @cmdshell = 0,
			@olea = 0;
    IF EXISTS ( SELECT TOP 1 1 FROM sys.configurations C WHERE C.name = 'show advanced options' AND C.value = 0 )
    BEGIN
		IF @debug = 1 RAISERROR ('Turn on "show advanced options"',0,1) WITH NOWAIT;
        EXEC sp_configure 'show advanced options', 1;
        RECONFIGURE WITH OVERRIDE;
		SET @showadvanced = 1;
    END;
    IF EXISTS ( SELECT TOP 1 1 FROM sys.configurations C WHERE   C.name = 'xp_cmdshell' AND C.value = 0 )
    BEGIN
		IF @debug = 1 RAISERROR ('Turn on "xp_cmdshell"',0,1) WITH NOWAIT;
        EXEC sp_configure 'xp_cmdshell', 1;
        RECONFIGURE WITH OVERRIDE;
		SET @cmdshell = 1;
	
    END;
    

        DECLARE @MajorVersion INT;
        IF OBJECT_ID('tempdb..#checkversion') IS NOT NULL DROP TABLE #checkversion;
        CREATE TABLE #checkversion
            (
                version NVARCHAR(128) ,
                common_version AS SUBSTRING(version, 1,
                                            CHARINDEX('.', version) + 1) ,
                major AS PARSENAME(CONVERT(VARCHAR(32), version), 4) ,
                minor AS PARSENAME(CONVERT(VARCHAR(32), version), 3) ,
                build AS PARSENAME(CONVERT(VARCHAR(32), version), 2) ,
                revision AS PARSENAME(CONVERT(VARCHAR(32), version), 1)
            );
        INSERT  INTO #checkversion ( version ) SELECT  CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128));
        SELECT  @MajorVersion = major + CASE WHEN minor = 0 THEN '00' ELSE minor end
        FROM    #checkversion
        OPTION  ( RECOMPILE );
	
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		-- Get VLF Counts for all databases on the instance (VLF Counts)
		IF @debug = 1 RAISERROR ('Collect VLF Counts for all databases on the instance (VLF Counts)',0,1) WITH NOWAIT;
        IF OBJECT_ID('tempdb..#VLFInfo2008') IS NOT NULL DROP TABLE #VLFInfo2008;
        CREATE TABLE #VLFInfo2008
            (
                FileID INT ,
                FileSize BIGINT ,
                StartOffset BIGINT ,
                FSeqNo BIGINT ,
                Status BIGINT ,
                Parity BIGINT ,
                CreateLSN NUMERIC(38)
            );
	
        IF OBJECT_ID('tempdb..#VLFInfo') IS NOT NULL DROP TABLE #VLFInfo;
        CREATE TABLE #VLFInfo
            (
                RecoveryUnitID INT ,
                FileID INT ,
                FileSize BIGINT ,
                StartOffset BIGINT ,
                FSeqNo BIGINT ,
                Status BIGINT ,
                Parity BIGINT ,
                CreateLSN NUMERIC(38)
            );

        IF OBJECT_ID('tempdb..#VLFCountResults') IS NOT NULL DROP TABLE #VLFCountResults;
        CREATE TABLE #VLFCountResults
            (
                DatabaseName sysname COLLATE DATABASE_DEFAULT ,
                VLFCount INT
            );

        IF @MajorVersion > 1050
            BEGIN
                EXEC sp_MSforeachdb N'Use [?]; 
INSERT INTO #VLFInfo 
EXEC sp_executesql N''DBCC LOGINFO([?]) WITH NO_INFOMSGS''; 
	 
INSERT INTO #VLFCountResults 
SELECT DB_NAME(), COUNT(*) 
FROM #VLFInfo
OPTION(RECOMPILE); 
TRUNCATE TABLE #VLFInfo;';
            END;
        ELSE
            BEGIN
	    
                EXEC sp_MSforeachdb N'Use [?]; 
INSERT INTO #VLFInfo2008
EXEC sp_executesql N''DBCC LOGINFO([?]) WITH NO_INFOMSGS''; 
	 
INSERT INTO #VLFCountResults 
SELECT DB_NAME(), COUNT(*) 
FROM #VLFInfo2008
OPTION(RECOMPILE); 
TRUNCATE TABLE #VLFInfo;';
            END;
		INSERT @DebugError VALUES  ('VLF Counts',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('VLF Counts',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------
			/*
BizTalk:https://blogs.msdn.microsoft.com/blogdoezequiel/2009/01/25/sql-best-practices-for-biztalk/
Auto create statistics must be disabled
Auto update statistics must be disabled
MAXDOP (Max degree of parallelism) must be defined as 1 in both SQL Server 2000 and SQL Server 2005 in the instance in which BizTalkMsgBoxDB database exists
*/

	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Software',0,1) WITH NOWAIT;
		DECLARE @DB_Exclude TABLE
		(DatabaseName sysname);
		DECLARE @DB_tfs TABLE
		(DatabaseName sysname);
		--CRM Dynamics
		INSERT @DB_Exclude
		SELECT D.name
		FROM   sys.databases D
		WHERE  D.name IN ('MSCRM_CONFIG','OrganizationName_MSCRM')
        OPTION  ( RECOMPILE );
		DECLARE @IsCRMDynamicsON BIT = 0;
		DECLARE @IsBizTalkON BIT = 0;
		DECLARE @IsSharePointON BIT = 0;
		DECLARE @IsTFSON BIT = 0;
		SELECT TOP 1 @IsCRMDynamicsON = 1 
		FROM   sys.server_principals SP
		WHERE  SP.name = 'MSCRMSqlLogin'
		IF @IsCRMDynamicsON = 0 
		   SELECT TOP 1 @IsCRMDynamicsON = 1
		   FROM   @DB_Exclude
        OPTION  ( RECOMPILE );
		DELETE FROM @DB_Exclude
        OPTION  ( RECOMPILE );
		--BizTalk
		SELECT @IsBizTalkON = 1 
		WHERE EXISTS (
		SELECT TOP 1 1
		FROM   sys.databases D
		WHERE  D.name IN (N'BizTalkMsgBoxDB',N'BizTalkRuleEngineDb',N'SSODB',N'BizTalkHWSDb',N'BizTalkEDIDb',N'BAMArchive',N'BAMStarSchema',N'BAMPrimaryImport',N'BizTalkMgmtDb',N'BizTalkAnalysisDb',N'BizTalkTPMDb')
		) OPTION  ( RECOMPILE );
		--SharePoint
		INSERT @DB_Exclude
		EXEC sp_MSforeachdb 'SELECT TOP 1 ''?'' [DatabaseName]
FROM   [?].sys.database_principals DP
WHERE  DP.type = ''R'' AND DP.name IN (N''SPDataAccess'',N''SPReadOnly'')
OPTION  ( RECOMPILE );'
		SELECT @IsSharePointON = 1 
		WHERE EXISTS (SELECT TOP 1 1 FROM @DB_Exclude);
		
		--Team Foundation Server Databases(TFS)
		IF DB_ID('Tfs_Configuration') IS NOT NULL
		BEGIN
			INSERT  @DB_tfs
			EXEC sp_MSforeachdb 'SELECT TOP 1 ''?''[DatabaseName]
FROM   [?].sys.database_principals DP
WHERE  DP.type = ''R'' AND DP.name = ''TfsWarehouseDataReader''
OPTION  ( RECOMPILE );'

			INSERT  @DB_tfs
			SELECT	CR.[DisplayName]
			FROM	[Tfs_Configuration].[dbo].[tbl_CatalogResource] CR
					INNER JOIN [Tfs_Configuration].[dbo].[tbl_CatalogResourceType] RC ON RC.Identifier = CR.ResourceType
			WHERE	RC.DisplayName = 'Team Foundation Project Collection Database'
					AND CR.[DisplayName] NOT IN(SELECT DatabaseName FROM @DB_tfs)
			UNION	SELECT name FROM sys.databases WHERE [name] IN ('TFS_Configuration','TFS_Warehouse','TFS_Analysis') AND state = 0 AND name NOT IN(SELECT DatabaseName FROM @DB_tfs)
			OPTION  ( RECOMPILE );
		END
		-----------------
		SELECT 'SharePoint' [Software] ,@IsSharePointON [Status]
		INTO	#SR_Software
		UNION ALL SELECT 'BizTalk' [Software] ,@IsBizTalkON [Status]
		UNION ALL SELECT 'CRMDynamics' [Software] ,@IsCRMDynamicsON [Status]
		UNION ALL SELECT 'TFS' [Software] ,@IsTFSON [Status]
        OPTION  ( RECOMPILE );

		INSERT @DebugError VALUES  ('Collect Software',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Collect Software',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------------------------------------------------------------------------------------------------

	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		DECLARE @IndexSize TABLE(DatabaseName sysname NOT NULL, IndexIssue NVARCHAR(MAX) NOT NULL);

		INSERT @IndexSize EXEC sp_MSforeachdb N'USE [?]; 
SELECT  ''[?]'' [name],
              ''Index '' + i.name  + '' on '' + S.name + ''.'' + t.name + '' is '' + convert(varchar(25),ls.LengthSizeInByte) + '' byte. The maximum index size for this version in 900 byte'' [msg]
FROM    sys.tables t
        INNER JOIN sys.schemas S ON S.schema_id = t.schema_id
        INNER JOIN sys.indexes i ON t.object_id = i.object_id
        CROSS APPLY (SELECT  TOP 1  SUM(c.max_length) LengthSizeInByte
                    FROM  sys.index_columns ic
                          INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                    WHERE ic.object_id = i.object_id
                                AND ic.index_id = i.index_id
                                AND ic.is_included_column = 0) ls
		CROSS APPLY (SELECT 1 [Ex] FROM sys.databases WHERE name = DB_NAME() AND compatibility_level < 130)DB
WHERE   i.type > 0
        AND S.name != ''sys''
        AND DB_NAME() NOT IN (''ReportServer'')
        AND ls.LengthSizeInByte > 900
OPTION  ( RECOMPILE );';
		INSERT @DebugError VALUES  ('Index Size',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Index Size',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect database',0,1) WITH NOWAIT;
        SELECT  D.name ,
                D.database_id ,
                D.source_database_id ,
                CONVERT(NVARCHAR(MAX), D.owner_sid,1) owner_sid ,
                D.create_date ,
                D.compatibility_level ,
                D.collation_name ,
                D.user_access ,
                D.user_access_desc ,
                D.is_read_only ,
                D.is_auto_close_on ,
                D.is_auto_shrink_on ,
                D.state ,
                D.state_desc ,
                D.is_in_standby ,
                D.is_cleanly_shutdown ,
                D.is_supplemental_logging_enabled ,
                D.snapshot_isolation_state ,
                D.snapshot_isolation_state_desc ,
                D.is_read_committed_snapshot_on ,
                D.recovery_model ,
                D.recovery_model_desc ,
                D.page_verify_option ,
                D.page_verify_option_desc ,
                D.is_auto_create_stats_on ,
                --D.is_auto_create_stats_incremental_on ,
                D.is_auto_update_stats_on ,
                D.is_auto_update_stats_async_on ,
                D.is_ansi_null_default_on ,
                D.is_ansi_nulls_on ,
                D.is_ansi_padding_on ,
                D.is_ansi_warnings_on ,
                D.is_arithabort_on ,
                D.is_concat_null_yields_null_on ,
                D.is_numeric_roundabort_on ,
                D.is_quoted_identifier_on ,
                D.is_recursive_triggers_on ,
                D.is_cursor_close_on_commit_on ,
                D.is_local_cursor_default ,
                D.is_fulltext_enabled ,
                D.is_trustworthy_on ,
                D.is_db_chaining_on ,
                D.is_parameterization_forced ,
                D.is_published ,
                D.is_subscribed ,
                D.is_merge_published ,
                D.is_distributor ,
                D.is_broker_enabled ,
                D.log_reuse_wait ,
                D.log_reuse_wait_desc ,
                D.is_cdc_enabled ,
                VL.VLFCount ,
                DF.NumberOfDataFiles ,
                LF.NumberOfLogFiles,
				CASE WHEN D.name IN ('BizTalkMsgBoxDB','BizTalkRuleEngineDb','SSODB','BizTalkHWSDb','BizTalkEDIDb','BAMArchive','BAMStarSchema','BAMPrimaryImport','BizTalkMgmtDb','BizTalkAnalysisDb','BizTalkTPMDb') THEN 1 ELSE 0 END [IsBizTalk],
				CASE WHEN D.name IN ('MSCRM_CONFIG','OrganizationName_MSCRM') THEN 1 ELSE 0 END [IsCRMDynamics],
				CASE WHEN D.name IN (SELECT DatabaseName FROM @DB_Exclude) THEN 1 ELSE 0 END [IsSharePoint],
				CASE WHEN D.name IN (SELECT DatabaseName FROM @DB_tfs) THEN 1 ELSE 0 END [IsTFS]
        INTO    #SR_Databases
        FROM    sys.databases D
                INNER JOIN #VLFCountResults VL ON VL.DatabaseName COLLATE DATABASE_DEFAULT = D.name
                OUTER APPLY ( SELECT    COUNT(1) NumberOfDataFiles
                                FROM      sys.master_files MF
                                WHERE     MF.database_id = D.database_id
                                        AND MF.type = 0
                            ) DF
                OUTER APPLY ( SELECT    COUNT(1) NumberOfLogFiles
                                FROM      sys.master_files MF
                                WHERE     MF.database_id = D.database_id
                                        AND MF.type = 1
                            ) LF
        WHERE   D.state = 0
        OPTION  ( RECOMPILE );

        DROP TABLE #VLFInfo;
        DROP TABLE #VLFCountResults;
		INSERT @DebugError VALUES  ('Collect database',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Collect database',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-------------------------------------------------------------------------------------------------------- 
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect System Info',0,1) WITH NOWAIT;
        DECLARE @output TABLE ( line VARCHAR(255) );
		DECLARE @sql VARCHAR(4000);
		CREATE TABLE #SR_KB
		( 
			KBID VARCHAR(255)
		) 
		--cleanUP
        DELETE  FROM @output;
		DECLARE @OSName NVARCHAR(1000);

		--systeminfo - For OS & KB
        SET @sql = 'systeminfo';
	
        INSERT  @output EXEC xp_cmdshell @sql;

		SELECT	@OSName = LTRIM(REPLACE(O.line,'OS Name:',''))
		FROM	@output O
		WHERE	O.line LIKE '%OS Name:%';

		INSERT	#SR_KB
		SELECT	SUBSTRING(O.line,CHARINDEX(':',O.line) + 2,LEN(O.line))--''
		FROM	@output O
		WHERE	O.line LIKE '%KB%';
		INSERT @DebugError VALUES  ('System Info',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('System Info',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Server Proporties',0,1) WITH NOWAIT;
        DECLARE @PhysicalMemory INT ,
				@VirtualMemory INT ,
				@Committed INT ,
				@CommittedTarget INT ,
				@VisibleTarget INT;
        IF @MajorVersion > 1050
            EXEC sp_executesql N'
SELECT	@PhysicalMemory = physical_memory_kb/1024 ,--MB
		@VirtualMemory = virtual_memory_kb/1024 ,
		@Committed = committed_kb/1024 ,
		@CommittedTarget = committed_target_kb/1024 ,
		@VisibleTarget = visible_target_kb/1024
FROM	sys.dm_os_sys_info WITH (NOLOCK)
OPTION(RECOMPILE);', N'@PhysicalMemory INT OUTPUT,
		@VirtualMemory INT OUTPUT,
		@Committed INT OUTPUT,
		@CommittedTarget INT OUTPUT,
		@VisibleTarget INT OUTPUT',
                @PhysicalMemory = @PhysicalMemory OUTPUT,
                @VirtualMemory = @VirtualMemory OUTPUT,
                @Committed = @Committed OUTPUT,
                @CommittedTarget = @CommittedTarget OUTPUT,
                @VisibleTarget = @VisibleTarget OUTPUT;
        ELSE
            EXEC sp_executesql N'
SELECT	@PhysicalMemory = physical_memory_in_bytes/1024/1024 ,--MB
		@VirtualMemory = virtual_memory_in_bytes/1024/1024
FROM	sys.dm_os_sys_info WITH (NOLOCK)
OPTION(RECOMPILE);', N'@PhysicalMemory INT OUTPUT,
		@VirtualMemory INT OUTPUT',
                @PhysicalMemory = @PhysicalMemory OUTPUT,
                @VirtualMemory = @VirtualMemory OUTPUT;

        DECLARE @OS_Mem FLOAT ,
				@ThreadStack INT ,
				@vCPU INT ,
				@VMOverhead INT;

        IF OBJECT_ID('tempdb..#_XPMSVER') IS NOT NULL DROP TABLE #_XPMSVER;
        CREATE TABLE #_XPMSVER
            (
                IDX INT NULL ,
                NAME VARCHAR(100) COLLATE DATABASE_DEFAULT NULL ,
                INT_VALUE FLOAT NULL ,
                C_VALUE VARCHAR(128) COLLATE DATABASE_DEFAULT NULL
            );
        INSERT  INTO #_XPMSVER EXEC ( 'master.dbo.xp_msver' );

        DECLARE @PlatformType INT;
        SELECT  @PlatformType = CASE WHEN C_VALUE LIKE '%x86%' THEN 1
                                        WHEN C_VALUE LIKE '%x64%' THEN 2
                                        WHEN C_VALUE LIKE '%IA64%' THEN 4
                                END
        FROM    #_XPMSVER
        WHERE   NAME = 'Platform'
        OPTION  ( RECOMPILE );

        IF OBJECT_ID('tempdb..#SR_ServerProporties') IS NOT NULL DROP TABLE #SR_ServerProporties;
        SELECT  cpu_count logicalCPU ,--@logicalCPU
                cpu_count / hyperthread_ratio CPU_Core ,
                hyperthread_ratio ,
                @PhysicalMemory PhysicalMemory ,
                @VirtualMemory VirtualMemory ,
                @Committed Committed ,
                @CommittedTarget CommittedTarget ,
                -@VisibleTarget VisibleTarget ,
                os_quantum ,
                os_error_mode ,
                os_priority_class ,
                max_workers_count ,
                scheduler_count ,
                scheduler_total_count ,
                deadlock_monitor_serial_number ,
                sqlserver_start_time ,
                affinity_type ,
                --virtual_machine_type , ONLY > 2008R2
                CASE WHEN @@Version LIKE '%64-bit%' THEN 64
                        ELSE 32
                END OS_bit ,
                @PlatformType PlatformType ,
                max_workers_count * @PlatformType [ThreadStack] ,
                ( cpu_count / hyperthread_ratio ) / 4.0 [OS_Mem],
				@OSName OSName
        INTO    #SR_ServerProporties
        FROM    sys.dm_os_sys_info
        OPTION  ( RECOMPILE );
		INSERT @DebugError VALUES  ('Server Proporties',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Server Proporties',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-----------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect System Configuration',0,1) WITH NOWAIT;
        IF OBJECT_ID('tempdb..#SR_Configuration') IS NOT NULL DROP TABLE #SR_Configuration;

        SELECT  name ,value
        INTO    #SR_Configuration
        FROM    sys.configurations
        OPTION  ( RECOMPILE );
		INSERT @DebugError VALUES  ('System Configuration',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('System Configuration',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-----------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Page Life Expectancy(60s)',0,1) WITH NOWAIT;

        DECLARE @counter INT; --This will be used to iterate the sampling loop for the PLE measure. 
        SET @counter = 0; 
        CREATE TABLE #pleSample
            (
                CaptureTime DATETIME ,
                PageLifeExpectancy BIGINT
            ); 
		CREATE TABLE #WaitStats
            (
                [counter] INT ,
                [Wait_type] sysname,
				[Wait_time] BIGINT
            ); 
        WHILE @counter < 30 --Sampling will run approximately 1 minute. 
        BEGIN 
--Captures Page Life Expectancy from sys.dm_os_performance_counters 
            INSERT  INTO #pleSample
                    ( CaptureTime ,
                        PageLifeExpectancy 
 				    )
                    SELECT  CURRENT_TIMESTAMP ,
                            cntr_value
                    FROM    sys.dm_os_performance_counters
                    WHERE   object_name = N'SQLServer:Buffer Manager'
                            AND counter_name = N'Page life expectancy'
            OPTION  ( RECOMPILE );

			INSERT INTO  #WaitStats
			SELECT	TOP 100
					@counter,
                    [Wait_type] = wait_type ,
                    [Wait_time] = wait_time_ms / 1000
            FROM    sys.dm_os_wait_stats
            WHERE   [wait_type] NOT IN ( N'CLR_SEMAPHORE',
                                    N'LAZYWRITER_SLEEP',
                                    N'RESOURCE_QUEUE',
                                    N'SQLTRACE_BUFFER_FLUSH',
                                    N'SLEEP_TASK',
                                    N'SLEEP_SYSTEMTASK', N'WAITFOR',
                                    N'HADR_FILESTREAM_IOMGR_IOCOMPLETION',
                                    N'CHECKPOINT_QUEUE',
                                    N'REQUEST_FOR_DEADLOCK_SEARCH',
                                    N'XE_TIMER_EVENT',
                                    N'XE_DISPATCHER_JOIN',
                                    N'LOGMGR_QUEUE',
                                    N'FT_IFTS_SCHEDULER_idLE_WAIT',
                                    N'BROKER_TASK_STOP',
                                    N'CLR_MANUAL_EVENT',
                                    N'CLR_AUTO_EVENT',
                                    N'DISPATCHER_QUEUE_SEMAPHORE',
                                    N'TRACEWRITE',
                                    N'XE_DISPATCHER_WAIT',
                                    N'BROKER_TO_FLUSH',
                                    N'BROKER_EVENTHANDLER',
                                    N'FT_IFTSHC_MUTEX',
                                    N'SQLTRACE_INCREMENTAL_FLUSH_SLEEP',
                                    N'DIRTY_PAGE_POLL',
                                    N'SP_SERVER_DIAGNOSTICS_SLEEP',
                                    N'SQLTRACE_LOCK',
                                    N'SLEEP_BPOOL_FLUSH',
                                    N'SQLTRACE_WAIT_ENTRIES',
                                    N'BROKER_TRANSMITTER',
                                    N'DBMIRRORING_CMD',
                                    N'DBMIRROR_EVENTS_QUEUE',
                                    N'ONDEMAND_TASK_QUEUE',
                                    N'BROKER_RECEIVE_WAITFOR' )
                            AND wait_time_ms > 1000
							AND (@counter = 0 OR @counter = 29)
            ORDER BY wait_time_ms DESC
			OPTION  ( RECOMPILE );
            SET @counter = @counter + 1; 
            WAITFOR DELAY '000:00:02';
        END; 
        IF OBJECT_ID('tempdb..#SR_PLE') IS NOT NULL DROP TABLE #SR_PLE;
		--This query will return the average PLE based on a 1 minute sample. 
        SELECT  AVG(PageLifeExpectancy) AS AveragePageLifeExpectancy
        INTO    #SR_PLE
        FROM    #pleSample
        OPTION  ( RECOMPILE ); 
        IF OBJECT_ID('tempdb..#pleSample') IS NOT NULL DROP TABLE #pleSample;
		
		SELECT	WS.Wait_type,WS.Wait_time - S.Wait_time [Wait_time]
		INTO	#SR_WaitStat
		FROM	#WaitStats WS
				INNER JOIN #WaitStats S ON WS.Wait_type = S.Wait_type
					AND S.[counter] = 0
		WHERE	WS.[counter] = 29
				AND WS.Wait_time - S.Wait_time > 0
        OPTION  ( RECOMPILE );
        IF OBJECT_ID('tempdb..#WaitStats') IS NOT NULL
            DROP TABLE #WaitStats;
		INSERT @DebugError VALUES  ('WaitStats',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('WaitStats',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-----------------------------------------------------------------------------------------------------------
BEGIN TRY
		SET @DebugStartTime = GETDATE();
	IF OBJECT_ID('tempdb..#SR_LoginIssue') IS NOT NULL DROP TABLE #SR_LoginIssue;
	CREATE TABLE #SR_LoginIssue
		(
		  [Weak] NVARCHAR(2000) NOT NULL
		);
	DECLARE @alg TABLE
		(
		 Algoritm NVARCHAR(10) NOT NULL ,
		  IsActive BIT
		);

		--define the crypto algoritms to check
		INSERT @alg VALUES ( 'SHA', 1 );
		INSERT @alg VALUES ( 'SHA1', 1 );
		INSERT @alg VALUES ( 'SHA2_256', 1 );
		INSERT @alg VALUES ( 'SHA2_512', 1 );

		INSERT	#SR_LoginIssue
		SELECT  'Login "' + SL.name + '" with algoritm ' + A.Algoritm + ' has very weak password.' [Weak]
		FROM    master.sys.sql_logins SL
				CROSS JOIN @alg A
				CROSS APPLY (SELECT SUBSTRING(SL.password_hash, 0, 3) Header ,CONVERT(VARBINARY(4), SUBSTRING(CONVERT(NVARCHAR(MAX), password_hash),2, 2)) Salt)iSL
				CROSS APPLY ( SELECT    iSL.Header + iSL.Salt + HASHBYTES(A.Algoritm,SL.name+ CONVERT(NVARCHAR(MAX), iSL.Salt)) MyHashedPassword) Pass
		WHERE   SL.name NOT IN ( '##MS_PolicyEventProcessingLogin##',
								 '##MS_PolicyTsqlExecutionLogin##',
								 '##MS_SSISServerCleanupJobLogin##' )
				AND Pass.MyHashedPassword = SL.password_hash
			    AND SL.is_disabled = 0
	    OPTION  ( RECOMPILE );
		INSERT @DebugError VALUES  ('Login Issue',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Login Issue',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-----------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
	--Collect sql logins data(Alert Weak Password)
        IF OBJECT_ID('tempdb..#SR_login') IS NOT NULL
            DROP TABLE #SR_login;
		CREATE TABLE #SR_login([Name] sysname,Header VARCHAR(6),[Salt] NVARCHAR(MAX),[password_hash] NVARCHAR(MAX));

		IF @Allow_Weak_Password_Check = 1
		BEGIN
		    IF @debug = 1 RAISERROR ('Collect Logins',0,1) WITH NOWAIT;
		
			INSERT	#SR_login
			SELECT  name COLLATE DATABASE_DEFAULT [Name] ,
					CONVERT(NVARCHAR(6),SUBSTRING([password_hash], 0, 3),1) Header ,
					CONVERT(NVARCHAR(MAX), CONVERT(VARBINARY(4), SUBSTRING([password_hash_str], 2, 2)),1) Salt ,
					[password_hash_full_str] password_hash
			FROM    sys.sql_logins WITH ( NOLOCK )
					CROSS APPLY (SELECT TOP 1 CONVERT(NVARCHAR(MAX), password_hash,1) [password_hash_full_str],CONVERT(NVARCHAR(MAX), password_hash) [password_hash_str])P
			WHERE	name COLLATE DATABASE_DEFAULT NOT IN ( '##MS_PolicyEventProcessingLogin##',
									 '##MS_PolicyTsqlExecutionLogin##',
									 '##MS_SSISServerCleanupJobLogin##' )
			OPTION  ( RECOMPILE );
		END
		INSERT @DebugError VALUES  ('Logins',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Logins',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-----------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		--TempDB
		IF @debug = 1 RAISERROR ('Collect Master Files',0,1) WITH NOWAIT;
        IF OBJECT_ID('tempdb..#SR_MasterFiles') IS NOT NULL
            DROP TABLE #SR_MasterFiles;
        SELECT  size ,
                file_id ,
                database_id ,
                type
        INTO    #SR_MasterFiles
        FROM    sys.master_files
		OPTION  ( RECOMPILE );
		INSERT @DebugError VALUES  ('Master Files',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Master Files',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-----------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
-- Sustained values above 10 suggest further investigation in that area
-- High Avg Task Counts are often caused by blocking or other resource contention
		IF @debug = 1 RAISERROR ('Collect OS Schedulers',0,1) WITH NOWAIT;
        IF OBJECT_ID('tempdb..#SR_os_schedulers') IS NOT NULL
            DROP TABLE #SR_os_schedulers;
        SELECT  scheduler_id ,
                current_tasks_count ,
                runnable_tasks_count ,
                pending_disk_io_count,
				status,
				parent_node_id,
				is_online,
				is_idle,
				active_workers_count
        INTO    #SR_os_schedulers
        FROM    sys.dm_os_schedulers WITH ( NOLOCK )
        OPTION  ( RECOMPILE );
		INSERT @DebugError VALUES  ('OS Schedulers',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('OS Schedulers',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-----------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Linked Servers',0,1) WITH NOWAIT;
        IF OBJECT_ID('tempdb..#SR_servers') IS NOT NULL
            DROP TABLE #SR_servers;
        SELECT  server_id ,
                name ,
                data_source ,
                is_linked
        INTO    #SR_servers
        FROM    sys.servers
        OPTION  ( RECOMPILE );

		IF @Mask = 1
		BEGIN
		    UPDATE	#SR_servers
			SET [name] = 'SQLServerMask'
			WHERE	is_linked = 0
			OPTION  ( RECOMPILE );

			UPDATE #SR_servers
			SET [name] = 'LinkedServer' + CONVERT(NVARCHAR(5),server_id)
			WHERE	is_linked = 1
			OPTION  ( RECOMPILE );
		END
		INSERT @DebugError VALUES  ('Linked Servers',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Linked Servers',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
----------------------------------------  TraceFlags  ----------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Trace Status',0,1) WITH NOWAIT;
        IF OBJECT_ID('tempdb..#SR_TraceStatus') IS NOT NULL
            DROP TABLE #SR_TraceStatus;
        CREATE TABLE #SR_TraceStatus
            (
                TraceFlag VARCHAR(10) COLLATE DATABASE_DEFAULT ,
                [status] BIT ,
                [Global] BIT ,
                [Session] BIT
            );
        INSERT  INTO #SR_TraceStatus EXEC ( 'DBCC TRACESTATUS(-1) WITH NO_INFOMSGS' );
		INSERT @DebugError VALUES  ('Trace Status',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Trace Status',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
----------------------------------------  TraceFlags  ----------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Machine Settings',0,1) WITH NOWAIT;
        IF OBJECT_ID('tempdb..#SR_MachineSettings') IS NULL
            CREATE TABLE #SR_MachineSettings
                (
                    ServerName NVARCHAR(200) ,
                    MachineName NVARCHAR(200) ,
                    Instance sysname ,
                    ProcessorCount VARCHAR(150) ,
                    ProcessorName VARCHAR(150) ,
                    PhysicalMemory VARCHAR(150) ,
                    SQLAccount VARCHAR(1000) ,
                    SQLAgentAccount VARCHAR(1000) ,
                    AuthenticationnMode VARCHAR(1000) ,
                    Version NVARCHAR(4000) ,
                    ProductVersion NVARCHAR(128) ,
                    Edition NVARCHAR(4000) ,
                    Collation NVARCHAR(500) ,
                    ProductLevel NVARCHAR(500) ,
                    SystemModel VARCHAR(40) ,
                    ServerStartTime DATETIME ,
                    InstantInitializationDisabled BIT ,
                    LockPagesInMemoryDisabled BIT,
					MaxClockSpeed INT,
					CurrentClockSpeed INT
                );

        DECLARE @SQLSVRACC VARCHAR(50); 
        DECLARE @SQLAGTACC VARCHAR(50);
        DECLARE @LOGINMODE VARCHAR(50);
        DECLARE @SystemManufacturer VARCHAR(20);
        EXEC master..xp_regread @rootkey = 'HKEY_LOCAL_MACHINE',
            @key = 'HARDWARE\DESCRIPTION\System\BIOS',
            @value_name = 'SystemManufacturer',
            @value = @SystemManufacturer OUTPUT;
  
        DECLARE @SystemModal VARCHAR(20);
        EXEC master..xp_regread @rootkey = 'HKEY_LOCAL_MACHINE',
            @key = 'HARDWARE\DESCRIPTION\System\BIOS',
            @value_name = 'SystemProductName',
            @value = @SystemModal OUTPUT;
  
        DECLARE @ProcessorNameString NVARCHAR(1024);
        EXEC master..xp_regread N'HKEY_LOCAL_MACHINE',
            N'HARDWARE\DESCRIPTION\System\CentralProcessor\0\',
            N'ProcessorNameString', @ProcessorNameString OUTPUT;
        IF OBJECT_ID('tempdb..#reg') IS NOT NULL
            EXEC ('Drop table #reg');

        CREATE TABLE #reg
            (
                keyname CHAR(200) ,
                value VARCHAR(1000)
            );

        DECLARE @key VARCHAR(8000); -- Holds Registry Key Value

--Build Sql Server's full service name
        DECLARE @SQLServiceName VARCHAR(8000);
        SELECT  @SQLServiceName = @@ServiceName;
        SET @SQLServiceName = CASE WHEN @@ServiceName = 'MSSQLSERVER'
                                    THEN 'MSSQLSERVER'
                                    ELSE 'MSSQL$' + @@ServiceName
                                END; 

        SET @key = 'SYSTEM\CurrentControlSet\Services\' + @SQLServiceName;
--MSSQLSERVER Service Account
        INSERT  INTO #reg
                EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @key,
                    'ObjectName';
        UPDATE  #reg
        SET     keyname = @SQLServiceName; 
--SQLSERVERAGENT Service Account
        DECLARE @AgentServiceName VARCHAR(8000);
        SELECT  @AgentServiceName = @@ServiceName;
        SET @AgentServiceName = CASE WHEN @@ServiceName = 'MSSQLSERVER'
                                        THEN 'SQLSERVERAGENT'
                                        ELSE 'SQLAgent$' + @@ServiceName
                                END; 
        SET @key = 'SYSTEM\CurrentControlSet\Services\'
            + @AgentServiceName; 
        INSERT  INTO #reg
                EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @key,
                    'ObjectName';
	
        UPDATE  #reg
        SET     keyname = @AgentServiceName
        WHERE   keyname = 'ObjectName';
--Authentication Mode
        INSERT  INTO #reg
                EXEC master..xp_loginconfig 'login mode';
--EXEC master..xp_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\MSSQLServer',N'LoginMode'
        SELECT  @SQLSVRACC = value
        FROM    #reg
        WHERE   keyname = @SQLServiceName
		OPTION  ( RECOMPILE );
        SELECT  @SQLAGTACC = value
        FROM    #reg
        WHERE   keyname = @AgentServiceName
		OPTION  ( RECOMPILE ); 
        SELECT  @LOGINMODE = CASE value
                                WHEN 'Windows NT Authentication'
                                THEN 'Windows Authentication Mode'
                                WHEN 'Mixed' THEN 'Mixed Mode'
                                END
        FROM    #reg
        WHERE   keyname = 'login mode'
		OPTION  ( RECOMPILE );
        DROP TABLE #reg;
        DECLARE @WindowsVersion VARCHAR(150);
        DECLARE @Processorcount VARCHAR(150);
        DECLARE @ProcessorType VARCHAR(150);
        DECLARE @PhysicalMemorySTR VARCHAR(150);
        IF OBJECT_ID('tempdb..#Internal') IS NOT NULL
           Drop table #Internal;

        CREATE TABLE #Internal
            (
                [Index] INT ,
                [Name] VARCHAR(20) ,
                Internal_Value VARCHAR(150) ,
                Character_Value VARCHAR(150)
            );

        INSERT  #Internal EXEC master..xp_msver;

        SELECT @WindowsVersion = Character_Value
        FROM    #Internal
        WHERE   [Name] = 'WindowsVersion'
		OPTION  ( RECOMPILE );
        SELECT @Processorcount = Character_Value
        FROM    #Internal
        WHERE   [Name] = 'ProcessorCount'
		OPTION  ( RECOMPILE );
        SELECT @ProcessorType = Character_Value
        FROM     #Internal
        WHERE    [Name] = 'ProcessorType'
		OPTION  ( RECOMPILE );
        SELECT   @PhysicalMemorySTR = Character_Value
        FROM     #Internal
        WHERE    [Name] = 'PhysicalMemory'
		OPTION  ( RECOMPILE );
        DROP TABLE #Internal;


        CREATE TABLE #xp_cmdshell_output ( Output VARCHAR(8000) );
        INSERT  INTO #xp_cmdshell_output EXEC ( 'xp_cmdshell "whoami /priv"');

        DECLARE @InstantInitializationDisabled BIT ,
				@LockPagesInMemoryDisabled BIT,
				@CurrentClockSpeed INT,
				@MaxClockSpeed INT;

        SELECT  @InstantInitializationDisabled = 0 ,
                @LockPagesInMemoryDisabled = 0;
	
        SELECT  @InstantInitializationDisabled = 1
        WHERE   NOT EXISTS ( SELECT TOP 1 1
                                FROM   #xp_cmdshell_output
                                WHERE  Output LIKE '%SeManageVolumePrivilege%'
                                    AND Output LIKE '%Enabled%' );

        SELECT  @LockPagesInMemoryDisabled = 1
        WHERE   NOT EXISTS ( SELECT TOP 1 1
                                FROM   #xp_cmdshell_output
                                WHERE  Output LIKE '%SeLockMemoryPrivilege%'
                                    AND Output LIKE '%Enabled%' );
		
		DELETE FROM #xp_cmdshell_output;
        INSERT  INTO #xp_cmdshell_output EXEC ( 'xp_cmdshell "wmic cpu get CurrentClockSpeed"');
		SELECT	TOP 1 @CurrentClockSpeed = LEFT(Output,4)
		FROM	#xp_cmdshell_output
		WHERE	ISNUMERIC(REPLACE(LEFT(Output,4),' ',''))= 1
				AND REPLACE(LEFT(Output,4),' ','') != '
'
		OPTION  ( RECOMPILE );
		DELETE FROM #xp_cmdshell_output;
        INSERT  INTO #xp_cmdshell_output EXEC ( 'xp_cmdshell "wmic cpu get MaxClockSpeed"');
		SELECT	TOP 1 @MaxClockSpeed = LEFT(Output,4)
		FROM	#xp_cmdshell_output
		WHERE	ISNUMERIC(REPLACE(LEFT(Output,4),' ',''))= 1
				AND REPLACE(LEFT(Output,4),' ','') != '
'
		OPTION  ( RECOMPILE );
		DELETE FROM #xp_cmdshell_output;
        INSERT  #SR_MachineSettings
        SELECT  CASE WHEN @Mask = 1 THEN CONVERT(NVARCHAR(200),'SQLServerMask')
				ELSE ISNULL(CONVERT(NVARCHAR(200), @@SERVERNAME),
                        CONVERT(NVARCHAR(200), SERVERPROPERTY('MachineName'))) 
				END [ServerName] ,
                CASE WHEN @Mask = 1 THEN CONVERT(NVARCHAR(200),'MachineNameMask')
				ELSE CONVERT(NVARCHAR(200), SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) END [MachineName] ,
                CASE WHEN @Mask = 1 THEN CONVERT(NVARCHAR(200),'ServiceNameMask')
				ELSE @@ServiceName END Instance ,
                @Processorcount AS ProcessorCount ,
                @ProcessorNameString AS ProcessorName ,
                @PhysicalMemorySTR AS PhysicalMemory ,
                CASE WHEN @Mask = 1 THEN CONVERT(NVARCHAR(200),'ADLoginNameMask')
				ELSE @SQLSVRACC END AS SQLAccount ,
                CASE WHEN @Mask = 1 THEN CONVERT(NVARCHAR(200),'ADLoginNameMask')
				ELSE @SQLAGTACC END AS SQLAgentAccount ,
                @LOGINMODE AS AuthenticationnMode ,
                @@Version AS Version ,
                CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)) ProductVersion ,
                CONVERT(NVARCHAR(200), SERVERPROPERTY('Edition')) AS Edition ,
                CONVERT(NVARCHAR(200), SERVERPROPERTY('Collation')) AS Collation ,
                CONVERT(NVARCHAR(200), SERVERPROPERTY('ProductLevel')) AS ProductLevel ,
                @SystemManufacturer + ' ' + @SystemModal AS SystemModel ,
                ( SELECT TOP 1
                            login_time AS ServiceStartTime
                    FROM      sys.sysprocesses
                    WHERE     spid = 1
                ) AS ServerStartTime ,
                @LockPagesInMemoryDisabled ,
                @InstantInitializationDisabled,
				@MaxClockSpeed,
				@CurrentClockSpeed
		OPTION  ( RECOMPILE );

				SET @SQLAGTACC = SUBSTRING(@SQLAGTACC,CHARINDEX('\',@SQLAGTACC) + 1,LEN(@SQLAGTACC))
		INSERT @DebugError VALUES  ('Machine Settings',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Machine Settings',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-----------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Server Services',0,1) WITH NOWAIT;
        IF OBJECT_ID('tempdb..#SR_server_services') IS NULL
            CREATE TABLE #SR_server_services(
				[servicename] [nvarchar](256)  NULL,
				[startup_type_desc] [nvarchar](256)  NULL,
				[startup_type] [int] NULL,
				[status] [int] NULL,
				[status_desc] [nvarchar](256)  NULL,
				[service_account] [nvarchar](256)  NULL);
		IF SERVERPROPERTY('productversion') > '10.50.2500.0'
		BEGIN
/*sys.dm_server_services - Returns information about the operating system volume (directory) on which the specified databases and files are stored. Use this dynamic management function in SQL Server 2008 R2 SP1 and later versions to check the attributes of the physical disk drive or return available free space information about the directory. 	*/
			SELECT @cmd = 'INSERT #SR_server_services
SELECT  servicename ,
		startup_type_desc ,
		startup_type ,
		status ,
		status_desc ,' + CASE WHEN @Mask = 1 THEN 'REPLACE(service_account,''' + @SQLAGTACC + ''',''ADLoginNameMask'')' ELSE 'service_account' END + ' [service_account]
FROM    sys.dm_server_services
OPTION  ( RECOMPILE );';

			EXEC(@cmd);
		END
        
		INSERT @DebugError VALUES  ('Server Services',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Server Services',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-----------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Registy Info',0,1) WITH NOWAIT;
		DECLARE @GetInstances TABLE
			( [Value] nvarchar(100),
			InstanceNames nvarchar(100),
			[Data] nvarchar(100))

		Insert into @GetInstances
		EXECUTE xp_regread
	  @rootkey = 'HKEY_LOCAL_MACHINE',
	  @key = 'SOFTWARE\Microsoft\Microsoft SQL Server',
	  @value_name = 'InstalledInstances'

  
	DECLARE @Ver nvarchar(128)
	DECLARE @ComptabilityLevel nvarchar(128)
	DECLARE @InstanceNames nvarchar(1000)
	DECLARE @reg TABLE
		(
			keyname CHAR(200) ,
			value NVARCHAR(1000)
		);
	DECLARE @Tempreg TABLE
		(
			keyname CHAR(200) ,
			value NVARCHAR(1000)
		);
		IF OBJECT_ID('tempdb..#SR_reg') IS NOT NULL DROP TABLE #SR_reg
	CREATE TABLE #SR_reg
		(
			Service VARCHAR(1000),
			InstanceNames VARCHAR(1000),
			keyname CHAR(200) ,
			value NVARCHAR(1000),
			CurrentInstance AS CASE WHEN InstanceNames = @@SERVICENAME THEN CONVERT(BIT,1) ELSE CONVERT(BIT,0) END
		);
	DECLARE @keyi VARCHAR(8000); -- Holds Registry Key Value
		
	DECLARE @SQLServiceNamei VARCHAR(8000);
	DECLARE @AgentServiceNamei VARCHAR(8000);
	  DECLARE crInctances CURSOR LOCAL FAST_FORWARD READ_ONLY FOR SELECT	InstanceNames
	  FROM	@GetInstances
	  ORDER BY [Value];
  
  OPEN crInctances
  
  FETCH NEXT FROM crInctances INTO @InstanceNames
  
  WHILE @@FETCH_STATUS = 0
  BEGIN
		--Build Sql Server's full service name
        SET @SQLServiceNamei = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                                    THEN 'MSSQLSERVER'
                                    ELSE 'MSSQL$' + @InstanceNames
                                END; 

        SET @keyi = 'SYSTEM\CurrentControlSet\Services\' + @SQLServiceNamei;
		DELETE FROM @reg  
		--MSSQLSERVER Service Account
        INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'ObjectName';
        UPDATE  @reg
        SET     keyname = @SQLServiceNamei
		OPTION  ( RECOMPILE ); 
        INSERT #SR_reg ( [Service], InstanceNames,keyname, [value] )
        SELECT 'SQL Server Engine',@InstanceNames,'Account Name'  ,[value] FROM @reg;
             -------------------------------------------------------------------------------	
		SET @PS = 'powershell.exe -noprofile -command "Get-Service | Where-Object {$_.DisplayName -like ''SQL Server (*'' -and $_.Name -eq ''' + @SQLServiceNamei + '''}"';
		DELETE FROM @output;
        INSERT @output EXEC xp_cmdshell @PS;
		IF LEN(@SQLServiceNamei) > 15
		BEGIN
			SET @SQLServiceNamei = @InstanceNames;
		END
		DELETE FROM @output WHERE line IS NULL OR line NOT LIKE '%' + @SQLServiceNamei + '%'
		
        INSERT #SR_reg ( [Service], InstanceNames,keyname, [value] )
		SELECT	TOP 1 'SQL Server Engine State',@InstanceNames,'Service state'  ,LEFT(line,CHARINDEX(' ',line))[State]
		FROM	@output
 
             -------------------------------------------------------------------------------
             IF @InstanceNames = @@SERVICENAME
             BEGIN
                 SET @Ver = CAST(serverproperty('ProductVersion') AS nvarchar)
                    IF ( SUBSTRING(@Ver, 1, CHARINDEX('.', @Ver) - 1) = '10' )
                    BEGIN
                           IF SUBSTRING(SUBSTRING(@Ver, CHARINDEX('.', @Ver)+1 , LEN(@Ver)),1,CHARINDEX('.', SUBSTRING(@Ver, CHARINDEX('.', @Ver)+1 , LEN(@Ver)))-1) = '50'
                                 SELECT @Ver = SUBSTRING(@Ver, 1, CHARINDEX('.', @Ver) - 1) + '_' + SUBSTRING(SUBSTRING(@Ver, CHARINDEX('.', @Ver)+1 , LEN(@Ver)),1,CHARINDEX('.', SUBSTRING(@Ver, CHARINDEX('.', @Ver)+1 , LEN(@Ver)))-1);
                           ELSE SELECT @Ver = SUBSTRING(@Ver, 1, CHARINDEX('.', @Ver) - 1)
                    END
   
                    ELSE SELECT @Ver = SUBSTRING(@Ver, 1, CHARINDEX('.', @Ver) - 1)
             END
                    
             SET @keyi = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                                    THEN 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @Ver + '.' + @InstanceNames + '\MSSQLServer\CurrentVersion'
                                    ELSE 'SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server\' + @InstanceNames + '\MSSQLServer\CurrentVersion'
                                END; 
             DELETE FROM @reg;
             DELETE FROM @Tempreg; 
        INSERT  INTO @Tempreg
             EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'CurrentVersion';
			 
             SELECT @Ver = value
             FROM   @Tempreg;
             SET @ComptabilityLevel = SUBSTRING(@Ver, 1, CHARINDEX('.', @Ver) - 1) + SUBSTRING(SUBSTRING(@Ver, CHARINDEX('.', @Ver)+1,LEN(@Ver) ), 1, 1);
             IF ( SUBSTRING(@Ver, 1, CHARINDEX('.', @Ver) - 1) = '10' )
             BEGIN
                    IF SUBSTRING(SUBSTRING(@Ver, CHARINDEX('.', @Ver)+1 , LEN(@Ver)),1,CHARINDEX('.', SUBSTRING(@Ver, CHARINDEX('.', @Ver)+1 , LEN(@Ver)))-1) = '50'
                           SELECT @Ver = SUBSTRING(@Ver, 1, CHARINDEX('.', @Ver) - 1) + '_' + SUBSTRING(SUBSTRING(@Ver, CHARINDEX('.', @Ver)+1 , LEN(@Ver)),1,CHARINDEX('.', SUBSTRING(@Ver, CHARINDEX('.', @Ver)+1 , LEN(@Ver)))-1);
                    ELSE SELECT @Ver = SUBSTRING(@Ver, 1, CHARINDEX('.', @Ver) - 1)
             END
   
             ELSE SELECT @Ver = SUBSTRING(@Ver, 1, CHARINDEX('.', @Ver) - 1)
----------------------------------------------------------------------------------------------------------------------------------
             SET @key = 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @Ver + '.' + @InstanceNames + '\Setup'
			 INSERT   @reg
             EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @key, 'PatchLevel';
			 
             INSERT #SR_reg ( [Service], InstanceNames,keyname, [value] )
             SELECT 'SQL Server Engine Version',@InstanceNames,'Last Version Installed' ,value FROM @reg;
			 
		
----------------------------------------------------------------------------------------------------------------------------------
             DELETE FROM @reg;
             SET @keyi = 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @Ver + '.' + @InstanceNames + '\Setup'
             INSERT @reg
             EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'Edition';
             INSERT #SR_reg ( [Service], InstanceNames,keyname, [value] )
             SELECT 'SQL Server Engine Edition',@InstanceNames,'Edition Installed' ,value FROM @reg;
			 
		
----------------------------------------------------------------------------------------------------------------------------------
             --Error Log file
             DELETE FROM @reg;
        SET @keyi = N'Software\Microsoft\Microsoft SQL Server\MSSQL' + @Ver + '.' + @InstanceNames + '\MSSQLServer'
             INSERT @reg
        EXECUTE xp_regread N'HKEY_LOCAL_MACHINE',@keyi, N'NumErrorLogs';
             INSERT #SR_reg ( [Service], InstanceNames,keyname, [value] )
             SELECT 'SQL Server Number of Error Log files',@InstanceNames,'Number Error Logs' ,value FROM @reg;     
			 
		         
----------------------------------------------------------------------------------------------------------------------------------
             DELETE FROM @reg;
             SET @key = 'SOFTWARE\Microsoft\Microsoft SQL Server\' + @ComptabilityLevel;
        INSERT @reg
             EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @key, 'CustomerFeedback';
             INSERT #SR_reg ( [Service], InstanceNames,keyname, [value] )
             SELECT 'SQL Server Customer Feedback',@InstanceNames,'Customer Feedback Enabled' ,value FROM @reg;
             DELETE FROM @reg;
        INSERT @reg
             EXECUTE xp_regread 'HKEY_LOCAL_MACHINE', @key, 'EnableErrorReporting';
             INSERT #SR_reg ( [Service], InstanceNames,keyname, [value] )
             SELECT 'SQL Server Error Reporting',@InstanceNames,'Error Reporting Enabled' ,value FROM @reg;
			 
		
----------------------------------------------------------------------------------------------------------------------------------
        --SQLSERVERAGENT Service Account
        SET @AgentServiceNamei = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                                        THEN 'SQLSERVERAGENT'
                                        ELSE 'SQLAgent$' + @InstanceNames
                                END; 
        SET @keyi = 'SYSTEM\CurrentControlSet\Services\' + @AgentServiceNamei; 
             
        DELETE FROM @reg  
        INSERT @reg
                EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'ObjectName';
       
        UPDATE  @reg
        SET     keyname = @AgentServiceNamei
        WHERE   keyname = 'ObjectName';
        INSERT #SR_reg
                ( Service, InstanceNames,keyname, value )
        SELECT 'SQL Server Agent',@InstanceNames,'Account Name' ,value FROM @reg;
----------------------------------------------------------------------------------------------------
        --Windows Power Plan
		IF @InstanceNames = @@SERVICENAME
        BEGIN
			SET @keyi = 'SOFTWARE\Microsoft\Windows\CurrentVersion\explorer\ControlPanel\NameSpace\{025A5937-A6BE-4686-A844-36FE4BEC8B6D}'; 
             
			DELETE FROM @reg  
			INSERT @reg
					EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'PreferredPlan';
       
			INSERT #SR_reg
					( Service, InstanceNames,keyname, value )
			SELECT 'Windows Power Plan',@InstanceNames,'Power Plan' ,CASE CONVERT(VARCHAR(50),value) 
					WHEN '381b4222-f694-41f0-9685-ff5bb260df2e' THEN 'Balanced'
					WHEN 'a1841308-3541-4fab-bc81-f71556f20b4a' THEN 'Power saver'
					WHEN '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' THEN 'High performance'
					ELSE NULL END 
			FROM	@reg;
		END
----------------------------------------------------------------------------------------------------
        --Windows Power Plan
		IF @InstanceNames = @@SERVICENAME--HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\
        BEGIN
			SET @keyi = 'SOFTWARE\CurrentControlSet\Control\Session Manager\Memory Management'; 
             
			DELETE FROM @reg  
			INSERT @reg
					EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'PagingFiles';
       
			INSERT #SR_reg
					( Service, InstanceNames,keyname, value )
			SELECT 'Windows Page File',@InstanceNames,'PagingFiles' ,value
			FROM	@reg;
		END		
----------------------------------------------------------------------------------------------------
--SQLArgs
        DELETE FROM @reg  
        
        SET @keyi = CASE WHEN @InstanceNames = 'MSSQLSERVER'
                            THEN 'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL' + @Ver + '.' + @InstanceNames + '\MSSQLServer\Parameters'
                            ELSE 'SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server\' + @InstanceNames + '\MSSQLServer\Parameters'
                        END; 
        DELETE FROM @reg  
        INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs3';
		INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs4';
		INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs5';
		INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs6';
		INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs7';
		INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs8';
		INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs9';
		INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs10';
		INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs11';
		INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs12';
		INSERT @reg EXEC master..xp_regread 'HKEY_LOCAL_MACHINE', @keyi, 'SQLArgs13';
       
        UPDATE  @reg
        SET     keyname = @InstanceNames
        WHERE   keyname like 'SQLArgs%';
		
        INSERT #SR_reg
                ( Service, InstanceNames,keyname, value )
        SELECT 'SQL Server Trace Flage',@InstanceNames,'Trace Flage' ,value FROM @reg;
----------------------------------------------------------------------------------------------------
      FETCH NEXT FROM crInctances INTO @InstanceNames      
  END
  
  CLOSE crInctances
  DEALLOCATE crInctances
  IF @Mask = 1
  BEGIN
	UPDATE	#SR_reg 
	SET		InstanceNames = 'ServiceNameMask'
	WHERE	CurrentInstance = 1;
	DECLARE @InstanceNamesCount INT;
	SELECT	@InstanceNamesCount = COUNT(DISTINCT InstanceNames)
	FROM	#SR_reg
	WHERE	CurrentInstance = 0;
	IF @InstanceNamesCount > 0
	BEGIN
		;WITH CTE AS (
	    SELECT	InstanceNames,ROW_NUMBER() OVER (ORDER BY InstanceNames ASC) RN
	    FROM	#SR_reg
		WHERE	CurrentInstance = 0
		)
		UPDATE	R
		SET		InstanceNames = 'ServiceNameMask' + CONVERT(VARCHAR(5),C.RN)
		FROM	#SR_reg R
				INNER JOIN CTE C ON C.InstanceNames = R.InstanceNames
		WHERE	R.CurrentInstance = 0;
	END
	
	UPDATE	#SR_reg 
	SET		value = REPLACE(value,@SQLAGTACC,'ADLoginNameMask')
	WHERE	value LIKE '%' + @SQLAGTACC + '%';
  END
		INSERT @DebugError VALUES  ('Registy Info',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Registy Info',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
-----------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Jobs Info',0,1) WITH NOWAIT;
        IF OBJECT_ID('tempdb..#SR_Jobs') IS NOT NULL
            DROP TABLE #SR_Jobs;
        SELECT  T.JobName ,
                T.RunDateTime ,
                T.RunDurationMinutes,
				CONVERT(NVARCHAR(MAX),'Over 55 Minuts')[Type]
        INTO    #SR_Jobs
        FROM    ( SELECT    j.name AS JobName ,
                            rdm.RunDateTime ,
                            rdm.RunDurationMinutes ,
                            ROW_NUMBER() OVER ( PARTITION BY j.name ORDER BY rdm.RunDateTime DESC) RN
                    FROM      msdb.dbo.sysjobs j
                            INNER JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
                            CROSS APPLY ( SELECT    msdb.dbo.agent_datetime(run_date, run_time) AS RunDateTime ,
                                                    ( ( h.run_duration / 10000 * 3600 + ( h.run_duration / 100 ) % 100 * 60 + run_duration % 100 + 31 ) / 60 ) RunDurationMinutes
                                        ) rdm
                    WHERE     j.enabled = 1  --Only Enabled Jobs
                            AND rdm.RunDateTime > DATEADD(DAY, -3,
                                                            GETDATE())
							AND rdm.RunDurationMinutes > 55
                ) T
        WHERE   T.RN = 1;

		
	INSERT	#SR_Jobs
	SELECT  j.name JobName,
            joa.JobStart ,
			rdm.RunDurationMinutes,
			'Longer then the next run'
    FROM    msdb..sysjobhistory AS h
			CROSS APPLY ( SELECT    msdb.dbo.agent_datetime(run_date, run_time) AS RunDateTime ,
                                                    ( ( h.run_duration / 10000 * 3600 + ( h.run_duration / 100 ) % 100 * 60 + run_duration % 100 + 31 ) / 60 ) RunDurationMinutes
                                        ) rdm
            INNER JOIN msdb..sysjobs AS j ON j.job_id = h.job_id
            OUTER APPLY ( SELECT    CAST(SUBSTRING(CONVERT(VARCHAR(10), h.run_date),
                                                   5, 2) + '-'
                                    + SUBSTRING(CONVERT(VARCHAR(10), h.run_date),
                                                7, 2) + '-'
                                    + SUBSTRING(CONVERT(VARCHAR(10), h.run_date),
                                                1, 4) + ' '
                                    + +SUBSTRING(CONVERT(VARCHAR(10), REPLICATE('0',
                                                              6
                                                              - LEN(h.run_time))
                                                 + CAST(h.run_time AS VARCHAR)),
                                                 1, 2) + ':'
                                    + SUBSTRING(CONVERT(VARCHAR(10), REPLICATE('0',
                                                              6
                                                              - LEN(h.run_time))
                                                + CAST(h.run_time AS VARCHAR)),
                                                3, 2) + ':'
                                    + SUBSTRING(CONVERT(VARCHAR(10), REPLICATE('0',
                                                              6
                                                              - LEN(h.run_time))
                                                + CAST(h.run_time AS VARCHAR)),
                                                5, 2) AS SMALLDATETIME) AS JobStart ,
                                    DATEADD(SECOND,
                                            CASE WHEN h.run_duration > 0
                                                 THEN ( h.run_duration
                                                        / 1000000 ) * ( 3600
                                                              * 24 )
                                                      + ( h.run_duration
                                                          / 10000 % 100 )
                                                      * 3600
                                                      + ( h.run_duration / 100
                                                          % 100 ) * 60
                                                      + ( h.run_duration % 100 )
                                                 ELSE 0
                                            END,
                                            CAST(SUBSTRING(CONVERT(VARCHAR(10), h.run_date),
                                                           5, 2) + '-'
                                            + SUBSTRING(CONVERT(VARCHAR(10), h.run_date),
                                                        7, 2) + '-'
                                            + SUBSTRING(CONVERT(VARCHAR(10), h.run_date),
                                                        1, 4) + ' '
                                            + +SUBSTRING(CONVERT(VARCHAR(10), REPLICATE('0',
                                                              6
                                                              - LEN(h.run_time))
                                                         + CAST(h.run_time AS VARCHAR)),
                                                         1, 2) + ':'
                                            + SUBSTRING(CONVERT(VARCHAR(10), REPLICATE('0',
                                                              6
                                                              - LEN(h.run_time))
                                                        + CAST(h.run_time AS VARCHAR)),
                                                        3, 2) + ':'
                                            + SUBSTRING(CONVERT(VARCHAR(10), REPLICATE('0',
                                                              6
                                                              - LEN(h.run_time))
                                                        + CAST(h.run_time AS VARCHAR)),
                                                        5, 2) AS SMALLDATETIME)) AS JobEnd ,
                                    outcome = CASE WHEN h.run_status = 0
                                                   THEN 'Fail'
                                                   WHEN h.run_status = 1
                                                   THEN 'Success'
                                                   WHEN h.run_status = 2
                                                   THEN 'Retry'
                                                   WHEN h.run_status = 3
                                                   THEN 'Cancel'
                                                   WHEN h.run_status = 4
                                                   THEN 'In progress'
                                              END
                        ) joa
			CROSS APPLY(SELECT	TOP 1 freq_subday_interval,job_id,
								CASE 
								WHEN [sSCH].freq_subday_type = 4 THEN [sSCH].freq_subday_interval * 60		-- Minuts
								WHEN [sSCH].freq_subday_type = 2 THEN [sSCH].freq_subday_interval			-- Seconds
								WHEN [sSCH].freq_subday_type = 8 THEN [sSCH].freq_subday_interval * 60 * 60 -- Hours
								END SecondsToNextRun
						FROM	msdb..[sysjobschedules] AS [sJOBSCH]
								LEFT JOIN msdb..[sysschedules] AS [sSCH] ON [sJOBSCH].[schedule_id] = [sSCH].[schedule_id]
						WHERE	sSCH.enabled = 1
								AND [sSCH].freq_type = 4 --Daily	
								AND [sSCH].freq_interval = 1 -- One Day
								AND [sSCH].freq_subday_type != 1 -- Minuts
								AND [sJOBSCH].job_id = j.job_id
								)SC
    WHERE   h.step_id = 0
            AND j.enabled = 1
            AND CAST(SUBSTRING(CONVERT(VARCHAR(10), h.run_date), 5, 2) + '-'
            + SUBSTRING(CONVERT(VARCHAR(10), h.run_date), 7, 2) + '-'
            + SUBSTRING(CONVERT(VARCHAR(10), h.run_date), 1, 4) AS SMALLDATETIME) = CONVERT(VARCHAR(10), GETDATE(), 121)
			--AND DATEDIFF(MI, joa.JobStart, joa.JobEND) > 10 -- 10 Min
			AND SC.SecondsToNextRun < DATEDIFF(SECOND, joa.JobStart, joa.JobEnd)

	IF OBJECT_ID('tempdb..#JobStatus') IS NOT NULL DROP TABLE #JobStatus;
		CREATE TABLE #JobStatus([JobName] sysname,[StepID] INT, [StepName] sysname,[Outcome] NVARCHAR(255),
		[LastRunDatetime] DATETIME,
		[SubSystem] NVARCHAR(512),
		[Message] NVARCHAR(max),
		[Caller] NVARCHAR(255));
	IF OBJECT_ID('tempdb..#SR_JobOut') IS NULL
		CREATE TABLE #SR_JobOut([JobName] sysname,[StepID] INT, [StepName] sysname,[Outcome] NVARCHAR(255),
		[LastRunDatetime] DATETIME,
		[SubSystem] NVARCHAR(512),
		[Message] NVARCHAR(max),
		[Caller] NVARCHAR(255));

	IF EXISTS(SELECT TOP 1 1 FROM sys.databases D WHERE D.name = 'SSIS')
	BEGIN
		INSERT #JobStatus
		SELECT	j.name [JobName],
				js.step_id [StepID],
				js.step_name [StepName],
				CASE 
				WHEN JSS.[SubSystem] = 'Maintenance Plans(SSIS)' AND MP.Error COLLATE DATABASE_DEFAULT != '' THEN LR.last_run_outcome + ' + Minor Errors'
				WHEN LR.last_run_datetime >= ISNULL(xSDT.StartDateTime,JxA.run_requested_date) OR ST.StepID IS NULL THEN LR.last_run_outcome 
						ELSE 'Did not run' END	[Outcome],
				CASE WHEN LR.last_run_datetime >= ISNULL(xSDT.StartDateTime,JxA.run_requested_date) THEN case WHEN ST.StepID IS NULL THEN null
									else LR.last_run_datetime END
						ELSE NULL END [LastRunDatetime] ,
			   JSS.[SubSystem],
			   CASE WHEN LR.last_run_datetime >= xSDT.StartDateTime THEN
					   CASE  
						WHEN JSS.[SubSystem] = 'Maintenance Plans(SSIS)' THEN CASE WHEN MP.Error COLLATE DATABASE_DEFAULT = '' THEN JH.message ELSE ISNULL(MP.Error COLLATE DATABASE_DEFAULT,JH.message) END
						WHEN LR.last_run_outcome = 'Failed' AND js.subsystem = 'SSIS' THEN JH.message
						WHEN LR.last_run_outcome = 'Failed' AND js.subsystem = 'TSQL' THEN JH.message
					   ELSE NULL END 
			   ELSE NULL END [Message],
			   CASE WHEN j.description LIKE '%report server%' THEN 'Report Server, ' ELSE '' END + ISNULL('Alert - ' + Al.name + ', ','') + ISNULL('Schedule - ' + SCH.name,'') [Caller]
		FROM	msdb.dbo.sysjobs j
				INNER JOIN msdb.dbo.sysjobsteps js ON j.job_id = js.job_id
				CROSS APPLY(SELECT TOP 1 CASE WHEN PATINDEX('%"Maintenance Plans\%',js.command) > 0 THEN 'Maintenance Plans(SSIS)' ELSE
				CASE js.subsystem
			WHEN 'ActiveScripting' THEN 'ActiveX Script'
			WHEN 'CmdExec' THEN 'Operating system (CmdExec)'
			WHEN 'PowerShell' THEN 'PowerShell'
			WHEN 'Distribution' THEN 'Replication Distributor'
			WHEN 'Merge' THEN 'Replication Merge'
			WHEN 'QueueReader' THEN 'Replication Queue Reader'
			WHEN 'Snapshot' THEN 'Replication Snapshot'
			WHEN 'LogReader' THEN 'Replication Transaction-Log Reader'
			WHEN 'ANALYSISCOMMAND' THEN 'SQL Server Analysis Services Command'
			WHEN 'ANALYSISQUERY' THEN 'SQL Server Analysis Services Query'
			WHEN 'SSIS' THEN 'SQL Server Integration Services Package'
			WHEN 'TSQL' THEN 'Transact-SQL script (T-SQL)'
			ELSE js.subsystem END
		  END AS [SubSystem]) JSS
				LEFT JOIN (SELECT DISTINCT Ij.name,
						ISNULL(CASE WHEN OA.Lag_on_success_step_id = 0 THEN Ijs.step_id ELSE OA.Lag_on_success_step_id END,Ijs.step_id) StepID
				FROM	msdb.dbo.sysjobs Ij
				inner join msdb.dbo.sysjobsteps Ijs 
						on Ij.job_id = Ijs.job_id
				Outer Apply (
					SELECT TOP 1 on_success_step_id Lag_on_success_step_id
					FROM	msdb.dbo.sysjobsteps Ijs2
					WHERE	Ijs2.step_id < Ijs.step_id 
					ORDER BY Ijs2.step_id) OA) ST 
				ON ST.StepID = js.step_id and ST.name = j.name
				CROSS APPLY (SELECT TOP 1 msdb.dbo.agent_datetime(
								   case when js.last_run_date = 0 then NULL else js.last_run_date end,
								   case when js.last_run_time = 0 then NULL else js.last_run_time end) last_run_datetime,
								   case WHEN ST.StepID IS NULL THEN 'Disabled'
									when js.last_run_outcome = 0 then 'Failed'
									when js.last_run_outcome = 1 then 'Succeeded'
									when js.last_run_outcome = 2 then 'Retry'
									when js.last_run_outcome = 3 then 'Canceled'
									else 'Unknown'
								   end AS last_run_outcome
								   ) LR
				LEFT JOIN msdb.dbo.sysjobhistory JH ON j.job_id = JH.job_id
					AND JH.step_id = js.step_id
					AND msdb.dbo.agent_datetime(JH.run_date,JH.run_time) = case WHEN ST.StepID IS NULL THEN null else LR.last_run_datetime END
				LEFT JOIN msdb..sysalerts Al ON Al.job_id = j.job_id
				OUTER APPLY (SELECT TOP 1 S2.name FROM msdb..sysjobschedules S INNER JOIN msdb..sysschedules S2 ON S2.schedule_id = S.schedule_id WHERE j.job_id = S.job_id)SCH
				OUTER APPLY (SELECT REPLACE(REPLACE(T.Error,'<X>',''),'</X>','')
							FROM	(SELECT  ld.error_message  X
									FROM    msdb..sysmaintplan_plans mp
											INNER JOIN msdb..sysmaintplan_subplans msp ON mp.id = msp.plan_id
											OUTER APPLY (SELECT TOP 1 * FROM msdb..sysmaintplan_log mpl WHERE msp.subplan_id = mpl.subplan_id ORDER BY mpl.start_time DESC)mpl
											LEFT JOIN msdb..sysmaintplan_logdetail ld ON mpl.task_detail_id = ld.task_detail_id
									WHERE   j.name LIKE mp.name + '%'
									FOR XML PATH(''))T(Error))MP(Error)
				OUTER APPLY (SELECT	TOP 1 [StartDateTime] = msdb.dbo.agent_datetime(
									   CASE WHEN xjs.last_run_date = 0 then NULL else xjs.last_run_date end,
									   CASE WHEN xjs.last_run_time = 0 then NULL else xjs.last_run_time end)
								FROM	msdb.dbo.sysjobsteps xjs
										LEFT JOIN (SELECT	ja.job_id,
															j.name AS job_name,
															ja.start_execution_date,      
															ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id,
															js.step_name
													FROM	msdb.dbo.sysjobactivity ja 
															LEFT JOIN msdb.dbo.sysjobhistory jh ON ja.job_history_id = jh.instance_id
															INNER JOIN msdb.dbo.sysjobs j ON ja.job_id = j.job_id
															INNER JOIN msdb.dbo.sysjobsteps js ON ja.job_id = js.job_id
																AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
													WHERE	ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
															AND start_execution_date is not null
															AND stop_execution_date is null)Ac ON Ac.job_id = xjs.job_id
								WHERE	j.job_id = xjs.job_id
										AND (Ac.start_execution_date != msdb.dbo.agent_datetime(case when xjs.last_run_date = 0 then NULL else xjs.last_run_date end,
									   case when xjs.last_run_time = 0 then NULL else xjs.last_run_time end) or Ac.start_execution_date is null)
								order by xjs.step_id)xSDT
				OUTER APPLY (SELECT	TOP 1 ja.run_requested_date FROM msdb.dbo.sysjobactivity ja WHERE j.job_id = ja.job_id ORDER BY ja.run_requested_date desc)JxA
				OUTER APPLY( SELECT  TOP 1 message
							   FROM    SSISDB.catalog.event_messages em
							   WHERE   em.package_name COLLATE DATABASE_DEFAULT = RIGHT( SUBSTRING(js.command,0,PATINDEX('%.dtsx%',js.command)), CHARINDEX( '\', REVERSE( SUBSTRING(js.command,0,PATINDEX('%.dtsx%',js.command))) + '\' ) - 1 ) +N'.dtsx'
										AND event_name = 'OnError'
						ORDER BY event_message_id DESC
				)SS
  
		WHERE	j.enabled = 1
		ORDER BY j.name,js.step_id;
	END
	ELSE
	BEGIN
		INSERT #JobStatus
		SELECT j.name [JobName],
				js.step_id [StepID],
				js.step_name [StepName],
				CASE WHEN JSS.[SubSystem] = 'Maintenance Plans(SSIS)' AND MP.Error COLLATE DATABASE_DEFAULT != '' THEN LR.last_run_outcome + ' + Minor Errors'
					WHEN LR.last_run_datetime >= ISNULL(xSDT.StartDateTime,JxA.run_requested_date) OR ST.StepID IS NULL THEN LR.last_run_outcome
					ELSE 'Did not run' 
					END     [Outcome],
				CASE WHEN LR.last_run_datetime >= ISNULL(xSDT.StartDateTime,JxA.run_requested_date) THEN case WHEN ST.StepID IS NULL THEN null else LR.last_run_datetime END
					 ELSE NULL END [LastRunDatetime] ,
				JSS.[SubSystem],
				CASE WHEN LR.last_run_datetime >= xSDT.StartDateTime THEN
							CASE
								WHEN JSS.[SubSystem] = 'Maintenance Plans(SSIS)' THEN CASE WHEN MP.Error COLLATE DATABASE_DEFAULT = '' THEN JH.message ELSE ISNULL(MP.Error COLLATE DATABASE_DEFAULT,JH.message) END
								WHEN LR.last_run_outcome = 'Failed' AND js.subsystem = 'SSIS' THEN JH.message
								WHEN LR.last_run_outcome = 'Failed' AND js.subsystem = 'TSQL' THEN JH.message
							ELSE NULL END
					ELSE NULL 
					END [Message],
				CASE WHEN j.description LIKE '%report server%' THEN 'Report Server, ' ELSE '' END + ISNULL('Alert - ' + Al.name + ', ','') + ISNULL('Schedule - ' + SCH.name,'') [Caller]
		FROM	msdb.dbo.sysjobs j
		INNER JOIN msdb.dbo.sysjobsteps js 
				ON j.job_id = js.job_id
		CROSS APPLY(SELECT TOP 1 CASE WHEN PATINDEX('%"Maintenance Plans\%',js.command) > 0 THEN 'Maintenance Plans(SSIS)' ELSE
												CASE js.subsystem    WHEN 'ActiveScripting' THEN 'ActiveX Script'
													WHEN 'CmdExec' THEN 'Operating system (CmdExec)'
													WHEN 'PowerShell' THEN 'PowerShell'
													WHEN 'Distribution' THEN 'Replication Distributor'
													WHEN 'Merge' THEN 'Replication Merge'
													WHEN 'QueueReader' THEN 'Replication Queue Reader'
													WHEN 'Snapshot' THEN 'Replication Snapshot'
													WHEN 'LogReader' THEN 'Replication Transaction-Log Reader'
													WHEN 'ANALYSISCOMMAND' THEN 'SQL Server Analysis Services Command'
													WHEN 'ANALYSISQUERY' THEN 'SQL Server Analysis Services Query'
													WHEN 'SSIS' THEN 'SQL Server Integration Services Package'
													WHEN 'TSQL' THEN 'Transact-SQL script (T-SQL)'
													ELSE js.subsystem END
								END AS [SubSystem]) JSS
		LEFT JOIN (SELECT DISTINCT Ij.name,
						ISNULL(CASE WHEN OA.Lag_on_success_step_id = 0 THEN Ijs.step_id ELSE OA.Lag_on_success_step_id END,Ijs.step_id) StepID
				FROM	msdb.dbo.sysjobs Ij
				inner join msdb.dbo.sysjobsteps Ijs 
						on Ij.job_id = Ijs.job_id
				Outer Apply (
					Select Top 1 on_success_step_id Lag_on_success_step_id
					From	msdb.dbo.sysjobsteps Ijs2
					Where	Ijs2.step_id<Ijs.step_id Order By Ijs2.step_id) OA) ST 
				ON ST.StepID = js.step_id and ST.name = j.name
		CROSS APPLY (SELECT TOP 1 msdb.dbo.agent_datetime(case when js.last_run_date = 0 then NULL else js.last_run_date end,
							case when js.last_run_time = 0 then NULL else js.last_run_time end) last_run_datetime,
							case WHEN ST.StepID IS NULL THEN 'Disabled'
								when js.last_run_outcome = 0 then 'Failed'
								when js.last_run_outcome = 1 then 'Succeeded'
								when js.last_run_outcome = 2 then 'Retry'
								when js.last_run_outcome = 3 then 'Canceled'
							else 'Unknown'
							end AS last_run_outcome) LR
		LEFT JOIN msdb.dbo.sysjobhistory JH 
				ON j.job_id = JH.job_id
				AND JH.step_id = js.step_id
				AND msdb.dbo.agent_datetime(JH.run_date,JH.run_time) = case WHEN ST.StepID IS NULL THEN null else LR.last_run_datetime END
		LEFT JOIN msdb..sysalerts Al 
				ON Al.job_id = j.job_id
		OUTER APPLY (SELECT TOP 1 S2.name 
				FROM	msdb..sysjobschedules S 
				INNER JOIN msdb..sysschedules S2 
						ON S2.schedule_id = S.schedule_id 
				WHERE	j.job_id = S.job_id)SCH
		OUTER APPLY (SELECT REPLACE(REPLACE(T.Error,'<X>',''),'</X>','')
					FROM   (SELECT  ld.error_message  X
							FROM    msdb..sysmaintplan_plans mp
							INNER JOIN msdb..sysmaintplan_subplans msp 
									ON mp.id = msp.plan_id
							OUTER APPLY (SELECT TOP 1 * 
									FROM	msdb..sysmaintplan_log mpl
									WHERE	msp.subplan_id = mpl.subplan_id 
									ORDER BY mpl.start_time DESC)mpl
							LEFT JOIN msdb..sysmaintplan_logdetail ld 
									ON mpl.task_detail_id = ld.task_detail_id
					WHERE   j.name LIKE mp.name + '%'
					FOR XML PATH(''))T(Error))MP(Error)
		OUTER APPLY (SELECT  TOP 1 [StartDateTime] = msdb.dbo.agent_datetime(
												CASE WHEN xjs.last_run_date = 0 then NULL else xjs.last_run_date end,
												CASE WHEN xjs.last_run_time = 0 then NULL else xjs.last_run_time end)
									FROM   msdb.dbo.sysjobsteps xjs
									LEFT JOIN (SELECT       ja.job_id,
													j.name AS job_name,
													ja.start_execution_date,      
													ISNULL(last_executed_step_id,0)+1 AS current_executed_step_id,
													js.step_name
										FROM       msdb.dbo.sysjobactivity ja 
										LEFT JOIN msdb.dbo.sysjobhistory jh 
												ON ja.job_history_id = jh.instance_id
										INNER JOIN msdb.dbo.sysjobs j 
												ON ja.job_id = j.job_id
										INNER JOIN msdb.dbo.sysjobsteps js 
												ON ja.job_id = js.job_id
												AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
										WHERE       ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
													AND start_execution_date is not null
													AND stop_execution_date is null)Ac ON Ac.job_id = xjs.job_id
				WHERE	j.job_id = xjs.job_id
						AND (Ac.start_execution_date != msdb.dbo.agent_datetime(case when xjs.last_run_date = 0 then NULL else xjs.last_run_date end, case when xjs.last_run_time = 0 then NULL else xjs.last_run_time end) or Ac.start_execution_date is null)
				order by xjs.step_id)xSDT
		OUTER APPLY (SELECT  TOP 1 ja.run_requested_date 
				FROM msdb.dbo.sysjobactivity ja 
				WHERE j.job_id = ja.job_id 
				ORDER BY ja.run_requested_date desc)JxA
		WHERE  j.enabled = 1
		ORDER BY JSS.[SubSystem],j.name,js.step_id;
	END
		INSERT	#SR_JobOut
		SELECT	[JobName] ,[StepID] , [StepName] ,[Outcome] ,[LastRunDatetime] ,[SubSystem],REPLACE([Message],@SQLAGTACC,'ADLoginNameMask'),[Caller]--@SQLAGTACC
		FROM	#JobStatus
		WHERE	Outcome LIKE '%Failed%' OR Outcome LIKE '%Error%'
		OPTION(RECOMPILE);
		DROP TABLE #JobStatus;
	
		INSERT	#SR_Jobs
		SELECT	S.name JobName ,
				NULL RunDateTime ,
				NULL RunDurationMinutes,
				CONVERT(NVARCHAR(MAX),'Owner')[Type]
		FROM	msdb..sysjobs S
		WHERE	S.owner_sid != '0x01'
				AND S.enabled = 1
		OPTION(RECOMPILE);
		INSERT @DebugError VALUES  ('Jobs Info',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Jobs Info',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
---------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Drive Latency',0,1) WITH NOWAIT;
        IF OBJECT_ID('tempdb..#SR_Latency') IS NOT NULL
            DROP TABLE #SR_Latency;
        SELECT  tab.Drive ,
                tab.type ,
                tab.num_of_reads ,
                tab.io_stall_read_ms ,
                tab.num_of_writes ,
                tab.io_stall_write_ms ,
                tab.num_of_bytes_read ,
                tab.num_of_bytes_written ,
                tab.io_stall ,
                RL.[Read Latency] [ReadLatency],
                RL.[Write Latency] [WriteLatency],
                RL.[Overall Latency] [OverallLatency],
                RL.[Avg Bytes/Read] [AvgBytes_Read],
                RL.[Avg Bytes/Write] [AvgBytes_Write],
                RL.[Avg Bytes/Transfer] [AvgBytes_Transfer]
        INTO    #SR_Latency
        FROM    ( SELECT    LEFT(mf.physical_name, 2) AS Drive ,
                            CASE WHEN mf.database_id = 2 THEN 99
                                    ELSE mf.type
                            END type ,
                            SUM(num_of_reads) AS num_of_reads ,
                            SUM(io_stall_read_ms) AS io_stall_read_ms ,
                            SUM(num_of_writes) AS num_of_writes ,
                            SUM(io_stall_write_ms) AS io_stall_write_ms ,
                            SUM(num_of_bytes_read) AS num_of_bytes_read ,
                            SUM(num_of_bytes_written) AS num_of_bytes_written ,
                            SUM(io_stall) AS io_stall
                    FROM      sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
                            INNER JOIN sys.master_files AS mf WITH ( NOLOCK ) ON vfs.database_id = mf.database_id
                                                            AND vfs.file_id = mf.file_id
                    WHERE     mf.database_id NOT IN ( 1, 3, 4 ) -- Master,MSDB,Model
                    GROUP BY  LEFT(mf.physical_name, 2) ,
                            CASE WHEN mf.database_id = 2 THEN 99
                                    ELSE mf.type
                            END
                ) AS tab
                CROSS APPLY ( SELECT    CASE WHEN num_of_reads = 0 THEN 0
                                                ELSE ( io_stall_read_ms
                                                    / num_of_reads )
                                        END AS [Read Latency] ,
                                        CASE WHEN io_stall_write_ms = 0
                                                THEN 0
                                                ELSE ( io_stall_write_ms
                                                    / num_of_writes )
                                        END AS [Write Latency] ,
                                        CASE WHEN ( num_of_reads = 0
                                                    AND num_of_writes = 0
                                                    ) THEN 0
                                                ELSE ( io_stall
                                                    / ( num_of_reads
                                                        + num_of_writes ) )
                                        END AS [Overall Latency] ,
                                        CASE WHEN num_of_reads = 0 THEN 0
                                                ELSE ( num_of_bytes_read
                                                    / num_of_reads )
                                        END AS [Avg Bytes/Read] ,
                                        CASE WHEN io_stall_write_ms = 0
                                                THEN 0
                                                ELSE ( num_of_bytes_written
                                                    / num_of_writes )
                                        END AS [Avg Bytes/Write] ,
                                        CASE WHEN ( num_of_reads = 0
                                                    AND num_of_writes = 0
                                                    ) THEN 0
                                                ELSE ( ( num_of_bytes_read
                                                        + num_of_bytes_written )
                                                    / ( num_of_reads
                                                        + num_of_writes ) )
                                        END AS [Avg Bytes/Transfer]
                            ) RL
							OPTION(RECOMPILE);
		INSERT @DebugError VALUES  ('Drive Latency',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Drive Latency',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------------------------------------------------------------------
BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Node Compare',0,1) WITH NOWAIT;
		IF OBJECT_ID('tempdb..#SR_RemoteServer') IS NULL
			CREATE TABLE #SR_RemoteServer([Server] sysname NOT NULL,Property VARCHAR(4000),[Value] VARCHAR(4000));
		DELETE FROM #SR_RemoteServer;
		DECLARE @RemoteServer VARCHAR(4000) ;
		DECLARE @RemoteProp TABLE([Server] sysname NOT NULL,Property VARCHAR(4000),[Value] VARCHAR(4000));
		DECLARE @PathcmdFile NVARCHAR(2048);
		DECLARE @NoOutput TABLE (ID INT);
		DECLARE @files TABLE (ID int IDENTITY(1,1), [FileName] VARCHAR(100))
		IF OBJECT_ID('tempdb..#Nodes') IS NOT NULL
			DROP TABLE #Nodes;
			CREATE TABLE #Nodes(NodeName sysname,[Type] sysname);
	
			INSERT	#Nodes
			SELECT	NodeName,'SQL Cluster' [Type]
			FROM	sys.dm_os_cluster_nodes
			OPTION(RECOMPILE);
			if SERVERPROPERTY('IsHadrEnabled') = 1
				EXEC('INSERT    #Nodes
SELECT member_name,''AlwaysOn''
FROM   sys.dm_hadr_cluster_members
WHERE	member_type = 0
OPTION(RECOMPILE);');
		IF EXISTS(SELECT COUNT(1) FROM #Nodes HAVING COUNT(1) > 1)
		BEGIN
			DECLARE cuNode CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
			SELECT	NodeName
			FROM	#Nodes
			OPEN cuNode
			FETCH NEXT FROM cuNode INTO @RemoteServer
			WHILE @@FETCH_STATUS = 0
			BEGIN
				DELETE FROM @output;
				DELETE FROM @RemoteProp;
				--By powershell
				SET @Command = 'powershell.exe -noprofile -command "$servername = ''' + @RemoteServer + '''; invoke-command -computer $servername -scriptblock {[array]$wmiinfo = Get-WmiObject Win32_Processor; $cpu = ($wmiinfo[0].name);  $cores = ( $wmiinfo | Select SocketDesignation | Measure-Object ).count;  $NumberOfLogicalProcessors = ( $wmiinfo[0].NumberOfLogicalProcessors); $obj = New-Object Object; $obj | Add-Member Noteproperty CPU -value $cpu; $obj | Add-Member Noteproperty Cores -value $cores; $obj | Add-Member Noteproperty NumberOfLogicalProcessors -value $NumberOfLogicalProcessors; Write-Host ($obj | Format-List | Out-String);}"';
				INSERT @output
				EXEC master.sys.xp_cmdshell @Command;
				IF EXISTS(SELECT TOP 1 1 FROM @output WHERE line like '%is not recognized as an internal or external command%')
				BEGIN
					   DELETE FROM @output;
					   SET @Command = '%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\powershell.exe -noprofile -command "$servername = ''' + @RemoteServer + '''; invoke-command -computer $servername -scriptblock {[array]$wmiinfo = Get-WmiObject Win32_Processor; $cpu = ($wmiinfo[0].name);  $cores = ( $wmiinfo | Select SocketDesignation | Measure-Object ).count;  $NumberOfLogicalProcessors = ( $wmiinfo[0].NumberOfLogicalProcessors); $obj = New-Object Object; $obj | Add-Member Noteproperty CPU -value $cpu; $obj | Add-Member Noteproperty Cores -value $cores; $obj | Add-Member Noteproperty NumberOfLogicalProcessors -value $NumberOfLogicalProcessors; Write-Host ($obj | Format-List | Out-String);}"';
					   INSERT @output
					   EXEC master.sys.xp_cmdshell @Command;
				END
				IF NOT EXISTS(SELECT TOP 1 1 FROM @output WHERE line = 'The system cannot find the path specified.')
					AND NOT EXISTS(SELECT TOP 1 1 FROM @output WHERE line LIKE '%following error message : Access is denied%')
					INSERT	@RemoteProp
					SELECT	@RemoteServer [Server],
							LEFT(line,CHARINDEX(' ',line))[Property],
							RIGHT(line,CASE CHARINDEX(':',REVERSE(line)) WHEN 0 THEN 0 ELSE CHARINDEX(':',REVERSE(line))-1 END)[Value]
					FROM	@output
					WHERE	line IS NOT NULL
					OPTION(RECOMPILE);
				ELSE
					RAISERROR('Access is denied on login',16,1);
				IF EXISTS(SELECT TOP 1 1 FROM @RemoteProp)
				BEGIN
					INSERT	#SR_RemoteServer
					SELECT	Server ,
							Property ,
							Value
					FROM	@RemoteProp
				END
				DELETE FROM @RemoteProp;
				FETCH NEXT FROM cuNode INTO @RemoteServer;
			END
			CLOSE cuNode;
			DEALLOCATE cuNode;
		END
		DROP TABLE #Nodes;
		INSERT @DebugError VALUES  ('Node Compare',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Node Compare',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
        SET @PS = 'powershell.exe -noprofile -command "get-wmiobject win32_diskpartition | select name, startingoffset | foreach{$_.name+''|''+$_.startingoffset/1024+''*''}"';
----------------------------------------------
        BEGIN TRY
			DELETE FROM @output;
            INSERT @output EXEC xp_cmdshell @PS;
        END TRY
        BEGIN CATCH
			SET @ErrorLog = ERROR_MESSAGE();
			GOTO GTError;
        END CATCH;
		IF OBJECT_ID('tempdb..#SR_Offset') IS NOT NULL
			DROP TABLE #SR_Offset;
        SELECT  RTRIM(LTRIM(SUBSTRING(line, 1, CHARINDEX('|', line) - 1))) Volume,
                CONVERT(BIGINT,SO.StartingOffset/1024)  [MB] 
		INTO	#SR_Offset
        FROM    @output
                CROSS APPLY ( SELECT TOP 1
                                        RTRIM(LTRIM(SUBSTRING(line,
                                                            CHARINDEX('|',
                                                            line) + 1,
                                                            ( CHARINDEX('*',
                                                            line) - 1 )
                                                            - CHARINDEX('|',
                                                            line)))) AS StartingOffset
                            ) SO
        WHERE   line IS NOT NULL
                AND line LIKE '%Partition #0%'
                AND SO.StartingOffset != '1024'
        ORDER BY 1
		OPTION(RECOMPILE);
--------------------------------------------------------------------------------------------
	----------------------------------------------
	--cleanUP
        DELETE  FROM @output;
----------------------------------------------
	--Block Size
        SET @sql = 'wmic volume GET Caption, BlockSize';--inserting disk name, total space and free space value in to temporary table
	
        INSERT  @output EXEC xp_cmdshell @sql;
        DELETE  FROM @output
        WHERE   line IS NULL
                OR line IN ( '
', 'BlockSize  Caption                                            
' );
        IF OBJECT_ID('tempdb..#DriveLeter') IS NOT NULL
            DROP TABLE #DriveLeter;
        CREATE TABLE #DriveLeter
            (
                DriveLeter CHAR(3) NOT NULL
            );
        INSERT  #DriveLeter
                SELECT	DISTINCT
                        LEFT(MF.physical_name, 3)
                FROM    sys.master_files MF
		OPTION(RECOMPILE);
        IF OBJECT_ID('tempdb..#SR_BlockSize') IS NOT NULL
            DROP TABLE #SR_BlockSize;
        SELECT  DL.DriveLeter ,
                RTRIM(LTRIM(REPLACE(O.line, DL.DriveLeter, ''))) [BlockSize]
        INTO    #SR_BlockSize
        FROM    #DriveLeter DL
                LEFT JOIN @output O ON O.line LIKE '%' + DL.DriveLeter + '%'
		OPTION(RECOMPILE);
----------------------------------------------
--cleanUP
        DELETE  FROM @output;
----------------------------------------------
        IF OBJECT_ID('tempdb..#DrvLetter') IS NOT NULL
            DROP TABLE #DrvLetter;
		CREATE TABLE #DrvLetter (Drive VARCHAR(500))
		INSERT #DrvLetter
		EXEC xp_cmdshell 'wmic volume where drivetype="3" get caption, freespace, capacity, label'
		DELETE FROM #DrvLetter
		WHERE	Drive IS NULL OR len(Drive) < 4 OR Drive LIKE '%Capacity%'
				OR Drive LIKE  '%\\%\Volume%'
		SELECT	[Drive] = LEFT(LTRIM(a.[Line]),CHARINDEX(' ',LTRIM(a.[Line]))),
				CAST(LEFT(Drive,CHARINDEX(' ',Drive)) AS REAL)/1024/1024 [TotalSize]
				,Freesize = LEFT(LTRIM(b.[Line]),CHARINDEX(' ',LTRIM(b.[Line])))
				,VolumeName = RTRIM(LTRIM(REPLACE(LTRIM(b.[Line]), LEFT(LTRIM(b.[Line]),CHARINDEX(' ',LTRIM(b.[Line]))),'')))
		INTO	#VolumeName
		FROM	#DrvLetter
				CROSS APPLY (SELECT TOP 1 REPLACE(Drive, LEFT(Drive,CHARINDEX(' ',Drive)),'') [Line] )a
				CROSS APPLY (SELECT TOP 1 RTRIM(LTRIM(REPLACE(LTRIM([Line]), LEFT(LTRIM([Line]),CHARINDEX(' ',LTRIM([Line]))),''))) [Line])b
		OPTION(RECOMPILE);
		INSERT @DebugError VALUES  ('Drive Offset',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Drive Offset',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
----------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
        IF OBJECT_ID('tempdb..#SR_Volume') IS NOT NULL
            DROP TABLE #SR_Volume;
		IF OBJECT_ID('tempdb..#VolumDiskInfo') IS NULL
		CREATE TABLE #VolumDiskInfo
		(
		  volume_mount_point CHAR(3) ,
		  [available_bytes] BIGINT ,
		  [total_bytes] BIGINT)
		IF SERVERPROPERTY('productversion') > '10.50.2500.0'
		BEGIN
			INSERT #VolumDiskInfo
			SELECT  vs.volume_mount_point ,
					MIN(CAST(vs.available_bytes AS FLOAT)) available_bytes ,
					MAX(CAST(vs.total_bytes AS FLOAT)) total_bytes
			FROM    sys.master_files AS f 
					CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id) AS vs
			GROUP BY vs.volume_mount_point
			OPTION(RECOMPILE);
		END
		ELSE
		BEGIN
/*https://msdn.microsoft.com/en-us/library/hh223223(v=sql.105).aspx
sys.dm_os_volume_stats - Returns information about the operating system volume (directory) on which the specified databases and files are stored. Use this dynamic management function in SQL Server 2008 R2 SP1 and later versions to check the attributes of the physical disk drive or return available free space information about the directory. 	*/
			IF EXISTS( SELECT TOP 1 1 FROM sys.configurations WHERE [name] LIKE 'Ole Automation Procedures' AND value_in_use = 0 ) 
			BEGIN
				EXEC sp_configure 'Ole Automation Procedures', 1;
				RECONFIGURE;
				SET @olea = 1;
			END;
			IF OBJECT_ID('tempdb..#_DriveSpace') IS NOT NULL
				DROP TABLE #_DriveSpace;
			IF OBJECT_ID('tempdb..#_DriveInfo') IS NOT NULL
				DROP TABLE #_DriveInfo;
			DECLARE @Result INT ,
				@objFSO INT ,
				@Drv INT ,
				@cDrive VARCHAR(13) ,
				@Size VARCHAR(50) ,
				@Free VARCHAR(50) ,
				@Label VARCHAR(10);
			CREATE TABLE #_DriveSpace (
				  driveletter CHAR(1) NOT NULL ,
				  FreeSpace VARCHAR(10) NOT NULL);
			CREATE TABLE #_DriveInfo(
				  driveletter CHAR(1) ,
				  TotalSpace BIGINT ,
				  FreeSpace BIGINT ,
				  Label VARCHAR(10));
			INSERT #_DriveSpace EXEC master.dbo.xp_fixeddrives;
			-- Iterate through drive letters.
			DECLARE curdriveletters CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
				SELECT  driveletter
				FROM    #_DriveSpace;
			DECLARE @driveletter CHAR(1);
			OPEN curdriveletters;
			FETCH NEXT FROM curdriveletters INTO @driveletter;
			WHILE ( @@fetch_status <> -1 )
				BEGIN
					IF ( @@fetch_status <> -2 )
						BEGIN
							SET @cDrive = 'GetDrive("' + @driveletter + '")'; 
							EXEC @Result = sp_OACreate 'Scripting.FileSystemObject', @objFSO OUTPUT; 
							IF @Result = 0 EXEC @Result = sp_OAMethod @objFSO, @cDrive, @Drv OUTPUT; 
							IF @Result = 0 EXEC @Result = sp_OAGetProperty @Drv, 'TotalSize', @Size OUTPUT; 
							IF @Result = 0 EXEC @Result = sp_OAGetProperty @Drv, 'FreeSpace', @Free OUTPUT; 
							IF @Result = 0 EXEC @Result = sp_OAGetProperty @Drv, 'VolumeName', @Label OUTPUT; 
							IF @Result <> 0 EXEC sp_OADestroy @Drv; 
							EXEC sp_OADestroy @objFSO; 
							INSERT  INTO #_DriveInfo
							VALUES  ( @driveletter, @Size, @Free, @Label );
						END;
					FETCH NEXT FROM curdriveletters INTO @driveletter;
				END;
			CLOSE curdriveletters;
			DEALLOCATE curdriveletters;
			INSERT	#VolumDiskInfo
			SELECT  driveletter + ':\' AS volume_mount_point ,
					FreeSpace AS [available_bytes],
					TotalSpace AS [total_bytes] 
			FROM    #_DriveInfo
			ORDER BY [driveletter] ASC;	
			DROP TABLE #_DriveSpace;
			DROP TABLE #_DriveInfo;
		END
        SELECT  vs.volume_mount_point ,
				MIN(CAST(vs.available_bytes AS FLOAT)) available_bytes ,
				MAX(CAST(vs.total_bytes AS FLOAT)) total_bytes,
                BS.DriveLeter ,
                BS.BlockSize,
				VN.VolumeName
        INTO    #SR_Volume
        FROM    (SELECT	DISTINCT LEFT(physical_name,3)physical_name
                FROM	sys.master_files) AS f
                CROSS APPLY (SELECT TOP 1 * FROM #VolumDiskInfo VDI WHERE f.physical_name = VDI.volume_mount_point) AS vs
                LEFT JOIN #SR_BlockSize BS ON BS.DriveLeter = vs.volume_mount_point
				LEFT JOIN #VolumeName VN ON VN.Drive = vs.volume_mount_point
		GROUP BY vs.volume_mount_point,BS.DriveLeter ,
                BS.BlockSize,
				VN.VolumeName
		OPTION(RECOMPILE);
        DROP TABLE #SR_BlockSize;
        DROP TABLE #DriveLeter;
		DROP TABLE #VolumeName;
		INSERT @DebugError VALUES  ('Volume',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Volume',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Versions Bugs',0,1) WITH NOWAIT;
		--#VersionsBugs
		DELETE FROM @output;
		DECLARE @cmdshellcommand VARCHAR(255)
		SET @cmdshellcommand = 'dir "%SystemRoot%\system32\config\software"'
		INSERT INTO @output
		EXEC master.dbo.xp_cmdshell @cmdshellcommand;
		CREATE TABLE #SR_VersionBug(Version NVARCHAR(30) NOT NULL,
		Detail NVARCHAR(MAX) NULL,
		IntDetail INT NULL);
		INSERT	#SR_VersionBug
		SELECT	CONVERT(NVARCHAR(30),SERVERPROPERTY('productversion')) Version,
				'msiexec' Detail,
				FileSize.GB IntDetail
		FROM    @output
				CROSS APPLY (SELECT LTRIM(
						REPLACE(
							SUBSTRING(line, CHARINDEX(')', line) + 1, LEN(line))
						, ',', '')
					) TrimLine) TL
				CROSS APPLY (SELECT CONVERT (INT,CONVERT (INT,SUBSTRING(TL.TrimLine,0,CHARINDEX(' ', TL.TrimLine)))/1048576.0/128) GB)FileSize
		WHERE   line LIKE '%File(s)%bytes'
				AND SERVERPROPERTY('productversion') BETWEEN '11.0.3000.0' AND '11.00.3513.0';
		INSERT @DebugError VALUES  ('Versions Bugs',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Versions Bugs',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Database Files',0,1) WITH NOWAIT;
		DECLARE @cmdSQL NVARCHAR(MAX);  
		IF OBJECT_ID('tempdb..##Results') IS NOT NULL
			DROP TABLE ##Results;
		IF OBJECT_ID('tempdb..#SR_DatabaseFiles') IS NULL 
		CREATE TABLE #SR_DatabaseFiles
					(
						[DatabaseName] VARCHAR(200) NULL,
						[FileName] VARCHAR(1000) NULL,
						[PhysicalName] NVARCHAR(260) NULL,
						[FileType] VARCHAR(15) NULL,
						[databaseid] INT NULL,
						[fileid] INT NULL,
						[TotalSize] INT NULL,
						[FreeSpace] INT NULL,
						[GrowthUnits] VARCHAR(15) NULL,
						[MaxSize] INT NULL,
						FGid INT NULL,
						FGName sysname NULL,
						FGType sysname NULL,
						FGDefault INT NULL
					);  
	CREATE TABLE ##Results ([Database Name] varchar(200) NULL, [File Name] varchar(1000) NULL,[Available Space in Mb] INT NULL,FG_Name sysname NULL,FG_Type sysname NULL,FG_Default int NULL)  
   
	SELECT @cmdSQL =    
'USE [?] INSERT INTO ##Results([Database Name], [File Name],[Available Space in Mb],FG_Name, FG_Type, FG_Default )    
SELECT	DB_NAME(),   
		fil.[name] AS [File Name],
		CASE ceiling(fil.[size]/128)   
		WHEN 0 THEN (1 - CAST(FILEPROPERTY(fil.[name], ''SpaceUsed''' + ') as int) /128)   
		ELSE (([size]/128) - CAST(FILEPROPERTY(fil.[name], ''SpaceUsed''' + ') as int) /128)   
		END AS [Available Space in Mb],
		fg.name,fg.type_desc,fg.is_default
FROM	sys.database_files fil
		LEFT JOIN sys.data_spaces fg ON fil.data_space_id = fg.data_space_id
OPTION(RECOMPILE);'   
	--Run the command against each database (IGNORE OFF-LINE DB)
	EXEC sp_MSforeachdb @cmdSQL   
	INSERT	#SR_DatabaseFiles
	SELECT	D.name [DatabaseName],MF.name [File Name],MF.physical_name [Physical Name],
			CASE MF.type_desc 
			WHEN 'ROWS' THEN 'Data'
			WHEN 'LOG' THEN 'Log'
			WHEN 'FILESTREAM' THEN 'FileStream'
			WHEN 'FULLTEXT' THEN 'FullText'
			ELSE 'Unknowen' END  [File Type],
			D.database_id,
			MF.file_id,
			MF.size * 8 / 1024 [Total Size in Mb],
			R.[Available Space in Mb],
			CONVERT(VARCHAR(25),CASE WHEN MF.is_percent_growth = 1 THEN MF.growth ELSE MF.growth * 8 / 1024 END) + CASE WHEN MF.is_percent_growth = 1 THEN '%' ELSE 'MB' END,
			CASE WHEN MF.max_size = -1 OR MF.max_size = 268435456 THEN NULL ELSE CONVERT(VARCHAR(25),MF.max_size) END [Max File Size in MB],
			MF.data_space_id,
			R.FG_Name,R.FG_Type,R.FG_Default
	FROM	sys.databases D
			INNER JOIN sys.master_files MF ON MF.database_id = D.database_id
			LEFT JOIN ##Results R ON D.name = R.[Database Name] AND R.[File Name] = MF.name
	OPTION(RECOMPILE);
		INSERT @DebugError VALUES  ('Database Files',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Database Files',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------------------------------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @debug = 1 RAISERROR ('Collect Database Errors',0,1) WITH NOWAIT;
		IF OBJECT_ID('tempdb..#Users') IS NOT NULL DROP TABLE #Users;
		CREATE TABLE #Users
			(
				DatabaseName sysname ,
				Type NVARCHAR(260) ,
				sid NVARCHAR(MAX) ,
				UserName sysname
			);
		EXEC sp_MSforeachdb '
INSERT #Users
SELECT ''[?]'',dp.type_desc, convert(nvarchar(max),dp.SID,1), dp.name AS user_name  
FROM   [?].sys.database_principals dp  
       LEFT JOIN sys.server_principals sp ON dp.SID = sp.SID  
WHERE	sp.SID IS NULL  
		AND dp.type_desc = ''SQL_USER''
		AND dp.SID IS NOT NULL
OPTION(RECOMPILE);';
IF OBJECT_ID('tempdb..#DBCCRes') IS NULL 
		CREATE TABLE #DBCCRes
        (
            id INT IDENTITY(1, 1)
                    PRIMARY KEY CLUSTERED ,
            DBName VARCHAR(500) ,
            dbccLastKnownGood DATETIME ,
            RowNum INT
        );
IF OBJECT_ID('tempdb..#temp') IS NOT NULL
	DROP TABLE #temp;
    CREATE TABLE #temp
        (
            id INT IDENTITY(1, 1) ,
            ParentObject VARCHAR(255) ,
            [OBJECT] VARCHAR(255) ,
            Field VARCHAR(255) ,
            [VALUE] VARCHAR(255)
        );
 
    DECLARE @DBName sysname ,
			@SQLcmd VARCHAR(4000);
 
    DECLARE dbccpage CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
        SELECT  name
        FROM    sys.databases
        WHERE   state = 0
                AND database_id NOT IN (2,DB_ID())
		OPTION(RECOMPILE);
 
    OPEN dbccpage;
    FETCH NEXT FROM dbccpage INTO @DBName;
    WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @SQLcmd = 'Use [' + @DBName + '];' + CHAR(10) + CHAR(13);
            SET @SQLcmd = @SQLcmd + 'DBCC Page ( [' + @DBName + '],1,9,3) WITH TABLERESULTS,NO_INFOMSGS;' + CHAR(10) + CHAR(13);
 
            INSERT  INTO #temp EXECUTE ( @SQLcmd);
            SET @SQLcmd = '';
 
            INSERT  INTO #DBCCRes ( DBName , dbccLastKnownGood , RowNum)
            SELECT  @DBName ,
                    [VALUE] ,
                    ROW_NUMBER() OVER ( PARTITION BY Field ORDER BY [VALUE] ASC) AS Rownum
            FROM    #temp
            WHERE   Field = 'dbi_dbccLastKnownGood'
			OPTION(RECOMPILE);
 
            TRUNCATE TABLE #temp;
 
            FETCH NEXT FROM dbccpage INTO @DBName;
        END;
    CLOSE dbccpage;
    DEALLOCATE dbccpage;
	
    DROP TABLE #temp;
	IF OBJECT_ID('tempdb..#Backup') IS NOT NULL DROP TABLE #Backup;
		CREATE TABLE #Backup
                (
                    DatabaseName sysname ,
                    [LastBackUpTime] VARCHAR(50) ,
                    [Type] CHAR(1) ,
                    physical_device_name NVARCHAR(1000)
                );
	IF OBJECT_ID('tempdb..#WitchDBtoCheck') IS NOT NULL DROP TABLE #WitchDBtoCheck;
	CREATE TABLE #WitchDBtoCheck(DatabaseName sysname NOT NULL,
	LastBackUpTime DATETIME NOT NULL,
	[Type] CHAR(1) NULL);
	
	SELECT @cmd = N'
INSERT	#WitchDBtoCheck
SELECT  sdb.name AS DatabaseName ,
		MAX(ISNULL(bus.backup_finish_date, 0)) AS LastBackUpTime ,
		bus.type AS Type
FROM    sys.databases sdb
		LEFT JOIN msdb..backupset bus ON bus.database_name = sdb.name
		LEFT JOIN sys.database_mirroring dm ON sdb.database_id = dm.database_id
WHERE   sdb.database_id NOT IN (2,DB_ID())
		AND sdb.source_database_id IS NULL ---Exclude Snapshots
		AND (dm.mirroring_role = 1 OR mirroring_guid IS NULL) --Not mirror
		AND sdb.state <> 6 -- not offline
		AND ((sdb.recovery_model = 3 AND ISNULL(bus.type,''D'') = ''D'') OR (sdb.recovery_model <> 3))
		' + CASE WHEN @@VERSION LIKE 'Microsoft SQL Server 201%' THEN N'AND sys.fn_hadr_backup_is_preferred_replica (sdb.name) != 0' ELSE N'' END+ N'
GROUP BY  sdb.name , bus.type
OPTION(RECOMPILE);';
	EXEC sp_executesql @cmd;
	INSERT #Backup
    SELECT  t1.DatabaseName ,
            CONVERT(VARCHAR(50), t1.LastBackUpTime, 101) AS LastBackUpTime ,
            t1.Type ,
            t2.physical_device_name
    FROM    #WitchDBtoCheck t1
            LEFT JOIN ( SELECT   sd.name AS database_name ,
                            ISNULL(bu.backup_finish_date, 0) AS BackupDate ,
                            bmf.physical_device_name
                    FROM    sys.databases AS sd
                            LEFT JOIN msdb..backupset bu ON bu.database_name = sd.name
								AND bu.is_copy_only = 0
                            LEFT JOIN msdb..backupmediafamily bmf ON bu.media_set_id = bmf.media_set_id
                    ) t2 ON t1.DatabaseName = t2.database_name
                            AND t1.LastBackUpTime = t2.BackupDate;
SELECT	CONVERT(sysname,'Backup') [Type],CONVERT(sysname,DatabaseName) [DatabaseName],CONVERT(NVARCHAR(max),'Backup ' + 
		CASE WHEN T.[Type] IS NULL THEN 'has yet run on this DB' ELSE 
		CASE T.[Type] 
			WHEN 'D' THEN 'type - Data' 
			WHEN 'L' THEN 'type - Log' 
			WHEN 'I' THEN 'type - Data-Diff' 
			ELSE 'N' 				
			END  +' was last backedup at - '+ 
		CASE WHEN LastBackUpTime ='01/01/1900'
			then 'never'
			else ISNULL(LastBackUpTime,'')
		END END)as  [Note],
		CONVERT(NVARCHAR(MAX),NULL)[Link]
INTO	#SR_DBProp
FROM	(SELECT	*,ROW_NUMBER() OVER(PARTITION BY LB.DatabaseName,LB.[Type] ORDER BY LB.LastBackUpTime DESC) RN
    	 FROM	#Backup LB
				INNER JOIN sys.databases DI ON LB.DatabaseName = DI.name
		 WHERE	LB.LastBackUpTime < DATEADD(DAY,-2,GETDATE())
				AND ((LB.[Type] = 'D' AND DI.recovery_model_desc = 'SIMPLE') OR (DI.recovery_model_desc IN ('FULL','BULK-LOGGED')))
				
		 )T
WHERE	T.RN = 1
UNION ALL 
SELECT	'Index Size' [Type],DatabaseName [Database Name],IndexIssue,'https://technet.microsoft.com/en-us/library/ms163207(v=sql.105).aspx' [Link]
FROM	@IndexSize
UNION ALL 
SELECT	'CheckDB'[Type],DBName [Database Name],CASE WHEN dbccLastKnownGood = '1900-01-01 00:00:00.000' THEN 'CheckDB never run on this db' ELSE 'The DB has it last check on- ' + CONVERT(VARCHAR(25),dbccLastKnownGood,3) END [Note],CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM	#DBCCRes
WHERE	DATEDIFF(DAY,dbccLastKnownGood,GETDATE()) > 7
UNION ALL 
SELECT  'User',U.DatabaseName,'Login ' + QUOTENAME(SP.name) + ' Have a different sid for the user',CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM    sys.server_principals SP
        INNER JOIN #Users U ON U.UserName = SP.name
WHERE   SP.sid != U.sid
UNION ALL 
SELECT 'PAGE VERIFY'[Type],db.name [Database Name],N'Change PAGE_VERIFY to CHECKSUM.' [Note],CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM	sys.databases db
WHERE	db.state = 0
		AND db.is_read_only = 0
		AND db.page_verify_option != 2
		AND db.database_id > 4
UNION ALL
SELECT  'File Growth'[Type],db.name as [Database Name],N'Change database file growth to Megabyte.',CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM    sys.databases db
        CROSS APPLY (SELECT TOP 1 1 [Ex] FROM sys.master_files mf WHERE mf.database_id = db.database_id AND mf.is_percent_growth = 1)mf
WHERE   db.state = 0
		AND db.is_read_only = 0
UNION ALL
SELECT  'File Growth'[Type],db.name as [Database Name],N'Change database file growth more then 1 Megabyte.',CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM    sys.databases db
        CROSS APPLY (SELECT TOP 1 1 [Ex] FROM sys.master_files mf WHERE mf.database_id = db.database_id AND mf.is_percent_growth = 0 AND mf.growth = 128)mf
WHERE   db.state = 0
		AND db.is_read_only = 0
UNION ALL
SELECT  'AUTO SHRINK'[Type],db.name,N'Turn off AUTO_SHRINK ' AS [Note],CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM    sys.databases db
WHERE	db.state = 0
		AND db.is_read_only = 0
		AND is_auto_shrink_on = 1
UNION ALL
SELECT  'CURSOR_DEFAULT'[Type],db.name,N'Change CURSOR_DEFAULT to LOCAL' AS [Note],CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM    sys.databases db
where	db.state = 0
		AND db.is_read_only = 0
		AND is_local_cursor_default = 0
UNION ALL
SELECT  'Auto Create Statistics'[Type],db.name,N'Turn on AUTO_CREATE_STATISTICS' AS [Note],CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM    sys.databases db
where	db.state = 0
		AND db.is_read_only = 0
		AND is_auto_create_stats_on = 0
		AND db.name NOT IN(SELECT DatabaseName FROM	@DB_Exclude)
UNION ALL
SELECT  'Auto Create Statistics'[Type],db.name,N'Turn off AUTO_CREATE_STATISTICS' AS [Note],CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM    sys.databases db
where	db.state = 0
		and db.is_read_only = 0
		AND is_auto_create_stats_on = 1
		AND db.name IN(SELECT DatabaseName FROM	@DB_Exclude)
UNION ALL
SELECT  'Auto Updtae Statistics'[Type],db.name,N'Turn on AUTO_UPDATE_STATISTICS' AS [Note],CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM    sys.databases db
where	db.state = 0
		and db.is_read_only = 0
		AND is_auto_update_stats_on = 0
		AND db.name NOT IN(SELECT DatabaseName FROM	@DB_Exclude)
UNION ALL
SELECT  'Auto Updtae Statistics'[Type],db.name,N'Turn off AUTO_UPDATE_STATISTICS' AS [Note],CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM    sys.databases db
where	db.state = 0
		and db.is_read_only = 0
		AND is_auto_update_stats_on = 1
		AND db.name IN(SELECT DatabaseName FROM	@DB_Exclude)
UNION ALL 
SELECT	'Recovery Model' [Type],db.name [name],'Set the recovery model of the Model database to SIMPLE'[Note],'https://dbaeyes.wordpress.com/2011/08/18/hooray-you-finished-installing-sql-server-now-what/'[Link] 
FROM	sys.databases db
WHERE	db.database_id = 3
		AND db.recovery_model = 1
UNION ALL 
SELECT 'User objects in system DB' [Type],'master' [name],N'system DB have ' + CONVERT(VARCHAR(25),COUNT_BIG(1)) + ' "' + CASE type 
              WHEN 'P' THEN 'user stored procedures' 
              WHEN 'U' THEN 'user tables' 
              WHEN 'V' THEN 'views' 
              WHEN 'TF' THEN 'user table valued function' 
              WHEN 'FN' THEN 'user define function' 
              WHEN 'TT' THEN 'user table type' 
              ELSE type_desc COLLATE DATABASE_DEFAULT END + '".
Clean user objects from master.'AS [Note],CONVERT(NVARCHAR(MAX),NULL)[Link]
FROM   [master].sys.objects o
WHERE  type NOT IN ('s','pk','d','f','SQ','UQ','it')
              AND is_ms_shipped <> 1
              AND o.name NOT IN ('sp_Blitz','sp_WhoIsActive','sp_dba_ForEachDB','sp_BlitzFirst','')
GROUP BY type_desc,type
HAVING  COUNT_BIG(1)  > 10
ORDER BY 2,1
OPTION(RECOMPILE);
 
 -- Memory Optimize Tables Check by Maxim Shmidt(NAYA)
    IF ( SELECT SERVERPROPERTY('ProductMajorVersion')) >= '12'
    BEGIN   
        IF OBJECT_ID('tempdb..#DBName') IS NOT NULL DROP TABLE #DBName;
        CREATE TABLE #DBName
            (
                ID INT IDENTITY(1, 1) ,
                [Name] NVARCHAR(128)
            );
        SET @cmd = ( SELECT 'union all 
		SELECT TOP 1 ''' + D.name + ''' as DatabaseName
		FROM ' + QUOTENAME(D.name) + '.sys.tables as t
		WHERE t.is_memory_optimized=1
		'
                        FROM   sys.databases AS D
						WHERE	D.state = 0
								AND D.is_read_only = 0
        FOR XML PATH('') ,
                TYPE).value('substring((./text())[1], 13)',
                            'nvarchar(max)');
		--print @cmd
        INSERT  INTO #DBName EXEC (@cmd);
        IF EXISTS ( SELECT TOP 1 1 FROM #DBName )
        BEGIN 
            DECLARE @stop INT; 
			SELECT TOP 1 @stop = ID
            FROM      #DBName
            ORDER BY ID DESC;
			DECLARE @count INT = 1 ;
            WHILE @count < @stop
            BEGIN 
				
                SELECT  @cmd = N'
INSERT #SR_DBProp
SELECT	''Memory-Optimized DB'' AS [Type] ,''' + DB.Name + ''',
		CASE	WHEN FLOOR((CAST(empty_bucket_count AS FLOAT) / total_bucket_count) * 100) < 0.1	-- number of empty buckets is less than 10 percent of the total number of buckets
				THEN ''Total number of buckets in the "''+ i.name+''" in "'''
                    + '+''' + DB.Name
                    + '.''+s.name + ''.'' + t.name+''" hash index is too low. Ideally, at least 33 percent of the buckets in the index should be empty''
				WHEN hs.avg_chain_length > 10 AND (FLOOR((CAST(empty_bucket_count AS FLOAT) / total_bucket_count) * 100)) > 0.1
				THEN ''For Hash Index "''+ i.name+''" in "'''
                    + '+''' + DB.Name
                    + '.''+s.name + ''.'' + t.name+''" There are many duplicate index key values and a nonclustered index would be more appropriate''
				WHEN (hs.avg_chain_length BETWEEN 0 AND 10) AND (FLOOR((CAST(empty_bucket_count AS FLOAT) / total_bucket_count) * 100)) > 0.1
				THEN ''Bucket count for Hash Index "''+ i.name+''" in "'''
                    + '+''' + DB.Name
                    + '.''+s.name + ''.'' + t.name+''" is likely to be too high, less than 10% is in use. Every bucket uses 8 bytes of memory whether it is empty or not.''
				END AS [Message]
		, ''https://msdn.microsoft.com/en-us/library/dn494956(v=sql.120).aspx'' AS [Link]
FROM	' + DB.Name + '.sys.dm_db_xtp_hash_index_stats AS hs
		INNER JOIN ' + DB.Name
                    + '.sys.indexes AS i ON hs.object_id = i.object_id
			AND hs.index_id = i.index_id
		INNER JOIN ' + DB.Name
                    + '.sys.tables t ON t.object_id =  hs.object_id
		INNER JOIN ' + DB.Name
                    + '.sys.schemas s ON s.schema_id = t.schema_id
OPTION(RECOMPILE);'
            FROM    #DBName DB
            WHERE   DB.ID = @count
			OPTION(RECOMPILE);
                EXEC sys.sp_executesql @cmd;
                SELECT  @cmd = N'
INSERT	#SR_DBProp
SELECT  t.[Type], t.[dbName],t.[Message],t.[Link]
FROM
		(SELECT ''Memory-Optimized DB'' AS [Type] ,''' + DB.Name + '''[dbName],
			CASE	WHEN FLOOR(st.rows_returned / NULLIF(st.scans_started,0) ) > 100 
					THEN ''Heavy index scans noticed for "''+ i.name+''" in "'''
                    + '+''' + DB.Name
                    + '.''+s.name + ''.'' + t.name+''" table, that can be the sign of a suboptimal indexing strategy and/or poorly written queries.''
					WHEN FLOOR(st.scans_started  / NULLIF(st.rows_returned,0) ) > 10
					THEN ''Workload "''+ i.name+''" in "'''
                    + '+''' + DB.Name
                    + '.''+s.name + ''.'' + t.name+''" table is insert-heavy, or point lookups failed to locate a row.''
					END AS [Message]
			, NULL AS [Link]
		FROM	' + DB.Name + '.sys.dm_db_xtp_index_stats st 
			INNER JOIN ' + DB.Name
                    + '.sys.tables t ON st.object_id = t.object_id
			INNER JOIN ' + DB.Name
                    + '.sys.indexes i ON st.object_id = i.object_id 
				AND	st.index_id = i.index_id
			INNER JOIN ' + DB.Name
                    + '.sys.schemas s ON s.schema_id = t.schema_id
			)t
WHERE t.Message is NOT NULL
OPTION(RECOMPILE);'
                FROM    #DBName DB
                WHERE   DB.ID = @count
				OPTION(RECOMPILE);
                EXEC sys.sp_executesql @cmd;
                SELECT  @cmd = N'
INSERT #SR_DBProp
SELECT TOP 1 ''Memory-Optimized DB'' AS [Type] ,''' + DB.Name + '''[dbName], N''The database "' + DB.Name
                + '" has Memory-optimized tables and the Resource Governor is not configured as expected.'' AS [Message]
		, ''http://msdn.microsoft.com/en-us/library/dn465873.aspx'' AS [Link]
FROM ' + DB.Name + '.sys.data_spaces 
WHERE type=''FX''
	AND EXISTS (select TOP 1 1 from ' + DB.Name
                + '.sys.tables where is_memory_optimized=1)-- Are there Memory-optimized tables in the DB
	AND (NOT EXISTS (select TOP 1 1 FROM ' + DB.Name
                + '.sys.databases d inner join sys.resource_governor_resource_pools p on d.resource_pool_id=p.pool_id and p.name <> ''default'' and d.name=DB_NAME()) -- Id the DB bounded to a RP?
		OR NOT EXISTS (select TOP 1 1 from ' + DB.Name
                + '.sys.resource_governor_configuration WHERE  is_enabled = 1))
OPTION(RECOMPILE);'
                FROM    #DBName DB
                WHERE   DB.ID = @count
				OPTION(RECOMPILE);
                EXEC sys.sp_executesql @cmd;
                SET @count = @count + 1;
            END; 
			
        END; 
	END; 
		INSERT @DebugError VALUES  ('Database Error',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Database Error',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		IF @MajorVersion > 1050 AND SERVERPROPERTY('IsHadrEnabled') = 1--2012
		BEGIN
			EXEC('
INSERT	#SR_DBProp
SELECT  ''SharePoint database''[Type],D.name [dbName],CONCAT(''Availability group - '',ag.name,'' conteins '',D.name,'' on asynchronous mode. SharePoint does not support this mode on this DB type.'')[Message], ''https://technet.microsoft.com/en-us/library/jj841106.aspx''[Link]
FROM    sys.availability_groups AS ag
        INNER JOIN sys.availability_replicas AS ar ON ag.group_id = ar.group_id
        INNER JOIN sys.dm_hadr_availability_replica_states AS ar_state ON ar.replica_id = ar_state.replica_id
        INNER JOIN sys.dm_hadr_database_replica_states dr_state ON ag.group_id = dr_state.group_id AND dr_state.replica_id = ar_state.replica_id
              INNER JOIN sys.databases D ON D.database_id = dr_state.database_id
WHERE  (D.name LIKE ''Search[_]Service[_]Application[_]DB[_]%''
              OR D.name LIKE ''SharePoint[_]Admin[_]Content%''
              OR D.name LIKE ''SharePoint[_]Config%''
              OR D.name LIKE ''Search[_]Service[_]Application[_]AnalyticsReportingStoreDB[_]%''
              OR D.name LIKE ''Search[_]Service[_]Application[_]CrawlStoreDB[_]%''
              OR D.name LIKE ''Search[_]Service[_]Application[_]LinkStoreDB[_]%''
              OR D.name LIKE ''SharePoint[_]Logging%''
              OR D.name LIKE ''Application[_]SyncDB[_]%''
              OR D.name LIKE ''SessionStateService[_]%''
              
              )
              AND ar.availability_mode = 0
OPTION(RECOMPILE);');
		END
		INSERT @DebugError VALUES  ('SharePoint HADR',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('SharePoint HADR',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		DECLARE cuMaxIdent CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
			SELECT  name
			FROM    sys.databases
			WHERE   state = 0
					AND database_id NOT IN (2,1)
			OPTION(RECOMPILE);
 
    OPEN cuMaxIdent;
    FETCH NEXT FROM cuMaxIdent INTO @DBName;
    WHILE @@FETCH_STATUS = 0
    BEGIN
	SET @cmd = N'USE ' + QUOTENAME(@DBName) + ';
	DECLARE @Innercmd NVARCHAR(MAX);
    SELECT  @Innercmd = ISNULL(@Innercmd + '' Union All'' + CHAR(13), '''')
            + ''Select ''''MaxIdentity'''' [Type],DB_NAME() DB, '''''' +
                     OBJECT_SCHEMA_NAME(Cl.object_id) + ''.'' + T.name +
                     '''''' Object, ''''Column '' + Cl.name +
                     '''''' ObjectType, Ident_Current(''''['' +
                     OBJECT_SCHEMA_NAME(Cl.object_id) + ''].['' +
                     OBJECT_NAME(Cl.object_id) + '']'''') MaxIdentity, Case '''''' +
                     Tp.name +
                     '''''' When ''''int'''' Then 2147483647 
					 When ''''smallint'''' then 32767 
					 When ''''tinyint'''' Then 255 
					 When ''''bigint'''' Then  9223372036854775807 
					 Else Null End UpperLimit''
    FROM    sys.columns Cl
            INNER JOIN sys.types Tp ON Cl.system_type_id = Tp.system_type_id
                                       AND Cl.user_type_id = Tp.user_type_id
            INNER JOIN sys.tables T ON Cl.object_id = T.object_id
    WHERE   Tp.name IN ( ''int'', ''smallint'', ''bigint'', ''tinyint'' )
            AND Cl.is_identity = 1
	OPTION(RECOMPILE);
	
    IF ( SELECT SERVERPROPERTY(''ProductMajorVersion'')) >= ''11''
    SET @Innercmd = @Innercmd + '' Union All'' + CHAR(13) + ''Select ''''MaxIdentity'''' [Type],DB_NAME() DB, Schema_Name(S.schema_id) + ''''.'''' + S.name Object, ''''Sequence'''' ObjectType, S.current_value MaxIdentity, S.maximum_value UpperLimit From	sys.sequences S Inner Join sys.types Tp On S.system_type_id=Tp.system_type_id And S.user_type_id=Tp.user_type_id Where	Tp.name=''''int'''''';
    SET @Innercmd = ''With T As'' +  CHAR(13) +  ''('' +  @Innercmd + '')'' + CHAR(13) +
                      ''INSERT #SR_DBProp
					  Select [Type],DB,''''Table '''' + T.Object + '''' on '''' + ObjectType + '''' limit identity is '''' + convert(varchar(50),MaxIdentity) + ''''/'''' +  convert(varchar(50),UpperLimit), NULL [Link] From T 
					  WHERE Cast(MaxIdentity As Float)/Cast(UpperLimit As Float) > 0.8
					  Order By Cast(MaxIdentity As Float)/Cast(UpperLimit As Float) Desc;'';
	EXEC(@Innercmd);
	';
	EXEC (@cmd);
            FETCH NEXT FROM cuMaxIdent INTO @DBName;
        END;
    CLOSE cuMaxIdent;
    DEALLOCATE cuMaxIdent;
		INSERT @DebugError VALUES  ('Max Ident',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Max Ident',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------
	BEGIN TRY
		SET @DebugStartTime = GETDATE();
		EXEC dbo.sp_MSforeachdb 'USE [?];
IF EXISTS(SELECT TOP 1 1 [Ex] FROM [?].sys.foreign_keys i WHERE i.is_not_trusted = 1 AND i.is_not_for_replication = 0 AND i.is_disabled = 0
UNION ALL SELECT TOP 1 1 [Ex] FROM sys.check_constraints i WHERE i.is_not_trusted = 1 AND i.is_not_for_replication = 0 AND i.is_disabled = 0)
BEGIN
	INSERT #SR_DBProp
SELECT ''Untrusted Constraints'' AS [Type] ,''?''[dbName], N''The database has untrusted constraints.'' AS [Message]
		, ''http://sqlblog.com/blogs/tibor_karaszi/archive/2008/01/12/non-trusted-constraints-and-performance.aspx'' AS [Link]
END';
		INSERT @DebugError VALUES  ('Untrusted Constraints',NULL,DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END TRY
	BEGIN CATCH
		INSERT @DebugError VALUES  ('Untrusted Constraints',ERROR_MESSAGE(),DATEDIFF(SECOND,@DebugStartTime,GETDATE()));
	END CATCH
--------------------------------------------------------------------------------------------------------
IF @debug = 1 RAISERROR ('Collect HADR Services',0,1) WITH NOWAIT;
IF OBJECT_ID('tempdb..#SR_HADRServices') IS NOT NULL
	DROP TABLE #SR_HADRServices;
CREATE TABLE #SR_HADRServices([AlwaysOn] BIT ,[Replication] BIT,[LogShipping] BIT, [Mirror] BIT)
INSERT #SR_HADRServices
SELECT  ISNULL(CONVERT(BIT,SERVERPROPERTY('IsHadrEnabled')),0) [AlwaysOn] ,
        ISNULL(( SELECT TOP 1
                        1 [Rep]
                 FROM   sys.databases
                 WHERE  is_published = 1
                        OR is_subscribed = 1
                        OR is_merge_published = 1
                        OR is_distributor = 1
               ), 0) [Replication] ,
        ISNULL(( SELECT TOP 1
                        1 [LogShipping]
                 FROM   msdb..log_shipping_primary_databases
               ), 0) [LogShipping] ,
        ISNULL(( SELECT TOP 1
                        1 [Mirroring]
                 FROM   sys.databases A
                        INNER JOIN sys.database_mirroring B ON A.database_id = B.database_id
                 WHERE  A.database_id > 4
                        AND B.mirroring_state IS NOT NULL
               ), 0) [Mirror]
		OPTION(RECOMPILE); 
 
--------------------------------------------------------------------------------------------------------
IF @debug = 1 
BEGIN
    IF EXISTS(SELECT TOP 1 1 FROM #SR_HADRServices WHERE AlwaysOn = 1) RAISERROR ('Collect HADR - AlwaysOn State',0,1) WITH NOWAIT;
END
	IF OBJECT_ID('tempdb..#SR_HADRState') IS NOT NULL
		DROP TABLE #SR_HADRState;
CREATE TABLE #SR_HADRState(ID INT NOT NULL,msg NVARCHAR(MAX) NOT NULL);
IF @MajorVersion > 1050 AND SERVERPROPERTY('IsHadrEnabled') = 1--2012
BEGIN
EXEC('INSERT	#SR_HADRState
SELECT	1 ID,''Replica name - '' + QUOTENAME(member_name) + '' is '' + member_state_desc + '' ('' + convert(varchar(25),d.cnt) + ''/'' + convert(varchar(25),u.cnt) + '').''--,* 
FROM	sys.dm_hadr_cluster_members 
		outer apply (select count(1) cnt from sys.dm_hadr_cluster_members)u
		outer apply (select count(1) cnt from sys.dm_hadr_cluster_members where member_state = 0)d
WHERE	member_state != 1
UNION ALL 
SELECT	2,''Availability Group- '' + QUOTENAME(AG.name) + '' on the '' + CASE is_local WHEN 1 then ''local'' else '''' end + '' '' + lower(role_desc) + '' replica are '' + ISNULL(lower(operational_state_desc),''NOT online'') + '' and '' + case connected_state when 0 then connected_state_desc else lower(connected_state_desc) + '' in '' + synchronization_health_desc + '' sync state'' end + ''.''
FROM	sys.dm_hadr_availability_replica_states RS
		INNER JOIN sys.availability_groups AG ON AG.group_id = RS.group_id
WHERE	synchronization_health = 0
UNION ALL
SELECT	3,''listener '' + QUOTENAME(L.dns_name) + '' are '' + IP.state_desc 
FROM	sys.availability_group_listener_ip_addresses IP 
		INNER JOIN sys.availability_group_listeners L ON IP.listener_id = L.listener_id
WHERE	IP.state <> 1
		AND NOT EXISTS (SELECT TOP 1 1 
						FROM	sys.availability_group_listener_ip_addresses iIP 
								INNER JOIN sys.availability_group_listeners iL ON iIP.listener_id = iL.listener_id
						where	iIP.state = 1
								and iL.listener_id = L.listener_id)
UNION ALL
SELECT	distinct 4,''End Point are '' + state_desc  + '' on port - '' + convert(varchar(6),port)
FROM	sys.dm_tcp_listener_states 
WHERE	type = 2 
		AND state != 0 --ONLINE
OPTION(RECOMPILE);');
END
IF  @Mask = 1
BEGIN
	CREATE TABLE #HADR_Replica(member_name sysname,ReplicaID varchar(10))
	EXEC('INSERT	#HADR_Replica
SELECT	member_name,''Replica'' + CONVERT(VARCHAR(5),ROW_NUMBER() OVER(ORDER BY member_name ASC)) ReplicaID
FROM	sys.dm_hadr_cluster_members
OPTION(RECOMPILE);');
	UPDATE	hadr
	SET		msg = REPLACE(msg,member_name,ReplicaID)
	FROM	#SR_HADRState hadr
			INNER JOIN #HADR_Replica R  ON hadr.msg LIKE '%' + member_name + '%'
	OPTION(RECOMPILE);
END
--------------------------------------------------------------------------------------------------------
IF @debug = 1 
BEGIN
    IF EXISTS(SELECT TOP 1 1 FROM #SR_HADRServices WHERE AlwaysOn = 1) RAISERROR ('Collect HADR - AlwaysOn info',0,1) WITH NOWAIT;
END
IF OBJECT_ID('tempdb..#SR_HADR') IS NOT NULL
		DROP TABLE #SR_HADR;
CREATE TABLE #SR_HADR(
	replica_server_name	nvarchar(256)	null
	,database_name	sysname	null
	,ag_name	sysname	null
	,is_local	bit	null
	,synchronization_state_desc	nvarchar(60)	null
	,is_commit_participant	bit	null
	,synchronization_health_desc	nvarchar(60)	null
	,recovery_lsn	Numeric(25,0)	null
	,truncation_lsn	Numeric(25,0)	null
	,last_sent_lsn	Numeric(25,0)	null
	,last_sent_time	datetime	null
	,last_received_lsn	Numeric(25,0)	null
	,last_received_time	datetime	null
	,last_hardened_lsn	Numeric(25,0)	null
	,last_hardened_time	datetime	null
	,last_redone_lsn	Numeric(25,0)	null
	,last_redone_time	datetime	null
	,log_send_queue_size	bigint	null
	,log_send_rate	bigint	null
	,redo_queue_size	bigint	null
	,redo_rate	bigint	null
	,filestream_send_rate	bigint	null
	,end_of_log_lsn	Numeric(25,0)	null
	,last_commit_lsn	Numeric(25,0)	null
	,last_commit_time	datetime	NULL);
IF @MajorVersion > 1050 AND SERVERPROPERTY('IsHadrEnabled') = 1--2012
BEGIN
	EXEC('INSERT	#SR_HADR
SELECT  ar.replica_server_name ,
        adc.database_name ,
        ag.name AS ag_name ,
        drs.is_local ,  
        drs.synchronization_state_desc ,
        drs.is_commit_participant ,
        drs.synchronization_health_desc ,
        drs.recovery_lsn ,
        drs.truncation_lsn ,
        drs.last_sent_lsn ,
        drs.last_sent_time ,
        drs.last_received_lsn ,
        drs.last_received_time ,
        drs.last_hardened_lsn ,
        drs.last_hardened_time ,
        drs.last_redone_lsn ,
        drs.last_redone_time ,
        drs.log_send_queue_size ,
        drs.log_send_rate ,
        drs.redo_queue_size ,
        drs.redo_rate ,
        drs.filestream_send_rate ,
        drs.end_of_log_lsn ,
        drs.last_commit_lsn ,
        drs.last_commit_time
FROM    sys.dm_hadr_database_replica_states AS drs
        INNER JOIN sys.availability_databases_cluster AS adc ON drs.group_id = adc.group_id AND drs.group_database_id = adc.group_database_id
        INNER JOIN sys.availability_groups AS ag ON ag.group_id = drs.group_id
        INNER JOIN sys.availability_replicas AS ar ON drs.group_id = ar.group_id AND drs.replica_id = ar.replica_id
OPTION(RECOMPILE);');
END
--------------------------------------------------------------------------------------------------------
IF @debug = 1 
BEGIN
    IF EXISTS(SELECT TOP 1 1 FROM #SR_HADRServices WHERE AlwaysOn = 1) RAISERROR ('Collect AlwaysOn Latency info',0,1) WITH NOWAIT;
END
	IF OBJECT_ID('tempdb..#SR_AlwaysOnLatency') IS NOT NULL
		DROP TABLE #SR_AlwaysOnLatency;
	CREATE TABLE #SR_AlwaysOnLatency(AlwaysOnGroup	sysname	null
		,PrimaryServer	nvarchar(256)	null
		,SecondaryServer	nvarchar(256)	null
		,database_name	nvarchar(128)	null
		,last_commit_time	datetime	null
		,DR_commit_time	datetime	null
		,lag_in_milliseconds	INT	NULL)
	
IF @MajorVersion > 1050 AND SERVERPROPERTY('IsHadrEnabled') = 1--2012
BEGIN
	EXEC('WITH    DR_CTE ( replica_server_name, database_name, last_commit_time )
        AS ( SELECT   ar.replica_server_name ,
                    database_name ,
                    rs.last_commit_time
            FROM     master.sys.dm_hadr_database_replica_states rs
                    INNER JOIN master.sys.availability_replicas ar ON rs.replica_id = ar.replica_id
                    INNER JOIN sys.dm_hadr_database_replica_cluster_states dcs ON dcs.group_database_id = rs.group_database_id
                                                            AND rs.replica_id = dcs.replica_id
            WHERE    replica_server_name <> @@SERVERNAME
            )
INSERT	#SR_AlwaysOnLatency
SELECT  AG.name [AlwaysOnGroup],
		ar.replica_server_name [PrimaryServer],
		DR_CTE.replica_server_name [SecondaryServer],
        dcs.database_name ,
        rs.last_commit_time ,
        DR_CTE.last_commit_time AS [DR_commit_time] ,
        DATEDIFF(MILLISECOND, DR_CTE.last_commit_time, rs.last_commit_time) [lag_in_milliseconds]
FROM    master.sys.dm_hadr_database_replica_states rs
        INNER JOIN master.sys.availability_replicas ar ON rs.replica_id = ar.replica_id
        INNER JOIN sys.dm_hadr_database_replica_cluster_states dcs ON dcs.group_database_id = rs.group_database_id
                                                            AND rs.replica_id = dcs.replica_id
        INNER JOIN DR_CTE ON DR_CTE.database_name = dcs.database_name
        JOIN master.sys.availability_groups AG ON ar.group_id = AG.group_id
WHERE   ar.replica_server_name = @@SERVERNAME
OPTION(RECOMPILE);
	')
END
--------------------------------------------------------------------------------------------------------
IF @debug = 1 
BEGIN
    IF EXISTS(SELECT TOP 1 1 FROM #SR_HADRServices WHERE Mirror = 1) RAISERROR ('Collect Mirroring info',0,1) WITH NOWAIT;
END
CREATE TABLE #SR_Mirror
( 
    DatabaseName VARCHAR(255), 
    Role INT, 
    MirroringState TINYINT, 
    WitnessStatus TINYINT, 
    LogGeneratRate INT, 
    UnsentLog INT, 
    SentRate INT, 
    UnrestoredLog INT, 
    RecoveryRate INT, 
    TransactionDelay INT, 
    TransactionPerSec INT, 
    AverageDelay INT, 
    TimeRecorded DATETIME, 
    TimeBehind DATETIME, 
    LocalTime DATETIME 
) 
/* declare variables */
DECLARE @DBMirror sysname
DECLARE curDBMirror CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
SELECT	d.name
FROM	sys.databases d
		inner join sys.database_mirroring m on d.database_id = m.database_id
WHERE	m.mirroring_guid IS NOT NULL
OPTION(RECOMPILE);
OPEN curDBMirror
FETCH NEXT FROM curDBMirror INTO @DBMirror
WHILE @@FETCH_STATUS = 0
BEGIN
    
	INSERT #SR_Mirror 
	EXEC msdb.sys.sp_dbmmonitorresults @DBMirror, 0,1 
    FETCH NEXT FROM curDBMirror INTO @DBMirror
END
CLOSE curDBMirror
DEALLOCATE curDBMirror
--------------------------------------------------------------------------------------------------------
IF @debug = 1 RAISERROR ('Collect Maintplan Plans Logs',0,1) WITH NOWAIT;
    DECLARE @line varchar(400)
    DECLARE @1MB    DECIMAL;
    SET     @1MB = 1024 * 1024;
    DECLARE @1KB    DECIMAL;
    SET     @1KB = 1024 ;
	---------------------------------------------------------------------------------------------
	-- Temp tables creation
	---------------------------------------------------------------------------------------------
	IF OBJECT_ID('tempdb..#MPLtempFilePaths') IS NOT NULL DROP TABLE #MPLtempFilePaths;
	IF OBJECT_ID('tempdb..#MPLtempFileInformation') IS NOT NULL DROP TABLE #MPLtempFileInformation;
	IF OBJECT_ID('tempdb..#MPLoutput') IS NOT NULL DROP TABLE #MPLoutput;
	CREATE TABLE #MPLoutput (Directory varchar(400), FilePath VARCHAR(400), SizeInMB DECIMAL(13,2), SizeInKB DECIMAL(13,2),FileDate VARCHAR(100))
	CREATE TABLE #MPLtempFilePaths (Files VARCHAR(500))
	CREATE TABLE #MPLtempFileInformation (FilePath VARCHAR(500), FileSize VARCHAR(100),FileDate VARCHAR(100))
	---------------------------------------------------------------------------------------------
	-- Call xp_cmdshell
	---------------------------------------------------------------------------------------------    
     SET @Command = 'dir "'+ @LogPath +'"';
     INSERT INTO #MPLtempFilePaths exec master.sys.xp_cmdshell @Command;
       --SELECT * FROM #MPLtempFilePaths
	---------------------------------------------------------------------------------------------
	-- Process the return data
	--------------------------------------------------------------------------------------------- 
    --delete all directories
    DELETE #MPLtempFilePaths WHERE Files LIKE '%<dir>%' OR Files IS NULL;
    --delete all informational messages
    DELETE #MPLtempFilePaths WHERE Files LIKE ' %';
       -- Store the FileName & Size
    INSERT INTO #MPLtempFileInformation
    SELECT  RIGHT(FD.files,LEN(FD.files) -PATINDEX('% %',FD.files)) AS FilePath,
        REPLACE(LEFT(FD.files,PATINDEX('% %',FD.files)), ',','') AS FileSize,
                    FD.FileDate
    FROM   #MPLtempFilePaths
                    CROSS APPLY(SELECT TOP 1 LEFT(Files,10) [FileDate],LTRIM(RIGHT(Files,(LEN(Files)-20)))[files])FD;
    --------------------------------------------------------------
    -- Store the results in the #MPLoutput table
    --------------------------------------------------------------
	DELETE  FROM    #MPLtempFileInformation WHERE	ISNUMERIC(FileSize) = 0;
    INSERT INTO #MPLoutput--(FilePath, SizeInMB, SizeInKB)
    SELECT  @LogPath,
            FilePath,
            CAST(CAST(FileSize AS DECIMAL(13,2))/ @1MB AS DECIMAL(13,2)),
            CAST(CAST(FileSize AS DECIMAL(13,2))/ @1KB AS DECIMAL(13,2)),
            FileDate
    FROM    #MPLtempFileInformation
	OPTION(RECOMPILE);
    --------------------------------------------------------------------------------------------
    DELETE FROM #MPLoutput WHERE Directory is null       
	----------------------------------------------
	-- DROP temp tables
	----------------------------------------------
	IF OBJECT_ID('tempdb..#MPLtempFilePaths') IS NOT NULL DROP TABLE #MPLtempFilePaths  
	IF OBJECT_ID('tempdb..#MPLtempFileInformation') IS NOT NULL DROP TABLE #MPLtempFileInformation  
	SELECT mp.name [MaintenancePlanName],
			F.SizeInMB ,
			F.NumberOfFiles,
			F.[OldFile]
	INTO   #SR_MaintenancePlanFiles
	FROM   msdb.dbo.sysmaintplan_plans mp
            OUTER APPLY(SELECT SUM(SizeInMB)[SizeInMB],COUNT_BIG(1)[NumberOfFiles],MIN(FileDate)[OldFile] FROM #MPLoutput WHERE FilePath LIKE mp.name + '%')F
	OPTION(RECOMPILE);
	IF OBJECT_ID('tempdb..#MPLoutput') IS NOT NULL DROP TABLE #MPLoutput 
--------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#SR_Replication', 'u') IS NOT NULL DROP TABLE #SR_Replication;
CREATE TABLE #SR_Replication(ID INT NOT NULL,[Messages] NVARCHAR(MAX) NOT NULL,[Type] NVARCHAR(MAX) NOT NULL,[Link] NVARCHAR(MAX) NULL);
DECLARE @DistributorName sysname
IF EXISTS(SELECT TOP 1 1 FROM sys.databases WHERE state = 0 AND is_distributor = 1)
BEGIN
	IF OBJECT_ID('tempdb..#MSdistribution_status', 'u') IS NOT NULL DROP TABLE #MSdistribution_status;
	IF OBJECT_ID('tempdb..#MSdistribution_agents', 'u') IS NOT NULL DROP TABLE #MSdistribution_agents;
	IF OBJECT_ID('tempdb..#MSpublications', 'u') IS NOT NULL DROP TABLE #MSpublications;
	IF OBJECT_ID('tempdb..#MSarticles', 'u') IS NOT NULL DROP TABLE #MSarticles;
	CREATE TABLE #MSdistribution_status(
		article_id	int	NULL,
		agent_id	int		NULL,
		UndelivCmdsInDistDB	int		NULL,
		DelivCmdsInDistDB	int	NULL);
	
	CREATE TABLE #MSdistribution_agents(
		[name]	NVARCHAR(100)	NULL,
		subscriber_id	int		NULL,
		id	int		NULL,
		publication	sysname	NULL,
		subscriber_db sysname NULL);
	CREATE TABLE #MSpublications(
		publication_id	int	NULL,
		publication	sysname	NULL,
		immediate_sync BIT NULL,
		publisher_id	smallint	NULL,
		publisher_db	sysname NULL
		);
	CREATE TABLE #MSarticles(
		publisher_id	smallint	NULL,
		publisher_db	sysname	NULL,
		publication_id	int	NULL, 
		article	sysname	NULL,
		article_id	int	NULL,
		destination_object	sysname NULL,
		source_owner	sysname	NULL,
		source_object	sysname	NULL,
		description	nvarchar(255)	NULL,
		destination_owner	sysname NULL
		);
	IF OBJECT_ID('tempdb..#agent_parameter', 'u') IS NOT NULL DROP TABLE #agent_parameter;
	CREATE TABLE #agent_parameter (
	agent_type	INT,
	parameter_name sysname,
	value nvarchar(255)
	)
	INSERT #agent_parameter
	VALUES(3,'-BcpBatchSize','2147473647')
	,(3,'-CommitBatchSize','100')
	,(3,'-CommitBatchThreshold','1000')
	,(3,'-HistoryVerboseLevel','1')
	,(3,'-KeepAliveMessageInterval','300')
	,(3,'-LoginTimeout','15')
	,(3,'-MaxBcpThreads','1')
	,(3,'-MaxDeliveredTransactions','0')
	,(3,'-PollingInterval','5')
	,(3,'-QueryTimeout','1800')
	,(3,'-SkipErrors','')
	,(3,'-TransactionsPerHistory','100')
	,(2,'-HistoryVerboseLevel','1')
	,(2,'-LoginTimeout','15')
	,(2,'-LogScanThreshold','500000')
	,(2,'-PollingInterval','5')
	,(2,'-QueryTimeout','1800')
	,(2,'-ReadBatchSize','500');
	IF OBJECT_ID('tempdb..#profiles', 'u') IS NOT NULL DROP TABLE #profiles;
	CREATE TABLE #profiles
		(
		  profile_id INT ,
		  profile_name sysname ,
		  agent_type INT ,
		  [type] INT ,
		  description VARCHAR(3000) ,
		  def_profile BIT
		);
	INSERT  INTO #profiles
			( profile_id ,
			  profile_name ,
			  agent_type ,
			  [type] ,
			  description ,
			  def_profile
			)
			EXEC sp_help_agent_profile;
	IF OBJECT_ID('tempdb..#ReplicationError', 'u') IS NOT NULL DROP TABLE #ReplicationError;
	CREATE TABLE #ReplicationError ([Message] NVARCHAR(MAX) NULL,
		PublisherName NVARCHAR(100) NULL,
		publisher_db sysname NULL,
		publication sysname NULL,
		error_text NVARCHAR(MAX) NULL
	
	);
	IF OBJECT_ID('tempdb..#ReplicationServers', 'u') IS NOT NULL DROP TABLE #ReplicationServers;
	CREATE TABLE #ReplicationServers
		(
		  ID INT NOT NULL
				 IDENTITY(1, 1) ,
		  PublicationName VARCHAR(200) ,
		  publisher_id INT ,
		  PublisherDB VARCHAR(200) ,
		  PublisherName VARCHAR(200) ,
		  source_object VARCHAR(200) ,
		  NumRows BIGINT
		);
	DECLARE @ReplicationID INT = 1;
	DECLARE @ReplicationMaxID INT; 
	DECLARE @ReplicationRows INT; 
	DECLARE curDistributor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
	SELECT [name] FROM sys.databases WHERE state = 0 AND is_distributor = 1;
	OPEN curDistributor
	FETCH NEXT FROM curDistributor INTO @DistributorName;
WHILE @@FETCH_STATUS = 0
BEGIN
	--############################################################################################################### 
	--                                    CHECK DISTRIBUTION Queues 
	--############################################################################################################### 
	DELETE FROM #MSdistribution_status;
	SET @cmd = N'INSERT	#MSdistribution_status
	SELECT  article_id,agent_id,UndelivCmdsInDistDB,DelivCmdsInDistDB
	FROM    ' + QUOTENAME(@DistributorName) + '..MSdistribution_status
	WHERE	UndelivCmdsInDistDB > 2000;'; -- GIVE A NUMBER HERE TO DEFINE A LARGE NUMBER OF RECORDS WAITING FOR REPLICATION;
	
    EXEC sys.sp_executesql @cmd;
	DELETE FROM #MSdistribution_agents;
	SET @cmd = N'INSERT  #MSdistribution_agents
	SELECT  [name],subscriber_id,id,publication,subscriber_db
	FROM    ' + QUOTENAME(@DistributorName) + '..MSdistribution_agents;';
	
    EXEC sys.sp_executesql @cmd;
	
	DELETE FROM #MSpublications;
	SET @cmd = N'INSERT  #MSpublications
	SELECT  publication_id,publication,immediate_sync,publisher_id,publisher_db
	FROM    ' + QUOTENAME(@DistributorName) + '..MSpublications;';
	
    EXEC sys.sp_executesql @cmd;
	
	DELETE FROM #MSarticles;
	SET @cmd = N'INSERT	#MSarticles
	SELECT  *
	FROM    ' + QUOTENAME(@DistributorName) + '..MSarticles;';
	
    EXEC sys.sp_executesql @cmd;
	INSERT #SR_Replication
	SELECT	3 [ID],
			'Article - ' + a.article COLLATE DATABASE_DEFAULT + '(' + agents.subscriber_db COLLATE DATABASE_DEFAULT + ') on publication ' + p.publication COLLATE DATABASE_DEFAULT + ' have ' + CONVERT(VARCHAR(1000),s.UndelivCmdsInDistDB) + ' undelivered Commands In distributionDB. on ' + CONVERT(VARCHAR(5),COUNT(1))+ ' agent(s).',
			'Undelivered Commands In distribution' [Type],
			CASE WHEN agents.subscriber_db = 'virtual' THEN 'https://blogs.msdn.microsoft.com/mangeshd/2009/01/27/virtual-subscription-entries-in-the-distribution-mssubscriptions-table'
			ELSE NULL END
	FROM    #MSdistribution_status AS s
			INNER JOIN #MSdistribution_agents AS agents ON agents.[id] = s.agent_id
			INNER JOIN #MSpublications AS p ON p.publication = agents.publication
			INNER JOIN #MSarticles AS a ON a.article_id = s.article_id
														   AND p.publication_id = a.publication_id
			LEFT JOIN sys.servers SR ON agents.subscriber_id = SR.server_id
	--WHERE   agents.subscriber_db <> 'virtual' -- https://blogs.msdn.microsoft.com/mangeshd/2009/01/27/virtual-subscription-entries-in-the-distribution-mssubscriptions-table/
	GROUP BY a.article,agents.subscriber_db,p.publication,s.UndelivCmdsInDistDB
	OPTION(RECOMPILE);
	SET @cmd = N'INSERT	#SR_Replication
	SELECT  DISTINCT 2 [ID],
			''You are using a '' + CASE publication_type WHEN 0 THEN ''Transactional'' WHEN 1 THEN ''Snapshot'' WHEN 2 THEN ''Merge'' ELSE '''' END + '' replication. You should turn off immediate_sync and subscriber_id, they can cause some performance isssues. On publication - '' + P.publication COLLATE DATABASE_DEFAULT + '' in publisher db - '' + P.publisher_db COLLATE DATABASE_DEFAULT  [Message],
			''Performance isssues related to configuration'',
			''www.replicationanswers.com/TransactionalOptimisation.asp''
	FROM    #MSpublications P
			INNER JOIN ' + QUOTENAME(@DistributorName) + '..MSsubscriptions S ON P.publication_id = S.publication_id
	WHERE   P.immediate_sync = 1
			AND S.subscriber_id = -1
	ORDER BY 1
	OPTION(RECOMPILE);'
	
    EXEC sys.sp_executesql @cmd;
	-- Errors
	DELETE FROM #ReplicationError;
	--https://social.msdn.microsoft.com/Forums/sqlserver/en-US/8f14068b-73ca-4d21-84ed-4afd816e9321/msreplerrors-details-for-particular-publisherssubscriber-?forum=sqlreplication
	
	SET @cmd = N'INSERT	#ReplicationError
	SELECT  ''On '' + T.PublisherName + '' - '' + T.publisher_db + '' - '' + T.publication + '' between '' + CONVERT(VARCHAR(25),MIN(T.time),121) + '' and '' + CONVERT(VARCHAR(25),MAX(T.time),121) + '' have an error - '' + T.error_text COLLATE DATABASE_DEFAULT [Message]
			,T.PublisherName
			,T.publisher_db 
			,T.publication 
			,T.error_text
	
	FROM    ( SELECT    publisher.name PublisherName,
						MSda.publication ,
						MSda.publisher_db ,
						CONVERT(NVARCHAR(MAX),MSre.error_text)error_text ,
						MSre.time,
						ROW_NUMBER() OVER ( PARTITION BY MSdh.agent_id ORDER BY MSre.time DESC) RN
			  FROM      ' + QUOTENAME(@DistributorName) + '..MSdistribution_history MSdh
						INNER JOIN #MSdistribution_agents MSda ON MSdh.agent_id = MSda.id
						INNER JOIN ' + QUOTENAME(@DistributorName) + '..MSrepl_errors MSre ON MSdh.error_id = MSre.id
						INNER JOIN master.sys.servers publisher ON MSda.publisher_id = publisher.server_id
						INNER JOIN master.sys.servers subscriber ON MSda.subscriber_id = subscriber.server_id
			  WHERE     MSdh.error_id <> 0
						AND MSre.time > DATEADD(DAY, -2, GETDATE())
		  
			) T
	WHERE   T.RN = 1
	GROUP BY T.PublisherName,T.publisher_db,T.publication,T.error_text
	OPTION(RECOMPILE);'
	
    EXEC sys.sp_executesql @cmd;
	-- Errors ignoring 
	SET @cmd = N'INSERT	#SR_Replication
	SELECT  13,''On '' + T.PublisherName + '' - '' + T.publisher_db + '' - '' + T.publication + '' between '' + CONVERT(VARCHAR(25),MIN(T.time),121) + '' and '' + CONVERT(VARCHAR(25),MAX(T.time),121) + '' have an error - '' + T.error_text COLLATE DATABASE_DEFAULT [Message],''Error'',NULL
	FROM    ( SELECT TOP 1000
						publisher.name AS PublisherName ,
						MSda.publication ,
						MSda.publisher_db ,
						CONVERT(NVARCHAR(MAX),MSre.error_text)error_text ,
						MSre.time,
						ROW_NUMBER() OVER ( PARTITION BY MSdh.agent_id ORDER BY MSre.time DESC) RN
				FROM    ' + QUOTENAME(@DistributorName) + '..MSrepl_errors MSre 
						INNER JOIN ' + QUOTENAME(@DistributorName) + '..MSdistribution_history MSdh ON MSre.time > DATEADD(DAY,
																			  -2, GETDATE())
																			  AND MSdh.error_id <> 0
																			  AND MSdh.error_id = MSre.id
						INNER JOIN #MSdistribution_agents MSda ON MSdh.agent_id = MSda.id
						INNER JOIN master.sys.servers publisher ON MSda.publisher_id = publisher.server_id
						INNER JOIN master.sys.servers subscriber ON MSda.subscriber_id = subscriber.server_id
						INNER JOIN msdb..MSagent_profiles prof ON MSda.profile_id = prof.profile_id
						LEFT JOIN msdb..MSagent_parameters param ON MSda.profile_id = param.profile_id
																			  AND param.parameter_name = ''-SkipErrors''
																			  AND param.value LIKE ''%'' + CONVERT(VARCHAR, MSre.error_code) + ''%''
				WHERE   param.value IS NULL
						AND MSre.time > DATEADD(DAY, -2, GETDATE())) T
				LEFT JOIN #Error R ON R.PublisherName = T.PublisherName
						AND R.publisher_db = T.publisher_db
						AND R.publication = T.publication
						AND R.error_text = T.error_text
	WHERE   T.RN = 1
			AND R.PublisherName IS NULL
	GROUP BY T.PublisherName,T.publisher_db,T.publication,T.error_text
	OPTION(RECOMPILE);'
	
    EXEC sys.sp_executesql @cmd;
	INSERT	#SR_Replication
	SELECT	13,Message,'Error',NULL
	FROM	#ReplicationError;
	-- Log reader jobs without 2nd schedule
	INSERT	#SR_Replication
	SELECT  1 [ID],'Job name ' + J.name + ' is Log reader job without 2nd schedule' AS Messages,
		   'Log reader jobs without 2nd schedule' [Type],
		   NULL
	FROM    msdb..syscategories C
			INNER JOIN  msdb..sysjobs J ON C.category_id = J.category_id
			INNER JOIN msdb..sysjobschedules S ON J.job_id = S.job_id
			LEFT JOIN msdb..sysschedules SS ON S.schedule_id = SS.schedule_id
											   AND freq_type = 64
			LEFT JOIN msdb..sysschedules SSOther ON S.schedule_id = SSOther.schedule_id
													AND SSOther.freq_type <> 64
	WHERE   C.name = 'REPL-LogReader' -- logreader
			AND SSOther.schedule_id IS NULL 
			AND SS.schedule_id IS NOT NULL
	GROUP BY J.name
	UNION ALL
	-- Distribution jobs that only have start on SQL start schedule
	SELECT  4 ,'Job name ' + J.name + ' have Only 1 Schedule SQL Agent Start' AS Messages,
			'Distribution jobs that only have start on SQL start schedule' [Type],
			NULL
	FROM    msdb..syscategories C
			INNER JOIN msdb..sysjobs J ON C.category_id = J.category_id
			INNER JOIN msdb..sysjobschedules S ON J.job_id = S.job_id
			LEFT JOIN msdb..sysschedules SS ON S.schedule_id = SS.schedule_id
											   AND freq_type = 64
			LEFT JOIN msdb..sysschedules SSOther ON S.schedule_id = SSOther.schedule_id
													AND SSOther.freq_type <> 64
	WHERE	C.name = 'REPL-Distribution' -- logreader
			AND SSOther.schedule_id IS NULL
			AND SS.schedule_id IS NOT NULL
	GROUP BY J.name
	--ORDER BY 1
	
	SET @cmd = N'INSERT	#SR_Replication
	-- If more than 5 million (need to decide a number) then need to examine archiving
	SELECT  5, CONVERT(VARCHAR(10),COUNT(*)) + '' commands are in MSrepl_commands - need to examine archiving'',
	''Examine archiving'',
		   ''blogs.msdn.microsoft.com/chrissk/2009/12/29/how-to-resolve-when-distribution-database-is-growing-huge-25gig''
	FROM    ' + QUOTENAME(@DistributorName) + '..MSrepl_commands
	/*
				*********************************************** THINK OF MAGIC NUMBER**************************************************
	*/
	HAVING COUNT(*) > 70000
	UNION ALL
	-- Check undelivered commands - again need to choose a number for threshold of alert
	SELECT  6,''There is '' + CONVERT(VARCHAR(10),SUM(UndelivCmdsInDistDB)) + '' UnReplicated Commands waiting'' AS Messages,
	''Check undelivered commands - again need to choose a number for threshold of alert'' [Type],
		   NULL
	FROM    ' + QUOTENAME(@DistributorName) + '..MSdistribution_status 
	/*
				*********************************************** THINK OF MAGIC NUMBER**************************************************
	*/
	HAVING SUM(UndelivCmdsInDistDB) > 8000
	OPTION(RECOMPILE);'
	
    EXEC sys.sp_executesql @cmd;
	--Check Publications with too many articles
    DECLARE @TooManyArticlesInAPublication INT = 50;
	INSERT	#SR_Replication
    SELECT  15,'Publication ' + p.publication + ' have ' + CONVERT(VARCHAR(15),COUNT(*)) + ' articles. try to lower the number of articles per publication under ' + CONVERT(VARCHAR(10),@TooManyArticlesInAPublication) +'.','Configuration',NULL
    FROM    #MSpublications p
            INNER JOIN #MSarticles a ON p.publication_id = a.publication_id
    GROUP BY p.publication
    HAVING  COUNT(*) > @TooManyArticlesInAPublication
    ORDER BY 2 DESC;
	------------------------------------------
	--Check Size of tables in a Publication
	DELETE FROM #ReplicationServers;
	INSERT  #ReplicationServers
			( PublicationName ,
			  publisher_id ,
			  PublisherDB ,
			  PublisherName ,
			  source_object ,
			  NumRows
			)
	SELECT  p.publication ,
			p.publisher_id ,
			p.publisher_db ,
			SR.name ,
			a.source_owner + '.' + a.source_object ,
			NULL
	FROM    #MSpublications p
			INNER JOIN #MSarticles a ON p.publication_id = a.publication_id
			INNER JOIN sys.servers SR ON p.publisher_id = SR.server_id;
	SELECT  @ReplicationMaxID = MAX(ID),@ReplicationID = MIN(ID)
	FROM    #ReplicationServers;
	WHILE @ReplicationID <= @ReplicationMaxID
    BEGIN
        SELECT  @cmd = 'SELECT @ReplicationRowsOut = Rows FROM OPENQUERY([' +
                              PublisherName +
                              '], ''Select sum(rows) as Rows from ' +
                              PublisherDB +
                              '.sys.partitions where object_id = OBJECT_ID(''''' +
                              PublisherDB + '.' + source_object + ''''')     and index_id = 1'')'
        FROM    #ReplicationServers
        WHERE   ID = @ReplicationID;
        EXECUTE sp_executesql @cmd, N'@RowsOut BIGINT OUTPUT',
            @ReplicationRowsOut = @ReplicationRows OUTPUT;
        UPDATE  #ReplicationServers
        SET     NumRows = @ReplicationRows
        WHERE   ID = @ReplicationID;
        SET @ReplicationID += 1;
    END;
	------------------------------------------
	IF EXISTS ( SELECT  TOP 1 1 
				FROM    #MSdistribution_agents D
						INNER JOIN #profiles P ON D.profile_id = P.profile_id
				WHERE	P.profile_name = 'Default agent profile'
						AND P.agent_type = 2 )
		INSERT #SR_Replication VALUES (10,'Default Log reader agent profile is being used, maybe some configuration changes should be considered','Configuration',NULL);
	ELSE
	IF NOT EXISTS ( SELECT  TOP 1 1 
					FROM    #profiles P
					WHERE   P.def_profile = 1
							AND P.profile_name <> 'Default agent profile'
							AND P.agent_type = 2 )-- LOG agent
		INSERT #SR_Replication VALUES (9,'Default Log reader agent profile has not been changed, maybe some configuration changes should be considered','Configuration',NULL);
	IF EXISTS ( SELECT  TOP 1 1 
				FROM    #MSdistribution_agents D
						INNER JOIN #profiles P ON D.profile_id = P.profile_id
				WHERE	P.profile_name = 'Default agent profile'
						AND P.agent_type = 3 )
		INSERT #SR_Replication VALUES (8,'Default distribution profile is being used, maybe some configuration changes should be considered','Configuration',NULL);
	ELSE
	IF NOT EXISTS ( SELECT  TOP 1 1 
					FROM    #profiles P
					WHERE   P.def_profile = 1
							AND P.profile_name <> 'Default agent profile'
							AND P.agent_type = 3 )-- distrebution agent
		INSERT #SR_Replication VALUES (7,'Default distribution profile has not been changed, maybe some configuration changes should be considered','Configuration',NULL);
	FETCH NEXT FROM curDistributor INTO @DistributorName
	END
	CLOSE curDistributor
	DEALLOCATE curDistributor
END
-------------------------------------------------------------------------------------------------------- 
--------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------- 
--------------------------------------------------------------------------------------------------------
CREATE TABLE #sp_Blitz (
	[ID] [INT]  NOT NULL,
	[BlitzVersion] [INT] NULL,
	[Priority] [TINYINT] NULL,
	[FindingsGroup] [VARCHAR](50) NULL,
	[Finding] [VARCHAR](200) NULL,
	[DatabaseName] [NVARCHAR](128) NULL,
	[Details] [NVARCHAR](4000) NULL,
	[CheckID] [INT] NULL);
	IF OBJECT_ID('dbo.sp_Blitz') IS NOT NULL
	BEGIN
	    BEGIN TRY 
			IF @debug = 1 RAISERROR ('Collect sp_Blitz',0,1) WITH NOWAIT;
			IF OBJECT_ID('dbo.sp_BlitzTableOutput') IS NOT NULL
			BEGIN
				EXEC('DELETE FROM dbo.sp_BlitzTableOutput;')
			END
	    	DECLARE @CheckUserDatabaseObjects TINYINT = 0
			DECLARE @CheckProcedureCache TINYINT = 0
			DECLARE @OutputType VARCHAR(20) = 'NONE'
			DECLARE @OutputProcedureCache TINYINT
			DECLARE @CheckProcedureCacheFilter VARCHAR(10)
			DECLARE @CheckServerInfo TINYINT = 1
			DECLARE @SkipChecksServer NVARCHAR(256)
			DECLARE @SkipChecksDatabase NVARCHAR(256)
			DECLARE @SkipChecksSchema NVARCHAR(256)
			DECLARE @SkipChecksTable NVARCHAR(256)
			DECLARE @IgnorePrioritiesBelow INT
			DECLARE @IgnorePrioritiesAbove INT
			DECLARE @OutputDatabaseName NVARCHAR(128) = 'master'
			DECLARE @OutputSchemaName NVARCHAR(256) = 'dbo'
			DECLARE @OutputTableName NVARCHAR(256) = 'sp_BlitzTableOutput'
			DECLARE @OutputXMLasNVARCHAR TINYINT =1
			DECLARE @EmailRecipients VARCHAR(MAX)
			DECLARE @EmailProfile sysname
			DECLARE @SummaryMode TINYINT
			DECLARE @Version INT
			DECLARE @VersionDate DATETIME
			EXECUTE [dbo].[sp_Blitz] 
			   @CheckUserDatabaseObjects
			  ,@CheckProcedureCache
			  ,@OutputType
			  ,@OutputProcedureCache
			  ,@CheckProcedureCacheFilter
			  ,@CheckServerInfo
			  ,@SkipChecksServer
			  ,@SkipChecksDatabase
			  ,@SkipChecksSchema
			  ,@SkipChecksTable
			  ,@IgnorePrioritiesBelow
			  ,@IgnorePrioritiesAbove
			  ,@OutputDatabaseName
			  ,@OutputSchemaName
			  ,@OutputTableName
			  ,@OutputXMLasNVARCHAR
			  ,@EmailRecipients
			  ,@EmailProfile
			  ,@SummaryMode
			  ,@Help
			  ,@Version OUTPUT
			  ,@VersionDate OUTPUT;
			  IF OBJECT_ID('dbo.sp_BlitzTableOutput') IS NOT NULL
			  BEGIN
				EXEC('INSERT	#sp_Blitz
SELECT	[ID]
		,[BlitzVersion]
		,[Priority]
		,[FindingsGroup]
		,[Finding]
		,[DatabaseName]
		,[Details]
		,[CheckID]
FROM	[master].[dbo].[sp_BlitzTableOutput]
WHERE	CheckID NOT IN (-1,1,2,14,6,4,55,158,155,1065,1057,1039,1036,1031,1015,1011,1006,1003,49,62,68,82,76,84,92,88,27,100,102,106,130,83,135,137);')
			  END
	    
	    END TRY
	    BEGIN CATCH
	    	PRINT 'Info only: No sp_Blitz has been found.'
	    	
	    	
	    END CATCH
	END
--------------------------------------------------------------------------------------------------------
-----------------------------------
        IF @debug = 1 RAISERROR ('Make XML',0,1) WITH NOWAIT;
        DECLARE @XML XML;
        SET @XML = ( SELECT ( SELECT    NEWID() AS id ,
                                        @Client Client,
										GETDATE() AS date ,
                                        CASE WHEN @Mask = 1 THEN CONVERT(sysname,'SQLServerMask') ELSE @@SERVERNAME END AS ServerName,
										@ClientVersion [ClientVersion],
										SUSER_NAME() [RuningBy]
                                FROM      ( SELECT    1 AS col1
                                        ) AS Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS ReportMetadata ,
                            ( SELECT    Data.* FROM      #SR_MachineSettings Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS MachineSettings ,
                            ( SELECT    Data.* FROM      #SR_ServerProporties Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS ServerProporties ,
                            ( SELECT    Data.* FROM      #SR_Configuration Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS Configuration ,
                            ( SELECT    Data.* FROM      #SR_Databases Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS Databases ,
                            ( SELECT    Data.* FROM      #SR_Jobs Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS Jobs ,
							( SELECT    Data.* FROM      #SR_JobOut Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS JobsOut ,
							( SELECT    Data.* FROM      #SR_KB Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS KB ,
                            ( SELECT    Data.* FROM      #SR_Latency Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS Latency ,
                            ( SELECT    Data.* FROM      #SR_login Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS login ,
                            ( SELECT    Data.* FROM      #SR_MasterFiles Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS MasterFiles ,
                            ( SELECT    Data.*FROM      #SR_os_schedulers Data
                            FOR XML AUTO ,TYPE ,ELEMENTS XSINIL) AS os_schedulers ,
                            ( SELECT    Data.*FROM      #SR_PLE Data
                            FOR XML AUTO ,TYPE ,ELEMENTS XSINIL) AS PLE ,
                            ( SELECT    Data.*FROM      #SR_servers Data
                            FOR XML AUTO ,TYPE ,ELEMENTS XSINIL) AS servers ,
                            ( SELECT    Data.*FROM      #SR_server_services Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS server_services ,
							( SELECT    Data.* FROM      #SR_Software Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS Software ,
                            ( SELECT    Data.* FROM      #SR_TraceStatus Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS TraceStatus ,
                            ( SELECT    Data.* FROM      #SR_Volume Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS Volume,
                            ( SELECT    Data.* FROM      #SR_Offset Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS Offset,
							( SELECT    Data.* FROM      #SR_reg Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS Registery,
							( SELECT    Data.* FROM      #SR_VersionBug Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS VersionBug,
							( SELECT    Data.* FROM      #SR_DatabaseFiles Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS DatabaseFiles,
							( SELECT    Data.* FROM      #SR_DBProp Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS DBPro,
							( SELECT    Data.* FROM      #SR_HADR Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS HADR,
							( SELECT    Data.* FROM      #SR_HADRState Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS HADRState,
							( SELECT    Data.* FROM      #SR_AlwaysOnLatency Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS AlwaysOnLatency,	
							( SELECT    Data.* FROM      #SR_HADRServices Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS HADRServices,
							( SELECT    Data.* FROM      #SR_Mirror Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS Mirror,
							( SELECT    Data.* FROM      #SR_MaintenancePlanFiles Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS MaintenancePlanFiles,
							( SELECT    Data.* FROM      #SR_Replication Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS Replications,
							( SELECT    Data.* FROM      #SR_WaitStat Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS WaitStat,
							( SELECT    Data.* FROM      #SR_LoginIssue Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS LoginIssue,
							( SELECT    Data.* FROM      #SR_RemoteServer Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS RemoteServerNode,
							( SELECT    Data.* FROM      @DebugError Data WHERE	ISNULL(Data.Error,'') <> '' OR Data.Duration > 1
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS DebugError,
							( SELECT    Data.* FROM      #sp_Blitz Data
                            FOR XML AUTO , TYPE , ELEMENTS XSINIL ) AS Blitz
                        FROM   ( SELECT    1 AS col ) AS SiteReview
                    FOR XML AUTO , TYPE , ELEMENTS XSINIL
                    );
		IF @Mask = 1
		BEGIN
			SELECT @XML =	CONVERT(XML,
							REPLACE(REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(MAX),@XML),
							@@SERVERNAME,'SQLServerMask'),
							CONVERT(SYSNAME,SERVERPROPERTY('MachineName')),'MachineNameMask'),
							@@SERVICENAME,'ServiceNameMask'),
							DEFAULT_DOMAIN(),'DefaultDomainMask')
							)
		END
		INSERT master.dbo.SiteReview ( Col ) SELECT  @XML;
		IF @Display = 1 
		BEGIN
		    SELECT TOP 1 Col FROM master.dbo.SiteReview;
		END
		ELSE
		BEGIN
			 SELECT  @Filename = @LogPath + 'SiteReview_' + CONVERT(VARCHAR(25),YEAR(GETDATE()))+CONVERT(VARCHAR(25),MONTH(GETDATE()))+CONVERT(VARCHAR(25),DAY(GETDATE())) + '_' + CONVERT(VARCHAR(25),DATEPART(MINUTE,GETDATE()))++CONVERT(VARCHAR(25),DATEPART(SECOND,GETDATE())) + '.xml'
			 /* we then insert a row into the table from the XML variable */
			 /* so we can then write it out via BCP! */
			 SELECT  @Command = 'bcp "select Col from master.dbo.SiteReview" queryout ' + @Filename + ' -w -T -S' + @@SERVERNAME;
			 INSERT @output
			 EXECUTE master..xp_cmdshell @Command;
	    END
		DROP TABLE #SR_Software;
        DROP TABLE #SR_Configuration;
        DROP TABLE #SR_Databases;
        DROP TABLE #SR_Jobs;
        DROP TABLE #SR_Latency;
        DROP TABLE #SR_login;
        DROP TABLE #SR_MasterFiles;
        DROP TABLE #SR_os_schedulers;
        DROP TABLE #SR_PLE;
        DROP TABLE #SR_servers;
        DROP TABLE #SR_server_services;
        DROP TABLE #SR_TraceStatus; 
        DROP TABLE #SR_Volume;
        DROP TABLE #SR_ServerProporties;
        DROP TABLE #SR_MachineSettings;
		DROP TABLE #SR_Offset;
		DROP TABLE #SR_reg;
		DROP TABLE #SR_KB;
		DROP TABLE #SR_HADR;
		DROP TABLE #SR_HADRServices;
		DROP TABLE #SR_HADRState;
		DROP TABLE #SR_Mirror;
		DROP TABLE #SR_MaintenancePlanFiles;
		DROP TABLE #SR_Replication;
		DROP TABLE #SR_WaitStat;
		DROP TABLE #SR_LoginIssue;
  --  END TRY
  --  BEGIN CATCH 
       
  --      SELECT  @ErrorLog = ERROR_MESSAGE();
  --      IF @debug = 1
  --          PRINT @@SERVERNAME + ' Failed Generating Report';
                
		--GOTO GTError;
  --  END CATCH
GTError:    
	IF @debug = 1
        PRINT @@SERVERNAME + ' Finished Generating Report';
--------------------------------------------------------------------------------------------------------
    IF @cmdshell = 1
    BEGIN
		IF @debug = 1 RAISERROR ('Turn off "xp_cmdshell"',0,1) WITH NOWAIT;
        EXEC sp_configure 'xp_cmdshell', 0;
        RECONFIGURE WITH OVERRIDE;
    END;
	IF @olea = 1
    BEGIN
		IF @debug = 1 RAISERROR ('Turn off "Ole Automation Procedures"',0,1) WITH NOWAIT;
        EXEC sp_configure 'Ole Automation Procedures', 0;
        RECONFIGURE WITH OVERRIDE;
    END;
    IF @showadvanced = 1
    BEGIN
		IF @debug = 1 RAISERROR ('Turn off "show advanced options"',0,1) WITH NOWAIT;
        EXEC sp_configure 'show advanced options', 0;
        RECONFIGURE WITH OVERRIDE;
    END;
	IF @Display = 0
	BEGIN
	    SET @Print = ISNULL(@Print,'') + 'Go tack your file from here - "' + @Filename + '"';
	END
	PRINT @Print;
	IF @ErrorLog IS NOT NULL
		RAISERROR(@ErrorLog,16,1);
END

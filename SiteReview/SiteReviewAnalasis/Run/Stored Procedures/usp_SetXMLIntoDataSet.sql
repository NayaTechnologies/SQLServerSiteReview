-- =============================================
-- Author:		Sharon
-- Create date: 07/06/2016
-- Description:	Get Excluded DB
-- =============================================
CREATE PROCEDURE [Run].[usp_SetXMLIntoDataSet]
	@XML AS XML,
	@ClientID INT = NULL
AS
--DECLARE @XML XML


--SELECT	@XML = XR.XMLData
--FROM	Client.XMLReports XR

BEGIN
	SET NOCOUNT ON;

	IF @XML IS NULL
	BEGIN
		RAISERROR('@XML Can not be NULL',16,1);
		RETURN -1;
	END
	DECLARE @hDoc AS INT, 
			@SQL NVARCHAR (MAX),
			@ServerName sysname;
	DECLARE @guid UNIQUEIDENTIFIER

	BEGIN TRY
		EXEC sp_xml_preparedocument @hDoc OUTPUT, @XML;
	END TRY
	BEGIN CATCH
		RETURN -1;
		RAISERROR('No XML has been found!',16,1);
	END CATCH
	
	SELECT @guid = ID FROM OPENXML(@hDoc, 'SiteReview/ReportMetadata/Data')WITH (ID UNIQUEIDENTIFIER  'id');
	SELECT @ServerName = ServerName FROM OPENXML(@hDoc, 'SiteReview/MachineSettings/Data')WITH (ServerName sysname 'ServerName');
	DECLARE @Print NVARCHAR(4000);
	SET @Print = 'Server Name :: ' + @ServerName + ' ID:: ' + CONVERT(NVARCHAR(36),@guid);
	PRINT @Print;
	IF @guid IS NULL
	BEGIN
		EXEC sp_xml_removedocument @hDoc;
		RAISERROR('No Guid has been found!',16,1);
		RETURN -1;
	END

	EXEC [Run].[usp_CleanDataSet] @guid;

	BEGIN TRY
	BEGIN TRANSACTION 

	INSERT INTO Client.[ReportMetaData]
           ([ReportGUID]
           ,[ClientID]
           ,[ClientName]
           ,[RunDate]
           ,[ServerName]
		   ,IsExported
		   ,ClientVersion
		   ,HaveExportError
		   ,ExportError
		   ,HaveSent
		   ,SentError)
	SELECT ID,ISNULL(@ClientID,ClientID),[ClientName], [Date],ISNULL([ServerName],@ServerName),0,ISNULL(ClientVersion,'1.0'),0,NULL,0,NULL
	FROM OPENXML(@hDoc, 'SiteReview/ReportMetadata/Data')
	WITH 
	(
	ID [Nvarchar](1000)  'id',
	ClientID INT 'ClientID',
	[ClientName] [Nvarchar](1000) 'Client',
	[Date] DATETIME 'date',
	[ServerName] sysname 'ServerName',
	[ClientVersion] VARCHAR(10) 'ClientVersion'
	);

	INSERT [Client].SPConfigure
	        ( guid, name, value )
	SELECT @guid [guid],name,value
	FROM OPENXML(@hDoc, 'SiteReview/Configuration/Data')--Configuration
	WITH 
	(name  [NVARCHAR](255) 'name'
	,value INT 'value'
	);

	INSERT [Client].Software
	        ( guid, Software, Status )
	SELECT @guid [guid],Software,Status
	FROM OPENXML(@hDoc, 'SiteReview/Software/Data')--Configuration
	WITH 
	(Software  [NVARCHAR](255) 'Software'
	,Status BIT 'Status'
	);

	
	INSERT [Client].[HeavyQueries]
	        ( guid, CheckType, execution_count ,AvgScore,last_execution_time,AvgDuration,query_text,database_name)
	SELECT @guid [guid],CheckType,execution_count,AvgScore,last_execution_time,AvgDuration,query_text,database_name
	FROM OPENXML(@hDoc, 'SiteReview/HeavyQueries/Data')--Configuration
	WITH 
	(CheckType  sysname 'CheckType'
	,execution_count BIGINT 'execution_count'
	,AvgScore  INT  'AvgScore'
	,last_execution_time DATETIME  'last_execution_time'
	,AvgDuration INT  'AvgDuration'
	,query_text NVARCHAR(MAX) 'query_text'
	,database_name sysname 'database_name'
	);
	
	INSERT [Client].CPUHistory
	        ( guid, EventTimeFrom, EventTimeTo ,SQLCPU,IdleCPU,Others)
	SELECT @guid [guid],EventTimeFrom,EventTimeTo,SQLCPU,IdleCPU,Others
	FROM OPENXML(@hDoc, 'SiteReview/CPUHistory/Data')--Configuration
	WITH 
	(EventTimeFrom  DATETIME 'EventTimeFrom'
	,EventTimeTo DATETIME 'EventTimeTo'
	,SQLCPU  INT 'SQLCPU'
	,IdleCPU INT 'IdleCPU'
	,Others INT 'Others'
	);
	
	
	INSERT [Client].[SysAdmin]
	        ( guid, name, type ,ParentGroup)
	SELECT @guid [guid],name,type,ParentGroup
	FROM OPENXML(@hDoc, 'SiteReview/SysAdmin/Data')--Configuration
	WITH 
	(name  [sysname] 'name'
	,type [sysname] 'type'
	,ParentGroup [sysname] 'ParentGroup'
	);

	--INSERT [Client].RemoteServerNode
	--        ( guid, Software, Status )
	--SELECT @guid [guid],Software,Status
	--FROM OPENXML(@hDoc, 'SiteReview/RemoteServerNode/Data')--RemoteServerNode
	--WITH 
	--(Software  [NVARCHAR](255) 'Software'
	--,Status BIT 'Status'
	--);


	DECLARE @PLE INT;
	SELECT  @PLE = ParamValues.xmlnode.value('./AveragePageLifeExpectancy[1][not(@xsi:nil = "true")]','int') 
	FROM    @XML.nodes('(/SiteReview/PLE/Data)') AS ParamValues (xmlnode);

	INSERT INTO [Client].[DatabaseFiles]
			   ([Database_Name]
			   ,[File_Name]
			   ,[Physical_Name]
			   ,[File_Type]
			   ,[database_id]
			   ,[file_id]
			   ,[Total_Size]
			   ,[Free_Space]
			   ,[Growth_Units]
			   ,[Max_Size]
			   ,[guid]
			   ,[FG_ID]
			   ,[FG_Name]
			   ,[FG_type]
			   ,[FG_Default])
	SELECT [DatabaseName], [FileName], [PhysicalName], [FileType],[databaseid]
			   ,[fileid], [TotalSize], [FreeSpace], [GrowthUnits], [MaxSize], @guid [guid], [FGID], [FGName], [FGtype], [FGDefault]
	FROM OPENXML(@hDoc, 'SiteReview/DatabaseFiles/Data')--DatabaseFiles
	WITH 
	(DatabaseName [NVARCHAR](255) 'DatabaseName'
	, FileName [NVARCHAR](255) 'FileName'
	, PhysicalName [NVARCHAR](MAX) 'PhysicalName'
	, FileType [NVARCHAR](255) 'FileType'
	, databaseid [INT] 'databaseid'
	, fileid [INT] 'fileid'
	, TotalSize [INT] 'TotalSize'
	, FreeSpace [INT] 'FreeSpace'
	, GrowthUnits [NVARCHAR](255) 'GrowthUnits'
	, MaxSize [NVARCHAR](255) 'MaxSize'

	, FGID [INT] 'FGid'
	, FGName [NVARCHAR](255) 'FGName'
	, FGtype [NVARCHAR](255) 'FGType'
	, FGDefault [INT] 'FGDefault'
	)

	INSERT Client.Registery
	        ( guid ,
	          Service ,
	          InstanceNames ,
	          keyName ,
	          Value ,
	          CurrentInstance
	        )
	SELECT @guid [guid], Service , InstanceNames , keyName , ISNULL(Value,'-99') , CurrentInstance
	FROM OPENXML(@hDoc, 'SiteReview/Registery/Data')--Registery
	WITH 
	(	Service sysname 'Service',
		InstanceNames sysname 'InstanceNames',
		keyName NVARCHAR(255) 'keyname',
		Value sysname 'value',
		CurrentInstance bit 'CurrentInstance'
	);

	INSERT Client.DebugError
	        ( guid ,
	          [Subject] ,
	          Error ,
	          Duration
	        )
	SELECT @guid [guid], [Subject] , Error ,  ISNULL(Duration,0) 
	FROM OPENXML(@hDoc, 'SiteReview/DebugError/Data')--DebugError
	WITH 
	(	[Subject] sysname 'Subject',
		Error NVARCHAR(MAX) 'Error',
		Duration INT 'Duration'
	);

	INSERT Client.HADRServices
	        ( Guid ,
	          AlwaysOn ,
	          [Replication] ,
	          LogShipping ,
	          Mirror
	        )
	SELECT @guid [guid], AlwaysOn ,
                         [Replication] ,
                         LogShipping ,
                         Mirror
	FROM OPENXML(@hDoc, 'SiteReview/HADRServices/Data')--HADRServices
	WITH 
	(	AlwaysOn BIT 'AlwaysOn',
		[Replication] BIT 'Replication',
		LogShipping BIT 'LogShipping',
		Mirror BIT 'Mirror'
	);

	INSERT Client.DatabaseProperties
	        ( guid, Type, DatabaseName, Note )	       
	SELECT @guid [guid], Type , DatabaseName ,Note
	FROM OPENXML(@hDoc, 'SiteReview/DBPro/Data')--DatabaseProperties
	WITH 
	(	Type sysname 'Type',
		DatabaseName sysname 'DatabaseName',
		Note NVARCHAR(MAX) 'Note'
	);

	INSERT Client.TraceFlag
	        ( guid ,
	          TraceFlag ,
	          status ,
	          Global ,
	          Session
	        )
	SELECT @guid [guid],TraceFlag,status,Global,Session
	FROM OPENXML(@hDoc, 'SiteReview/TraceStatus/Data')--TraceFlag
	WITH 
	(TraceFlag INT 'TraceFlag',
	status INT 'status',
	Global INT 'Global',
	Session INT 'Session'
	);

	INSERT [Client].Volumes
	        ( guid ,
	          VolumeName ,
	          available_bytes ,
	          total_bytes ,
	          DriveLeter ,
	          BlockSize,
			  VolumeLeble
	        )
	SELECT @guid [guid],volume_mount_point,TRY_CONVERT(BIGINT,available_bytes/1024/1024/1024),TRY_CONVERT(BIGINT,total_bytes/1024/1024/1024),DriveLeter,BlockSize,VolumeLeble
	FROM OPENXML(@hDoc, 'SiteReview/Volume/Data')--Volumes
	WITH 
	(volume_mount_point VARCHAR(5) 'volume_mount_point',
	available_bytes FLOAT 'available_bytes',
	total_bytes FLOAT 'total_bytes',
	DriveLeter VARCHAR(5) 'DriveLeter',
	[BlockSize] INT 'BlockSize',
	VolumeLeble NVARCHAR(255) 'VolumeLeble'
	);

	INSERT [Client].MaintenancePlanFiles
	        ( guid ,
	          MaintenancePlanName ,
             SizeInMB ,
             NumberOfFiles ,
             OldFile
	        )
	SELECT @guid [guid], MaintenancePlanName ,
                        SizeInMB ,
                        NumberOfFiles ,
                        OldFile
	FROM OPENXML(@hDoc, 'SiteReview/MaintenancePlanFiles/Data')--MaintenancePlanFiles
	WITH 
	(MaintenancePlanName sysname 'MaintenancePlanName',
	SizeInMB FLOAT 'SizeInMB',
	NumberOfFiles INT 'NumberOfFiles',
	OldFile DATE 'OldFile'
	);

	INSERT [Client].LoginIssue
	        ( guid ,Message )
	SELECT @guid [guid], Weak 
	FROM OPENXML(@hDoc, 'SiteReview/LoginIssue/Data')--LoginIssue
	WITH 
	(Weak NVARCHAR(max) 'Weak'
	);

	INSERT [Client].Mirror
	        ( guid ,
	          DatabaseName ,
	          Role ,
	          MirroringState ,
	          WitnessStatus ,
	          LogGeneratRate ,
	          UnsentLog ,
	          SentRate ,
	          UnrestoredLog ,
	          RecoveryRate ,
	          TransactionDelay ,
	          TransactionPerSec ,
	          AverageDelay ,
	          TimeRecorded ,
	          TimeBehind ,
	          LocalTime
	        )
	SELECT @guid [guid], DatabaseName ,
                        Role ,
                        MirroringState ,
                        WitnessStatus ,
                        LogGeneratRate ,
                        UnsentLog ,
                        SentRate ,
                        UnrestoredLog ,
                        RecoveryRate ,
                        TransactionDelay ,
                        TransactionPerSec ,
                        AverageDelay ,
                        TimeRecorded ,
                        TimeBehind ,
                        LocalTime
	FROM OPENXML(@hDoc, 'SiteReview/Mirror/Data')--Volumes
	WITH 
	(DatabaseName sysname 'DatabaseName', 
    Role INT 'Role', 
    MirroringState TINYINT 'MirroringState', 
    WitnessStatus TINYINT 'WitnessStatus', 
    LogGeneratRate INT 'LogGeneratRate', 
    UnsentLog INT 'UnsentLog', 
    SentRate INT 'SentRate', 
    UnrestoredLog INT 'UnrestoredLog', 
    RecoveryRate INT 'RecoveryRate', 
    TransactionDelay INT 'TransactionDelay', 
    TransactionPerSec INT 'TransactionPerSec', 
    AverageDelay INT 'AverageDelay', 
    TimeRecorded DATETIME 'TimeRecorded', 
    TimeBehind DATETIME 'TimeBehind', 
    LocalTime DATETIME 'LocalTime' 
	);

	INSERT [Client].Offset
	        ( guid, VolumeName, MB )
	SELECT @guid [guid],Volume,MB
	FROM OPENXML(@hDoc, 'SiteReview/Offset/Data')--Offset
	WITH 
	(Volume sysname 'Volume',
	MB BIGINT 'MB'
	);

	INSERT [Client].[Logins]
	SELECT @guid [guid],Name,Header,Salt,password_hash
	FROM OPENXML(@hDoc, 'SiteReview/login/Data')--[Logins]
	WITH 
	(Name sysname 'Name',
	 Header VARBINARY(MAX) 'Header',
	 Salt VARBINARY(MAX) 'Salt',
	 password_hash  VARBINARY(MAX) 'password_hash'
	);

	INSERT [Client].Latency
	        ( guid ,
	          Drive ,
	          type ,
	          num_of_reads ,
	          io_stall_read_ms ,
	          num_of_writes ,
	          io_stall_write_ms ,
	          num_of_bytes_read ,
	          num_of_bytes_written ,
	          io_stall ,
	          ReadLatency ,
	          WriteLatency ,
	          OverallLatency ,
	          AvgBytesRead ,
	          AvgBytesWrite ,
	          AvgBytesTransfer
	        )
	SELECT @guid [guid],
	          Drive ,
	          type ,
	          num_of_reads ,
	          io_stall_read_ms ,
	          num_of_writes ,
	          io_stall_write_ms ,
	          num_of_bytes_read ,
	          num_of_bytes_written ,
	          io_stall ,
	          ReadLatency ,
	          WriteLatency ,
	          OverallLatency ,
	          AvgBytes_Read ,
	          AvgBytes_Write ,
	          AvgBytes_Transfer
	FROM OPENXML(@hDoc, 'SiteReview/Latency/Data')--Latency
	WITH 
	(Drive sysname 'Drive',
	type INT 'type',
	num_of_reads BIGINT 'num_of_reads',
	io_stall_read_ms BIGINT 'io_stall_read_ms',
	num_of_writes BIGINT 'num_of_writes',
	io_stall_write_ms BIGINT 'io_stall_write_ms',
	num_of_bytes_read BIGINT 'num_of_bytes_read',
	num_of_bytes_written BIGINT 'num_of_bytes_written',
	io_stall BIGINT 'io_stall',
	ReadLatency BIGINT 'ReadLatency',
	WriteLatency BIGINT 'WriteLatency',
	OverallLatency BIGINT 'OverallLatency',
	AvgBytes_Read BIGINT 'AvgBytes_Read',
	AvgBytes_Write BIGINT 'AvgBytes_Write',
	AvgBytes_Transfer BIGINT 'AvgBytes_Transfer'
		);

	INSERT [Client].MasterFiles
	        ( guid ,
	          size ,
	          file_id ,
	          database_id ,
	          type
	        )
	SELECT @guid [guid], size ,
                        file_id ,
                        database_id ,
                        type
	          
	FROM OPENXML(@hDoc, 'SiteReview/MasterFiles/Data')--MasterFiles
	WITH 
	(size INT 'size',
	file_id INT 'file_id',
	database_id INT 'database_id',
	type INT 'type'
	);

	INSERT [Client].HADRStatus
	        ( guid, TypeID, Msg )
	SELECT @guid [guid], ID,msg
	FROM OPENXML(@hDoc, 'SiteReview/HADRState/Data')--Latency
	WITH 
	(ID INT 'ID',
	msg NVARCHAR(MAX) 'msg'
	);

	INSERT [Client].os_schedulers
	        ( guid ,
	          scheduler_id ,
	          current_tasks_count ,
	          runnable_tasks_count ,
	          pending_disk_io_count,
			  status,
			  parent_node_id,
			  is_online,
			  is_idle,
			  active_workers_count
	        )
	SELECT	@guid [guid], 
			scheduler_id ,
            current_tasks_count ,
            runnable_tasks_count ,
            pending_disk_io_count,
			status,
			parent_node_id,
			is_online,
			is_idle,
			active_workers_count
	FROM OPENXML(@hDoc, 'SiteReview/os_schedulers/Data')--Latency
	WITH 
	(scheduler_id INT 'scheduler_id',
	current_tasks_count INT 'current_tasks_count',
	runnable_tasks_count INT 'runnable_tasks_count',
	pending_disk_io_count INT 'pending_disk_io_count',
	status NVARCHAR(60) 'status',
	parent_node_id INT 'parent_node_id',
	is_online BIT 'is_online',
	is_idle BIT 'is_idle',
	active_workers_count INT 'active_workers_count'
	);

	INSERT Client.Jobs
	        ( guid ,
	          JobName ,
	          RunDateTime ,
	          RunDurationMinutes,
			  [Type]
	        )
	SELECT @guid [guid], JobName ,
                        RunDateTime ,
                        RunDurationMinutes,
						[Type]
	FROM OPENXML(@hDoc, 'SiteReview/Jobs/Data')--Jobs
	WITH 
	(JobName sysname 'JobName',
      RunDateTime datetime 'RunDateTime',
      RunDurationMinutes INT 'RunDurationMinutes',
	  [Type] NVARCHAR(255) 'Type'
	);

	INSERT Client.JobsOut
	        ( Guid ,
	          JobName ,
	          StepID ,
	          StepName ,
	          Outcome ,
	          LastRunDatetime ,
	          SubSystem ,
	          Message ,
	          Caller
	        )
	SELECT @guid [guid], 
			  JobName ,
              StepID ,
	          StepName ,
	          Outcome ,
	          LastRunDatetime ,
	          SubSystem ,
	          Message ,
	          Caller
	FROM OPENXML(@hDoc, 'SiteReview/JobsOut/Data')--Jobs
	WITH 
	(JobName sysname 'JobName',
     [StepID] INT 'StepID', 
	 [StepName] sysname 'StepName',
	 [Outcome] NVARCHAR(255) 'Outcome',
	 [LastRunDatetime] DATETIME 'LastRunDatetime',
	 [SubSystem] NVARCHAR(512) 'SubSystem',
	 [Message] NVARCHAR(max) 'Message',
	 [Caller] NVARCHAR(255) 'Caller'
	);

	INSERT [Client].[VersionBug]
	        ( [guid] ,
	          [Version] ,
	          [Detail] ,
	          [IntDetail]
	        )
	SELECT @guid [guid], Version ,
                         Detail ,
                         IntDetail
	FROM OPENXML(@hDoc, 'SiteReview/VersionBug/Data')--Jobs
	WITH 
	(Version NVARCHAR(30) 'Version',
      Detail NVARCHAR(MAX) 'Detail',
      IntDetail INT 'IntDetail'
	);

	INSERT Client.Databases
	        ( guid ,
	          name ,
	          database_id ,
	          source_database_id ,
	          owner_sid ,
	          create_date ,
	          compatibility_level ,
	          collation_name ,
	          user_access ,
	          user_access_desc ,
	          is_read_only ,
	          is_auto_close_on ,
	          is_auto_shrink_on ,
	          state ,
	          state_desc ,
	          is_in_standby ,
	          is_cleanly_shutdown ,
	          is_supplemental_logging_enabled ,
	          snapshot_isolation_state ,
	          snapshot_isolation_state_desc ,
	          is_read_committed_snapshot_on ,
	          recovery_model ,
	          recovery_model_desc ,
	          page_verify_option ,
	          page_verify_option_desc ,
	          is_auto_create_stats_on ,
	          is_auto_create_stats_incremental_on ,
	          is_auto_update_stats_on ,
	          is_auto_update_stats_async_on ,
	          is_ansi_null_default_on ,
	          is_ansi_nulls_on ,
	          is_ansi_padding_on ,
	          is_ansi_warnings_on ,
	          is_arithabort_on ,
	          is_concat_null_yields_null_on ,
	          is_numeric_roundabort_on ,
	          is_quoted_identifier_on ,
	          is_recursive_triggers_on ,
	          is_cursor_close_on_commit_on ,
	          is_local_cursor_default ,
	          is_fulltext_enabled ,
	          is_trustworthy_on ,
	          is_db_chaining_on ,
	          is_parameterization_forced ,
	          is_published ,
	          is_subscribed ,
	          is_merge_published ,
	          is_distributor ,
	          is_broker_enabled ,
	          log_reuse_wait ,
	          log_reuse_wait_desc ,
	          is_cdc_enabled ,
	          VLFCount ,
	          NumberOfDataFiles ,
	          NumberOfLogFiles,
			  IsBizTalk,
			  IsCRMDynamics,
			  IsSharePoint,
			  IsTFS
	        )
	SELECT @guid [guid], name ,
                         database_id ,
                         NULL source_database_id ,
                         owner_sid ,
                         create_date ,
                         compatibility_level ,
                         collation_name ,
                         user_access ,
                         user_access_desc ,
                         is_read_only ,
                         is_auto_close_on ,
                         is_auto_shrink_on ,
                         state ,
                         state_desc ,
                         is_in_standby ,
                         is_cleanly_shutdown ,
                         is_supplemental_logging_enabled ,
                         snapshot_isolation_state ,
                         snapshot_isolation_state_desc ,
                         is_read_committed_snapshot_on ,
                         recovery_model ,
                         recovery_model_desc ,
                         page_verify_option ,
                         page_verify_option_desc ,
                         is_auto_create_stats_on ,
                         ISNULL(is_auto_create_stats_incremental_on,0) ,
                         is_auto_update_stats_on ,
                         is_auto_update_stats_async_on ,
                         is_ansi_null_default_on ,
                         is_ansi_nulls_on ,
                         is_ansi_padding_on ,
                         is_ansi_warnings_on ,
                         is_arithabort_on ,
                         is_concat_null_yields_null_on ,
                         is_numeric_roundabort_on ,
                         is_quoted_identifier_on ,
                         is_recursive_triggers_on ,
                         is_cursor_close_on_commit_on ,
                         is_local_cursor_default ,
                         is_fulltext_enabled ,
                         is_trustworthy_on ,
                         is_db_chaining_on ,
                         is_parameterization_forced ,
                         is_published ,
                         is_subscribed ,
                         is_merge_published ,
                         is_distributor ,
                         is_broker_enabled ,
                         log_reuse_wait ,
                         log_reuse_wait_desc ,
                         is_cdc_enabled ,
                         VLFCount ,
                         NumberOfDataFiles ,
                         NumberOfLogFiles,
						 ISNULL(IsBizTalk,0),
						 ISNULL(IsCRMDynamics,0),
						 ISNULL(IsSharePoint,0),
						 ISNULL(IsTFS,0)
	FROM OPENXML(@hDoc, 'SiteReview/Databases/Data')--DatabaseFiles
	WITH 
	(name sysname 'name',
		database_id INT 'database_id',
		source_database_id NVARCHAR(36) 'source_database_id',
		owner_sid VARBINARY(MAX) 'owner_sid',
		create_date DATETIME 'create_date',
		compatibility_level INT 'compatibility_level',
		collation_name sysname 'collation_name',
		user_access BIT 'user_access',
		user_access_desc NVARCHAR(260) 'user_access_desc',
		is_read_only BIT 'is_read_only',
		is_auto_close_on BIT 'is_auto_close_on',
		is_auto_shrink_on BIT 'is_auto_shrink_on',
		state INT 'state',
		state_desc NVARCHAR(260) 'state_desc',
		is_in_standby BIT 'is_in_standby',
		is_cleanly_shutdown BIT 'is_cleanly_shutdown',
		is_supplemental_logging_enabled BIT 'is_supplemental_logging_enabled',
		snapshot_isolation_state INT 'snapshot_isolation_state',
		snapshot_isolation_state_desc  NVARCHAR(260) 'snapshot_isolation_state_desc',
		is_read_committed_snapshot_on BIT 'is_read_committed_snapshot_on',
		recovery_model INT 'recovery_model',
		recovery_model_desc NVARCHAR(260) 'recovery_model_desc',
		page_verify_option INT 'page_verify_option',
		page_verify_option_desc NVARCHAR(260) 'page_verify_option_desc',
		is_auto_create_stats_on BIT 'is_auto_create_stats_on',
		is_auto_create_stats_incremental_on BIT 'is_auto_create_stats_incremental_on',
		is_auto_update_stats_on BIT 'is_auto_update_stats_on',
		is_auto_update_stats_async_on BIT 'is_auto_update_stats_async_on',
		is_ansi_null_default_on BIT 'is_ansi_null_default_on',
		is_ansi_nulls_on BIT 'is_ansi_nulls_on',
		is_ansi_padding_on BIT 'is_ansi_padding_on',
		is_ansi_warnings_on BIT 'is_ansi_warnings_on',
		is_arithabort_on BIT 'is_arithabort_on',
		is_concat_null_yields_null_on BIT 'is_concat_null_yields_null_on',
		is_numeric_roundabort_on BIT 'is_numeric_roundabort_on',
		is_quoted_identifier_on BIT 'is_quoted_identifier_on',
		is_recursive_triggers_on BIT 'is_recursive_triggers_on',
		is_cursor_close_on_commit_on BIT 'is_cursor_close_on_commit_on',
		is_local_cursor_default BIT 'is_local_cursor_default',
		is_fulltext_enabled BIT 'is_fulltext_enabled',
		is_trustworthy_on BIT 'is_trustworthy_on',
		is_db_chaining_on BIT 'is_db_chaining_on',
		is_parameterization_forced BIT 'is_parameterization_forced',
		is_published BIT 'is_published',
		is_subscribed BIT 'is_subscribed',
		is_merge_published BIT 'is_merge_published',
		is_distributor BIT 'is_distributor',
		is_broker_enabled BIT 'is_broker_enabled',
		log_reuse_wait INT 'log_reuse_wait',
		log_reuse_wait_desc NVARCHAR(260) 'log_reuse_wait_desc',
		is_cdc_enabled BIT 'is_cdc_enabled',
		VLFCount INT 'VLFCount',
		NumberOfDataFiles INT 'NumberOfDataFiles',
		NumberOfLogFiles INT 'NumberOfLogFiles',
		IsBizTalk BIT 'IsBizTalk',
		IsCRMDynamics BIT 'IsCRMDynamics',
		IsSharePoint BIT 'IsSharePoint',
		IsTFS BIT 'IsTFS')

		INSERT Client.ProductVersion
		        ( Guid, Version )
		SELECT @guid [guid], [ProductVersion]
		FROM OPENXML(@hDoc, 'SiteReview/MachineSettings/Data')--MachineSettings
		WITH 
		([ProductVersion] NVARCHAR(128) 'ProductVersion');


	INSERT INTO Client.[MachineSettings]
			   ([ServerName]
			   ,[MachineName]
			   ,[Instance]
			   ,[ProcessorCount]
			   ,[ProcessorName]
			   ,[PhysicalMemory]
			   ,[SQLAccount]
			   ,[SQLAgentAccount]
			   ,[AuthenticationnMode]
			   ,[Version]
			   ,[Edition]
			   ,[Collation]
			   ,[ProductLevel]
			   ,[SystemModel]
			   ,[guid]
			   ,[ServerStartTime]
			   ,[ProductVersion]
			   ,InstantInitializationDisabled
			   ,LockPagesInMemoryDisabled
			   ,MaxClockSpeed
			   ,CurrentClockSpeed)
	SELECT [ServerName], [MachineName], [Instance], [ProcessorCount], [ProcessorName], [PhysicalMemory], [SQLAccount], [SQLAgentAccount], [AuthenticationnMode], [Version], [Edition], [Collation], [ProductLevel], [SystemModel], @guid [guid], [ServerStartTime],[ProductVersion],InstantInitializationDisabled
			   ,LockPagesInMemoryDisabled
			   ,MaxClockSpeed
			   ,CurrentClockSpeed
	FROM OPENXML(@hDoc, 'SiteReview/MachineSettings/Data')--MachineSettings
	WITH 
	(ServerName sysname 'ServerName'
	, MachineName [NVARCHAR](MAX) 'MachineName'
	, Instance [NVARCHAR](MAX) 'Instance'
	, ProcessorCount [INT] 'ProcessorCount'
	, ProcessorName [NVARCHAR](MAX) 'ProcessorName'
	, PhysicalMemory [NVARCHAR](MAX) 'PhysicalMemory'
	, SQLAccount [NVARCHAR](MAX) 'SQLAccount'
	, SQLAgentAccount [NVARCHAR](MAX) 'SQLAgentAccount'
	, AuthenticationnMode [NVARCHAR](MAX) 'AuthenticationnMode'
	, Version [NVARCHAR](MAX) 'Version'
	, [ProductVersion] NVARCHAR(128) 'ProductVersion'
	, Edition [NVARCHAR](MAX) 'Edition'
	, Collation [NVARCHAR](MAX) 'Collation'
	, ProductLevel [NVARCHAR](MAX) 'ProductLevel'
	, SystemModel [NVARCHAR](MAX) 'SystemModel'
	, ServerStartTime [NVARCHAR](255) 'ServerStartTime'
	,InstantInitializationDisabled BIT 'InstantInitializationDisabled'
	,LockPagesInMemoryDisabled BIT 'LockPagesInMemoryDisabled'
	,MaxClockSpeed INT 'MaxClockSpeed'
	,CurrentClockSpeed INT 'CurrentClockSpeed'
	);

	INSERT [Client].ServerServices
	        ( Guid,ServiceName ,
	          StartupTypeDesc ,
	          StartupType ,
	          Status ,
	          StatusDesc ,
	          ServiceAccount
	        )

	SELECT @guid [guid], ServiceName ,
                         StartupTypeDesc ,
                         StartupType ,
                         Status ,
                         StatusDesc ,
                         ServiceAccount
	FROM OPENXML(@hDoc, 'SiteReview/server_services/Data')--MachineSettings
	WITH 
	(	ServiceName sysname 'servicename',
		StartupTypeDesc sysname 'startup_type_desc',
		StartupType INT 'startup_type',
		Status INT 'status',
		StatusDesc sysname 'status_desc',
		ServiceAccount sysname 'service_account'
	);


	INSERT [Client].ServerProporties
	        ( guid ,
	          logicalCPU ,
	          CPU_Core ,
	          hyperthread_ratio ,
	          VirtualMemory ,
	          Committed ,
	          CommittedTarget ,
	          VisibleTarget ,
	          os_quantum ,
	          os_error_mode ,
	          os_priority_class ,
	          max_workers_count ,
	          scheduler_count ,
	          scheduler_total_count ,
	          deadlock_monitor_serial_number ,
	          sqlserver_start_time ,
	          affinity_type ,
	          virtual_machine_type ,
	          OS_bit ,
	          PlatformType ,
	          ThreadStack ,
	          OS_Mem ,
	          PLE,
			  PhysicalMemory,
			  OSName
	        )
	SELECT @guid [guid],
	          logicalCPU ,
	          CPU_Core ,
	          hyperthread_ratio ,
	          VirtualMemory ,
	          Committed ,
	          CommittedTarget ,
	          VisibleTarget ,
	          os_quantum ,
	          os_error_mode ,
	          os_priority_class ,
	          max_workers_count ,
	          scheduler_count ,
	          scheduler_total_count ,
	          deadlock_monitor_serial_number ,
	          sqlserver_start_time ,
	          affinity_type ,
	          virtual_machine_type ,
	          OS_bit ,
	          PlatformType ,
	          ThreadStack ,
	          OS_Mem,@PLE,PhysicalMemory,OSName
	FROM OPENXML(@hDoc, 'SiteReview/ServerProporties/Data')--MachineSettings
	WITH 
	(logicalCPU INT 'logicalCPU',
	CPU_Core INT 'CPU_Core',
	hyperthread_ratio INT 'hyperthread_ratio',
	VirtualMemory BIGINT 'VirtualMemory',
	PhysicalMemory BIGINT 'PhysicalMemory',
	Committed INT 'Committed',
	CommittedTarget INT 'CommittedTarget',
	VisibleTarget INT 'VisibleTarget',
	os_quantum INT 'os_quantum',
	os_error_mode INT 'os_error_mode',
	os_priority_class INT 'os_priority_class',
	max_workers_count INT 'max_workers_count',
	scheduler_count INT 'scheduler_count',
	scheduler_total_count INT 'scheduler_total_count',
	deadlock_monitor_serial_number bigINT 'deadlock_monitor_serial_number',
	sqlserver_start_time DATETIME 'sqlserver_start_time',
	affinity_type INT 'affinity_type',
	virtual_machine_type INT 'virtual_machine_type',
	OS_bit INT 'OS_bit',
	PlatformType INT 'PlatformType',
	ThreadStack INT 'ThreadStack',
	OS_Mem FLOAT 'OS_Mem',
	OSName NVARCHAR(1000) 'OSName'
	);

	INSERT [Client].[Servers]
	        ( [guid] ,
	          [server_id] ,
	          [name] ,
	          [data_source] ,
	          [is_linked]
	        )
	SELECT  @guid [guid],server_id,name,data_source,is_linked
	FROM OPENXML(@hDoc, 'SiteReview/servers/Data')--Linked Servers
	WITH 
	(server_id INT 'server_id',
	name sysname 'name',
	data_source NVARCHAR(max) 'data_source',
	is_linked BIT 'is_linked'
	);

	INSERT Client.KB
	        ( guid, KBID )
	SELECT  @guid [guid],KBID
	FROM OPENXML(@hDoc, 'SiteReview/KB/Data')--Linked Servers
	WITH 
	(KBID VARCHAR(255) 'KBID'
	);

	INSERT [Client].AlwaysOnLatency
	        ( Guid ,
	          AlwaysOnGroup ,
	          PrimaryServer ,
	          SecondaryServer ,
	          database_name ,
	          last_commit_time ,
	          DR_commit_time ,
	          lag_in_milliseconds
	        )
	SELECT  @guid [guid], AlwaysOnGroup,PrimaryServer,SecondaryServer,database_name,last_commit_time,DR_commit_time,lag_in_milliseconds
	FROM OPENXML(@hDoc, 'SiteReview/AlwaysOnLatency/Data')--AlwaysOnLatency
	WITH 
	(AlwaysOnGroup	sysname	'AlwaysOnGroup'
,PrimaryServer	nvarchar(256)	'PrimaryServer'
,SecondaryServer	nvarchar(256)	'SecondaryServer'
,database_name	nvarchar(128)	'database_name'
,last_commit_time	datetime	'last_commit_time'
,DR_commit_time	datetime	'DR_commit_time'
,lag_in_milliseconds	INT	'lag_in_milliseconds'
	);


	INSERT [Client].HADR
	        ( guid ,
	          replica_server_name ,
	          database_name ,
	          ag_name ,
	          is_local ,
	          synchronization_state_desc ,
	          is_commit_participant ,
	          synchronization_health_desc ,
	          recovery_lsn ,
	          truncation_lsn ,
	          last_sent_lsn ,
	          last_sent_time ,
	          last_received_lsn ,
	          last_received_time ,
	          last_hardened_lsn ,
	          last_hardened_time ,
	          last_redone_lsn ,
	          last_redone_time ,
	          log_send_queue_size ,
	          log_send_rate ,
	          redo_queue_size ,
	          redo_rate ,
	          filestream_send_rate ,
	          end_of_log_lsn ,
	          last_commit_lsn ,
	          last_commit_time
	        )
	SELECT  @guid [guid] , 
			replica_server_name,
            database_name ,
            ag_name ,
            is_local ,
            synchronization_state_desc ,
            is_commit_participant ,
            synchronization_health_desc ,
            IIF(recovery_lsn = '',NULL,TRY_CONVERT(NUMERIC(25,0),recovery_lsn)) ,
            IIF(truncation_lsn  = '',NULL,TRY_CONVERT(NUMERIC(25,0),truncation_lsn)),
            IIF(last_sent_lsn  = '',NULL,TRY_CONVERT(NUMERIC(25,0),last_sent_lsn)),
            last_sent_time ,
            IIF(last_received_lsn  = '',NULL,TRY_CONVERT(NUMERIC(25,0),last_received_lsn)),
            last_received_time ,
            IIF(last_hardened_lsn  = '',NULL,TRY_CONVERT(NUMERIC(25,0),last_hardened_lsn)),
            last_hardened_time ,
            IIF(last_redone_lsn  = '',NULL,TRY_CONVERT(NUMERIC(25,0),last_redone_lsn)),
            last_redone_time ,
            log_send_queue_size ,
            log_send_rate ,
            redo_queue_size ,
            redo_rate ,
            filestream_send_rate ,
            IIF(end_of_log_lsn = '',NULL,TRY_CONVERT(NUMERIC(25,0),end_of_log_lsn)),
            IIF(last_commit_lsn = '',NULL,TRY_CONVERT(NUMERIC(25,0),last_commit_lsn)),
            last_commit_time
	FROM OPENXML(@hDoc, 'SiteReview/HADR/Data')--HADR
	WITH 
	(replica_server_name	nvarchar(256)	'replica_server_name'
	,database_name	sysname	'database_name'
	,ag_name	sysname	'ag_name'
	,is_local	bit	'is_local'
	,synchronization_state_desc	nvarchar(60)	'synchronization_state_desc'
	,is_commit_participant	bit	'is_commit_participant'
	,synchronization_health_desc	nvarchar(60)	'synchronization_health_desc'
	,recovery_lsn	VARCHAR(25)	'recovery_lsn'
	,truncation_lsn	VARCHAR(25)	'truncation_lsn'
	,last_sent_lsn	VARCHAR(25)	'last_sent_lsn'
	,last_sent_time	datetime	'last_sent_time'
	,last_received_lsn	VARCHAR(25)	'last_received_lsn'
	,last_received_time	datetime	'last_received_time'
	,last_hardened_lsn	VARCHAR(25)	'last_hardened_lsn'
	,last_hardened_time	datetime	'last_hardened_time'
	,last_redone_lsn	VARCHAR(25)	'last_redone_lsn'
	,last_redone_time	datetime	'last_redone_time'
	,log_send_queue_size	bigint	'log_send_queue_size'
	,log_send_rate	bigint	'log_send_rate'
	,redo_queue_size	bigint	'redo_queue_size'
	,redo_rate	bigint	'redo_rate'
	,filestream_send_rate	bigint	'filestream_send_rate'
	,end_of_log_lsn	VARCHAR(25)	'end_of_log_lsn'
	,last_commit_lsn	VARCHAR(25)	'last_commit_lsn'
	,last_commit_time	datetime	'last_commit_time'
	);

	INSERT [Client].Replications
	        ( guid ,
	          ID ,
	          [Messages] ,
	          [Type] ,
	          Link
	        )
	SELECT  @guid [guid], ID ,
                         [Messages] ,
                         [Type] ,
                         IIF(Link = '',NULL,Link)
	FROM OPENXML(@hDoc, 'SiteReview/Replications/Data')--Replications
	WITH 
	(ID INT 'ID',
	[Messages] NVARCHAR(MAX) 'Messages',
	[Type] sysname 'Type',
	Link NVARCHAR(MAX) 'Link'
	);

	INSERT [Client].Blitz
	        ( guid ,
	          ID ,
	          ServerName ,
	          CheckDate ,
	          BlitzVersion ,
	          Priority ,
	          FindingsGroup ,
	          Finding ,
	          DatabaseName ,
	          URL ,
	          Details ,
	          CheckID
	        )
	SELECT  @guid [guid], ID ,
                         ServerName ,
                         CheckDate ,
                         BlitzVersion ,
                         Priority ,
                         FindingsGroup ,
                         Finding ,
                         DatabaseName ,
                         URL ,
                         Details ,
                         CheckID
	FROM OPENXML(@hDoc, 'SiteReview/Blitz/Data')--OrphanedSQLFile
	WITH 
	(ID INT 'ID',
	ServerName sysname 'ServerName',
	CheckDate DATETIME 'CheckDate',
	BlitzVersion INT 'BlitzVersion',
	Priority INT 'Priority',
	FindingsGroup VARCHAR(50) 'FindingsGroup',
	Finding VARCHAR(200) 'Finding',
	[DatabaseName] [NVARCHAR](128) 'DatabaseName',
	[URL] [VARCHAR](200) 'URL',
	[Details] [NVARCHAR](4000) 'Details',
	[CheckID] [INT] 'CheckID'
	);



	--INSERT dbo.JobOutcome
	--        ( JobName ,
	--          StepID ,
	--          StepName ,
	--          Outcome ,
	--          LastRunDatetime ,
	--          Difference ,
	--          SubSystem ,
	--          Message ,
	--          Caller ,
	--          Guid
	--        )
	--SELECT JobName ,
 --          StepID ,
 --          StepName ,
 --          Outcome ,
 --          LastRunDatetime ,
 --          Diff ,
 --          SubSystem ,
 --          Message ,
 --          Caller,
	--	   @guid
	--FROM OPENXML(@hDoc, 'SiteReview/JobOut/JobOut_Data')--TopQueries
	--WITH 
	--([JobName] sysname 'JobName',[StepID] INT 'StepID', [StepName] sysname 'StepName',[Outcome] NVARCHAR(255) 'Outcome',
	--	[LastRunDatetime] DATETIME 'LastRunDatetime',
	--	[Diff] VARCHAR(50) 'Diff',
	--	[SubSystem] NVARCHAR(512) 'SubSystem',
	--	[Message] NVARCHAR(max) 'Message',
	--	[Caller] NVARCHAR(255) 'Caller'

	--);

	COMMIT
	
	
	END TRY
	BEGIN CATCH
		ROLLBACK;
		THROW;
	END CATCH

	EXEC sp_xml_removedocument @hDoc;



END





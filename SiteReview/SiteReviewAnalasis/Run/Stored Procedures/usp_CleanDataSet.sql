
-- =============================================
-- Author:		Sharon
-- Create date: 07/06/2016
-- Description:	Get Excluded DB
-- =============================================
CREATE PROCEDURE [Run].[usp_CleanDataSet]
	@guid UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;

	IF @guid IS NULL
	BEGIN
		RAISERROR('@guid Can not be NULL',16,1);
		RETURN -1;
	END
	
	DELETE FROM [Client].[Blitz] WHERE guid = @guid;
	DELETE FROM [Client].[Databases] WHERE guid = @guid;
	DELETE FROM [Client].[Jobs] WHERE guid = @guid;
	DELETE FROM [Client].[JobsOut] WHERE Guid = @guid;
	DELETE FROM [Client].[HADR] WHERE guid = @guid;
	DELETE FROM [Client].[HADRServices] WHERE guid = @guid;
	DELETE FROM [Client].[AlwaysOnLatency] WHERE guid = @guid;
	DELETE FROM [Client].[HADRStatus] WHERE guid = @guid;
	DELETE FROM [Client].[Mirror] WHERE guid = @guid;
	DELETE FROM [Client].[Latency] WHERE guid = @guid;
	DELETE FROM [Client].[Logins] WHERE guid = @guid;
	DELETE FROM [Client].[MachineSettings] WHERE guid = @guid;
	DELETE FROM [Client].[MasterFiles] WHERE guid = @guid;
	DELETE FROM [Client].[Offset] WHERE guid = @guid;
	DELETE FROM [Client].[os_schedulers] WHERE guid = @guid;
	DELETE FROM [Client].[ProductVersion] WHERE guid = @guid;
	DELETE FROM [Client].[Registery] WHERE guid = @guid;
	DELETE FROM [Client].[ReportMetaData] WHERE ReportGUID = @guid;
	DELETE FROM [Client].[ServerProporties] WHERE guid = @guid;
	DELETE FROM [Client].[Servers] WHERE guid = @guid;
	DELETE FROM [Client].[ServerServices] WHERE guid = @guid;
	DELETE FROM [Client].[SPConfigure] WHERE guid = @guid;
	DELETE FROM [Client].[TraceFlag] WHERE guid = @guid;
	DELETE FROM [Client].[VersionBug] WHERE guid = @guid;
	DELETE FROM [Client].[Volumes] WHERE guid = @guid;
	DELETE FROM [Client].[Software] WHERE guid = @guid;
	DELETE FROM [Client].[DatabaseFiles] WHERE guid = @guid;
	DELETE FROM [Client].[DatabaseProperties] WHERE guid = @guid;
	DELETE FROM [Client].[Replications] WHERE guid = @guid;
	DELETE FROM [Client].[DebugError] WHERE guid = @guid;
	
	DELETE FROM [Client].[SysAdmin] WHERE guid = @guid;
	DELETE FROM [Client].CPUHistory WHERE guid = @guid;
	DELETE FROM [Client].HeavyQueries WHERE guid = @guid;
	--DELETE FROM [Client].[RemoteServerNode] WHERE guid = @guid;
	
END



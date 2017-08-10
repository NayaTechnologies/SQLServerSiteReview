-- =============================================
-- Author:		Sharon
-- Create date: 2012
-- Update date: 2016/06/08 Sharon
--				2016/07/21 Sharon Utility.ufn_Util_clr_RegexReplace(Version,'Microsoft SQL Server [\d]+ \- ([\d]+\.[\d]+\.[\d]+\.[\d]+)[\W\w]*','$1',0)
-- Description:	
-- =============================================
CREATE PROCEDURE [GUI].[usp_GetSQLSettings] @guid UNIQUEIDENTIFIER
AS
BEGIN
	SET NOCOUNT ON;

	
	DECLARE @Ver NVARCHAR(128) ;
	SELECT	@Ver = ISNULL(ProductVersion,Utility.ufn_Util_clr_RegexReplace(Version,'Microsoft SQL Server [\d]+ \- ([\d]+\.[\d]+\.[\d]+\.[\d]+)[\W\w]*','$1',0))
	FROM	Client.[MachineSettings]
    WHERE   guid = @guid;

	--OS Mem: 1GB for every 4 CPU Cores 
	DECLARE @PhysicalMemory INT,
			@vCPU INT,
			@VMOverhead INT 
	SELECT	@PhysicalMemory = SP.PhysicalMemory/1024 --MB
			,@vCPU = SP.logicalCPU
	FROM	Client.ServerProporties SP
	WHERE	SP.guid = @guid
	OPTION(RECOMPILE);

	SELECT	@VMOverhead = mo.Memory_MB
	FROM	Configuration.[VM_MemoryOverhead] mo
	WHERE	mo.vCPU = CASE WHEN @vCPU > 8 THEN 8 ELSE @vCPU END
			AND @PhysicalMemory BETWEEN VM_Memory_MB_From AND VM_Memory_MB_Till
	OPTION(RECOMPILE);

	SELECT	R.Service [Subject],CONVERT(NVARCHAR(MAX),'The SQL Server service is calling home.') [Status],CONVERT(NVARCHAR(MAX),'Change Customer Feedback to false')[Reco],'Black' [Color],NULL [Link]
	FROM	Client.Registery R
	WHERE	R.guid = @guid
			AND R.CurrentInstance = 1
			AND R.Service = 'Customer Feedback Enabled'
			AND R.Value != '1'
	UNION ALL 
	SELECT	R.Service [Subject],'The SQL Server service is reporting product error to Microsoft.' [Status],'Change Error Reporting to false.'[Reco],'Black' [Color],NULL [Link]
	FROM	Client.Registery R
	WHERE	R.guid = @guid
			AND R.CurrentInstance = 1
			AND R.Service = 'Error Reporting Enabled'
			AND R.Value = '1'
	UNION ALL 
	SELECT	R.Service [Subject],'The number of error log files - ' + R.Value + '.' [Status],'Increase the number of <font color =Blue><HRef="https://msdn.microsoft.com/en-us/library/ms177285.aspx"><U>error log</U></A></font> to 30. Than add Job to cycle the error log etch day.'[Reco],'Black' [Color],NULL [Link]
	FROM	Client.Registery R
	WHERE	R.guid = @guid
			AND R.CurrentInstance = 1
			AND R.Service = 'Number Error Logs'
			AND R.Value = '6'
	UNION ALL 
	SELECT	'Number Error Logs' [Subject],'The number of error log files - 6.' [Status],'Increase the number of <font color =Blue><HRef="https://msdn.microsoft.com/en-us/library/ms177285.aspx"><U>error log</U></A></font> to 30. Than add Job to cycle the error log etch day.'[Reco],'Black' [Color],NULL [Link]
	WHERE	NOT EXISTS (SELECT TOP 1 1 
		FROM	Client.Registery R
		WHERE	R.guid = @guid
				AND R.CurrentInstance = 1
				AND R.Service = 'Number Error Logs')
	UNION ALL 
	SELECT	'Service startup type'[Subject],'Startup type of service - ' + SS.ServiceName + ' is confugured to - <B>' + SS.StartupTypeDesc + '</B>.'  [Status],'Change startup type of service to "<B>Automatic</B>".'[Reco],'Black' [Color],NULL [Link]
	FROM	Client.ServerServices SS
	WHERE	SS.Guid = @guid
			AND SS.StartupType != 2 --Auto
	UNION ALL 
	SELECT	TOP 1 'Service state'[Subject],'SQL Server Agent is in state - <B>Stopped</B>'[Status],'Turn on the service'[Reco],'Black' [Color],NULL [Link]
	FROM	Client.ServerServices SS
	WHERE	servicename LIKE 'SQL Server Agent%'
			AND status = 1
			AND SS.Guid = @guid
	UNION ALL 
	SELECT	'TraceFlag',IIF(CTF.[Link] IS NOT NULL,CONCAT('<font color =Blue><HRef="',CTF.[Link],'"><U>TraceFlag</U></A></font>'),'TraceFlag') + ' No-' + CONVERT(NVARCHAR(25),CTF.TraceFlag) + ' (' + CTF.Description + ') is off.','Consider this SQL startup traceflags. Remember, the answer to “should I do this on all my servers?” is not “<strong>yes</strong>”, the answer is “<strong>it depends on the situation</strong>”.<br>
* ' + IIF(CTF.[Link] IS NOT NULL,CONCAT('<font color =Blue><HRef="',CTF.[Link],'"><U>',CONVERT(NVARCHAR(25),CTF.TraceFlag),'</U></A></font>',CASE 
WHEN CTF.TraceFlag = 1118 THEN ' (reduce tempdb contention, <font color =Blue><HRef="http://www.sqlskills.com/blogs/paul/misconceptions-around-tf-1118"><U>Paul says everyone should turn it on, there’s no downside.</U></A></font>)'
WHEN CTF.TraceFlag = 1222 THEN ' (<font color =Blue><HRef="https://www.simple-talk.com/sql/database-administration/handling-deadlocks-in-sql-server"><U>XML deadlock graph</U></A></font>, you’re unlikely to get deadlocks because we find most of them while dogfooding, but this information is useful if you do hit them.)'
WHEN CTF.TraceFlag = 1117 THEN ' (equal file autogrowth for tempdb files).'
WHEN CTF.TraceFlag = 1211 THEN ' (prevent table lock escalation) (<font color =Blue><HRef="http://support.microsoft.com/kb/934005"><U>KB934005</U></A></font>)'
ELSE ''
END,IIF(STF.Software != '' ,'-<strong> ' + STF.Software + ' Best Practices</strong>','')),CONVERT(NVARCHAR(25),CTF.TraceFlag)) + '.',IIF(CTF.Link IS NULL,'Black','Blue') [Color],CTF.[Link]
	FROM	Configuration.TraceFlag CTF
			LEFT JOIN Client.TraceFlag TF ON TF.TraceFlag = CTF.TraceFlag
				AND TF.guid = @guid
			OUTER APPLY(SELECT Utility.ufn_Util_clr_Conc(STF.Software)Software FROM Configuration.SoftwareTraceFlage STF WHERE STF.TraceFlag = CTF.TraceFlag
				AND STF.Software IN (SELECT S.Software FROM Client.Software S WHERE S.Status = 1 AND S.guid = @guid))STF
	WHERE	TF.guid IS NULL
			AND @Ver BETWEEN ISNULL(CTF.FromProductVersion,@Ver) AND ISNULL(CTF.ToProductVersion,@Ver)
			AND CTF.TraceFlag NOT IN (1448)

	UNION ALL 
	SELECT	'TraceFlag',IIF(CTF.[Link] IS NOT NULL,CONCAT('<font color =Blue><HRef="',CTF.[Link],'"><U>TraceFlag</U></A></font>'),'TraceFlag') + ' No-' + CONVERT(NVARCHAR(25),CTF.TraceFlag) + ' (' + CTF.Description + ') is off.','Consider this SQL startup traceflags. Remember, the answer to “should I do this on all my servers?” is not “yes”, the answer is “it depends on the situation”.<br>
* ' + IIF(CTF.[Link] IS NOT NULL,CONCAT('<font color =Blue><HRef="',CTF.[Link],'"><U>',CONVERT(NVARCHAR(25),CTF.TraceFlag),'</U></A></font>'),CONVERT(NVARCHAR(25),CTF.TraceFlag)) + '.',IIF(CTF.Link IS NULL,'Black','Blue') [Color],CTF.[Link]
	FROM	Configuration.TraceFlag CTF
			LEFT JOIN Client.TraceFlag TF ON TF.TraceFlag = CTF.TraceFlag
				AND TF.guid = @guid
	WHERE	TF.guid IS NULL
			AND @Ver BETWEEN ISNULL(CTF.FromProductVersion,@Ver) AND ISNULL(CTF.ToProductVersion,@Ver)
			AND	EXISTS (SELECT TOP 1 1 FROM Client.HADRServices HS WHERE HS.Guid = @guid AND HS.AlwaysOn = 1 AND HS.[Replication] = 1)
			AND CTF.TraceFlag = 1448
	UNION ALL 
	SELECT	'LinkedServer','The LinkedServer (' + S.name +' - ' + S.data_source + ') is configured to work with IP address.','Change to DNS name. On DR based IP This will not work automaticly.','Black' [Color],NULL [Link]
	FROM	Client.Servers S
	WHERE	S.guid = @guid
			AND S.is_linked = 1
			AND Utility.ufn_Util_clr_RegexIsMatch(S.data_source,'^\d*\.\d*\.\d*\.\d*') = 1
	UNION ALL 
	-- Sustained values above 10 suggest further investigation in that area
	-- High Avg Task Counts are often caused by blocking or other resource contention
	
	SELECT  'Server Task' Type,
			'Avg Task Count ' + CONVERT(varchar(25),AVG(current_tasks_count)) ,
			'High Avg Task Counts are often caused by blocking or other resource contention','Black' [Color],NULL [Link]
	FROM    Client.os_schedulers OS
	WHERE   scheduler_id < 255
			AND OS.guid = @guid
	HAVING AVG(current_tasks_count) > 10
	UNION ALL 
	-- High Avg Runnable Task Counts are a good sign of CPU pressure
	SELECT 'CPU' Type,
			'Avg Runnable Task Count ' + CONVERT(varchar(25),AVG(runnable_tasks_count)) ,
			'High Avg Runnable Task Counts are a good sign of CPU pressure','Black' [Color],NULL [Link]
	FROM    Client.os_schedulers OS
	WHERE   scheduler_id < 255
			AND OS.guid = @guid
	HAVING AVG(runnable_tasks_count) > 10
	UNION ALL 
	-- High Avg Pending DiskIO Counts are a sign of disk pressure
	SELECT  'CPU' Type,
			'Avg Pending DiskIO Count ' + CONVERT(varchar(25),AVG(pending_disk_io_count)) ,
			'High Avg Pending DiskIO Counts are a sign of disk pressure'  Action,'Black' [Color],NULL [Link]
	FROM    Client.os_schedulers OS
	WHERE   scheduler_id < 255
			AND OS.guid = @guid
	HAVING AVG(pending_disk_io_count) > 10
	UNION ALL 
	SELECT	'CPU','Max worker threads:' + CONVERT(VARCHAR(10), SP.max_workers_count),'Max worker threads shuold be 0 or Total available logical CPU’s <= 4 : 512 On 64bit system','Black' [Color],NULL [Link]
	FROM	Client.ServerProporties SP
	WHERE	SP.guid = @guid
			AND SP.OS_bit = 64
			AND SP.logicalCPU <= 4
			AND SP.max_workers_count NOT IN (0,512)
	UNION ALL 
	SELECT	'CPU','Max worker threads:' + CONVERT(VARCHAR(10), SP.max_workers_count),'Max worker threads shuold be 0 or Total available logical CPU’s > 4 : 512 + ((logical CPU - 4) * 16)) On 64bit system','Black' [Color],NULL [Link]
	FROM	Client.ServerProporties SP
	WHERE	SP.guid = @guid
			AND SP.OS_bit = 64
			AND SP.logicalCPU > 4
			AND SP.max_workers_count NOT IN (0,512 + ((SP.logicalCPU - 4) * 16))
	UNION ALL 
	SELECT	'CPU','Max worker threads:' + CONVERT(VARCHAR(10), SP.max_workers_count),'Max worker threads shuold be 0 or Total available logical CPU’s <= 4 : 256 On 32bit system','Black' [Color],NULL [Link]
	FROM	Client.ServerProporties SP
	WHERE	SP.guid = @guid
			AND SP.OS_bit = 32
			AND SP.logicalCPU <= 4
			AND SP.max_workers_count NOT IN (0,256)
	UNION ALL 
	SELECT	'CPU','Max worker threads:' + CONVERT(VARCHAR(10), SP.max_workers_count),'Max worker threads shuold be 0 or Total available logical CPU’s > 4 : 256 + ((logical CPU - 4) * 8)) On 32bit system','Black' [Color],NULL [Link]
	FROM	Client.ServerProporties SP
	WHERE	SP.guid = @guid
			AND SP.OS_bit = 32
			AND SP.logicalCPU > 4
			AND SP.max_workers_count NOT IN (0,256 + ((SP.logicalCPU - 4) * 8))
	UNION ALL 
	SELECT	'CPU' ,
			'CPU resources ratio of the physical cores is 1:' + CONVERT(VARCHAR(10), OS.logicalCPU / hyperthread_ratio)  ,
			'Provide CPU resources by maintaining a 1:1 ratio of the physical cores' Action,'Black' [Color],NULL [Link]
	FROM	Client.ServerProporties OS
	WHERE   OS.guid = @guid
			AND hyperthread_ratio != 1
			AND OS.logicalCPU / hyperthread_ratio > 1
			AND OS.virtual_machine_type = 1
	UNION ALL 
	SELECT  'Memory' ,
			'Minimum Memory For This VM is ' + CONVERT(VARCHAR(50),@PhysicalMemory ) + 'MB and does not meet VM requirements: ' + CONVERT(VARCHAR(50),(CONVERT(BIGINT,value)) + OS.ThreadStack + OS.OS_Mem + @VMOverhead ) Message,
			'VM Memory = SQL Max Server Memory + ThreadStack + OS Mem + VM Overhead ' Action ,'Black' [Color],NULL [Link]
	FROM	Client.ServerProporties OS
			CROSS APPLY (SELECT TOP 1 SC.value FROM Client.SPConfigure SC WHERE SC.guid = @guid AND SC.name = 'max server memory (MB)' AND SC.value != '2147483647')C
	WHERE   OS.guid = @guid
			AND OS.virtual_machine_type = 1
			AND (CONVERT(BIGINT,C.value)) + OS.ThreadStack + OS.OS_Mem + @VMOverhead > OS.PhysicalMemory
	UNION ALL 
	SELECT	'Software',
            S.Software ,--CONCAT('<font color =Blue><HRef="',CTF.[Link],'"><U>TraceFlag</U></A></font>'),'TraceFlag')
            CONCAT(S.Software,' software installed on this server - <font color =Blue><HRef="',CS.Link,'"><U>best practice</U></A></font> are different'),
			'Blue',CS.Link
	FROM	Client.Software S
			INNER JOIN [Configuration].[Software] CS ON CS.Software = S.Software
	WHERE	S.guid = @guid
			AND S.Status = 1
	UNION ALL 
	SELECT	'SQL Server Version Bug',
			'Serious <font color =Blue><HRef="http://connect.microsoft.com/SQLServer/feedback/details/770630/msiexec-exe-processes-keep-running-after-installation-of-sql-server-2012-sp1"><U>bug</U></A></font> in SQL Server 2012 SP1, due to msiexec process keep running. registry file grow to 2GB' ,
			'<font color =Blue><HRef="https://sqlserverbuilds.blogspot.co.il/"><U>Upgrade SQL Server Version</U></A></font>',
			'Blue' [Color],
			'http://connect.microsoft.com/SQLServer/feedback/details/770630/msiexec-exe-processes-keep-running-after-installation-of-sql-server-2012-sp1' [Link]
	FROM	[Client].[VersionBug] VB
	WHERE	VB.guid = @guid
			AND VB.[Version] BETWEEN '11.0.3000.0' AND '11.00.3339.0'
			AND VB.Detail = 'msiexec'
			AND VB.IntDetail = 2
	UNION ALL 
	SELECT	'SQL Server Version Bug',
			'Serious <font color =Blue><HRef="https://blogs.msdn.microsoft.com/sqlreleaseservices/alwayson-availability-groups-may-be-reported-as-not-synchronizing-after-you-apply-sql2012-sp2-cu3-or-sql2012-sp2-cu4-or-sql2014-cu5/"><U>bug</U></A></font>- AlwaysOn Availability Groups may be reported as NOT SYNCHRONIZING after you apply SQL2012 SP2 CU3 or SQL2012 SP2 CU4 or SQL2014 CU5' ,
			'<font color =Blue><HRef="https://sqlserverbuilds.blogspot.co.il/"><U>Upgrade SQL Server Version</U></A></font>',
			'Blue' [Color],
			'https://blogs.msdn.microsoft.com/sqlreleaseservices/alwayson-availability-groups-may-be-reported-as-not-synchronizing-after-you-apply-sql2012-sp2-cu3-or-sql2012-sp2-cu4-or-sql2014-cu5/' [Link]
	FROM	Client.HADRServices HS
	WHERE	HS.guid = @guid
			AND @Ver IN ('11.00.5556','11.00.5569','12.00.2456','12.00.2464','12.00.2472')
			AND HS.AlwaysOn = 1
---------------------------------------------------------
	UNION ALL 
	SELECT	'Security ',
			Message ,
			'Change login password.',
			'Black' [Color],
			NULL [Link]
	FROM	[Client].LoginIssue LI
	WHERE	LI.guid = @guid

END
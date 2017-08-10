-- =============================================
-- Author:		Sharon
-- Create date: 11/06/2016
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [GUI].[usp_GetJobStatus] @guid UNIQUEIDENTIFIER
AS
BEGIN
    SET NOCOUNT ON;

	SELECT	CASE WHEN TRY_CONVERT(UNIQUEIDENTIFIER,J.JobName) IS NOT NULL THEN CONCAT(J.JobName,' (Report Server Subscription)') ELSE J.JobName END [JobName],
			'Change Job owner to "sa".' [Action],'Black' Color
	FROM	Client.Jobs J
	WHERE	J.guid = @guid
			AND J.[Type] = 'Owner'
	UNION ALL 
	SELECT	CASE WHEN TRY_CONVERT(UNIQUEIDENTIFIER,J.JobName) IS NOT NULL THEN CONCAT(J.JobName,' (Report Server Subscription)') ELSE J.JobName END,
			'Job duration is ' + CONVERT(VARCHAR(25),J.RunDurationMinutes) + ' minutes. Chack if its OK by you(ETL etc...).' [Action],'Orange' Color
	FROM	Client.Jobs J
	WHERE	J.guid = @guid
			AND J.[Type] = 'Over 55 Minuts'
	UNION ALL 
	SELECT	CASE WHEN TRY_CONVERT(UNIQUEIDENTIFIER,JO.JobName) IS NOT NULL THEN CONCAT(JO.JobName,' (Report Server Subscription)') ELSE CONCAT(JO.JobName,' ',JO.SubSystem) END,
			CONCAT('Job has ',JO.Outcome,' on step ',JO.StepID,'-',JO.StepName,' at ',JO.LastRunDatetime,'.
Reason - ',LEFT(M.msg,200),IIF(LEN(M.msg)>200,'...','')),'Red' Color
	FROM	Client.JobsOut JO
			CROSS APPLY (SELECT CASE WHEN CHARINDEX('Execution Status:',JO.Message) > 0 THEN SUBSTRING(JO.Message,CHARINDEX('Execution Status:',JO.Message),LEN(JO.Message))
			ELSE JO.Message
			END msg)M
	WHERE	JO.Guid = @guid
	UNION ALL 
	SELECT	mp.MaintenancePlanName,'<B>Maintplan Plans</B> conteins ' + CONVERT(VARCHAR(25),mp.NumberOfFiles) + ' <a href="https://www.mssqltips.com/sqlservertip/3225/sql-server-maintenance-plans-reporting-and-logging/">log files</a>. about ' + IIF(mp.SizeInMB = 0,'~1',CONVERT(VARCHAR(25),mp.SizeInMB)) + 'MB.','Black' Color
	FROM	[Client].[MaintenancePlanFiles] mp
	WHERE	mp.guid = @guid
			AND mp.NumberOfFiles > 0 
END

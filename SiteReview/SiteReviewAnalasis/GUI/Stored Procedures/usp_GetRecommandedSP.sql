-- =============================================
-- Author:		Sharon
-- Create date: 09/06/2016
-- Update date: 
-- Description:	Recomanded Versions
-- =============================================
CREATE PROCEDURE [GUI].[usp_GetRecommandedSP]
	@guid NVARCHAR(50),
	@Debug BIT = 0
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Ver NVARCHAR(128);
	DECLARE @SPBuild NVARCHAR(128);
	DECLARE @CUBuild NVARCHAR(128);
	DECLARE @Print NVARCHAR(2048);
	
	SELECT @Ver = CAST(ISNULL(ProductVersion,Utility.ufn_Util_clr_RegexReplace(Version,'Microsoft SQL Server [\d]+ \- ([\d]+\.[\d]+\.[\d]+\.[\d]+)[\W\w]*','$1',0))AS NVARCHAR(128))
	FROM	Client.MachineSettings MS
	WHERE	@guid = MS.guid;

	SELECT	TOP 1 @SPBuild = SSB.[FriendlyVersion]
	FROM	Configuration.SQLServerBuild SSB
			CROSS APPLY(SELECT CASE WHEN ssb.Description LIKE '%Cumulative update%' THEN 'CU'
			WHEN ssb.Description LIKE '%security update%' THEN 'SU'			
			WHEN ssb.Description LIKE '%FIX%' THEN 'FIX'
			WHEN ssb.Description LIKE '%Service Pack%' OR ssb.Description LIKE '%GDR%'  THEN 'SP'			
			WHEN ssb.Description LIKE '%TLS%' THEN 'TLS'
			WHEN ssb.Description LIKE '%RTM%' THEN 'RTM'
			WHEN ssb.Description LIKE '%CTP%' THEN 'CTP'
			ELSE NULL END [ShortName])Short
	WHERE	PARSENAME(CONVERT(VARCHAR(32), @Ver), 4) = SSB.Major
			AND CONVERT(INT,PARSENAME(CONVERT(VARCHAR(32), @Ver), 3)) = CONVERT(INT,SSB.Minor)
			AND SSB.[FriendlyVersion] > @Ver
			AND [ShortName] = 'SP'
	ORDER BY SSB.[FriendlyVersion] DESC;
	IF @Debug = 1
	BEGIN
		SET @Print = CONCAT('@SPBuild:',@SPBuild);
		RAISERROR(@Print,10,1)WITH NOWAIT;
	END 
	SELECT	TOP 1 @CUBuild = SSB.[FriendlyVersion]
	FROM	Configuration.SQLServerBuild SSB
			CROSS APPLY(SELECT CASE WHEN ssb.Description LIKE '%Cumulative update%' THEN 'CU'
			WHEN ssb.Description LIKE '%security update%' THEN 'SU'			
			WHEN ssb.Description LIKE '%FIX%' THEN 'FIX'
			WHEN ssb.Description LIKE '%Service Pack%' OR ssb.Description LIKE '%GDR%'  THEN 'SP'			
			WHEN ssb.Description LIKE '%TLS%' THEN 'TLS'
			WHEN ssb.Description LIKE '%RTM%' THEN 'RTM'
			WHEN ssb.Description LIKE '%CTP%' THEN 'CTP'
			ELSE NULL END [ShortName])Short
	WHERE	PARSENAME(CONVERT(VARCHAR(32), ISNULL(@SPBuild,@Ver)), 4) = SSB.Major
			AND CONVERT(INT,PARSENAME(CONVERT(VARCHAR(32), ISNULL(@SPBuild,@Ver)), 3)) = CONVERT(INT,SSB.Minor)
			AND SSB.Build > ISNULL(@SPBuild,@Ver)
			AND [ShortName] = 'CU'
	ORDER BY SSB.Build DESC;
	
	IF @Debug = 1
	BEGIN
		SET @Print = CONCAT('@CUBuild:',@CUBuild);
		RAISERROR(@Print,10,1)WITH NOWAIT;
	END 

	--Result
	SELECT	SSB.[FriendlyVersion] [Build],SSB.Description,SSB.ReleaseDate,
			CASE WHEN ssb.Description LIKE '%Cumulative update%' THEN 'CU'
			WHEN ssb.Description LIKE '%security update%' THEN 'SU'			
			WHEN ssb.Description LIKE '%FIX%' THEN 'FIX'
			WHEN ssb.Description LIKE '%Service Pack%' OR ssb.Description LIKE '%GDR%'  THEN 'SP'			
			WHEN ssb.Description LIKE '%TLS%' THEN 'TLS'
			WHEN ssb.Description LIKE '%RTM%' THEN 'RTM'
			WHEN ssb.Description LIKE '%CTP%' THEN 'CTP'
			ELSE NULL END [ShortName]
	 FROM	Configuration.SQLServerBuild SSB
			INNER JOIN (
						SELECT	TOP 1 *
						FROM	Configuration.SQLServerBuild SSB
						WHERE	PARSENAME(CONVERT(VARCHAR(32), @CUBuild), 4) = SSB.Major
								AND CONVERT(INT,PARSENAME(CONVERT(VARCHAR(32), @CUBuild), 3)) = CONVERT(INT,SSB.Minor)
								AND PARSENAME(CONVERT(varchar(32), @CUBuild), 2) = SSB.VersionBuild
								AND PARSENAME(CONVERT(VARCHAR(32), @CUBuild), 1) = ISNULL(SSB.Revision,PARSENAME(CONVERT(VARCHAR(32), @CUBuild), 1))
						)T ON T.Major = SSB.Major
						AND t.Minor = SSB.Minor
	 WHERE	T.[FriendlyVersion] < SSB.[FriendlyVersion]
			AND ISNULL(@SPBuild,T.[FriendlyVersion]) <= SSB.[FriendlyVersion]
			AND SSB.Build NOT IN ('11.00.9120','11.00.9000')
	UNION ALL --CU
	SELECT	TOP 1 SSB.[FriendlyVersion],SSB.Description,SSB.ReleaseDate,[ShortName]
	FROM	Configuration.SQLServerBuild SSB
			CROSS APPLY(SELECT CASE WHEN ssb.Description LIKE '%Cumulative update%' THEN 'CU'
			WHEN ssb.Description LIKE '%security update%' THEN 'SU'			
			WHEN ssb.Description LIKE '%FIX%' THEN 'FIX'
			WHEN ssb.Description LIKE '%Service Pack%' OR ssb.Description LIKE '%GDR%'  THEN 'SP'			
			WHEN ssb.Description LIKE '%TLS%' THEN 'TLS'
			WHEN ssb.Description LIKE '%RTM%' THEN 'RTM'
			WHEN ssb.Description LIKE '%CTP%' THEN 'CTP'
			ELSE NULL END [ShortName])Short
	WHERE	SSB.[FriendlyVersion] = @CUBuild
	UNION ALL--SP
	SELECT	TOP 1 SSB.[FriendlyVersion] [Build],SSB.Description,SSB.ReleaseDate,[ShortName]
	FROM	Configuration.SQLServerBuild SSB
			CROSS APPLY(SELECT CASE WHEN ssb.Description LIKE '%Cumulative update%' THEN 'CU'
			WHEN ssb.Description LIKE '%security update%' THEN 'SU'			
			WHEN ssb.Description LIKE '%FIX%' THEN 'FIX'
			WHEN ssb.Description LIKE '%Service Pack%' OR ssb.Description LIKE '%GDR%'  THEN 'SP'			
			WHEN ssb.Description LIKE '%TLS%' THEN 'TLS'
			WHEN ssb.Description LIKE '%RTM%' THEN 'RTM'
			WHEN ssb.Description LIKE '%CTP%' THEN 'CTP'
			ELSE NULL END [ShortName])Short
	WHERE	SSB.[FriendlyVersion] = @SPBuild
	ORDER BY SSB.[FriendlyVersion] DESC;

END


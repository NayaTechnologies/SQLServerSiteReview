
CREATE FUNCTION [Utility].[ufn_GetSQLServerEdition] (@Version [nvarchar](max),
@Edition  [nvarchar](max),
@ProductVersion [nvarchar](max))
RETURNS VARCHAR(1000)
AS
BEGIN
	--Declare Variables
    DECLARE @Ver NVARCHAR(128),@ResultString  VARCHAR(1000);
	SELECT  @Ver = ISNULL(@ProductVersion,Utility.ufn_Util_clr_RegexReplace(@Version,'([\W\w]*)\- ([\d]+\.[\d]+\.[\d]+\.[\d]+)[\W\w]*','$2',0))
	
	IF @Edition LIKE '%Enterprise%' AND @Edition LIKE '%Core-based%' SET @Edition = 'Enterprise Core'
	ELSE IF @Edition LIKE '%Enterprise%' SET @Edition = 'Enterprise'
	ELSE IF @Edition LIKE '%Web%' SET @Edition = 'Web'
	ELSE IF @Edition LIKE '%Express%' SET @Edition = 'Express'
	ELSE IF @Edition LIKE '%Developer%' SET @Edition = 'Developer'
	ELSE IF @Edition LIKE '%Business Intelligence%' SET @Edition = 'Business Intelligence'
	ELSE IF @Edition LIKE '%Standard%' SET @Edition = 'Standard'

	SELECT TOP 1 @ResultString = 'Microsoft SQL Server ' + CASE WHEN b.Major = 10 THEN CASE WHEN PARSENAME(CONVERT(VARCHAR(32), @Ver), 3) = '50' THEN '2008 R2' ELSE '2008' END
			ELSE CONVERT(VARCHAR(8),b.Year) END +' ' + @Edition
	FROM	[Configuration].[SQLServerMajorBuild] b 
	WHERE	PARSENAME(CONVERT(VARCHAR(32), @Ver), 4) = CONVERT(NCHAR(4),b.Major)
    RETURN @ResultString;
END;

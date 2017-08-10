
CREATE FUNCTION [Utility].[ufn_GetSQLServerServicePack] (@Version [nvarchar](max),
@ProductLevel  [nvarchar](max),
@ProductVersion [nvarchar](max))
RETURNS VARCHAR(1000)
AS
BEGIN
	--Declare Variables
    DECLARE @Ver NVARCHAR(128),@ResultString  VARCHAR(1000);
	SELECT  @Ver = ISNULL(@ProductVersion,Utility.ufn_Util_clr_RegexReplace(@Version,'([\W\w]*)\- ([\d]+\.[\d]+\.[\d]+\.[\d]+)[\W\w]*','$2',0))
	
	IF @ProductLevel = 'SP1' SET @ResultString = 'Service Pack 1'
	ELSE IF @ProductLevel = 'SP2' SET @ResultString = 'Service Pack 2'
	ELSE IF @ProductLevel = 'SP3' SET @ResultString = 'Service Pack 3'
	ELSE IF @ProductLevel = 'SP4' SET @ResultString = 'Service Pack 4'
	ELSE IF @ProductLevel = 'SP5' SET @ResultString = 'Service Pack 5'
	ELSE IF @ProductLevel = 'SP6' SET @ResultString = 'Service Pack 6'
	ELSE IF @ProductLevel = 'SP7' SET @ResultString = 'Service Pack 7'
	ELSE IF @ProductLevel = 'SP8' SET @ResultString = 'Service Pack 8'
	ELSE IF @ProductLevel = 'SP9' SET @ResultString = 'Service Pack 9'
	SELECT TOP 1 @ResultString = 'Microsoft SQL Server ' + 
			CASE WHEN b.Major = 10 THEN CASE WHEN PARSENAME(CONVERT(VARCHAR(32), @Ver), 3) = '50' THEN '2008 R2' ELSE '2008' END
			ELSE CONVERT(VARCHAR(8),b.Year) END + ' ' + @ResultString
	FROM	[Configuration].[SQLServerMajorBuild] b 
	WHERE	PARSENAME(CONVERT(VARCHAR(32), @Ver), 4) = CONVERT(NCHAR(4),b.Major)
    RETURN @ResultString;
END;

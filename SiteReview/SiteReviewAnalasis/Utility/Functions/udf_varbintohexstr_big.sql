/******************************************************************

Author
======
Florian Reischl

Summary
=======
Function to create a hex string of a specified varbinary value.

Parameters
==========

 @pbinin
 The varbinary to be converted to a hex string.

Remarks
=======
This function is a wrapper for the SQL Server 2005 system function
master.sys.fn_varbintohexsubstring which is restricted to 3998 bytes

History
=======
V01.00.00 (2009-01-15)
 * Initial Release
V01.00.01 (2009-04-01)
* Fixed bug reported by Robert
V01.00.02 (2014-11-30)
* Fixed bug reported by Sharon Rimer @len = DATALENGTH(@pbinin) -> @len = DATALENGTH(@pbinin) + 1;
******************************************************************/
CREATE FUNCTION Utility.[udf_varbintohexstr_big] ( @pbinin VARBINARY(MAX) )
RETURNS VARCHAR(MAX)
AS
BEGIN
    DECLARE @str VARCHAR(MAX)
    DECLARE @len INT
    DECLARE @pos INT

    SET @str = '0x';
    SET @len = DATALENGTH(@pbinin) + 1;
    SET @pos = 1;

    IF ( @pbinin IS NULL )
        RETURN NULL;

    IF ( @len = 0 )
        RETURN '0x0';

    WHILE ( @pos < @len )
    BEGIN
        DECLARE @offset INT;
        DECLARE @sub VARCHAR(2048);

		-- Thanks to Robert for bug reporting!
        SET @offset = @len - @pos
        IF @offset > 1024
            SET @offset = 1024;

        SELECT  @sub = master.sys.fn_varbintohexsubstring(0, @pbinin,@pos, @offset);
        SET @str = @str + @sub;
        SET @pos = @pos + @offset;
    END

    RETURN @str;

END
-- =============================================
-- Author:		Sharon
-- Create date: 21/10/2014
-- Update date: 29/10/2014 Set output parameter
--				02/11/2014 Sharon Partition AND P.index_id IN (0,1)
--				03/11/2014 Sharon Update
--				13/11/2014 Sharon @ColumnFillter @IgnoreColumnFillter
--				20/11/2014 Sharon Insert @ColumnFillter @IgnoreColumnFillter
--				01/12/2014 Sharon Path not Exists
--				29/12/2014 Sharon IF @Path IS NOT NULL AND @IsDebug = 0
--				02/07/2015 Sharon IF EXISTS
--				20/08/2015 Niro @Filename added condition if table is datadic_filed
--				14/10/2015 Sharon Fix @Filename with replace illigle chars
--				22/11/2015 Niro Changing the file name format
-- Description:	Create Script .sql file in path for insert\update\dalete
-- =============================================
CREATE PROCEDURE Utility.[usp_CreateScriptFile]
(
	@table_name SYSNAME,
	@IsTruncate BIT = 1,
	@IsDebug BIT = 0,
	@Path VARCHAR(600),
	@Fillter VARCHAR(MAX),
	@Output NVARCHAR(MAX) OUTPUT,
	@Action int = 1, -- 1. Insert, 2. Update 3.All
	@IsSafeInsert BIT = 0,
	@ColumnFillter VARCHAR(MAX),
	@IgnoreColumnFillter VARCHAR(MAX),
	@Advanced BIT = 0
)
AS
BEGIN	
	SET NOCOUNT ON;
	-- Declaration
	DECLARE @object_id INT;
	DECLARE @schema_id INT;
	DECLARE @isIdentity BIT = 0;
	DECLARE @cmd NVARCHAR(MAX) = N'';
	DECLARE @rc INT = 0;
	DECLARE @Error NVARCHAR(2048) = N'';
	DECLARE @column_names BIT,
			@handle_big_binary BIT;
	DECLARE @ColumnFillterTable TABLE (ColumnName sysname);
	DECLARE @IgnoreColumnFillterTable TABLE (ColumnName sysname);

	IF @IgnoreColumnFillter IS NOT NULL
	INSERT @IgnoreColumnFillterTable
	SELECT	* 
	FROM	Utility.ufn_Util_clr_SplitStr( @IgnoreColumnFillter,',')

	IF @ColumnFillter IS NOT NULL
	INSERT @ColumnFillterTable
	SELECT	* 
	FROM	Utility.ufn_Util_clr_SplitStr(@ColumnFillter,',')

	-- Configuration
	SET @column_names = 1;
	
	IF @Action IN (2,3) AND @IsTruncate = 1
	BEGIN 
		SET @Error = 'Can''t use update with TRUNCATE! Choose other action or change @IsTruncate to 0.';
		RAISERROR (@Error,16,1);
		RETURN -1;
	END
	IF @Path IS NOT NULL AND @IsDebug = 0
	BEGIN
		DECLARE @file_results TABLE
			(
			  file_exists INT ,
			  file_is_a_directory INT ,
			  parent_directory_exists INT
			)
 
		INSERT  INTO @file_results
				( file_exists ,
				  file_is_a_directory ,
				  parent_directory_exists
				)
				EXEC master.dbo.xp_fileexist @Path
     
		IF EXISTS(SELECT TOP 1 1 FROM @file_results WHERE file_is_a_directory = 0)
		BEGIN 
			SET @Error = 'Path "%s" is not exists on this server';
			RAISERROR (@Error,16,1,@Path);
			RETURN -1;
		END
	END
	-- Declaration
	DECLARE @select VARCHAR(MAX)
	DECLARE @update VARCHAR(MAX)
	DECLARE @PKfilter VARCHAR(MAX)
	DECLARE @insert VARCHAR(MAX)
	DECLARE @crlf CHAR(2)
	DECLARE @sql VARCHAR(MAX)
	DECLARE @sqlPK VARCHAR(MAX)
	DECLARE @first BIT
	

	SET @crlf = CHAR(13) + CHAR(10)
	--Column for cursor
	DECLARE @column_name SYSNAME
	DECLARE @data_type SYSNAME
	DECLARE @data_length INT
	DECLARE @is_nullable BIT
	DECLARE @pos INT
	SET @pos = 1
	--Info about the table
	SELECT  @object_id = t.object_id ,
			@schema_id = t.schema_id ,
			@isIdentity = ISNULL(id.[is_identity],0),
			@handle_big_binary = ISNULL(Bin.IsBinary,0),
			@rc = RC.[RowCount]
	FROM    sys.tables t
			OUTER APPLY (SELECT * FROM (SELECT	TOP 1 c.is_identity
						FROM	sys.columns C
						WHERE	C.system_type_id != 189 -- 'TimeStamp'
								AND t.object_id = C.object_id
						ORDER BY c.is_identity desc) AS [is_identity])id
			OUTER APPLY (SELECT TOP 1 1 IsBinary 
						FROM	SYS.COLUMNS C 
						WHERE	t.object_id = C.object_id 
								AND C.user_type_id IN (165,173)--Var/Binary
						)Bin
			CROSS APPLY (SELECT top 1 p.rows AS [RowCount]
						FROM	sys.partitions p
						WHERE	p.object_id = t.object_id
								AND P.index_id IN (0,1)-- Heap/Clusterd
						Order By p.rows desc)RC
	WHERE   t.object_id = OBJECT_ID(@table_name)
	IF @@ROWCOUNT = 0 
	BEGIN 
		SET @Error = @table_name + ' Does not exist!';
		RAISERROR (@Error,16,1);
		RETURN -1;
	END

	IF @rc > 0
	BEGIN
		
-------------------------------------------------------- PK Collector ----------------------------------------------------------
		IF (@Action = 1 /*Insert*/ AND @IsSafeInsert = 1) OR @Action IN (2,3)
		BEGIN
			DECLARE @PKcolumns TABLE
			(
			  column_name SYSNAME ,
			  ordinal_position INT ,
			  data_type SYSNAME ,
			  data_length INT ,
			  is_nullable BIT
			);

			-- Get all PK column information
			INSERT  INTO @PKcolumns
			SELECT  C.column_name ,
					C.ordinal_position ,
					C.data_type ,
					C.character_maximum_length ,
					CASE WHEN C.is_nullable = 'YES' THEN 1 ELSE 0 END
			FROM    INFORMATION_SCHEMA.COLUMNS c
					OUTER APPLY (SELECT TOP 1 1 IsComputed FROM sys.columns CC WHERE CC.object_id = OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME) AND C.column_name = CC.name AND	is_computed = 1 )OA
					OUTER APPLY (SELECT TOP 1 1 IsTimeStump FROM sys.columns CC WHERE CC.object_id = OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME) AND C.column_name = CC.name AND CC.system_type_id = 189 )OAtimeStump
					CROSS APPLY (SELECT TOP 1 1 IsPK FROM sys.indexes i INNER JOIN SYS.index_columns IC ON iC.object_id = i.object_id INNER JOIN SYS.columns CC ON CC.column_id = IC.column_id AND CC.object_id = iC.object_id WHERE CC.object_id = OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME) AND C.column_name = CC.name AND I.is_primary_key = 1 AND I.index_id = IC.index_id)OAPK
			WHERE   C.TABLE_SCHEMA = SCHEMA_NAME(@schema_id)
					AND C.TABLE_NAME = OBJECT_NAME(@object_id)
					AND OA.IsComputed IS NULL
					AND OAtimeStump.IsTimeStump IS NULL;
			
						---------------------------------------------------------------------------------------
			-- Get information for the current column of PK
			DECLARE PKCU  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			SELECT  column_name ,
					data_type ,
					data_length ,
					is_nullable ,
					ordinal_position
			FROM    @PKcolumns
			ORDER BY   ordinal_position

			OPEN PKCU
			-- Get information for the current column
			FETCH NEXT FROM PKCU INTO @column_name,@data_type,@data_length,@is_nullable,@pos

			WHILE @@FETCH_STATUS = 0
			BEGIN

				-- Create column select information to script the name of the source/destination column if configured
				IF ( @PKfilter IS NULL )
					SET @PKfilter = ''' WHERE ' + QUOTENAME(@column_name) + ' = '' + '
				ELSE
					SET @PKfilter += @crlf + ' ''' + QUOTENAME(@column_name) + ' = '' + '

				SET @sqlPK = ' '
				-- Handle NULL values
				IF @is_nullable = 1 SET @sqlPK += 'CASE WHEN ' + QUOTENAME(@column_name) + ' IS NULL THEN ''NULL'' ELSE '

				-- Handle the different data types
				IF ( @data_type IN ( 'bigint', 'bit', 'decimal', 'float', 'int','money', 'numeric', 'real', 'smallint','smallmoney', 'tinyint', 'geography') )
					SET @sqlPK +=  'CONVERT(VARCHAR(max), ' + QUOTENAME(@column_name) + ')'
				ELSE
					IF ( @data_type IN ( 'char', 'nchar', 'nvarchar', 'varchar' ) )
						SET @sqlPK += '''N'''''' + REPLACE(' + QUOTENAME(@column_name) + ', '''''''', '''''''''''') + '''''''''
					ELSE
						IF ( @data_type = 'date' )
							SET @sqlPK += '''''''''+ CONVERT(VARCHAR(8),' + QUOTENAME(@column_name) + ',112) + ''''''''' --112 = yyyymmdd
						ELSE IF ( @data_type = 'datetime' )
							SET @sqlPK += '''''''''+ CONVERT(VARCHAR(23),' + QUOTENAME(@column_name) + ',121) + ''''''''' -- yyyy-mm-dd hh:mi:ss.mmm(24h)
						ELSE IF ( @data_type = 'geography' )
							SET @sqlPK +=  '''CONVERT(GEOGRAPHY, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(5), ' + QUOTENAME(@column_name) + ')) + '')'''
						ELSE IF ( @data_type = 'time' )
							SET @sqlPK += '''''''''+ CONVERT(VARCHAR(12),' + QUOTENAME(@column_name) + ',114) + ''''''''' -- hh:mi:ss:mmm(24h)
						ELSE IF ( @data_type = 'datetime2' )
							SET @sqlPK += '''CONVERT(DATETIME2, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(8), ' + QUOTENAME(@column_name) + ')) + '')'''
						ELSE IF ( @data_type = 'smalldatetime' )
							SET @sqlPK += '''CONVERT(SMALLDATETIME, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(4), ' + QUOTENAME(@column_name) + ')) + '')'''
						ELSE IF ( @data_type = 'text' )
							SET @sqlPK += ''''''''' + REPLACE(CONVERT(VARCHAR(MAX), ' + QUOTENAME(@column_name) + '), '''''''', '''''''''''') + '''''''''
						ELSE IF ( @data_type IN ( 'ntext','xml' ) )
							SET @sqlPK += ''''''''' + REPLACE(CONVERT(NVARCHAR(MAX), ' + QUOTENAME(@column_name) + '), '''''''', '''''''''''') + '''''''''
						ELSE IF ( @data_type IN ('binary', 'varbinary' ) )-- Use udf_varbintohexstr_big if available to avoid cutted binary data
							IF ( @handle_big_binary = 1 )SET @sqlPK += ' master.dbo.udf_varbintohexstr_big ('+ QUOTENAME(@column_name)+ ')'
							ELSE SET @sqlPK += ' master.sys.fn_varbintohexstr ('+ QUOTENAME(@column_name)+ ')'
						ELSE IF ( @data_type = 'timestamp' )
							SET @sqlPK += '''CONVERT(TIMESTAMP, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(8), '+ QUOTENAME(@column_name)+ ')) + '')'''
						ELSE IF ( @data_type = 'uniqueidentifier' )  
							SET @sqlPK += '''CONVERT(UNIQUEIDENTIFIER, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(16), '+ QUOTENAME(@column_name)+ ')) + '')'''
						ELSE IF ( @data_type = 'image' )-- Use udf_varbintohexstr_big if available to avoid cutted binary data
							IF ( @handle_big_binary = 1 )
							SET @sqlPK += ' [Utility].[udf_varbintohexstr_big] (CONVERT(VARBINARY(MAX), '+ QUOTENAME(@column_name)+ '))'
							ELSE SET @sqlPK += ' master.sys.fn_varbintohexstr (CONVERT(VARBINARY(MAX), '+ QUOTENAME(@column_name)+ '))'
						ELSE
						BEGIN
							PRINT 'ERROR: Not supported data type: ' + @data_type
							--RETURN -1;
						END
				IF @is_nullable = 1
				SET @sqlPK +=  ' END'

				-- Script line end for finish or next column
				IF EXISTS ( SELECT TOP 1 1 FROM @PKcolumns WHERE ordinal_position > @pos )
					SET @sqlPK +=  ' + '', '' +'

				-- Remember the data script
				SET @PKfilter +=  @sqlPK

	
				FETCH NEXT FROM PKCU INTO @column_name,@data_type,@data_length,@is_nullable,@pos

			END

			CLOSE PKCU
			DEALLOCATE PKCU

		END

---------------------------------------------------------- Insert --------------------------------------------------------------
		IF @Action IN (1,3) -- Insert
		BEGIN
			DECLARE @columns TABLE
			(
			  column_name SYSNAME ,
			  ordinal_position INT ,
			  data_type SYSNAME ,
			  data_length INT ,
			  is_nullable BIT
			)

			-- Get all column information
			INSERT  INTO @columns
			SELECT  C.column_name ,
					C.ordinal_position ,
					C.data_type ,
					C.character_maximum_length ,
					CASE WHEN C.is_nullable = 'YES' THEN 1 ELSE 0 END
			FROM    INFORMATION_SCHEMA.COLUMNS c
					OUTER APPLY (SELECT TOP 1 1 IsComputed FROM sys.columns CC WHERE CC.object_id = OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME) AND C.column_name = CC.name AND	is_computed = 1 )OA
					OUTER APPLY (SELECT TOP 1 1 IsTimeStump FROM sys.columns CC WHERE CC.object_id = OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME) AND C.column_name = CC.name AND CC.system_type_id = 189 )OAtimeStump
			WHERE   C.TABLE_SCHEMA = SCHEMA_NAME(@schema_id)
					AND C.TABLE_NAME = OBJECT_NAME(@object_id)
					AND OA.IsComputed IS NULL
					AND OAtimeStump.IsTimeStump IS NULL
					AND C.column_name NOT IN (SELECT ColumnName FROM @IgnoreColumnFillterTable)
					AND (C.column_name IN (SELECT ColumnName FROM @ColumnFillterTable) OR @ColumnFillter IS NULL);

			DECLARE CU  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			SELECT  column_name ,
					data_type ,
					data_length ,
					is_nullable ,
					ordinal_position
			FROM    @columns
			ORDER BY   ordinal_position

			OPEN CU
			-- Get information for the current column
			FETCH NEXT FROM CU INTO @column_name,@data_type,@data_length,@is_nullable,@pos

			WHILE @@FETCH_STATUS = 0
			BEGIN

				-- Create column select information to script the name of the source/destination column if configured
				IF ( @select IS NULL )
					SET @select = ' ''' + QUOTENAME(@column_name)
				ELSE
					SET @select = @select + ','' + ' + @crlf + ' ''' + QUOTENAME(@column_name)
				SET @sql = ' '
				-- Handle NULL values
				IF @is_nullable = 1 SET @sql += 'CASE WHEN ' + QUOTENAME(@column_name) + ' IS NULL THEN ''NULL'' ELSE '

				-- Handle the different data types
				IF ( @data_type IN ( 'bigint', 'bit', 'decimal', 'float', 'int','money', 'numeric', 'real', 'smallint','smallmoney', 'tinyint', 'geography') )
					SET @sql +=  'CONVERT(VARCHAR(max), ' + QUOTENAME(@column_name) + ')'
				ELSE
					IF ( @data_type IN ( 'char', 'nchar', 'nvarchar', 'varchar' ) )
						SET @sql += '''N'''''' + REPLACE(' + QUOTENAME(@column_name) + ', '''''''', '''''''''''') + '''''''''
					ELSE
						IF ( @data_type = 'date' )
							SET @sql += '''''''''+ CONVERT(VARCHAR(8),' + QUOTENAME(@column_name) + ',112) + ''''''''' --112 = yyyymmdd
						ELSE IF ( @data_type = 'datetime' )
							SET @sql += '''''''''+ CONVERT(VARCHAR(23),' + QUOTENAME(@column_name) + ',121) + ''''''''' -- yyyy-mm-dd hh:mi:ss.mmm(24h)
						ELSE IF ( @data_type = 'geography' )
							SET @sql +=  '''CONVERT(GEOGRAPHY, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(5), ' + QUOTENAME(@column_name) + ')) + '')'''
						ELSE IF ( @data_type = 'time' )
							SET @sql += '''''''''+ CONVERT(VARCHAR(12),' + QUOTENAME(@column_name) + ',114) + ''''''''' -- hh:mi:ss:mmm(24h)
						ELSE IF ( @data_type = 'datetime2' )
							SET @sql += '''CONVERT(DATETIME2, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(8), ' + QUOTENAME(@column_name) + ')) + '')'''
						ELSE IF ( @data_type = 'smalldatetime' )
							SET @sql += '''CONVERT(SMALLDATETIME, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(4), ' + QUOTENAME(@column_name) + ')) + '')'''
						ELSE IF ( @data_type = 'text' )
							SET @sql += ''''''''' + REPLACE(CONVERT(VARCHAR(MAX), ' + QUOTENAME(@column_name) + '), '''''''', '''''''''''') + '''''''''
						ELSE IF ( @data_type IN ( 'ntext','xml' ) )
							SET @sql += ''''''''' + REPLACE(CONVERT(NVARCHAR(MAX), ' + QUOTENAME(@column_name) + '), '''''''', '''''''''''') + '''''''''
						ELSE IF ( @data_type IN ('binary', 'varbinary' ) )-- Use udf_varbintohexstr_big if available to avoid cutted binary data
							IF ( @handle_big_binary = 1 )SET @sql += ' [Utility].[udf_varbintohexstr_big] ('+ QUOTENAME(@column_name)+ ')'
							ELSE SET @sql += ' master.sys.fn_varbintohexstr ('+ QUOTENAME(@column_name)+ ')'
						ELSE IF ( @data_type = 'timestamp' )
							SET @sql += '''CONVERT(TIMESTAMP, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(8), '+ QUOTENAME(@column_name)+ ')) + '')'''
						ELSE IF ( @data_type = 'uniqueidentifier' )  
							SET @sql += '''CONVERT(UNIQUEIDENTIFIER, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(16), '+ QUOTENAME(@column_name)+ ')) + '')'''
						ELSE IF ( @data_type = 'image' )-- Use udf_varbintohexstr_big if available to avoid cutted binary data
							IF ( @handle_big_binary = 1 )
							SET @sql += ' [Utility].[udf_varbintohexstr_big] (CONVERT(VARBINARY(MAX), '+ QUOTENAME(@column_name)+ '))'
							ELSE SET @sql += ' master.sys.fn_varbintohexstr (CONVERT(VARBINARY(MAX), '+ QUOTENAME(@column_name)+ '))'
						ELSE
						BEGIN
							PRINT 'ERROR: Not supported data type: ' + @data_type
							RETURN -1;
						END
				IF @is_nullable = 1
				SET @sql +=  ' END'

				-- Script line end for finish or next column
				IF EXISTS ( SELECT TOP 1 1 FROM @columns WHERE ordinal_position > @pos )
					SET @sql +=  ' + '', '' +'
				ELSE
					SET @sql +=  ' + '

				-- Remember the data script
				IF ( @insert IS NULL )
					SET @insert = @sql
				ELSE
					SET @insert = @insert + @crlf + @sql
	
				FETCH NEXT FROM CU INTO @column_name,@data_type,@data_length,@is_nullable,@pos

			END

			CLOSE CU
			DEALLOCATE CU
		END 
---------------------------------------------------------- Update --------------------------------------------------------------
		IF @Action IN (2,3) -- Update 
		BEGIN
			DECLARE @UpdateColumns TABLE
			(
			  column_name SYSNAME ,
			  ordinal_position INT ,
			  data_type SYSNAME ,
			  data_length INT ,
			  is_nullable BIT
			);
			
			-- Get all Update column information
			INSERT  INTO @UpdateColumns
			SELECT  C.column_name ,
					C.ordinal_position ,
					C.data_type ,
					C.character_maximum_length ,
					CASE WHEN C.is_nullable = 'YES' THEN 1 ELSE 0 END
			FROM    INFORMATION_SCHEMA.COLUMNS c
					OUTER APPLY (SELECT TOP 1 1 IsComputed FROM sys.columns CC WHERE CC.object_id = OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME) AND C.column_name = CC.name AND	is_computed = 1 )OA
					OUTER APPLY (SELECT TOP 1 1 IsTimeStump FROM sys.columns CC WHERE CC.object_id = OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME) AND C.column_name = CC.name AND CC.system_type_id = 189 )OAtimeStump
					OUTER APPLY (SELECT TOP 1 1 IsPK FROM sys.indexes i INNER JOIN SYS.index_columns IC ON iC.object_id = i.object_id INNER JOIN SYS.columns CC ON CC.column_id = IC.column_id AND CC.object_id = iC.object_id WHERE CC.object_id = OBJECT_ID(TABLE_SCHEMA + '.' + TABLE_NAME) AND C.column_name = CC.name AND I.is_primary_key = 1 AND I.index_id = IC.index_id)OAPK
			WHERE   C.TABLE_SCHEMA = SCHEMA_NAME(@schema_id)
					AND C.TABLE_NAME = OBJECT_NAME(@object_id)
					AND OA.IsComputed IS NULL
					AND OAtimeStump.IsTimeStump IS NULL
					AND OAPK.IsPK IS NULL
					AND C.column_name NOT IN (SELECT ColumnName FROM @IgnoreColumnFillterTable)
					AND (C.column_name IN (SELECT ColumnName FROM @ColumnFillterTable) OR @ColumnFillter IS NULL);



			DECLARE UPCU  CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			SELECT  column_name ,
					data_type ,
					data_length ,
					is_nullable ,
					ordinal_position
			FROM    @UpdateColumns
			ORDER BY   ordinal_position

			OPEN UPCU
			-- Get information for the current column
			FETCH NEXT FROM UPCU INTO @column_name,@data_type,@data_length,@is_nullable,@pos

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Create column select information to script the name of the source/destination column if configured
				IF ( @update IS NULL )
					SET @update = ' ' + QUOTENAME(@column_name) + ' = '' + '
				ELSE
					SET @update += @crlf + ' ''' + QUOTENAME(@column_name) + ' = '' + '
				SET @sql = ' '
				-- Handle NULL values
				IF @is_nullable = 1 SET @sql += 'CASE WHEN ' + QUOTENAME(@column_name) + ' IS NULL THEN ''NULL'' ELSE '

				-- Handle the different data types
				IF ( @data_type IN ( 'bigint', 'bit', 'decimal', 'float', 'int','money', 'numeric', 'real', 'smallint','smallmoney', 'tinyint', 'geography') )
					SET @sql +=  'CONVERT(VARCHAR(max), ' + QUOTENAME(@column_name) + ')'
				ELSE
					IF ( @data_type IN ( 'char', 'nchar', 'nvarchar', 'varchar' ) )
						SET @sql += '''N'''''' + REPLACE(' + QUOTENAME(@column_name) + ', '''''''', '''''''''''') + '''''''''
					ELSE
						IF ( @data_type = 'date' )
							SET @sql += '''''''''+ CONVERT(VARCHAR(8),' + QUOTENAME(@column_name) + ',112) + ''''''''' --112 = yyyymmdd
						ELSE IF ( @data_type = 'datetime' )
							SET @sql += '''''''''+ CONVERT(VARCHAR(23),' + QUOTENAME(@column_name) + ',121) + ''''''''' -- yyyy-mm-dd hh:mi:ss.mmm(24h)
						ELSE IF ( @data_type = 'geography' )
							SET @sql +=  '''CONVERT(GEOGRAPHY, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(5), ' + QUOTENAME(@column_name) + ')) + '')'''
						ELSE IF ( @data_type = 'time' )
							SET @sql += '''''''''+ CONVERT(VARCHAR(12),' + QUOTENAME(@column_name) + ',114) + ''''''''' -- hh:mi:ss:mmm(24h)
						ELSE IF ( @data_type = 'datetime2' )
							SET @sql += '''CONVERT(DATETIME2, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(8), ' + QUOTENAME(@column_name) + ')) + '')'''
						ELSE IF ( @data_type = 'smalldatetime' )
							SET @sql += '''CONVERT(SMALLDATETIME, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(4), ' + QUOTENAME(@column_name) + ')) + '')'''
						ELSE IF ( @data_type = 'text' )
							SET @sql += ''''''''' + REPLACE(CONVERT(VARCHAR(MAX), ' + QUOTENAME(@column_name) + '), '''''''', '''''''''''') + '''''''''
						ELSE IF ( @data_type IN ( 'ntext','xml' ) )
							SET @sql += ''''''''' + REPLACE(CONVERT(NVARCHAR(MAX), ' + QUOTENAME(@column_name) + '), '''''''', '''''''''''') + '''''''''
						ELSE IF ( @data_type IN ('binary', 'varbinary' ) )-- Use udf_varbintohexstr_big if available to avoid cutted binary data
							IF ( @handle_big_binary = 1 )SET @sql += ' [Utility].[udf_varbintohexstr_big] ('+ QUOTENAME(@column_name)+ ')'
							ELSE SET @sql += ' master.sys.fn_varbintohexstr ('+ QUOTENAME(@column_name)+ ')'
						ELSE IF ( @data_type = 'timestamp' )
							SET @sql += '''CONVERT(TIMESTAMP, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(8), '+ QUOTENAME(@column_name)+ ')) + '')'''
						ELSE IF ( @data_type = 'uniqueidentifier' )  
							SET @sql += '''CONVERT(UNIQUEIDENTIFIER, '' + master.sys.fn_varbintohexstr (CONVERT(BINARY(16), '+ QUOTENAME(@column_name)+ ')) + '')'''
						ELSE IF ( @data_type = 'image' )-- Use udf_varbintohexstr_big if available to avoid cutted binary data
							IF ( @handle_big_binary = 1 )
							SET @sql += ' [Utility].[udf_varbintohexstr_big] (CONVERT(VARBINARY(MAX), '+ QUOTENAME(@column_name)+ '))'
							ELSE SET @sql += ' master.sys.fn_varbintohexstr (CONVERT(VARBINARY(MAX), '+ QUOTENAME(@column_name)+ '))'
						ELSE
						BEGIN
							PRINT 'ERROR: Not supported data type: ' + @data_type
							--RETURN -1;
						END
				IF @is_nullable = 1
				SET @sql +=  ' END'

				-- Script line end for finish or next column
				IF EXISTS ( SELECT TOP 1 1 FROM @UpdateColumns WHERE ordinal_position > @pos )
					SET @sql +=  ' + '', '' +'
				ELSE
					SET @sql +=  ' + '

				-- Remember the data script
				SET @update +=  @sql

	
				FETCH NEXT FROM UPCU INTO @column_name,@data_type,@data_length,@is_nullable,@pos

			END

			CLOSE UPCU
			DEALLOCATE UPCU


			SET @update += @PKfilter


		END
---------------------------------------------
		-- Close the column names select
		SET @select = @select + ''' +'

		-- Print the INSERT INTO part
		SELECT	@cmd += t.Script 
		FROM	(SELECT 'SELECT ''SET NOCOUNT ON;
''  AS Script ' Script, 1 AS [Order]
-- @update
				UNION ALL SELECT '
UNION ALL
SELECT ''
UPDATE ' + @table_name + ' SET ' + @update + ' FROM ' + @table_name + ' ' , 2 AS [Order] WHERE @Action IN (2,3) AND @update IS NOT NULL
				--@Fillter
				UNION ALL SELECT ' WHERE ' + @Fillter , 3 AS [Order]WHERE @Action IN (2,3) AND @Fillter IS NOT NULL
				-- @IsTruncate
				UNION ALL SELECT 'UNION ALL SELECT ''TRUNCATE TABLE ' + @table_name + ';
''  AS Script ' , 4 AS [Order]WHERE @IsTruncate = 1
				-- @isIdentity
				UNION ALL SELECT 'UNION ALL SELECT ''
SET IDENTITY_INSERT ' + @table_name + ' ON
'' AS Script ' , 5 AS [Order]WHERE @Action IN (1,3) AND @isIdentity = 1
				-- Insert + @IsSafeInsert
				UNION ALL SELECT  'UNION ALL SELECT ''
' + CASE WHEN @IsSafeInsert = 1 THEN 'IF NOT EXISTS(SELECT TOP 1 1 FROM ' + @table_name + REPLACE(@PKfilter,''' WHERE',' WHERE') + ' + '')' ELSE '' END + '
INSERT INTO ' + @table_name + ''' + ' + 
					CASE WHEN @column_names = 1 THEN ' ''('' + ' + @select + ' '')'' + ' ELSE '' END + 
					' ''VALUES ('' +' + @insert + ' '')''' + ' FROM ' + @table_name + CASE WHEN @Fillter IS NOT NULL THEN ' WHERE ' + @Fillter ELSE '' END +  ' '   
						, 6 AS [Order]	WHERE @Action IN (1,3)
				-- @isIdentity
				UNION ALL SELECT '
UNION ALL
SELECT ''
SET IDENTITY_INSERT ' + @table_name + ' OFF''' , 7 AS [Order]WHERE @Action IN (1,3) AND @isIdentity = 1
				
				)t
		ORDER BY [Order] ASC;
---------------------------------------------
		IF @IsDebug = 1
		EXEC [Customs_DBA].[Script].[usp_PrintNvarcharMax] @cmd

		SET @cmd = 'IF EXISTS(SELECT TOP 1 1 FROM ' + @table_name + CASE WHEN @Fillter IS NOT NULL THEN ' WHERE ' + @Fillter ELSE '' END + ') 
BEGIN
	SET @output = N'''';
	SELECT @output+= Script FROM ( ' + @cmd + ' )T;
END
ELSE
BEGIN
	SET @output = N''/* No Diffarance has been detected*/''
END'
		
		EXEC sp_executesql @cmd , N'@output NVARCHAR(MAX) OUT',@output = @output OUT
		IF @output = '/*Table ' + @table_name + ' has no rows*/'
		BEGIN
			set @cmd = '';
		END
	END	
	ELSE -- Thera are no rows on the table
	BEGIN
		SET @output = '/* No Diffarance has been detected*/';
		set @cmd = '';
	END 

	IF @IsDebug = 1
	BEGIN
		IF @Advanced = 1
		BEGIN
			SET @cmd = REPLACE(REPLACE(@cmd,'SET @output = N'''';',''),'SELECT @output+= Script','SELECT Script');
			PRINT @cmd;
			PRINT '***************************************************'
		END
	END
	ELSE
	BEGIN
		IF @Path IS NOT NULL
		BEGIN
		
			DECLARE @Filename VARCHAR(125)=@table_name+'_'+REPLACE(CONVERT(VARCHAR(8), GETDATE(), 112) + '_' + CONVERT(VARCHAR(8), GETDATE(), 114), ':', '_')+'.Sql'; 

			print @Filename
			BEGIN TRY
				IF  @output = '/* No Diffarance has been detected*/'
					RETURN 0;
				ELSE
               	BEGIN
					EXEC Customs_DBA.[Script].[usp_PrintNvarcharMax] @output;
               		--EXEC Customs_DBA.Script.usp_WriteStringToFile @output,@Path,@Filename;
					RETURN 1;
               	END
			END TRY
			BEGIN CATCH
				SELECT @Error = CONCAT('Customs_DBA.Script.usp_WriteStringToFile - ',ERROR_MESSAGE())

				RAISERROR(@Error,16,1);
				RETURN -1;
			END CATCH
		END
	END
	RETURN 1;
END
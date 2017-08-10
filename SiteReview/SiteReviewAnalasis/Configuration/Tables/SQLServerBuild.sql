CREATE TABLE [Configuration].[SQLServerBuild] (
    [Build]           NVARCHAR (128) NOT NULL,
    [FileVersion]     VARCHAR (128)  NULL,
    [Description]     NVARCHAR (MAX) NULL,
    [ReleaseDate]     VARCHAR (50)   NULL,
    [CommonVersion]   AS             (substring([Build],(1),charindex('.',[Build])+(1))),
    [Major]           AS             (case when parsename(CONVERT([varchar](32),[Build]),(4)) IS NULL then parsename(CONVERT([varchar](32),[Build]),(3)) else parsename(CONVERT([varchar](32),[Build]),(4)) end),
    [Minor]           AS             (case when parsename(CONVERT([varchar](32),[Build]),(4)) IS NULL then parsename(CONVERT([varchar](32),[Build]),(2)) else parsename(CONVERT([varchar](32),[Build]),(3)) end),
    [VersionBuild]    AS             (case when parsename(CONVERT([varchar](32),[Build]),(4)) IS NULL then parsename(CONVERT([varchar](32),[Build]),(1)) else parsename(CONVERT([varchar](32),[Build]),(2)) end),
    [Revision]        AS             (case when parsename(CONVERT([varchar](32),[Build]),(4)) IS NULL then NULL else parsename(CONVERT([varchar](32),[Build]),(1)) end),
    [FriendlyVersion] AS             (concat(case when parsename(CONVERT([varchar](32),[Build]),(4)) IS NULL then parsename(CONVERT([varchar](32),[Build]),(3)) else parsename(CONVERT([varchar](32),[Build]),(4)) end,'.',TRY_CAST(case when parsename(CONVERT([varchar](32),[Build]),(4)) IS NULL then parsename(CONVERT([varchar](32),[Build]),(2)) else parsename(CONVERT([varchar](32),[Build]),(3)) end AS [int]),'.',TRY_CAST(case when parsename(CONVERT([varchar](32),[Build]),(4)) IS NULL then parsename(CONVERT([varchar](32),[Build]),(1)) else parsename(CONVERT([varchar](32),[Build]),(2)) end AS [int]),'.',TRY_CAST(case when parsename(CONVERT([varchar](32),[Build]),(4)) IS NULL then '0' else parsename(CONVERT([varchar](32),[Build]),(1)) end AS [int]))),
    CONSTRAINT [PK_SQLServerBuild] PRIMARY KEY CLUSTERED ([Build] ASC) ON [Configuration]
) TEXTIMAGE_ON [Configuration];




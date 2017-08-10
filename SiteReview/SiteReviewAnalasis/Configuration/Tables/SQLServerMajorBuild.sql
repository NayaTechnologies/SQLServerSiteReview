CREATE TABLE [Configuration].[SQLServerMajorBuild] (
    [ID]        INT       IDENTITY (1, 1) NOT NULL,
    [Major]     INT       NOT NULL,
    [FullMajor] INT       NOT NULL,
    [Year]      INT       NOT NULL,
    [Name]      [sysname] NOT NULL,
    CONSTRAINT [PK_SQLServerMajorBuild] PRIMARY KEY CLUSTERED ([ID] ASC) ON [Configuration]
);




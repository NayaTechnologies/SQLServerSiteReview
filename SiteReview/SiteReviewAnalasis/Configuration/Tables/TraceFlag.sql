CREATE TABLE [Configuration].[TraceFlag] (
    [TraceFlag]          INT             NOT NULL,
    [Description]        NVARCHAR (MAX)  NULL,
    [FromProductVersion] NVARCHAR (128)  NULL,
    [ToProductVersion]   NVARCHAR (128)  NULL,
    [Link]               NVARCHAR (1000) NULL,
    CONSTRAINT [PK_TraceFlag] PRIMARY KEY CLUSTERED ([TraceFlag] ASC) ON [Configuration]
) TEXTIMAGE_ON [Configuration];




CREATE TABLE [Client].[DebugError] (
    [guid]     UNIQUEIDENTIFIER NOT NULL,
    [Subject]  [sysname]        NULL,
    [Error]    NVARCHAR (MAX)   NULL,
    [Duration] INT              NULL
) TEXTIMAGE_ON [Client];


GO
CREATE CLUSTERED INDEX [CIX_guid]
    ON [Client].[DebugError]([guid] ASC)
    ON [Client];


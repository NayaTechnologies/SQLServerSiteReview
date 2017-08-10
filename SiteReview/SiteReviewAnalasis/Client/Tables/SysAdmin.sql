CREATE TABLE [Client].[SysAdmin] (
    [guid]        UNIQUEIDENTIFIER NOT NULL,
    [name]        [sysname]        NOT NULL,
    [type]        [sysname]        NOT NULL,
    [ParentGroup] [sysname]        NULL
);


GO
CREATE CLUSTERED INDEX [CIX_guid]
    ON [Client].[SysAdmin]([guid] ASC)
    ON [Client];


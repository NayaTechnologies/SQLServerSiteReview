CREATE TABLE [Client].[HADRServices] (
    [Guid]        UNIQUEIDENTIFIER NOT NULL,
    [AlwaysOn]    BIT              CONSTRAINT [DF_HADRServices_AlwaysOn] DEFAULT ((0)) NOT NULL,
    [Replication] BIT              CONSTRAINT [DF_HADRServices_Replication] DEFAULT ((0)) NOT NULL,
    [LogShipping] BIT              CONSTRAINT [DF_HADRServices_LogShipping] DEFAULT ((0)) NOT NULL,
    [Mirror]      BIT              CONSTRAINT [DF_HADRServices_Mirror] DEFAULT ((0)) NOT NULL,
    [Cluster]     BIT              CONSTRAINT [DF_HADRServices_Cluster] DEFAULT ((0)) NOT NULL
) ON [Client];




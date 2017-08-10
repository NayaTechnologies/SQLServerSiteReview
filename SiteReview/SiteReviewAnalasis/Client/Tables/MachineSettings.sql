CREATE TABLE [Client].[MachineSettings] (
    [guid]                          UNIQUEIDENTIFIER NOT NULL,
    [ServerName]                    [sysname]        NOT NULL,
    [MachineName]                   NVARCHAR (MAX)   NULL,
    [Instance]                      NVARCHAR (MAX)   NULL,
    [ProcessorCount]                INT              NULL,
    [ProcessorName]                 NVARCHAR (MAX)   NULL,
    [PhysicalMemory]                NVARCHAR (MAX)   NULL,
    [SQLAccount]                    NVARCHAR (MAX)   NULL,
    [SQLAgentAccount]               NVARCHAR (MAX)   NULL,
    [AuthenticationnMode]           NVARCHAR (MAX)   NULL,
    [Version]                       NVARCHAR (MAX)   NULL,
    [Edition]                       NVARCHAR (MAX)   NULL,
    [Collation]                     NVARCHAR (MAX)   NULL,
    [ProductLevel]                  NVARCHAR (MAX)   NULL,
    [SystemModel]                   NVARCHAR (MAX)   NULL,
    [ServerStartTime]               NVARCHAR (255)   NULL,
    [ProductVersion]                NVARCHAR (128)   NULL,
    [InstantInitializationDisabled] BIT              NULL,
    [LockPagesInMemoryDisabled]     BIT              NULL,
    [MaxClockSpeed]                 INT              NULL,
    [CurrentClockSpeed]             INT              NULL,
    [LicenseType]                   AS               ([Utility].[ufn_GetSQLServerLicenseType]([Version])),
    [MajorVersion]                  AS               ([Utility].[ufn_GetSQLServerMajorVersion]([Version]))
) TEXTIMAGE_ON [Client];




GO
CREATE CLUSTERED INDEX [CIX_guid]
    ON [Client].[MachineSettings]([guid] ASC)
    ON [Client];


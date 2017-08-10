CREATE TABLE [Client].[CPUHistory] (
    [guid]          UNIQUEIDENTIFIER NOT NULL,
    [EventTimeFrom] DATETIME         NOT NULL,
    [EventTimeTo]   DATETIME         NOT NULL,
    [SQLCPU]        INT              NOT NULL,
    [IdleCPU]       INT              NOT NULL,
    [Others]        INT              NOT NULL
);


GO
CREATE CLUSTERED INDEX [CIX_guid]
    ON [Client].[CPUHistory]([guid] ASC)
    ON [Client];


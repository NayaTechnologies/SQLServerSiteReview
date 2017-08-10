CREATE TABLE [Client].[HeavyQueries] (
    [guid]                UNIQUEIDENTIFIER NOT NULL,
    [CheckType]           [sysname]        NOT NULL,
    [execution_count]     BIGINT           NOT NULL,
    [AvgScore]            INT              NULL,
    [last_execution_time] DATETIME         NULL,
    [AvgDuration]         INT              NULL,
    [query_text]          NVARCHAR (MAX)   NULL,
    [database_name]       [sysname]        NULL
) TEXTIMAGE_ON [Client];


GO
CREATE CLUSTERED INDEX [CIX_guid]
    ON [Client].[HeavyQueries]([guid] ASC)
    ON [Client];


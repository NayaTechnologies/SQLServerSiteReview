CREATE TABLE [Configuration].[SoftwareTraceFlage] (
    [ID]        INT            IDENTITY (1, 1) NOT NULL,
    [Software]  NVARCHAR (255) NOT NULL,
    [TraceFlag] INT            NOT NULL,
    CONSTRAINT [PK_SoftwareTraceFlage] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_SoftwareTraceFlage_Software] FOREIGN KEY ([Software]) REFERENCES [Configuration].[Software] ([Software]),
    CONSTRAINT [FK_SoftwareTraceFlage_TraceFlag] FOREIGN KEY ([TraceFlag]) REFERENCES [Configuration].[TraceFlag] ([TraceFlag])
);


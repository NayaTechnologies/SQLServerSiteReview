CREATE TABLE [Configuration].[SQLServerLicenseLimit] (
    [ID]                   INT       IDENTITY (1, 1) NOT NULL,
    [LicenseType]          [sysname] NOT NULL,
    [MaxMemoryUtilization] INT       NOT NULL,
    [MaxComputeCapacity]   INT       NOT NULL,
    [MaxDBSize]            INT       NOT NULL,
    CONSTRAINT [PK_SQLServerLicenseLimit] PRIMARY KEY CLUSTERED ([ID] ASC)
);


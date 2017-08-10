CREATE TABLE [Configuration].[SQLServerLicenseLimit_cl_SQLServerMajorBuild] (
    [ID]                      INT IDENTITY (1, 1) NOT NULL,
    [SQLServerLicenseLimitID] INT NOT NULL,
    [SQLServerMajorBuildID]   INT NOT NULL,
    CONSTRAINT [PK_SQLServerLicenseLimit_cl_SQLServerMajorBuild] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [FK_SQLServerLicenseLimit_cl_SQLServerMajorBuild_SQLServerLicenseLimit] FOREIGN KEY ([SQLServerLicenseLimitID]) REFERENCES [Configuration].[SQLServerLicenseLimit] ([ID]),
    CONSTRAINT [FK_SQLServerLicenseLimit_cl_SQLServerMajorBuild_SQLServerMajorBuild] FOREIGN KEY ([SQLServerMajorBuildID]) REFERENCES [Configuration].[SQLServerMajorBuild] ([ID])
);


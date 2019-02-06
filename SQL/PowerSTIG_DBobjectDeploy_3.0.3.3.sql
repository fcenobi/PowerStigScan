-- ===============================================================================================
-- ===============================================================================================
-- Purpose: Deployment script for PowerSTIG database objects
-- Revisions:
-- 09172018 - v3.0.0.0 - Kevin Barlett, Microsoft - Initial creation.
-- 10302018 - v3.0.0.1 - Kevin Barlett, Microsoft - Addition of GUID input in FindingImport table and insert proc.
-- 10312018 - v3.0.1.8 - Kevin Barlett, Microsoft 
--								- Added new compliance types, removed unused and renamed existing.
--								- Modified sproc_AddTargetComputer to accept new compliance types.
--								- Added error handling to sproc_CreateComplianceIteration
--								- Added error handling to sproc_CompleteComplianceIteration
--								- Added error handling to sproc_InsertComplianceCheckLog
--								- Added error handling to sproc_AddTargetComputer
--								- Fixed sproc_FindingImport extended property showing in compiled proc
--								- Commented out FindingSubPlatform table creation.  Now unused.
--								- Added FindingSeverity table drop/create.
--								- Created sproc_ProcessFindings to process raw data in FindingImport
--								- New table Scans
--								- FindingRepo table changes: Remove IterationID,FindingCategoryID,CollectTime.  Add ScanID
-- 11162018 - v3.0.2.4 - Kevin Barlett, Microsoft
--								- Significant code cleanup to remove unneeded V1 features
--								- New proc sproc_GetDependencies to retrieve object dependencies and relationships
--								- Made sproc_InsertScanLog input parameters less generic and make some semblance of sense
--01072019  - v3.0.2.6 - Kevin Barlett, Microsoft
-- 								- sproc_GetLastDataForCKL missing from deployment issue
--								- Bug fix in sproc_ProcessFindings
--01092019  - v3.0.2.7 - Kevin Barlett, Microsoft
-- 								- Fix for sproc_GetLastDataForCKL returning incorrect columns
--01232019  - v3.0.3.1 - Kevin Barlett, Microsoft
-- 								- Revised temp table handling in sproc_ProcessFindings
--                              - Fix in GetComplianceStateByServer to handle rule overlaps - Issue #15
--                              - Fix in sproc_AddTargetComputer where the message being logged to the ScanLog table was NULL.
--02042019  - v3.0.3.3 - Kevin Barlett, Microsoft
--								- Addition of GUID as parameter in GetComplianceStateByServer
--								- Modified GetLastDataForCKL to return the scan for each compliance type associated with a target.
-- ===============================================================================================
-- ===============================================================================================
/*
Detect SQLCMD mode and disable script execution if SQLCMD mode is not supported.
To re-enable the script after enabling SQLCMD mode, execute the following:
SET NOEXEC OFF;

  Copyright (C) 2018 Microsoft Corporation
  Disclaimer:
        This is SAMPLE code that is NOT production ready. It is the sole intention of this code to provide a proof of concept as a
        learning tool for Microsoft Customers. Microsoft does not provide warranty for or guarantee any portion of this code
        and is NOT responsible for any affects it may have on any system it is executed on or environment it resides within.
        Please use this code at your own discretion!
  Additional legalize:
        This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
    THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
    INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
    We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
    the object code form of the Sample Code, provided that You agree:
                  (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
         (ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
         (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys� fees,
               that arise or result from the use or distribution of the Sample Code.
*/
-- ===============================================================================================
--  Verify execution in SqlCmd mode
-- ===============================================================================================
:setvar __IsSqlCmdEnabled "True"
GO
IF N'$(__IsSqlCmdEnabled)' NOT LIKE N'True'
    BEGIN
        PRINT N'SQLCMD mode must be enabled to successfully execute this script.';
        SET NOEXEC ON;
    END
GO
--
SET NOEXEC OFF;
SET NOCOUNT ON;
-- ===============================================================================================
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
--  Set parameters - BEGIN SCRIPT EDIT
-- ===============================================================================================
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- ===============================================================================================
:setvar MAIL_PROFILE        "mailprofile"   -- SQL Server Database Mail profile for use with sending outbound mail
:setvar CMS_SERVER			"STIG2016"		-- SQL instance hosting scan data repository.                 
:setvar CMS_DATABASE		"PowerSTIG"     -- Database used for storing scan data.    
:setvar CKL_OUTPUT			"C:\Temp\PowerStig\CKL\"
:setvar CKL_ARCHIVE			"C:\Temp\PowerStig\CKL\Archive\"
:setvar CREATE_JOB			"Y"
-- ===============================================================================================
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- ===============================================================================================
-- END SCRIPT EDIT - DO NOT MODIFY BELOW THIS LINE!
-- ===============================================================================================
-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
-- ===============================================================================================
:setvar DEP_VER "3.0.3.3"
DECLARE @Timestamp DATETIME
SET @Timestamp = (GETDATE())
-- ===============================================================================================
PRINT '///////////////////////////////////////////////////////'
PRINT 'PowerSTIG database object deployment start - '+CONVERT(VARCHAR,@Timestamp, 21)
PRINT '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'
-- ===============================================================================================
USE [$(CMS_DATABASE)]
GO
-- ===============================================================================================
-- Create schema
-- ===============================================================================================
--
PRINT 'Begin create schema'
:setvar CREATE_SCHEMA "PowerSTIG"
--
PRINT '		Create schema: $(CREATE_SCHEMA)'
--
IF NOT EXISTS (SELECT name FROM sys.schemas WHERE name = 'PowerSTIG')
	EXEC('CREATE SCHEMA [PowerSTIG] AUTHORIZATION [dbo]');	
GO
PRINT 'End create schema'

-- ===============================================================================================
-- Create objects needed for deployment logging
-- ===============================================================================================
PRINT 'Begin create logging objects'
--
:setvar DROP_TABLE "ScanLog"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ScanLog') IS NOT NULL
	DROP TABLE PowerSTIG.ScanLog
GO
:setvar CREATE_TABLE "ScanLog"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.ScanLog (
	--LogID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	LogTS datetime NOT NULL DEFAULT(GETDATE()),
	LogEntryTitle varchar(128) NULL,
	LogMessage varchar(2000) NULL,
	ActionTaken varchar(25) NULL CONSTRAINT check_ActionTaken CHECK (ActionTaken IN ('INSERT','UPDATE','DELETE','DEPLOY','ERROR')),
	LoggedUser varchar(50) NULL DEFAULT(SUSER_NAME()))
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
:setvar DROP_PROC "sproc_InsertScanLog"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertScanLog') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertScanLog
	--
GO
:setvar CREATE_PROC "sproc_InsertScanLog"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_InsertScanLog
			@LogEntryTitle varchar(128)=NULL,
			@LogMessage varchar(1000)=NULL,
			@ActionTaken varchar(25)=NULL
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @LoggedUser varchar(50)
DECLARE @LogTS datetime
SET @LoggedUser = (SELECT SUSER_NAME() AS LoggedUser)
SET @LogTS = (SELECT GETDATE() AS LogTS)
--
	BEGIN TRY
		INSERT INTO	
			PowerSTIG.ScanLog (LogTS,LogEntryTitle,LogMessage,ActionTaken,LoggedUser)
		VALUES
			(
			@LogTS,
			@LogEntryTitle,
			@LogMessage,
			@ActionTaken,
			@LoggedUser
			)
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH

GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
PRINT 'End create logging objects'
-- ===============================================================================================
-- Drop constraints
-- ===============================================================================================
PRINT 'Begin drop constraints'
--

:setvar DROP_CONSTRAINT "FK_FindingRepo_ComplianceType"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_ComplianceType', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_ComplianceType]
GO
--
:setvar DROP_CONSTRAINT "FK_FindingRepo_TargetComputer"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_TargetComputer', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_TargetComputer]
GO
--
:setvar DROP_CONSTRAINT "FK_TargetComputer"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_TargetComputer', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[TargetTypeMap] DROP CONSTRAINT [FK_TargetComputer]
GO
--
:setvar DROP_CONSTRAINT "FK_ComplianceType"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_ComplianceType', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[TargetTypeMap] DROP CONSTRAINT [FK_ComplianceType]
GO
--
:setvar DROP_CONSTRAINT "FK_FindingRepo_FindingCategory"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_FindingCategory', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_FindingCategory]
GO
--
:setvar DROP_CONSTRAINT "FK_ComplianceCheckLog_TargetComputer"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_ComplianceCheckLog_TargetComputer', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[ComplianceCheckLog] DROP CONSTRAINT [FK_ComplianceCheckLog_TargetComputer]
GO
--
:setvar DROP_CONSTRAINT "FK_FindingRepo_Finding"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_FindingRepo_Finding', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[FindingRepo] DROP CONSTRAINT [FK_FindingRepo_Finding]
GO
--
:setvar DROP_CONSTRAINT "FK_ComplianceCheckLog_ComplianceType"
PRINT '		Drop constraint: $(CREATE_SCHEMA).$(DROP_CONSTRAINT)'
IF (OBJECT_ID('PowerSTIG.FK_ComplianceCheckLog_ComplianceType', 'F') IS NOT NULL)
	ALTER TABLE [PowerSTIG].[ComplianceCheckLog] DROP CONSTRAINT [FK_ComplianceCheckLog_ComplianceType]
GO
--
PRINT 'End drop constraints'
-- ===============================================================================================
-- Drop tables
-- ===============================================================================================
PRINT 'Begin drop tables'
--
:setvar DROP_TABLE "TargetTypeMap"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.TargetTypeMap') IS NOT NULL
	DROP TABLE PowerSTIG.TargetTypeMap
GO
--
:setvar DROP_TABLE "ComplianceTypes"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ComplianceTypes') IS NOT NULL
	DROP TABLE PowerSTIG.ComplianceTypes
GO
:setvar DROP_TABLE "ComplianceTargets"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ComplianceTargets') IS NOT NULL
	DROP TABLE PowerSTIG.ComplianceTargets
GO
:setvar DROP_TABLE "ComplianceIteration"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ComplianceIteration') IS NOT NULL
	DROP TABLE PowerSTIG.ComplianceIteration
GO
:setvar DROP_TABLE "FindingImport"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingImport') IS NOT NULL
	DROP TABLE PowerSTIG.FindingImport
GO
:setvar DROP_TABLE "UnreachableTargets"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.UnreachableTargets') IS NOT NULL
	DROP TABLE PowerSTIG.UnreachableTargets
GO
:setvar DROP_TABLE "FindingImportFiles"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingImportFiles') IS NOT NULL
	DROP TABLE PowerSTIG.FindingImportFiles
GO
:setvar DROP_TABLE "ComplianceCheckLog"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ComplianceCheckLog') IS NOT NULL
	DROP TABLE PowerSTIG.ComplianceCheckLog
GO
:setvar DROP_TABLE "FindingRepo"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingRepo') IS NOT NULL
	DROP TABLE PowerSTIG.FindingRepo
GO
:setvar DROP_TABLE "DupFindingFileCheck"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.DupFindingFileCheck') IS NOT NULL
	DROP TABLE PowerSTIG.DupFindingFileCheck
GO
:setvar DROP_TABLE "FindingSubPlatform"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingSubPlatform') IS NOT NULL
	DROP TABLE PowerSTIG.FindingSubPlatform
GO
:setvar DROP_TABLE "ScanImportLog"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ScanImportLog') IS NOT NULL
	DROP TABLE PowerSTIG.ScanImportLog
GO
--:setvar DROP_TABLE "ScanLog"
--PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
--IF OBJECT_ID('PowerSTIG.ScanLog') IS NOT NULL
--	DROP TABLE PowerSTIG.ScanLog
--GO
:setvar DROP_TABLE "ScanImportErrorLog"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.ScanImportErrorLog') IS NOT NULL
	DROP TABLE PowerSTIG.ScanImportErrorLog
GO
:setvar DROP_TABLE "ScanQueue"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerStig.ScanQueue') IS NOT NULL
	DROP TABLE PowerStig.ScanQueue
GO
:setvar DROP_TABLE "FindingCategory"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingCategory') IS NOT NULL
	DROP TABLE PowerSTIG.FindingCategory
GO
:setvar DROP_TABLE "FindingSeverity"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingSeverity') IS NOT NULL
	DROP TABLE PowerSTIG.FindingSeverity
GO
:setvar DROP_TABLE "ComplianceConfig"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF (SELECT CAST(SERVERPROPERTY('ProductMajorVersion')AS smallint)) >= 13
	BEGIN
		DECLARE @SQLcmd varchar(4000)
		SET @SQLcmd =' 
		IF OBJECT_ID (''PowerSTIG.ComplianceConfig'') IS NOT NULL
			BEGIN
				ALTER TABLE [PowerSTIG].[ComplianceConfig] SET ( SYSTEM_VERSIONING = OFF)
				DROP TABLE PowerSTIG.ComplianceConfigHistory
			END'
		EXEC(@SQLcmd)
	END
GO
IF OBJECT_ID('PowerSTIG.ComplianceConfig') IS NOT NULL
	DROP TABLE PowerSTIG.ComplianceConfig
GO
:setvar DROP_TABLE "Finding"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.Finding') IS NOT NULL
	DROP TABLE PowerSTIG.Finding
GO
:setvar DROP_TABLE "FindingImport"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.FindingImport') IS NOT NULL
	DROP TABLE PowerSTIG.FindingImport
GO
:setvar DROP_TABLE "Scans"
PRINT '		Drop table: $(CREATE_SCHEMA).$(DROP_TABLE)'
IF OBJECT_ID('PowerSTIG.Scans') IS NOT NULL
	DROP TABLE PowerSTIG.Scans
GO
--
PRINT 'End drop tables'
GO
-- ===============================================================================================
-- Drop views
-- ===============================================================================================
PRINT 'Begin drop views'
GO
:setvar DROP_VIEW "vw_TargetTypeMap"
PRINT '		Drop view: $(CREATE_SCHEMA).$(DROP_VIEW)'
IF OBJECT_ID('PowerSTIG.vw_TargetTypeMap') IS NOT NULL
	DROP VIEW PowerSTIG.vw_TargetTypeMap
GO
:setvar DROP_VIEW "v_BulkFindingImport"
PRINT '		Drop view: $(CREATE_SCHEMA).$(DROP_VIEW)'
IF OBJECT_ID('PowerSTIG.v_BulkFindingImport') IS NOT NULL
	DROP VIEW PowerSTIG.v_BulkFindingImport
PRINT 'End drop views'
-- ===============================================================================================
-- Create tables
-- ===============================================================================================
PRINT 'Begin create tables'
----

GO
--
:setvar CREATE_TABLE "Scans"
--  
CREATE TABLE PowerSTIG.Scans (
	ScanID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	ScanGUID char(36)  NOT NULL,
	ScanDate datetime NOT NULL,
	isProcessed BIT NOT NULL DEFAULT(0))
--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  

GO
--
:setvar CREATE_TABLE "FindingSeverity"
--  
CREATE TABLE [PowerSTIG].[FindingSeverity](
	[FindingSeverityID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
	[FindingSeverity] [varchar](128) NOT NULL)
--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO  

--
:setvar CREATE_TABLE "FindingCategory"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.FindingCategory(
	FindingCategoryID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	FindingCategory varchar(128) NOT NULL)
--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO  
--
:setvar CREATE_TABLE "Finding"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.Finding(
	FindingID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	Finding varchar(128) NOT NULL,
	FindingText varchar(768) NOT NULL)
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO
--
:setvar CREATE_TABLE "ComplianceTargets"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.ComplianceTargets (
	TargetComputerID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	TargetComputer varchar(256) NOT NULL UNIQUE,
	isActive BIT NOT NULL DEFAULT(1),
	LastComplianceCheck datetime NOT NULL DEFAULT('1900-01-01 00:00:00.000'))
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO
--
:setvar CREATE_TABLE "ComplianceTypes"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.ComplianceTypes (
	ComplianceTypeID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	ComplianceType varchar(256) NOT NULL UNIQUE,
	isActive BIT NOT NULL DEFAULT(1))
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO

--
:setvar CREATE_TABLE "ComplianceCheckLog"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.ComplianceCheckLog(
	CheckLogID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	--IterationID INT NOT NULL,
	ScanID INT NOT NULL,
	TargetComputerID INT NOT NULL,
	ComplianceTypeID INT NOT NULL,
	LastComplianceCheck datetime NOT NULL DEFAULT('1900-01-01 00:00:00.000'))
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';  
GO
--
:setvar CREATE_TABLE "FindingRepo"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.FindingRepo(
	TargetComputerID INT NOT NULL,
	FindingID INT NOT NULL,
	InDesiredState BIT NOT NULL,
	ComplianceTypeID INT NOT NULL,
	ScanID INT NOT NULL)
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO

--
--:setvar CREATE_TABLE "ScanLog"
--
--PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
--CREATE TABLE PowerSTIG.ScanLog (
--	LogID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
--	ComplianceIteration INT NOT NULL,
--	StepName varchar(128) NOT NULL,
--	StepMessage varchar(768) NULL,
--	StepAction varchar(12) NOT NULL,
--	StepTS datetime NOT NULL)
--	--
--	EXEC sys.sp_addextendedproperty   
--	@name = N'DEP_VER',   
--	@value = '$(DEP_VER)',  
--	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
--	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)';
--
--:setvar CREATE_TABLE "ScanLog"
----
--PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
--CREATE TABLE PowerSTIG.ScanLog (
--	--LogID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
--	LogTS datetime NOT NULL DEFAULT(GETDATE()),
--	LogEntryTitle varchar(128) NULL,
--	LogMessage varchar(2000) NULL,
--	ActionTaken varchar(25) NULL CONSTRAINT check_ActionTaken CHECK (ActionTaken IN ('INSERT','UPDATE','DELETE','DEPLOY','ERROR')),
--	LoggedUser varchar(50) NULL DEFAULT(SUSER_NAME()))
--	--
--	EXEC sys.sp_addextendedproperty   
--	@name = N'DEP_VER',   
--	@value = '$(DEP_VER)',  
--	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
--	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
--GO

--
:setvar CREATE_TABLE "ScanQueue"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerStig.ScanQueue (
	ScanQueueID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	TargetComputer varchar(256) NOT NULL,
	ComplianceType varchar(256) NOT NULL,
	QueueStart datetime NOT NULL,
	QueueEnd datetime NOT NULL DEFAULT('1900-01-01 00:00:00.000'))
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
--
:setvar CREATE_TABLE "ComplianceConfig"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
IF (SELECT CAST(SERVERPROPERTY('ProductMajorVersion')AS smallint)) >= 13
	BEGIN
		DECLARE @SQLcmd varchar(4000)
		SET @SQLcmd ='
		CREATE TABLE PowerSTIG.ComplianceConfig (
			ConfigID SMALLINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
			ConfigProperty varchar(256) NOT NULL,
			ConfigSetting varchar(256) NOT NULL,
			ConfigNote varchar(1000) NULL,
			SysStartTime datetime2 GENERATED ALWAYS AS ROW START NOT NULL,  
			SysEndTime datetime2 GENERATED ALWAYS AS ROW END NOT NULL,
				PERIOD FOR SYSTEM_TIME (SysStartTime, SysEndTime))
				WITH
				(   
				  SYSTEM_VERSIONING = ON (HISTORY_TABLE = PowerSTIG.ComplianceConfigHistory)   
				)'
		EXEC (@SQLcmd)
	END
GO
IF (SELECT CAST(SERVERPROPERTY('ProductMajorVersion') AS smallint)) <= 12
	BEGIN
		DECLARE @SQLcmd varchar(4000)
		SET @SQLcmd ='
		CREATE TABLE PowerSTIG.ComplianceConfig (
			ConfigID SMALLINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
			ConfigProperty varchar(256) NOT NULL,
			ConfigSetting varchar(256) NOT NULL,
			ConfigNote varchar(1000) NULL)'
		EXEC (@SQLcmd)
	END
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
--
:setvar CREATE_TABLE "TargetTypeMap"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.TargetTypeMap (
	TargetTypeMapID INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	TargetComputerID INT NOT NULL,
	ComplianceTypeID INT NOT NULL,
	isRequired BIT NOT NULL)
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
--
:setvar CREATE_TABLE "FindingImport"
--
PRINT '		Create table: $(CREATE_SCHEMA).$(CREATE_TABLE)'
CREATE TABLE PowerSTIG.FindingImport (
	--FindingImportID INT IDENTITY(1,1) NOT NULL,
	TargetComputer varchar(255) NULL,
	VulnID varchar(25) NULL,
	FindingSeverity varchar(25) NULL,
	StigDefinition varchar(768) NULL,
	StigType varchar(50) NULL,
	DesiredState varchar(25) NULL,
	ScanDate datetime NULL,
	[GUID] char(36) NULL,
	ImportDate datetime DEFAULT(GETDATE()))
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'TABLE',  @level1name = '$(CREATE_TABLE)'; 
GO
PRINT 'End create tables'
GO
-- ===============================================================================================
-- Create views
-- ===============================================================================================
PRINT 'Begin create views'
GO
:setvar CREATE_VIEW "vw_TargetTypeMap"
--
PRINT '		Create view: $(CREATE_SCHEMA).$(CREATE_VIEW)'
GO
CREATE VIEW PowerSTIG.vw_TargetTypeMap
AS
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 1112018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
	SELECT
		T.TargetComputer,
		C.ComplianceType
	FROM
		PowerSTIG.TargetTypeMap M
			JOIN PowerSTIG.ComplianceTargets T
				ON M.TargetComputerID = T.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes C
				ON M.ComplianceTypeID = C.ComplianceTypeID
	WHERE
		isRequired = 1
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'VIEW',  @level1name = '$(CREATE_VIEW)'; 
GO
PRINT 'End create views'
GO

-- ===============================================================================================
-- Hydrate ComplianceConfig table
-- ===============================================================================================
PRINT 'Hydrating PowerSTIG.ComplianceConfig table'
--
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('FindingRepoTableRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('LastComplianceCheckAlert','OFF','Possible values are ON or OFF.  Controls whether the last compliance type checks for a target computer has violated the LastComplianceCheckInDays threshold.')
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('LastComplianceCheckInDays','90','Specifies the number of days that a compliance type check for a target computer may not occur.')
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('LastComplianceCheckAlertRecipients','user@mail.mil',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ComplianceCheckLogTableRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('FindingImportFilesTableRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('MailProfileName','$(MAIL_PROFILE)',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('CKLfileLoc','$(CKL_OUTPUT)',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('CKLfileArchiveLoc','$(CKL_ARCHIVE)',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ScanImportLogRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ScanImportErrorLogRetentionDays','365',NULL)
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ConcurrentScans','5','This setting controls the maximum number of simultaneous scans.')
	INSERT INTO PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote) VALUES ('ScanLogRetentionDays','730','This setting controls the number of days of history to store in the PowerSTIG.ScanLog table.')
GO
-- ===============================================================================================
-- Hydrate compliance types
-- ===============================================================================================
PRINT 'Hydrating compliance types in PowerSTIG.ComplianceTypes'
--
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('MemberServer',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('DomainController',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('DotNet',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Firefox',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Firewall',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('IIS',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Word',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Excel',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('PowerPoint',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Outlook',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('JRE',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Sql',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('Client',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('DNS',1)
		INSERT INTO PowerSTIG.ComplianceTypes (ComplianceType,isActive) VALUES ('IE',1)
	--
GO
-- ===============================================================================================
-- Create constraints
-- ===============================================================================================
PRINT 'Begin create constraints'
--
:setvar CREATE_CONSTRAINT "FK_TargetComputer"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.TargetTypeMap WITH NOCHECK ADD  CONSTRAINT [FK_TargetComputer]
	FOREIGN KEY (TargetComputerID) REFERENCES [PowerSTIG].[ComplianceTargets] (TargetComputerID)
GO
--
:setvar CREATE_CONSTRAINT "FK_ComplianceType"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.TargetTypeMap WITH NOCHECK ADD  CONSTRAINT [FK_ComplianceType]
	FOREIGN KEY (ComplianceTypeID) REFERENCES [PowerSTIG].[ComplianceTypes] (ComplianceTypeID)
GO
--
:setvar CREATE_CONSTRAINT "FK_FindingRepo_TargetComputer"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.FindingRepo WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_TargetComputer]
	FOREIGN KEY (TargetComputerID) REFERENCES [PowerSTIG].[ComplianceTargets] (TargetComputerID)
GO
--
:setvar CREATE_CONSTRAINT "FK_FindingRepo_ComplianceType"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.FindingRepo WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_ComplianceType]
	FOREIGN KEY (ComplianceTypeID) REFERENCES [PowerSTIG].[ComplianceTypes] (ComplianceTypeID)
GO

--
:setvar CREATE_CONSTRAINT "FK_ComplianceCheckLog_TargetComputer"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.ComplianceCheckLog WITH NOCHECK ADD  CONSTRAINT [FK_ComplianceCheckLog_TargetComputer]
	FOREIGN KEY (TargetComputerID) REFERENCES [PowerSTIG].[ComplianceTargets] (TargetComputerID)
GO
--
:setvar CREATE_CONSTRAINT "FK_ComplianceCheckLog_ComplianceType"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.ComplianceCheckLog WITH NOCHECK ADD  CONSTRAINT [FK_ComplianceCheckLog_ComplianceType]
	FOREIGN KEY (ComplianceTypeID) REFERENCES [PowerSTIG].[ComplianceTypes] (ComplianceTypeID)
GO
--
:setvar CREATE_CONSTRAINT "FK_FindingRepo_Finding"
PRINT '		Create constraint: $(CREATE_SCHEMA).$(CREATE_CONSTRAINT)'
ALTER TABLE PowerSTIG.FindingRepo WITH NOCHECK ADD  CONSTRAINT [FK_FindingRepo_Finding]
	FOREIGN KEY (FindingID) REFERENCES [PowerSTIG].[Finding] (FindingID)
GO
--
PRINT 'End create constraints'
GO

-- ===============================================================================================
-- Indexes
-- ===============================================================================================
PRINT 'Begin create indexes'
--
:setvar CREATE_INDEX "IX_UNQ_ConfigProperty"
PRINT '		Create index: $(CREATE_SCHEMA).$(CREATE_INDEX)'
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_ConfigProperty')
	CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_ConfigProperty ON PowerSTIG.ComplianceConfig(ConfigProperty)
GO
:setvar CREATE_INDEX "IX_UNQ_ComputerAndTypeID"
PRINT '		Create index: $(CREATE_SCHEMA).$(CREATE_INDEX)'
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_UNQ_ComputerAndTypeID')
	CREATE UNIQUE NONCLUSTERED INDEX IX_UNQ_ComputerAndTypeID ON PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID)
GO
:setvar CREATE_INDEX "IX_TargetComplianceCheck"
PRINT '		Create index: $(CREATE_SCHEMA).$(CREATE_INDEX)'
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_TargetComplianceCheck')
	--DROP INDEX [IX_TargetComplianceCheck] ON [PowerSTIG].[ComplianceCheckLog]
	CREATE NONCLUSTERED INDEX [IX_TargetComplianceCheck]
		ON PowerSTIG.ComplianceCheckLog(TargetComputerID,ComplianceTypeID,LastComplianceCheck)
GO
:setvar CREATE_INDEX "IX_CoverRepo"
PRINT '		Create index: $(CREATE_SCHEMA).$(CREATE_INDEX)'
IF NOT EXISTS (SELECT name FROM sys.indexes WHERE name = 'IX_CoverRepo')
	--DROP INDEX [IX_CoverRepo] ON [PowerSTIG].[FindingRepo]
	CREATE NONCLUSTERED INDEX IX_CoverRepo 
		ON PowerSTIG.FindingRepo(TargetComputerID) INCLUDE (FindingID,InDesiredState,ComplianceTypeID,ScanID)
PRINT 'End create indexes'
-- ===============================================================================================
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
-- ===============================================================================================
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
-- Stored procedure drop and create starts
-- ===============================================================================================
-- ///////////////////////////////////////////////////////////////////////////////////////////////
-- ===============================================================================================
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
PRINT 'Begin drop procedures'
--
:setvar DROP_PROC "sproc_GetAllServersRoles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetAllServersRoles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetAllServersRoles
	--
GO
:setvar DROP_PROC "sproc_GetInactiveServersRoles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetInactiveServersRoles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetInactiveServersRoles
	--
GO
:setvar DROP_PROC "sproc_GetActiveRoles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetActiveRoles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetActiveRoles
	--
GO
:setvar DROP_PROC "sproc_UpdateServerRoles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_UpdateServerRoles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_UpdateServerRoles
	--
GO
:setvar DROP_PROC "sproc_GetRolesPerServer"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetRolesPerServer') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetRolesPerServer
	--
GO
:setvar DROP_PROC "sproc_GetActiveServers"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetActiveServers') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetActiveServers
	--
GO
:setvar DROP_PROC "sproc_GetReachableTargets"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetReachableTargets') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetReachableTargets
	--
GO
:setvar DROP_PROC "sproc_ProcessRawInput"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_ProcessRawInput') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_ProcessRawInput
	--
GO
:setvar DROP_PROC "sproc_CreateComplianceIteration"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_CreateComplianceIteration') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_CreateComplianceIteration
	--
GO
:setvar DROP_PROC "sproc_CompleteComplianceIteration"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_CompleteComplianceIteration') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_CompleteComplianceIteration
	--
GO
:setvar DROP_PROC "GetComplianceStateByServer"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.GetComplianceStateByServer') IS NOT NULL
	DROP PROCEDURE PowerSTIG.GetComplianceStateByServer
	--
GO
:setvar DROP_PROC "sproc_GetComplianceStateByServer"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetComplianceStateByServer') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetComplianceStateByServer
GO
:setvar DROP_PROC "sproc_InsertUnreachableTargets"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertUnreachableTargets') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertUnreachableTargets
	--
GO
:setvar DROP_PROC "InsertFindingFileImport"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.InsertFindingFileImport') IS NOT NULL
	DROP PROCEDURE PowerSTIG.InsertFindingFileImport
	--
GO
:setvar DROP_PROC "sproc_GetUnprocessedFiles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetUnprocessedFiles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetUnprocessedFiles
	--
GO
:setvar DROP_PROC "sproc_UpdateFindingImportFiles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_UpdateFindingImportFiles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_UpdateFindingImportFiles
	--
GO
:setvar DROP_PROC "sproc_InsertComplianceCheckLog"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertComplianceCheckLog') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertComplianceCheckLog
	--
GO
:setvar DROP_PROC "sproc_DuplicateFileCheck"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_DuplicateFileCheck') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_DuplicateFileCheck
	--
GO
:setvar DROP_PROC "sproc_GetDuplicateFiles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetDuplicateFiles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetDuplicateFiles
	--
GO
:setvar DROP_PROC "sproc_GetConfigSetting"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetConfigSetting') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetConfigSetting
	--
GO
:setvar DROP_PROC "sproc_AssociateFileIDtoData"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_AssociateFileIDtoData') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_AssociateFileIDtoData
	--
GO
:setvar DROP_PROC "sproc_AssociateFileToTarget"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_AssociateFileToTarget') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_AssociateFileToTarget
	--
GO
:setvar DROP_PROC "sproc_GetFilesToCompress"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetFilesToCompress') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetFilesToCompress
	--
GO
:setvar DROP_PROC "sproc_GetTargetsWithFilesToCompress"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetTargetsWithFilesToCompress') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetTargetsWithFilesToCompress
	--
GO
:setvar DROP_PROC "sproc_AddTargetComputer"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_AddTargetComputer') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_AddTargetComputer
	--
GO
:setvar DROP_PROC "sproc_GetFullyProcessedFiles"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetFullyProcessedFiles') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetFullyProcessedFiles
	--
GO
:setvar DROP_PROC "sproc_PurgeHistory"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_PurgeHistory') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_PurgeHistory
	--
GO
:setvar DROP_PROC "sproc_GetLastComplianceCheckByTarget"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetLastComplianceCheckByTarget') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetLastComplianceCheckByTarget
	--
GO
:setvar DROP_PROC "sproc_GetLastComplianceCheckByTargetAndRole"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetLastComplianceCheckByTargetAndRole') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetLastComplianceCheckByTargetAndRole
	--
GO
:setvar DROP_PROC "sproc_DuplicateFileAlert"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_DuplicateFileAlert') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_DuplicateFileAlert
	--
GO
:setvar DROP_PROC "sproc_UpdateConfig"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_UpdateConfig') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_UpdateConfig
	--
GO
:setvar DROP_PROC "sproc_InsertConfig"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertConfig') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertConfig
	--
GO
:setvar DROP_PROC "sproc_InsertScanErrorLog"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertScanErrorLog') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertScanErrorLog
	--
GO
--:setvar DROP_PROC "sproc_InsertScanLog"
--PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
--IF OBJECT_ID('PowerSTIG.sproc_InsertScanLog') IS NOT NULL
--	DROP PROCEDURE PowerSTIG.sproc_InsertScanLog
--	--
--GO
:setvar DROP_PROC "sproc_GetScanQueue"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetScanQueue') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetScanQueue
	--
GO
:setvar DROP_PROC "sproc_GetLastDataForCKL"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetLastDataForCKL') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetLastDataForCKL
	--
GO
:setvar DROP_PROC "sproc_GetIterationID"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetIterationID') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetIterationID
	--
GO
:setvar DROP_PROC "sproc_DeleteTargetComputerAndData"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_DeleteTargetComputerAndData') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_DeleteTargetComputerAndData
	--
GO
:setvar DROP_PROC "sproc_InsertFindingImport"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_InsertFindingImport') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_InsertFindingImport
GO
:setvar DROP_PROC "sproc_ProcessFindings"
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_ProcessFindings') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_ProcessFindings
GO
:setvar DROP_PROC "sproc_GetDependencies "
PRINT '		Drop procedure: $(CREATE_SCHEMA).$(DROP_PROC)'
IF OBJECT_ID('PowerSTIG.sproc_GetDependencies ') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_GetDependencies 
GO
PRINT 'End drop procedures'
GO
PRINT 'Start create procedures'
GO
-- ==================================================================
-- sproc_GetAllServersRoles
-- ==================================================================
:setvar CREATE_PROC "sproc_GetAllServersRoles"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetAllServersRoles AS
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
-- Query for all servers - Return Name/Roles
-- EXAMPLE: EXEC PowerSTIG.sproc_GetAllServersRoles
	SELECT DISTINCT
		T.TargetComputer,
		Y.ComplianceType
	FROM
		PowerSTIG.ComplianceTargets T
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON M.ComplianceTypeID = Y.ComplianceTypeID
	WHERE
		M.isRequired = 1
		AND
		T.isActive = 1
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- sproc_GetInactiveServersRoles
-- ==================================================================
:setvar CREATE_PROC "sproc_GetInactiveServersRoles"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetInactiveServersRoles AS
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
-- Query for all inactive - Return Name/Roles where active == 0 - Don't Return where active == 1
-- EXAMPLE: EXEC PowerSTIG.sproc_GetInactiveServersRoles
	SELECT DISTINCT
		T.TargetComputer,
		Y.ComplianceType
	FROM
		PowerSTIG.ComplianceTargets T
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON M.ComplianceTypeID = Y.ComplianceTypeID
	WHERE
		M.isRequired = 0
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- sproc_GetActiveRoles
-- ==================================================================
:setvar CREATE_PROC "sproc_GetActiveRoles"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetActiveRoles
			@ComplianceType varchar(256)
 AS
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
-- Query by role Return Name/Roles where specified role/roles == 1
-- EXAMPLE: EXEC PowerSTIG.sproc_GetActiveRoles @ComplianceType = 'DNScheck'
	SELECT DISTINCT
		T.TargetComputer
	FROM
		PowerSTIG.ComplianceTargets T
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON M.ComplianceTypeID = Y.ComplianceTypeID
	WHERE
		Y.ComplianceType = @ComplianceType
		AND
		M.isRequired = 1
		AND
		T.isActive = 1
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- sproc_UpdateServerRoles
-- ==================================================================
:setvar CREATE_PROC "sproc_UpdateServerRoles"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_UpdateServerRoles
				@TargetComputer varchar(256),
				@ComplianceType varchar(256),
				@UpdateAction BIT --1 = Enable, 0 = Disable
AS
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
-- Set Active - By name set value 0 or 1
-- EXAMPLE: EXEC PowerSTIG.sproc_UpdateServerRoles @TargetComputer = 'CRAFNCEDC01', @ComplianceType = 'DNScheck', @UpdateAction = 0
DECLARE @TargetComputerID INT
DECLARE @ComplianceTypeID INT
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = LTRIM(RTRIM(@ComplianceType)))
SET @StepMessage = ('Target type map update to ['+@TargetComputer+'] requested by ['+SUSER_NAME()+'].  The UpdateAction is ['+CAST(@UpdateAction AS char(2))+'].')
--
--
-- Invalid TargetComputer specified
-- 
	IF @TargetComputerID IS NULL
		BEGIN
			PRINT 'The specified target computer ['+LTRIM(RTRIM(@TargetComputer))+'] was not found.  Please validate.'
			RETURN
		END
--
-- Invalid ComplianceType specified
--

	IF @ComplianceTypeID IS NULL
		BEGIN
			PRINT 'The specified compliance type ['+LTRIM(RTRIM(@ComplianceType))+'] was not found.  Please validate.'
			RETURN
		END
--
SET @StepName = 'Update TargetTypeMap'
SET @StepAction = 'UPDATE'
--
	BEGIN TRY
			UPDATE
					PowerSTIG.TargetTypeMap
				SET
					isRequired = @UpdateAction
				FROM
					PowerSTIG.ComplianceTargets T
						JOIN PowerSTIG.TargetTypeMap M
							ON T.TargetComputerID = M.TargetComputerID
						JOIN PowerSTIG.ComplianceTypes Y
							ON M.ComplianceTypeID = Y.ComplianceTypeID
				WHERE
					T.TargetComputerID = @TargetComputerID
					AND
					Y.ComplianceTypeID = @ComplianceTypeID 
		--
		-- Log the update
		--
		EXEC PowerSTIG.sproc_InsertScanLog
		   @LogEntryTitle = @StepName
		   ,@LogMessage = @StepMessage
		   ,@ActionTaken = @StepAction

		--
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO
-- ==================================================================
-- sproc_GetRolesPerServer
-- ==================================================================
:setvar CREATE_PROC "sproc_GetRolesPerServer"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE [PowerSTIG].[sproc_GetRolesPerServer] 
				@TargetComputer varchar(256)
AS
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--Query roles for a specific Target Computer
DECLARE @TargetComputerID INT
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
	--
	SELECT DISTINCT
		Y.ComplianceType
	FROM
		PowerSTIG.ComplianceTargets T
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON M.ComplianceTypeID = Y.ComplianceTypeID
	WHERE
		M.isRequired = 1
		AND
		T.isActive = 1
		AND
		T.TargetComputerID = @TargetComputerID
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO 
-- ==================================================================
-- sproc_GetActiveServers
-- ==================================================================
:setvar CREATE_PROC "sproc_GetActiveServers"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE [PowerSTIG].[sproc_GetActiveServers] 
AS
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
	SELECT DISTINCT
		TargetComputer
	FROM
		PowerSTIG.ComplianceTargets T
	WHERE
		T.isActive = 1
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)';
GO 
-- ==================================================================
-- GetComplianceStateByServer
-- ==================================================================
:setvar CREATE_PROC "GetComplianceStateByServer"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.GetComplianceStateByServer
				@TargetComputer varchar(255),
				@GUID char(36)
	AS
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
	SET NOCOUNT ON
	--
	DECLARE @TargetComputerID INT
	DECLARE @ScanID INT
	SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @TargetComputer)
	SET @ScanID = (SELECT ScanID FROM PowerSTIG.Scans WHERE ScanGUID = @GUID)
-- =======================================================
-- Retrieve findings
-- =======================================================
		SELECT
			DISTINCT (F.Finding),
			R.InDesiredState
		FROM
			PowerSTIG.FindingRepo R
				JOIN
					PowerSTIG.Finding F
						ON R.FindingID = F.FindingID
		WHERE
			R.TargetComputerID = @TargetComputerID 
			AND
			R.ScanID = @ScanID
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_GetConfigSetting
-- ==================================================================
:setvar CREATE_PROC "sproc_GetConfigSetting"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetConfigSetting 
					@ConfigProperty varchar(255)
AS
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 05222018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
SET NOCOUNT ON
--
	SELECT ConfigSetting = 
		CASE
			WHEN LTRIM(RTRIM(ConfigSetting)) = '' THEN 'No value specified for supplied ConfigProperty.'
			WHEN ConfigSetting IS NULL THEN 'No value specified for supplied ConfigProperty.'
		ELSE LTRIM(RTRIM(ConfigSetting))
		END
	FROM
		PowerSTIG.ComplianceConfig
	WHERE
		ConfigProperty = @ConfigProperty
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_AddTargetComputer
-- ==================================================================
:setvar CREATE_PROC "sproc_AddTargetComputer"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
IF OBJECT_ID('PowerSTIG.sproc_AddTargetComputer') IS NOT NULL
	DROP PROCEDURE PowerSTIG.sproc_AddTargetComputer
GO
CREATE PROCEDURE PowerSTIG.sproc_AddTargetComputer
					@TargetComputerName varchar(MAX) NULL,
					@MemberServer BIT = 0,
					@DomainController BIT = 0,
					@DotNet BIT = 0,
					@Firefox BIT = 0,
					@Firewall BIT = 0,
					@IIS BIT = 0,
					@Word BIT = 0,
					@Excel BIT = 0,
					@PowerPoint BIT = 0,
					@Outlook BIT = 0,
					@JRE BIT = 0,
					@Sql BIT = 0,
					@Client BIT = 0,
					@DNS BIT = 0,
					@IE BIT = 0
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- 07162018 - Kevin Barlett, Microsoft - Additions and changes to support PowerSTIG V2.
-- Use examples:
-- EXEC PowerSTIG.sproc_AddTargetComputer @TargetComputerName = 'ThisIsATargetComputer',@DNS=1
-- EXEC PowerSTIG.sproc_AddTargetComputer @TargetComputerName = 'ThisIsATargetComputer',@MemberServer = 1,  @DNS = 1, @IE = 1
-- EXEC PowerSTIG.sproc_AddTargetComputer @TargetComputerName = 'ThisIsATargetComputer, ThisIsAnotherTargetComputer, HereIsAnotherTargetComputer, AndAnotherTargetComputer', @MemberServer = 1, @IE = 1
-- ===============================================================================================
DECLARE @CreateFunction varchar(MAX)
DECLARE @TargetComputer varchar(256)
DECLARE @TargetComputerID INT
DECLARE @DuplicateTargets varchar(MAX)
DECLARE @DuplicateToValidate varchar(MAX)
DECLARE @StepName varchar(256)
DECLARE @LogMessage varchar(2000)
DECLARE @StepAction varchar(25)
DECLARE @StepMessage varchar(2000)
SET @StepName = 'Add new target computer'
-- ----------------------------------------------------
-- Validate @TargetComputerName
-- ----------------------------------------------------
	IF @TargetComputerName IS NULL
		BEGIN
			PRINT 'ACTION REQUIRED: Please specify at least one target computer and rerun the procedure.'
			RETURN
		END

-- ----------------------------------------------------
-- Create SplitString function
-- ----------------------------------------------------
IF OBJECT_ID('dbo.SplitString') IS NULL
	BEGIN
		SET @CreateFunction = '
					CREATE FUNCTION SplitString
				(     
					  @Input NVARCHAR(MAX),
					  @Character CHAR(1)
				)
				RETURNS @Output TABLE (
					  SplitOutput NVARCHAR(1000)
				)
				AS
				BEGIN
					  DECLARE @StartIndex INT, @EndIndex INT
 
					  SET @StartIndex = 1
					  IF SUBSTRING(@Input, LEN(@Input) - 1, LEN(@Input)) <> @Character
					  BEGIN
							SET @Input = @Input + @Character
					  END
 
					  WHILE CHARINDEX(@Character, @Input) > 0
					  BEGIN
							SET @EndIndex = CHARINDEX(@Character, @Input)
            
							INSERT INTO @Output(SplitOutput)
							SELECT SUBSTRING(@Input, @StartIndex, @EndIndex - 1)
            
							SET @Input = SUBSTRING(@Input, @EndIndex + 1, LEN(@Input))
					  END
 
					  RETURN
				END'
		--PRINT @CreateFunction
		EXEC (@CreateFunction)
	END
-- ----------------------------------------------------
-- Parse @TargetComputerName
-- ----------------------------------------------------

	IF OBJECT_ID('tempdb.dbo.#TargetComputers') IS NOT NULL
		DROP TABLE #TargetComputers
		--
		CREATE TABLE #TargetComputers (TargetComputer varchar(256) NULL, isProcessed BIT,AlreadyExists BIT)
		--
			INSERT INTO #TargetComputers
				(TargetComputer,isProcessed,AlreadyExists)
			SELECT
				LTRIM(RTRIM(SplitOutput)) AS TargetComputer,
				0 AS isProcessed,
				0 AS AlreadyExists
			FROM
				SplitString(@TargetComputerName,',')

-- ----------------------------------------------------
-- Validate non-duplicate 
-- ----------------------------------------------------
WHILE EXISTS
	(SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0)
		BEGIN
			SET @TargetComputer = (SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0)
			--
				IF (SELECT 1 FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @TargetComputer) = 1
					BEGIN
						UPDATE #TargetComputers SET AlreadyExists = 1 WHERE TargetComputer = @TargetComputer
					END
				--
				UPDATE #TargetComputers SET isProcessed = 1 WHERE TargetComputer = @TargetComputer
		END
	--
	-- Reset isProcessed flag
	--
		UPDATE #TargetComputers SET isProcessed = 0
-- ----------------------------------------------------
-- If not exists, add TargetComputerName to PowerSTIG.ComplianceTargets
-- ----------------------------------------------------
WHILE EXISTS
	(SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0 AND AlreadyExists = 0)
		BEGIN
			SET @TargetComputer = (SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0 AND AlreadyExists = 0)
			--
				INSERT INTO	PowerSTIG.ComplianceTargets (TargetComputer,isActive,LastComplianceCheck)
				VALUES
				(@TargetComputer,1,'1900-01-01 00:00:00.000')
			--
			UPDATE #TargetComputers SET isProcessed = 1 WHERE TargetComputer = @TargetComputer
		END
		--
		-- Reset isProcessed flag
		-- 
			UPDATE #TargetComputers SET isProcessed = 0
-- ----------------------------------------------------
-- Set TargetTypeMap for each target computer
-- ----------------------------------------------------
WHILE EXISTS
	(SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0 AND AlreadyExists = 0)
		BEGIN
			SET @StepAction = 'INSERT'
			SET @TargetComputer = (SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0 AND AlreadyExists = 0)
			SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @TargetComputer)
			SET @StepMessage = 'Target ['+@TargetComputer+'] added.'
			--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@MemberServer FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'MemberServer'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@DomainController FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'DomainController'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@DotNet FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'DotNet'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@Firefox FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'Firefox'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@Firewall FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'Firewall'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@IIS BIT FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'IIS'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@Word FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'Word'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@Excel FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'Excel'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@PowerPoint FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'PowerPoint'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@Outlook FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'Outlook'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@JRE FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'JRE'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@Sql FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'Sql'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@Client FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'Client'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@DNS FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'DNS'
				--
				INSERT INTO PowerSTIG.TargetTypeMap (TargetComputerID,ComplianceTypeID,isRequired)
				SELECT @TargetComputerID,Y.ComplianceTypeID,@IE FROM PowerSTIG.ComplianceTypes Y WHERE Y.ComplianceType = 'IE'
		--
			UPDATE #TargetComputers SET isProcessed = 1 WHERE TargetComputer = @TargetComputer
			-- Log the action
					EXEC PowerSTIG.sproc_InsertScanLog
				   @LogEntryTitle = @StepName
				   ,@LogMessage = @StepMessage
				   ,@ActionTaken = @StepAction
				   
		END
		--
		-- Reset isProcessed flag
		--
			UPDATE #TargetComputers SET isProcessed = 0
-- ----------------------------------------------------
-- Notify if TargetComputers already existed.  At present, no action is taken on these target computers
-- so as to remove the potential for orphaning finding data.  This may need to be revisted in the future.
-- ----------------------------------------------------
SET @DuplicateToValidate = ''
WHILE EXISTS
	(SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed = 0 AND AlreadyExists = 1)
		
		BEGIN
			SET @TargetComputer = (SELECT TOP 1 TargetComputer FROM #TargetComputers WHERE isProcessed=0 AND AlreadyExists = 1)
			SET @DuplicateToValidate = @DuplicateToValidate +'||'+ @TargetComputer
			--
			UPDATE #TargetComputers SET isProcessed = 1 WHERE TargetComputer = @TargetComputer
		END

	IF LEN(@DuplicateToValidate) > 0
		BEGIN
			SET @StepAction = 'ERROR'
			PRINT 'PLEASE VALIDATE: The following supplied target computer(s) appears to exist and therefore no action was taken at this time: '+ @DuplicateToValidate
			SET @StepMessage = 'The following supplied target computer(s) appears to exist and therefore no action was taken at this time: ['+ @DuplicateToValidate+']'
					-- Log the action
					EXEC PowerSTIG.sproc_InsertScanLog
				   @LogEntryTitle = @StepName
				   ,@LogMessage = @StepMessage
				   ,@ActionTaken = @StepAction
		END
-- ----------------------------------------------------
-- Cleanup
-- ----------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#TargetComputers') IS NOT NULL
	DROP TABLE #TargetComputers
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_GetLastComplianceCheckByTarget
-- ==================================================================
:setvar CREATE_PROC "sproc_GetLastComplianceCheckByTarget"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetLastComplianceCheckByTarget
							@TargetComputer varchar(255)
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @TargetComputerID INT
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
--
			SELECT
				T.TargetComputer,
				Y.ComplianceType,
				MAX(L.LastComplianceCheck) AS LastComplianceCheck
			FROM
				PowerSTIG.ComplianceTargets T
					JOIN
						PowerSTIG.ComplianceCheckLog L
							ON T.TargetComputerID = L.TargetComputerID
					JOIN
						PowerSTIG.ComplianceTypes Y
							ON Y.ComplianceTypeID = L.ComplianceTypeID
			WHERE
				T.TargetComputerID = @TargetComputerID
				AND
				Y.ComplianceType != 'UNKNOWN'
			GROUP BY
				T.TargetComputer,Y.ComplianceType, L.LastComplianceCheck
				
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- sproc_GetLastComplianceCheckByTargetAndRole
-- ==================================================================
:setvar CREATE_PROC "sproc_GetLastComplianceCheckByTargetAndRole"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetLastComplianceCheckByTargetAndRole
							@TargetComputer varchar(255),
							@Role varchar(256)
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
	--
	DECLARE @TargetComputerID INT
	DECLARE @ComplianceTypeID INT
	SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
	SET @ComplianceTypeID = (SELECT ComplianceTypeID FROM PowerSTIG.ComplianceTypes WHERE ComplianceType = LTRIM(RTRIM(@Role)))
	--
			SELECT
				T.TargetComputer,
				Y.ComplianceType,
				MAX(L.LastComplianceCheck) AS LastComplianceCheck
			FROM
				PowerSTIG.ComplianceTargets T
					JOIN
						PowerSTIG.ComplianceCheckLog L
							ON T.TargetComputerID = L.TargetComputerID
					JOIN
						PowerSTIG.ComplianceTypes Y
							ON Y.ComplianceTypeID = L.ComplianceTypeID
			WHERE
				T.TargetComputerID = @TargetComputerID
				AND
				Y.ComplianceTypeID = @ComplianceTypeID
			GROUP BY
				T.TargetComputer,Y.ComplianceType, L.LastComplianceCheck
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_UpdateConfig
-- ==================================================================
:setvar CREATE_PROC "sproc_UpdateConfig"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_UpdateConfig
			@ConfigProperty varchar(256) = NULL,
			@NewConfigSetting varchar(256) = NULL,
			@NewConfigNote varchar(1000) = NULL
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @ConfigID INT
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(2000)
DECLARE @StepAction varchar(25)
SET @ConfigProperty = LTRIM(RTRIM(@ConfigProperty))
SET @NewConfigSetting = LTRIM(RTRIM(@NewConfigSetting))
-- ----------------------------------------------------
-- Validate ConfigProperty input
-- ----------------------------------------------------
	IF @ConfigProperty IS NULL
		BEGIN
			PRINT 'Please specify a ConfigProperty.  Example: EXEC PowerSTIG.sproc_UpdateConfig ''ThisIsAconfigurationProperty'''
			RETURN
		END
		--
		--

	IF NOT EXISTS
		(SELECT TOP 1 ConfigID FROM PowerSTIG.ComplianceConfig WHERE ConfigProperty = @ConfigProperty)
			BEGIN
				PRINT 'The specified configuration property '+@ConfigProperty+' does not appear to be valid. Please specify a valid configuration property'
				RETURN
			END
-- ----------------------------------------------------
-- ConfigProperty validated, get ConfigID
-- ----------------------------------------------------
	SET @ConfigID = (SELECT ConfigID FROM PowerSTIG.ComplianceConfig WHERE ConfigProperty = @ConfigProperty)
-- ----------------------------------------------------
-- Update ConfigSetting
-- ----------------------------------------------------
IF @NewConfigSetting IS NOT NULL
	SET @StepName = 'Update configuration setting'
	SET @StepMessage = 'Update to ConfigID: ['+CAST(@ConfigID AS varchar(25))+'].  The new value is ConfigSetting: ['+@NewConfigSetting+'].'
	SET @StepAction = 'UPDATE'
	--
	BEGIN TRY
				UPDATE
					PowerSTIG.ComplianceConfig
				SET
					ConfigSetting = @NewConfigSetting
				WHERE
					ConfigID = @ConfigID
				--
				-- Log the action
				--
				EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH
-- ----------------------------------------------------
-- Update ConfigNote
-- ----------------------------------------------------
IF @NewConfigNote IS NOT NULL
	BEGIN TRY
		SET @StepName = 'Update configuration note'
		SET @StepMessage = 'Update to ConfigID: ['+CAST(@ConfigID AS varchar(25))+'].  The new value for ConfigNote: ['+@NewConfigSetting+'].'
		SET @StepAction = 'UPDATE'
		
			UPDATE
				PowerSTIG.ComplianceConfig
			SET
				ConfigNote = @NewConfigNote
			WHERE
				ConfigID = @ConfigID
				--
				-- Log the action
				--
				EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
		
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH
-- ----------------------------------------------------
-- ConfigSetting and ConfigNote both NULL, return current setting
-- ----------------------------------------------------
	IF @NewConfigSetting IS NULL AND @NewConfigNote IS NULL
		BEGIN
			SELECT
				ConfigProperty,
				ConfigSetting,
				ConfigNote
			FROM
				PowerSTIG.ComplianceConfig
			WHERE
				ConfigID = @ConfigID
		END
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- sproc_InsertConfig
-- ==================================================================
:setvar CREATE_PROC "sproc_InsertConfig"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_InsertConfig
		@NewConfigProperty varchar(256) = NULL,
		@NewConfigSetting varchar(256) = NULL,
		@NewConfigNote varchar(1000) = NULL
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @StepAction varchar(25)
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(2000)
--
SET @NewConfigProperty = LTRIM(RTRIM(@NewConfigProperty))
SET @NewConfigSetting = LTRIM(RTRIM(@NewConfigSetting))
-- ----------------------------------------------------
-- Validate ConfigProperty and ConfigSetting inputs
-- ----------------------------------------------------
	IF @NewConfigProperty IS NULL OR @NewConfigSetting IS NULL
		BEGIN
			PRINT 'Please specify a ConfigProperty and ConfigSetting.  Example: EXEC PowerSTIG.sproc_UpdateConfig ''ThisIsAconfigurationProperty'', ''ThisIsAconfigurationSetting'''
			RETURN
		END

-- ----------------------------------------------------
-- Insert
-- ----------------------------------------------------
	BEGIN TRY
		SET @StepName = 'Update configuration note'
		SET @StepMessage = 'Update to ConfigID: ['+@NewConfigProperty+'].  The new value for ConfigNote: ['+@NewConfigSetting+'].'
		SET @StepAction = 'UPDATE'

		--
		INSERT INTO
			PowerSTIG.ComplianceConfig (ConfigProperty,ConfigSetting,ConfigNote)
		VALUES
			(
			@NewConfigProperty,
			@NewConfigSetting,
			@NewConfigNote
			)
				--
				-- Log the action
				--
				EXEC PowerSTIG.sproc_InsertScanLog
					@LogEntryTitle = @StepName
					,@LogMessage = @StepMessage
					,@ActionTaken = @StepAction
		
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_GetScanQueue
-- ==================================================================
:setvar CREATE_PROC "sproc_GetScanQueue"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerStig.sproc_GetScanQueue 
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
--
	BEGIN TRY
	--
	-- Truncate PowerStig.ScanQueue
	--
		TRUNCATE TABLE PowerStig.ScanQueue
	--
	-- Hydrate ScanQueue
	--
			INSERT INTO PowerStig.ScanQueue (TargetComputer,ComplianceType,QueueStart,QueueEnd)
			SELECT
				T.TargetComputer,
				Y.ComplianceType,
				GETDATE() AS QueueStart,
				'1900-01-01 00:00:00.000' AS QueueEnd
			FROM
				PowerSTIG.ComplianceTargets T
					JOIN PowerSTIG.TargetTypeMap M
						ON T.TargetComputerID = M.TargetComputerID
					JOIN PowerSTIG.ComplianceTypes Y
						ON M.ComplianceTypeID = Y.ComplianceTypeID
			WHERE
				M.isRequired = 1

			--
			-- Return queued scans
			--
			SELECT
				TargetComputer,
				ComplianceType
			FROM
				PowerSTIG.ScanQueue
				
		END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
	
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO

-- ==================================================================
-- sproc_DeleteTargetComputerAndData
-- ==================================================================
:setvar CREATE_PROC "sproc_DeleteTargetComputerAndData"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerStig.sproc_DeleteTargetComputerAndData
					@TargetComputer varchar(255)
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
-- ===============================================================================================
--
DECLARE @TargetComputerID INT
DECLARE @StepName varchar(256)
DECLARE @StepAction varchar(256)
DECLARE @StepMessage varchar(768)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
DECLARE @LogTheUser varchar(256)
--
SET @TargetComputerID = (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = LTRIM(RTRIM(@TargetComputer)))
SET @LogTheUser = (SELECT SUSER_NAME() AS LogTheUser)
SET @StepMessage = ('Delete requested by ['+@LogTheUser+'] for target computer ['+ LTRIM(RTRIM(@TargetComputer))+'].')
--
-- Invalid TargetComputer specified
-- 
	IF @TargetComputerID IS NULL
		BEGIN
			PRINT 'The specified target computer ['+LTRIM(RTRIM(@TargetComputer))+'] was not found.  Please validate.'
			RETURN
		END
--
--
SET @StepName = 'Delete from FindingRepo'
SET @StepAction = 'DELETE'
--
	BEGIN TRY
		DELETE FROM 
			PowerSTIG.FindingRepo
		WHERE
			TargetComputerID = @TargetComputerID
		--
		-- Log the delete
		--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @StepMessage
				,@ActionTaken = @StepAction
		--
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH

--
SET @StepName = 'Delete from TargetTypeMap'
SET @StepAction = 'DELETE'
--
	BEGIN TRY
		DELETE FROM 
			PowerSTIG.TargetTypeMap
		WHERE
			TargetComputerID = @TargetComputerID
		--
		-- Log the delete
		--
		EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @StepMessage
				,@ActionTaken = @StepAction
		--
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH
	


--
SET @StepName = 'Delete from ComplianceCheckLog'
SET @StepAction = 'DELETE'
--
	BEGIN TRY
		DELETE FROM 
			PowerSTIG.ComplianceCheckLog
		WHERE
			TargetComputerID = @TargetComputerID
		--
		-- Log the delete
		--
		EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @StepMessage
				,@ActionTaken = @StepAction
		--
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH

--
SET @StepName = 'Delete from ComplianceTargets'
SET @StepAction = 'DELETE'
--
	BEGIN TRY
		DELETE FROM 
			PowerSTIG.ComplianceTargets
		WHERE
			TargetComputerID = @TargetComputerID
		--
		-- Log the delete
		--
		EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @StepMessage
				,@ActionTaken = @StepAction
		--
	END TRY
	BEGIN CATCH
			SET @StepAction = 'ERROR'
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
			--
			EXEC PowerSTIG.sproc_InsertScanLog
				@LogEntryTitle = @StepName
				,@LogMessage = @ErrorMessage
				,@ActionTaken = @StepAction
	END CATCH
GO
	--
	EXEC sys.sp_addextendedproperty   
	@name = N'DEP_VER',   
	@value = '$(DEP_VER)',  
	@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
	@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- sproc_InsertFindingImport
-- ==================================================================
:setvar CREATE_PROC "sproc_InsertFindingImport"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_InsertFindingImport
				@PScomputerName varchar(255)
				,@VulnID varchar(25) 
				,@FindingSeverity varchar(25) 
				,@StigDefinition varchar(768) 
				,@StigType varchar(50) 
				,@DesiredState varchar(25)
				,@ScanDate datetime
				,@GUID UNIQUEIDENTIFIER
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 07162018 - Kevin Barlett, Microsoft - Initial creation.
--Use example:
--EXEC PowerSTIG.sproc_InsertFindingImport 'SERVER2012','V-26529','medium','Audit - Credential Validation','WindowsServerBaseLine','True','09/17/2018 14:32:42'
-- ===============================================================================================
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
--
BEGIN TRY
	INSERT INTO PowerSTIG.FindingImport
		(
		TargetComputer,
		VulnID,
		FindingSeverity,
		StigDefinition,
		StigType,
		DesiredState,
		ScanDate,
		[GUID],
		ImportDate
		)
	VALUES
		(
		@PScomputerName,
		@VulnID,
		@FindingSeverity,
		@StigDefinition,
		@StigType,
		@DesiredState,
		@ScanDate,
		@GUID,
		GETDATE()
		)
END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- sproc_ProcessFindings
-- ==================================================================
:setvar CREATE_PROC "sproc_ProcessFindings"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_ProcessFindings 
							@GUID varchar(128)
							
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 11012018 - Kevin Barlett, Microsoft - Initial creation.
-- Use example:
-- EXEC PowerSTIG.sproc_ProcessFindings @GUID='242336A7-FA89-4F25-8D9C-97B566AEE3F7'
-- ===============================================================================================
DECLARE @StepName varchar(256)
DECLARE @StepMessage varchar(2000)
DECLARE @StepAction varchar(25)
DECLARE @LastComplianceCheck datetime
DECLARE @ScanID INT
DECLARE @NewTargetID smallint
DECLARE @NewTargetComputer varchar(256)
DECLARE @NewStigType varchar(128)
DECLARE @ErrorMessage varchar(2000)
DECLARE @ErrorSeverity tinyint
DECLARE @ErrorState tinyint
-- =======================================================
-- Validate that GUID not previously processed
-- =======================================================
	IF
		(SELECT isProcessed FROM PowerSTIG.Scans WHERE ScanGUID = @GUID) = 1
			BEGIN
				PRINT 'The provided ['+@GUID+'] has already been processed.  Please verify.  Exiting.'
				SET NOEXEC ON
			END
-- =======================================================
-- Retrieve new GUIDs
-- =======================================================
	BEGIN TRY
		INSERT INTO 
			PowerSTIG.Scans (ScanGUID,ScanDate)
		SELECT DISTINCT
			[GUID]
			,ScanDate
		FROM
			PowerSTIG.FindingImport
		WHERE 
			[GUID] NOT IN (SELECT ScanGUID FROM PowerSTIG.Scans)
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH


-- =======================================================
-- Hydrate StigTypes
-- =======================================================		
	--INSERT INTO
	--	PowerSTIG.ComplianceTypes (ComplianceType,isActive)
	--SELECT DISTINCT
	--	StigType,
	--	1
	--FROM
	--	PowerSTIG.FindingImport
	--WHERE
	--	StigType NOT IN (SELECT ComplianceType FROM PowerSTIG.ComplianceTypes)

-- =======================================================
-- Hydrate ComplianceTargets
-- =======================================================
BEGIN TRY		
	DROP TABLE IF EXISTS #NewComplianceTarget
	
	CREATE TABLE #NewComplianceTarget (
	NewTargetID smallint IDENTITY(1,1) NOT NULL,
	NewTargetComputer varchar(256) NULL,
	NewStigType varchar(128) NULL,
	isProcessed BIT DEFAULT(0))
	--
		INSERT INTO
			#NewComplianceTarget (NewTargetComputer,NewStigType,isProcessed)
		SELECT DISTINCT
			LTRIM(RTRIM(TargetComputer)) AS TargetComputer,
			StigType,
			0 AS isProcessed
		FROM
			PowerSTIG.FindingImport I
		WHERE
			NOT EXISTS 
				(SELECT 1 FROM PowerSTIG.vw_TargetTypeMap M WHERE I.TargetComputer = M.TargetComputer AND I.StigType = M.ComplianceType)
			AND 
				[GUID] = @GUID

	--
	WHILE EXISTS
		(SELECT TOP 1 NewTargetID FROM #NewComplianceTarget WHERE isProcessed = 0)
			BEGIN
				SET @NewTargetID = (SELECT TOP 1 NewTargetID FROM #NewComplianceTarget WHERE isProcessed = 0)
					SET @NewTargetComputer = (SELECT TOP 1 NewTargetComputer FROM #NewComplianceTarget WHERE NewTargetID = @NewTargetID)
					SET @NewStigType = (SELECT NewStigType FROM #NewComplianceTarget WHERE NewTargetID = @NewTargetID)
					--
					--
					--
					IF NOT EXISTS (SELECT TargetComputerID FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @NewTargetComputer)
						BEGIN
								--
								-- New ComplianceTarget detected
								--
									EXEC PowerSTIG.sproc_AddTargetComputer 
											@TargetComputerName = @NewTargetComputer
											,@MemberServer = 0
											,@DomainController = 0 
											,@DotNet = 0
											,@Firefox = 0
											,@Firewall = 0
											,@IIS = 0
											,@Word = 0
											,@Excel = 0
											,@PowerPoint = 0
											,@Outlook = 0
											,@JRE = 0
											,@Sql = 0
											,@Client = 0
											,@DNS = 0
											,@IE = 0
							
						--
						-- Add a ComplianceType for the new ComplianceTarget
						--
						EXEC PowerSTIG.sproc_UpdateServerRoles @TargetComputer = @NewTargetComputer, @ComplianceType = @NewStigType, @UpdateAction = 1
					END
			ELSE	--
				--
				-- ComplianceTarget already exists, but new ComplianceType+ComplianceTarget relationship detected
				--
				IF (SELECT 1 FROM PowerSTIG.ComplianceTargets WHERE TargetComputer = @NewTargetComputer) = 1
						BEGIN			
							--
							-- Add a ComplianceType for the new ComplianceTarget
							--
							EXEC PowerSTIG.sproc_UpdateServerRoles @TargetComputer = @NewTargetComputer, @ComplianceType = @NewStigType, @UpdateAction = 1
				
						END
				--
				-- Set TargetComputer as processed
				-- 
					UPDATE
						#NewComplianceTarget
					SET
						isProcessed = 1
					WHERE
						NewTargetID = @NewTargetID
				
		END					

END TRY
BEGIN CATCH
	    SET @ErrorMessage  = ERROR_MESSAGE()
		SET @ErrorSeverity = ERROR_SEVERITY()
		SET @ErrorState    = ERROR_STATE()
		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
END CATCH	
-- =======================================================
-- Hydrate FindingSeverity
-- =======================================================
	BEGIN TRY
		INSERT INTO
			PowerSTIG.FindingSeverity(FindingSeverity)
		SELECT DISTINCT
			FindingSeverity
		FROM
			PowerSTIG.FindingImport
		WHERE
			FindingSeverity NOT IN (SELECT FindingSeverity FROM PowerSTIG.FindingSeverity)
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
-- =======================================================
-- Hydrate Finding
-- =======================================================
	BEGIN TRY
		INSERT INTO 
			PowerSTIG.Finding(Finding,FindingText)
		SELECT DISTINCT
			LTRIM(RTRIM(VulnID)) AS Finding,
			LTRIM(RTRIM(StigDefinition)) AS FindingText
		FROM 
			PowerSTIG.FindingImport
		WHERE
			LTRIM(RTRIM(VulnID)) NOT IN (SELECT Finding FROM PowerSTIG.Finding)
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
-- =======================================================
-- Hydrate FindingRepo
-- =======================================================
	BEGIN TRY
		INSERT INTO
			--PowerSTIG.FindingRepo (IterationID,TargetComputerID,FindingID,InDesiredState,ComplianceTypeID,FindingCategoryID,CollectTime)
			PowerSTIG.FindingRepo (TargetComputerID,FindingID,InDesiredState,ComplianceTypeID,ScanID)
		SELECT
			T.TargetComputerID,
			F.FindingID,
			CASE
				WHEN I.DesiredState = 'True' THEN 1
				WHEN I.DesiredState = 'False' THEN 0
				END AS InDesiredState,
			C.ComplianceTypeID,
			S.ScanID
		FROM
			PowerSTIG.FindingImport I
				JOIN PowerSTIG.ComplianceTargets T
					ON I.TargetComputer = T.TargetComputer
				JOIN PowerSTIG.Finding F
					ON I.VulnID = F.Finding
				JOIN PowerSTIG.ComplianceTypes C
					ON I.StigType = C.ComplianceType
				JOIN PowerSTIG.Scans S
					ON I.[GUID] = S.ScanGUID
		WHERE
			I.[GUID] = @GUID--'AEC7D71D-3E47-4D81-920C-0408D33984AF'
			AND
			S.isProcessed = 0
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
-- =======================================================
-- Set GUID as processed
-- =======================================================
	BEGIN TRY
		UPDATE
			PowerSTIG.Scans
		SET
			isProcessed = 1
		WHERE
			ScanGUID = @GUID
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
-- =======================================================
-- Update ComplianceCheckLog
-- =======================================================
	BEGIN TRY
SET @ScanID = (SELECT ScanID FROM PowerSTIG.Scans WHERE ScanGUID = @GUID)
SET @LastComplianceCheck = (SELECT GETDATE())
	--
	INSERT INTO
			PowerSTIG.ComplianceCheckLog (ScanID,TargetComputerID,ComplianceTypeID,LastComplianceCheck)
		SELECT DISTINCT
			ScanID,
			TargetComputerID,
			ComplianceTypeID,
			@LastComplianceCheck AS LastComplianceCheck
		FROM
			PowerSTIG.FindingRepo
		WHERE
			ScanID = @ScanID
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
-- =======================================================
-- Update ComplianceCheckLog
-- =======================================================
	BEGIN TRY
			UPDATE
				PowerSTIG.ComplianceTargets
			SET
				LastComplianceCheck = @LastComplianceCheck
			FROM
				PowerSTIG.ComplianceTargets T
					JOIN PowerSTIG.ComplianceCheckLog L
						ON T.TargetComputerID = L.TargetComputerID
			WHERE
				L.ScanID = @ScanID
	END TRY
	BEGIN CATCH
		    SET @ErrorMessage  = ERROR_MESSAGE()
			SET @ErrorSeverity = ERROR_SEVERITY()
			SET @ErrorState    = ERROR_STATE()
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
-- =======================================================
-- Cleanup
-- =======================================================
DROP TABLE IF EXISTS #NewComplianceTarget
 GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- sproc_GetDependencies
-- ==================================================================
:setvar CREATE_PROC "sproc_GetDependencies"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetDependencies 
		@SchemaName varchar(256)=NULL
		--,@ObjectName varchar(256)=NULL
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 11162018 - Kevin Barlett, Microsoft - Initial creation.
-- Use example:
-- EXEC PowerSTIG.sproc_GetDependencies
-- EXEC PowerSTIG.sproc_GetDependencies @SchemaName = 'PowerSTIG'
-- ===============================================================================================

-- ----------------------------------------------------------------------
-- Validation
-- ----------------------------------------------------------------------
--
-- SchemaName
--
IF @SchemaName IS NOT NULL
	BEGIN
		IF
			(SELECT 1 FROM sys.schemas WHERE [name] = LTRIM(RTRIM(@SchemaName))) IS NULL
				BEGIN
					PRINT 'The specified schema: ['+@SchemaName+'] does not appear to exist.  Please validate.  Exiting.'
					SET NOEXEC ON
				END
	END
-- ----------------------------------------------------------------------
-- If exists, drop #DependencyMapping__
-- ----------------------------------------------------------------------
	IF OBJECT_ID('tempdb.dbo.#DependencyMapping__') IS NOT NULL
		DROP TABLE #DependencyMapping__
-- ----------------------------------------------------------------------
-- Hydrate CTE
-- ----------------------------------------------------------------------
;with ObjectHierarchy (Base_Object_Id,Base_Schema_Id,Base_Object_Name,Base_Object_Type,object_id,Schema_Id,[Name],[Type_Desc],[Level],Obj_Path) 
as 
    ( select  so.object_id as Base_Object_Id 
        , so.schema_id as Base_Schema_Id 
        , so.name as Base_Object_Name 
        , so.type_desc as Base_Object_Type
        , so.object_id as object_id 
        , so.schema_id as Schema_Id 
        , so.name 
        , so.type_desc 
        , 0 as Level 
        , convert ( nvarchar ( 1000 ) , N'/' + so.name ) as Obj_Path 
    from sys.objects so 
        left join sys.sql_expression_dependencies ed on ed.referenced_id = so.object_id 
        left join sys.objects rso on rso.object_id = ed.referencing_id 
    where rso.type is null 
        and so.type in ( 'P', 'V', 'IF', 'FN', 'TF' ) 

    UNION ALL 
    select   cp.Base_Object_Id as Base_Object_Id 
        , cp.Base_Schema_Id 
        , cp.Base_Object_Name 
        , cp.Base_Object_Type
        , so.object_id as object_id 
        , so.schema_id as ID_Schema 
        , so.name 
        , so.type_desc 
        , Level + 1 as Level 
        , convert ( nvarchar ( 1000 ) , cp.Obj_Path + N'/' + so.name ) as Obj_Path 
    from sys.objects so 
        inner join sys.sql_expression_dependencies ed on ed.referenced_id = so.object_id 
        inner join sys.objects rso on rso.object_id = ed.referencing_id 
        inner join ObjectHierarchy as cp on rso.object_id = cp.object_id and rso.object_id <> so.object_id 
    where so.type in ( 'P', 'V', 'IF', 'FN', 'TF', 'U') 
        and ( rso.type is null or rso.type in ( 'P', 'V', 'IF', 'FN', 'TF', 'U' ) ) 
        and cp.Obj_Path not like '%/' + so.name + '/%' )   -- prevent cycles n hierarcy
-- ----------------------------------------------------------------------
-- Hydrate temp table
-- ----------------------------------------------------------------------
		SELECT
			Base_Object_Name AS BaseObjectName
			,Base_Object_Type AS BaseObjectType
			,REPLICATE ( '   ' , [Level] ) +'-->'+ [Name] AS IndentedObjectName
			,SCHEMA_NAME ( Schema_Id ) AS SchemaName
			--,SCHEMA_NAME ( Schema_Id ) + '.' + [Name] AS DependencyObjectName
			,[Name] AS DependencyObjectName
			,[Type_Desc] AS DependencyObjectType
			,[Level] 
			,Obj_Path AS ObjectPath
		INTO
			#DependencyMapping__ 
		FROM
			ObjectHierarchy AS p 
		ORDER BY 
			Obj_Path

-- Parameter sniffing below!  Fix when time allows.
-- ----------------------------------------------------------------------
-- Return results for specified schema name
-- ----------------------------------------------------------------------
	IF LTRIM(RTRIM(@SchemaName)) IS NOT NULL-- AND LTRIM(RTRIM(@ObjectName)) IS NULL
		BEGIN
			SELECT
				BaseObjectName,
				BaseObjectType,
				IndentedObjectName,
				SchemaName,
				DependencyObjectName,
				DependencyObjectType,
				[Level],
				ObjectPath
			FROM 
				#DependencyMapping__ 
			WHERE
				SchemaName = LTRIM(RTRIM(@SchemaName))
			ORDER BY 
				ObjectPath
		END

-- ----------------------------------------------------------------------
-- Schema and Object names are NULL.  Return everything.
-- ----------------------------------------------------------------------
	IF LTRIM(RTRIM(@SchemaName)) IS NULL-- AND LTRIM(RTRIM(@ObjectName)) IS NULL
		BEGIN
			SELECT
				BaseObjectName,
				BaseObjectType,
				IndentedObjectName,
				SchemaName,
				DependencyObjectName,
				DependencyObjectType,
				[Level],
				ObjectPath
			FROM 
				#DependencyMapping__
			ORDER BY 
				ObjectPath
		END
-- ----------------------------------------------------------------------
-- Cleanup
-- ----------------------------------------------------------------------
		IF OBJECT_ID('tempdb.dbo.#DependencyMapping__') IS NOT NULL
		DROP TABLE #DependencyMapping__
GO
--
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
-- ==================================================================
-- sproc_GetLastDataForCKL
-- ==================================================================
:setvar CREATE_PROC "sproc_GetLastDataForCKL"
--
PRINT '		Create procedure: $(CREATE_SCHEMA).$(CREATE_PROC)'
GO
CREATE PROCEDURE PowerSTIG.sproc_GetLastDataForCKL
AS
SET NOCOUNT ON
--------------------------------------------------------------------------------- 
-- The sample scripts are not supported under any Microsoft standard support 
-- program or service. The sample scripts are provided AS IS without warranty  
-- of any kind. Microsoft further disclaims all implied warranties including,  
-- without limitation, any implied warranties of merchantability or of fitness for 
-- a particular purpose. The entire risk arising out of the use or performance of  
-- the sample scripts and documentation remains with you. In no event shall 
-- Microsoft, its authors, or anyone else involved in the creation, production, or 
-- delivery of the scripts be liable for any damages whatsoever (including, 
-- without limitation, damages for loss of business profits, business interruption, 
-- loss of business information, or other pecuniary loss) arising out of the use 
-- of or inability to use the sample scripts or documentation, even if Microsoft 
-- has been advised of the possibility of such damages 
---------------------------------------------------------------------------------
-- ===============================================================================================
-- Purpose:
-- Revisions:
-- 01072019 - Kevin Barlett, Microsoft - Initial creation.
-- EXAMPLE: EXEC PowerSTIG.sproc_GetLastDataForCKL
-- ===============================================================================================
--
DROP TABLE IF EXISTS #RecentScan

-- =======================================================
-- Find the most recent scan for each target + compliance type combination
-- =======================================================
			SELECT * INTO #RecentScan FROM (
		SELECT
				T.TargetComputer,
			Y.ComplianceType,
			--TargetComputerID,
			--ComplianceTypeID,
			S.ScanID,
			S.ScanGUID,

			ROW_NUMBER() OVER(PARTITION BY L.ComplianceTypeID,L.TargetComputerID ORDER BY L.LastComplianceCheck DESC) AS RowNum
		
		FROM
			PowerSTIG.ComplianceCheckLog L
				JOIN PowerSTIG.ComplianceTargets T
					ON L.TargetComputerID = T.TargetComputerID
			JOIN PowerSTIG.TargetTypeMap M
				ON T.TargetComputerID = M.TargetComputerID
			JOIN PowerSTIG.ComplianceTypes Y
				ON L.ComplianceTypeID = Y.ComplianceTypeID
			JOIN PowerSTIG.Scans S
				ON S.ScanID = L.ScanID

		--WHERE
		--	TargetComputerID = 46--@TargetComputerID
			) T
		WHERE
			T.RowNum = 1
-- =======================================================
-- Return results
-- =======================================================
	SELECT 
		TargetComputer,
		ComplianceType,
		ScanGUID
	FROM
		#RecentScan
	ORDER BY
		TargetComputer,ComplianceType ASC

-- =======================================================
-- Cleanup
-- =======================================================
DROP TABLE IF EXISTS #RecentScan
GO
EXEC sys.sp_addextendedproperty   
@name = N'DEP_VER',   
@value = '$(DEP_VER)',  
@level0type = N'SCHEMA', @level0name = '$(CREATE_SCHEMA)',  
@level1type = N'PROCEDURE',  @level1name = '$(CREATE_PROC)'; 
GO
PRINT 'End create procedures'
-- ===============================================================================================
-- ===============================================================================================
-- ===============================================================================================
DECLARE @Timestamp DATETIME
SET @Timestamp = (GETDATE())
--
PRINT '///////////////////////////////////////////////////////'
PRINT 'PowerSTIG database object deployment end - '+CONVERT(VARCHAR,@Timestamp, 21)
PRINT '\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\'

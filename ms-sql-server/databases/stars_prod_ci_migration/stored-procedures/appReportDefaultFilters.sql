
            

-- ------------ Write DROP-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
IF  EXISTS (
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID (N'[dbo].[appReportDefaultFilters]') AND 
type = N'P')
DROP PROCEDURE [dbo].[appReportDefaultFilters];
GO
            


            


            

-- ------------ Write CREATE-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
CREATE procedure [dbo].[appReportDefaultFilters] --1058659, 1000003, 1004831
@UserRoleID int,
@UserCampusID int,
@UserTeacherID int,
@ReportType Varchar(5) = '',
@From varchar(20) = '',
@TemplateID	varchar(100) = '',
@AID varchar(100) = '-1',
@UserNetworkID int = -1
AS
set NOCOUNT on
/*
	Revision History:
	----------------------------------------------------------------------------------------------------
	DATE				CREATED BY			DESCRIPTION/REMARKS
	----------------------------------------------------------------------------------------------------
	24-Jun-2013			Athar/Anandan 		Save the user related SIS, Assessment for getting the report.
	12-Aug-2015			Shruthi Shetty		Added Embargo functionality.
	04-Jan-2016			Rahini.J			Modified the query to get DDI report assessment @4.1.0 - HISD Specific
	24-Jan-2017			Nithin				Added AssessmentItem Table for checking Assessments for DDI reports.
	07-Feb-2017			Rahini/Suresh       Modified. Added condtion to default assessment contains standards or not.
	08-Feb-2017			Rahini/Suresh       Modified. Added condtion to get DDI report assessment.
	09-Feb-2017			Nithin/ChinnaReddy  Added @From parameter to procedure for the assessment delete Bug 30857.
	17-Feb-2017         Gayithri            Added condition not to consider AFL and CI assessments.
	23-Mar-2017         Gayithri            Updated to fix Bug 31686. Added StudentGroup UNIon while taking students from roster.
	21-Jun-2016			Mahananda/RamchandraDid Changes related to Princiapl Exchange
	12-Jun-2017			Ram\Manohar			HISD - Legacy Test Search & Data View @5.0v
	14-Jun-2017			Irfan			    Hasdled cascading, HISD - Legacy Test Search & Data View @5.0v
	07-Nov-2017			Manohar				Modified to improve the performance
	19-Oct-2017         Sowjanya C          Modified since @Revisions to Principal's Exchange Form 2
	06-Dec-2017			Manohar				Added Union condition for StudentGroup tables
	05-Jan-2018			Manohar				Modified to improve the performance
	02-Mar-2018			Sai/Manohar			Modified for Task @5.2.0 - Default RosterYear/Roster/School Year/Subject/Assessment.
	04-Apr-2018         Gayithri            Modified to fix bug 40826
	05-APR-2018			ChinnaReddy			Modified to fix Bug 40970 
	25-May-2018         Gayithri            Updated for LMS.
	19-Jun-2018         Mala                Modified to replace Null values
	10-Jul-2018			Manohar				Modified to fix the primary key vaiolation error - added truncate on #RosterStudents table
	18-Jul-2018         Mala                Modified to get SchoolYearName and SchoolYearID from Roster
	09-Aug-2018			ChinnaReddy			Modified to fix Bug 43616
    30-Aug-2018			ChinnaReddy			Modified to fix (Principal's Exchange report issue forward from Nithin)
	09-Oct-2018			Eranna/Lokeshwari	Modified to fix ticket in NYC, i.e., showing no assessments are available message 
	13-Aug-2018			Mala				Modified to fix bug 43491 ( only for HISD)
	01-Nov-2018			Nithin				Modified to fix ticket #29561
	05-Nov-2018			Lokeshwari			Added to restrict result set when called from appAssessDeleteStudentScores procedure
	19-Dec-2018			Manohar				Modified to improve the performance
	10-Jan-2019			Manohar				Modified to fix the ticket #29864 - if RYID = -1 then deleting the data from UserSetting and reinserting it
	18-Jan-2019			Manohar				Modified to fix the ticket #30785 - Converting special characters to xml tags in the assessment names
	30-Jan-2019			Athar/Sravani		Added below code to fix ticket  ZDT 30942
	27-Feb-2019         Khushboo            Modified to increase the size of column AN in @AllTypeValues table variable
	03-May-2019			Srinatha R A		Modified for 7.0 SC-206 PLC Support for Reports task
	03-Jun-2019			Manohar				Added the below code as in SDHC instance all parameters was coming as -1 and this proc was taking more than a minute
	02-Jul-2019			Manohar				Modified to fix getting RosterDataSetID if there is no data in @AllTypeValues table
	29-Aug-2019         Sushmitha           Modified for SC-2549 - Include CurrentStudent Table
	25-Oct-2019			Sravani Balireddy	Modified to SC-3020 Launchpad performance -- Set default procedure performance Improvement
	17-Jan-2020			Abdul Rahiman		Modified for SC-3077-Run Academic Growth Template and show results in new format
	21-Jan-2020			Srinatha R A		Modified for SC-5285 'Check all the procedures for SQL injections task'	
	05-Mar-2020			Manohar				Modified for SC-6030 - Check for PLC assessment
    11-Mar-2020			Prasannakumar		Modified for SC-5050 task getting IncludeNotes value in TypeCodeQGStatus column.
	24-Apr-2020			Sandeep				Modified for SC-6579 task getting IsProgressBuild value in TypeCodeQGStatus column.
	11-Jun-2020			Manohar				Added the below check for if no scored assessments then skip all the queries to improve the procedure performance
											and Added DDITab setting to skip running query if DDITab is not enabled for any instances
	31-Jul-2020         Khushboo            Modified for SC-7100 task 8.1 -Networks - Predefined Reports changes - Add Assessment Level filter in green filter bar
	06-Aug-2020			Srinatha R A		Modifed to include UserNetworkID for @8.1 SC-7099/SC-8021 'Networks - Predefined Reports changes' task
	21-Aug-2020         Khushboo            Modified for SC-8043 task 8.1 'Apply School Level Assessment and Teacher Level Assessment Data View permission to Predefined Reports'		
	08-Sep-2020			Abdul Rahiman		Modfied for @v8.1- SC-7558-Assessment Manager > Dropdown Functions
	19-Oct-2020			Manohar				Modified to improve the performance
	01-Dec-2020         Madhushree K        Modified for [SC-10481] JW - 706457 (P3) - Principal Exchange/Orenda reports not working (Palm Springs)
	15-Dec-2020			ChinnaReddy			Modified for SC-5870 Revise Academic Growth Template UI @v8.2.0
	28-Dec-2020         Madhushree K        Modified for [SC-10389] CPSQA-Reports-In Manage Assessment click on Test Results icon  No assessment is showing  in Reports.
    31-Dec-2020         Khushboo            Modified to fix issue - Even after selecting and saving different assessment as the default assessment in the UserSetting table, we are getting another assessment from procedure - sc-10070
	14-Apr-2021			Prasannakumar		Added @From condition to fix loger issue.
	07-May-2021			Manohar				SC-13858 -- added IsEmbargo column in the temp table
	25-May-2021         Madhushree K        Modified for [SC-14203] Sdhcqa-Reports-In Graduation Requirement tab subtab's are hiding
	08-Sep-2021         Rajesh              Modified for SC-15445 Horizon ACT Student Summary Report for Staff Users (Individual Students)
	20-Oct-2021         Srinatha R A        Modified for SC-16815 Hide Linked Assessments in Hillsborough task
	17-Dec-2021         Rakshith H S        Modified for SC-17752 Incorrect syntax near ')'
	16-Jan-2022			Manohar				SC-18077 - Modified to fix the memory grant issue in HISD
	03-Feb-2022         Manohar/Rajesh      SC-18200 SDHCQA-Reports-Clicking on the Test Result icon user is not navigated to Report Manger
	18-Apr-2022         Manohar/Rajesh      SC-18101 Suiteqa-Reports-Horizon Reports is not loading for particular teacher user
	13-May-2022			Manohar/Rajesh		SC-19871: added rosteryear to restrict the groups to the default year
	22-Jun-2022         Rajesh              SC-20391 HISD and Common Code comparison Gaspedal
	28-jul-2022         Rajesh              SC-20766 Hisdqa-Reports-Test Result icon is not clickable
	29-jul-2022         Rajesh/Prasanna     Modified for SC-19866
	03-Nov-2022         Srinatha R A        Modified to fix SC-22264 DISD: Teacher - No assessment data available customer request.
	10-Jan-2023			Prasannakumar		Modified for SC-16387 Report Year Apply the report year from the District default task
	28-Feb-2023         Madhushree K        Modified for [SC-24018] HISD | IRM: Insert Data into UserSetting Table.
	24-May-2023			Amrut Kumbar		SC-25293: Modified the code to check data for DDI from App setting and Campus settings
	21-Jun-2023			JayaPrakash			Modified to fix SC-25751 improving the performance/blocking issues
	01-Sep-2023			Manohar\Amrut		SC-26631 Commented the SC-16387 changeswhile taking roster data. This should be applied only at assessment query
	06-Sep-2023			JayaPrakash			SC-26408 Added OPTION(RECOMPILE)
	04-Oct-2023         Srinatha R A        Modified for SC-27148 appReportDefaultFilters procedure performance improvement task.
	05-Sep-2024			Amrut Kumbar		SC-29560: SUITEQA | Student Response, Feedback Cards, Standards Analysis, Demographics Profile(By Grade and By Period) and Summary Reports data is not loading
	----------------------------------------------------------------------------------------------------
EXEC [dbo].[appReportDefaultFilters] 1250572,-1,-1,'L','',105
*/	
begin
BEGIN TRY
	--Srinatha Added below codition to handle sql injectios
	if @TemplateID like '%[a-z]%'
	return;

	if @AID like '%[a-z]%'
	return;

	declare @InstanceID int
	declare @UserAccountID int
	declare @DefaultSetting varchar(max) 
	declare @ResultQuery varchar(max)
	declare @RosterQuery varchar(max)
	declare @StudentGrpQuery varchar(max)
	declare @AssessmentFormID int
	declare @AssessmentID int = -1
	declare @ReturnValue int
	declare @AccessLevel char(1)
	declare @Query varchar(max)
	
	declare @RosterDataSetID int
	declare @SubjectID int
	declare @StudentGroup Int = 0
	declare @FDsashBoard bit --Rajesh added For SC-20391
	declare @PLCIsNonRostered char(1) = 'N' -- to check whether the district default value for PLC users is set to access Non Rostered students

	-- Manohar\Rajesh Modified for SC-18101
	declare @PastRosterVisibility xml
	declare @PastYear int --Teacher Access for past Roster Data
	declare @AllowAccess char(1)--Reading from setting(Teacher Access)
	declare @FutureYear char(1) --Assessment Data Access in Current Year Associated with Past Roster(Teacher Access)
	declare @CurrentYear int
	declare @RosterPYear int 
	declare @RosterSubQuery varchar(max)
	declare @ResultQuery1 varchar(max)
 -- Below are the report types that we are handling currently:
 -- P: PreDefinedReport
 -- DDI: DDI
 -- L: Lead4Ward
 -- PE: Principal Exchange
 -- C: Curriculam & Instruction
 -- BRR: BRR
 -- S: SBAC
 -- H: Horizon Report
 -- INTR: Interim Report

	declare @bPreDefinedReport	bit = 0 -- This will contain 1 if Assessment exists for Predefined reports else 0. @since v4.1
	declare @bDDIReport			bit	= 0 -- This will contain 1 if Assessment exists for DDI report else 0. @since v4.1
	declare @bPEReport			bit	= 0 -- This will contain 1 if Assessment exists for Principal's exchange Standard analysis report else 0. @since v4.2
	declare @bLFReport			bit	= 0 -- This will contain 1 if Assessment exists for Lead4Ward report
	declare @bSBACReport		bit	= 0 -- This will contain 1 if Assessment exists for SBAC report
	declare @bBRReport			bit	= 0 -- This will contain 1 if Assessment exists for BRR report
	declare @bCIReport			bit	= 0 -- This will contain 1 if Assessment exists for C&I report
	declare @HReport            bit = 0 -- Rajesh  Modified for SC-15445
	declare @IncLinkedAssess	bit = 0 -- Srinath Added for SC-16815 task
	declare @InterimReport      bit = 0 -- Madhushree K: Modified for [SC-24018]

	--declare @bCheckForOtherAssessments		bit = 0 -- This will contains 1 if Assessment saved in UserSetting does not meet DDI criteria (Standards) and need to check if any other Assessments meets or not.
	
	declare @bFromLMS bit  = case when @AID <> '-1' then 1 else 0 end

    declare @CurrentStudent char(1) = 'N' --Sushmitha : SC-2549 - Include  CurrentStudent Table
	declare @DDITab char(1) = 'N' -- Manohar: added to check whether the DDITab is enabled then only the DDI report queries should run else it will skip 
	declare @RosterYearID int -- Manohar\Rajesh Modified for SC-18101
	declare @ReportSchoolYearID int


	-- Manohar: Added the below code as in SDHC instance all parameters was coming as -1 and this proc was taking more than a minute
	if @UserRoleID = -1
	begin
		select cast(0 as int) as PreDefinedReport
		return;
	end
        --Rajesh added below block  For SC-20391
	--Mala : Added below lines to fix bug 43491
	if(@ReportType ='D')
	begin
		set @ReportType ='P' 
		set @FDsashBoard = 1
	end

	-- Manohar: added the below lines
	if @From = '-1'
		set @From = ''

	-- MS: Align the code properly and folow the coding convensions
	select @InstanceID = UserAccount.InstanceID, @UserAccountID = UserRole.UserAccountID, @AccessLevel = AccessLevelCode
	from UserRole 
	INNER JOIN UserAccount on UserRole.UserAccountID = UserAccount.UserAccountID 
	INNER JOIN Role on Role.RoleID = UserRole.RoleID
	where UserRole.UserRoleID = @UserRoleID

	select @ReportSchoolYearID = Value from InstanceSetting 
	where InstanceID = @InstanceID and SettingID in(select SettingID from Setting where ShortName = 'SchYrR')

	-- Manohar\Rajesh Modified for SC-18101
	set  @PastRosterVisibility = (select top 1  Value 
	from InstanceSetting INS
	inner join Setting S on INS.SettingID = S.SettingID
	where S.Name = 'PastRosterVisibility'
	and InstanceID = @InstanceID)

	select @AllowAccess  = isnull(objNode.value('access[1]', 'char(1)'),'Y'),
			@PastYear     = objNode.value('years[1]', 'int'),
			@FutureYear   = objNode.value('aaccess[1]', 'char(1)')
	from
			@PastRosterVisibility.nodes('/roster') nodeset(objNode)

			if @PastYear is null
			set @PastYear = 2 --Default Year
		else 
			set @PastYear = @PastYear


	 if @ReportType = 'C' and @AccessLevel != 'T'
	 begin
	   set @UserRoleID = (select top 1 UserRoleTeacher.UserRoleID from UserRoleTeacher 
							Join UserRole on UserRole.UserRoleID = UserRoleTeacher.UserRoleID
							Join UserAccount on UserRole.UserAccountID = UserAccount.UserAccountID
							Join Role on Role.RoleID = UserRole.RoleID and Role.ActiveCode = 'A' and AccessLevelCode = 'T'
							where TeacherID = @UserTeacherID and UserAccount.ActiveCode = 'A')

		select @InstanceID = UserAccount.InstanceID, @UserAccountID = UserRole.UserAccountID, @AccessLevel = AccessLevelCode
		from UserRole 
		inner join UserAccount on UserRole.UserAccountID = UserAccount.UserAccountID 
		inner join Role on Role.RoleID = UserRole.RoleID
		where UserRole.UserRoleID = @UserRoleID

		--select @UserRoleID, @UserAccountID,@ReportType
     end

	--Srinatha : Added below changes for SC-16815 task
	if exists(select top 1 1 from InstanceApp IA join App A on A.AppID = IA.AppID 
		where A.Name = 'Linked Assessment' and IA.InstanceID = @InstanceID)
		set @IncLinkedAssess = 1

	-- Manohar: Added the below check for if no scored assessments then skip all the queires to improve the procedure performance
	if not exists (select top 1 1 from Assessment where InstanceID = @InstanceID and ActiveCode = 'A' and HasScores = 1)
	begin
		if('' = @From)select cast(0 as int) as PreDefinedReport,  cast(0 as int) as HReport --Rajesh  Modified for SC-15445
		                                                                                    --Prasanna: Added condition to fix loger issue.
		return;
	end

	declare @SettingXML xml
	select @SettingXML = case when @bFromLMS = 0 then (select top 1 Value from UserSetting Where UserAccountID = @UserAccountID  AND UserRoleID = @UserRoleID AND SettingID = 42) else '' end

	set @DefaultSetting = cast(ISNULL(@SettingXML, '') as varchar(max))
	
	declare @AllTypeValues table (SiNo int identity, RT varchar(10), RYID int, RYN varchar(100), RDSID int, RDSN varchar(100), SYID int, SYN varchar(100), 
								  COLID varchar(100), COLN varchar(100), ALID int, ALN varchar(100), TID int, TN varchar(100), CID int, CN varchar(100),
								  NID int, NN varchar(100), SBID int, SBN varchar(100), AID int, AN varchar(200), URCID int)
	--Khushboo: added NID,NN for SC-8043 task

	if @DefaultSetting <> '' 
	begin
		insert into @AllTypeValues
		select
			objNode.value('RT[1]', 'varchar(100)'), -- ReportType
			objNode.value('RYID[1]', 'int') , -- RosterYearID
			objNode.value('RYN[1]', 'varchar(100)') , -- RosterYearName
			objNode.value('RDSID[1]', 'int') , -- RosterDataSetID
			objNode.value('RDSN[1]', 'varchar(100)') , -- RosterDataSetName
			objNode.value('SYID[1]', 'int') , -- SchoolYearID
			objNode.value('SYN[1]', 'varchar(100)') , -- SchoolYearName
			objNode.value('COLID[1]', 'varchar(100)') , -- CollectionID
			objNode.value('COLN[1]', 'varchar(100)'), -- CollectionName
			objNode.value('ALID[1]', 'int') , -- AssessmentLevel
			objNode.value('ALN[1]', 'varchar(100)') , -- AssessmentLevelName
			objNode.value('TID[1]', 'int') , -- TeacherID
			objNode.value('TN[1]', 'varchar(100)'), -- TeacherName
			objNode.value('CID[1]', 'int') , -- CampusID
			objNode.value('CN[1]', 'varchar(100)'), -- CampusName
			objNode.value('NID[1]', 'int') , -- NetworkID
			objNode.value('NN[1]', 'varchar(100)'), -- NetworkName
			objNode.value('SBID[1]', 'int') , -- SubjectID
			objNode.value('SBN[1]', 'varchar(100)') , -- SubjectName
			objNode.value('AID[1]', 'int') , -- AssessmentID
			objNode.value('AN[1]', 'varchar(200)'), -- AssessmentName	
			objNode.value('URCID[1]', 'int') -- UserRoleCampusID
						
		from 
			@SettingXML.nodes('/Data/Type') nodeset(objNode)

		-- Manohar: Modified to fix the ticket #29864 - added the below line of code
		if exists (select top 1 1 from @AllTypeValues where RT = 'P' and (RYID = -1 or RYID = 0) )
			delete from @AllTypeValues where RT = 'P'

		if not exists (select top 1 1 from @AllTypeValues where RT = 'P')
		insert into @AllTypeValues
		select  'P', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''

		if not exists (select top 1 1 from @AllTypeValues where RT = 'DDI')
		insert into @AllTypeValues
		select  'DDI', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''

		if not exists (select top 1 1 from @AllTypeValues where RT = 'PE')
		insert into @AllTypeValues
		select  'PE', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''

		if not exists (select top 1 1 from @AllTypeValues where RT = 'S')
		insert into @AllTypeValues
		select  'S', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''

		if not exists (select top 1 1 from @AllTypeValues where RT = 'L')
		insert into @AllTypeValues
		select  'L', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''

		if not exists (select top 1 1 from @AllTypeValues where RT = 'BRR')
		insert into @AllTypeValues
		select  'BRR', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''

	if not exists (select top 1 1 from @AllTypeValues where RT = 'C')
		insert into @AllTypeValues
		select  'C', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''

		if not exists (select top 1 1 from @AllTypeValues where RT = 'H') --Rajesh  Modified for SC-15445
		insert into @AllTypeValues
		select  'H', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''

		--Madhushree K: Modified for [SC-24018]
		if not exists (select top 1 1 from @AllTypeValues where RT = 'INTR')
		insert into @AllTypeValues
		select  'INTR', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''
	
	end
	else
		Begin
			insert into @AllTypeValues
			select  'P', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''
			union all select  'DDI', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''
			union all select  'PE', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''
			union all select  'S', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''
			union all select  'L', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''
			union all select  'BRR', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''
			union all select  'C', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','',''
			union all select  'H', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','','' --Rajesh  Modified for SC-15445
			union all select  'INTR', '' , '', '', '', '', '' ,'' ,'' ,'' ,'' ,'' ,'','' ,'' ,'','' ,'' ,'','','','' --Madhushree K: Modified for [SC-24018]
		End

	create table #HasAssessData (Value int PRIMARY KEY)
	create table #StdList (StudentID int PRIMARY KEY)
	create table #Studentclass (StudentID int PRIMARY KEY)
	create table #RosterStudents (StudentID int primary key)
	Create table #PLCIDs (PLCID int primary key)

	-- set the roster data set while will be used inside Roster query
	if @ReportType != '' and @bFromLMS = 0
		select @RosterDataSetID = isnull(RDSID, -1), @AssessmentID = AID, @SubjectID = SBID from @AllTypeValues where RT = @ReportType
	-- Manohar: Modified to fix getting RosterDataSetID if there is no data in @AllTypeValues table
	if @RosterDataSetID = -1 or isnull(@RosterDataSetID, 0) = 0
		select @RosterDataSetID = RosterdataSetID from RosterDataSet where IsDefault = 1 and InstanceID = @InstanceID
		
	 
	select @RosterYearID =  SchoolYearID from  Rosterdataset where IsDefault = 1 and InstanceID = @InstanceID --Manohar/Rajesh added for SC-18101 


	-- Manohar\Rajesh Modified for SC-18101
	select @CurrentYear =  SchoolYearID from  Rosterdataset where IsDefault = 1 and InstanceID = @InstanceID

	select @RosterPYear = try_cast(COALESCE(US.Value, CS.Value, NS.Value, INS.Value) as int)
							  from  Setting S     
							  join InstanceSetting INS on S.SettingID =  INS.SettingID
                              left outer join NetworkSetting NS ON S.SettingID = NS.SettingID  and INS.SortOrder = NS.SortOrder and  NetworkID = @UserNetworkID							  
							  left outer join CampusSetting CS ON S.SettingID = CS.SettingID  and INS.SortOrder = CS.SortOrder and  CampusID = @UserCampusID 
							  left outer join UserSetting US ON S.SettingID = US.SettingID  and  INS.SortOrder = US.SortOrder and  UserAccountID = @UserAccountID  
							  where InstanceID = @InstanceID and S.ShortName in ('RstrVU')



	--Sravani Balireddy: Modified below to check whether the district user is having any UserRole restrictions or not	
	declare @DistictValue bit = 0
	 		
	-- set the roster query and this will be used while checking every report type
	
	--Sushmitha : SC-2549 - Include CurrentStudent Table
	select @CurrentStudent = Value from InstanceSetting join Setting on Setting.SettingID = InstanceSetting.SettingID 
	where Setting.ShortName = 'CurrStutbl' and InstanceID = @InstanceID 

	--SC-25293: Added the below code to check data for DDI from App setting and Campus settings
	if exists (select top 1 1 from [dbo].[appfnCheckCampusApp](@InstanceID, 'DDI', '-1', @UserCampusID))
	set @DDITab = 'Y'
	--select @DDITab = Value from InstanceSetting join Setting on Setting.SettingID = InstanceSetting.SettingID  
	--where Setting.ShortName = 'DDITab' and InstanceID = @InstanceID

	--Srinatha: Added below code to include NetworkID and to restrict calling of below function for @8.1 SC-7099/SC-8021 'Networks - Predefined Reports changes' task
	declare @appFnReportUserData varchar(max) = ''

	if @AccessLevel in ('A', 'D', 'N') or 
		(exists (select top 1 1 from UserRoleGrade where UserRoleID = @UserRoleID)) or 
		(exists (select top 1 1 from UserRoleStudentGroup where UserRoleID = @UserRoleID) )
	set @appFnReportUserData = (select dbo.appFnReportUserData (@UserRoleID, @UserNetworkID))

	-- Manohar: just uncomment the below query for SC-1645 - Data access: Non-rostered students @7.1 release 
    select @PLCIsNonRostered = value from InstanceSetting join Setting on Setting.SettingID = InstanceSetting.SettingID where Setting.ShortName = 'PLCNonRstr'
	and InstanceID = @InstanceID

	if @appFnReportUserData = '' 
		and @UserCampusID = -1
		and @AccessLevel = 'D'
		and (select IsDefault from dbo.RosterDataset where RosterDatasetID = @RosterDataSetID) = 1
		and (select count(*) from dbo.UserRoleStudentGroup where UserRoleID = @UserRoleID) = 0
		begin	
			if( @CurrentStudent = 'Y')
				set @RosterQuery = ' insert into #RosterStudents select distinct StudentID from CurrentStudent ' 
			else
			set @DistictValue = 1
	end
	else
	begin
		set @RosterQuery = ' insert into #RosterStudents select distinct StudentClass.StudentID from '
			+ 'StudentClass Join Class on Class.ClassID = StudentClass.ClassID AND StudentClass.IsCurrent = 1'
			+' INNER JOIN TeacherClass on Class.ClassID = TeacherClass.ClassID AND TeacherClass.IsCurrent = 1 '					
			+(case when (select TOP 1 1 from UserRoleStudentGroup where UserRoleID = @UserRoleID) = 1 then 
				' INNER JOIN StudentGroupStudent on StudentClass.StudentID = StudentGroupStudent.StudentID ' else '' end)
			+ @appFnReportUserData					
			+' where Class.RosterDataSetID = '+ CAST(@RosterDatasetID as varchar)					
			+ case when @UserCampusID = '-1'  then '' else ' and Class.CampusID = ' + CAST(@UserCampusID as varchar)  end
			+ case when @UserTeacherID = '-1'  then '' else ' and TeacherClass.TeacherID = ' + CAST(@UserTeacherID as varchar)  end 
		
	/*set @StudentGrpQuery = ' insert into #RosterStudents
			select distinct StudentGroupStudent.StudentID from StudentGroup JOIN StudentGroupStudent  on                   
			StudentGroupStudent.StudentGroupID = StudentGroup.StudentGroupID 
			where InstanceID = ' + CAST(@InstanceID as varchar(10)) + ' AND StudentGroup.PublicRestrictToSIS = 0 and (StudentGroup.CreatedBy = ' + CAST(@UserAccountID as varchar(10)) + ' OR StudentGroup.PrivacyCode = 3 ) 
			AND StudentGroup.ActiveCode = ''A'' and SchoolYearID = ' + CAST(@RosterYearID as varchar(10)) -- SC-19871: added rosteryear to restrict to the default year
			+ ' union
			select distinct StudentGroupStudent.StudentID from StudentGroup JOIN StudentGroupStudent  on                   
			StudentGroupStudent.StudentGroupID = StudentGroup.StudentGroupID 
			LEFT JOIN StudentGroupConsumer on StudentGroup.StudentGroupID = StudentGroupConsumer.StudentGroupID                   
			where InstanceID = ' + CAST(@InstanceID as varchar(10)) + ' AND StudentGroup.PublicRestrictToSIS = 0 and       
			(StudentGroup.privacyCode = 2 AND StudentGroupConsumer.UserAccountID = ' + CAST(@UserAccountID as varchar(10)) + ' ) 
			AND StudentGroup.ActiveCode = ''A'' and SchoolYearID = ' + CAST(@RosterYearID as varchar(10)) -- SC-19871: added rosteryear to restrict to the default year
			+ ' except
		select StudentID from #RosterStudents ' 	*/

		--Srinatha : Commented above block and added below code to read correct Student groups to fix SC-22264 customer ticket.
		create table #UserStudentGroups (StudentGroupID int primary key, PublicRestrictToSIS bit)  
		insert into #UserStudentGroups(StudentGroupID, PublicRestrictToSIS)
		select StudentGroupid, PublicRestrictToSIS from dbo.appfnGetUserStudentGroups(@InstanceID, @UserAccountID, @UserCampusID, @UserNetworkID, @RosterYearID) 

		set @StudentGrpQuery = ' insert into #RosterStudents
			select distinct SGS.StudentID 
			from dbo.#UserStudentGroups SG
			join dbo.StudentGroupStudent  SGS with (nolock) on SGS.StudentGroupID = SG.StudentGroupID
			where SG.PublicRestrictToSIS = 0  
			except
			select StudentID from #RosterStudents ' 					
	end				

	--Sravani Balireddy :Moved this code here to check PLC permissions
	--Srinatha: added below code for 7.0 SC-206 PLC Support for Reports task
	declare @AssPLCID int
	declare @HavePLC bit = 0
	declare @IsPLCRolePerm bit = 0
	declare @OTName varchar(200)

	declare @PLCpermissions table (OTName varchar(100))   

	insert into @PLCpermissions
	select ObjectType.Name from UserRole
	join RolePermission on UserRole.RoleID = RolePermission.RoleID
	join Permission on Permission.PermissionID = RolePermission.PermissionID
	join ObjectType on ObjectType.ObjectTypeID = Permission.ObjectTypeID
	join Operation on Operation.OperationID = Permission.OperationID
	where Operation.Name = 'View' and UserRole.UserRoleID = @UserRoleID and isnull(RolePermission.ScopeCode,'A') = 'A'  --Rajesh/Prasanna Modified for SC-19866

	if exists(select top 1 1 from @PLCpermissions)
		set @IsPLCRolePerm = 1

	--Sravani Balireddy :Collecting all the PLCIDs with PLC permissions
	if @IsPLCRolePerm = 1
	begin
		insert into #PLCIDs
		select distinct PLCID from PLCUser where userAccountID = @UserAccountID
	end
		
	if @DDITab = 'Y' and (@ReportType = '' or @ReportType = 'DDI') -- DDI tab check\Start
	begin		
		set @AssessmentID = -1	
		-- set the roster data set while will be used inside Roster query
		select @AssessmentID = AID, @SubjectID = SBID from @AllTypeValues where RT = 'DDI'

		-- Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup 
		-- and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1
		if exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID and PLCID in (select PLCID from #PLCIDs)) and @PLCIsNonRostered = 'Y' 
			set @DistictValue = 1

		--Sravani Balireddy : these queries should not run for District user without Userrole restrictions
		if(@DistictValue = 0)
		begin
			print @RosterQuery
			exec(@RosterQuery)

			exec (@StudentGrpQuery)	--Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test.

			--Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942
			-- 19-Oct-2020: Manohar - Modified to improve the performance -- added with (nolock) on testattempt table
			if not exists (select top 1 1 from #RosterStudents where exists (select top 1 1 from TestAttempt with (nolock) where StudentID = #RosterStudents.StudentID))
			truncate table #RosterStudents

			-- if there are no students from the default roster for the user then check in all other rosters
			if @ReportType = '' and not exists (select top 1 1 from #RosterStudents)
			begin
				set @RosterQuery = ' insert into #RosterStudents select distinct StudentClass.StudentID from '
					+ 'StudentClass Join Class on Class.ClassID = StudentClass.ClassID AND StudentClass.IsCurrent = 1'
					+' INNER JOIN TeacherClass on Class.ClassID = TeacherClass.ClassID AND TeacherClass.IsCurrent = 1 '					
					+(case when (select TOP 1 1 from UserRoleStudentGroup where UserRoleID = @UserRoleID) = 1 then 
						' INNER JOIN StudentGroupStudent on StudentClass.StudentID = StudentGroupStudent.StudentID ' else '' end)
					+ @appFnReportUserData				
					+' where 1 = 1 '				
					+ case when @UserCampusID = '-1'  then '' else ' and Class.CampusID = ' + CAST(@UserCampusID as varchar)  end
					+ case when @UserTeacherID = '-1'  then '' else ' and TeacherClass.TeacherID = ' + CAST(@UserTeacherID as varchar)  end

				exec(@RosterQuery)

				--Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942
				if not exists (select top 1 1 from #RosterStudents where exists (select top 1 1 from TestAttempt with (nolock) where StudentID = #RosterStudents.StudentID))
				truncate table #RosterStudents
			end

			--Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue.
			-- insert student group students (if any)
			--if not exists (select top 1 1 from #RosterStudents)
			--exec(@StudentGrpQuery)
	    end

		-- check the current assessment has valid scores for the user
		if (exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID  and HasScores = 1 and ActiveCode = 'A') and (select dbo.[fn_EmbargoGetEmbargoStatus](@AssessmentID, @UserRoleID, @UserAccountID)) = 0 )
		begin
			--Sravani Balireddy : Considering Assessment without checking Rosterstudents for District user without Userrole restrictions
			if(@DistictValue = 1)
			begin
				truncate table #HasAssessData
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID
			end
			else
			begin
				truncate table #HasAssessData
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join #RosterStudents RS on TestAttempt.StudentID = RS.StudentID 
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID
			end

		end

		-- run the below only when it is called from Launchpad page
		-- if the current assessment is not exists then check for other assessment for the user
		if @ReportType = '' and not exists(select top 1 1 from #HasAssessData)
		begin				
			-- 19-Oct-2020: Manohar - Modified to improve the performance -- added IsEmbargoed column to avoid assessments that are not embargoed passing to the embargo functions
			create table #tmpDDIAssessment(AssessmentID int primary key, IsEmbargoed bit default 0)
			
			--Sravani Balireddy :Modified to add the PLC Assessments
			set @ResultQuery = ' insert into #tmpDDIAssessment (AssessmentID, IsEmbargoed)   
			select Distinct Assessment.AssessmentID, Assessment.IsEmbargoed From Assessment where Assessment.ActiveCode = ''A'' and Assessment.InstanceID = '+CAST(@InstanceID  as varchar) + ' AND Assessment.IsAFL = 0 AND Assessment.CIStatusCode != ''C'' '

			if @AccessLevel = 'D' OR @AccessLevel = 'A' OR @AccessLevel = 'C' OR @AccessLevel = 'T' OR @AccessLevel = 'N'
				set @ResultQuery += ' AND ( LevelCode = ''D'''
			if @AccessLevel = 'N' --Srinatha: added Network assessment code for @8.1 SC-7099/SC-8021 'Networks - Predefined Reports changes' task
				set @ResultQuery += ' OR (LevelCode = ''N'' And LevelOwnerID = ' + cast(@UserNetworkID as varchar(10)) + ')'
			if @AccessLevel = 'C' OR @AccessLevel = 'T'
				set @ResultQuery += ' OR (LevelCode = ''C'' And LevelOwnerID = ' + CAST(@UserCampusID as varchar) + ')'
									+ ' OR ( LevelCode = ''N'' And exists (select top 1 1 from NetworkCampus where NetWorkID = LevelOwnerID and CampusID = '+ cast(@UserCampusID as varchar(15)) + '))'
			if @AccessLevel = 'T'
				set @ResultQuery += ' OR (LevelCode = ''U'' And LevelOwnerID = ' + CAST(@UserAccountID as varchar) + ')'
				if @AccessLevel in ('D', 'A','C','T', 'N')
			set @ResultQuery += ')'
			set @ResultQuery += ' and (PLCID is null or PLCID in (select PLCID from #PLCIDs))' --Sravani Balireddy :Collecting all Non PLC Assessments

			print @ResultQuery
			exec (@ResultQuery)			

			update #tmpDDIAssessment set IsEmbargoed = IsEmb From #tmpDDIAssessment tmpA
			Join (select AssessmentID, dbo.[fn_EmbargoGetEmbargoStatus](AssessmentID, @UserRoleID, @UserAccountID) IsEmb from #tmpDDIAssessment) tmpB On tmpA.AssessmentID = tmpB.AssessmentID
			where IsEmbargoed = 1 -- 19-Oct-2020: Manohar - Modified to improve the performance -- added Embargo condition
	
			delete from #tmpDDIAssessment where IsEmbargoed = 1

			--Sravani Balireddy : Considering Assessment without checking Rosterstudents for District user without Userrole restrictions
			if(@DistictValue = 1)
				insert into #HasAssessData 
				select distinct AssessmentForm.AssessmentFormID from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join #tmpDDIAssessment tAss on tAss.AssessmentID = AssessmentForm.AssessmentID
			else
				insert into #HasAssessData 
				select distinct AssessmentForm.AssessmentFormID from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join #tmpDDIAssessment tAss on tAss.AssessmentID = AssessmentForm.AssessmentID
				--Join #RosterStudents on TestAttempt.StudentID = #RosterStudents.StudentID
				-- 19-Oct-2020: Manohar - Modified to improve the performance -- changed to exists
				where exists (select top 1 1 from #RosterStudents where StudentID = TestAttempt.StudentID)

			-- if none of the assessments statisfies the DDI assessment condition then delete the record from #HasAssessData
			if not exists 
			(
				select top 1 1 from #HasAssessData AF join ScoreTopic ST on AF.Value = ST.AssessmentFormID where ST.TypeCode = 'T'
				union
				select top 1 1 from #HasAssessData t join AssessmentItem AI with (nolock) on t.Value = AI.AssessmentFormID
			)
				-- delete data from #HasAssessData if not exists
				truncate table #HasAssessData
		end
		
		if exists(select top 1 1 from #HasAssessData) -- if exists
		begin			
			set @bDDIReport = 1	
			set @bPreDefinedReport = 1
		end
		else -- if not any assessment exists
		begin
			truncate table #HasAssessData
			delete from @AllTypeValues where RT = 'DDI'
			set @bPreDefinedReport = 0
			set @bDDIReport = 0
		end		
	end -- DDI tab check\end	
	
	-- if it is called from Launchpad and already @bPreDefinedReport is set to 1 then no need to run the below code 
	if (@ReportType = '' and @bPreDefinedReport = 0) or (@ReportType = 'P' and @bFromLMS = 0) -- Predefined tab check\Start
	begin
		truncate table #HasAssessData
		truncate table #RosterStudents
		set @AssessmentID = -1

		-- set the roster data set while will be used inside Roster query
		select @AssessmentID = AID, @SubjectID = SBID from @AllTypeValues where RT = 'P'

		-- Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup 
		-- and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1
		if exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID and PLCID in (select PLCID from #PLCIDs)) and @PLCIsNonRostered = 'Y' 
			set @DistictValue = 1

		--Sravani Balireddy : these queries should not run for District user without Userrole restrictions
		if(@DistictValue = 0)
		begin
			print @RosterQuery
			exec(@RosterQuery)
			
			exec (@StudentGrpQuery)	--Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test.

			--Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942
			if not exists (select top 1 1 from #RosterStudents where exists (select top 1 1 from TestAttempt with (nolock) where StudentID = #RosterStudents.StudentID))
			truncate table #RosterStudents
		
			-- if there are no students from the default roster for the user then check in all other rosters
			if @ReportType = '' and not exists (select top 1 1 from #RosterStudents)
			begin
				set @RosterQuery = ' insert into #RosterStudents select distinct StudentClass.StudentID from '
					+ 'StudentClass Join Class on Class.ClassID = StudentClass.ClassID AND StudentClass.IsCurrent = 1'
					+' INNER JOIN TeacherClass on Class.ClassID = TeacherClass.ClassID AND TeacherClass.IsCurrent = 1 '					
					+(case when (select TOP 1 1 from UserRoleStudentGroup where UserRoleID = @UserRoleID) = 1 then 
						' INNER JOIN StudentGroupStudent on StudentClass.StudentID = StudentGroupStudent.StudentID ' else '' end)
					+ @appFnReportUserData				
					+' where 1 = 1 '				
					+ case when @UserCampusID = '-1'  then '' else ' and Class.CampusID = ' + CAST(@UserCampusID as varchar)  end
					+ case when @UserTeacherID = '-1'  then '' else ' and TeacherClass.TeacherID = ' + CAST(@UserTeacherID as varchar)  end

				exec(@RosterQuery)

				--Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942
				if not exists (select top 1 1 from #RosterStudents where exists (select top 1 1 from TestAttempt with (nolock) where StudentID = #RosterStudents.StudentID))
				truncate table #RosterStudents
			end

			--Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue.
			---- insert student group students (if any)
			--if not exists (select top 1 1 from #RosterStudents)
			--exec(@StudentGrpQuery)		
		end

		-- check the current assessment has valid scores for the user
		if (exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID  and HasScores = 1 and ActiveCode = 'A') AND (select dbo.[fn_EmbargoGetEmbargoStatus](@AssessmentID, @UserRoleID, @UserAccountID)) = 0 )
		begin	
			--Sravani Balireddy : Considering Assessment without checking Rosterstudents for District user without Userrole restrictions
			if(@DistictValue = 1)
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID
			else
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join #RosterStudents RS on TestAttempt.StudentID = RS.StudentID 
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID
		end
		
		-- run the below only when it is called from Launchpad page
		-- if the current assessment is not exists then check for other assessment for the user
		if @ReportType = '' and not exists(select top 1 1 from #HasAssessData)  and @Accesslevel <> 'T' -- Manohar\Rajesh Modified for SC-18101
		begin			
			insert into #HasAssessData 
			select top 1 1 from TestAttempt with (nolock)
			Join #RosterStudents on TestAttempt.StudentID = #RosterStudents.StudentID
		end

		if exists(select top 1 1 from #HasAssessData)			
			set @bPreDefinedReport = 1	
		else
		begin
			truncate table #HasAssessData
			delete from @AllTypeValues where RT = 'P'
			set @bPreDefinedReport = 0
		end
	end -- Predefined tab check\End

	-- it is called from the report tab
	if @ReportType = 'PE' -- Principal Exch tab check\Start
	begin
		truncate table #HasAssessData
		truncate table #RosterStudents
		set @AssessmentID = -1

		-- set the roster data set while will be used inside Roster query
		select @AssessmentID = AID, @SubjectID = SBID from @AllTypeValues where RT = 'PE'

		-- Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup 
		-- and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1
		if exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID and PLCID in (select PLCID from #PLCIDs)) and @PLCIsNonRostered = 'Y' 
			set @DistictValue = 1

		--Sravani Balireddy : these queries should not run for District user without Userrole restrictions
		if(@DistictValue = 0)
		begin
			print @RosterQuery
			exec(@RosterQuery)			
			
			exec (@StudentGrpQuery)	--Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test.		

			--Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942	
			if not exists (select top 1 1 from #RosterStudents where exists (select top 1 1 from TestAttempt with (nolock) where StudentID = #RosterStudents.StudentID))
			truncate table #RosterStudents		

			--Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue.
			-- insert student group students (if any)
			--if not exists (select top 1 1 from #RosterStudents)
			--exec(@StudentGrpQuery)
		end

		-- check the current assessment has valid scores for the user
		if (exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID  and HasScores = 1 and ActiveCode = 'A') AND (select dbo.[fn_EmbargoGetEmbargoStatus](@AssessmentID, @UserRoleID, @UserAccountID)) = 0 )
		begin	
			--Sravani Balireddy : Considering Assessment without checking Rosterstudents for District user without Userrole restrictions
			if(@DistictValue = 1)
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join ScoreTopic on AssessmentForm.AssessmentFormID = ScoreTopic.AssessmentFormID 
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID and ScoreTopic.TypeCode = 'T' 
				group by AssessmentForm.AssessmentID
				having count(distinct ScoreTopic.StandardID) = '5'
			else
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join #RosterStudents RS on TestAttempt.StudentID = RS.StudentID
				join ScoreTopic on AssessmentForm.AssessmentFormID = ScoreTopic.AssessmentFormID 
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID and ScoreTopic.TypeCode = 'T' 
				group by AssessmentForm.AssessmentID
				having count(distinct ScoreTopic.StandardID) = '5'
		end
		
		if exists(select top 1 1 from #HasAssessData)			
			set @bPEReport = 1	
		else
		begin
			truncate table #HasAssessData
			delete from @AllTypeValues where RT = 'PE'
			set @bPEReport = 0
		end
	end -- Principal Exch tab check\End

	-- it is called from the SBAC report tab
	if @ReportType = 'S' -- SBAC tab check\Start
	begin
		truncate table #HasAssessData
		truncate table #RosterStudents
		set @AssessmentID = -1

		-- set the roster data set while will be used inside Roster query
		select @AssessmentID = AID, @SubjectID = SBID from @AllTypeValues where RT = 'S'
		
		-- Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup 
		-- and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1
		if exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID and PLCID in (select PLCID from #PLCIDs)) and @PLCIsNonRostered = 'Y' 
			set @DistictValue = 1

		if(@DistictValue = 0)
		begin		
			print @RosterQuery
			exec(@RosterQuery)

			exec (@StudentGrpQuery)	--Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test.	

			--Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942	
			if not exists (select top 1 1 from #RosterStudents where exists (select top 1 1 from TestAttempt where StudentID = #RosterStudents.StudentID))
			truncate table #RosterStudents	
		
			--Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue.
			-- insert student group students (if any)
			--if not exists (select top 1 1 from #RosterStudents)
			--exec(@StudentGrpQuery)	
		end

		-- check the current assessment has valid scores for the user
		if (exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID  and HasScores = 1 and ActiveCode = 'A') AND (select dbo.[fn_EmbargoGetEmbargoStatus](@AssessmentID, @UserRoleID, @UserAccountID)) = 0 )
		begin	
			if(@DistictValue = 1)
			begin
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join Assessment on Assessment.AssessmentID = AssessmentForm.AssessmentID and Assessment.PublisherExtID = 'SC-SBAC-SUMMATIVE'
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID 
			end
			else
			begin
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join #RosterStudents RS on TestAttempt.StudentID = RS.StudentID
				join Assessment on Assessment.AssessmentID = AssessmentForm.AssessmentID and Assessment.PublisherExtID = 'SC-SBAC-SUMMATIVE'
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID 
			end
		end

		if exists(select top 1 1 from #HasAssessData)			
			set @bSBACReport = 1	
		else
		begin
			truncate table #HasAssessData
			delete from @AllTypeValues where RT = 'S'
			set @bSBACReport = 0
		end
	end -- SBAC tab check\End

	--Rajesh  Modified for SC-15445 Horizon ACT Student Summary Report for Staff Users
	 -- it is called from the Horizon report tab
	 --  Horizon Report tab check\Start
	if @ReportType = 'H' 
	begin

		truncate table #HasAssessData
		truncate table #RosterStudents
		set @AssessmentID = -1

		-- set the roster data set while will be used inside Roster query
		select  @AssessmentID = AID, @SubjectID = SBID from @AllTypeValues where RT = 'H'
		
		
		if exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID and PLCID in (select PLCID from #PLCIDs)) and @PLCIsNonRostered = 'Y' 
			set @DistictValue = 1

		if(@DistictValue = 0)
		begin		
			print @RosterQuery
			exec(@RosterQuery)

			exec (@StudentGrpQuery)		

			
			if not exists (select top 1 1 from #RosterStudents where exists (select top 1 1 from TestAttempt with (nolock) where StudentID = #RosterStudents.StudentID))
			truncate table #RosterStudents	
		
			
		end

		-- check the current assessment has valid scores for the user
		if (exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID  and HasScores = 1 and ActiveCode = 'A') AND (select dbo.[fn_EmbargoGetEmbargoStatus](@AssessmentID, @UserRoleID, @UserAccountID)) = 0 )
		begin
		

			if(@DistictValue = 1)
			begin
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join Assessment on Assessment.AssessmentID = AssessmentForm.AssessmentID and Assessment.SpecialAssessmentTabID = 16 and Assessment.TypeCode = 'P' and Assessment.Activecode = 'A'
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID 
			end
			else
			begin
			    insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join #RosterStudents RS on TestAttempt.StudentID = RS.StudentID
				join Assessment on Assessment.AssessmentID = AssessmentForm.AssessmentID and Assessment.SpecialAssessmentTabID = 16 and Assessment.TypeCode = 'P' and Assessment.Activecode = 'A'
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID 
			end
		end

		if exists(select top 1 1 from #HasAssessData)			
			set @HReport = 1	
		else
		begin
			truncate table #HasAssessData
			delete from @AllTypeValues where RT = 'H'
			set @HReport = 0
		end
	end  --  Horizon Report tab check\End
	-- it is called from the Lead4Ward report tab
	if @ReportType = 'L' -- Lead4Ward tab check\Start
	begin
		truncate table #HasAssessData
		truncate table #RosterStudents
		set @AssessmentID = -1
		declare @L4WMenuXML xml

		create table #TmpAssessmentIDs(AssessmentID int Primary key)
		-- START Done the changes Revise Academic Growth Template UI : ChinnaReddy
		select @L4WMenuXML = Value from InstanceSetting where SettingID = (select SettingID from Setting where Name ='L4WMenuPGM') and InstanceID = @InstanceID
		create table #l4wTemplateTable(TemplateID int Primary key)

		insert into #l4wTemplateTable
		select distinct item newTemplateID from
		(
			select  
			   objNode.value('@ID', 'varchar(max)') TemplateID
			from
			 @L4WMenuXML.nodes('/L4WMenuPGM/L4WSubject/Template') nodeset(objNode)

		) A cross apply dbo.fn_split(TemplateID,',')
		order by newTemplateID asc

		--SC-3077-Run Academic Growth Template and load filter values
		--if @TemplateID <> '' and @TemplateID <> '-1'
		--begin
		-- END Done the changes Revise Academic Growth Template UI : ChinnaReddy
			set @Query = '
			insert into #TmpAssessmentIDs
			select distinct A.AssessmentID from ScoreTopic join ( select distinct LTRS.StandardID
			from [L4WTemplateRow] LTR  
			join [L4WTemplateRowStandard] LTRS on LTR.[L4WTemplateRowID] = LTRS.[L4WTemplateRowID]
			where LTR.[L4WTemplateID] in (select TemplateID from #l4wTemplateTable)
			) SD on SD.StandardID = ScoreTopic.StandardID 
			join AssessmentForm AF on ScoreTopic.AssessmentFormID = AF.AssessmentFormID
			join Assessment A on AF.AssessmentID = A.AssessmentID
			join TXSTAARProgressMeasure TX on TX.AssessmentID = A.AssessmentID
			join AssessmentFamily AFF on AFF.AssessmentFamilyID = A.AssessmentFamilyID
			where isnull(TX.STAARProgressMeasure, '''') <> '''' and isnull(TX.PriorYearPL, '''') <> '''' and 
			A.InstanceID = ' + cast(@InstanceID as varchar) + ' and A.ActiveCode = ''A'' and AFF.Name = ''STAAR'' and AFF.CategoryList = ''STATE''  '

			print @Query
			exec(@Query)
		--end

		-- set the roster data set while will be used inside Roster query
		select @AssessmentID = AID, @SubjectID = SBID from @AllTypeValues where RT = 'L'
		
		-- Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup 
		-- and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1
		if exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID and PLCID in (select PLCID from #PLCIDs)) and @PLCIsNonRostered = 'Y' 
			set @DistictValue = 1

		--SC-3077-Run Academic Growth Template and load filter values		
		if not exists(select top 1 1 from #TmpAssessmentIDs where AssessmentID = @AssessmentID )
		begin
			delete from @AllTypeValues where RT = 'L'
			set @bLFReport = 0
		end
		else
		begin		
		if(@DistictValue = 0)
		begin		
			print @RosterQuery
			exec(@RosterQuery)

			exec (@StudentGrpQuery)	--Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test.		

			--Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942	
			if not exists (select top 1 1 from #RosterStudents where exists (select top 1 1 from TestAttempt with (nolock) where StudentID = #RosterStudents.StudentID))
			truncate table #RosterStudents	
		
		    --Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue.
			-- insert student group students (if any)
			--if not exists (select top 1 1 from #RosterStudents)
			--exec(@StudentGrpQuery)	
		end

		-- check the current assessment has valid scores for the user
		if (exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID  and HasScores = 1 and ActiveCode = 'A') AND (select dbo.[fn_EmbargoGetEmbargoStatus](@AssessmentID, @UserRoleID, @UserAccountID)) = 0 )
		begin
			if(@DistictValue = 1)
			begin	
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join Assessment A on A.AssessmentID = AssessmentForm.AssessmentID and A.AssessmentFamilyID = 123
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID 
			end
			else
			begin
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join #RosterStudents RS on TestAttempt.StudentID = RS.StudentID
				join Assessment A on A.AssessmentID = AssessmentForm.AssessmentID and A.AssessmentFamilyID = 123
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID 
			end
		end

		if exists(select top 1 1 from #HasAssessData)			
			set @bLFReport = 1	
		else
		begin
			truncate table #HasAssessData
			delete from @AllTypeValues where RT = 'L'
			set @bLFReport = 0
		end
		end
	end -- Lead4Ward tab check\End

	-- it is called from the BRR report tab

	if @ReportType = 'BRR' -- BRR tab check\Start
	begin
		truncate table #HasAssessData
		truncate table #RosterStudents
		set @AssessmentID = -1

		-- set the roster data set while will be used inside Roster query
		select @AssessmentID = AID, @SubjectID = SBID from @AllTypeValues where RT = 'BRR'
		
		-- Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup 
		-- and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1
		if exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID and PLCID in (select PLCID from #PLCIDs)) and @PLCIsNonRostered = 'Y' 
			set @DistictValue = 1

		if(@DistictValue = 0)
		begin		
			print @RosterQuery
			exec(@RosterQuery)			
			
			exec (@StudentGrpQuery)	--Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test.				

			--Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942		
			if not exists (select top 1 1 from #RosterStudents where exists (select top 1 1 from TestAttempt with (nolock) where StudentID = #RosterStudents.StudentID))
			truncate table #RosterStudents	

			--Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue.
			-- insert student group students (if any)
			--if not exists (select top 1 1 from #RosterStudents)
			--exec(@StudentGrpQuery)
		end

		-- check the current assessment has valid scores for the user
		if (exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID  and HasScores = 1 and ActiveCode = 'A') AND (select dbo.[fn_EmbargoGetEmbargoStatus](@AssessmentID, @UserRoleID, @UserAccountID)) = 0 )
		begin	
		if(@DistictValue = 1)
			begin	
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join Assessment on Assessment.AssessmentID = AssessmentForm.AssessmentID
				join TagLink on Assessment.AssessmentID = TagLink.ObjectID
				join Tag on Tag.TagID = TagLink.TagID and (Tag.Name in ('FountasAndPinnellT1', 'FountasAndPinnellT2', 'FountasAndPinnellT3')  or Tag.Name like '%BRR%')
				join ObjectType on TagLink.ObjectTypeID = ObjectType.ObjectTypeID and ObjectType.Name = 'Assessment'
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID 
			end
			else
			begin
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join #RosterStudents RS on TestAttempt.StudentID = RS.StudentID
				join Assessment on Assessment.AssessmentID = AssessmentForm.AssessmentID
				join TagLink on Assessment.AssessmentID = TagLink.ObjectID
				join Tag on Tag.TagID = TagLink.TagID and (Tag.Name in ('FountasAndPinnellT1', 'FountasAndPinnellT2', 'FountasAndPinnellT3')  or Tag.Name like '%BRR%')
				join ObjectType on TagLink.ObjectTypeID = ObjectType.ObjectTypeID and ObjectType.Name = 'Assessment'
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID 
			end
		end

		if exists(select top 1 1 from #HasAssessData)			
			set @bBRReport = 1	
		else
		begin
			truncate table #HasAssessData
			delete from @AllTypeValues where RT = 'BRR'
			set @bBRReport = 0
		end
	end -- BRR tab check\End

	-- it is called from the C&I report tab
	if @ReportType = 'C' -- C&I tab check\Start
	begin
		truncate table #HasAssessData
		truncate table #RosterStudents
		set @AssessmentID = -1

		-- set the roster data set while will be used inside Roster query
		select @AssessmentID = AID, @SubjectID = SBID from @AllTypeValues where RT = 'C'
		
		-- Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup 
		-- and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1
		if exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID and PLCID in (select PLCID from #PLCIDs)) and @PLCIsNonRostered = 'Y' 
			set @DistictValue = 1

		if(@DistictValue = 0)
		begin			
			print @RosterQuery
			exec(@RosterQuery)
			
			exec (@StudentGrpQuery)	--Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test.			

			--Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942
			if not exists (select top 1 1 from #RosterStudents where exists (select top 1 1 from TestAttempt with (nolock) where StudentID = #RosterStudents.StudentID))
			truncate table #RosterStudents
		
			--Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue.
			-- insert student group students (if any)
			--if not exists (select top 1 1 from #RosterStudents)
			--exec(@StudentGrpQuery)		
		end

		-- check the current assessment has valid scores for the user
		if (exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID  and HasScores = 1 and ActiveCode = 'A') AND (select dbo.[fn_EmbargoGetEmbargoStatus](@AssessmentID, @UserRoleID, @UserAccountID)) = 0 )
		begin	
			if(@DistictValue = 1)
			begin	
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join Assessment on Assessment.AssessmentID = AssessmentForm.AssessmentID
				where TestAttempt.IsValid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and (Assessment.CIStatusCode in ('C') or Assessment.IsAFL = 1) 
				and AssessmentForm.SubjectID = @SubjectID 
			end
			else
			begin
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join #RosterStudents RS on TestAttempt.StudentID = RS.StudentID
				join Assessment on Assessment.AssessmentID = AssessmentForm.AssessmentID
				where TestAttempt.IsValid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and (Assessment.CIStatusCode in ('C') or Assessment.IsAFL = 1) 
				and AssessmentForm.SubjectID = @SubjectID 
			end
		end

		if exists(select top 1 1 from #HasAssessData)			
			set @bCIReport = 1	
		else
		begin
			truncate table #HasAssessData
			delete from @AllTypeValues where RT = 'C'
			set @bCIReport = 0
		end
	end -- C&I tab check\End

	-- two cases: The below block will run
	-- 1. when it is called from Launchpad and no assessments establsihed for DDI or PreDefined )
	-- 2. when it is called from the report tab and existing Assessment doesn't satisfy the report rules

	--Madhushree K: Added for [SC-24018]
	--Interim Report check START
	if @ReportType = 'INTR' 
	begin

		truncate table #HasAssessData
		truncate table #RosterStudents
		set @AssessmentID = -1

		select @AssessmentID = AID, @SubjectID = SBID from @AllTypeValues where RT = 'INTR'	

		if exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID and PLCID in (select PLCID from #PLCIDs)) and @PLCIsNonRostered = 'Y' 
			set @DistictValue = 1

		if(@DistictValue = 0)
		begin		
			print @RosterQuery
			exec(@RosterQuery)

			exec (@StudentGrpQuery)	
			
			if not exists (select top 1 1 from #RosterStudents where exists (select top 1 1 from TestAttempt with (nolock) where StudentID = #RosterStudents.StudentID))
			truncate table #RosterStudents	
	
		end

		-- check the current assessment has valid scores for the user
		if (exists(select top 1 1 from Assessment where AssessmentID = @AssessmentID  and HasScores = 1 and ActiveCode = 'I') AND (select dbo.[fn_EmbargoGetEmbargoStatus](@AssessmentID, @UserRoleID, @UserAccountID)) = 0 )
		begin

			if(@DistictValue = 1)
			begin
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join Assessment on Assessment.AssessmentID = AssessmentForm.AssessmentID
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID 
			end
			else
			begin
				insert into #HasAssessData 
				select distinct top 1 1 from TestAttempt with (nolock)
				Join AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID
				join #RosterStudents RS on TestAttempt.StudentID = RS.StudentID
				join Assessment on Assessment.AssessmentID = AssessmentForm.AssessmentID
				where TestAttempt.Isvalid = 1 and AssessmentForm.AssessmentID = @AssessmentID
				and AssessmentForm.SubjectID = @SubjectID 
			end
		end

		if exists(select top 1 1 from #HasAssessData)			
			set @InterimReport = 1	
		else
		begin
			truncate table #HasAssessData
			delete from @AllTypeValues where RT = 'INTR'
			set @InterimReport = 0
		end
	end
	--Interim Report check END

	-- Madhushree K: Modified for [SC-24018]
	if (@ReportType != '' and @bPreDefinedReport = 0 and @bDDIReport = 0 and @bLFReport = 0 and @bSBACReport = 0 and @Hreport = 0 and @bPEReport = 0 and @bBRReport = 0
				and @bCIReport = 0 and @InterimReport = 0)
	begin
		create table #RosterInfo (SchoolYearID int, SchoolYearName varchar(200), RosterDataSetID int, Name varchar(200), Isdefault bit)
		create table #AssessmentFormInfo (AssessmentFormID int primary key)
		create table #TestAttempt (StudentID int PRIMARY KEY)		
				
		Create Table #tmpAssessments(AssessmentID int primary key, IsEmbargoed bit)

		if exists(select top 1 1 from Assessment where AssessmentID = @AID and PLCID in (select PLCID from #PLCIDs)) and @PLCIsNonRostered = 'Y'  --Madhushree K : Added for [SC-10389]
			set @DistictValue = 1

		if @ReportType = 'L'
		begin
			create table #tmpAFIDs(AssessmentFormID int Primary key)

			set @Query = '
			insert into #tmpAFIDs
			select distinct AssessmentformID from ScoreTopic join ( select distinct LTRS.StandardID
			from [L4WTemplateRow] LTR  
			join [L4WTemplateRowStandard] LTRS on LTR.[L4WTemplateRowID] = LTRS.[L4WTemplateRowID]
			where LTR.[L4WTemplateID] in (select TemplateID from #l4wTemplateTable) -- Modified for SC-5870 Revise Academic Growth Template UI @v8.2.0
			) SD on SD.StandardID = ScoreTopic.StandardID '

			print @Query
			exec(@Query)
		end

		--Sravani Balireddy : Modified to add the PLC Assessments
		if(@DistictValue = 1)
		begin
			-- 19-Oct-2020: Manohar - Modified to improve the performance -- added Embargo column
			---- Manohar\Rajesh Modified for SC-18101 added @AccessLevel case condition
			set @ResultQuery = ' Insert into #tmpAssessments (AssessmentID, IsEmbargoed)
			select top 1  AssessmentID, IsEmbargoed from(  
			select Distinct Assessment.AssessmentID, Assessment.IsEmbargoed, TestAttempt.TestAttemptID From Assessment  
			inner join AssessmentForm on Assessment.AssessmentID = AssessmentForm.AssessmentID 
			join TestAttempt with (nolock) on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID ' +
			case when @ReportType = 'L' then ' join #tmpAFIDs tAF on tAF.AssessmentformID = Assessmentform.AssessmentformID ' else ''  end +
			(case when @ReportType in ('DDI', 'PE') then ' inner join ScoreTopic ST on AssessmentForm.AssessmentFormID = ST.AssessmentFormID and ST.TypeCode = ''T''' else '' end ) +
			(case when @ReportType = 'BRR' then ' join TagLink on Assessment.AssessmentID = TagLink.ObjectID
			join Tag on Tag.TagID = TagLink.TagID and (Tag.Name in (''FountasAndPinnellT1'', ''FountasAndPinnellT2'', ''FountasAndPinnellT3'') or Tag.Name like ''%BRR%'')
			join ObjectType on TagLink.ObjectTypeID = ObjectType.ObjectTypeID and ObjectType.Name = ''Assessment'' ' else ''  end ) + '
			where '+ case when @ReportType = 'INTR' then 'Assessment.ActiveCode = ''I''' else 'Assessment.ActiveCode = ''A''' end + 
			' and HasScores = 1 and Assessment.InstanceID = '+CAST(@InstanceID  as varchar)
			+ ' and (Assessment.PLCID is null or Assessment.PLCID in (select PLCID from #PLCIDs))'
			--Prasanna : Modified below lines to inlcude "ReportSchoolYearID" setting year assessments also for SC-16387 task 
			+' and (('
			+ case when  @AccessLevel  = 'T' and @FutureYear = 'N' then ' Assessment.SchoolYearID <= ' + cast(@RosterYearID as varchar(10))  else '' end 
			+ case when  @AccessLevel  = 'T' and @FutureYear = 'N' then ' and ' else '' end
			+' Assessment.SchoolYearID between ' + cast((@CurrentYear - @RosterPYear) as varchar(10)) + ' and ' +  cast(@CurrentYear as varchar(10))
			+') or Assessment.SchoolYearID =' + cast(@ReportSchoolYearID  as varchar(10)) + ')'

			--Rajesh replaced  and ( LevelCode = ''D'' )' with Case Condition for SC-20391 			
			set @ResultQuery += ' and RosterDataSetID is not null '	+ case when  @AID <> '-1' and @FDsashBoard = 1  then  '' else  ' and ( LevelCode = ''D'' )' end 
			+ case when @ReportType = 'C' then ' and ( Assessment.IsAFL = 1 or Assessment.CIStatusCode = ''C'' ) ' else '' end
			+ case when @ReportType = 'PE' then 'group by Assessment.AssessmentID , Assessment.IsEmbargoed, TestAttempt.TestAttemptID having count(distinct StandardID) = ''5'' '  else ''  end --Madhushree K : Added Assessment.IsEmbargoed for [SC-10481]
			+ case when @ReportType = 'S' then 'and Assessment.PublisherExtID = ''SC-SBAC-SUMMATIVE'' '  else ''  end
			+ case when @ReportType = 'H' then 'and SpecialAssessmentTabID = 16 and Assessment.TypeCode = ''P'' '  else ''  end --Rajesh  Modified for SC-15445
			+ case when @ReportType = 'L' then 'and Assessment.AssessmentFamilyID = 123 ' else ''  end
			+ case when @bFromLMS = 1 then ' and Assessment.AssessmentID = ' + CAST(@AID as varchar) else ''  end
			+ ' ) tmpA
			cross apply (select dbo.[fn_EmbargoGetEmbargoStatus] (tmpA.AssessmentID,' +cast(@UserRoleID as varchar(100))+',' +cast(@UserAccountID as varchar(100))+') 
						as Embargoed ) X  where Embargoed = 0  
                        order by TestAttemptID desc'
			exec (@ResultQuery)
		end
		else
		begin
			-- SC-13858 -- added IsEmbargo column in the temp table, this was missed
                 	---- Manohar\Rajesh Modified for SC-18101 added @AccessLevel case condition
			--Rajesh for SC-20766 added LevelCode = ''D''
			set @ResultQuery = ' Insert into #tmpAssessments (AssessmentID, IsEmbargoed)   
			select Distinct Assessment.AssessmentID, Assessment.IsEmbargoed From Assessment  
			inner join AssessmentForm on Assessment.AssessmentID = AssessmentForm.AssessmentID ' +
			case when @ReportType = 'L' then ' join #tmpAFIDs tAF on tAF.AssessmentformID = Assessmentform.AssessmentformID ' else ''  end +
			(case when @ReportType in ('DDI', 'PE') then ' inner join ScoreTopic ST on AssessmentForm.AssessmentFormID = ST.AssessmentFormID and ST.TypeCode = ''T''' else '' end ) +
			(case when @ReportType = 'BRR' then ' join TagLink on Assessment.AssessmentID = TagLink.ObjectID
			join Tag on Tag.TagID = TagLink.TagID and (Tag.Name in (''FountasAndPinnellT1'', ''FountasAndPinnellT2'', ''FountasAndPinnellT3'') or Tag.Name like ''%BRR%'')
			join ObjectType on TagLink.ObjectTypeID = ObjectType.ObjectTypeID and ObjectType.Name = ''Assessment'' ' else ''  end ) + '
			where '+ case when @ReportType = 'INTR' then 'Assessment.ActiveCode = ''I''' else 'Assessment.ActiveCode = ''A''' end + 
			' and HasScores = 1 and Assessment.InstanceID = '+CAST(@InstanceID  as varchar)
			+ ' and (Assessment.PLCID is null or Assessment.PLCID in (select PLCID from #PLCIDs))'
			--Prasanna : Modified below lines to inlcude "ReportSchoolYearID" setting year assessments also for SC-16387 task 
			+' and (('
			+ case when  @AccessLevel  = 'T' and @FutureYear = 'N' then ' Assessment.SchoolYearID <= ' + cast(@RosterYearID as varchar(10))  else '' end 
			+ case when  @AccessLevel  = 'T' and @FutureYear = 'N' then ' and ' else '' end
			+' Assessment.SchoolYearID between ' + cast((@CurrentYear - @RosterPYear) as varchar(10)) + ' and ' +  cast(@CurrentYear as varchar(10))
			+') or Assessment.SchoolYearID =' + cast(@ReportSchoolYearID  as varchar(10)) + ')'
/*
			set @ResultQuery += ' and ( LevelCode = ''D'' '
			if @AccessLevel = 'N' --Srinatha: added Network assessment code for @8.1 SC-7099/SC-8021 'Networks - Predefined Reports changes' task
				set @ResultQuery += ' OR (LevelCode = ''N'' And LevelOwnerID = ' + cast(@UserNetworkID as varchar(10)) + ')'
			if @AccessLevel = 'C' OR @AccessLevel = 'T'
				set @ResultQuery += ' OR (LevelCode = ''C'' And LevelOwnerID = ' + CAST(@UserCampusID as varchar) + ')'
									+ ' OR ( LevelCode = ''N'' And exists (select top 1 1 from NetworkCampus where NetWorkID = LevelOwnerID and CampusID = '+ cast(@UserCampusID as varchar(15)) + '))'
			if @AccessLevel = 'T'
				set @ResultQuery += ' OR (LevelCode = ''U'' And LevelOwnerID = ' + CAST(@UserAccountID as varchar) + ')'
			set @ResultQuery += ')'
*/
-- Rajesh Commented Above and Merged bleow blocks from HisD SC-20391
-- Rakshith H S  Modified for SC-17752 Incorrect syntax near  ')' added 'or @AccessLevel = 'A''
+ case when  @AID <> '-1' and @FDsashBoard = 1  then  '' else   
				+ case when   @AccessLevel = 'D'  or @AccessLevel = 'A' then ' and ( LevelCode = ''D'' ' else '' end 
				+ case when   @AccessLevel = 'N' then ' and (LevelCode = ''D'' or ( LevelCode = ''N'' And LevelOwnerID = ' + cast(@UserNetworkID as varchar(10)) + ')' else '' end 
				+ case when @AccessLevel = 'C' OR @AccessLevel = 'T' then
				' and ( LevelCode = ''D'' OR (LevelCode = ''C'' And LevelOwnerID = ' + CAST(@UserCampusID as varchar) + ') OR ( LevelCode = ''N'' And exists (select top 1 1 from NetworkCampus where NetWorkID = LevelOwnerID and CampusID = '+ cast(@UserCampusID as varchar(15)) + ' )) ' else '' end 
				+ case  when @AccessLevel = 'T' then
				' OR (LevelCode = ''U'' And LevelOwnerID = ' + CAST(@UserAccountID as varchar) + ')' else '' end +
				')'  
			 end
			+ case when @ReportType = 'C' then ' and ( Assessment.IsAFL = 1 or Assessment.CIStatusCode = ''C'' ) ' else '' end
			+ case when @ReportType = 'PE' then 'group by Assessment.AssessmentID, Assessment.IsEmbargoed having count(distinct StandardID) = ''5'' '  else ''  end --Madhushree K: Modified for [SC-14203]
			+ case when @ReportType = 'S' then 'and Assessment.PublisherExtID = ''SC-SBAC-SUMMATIVE'' '  else ''  end
			+ case when @ReportType = 'H' then 'and SpecialAssessmentTabID = 16 and Assessment.TypeCode = ''P''  '  else ''  end --Rajesh  Modified for SC-15445
			+ case when @ReportType = 'L' then 'and Assessment.AssessmentFamilyID = 123 ' else ''  end
			+ case when @bFromLMS = 1 then ' and Assessment.AssessmentID = ' + CAST(@AID as varchar) else ''  end
			print (@ResultQuery)
			exec (@ResultQuery)

			update #tmpAssessments set IsEmbargoed = IsEmb
			From #tmpAssessments tmpA
			Join (select AssessmentID, dbo.[fn_EmbargoGetEmbargoStatus](AssessmentID, @UserRoleID, @UserAccountID) IsEmb From #tmpAssessments) tmpB On tmpA.AssessmentID = tmpB.AssessmentID
			where IsEmbargoed = 1 -- 19-Oct-2020: Manohar - Modified to improve the performance -- added Embargo condition
			
			Delete from #tmpAssessments where IsEmbargoed = 1

			--Srinatha : Added below insert while doing performance tuning SC-27148 
			if @AccessLevel <> 'D' or (@AccessLevel = 'D' and @appFnReportUserData <> '')
			begin
				insert into #TestAttempt(StudentID)
				select TMP.StudentID from #tmpAssessments t 	
				INNER JOIN AssessmentForm AF on t.AssessmentID = AF.AssessmentID
				INNER JOIN TestAttempt TMP  with(nolock) on TMP.AssessmentFormID = AF.AssessmentFormID 
				group by TMP.StudentID
			end

			-- SC-18077 -- commented the below code instead using this whole query in the below joins
			--insert into #TestAttempt  
			--select studentid from TestAttempt with (nolock)
			--INNER JOIN AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID 
			----INNER JOIN #tmpAssessments tmpAssess on AssessmentForm.AssessmentID = tmpAssess.AssessmentID 
			--where exists (select top 1 1 from #tmpAssessments where AssessmentID = AssessmentForm.AssessmentID)
			--group by studentid
			---- Manohar\Rajesh Modified for SC-18101 added @AccessLevel case condition
			set @ResultQuery = 'insert into #RosterInfo '
			+' select DISTINCT TOP 1 RosterDataSet.SchoolYearID, SchoolYear.LongName, RosterDataSet.RosterDataSetID, RosterDataSet.Name, RosterDataSet.Isdefault from RosterDataSet'
			+' INNER JOIN Class on RosterDataSet.RosterDataSetID = Class.RosterDataSetID '
			+' INNER JOIN StudentClass with(nolock, forceseek) on Class.ClassID = StudentClass.ClassID AND StudentClass.IsCurrent = 1 '
			+ case when @AccessLevel = 'D' and @appFnReportUserData = '' then '' else 
			' join #TestAttempt T on T.StudentID = StudentClass.StudentID ' end
			+(case when (select TOP 1 1 from UserRoleTeacher where UserRoleID = @UserRoleID) = 1  OR @UserTeacherID <> '-1' then 
				' INNER JOIN TeacherClass on Class.ClassID = TeacherClass.ClassID AND TeacherClass.IsCurrent = 1 ' else '' end)
			+(case when (select TOP 1 1 from UserRoleStudentGroup where UserRoleID = @UserRoleID) = 1 then 
				' INNER JOIN StudentGroupStudent on StudentClass.StudentID = StudentGroupStudent.StudentID ' else '' end)
			+ @appFnReportUserData
			+' INNER JOIN SchoolYear on RosterDataSet.SchoolYearID = SchoolYear.SchoolYearID '
			-- SC-18077 - changed it to original table 
			--Manohar /Rajesh SC-18200 added Testattempt in Exists Condition
			--+' INNER JOIN TestAttempt TMP  with (nolock) on StudentClass.StudentID = TMP.StudentID '
			--+' INNER JOIN AssessmentForm AF on TMP.AssessmentFormID = AF.AssessmentFormID '
			+' where RosterDataSet.IsHidden = 0  AND RosterDataSet.InstanceID = '+ CAST(@InstanceID  as varchar)		

			--+ case when  @AccessLevel  = 'T' then ' and RosterDataset.SchoolYearID between ' 
			--+ cast(case when @AllowAccess = 'Y' then (@RosterYearID - @Pastyear) else (@RosterYearID - 1) end as varchar(10)) 
			--+' and '+ cast(@RosterYearID  as varchar(10))   
			--else ' and RosterDataset.SchoolYearID between ' + cast((@CurrentYear - @RosterPYear) as varchar(10)) +' and '+ cast(@CurrentYear  as varchar(10)) end 

			set @ResultQuery1 = 
			--Srinatha : Commented below block and moved this to #TestAttempt table and used it in JOIN for SC-27148 ticket
			--' and exists (select top 1 1 from #tmpAssessments t '			
			--+' INNER JOIN AssessmentForm AF on t.AssessmentID = AF.AssessmentID '
			--+' INNER JOIN TestAttempt TMP  with (nolock) on TMP.AssessmentFormID = AF.AssessmentFormID where  TMP.StudentID = StudentClass.StudentID ) '
			 case when @UserCampusID = '-1'  then '' else ' and Class.CampusID = ' + CAST(@UserCampusID as varchar)  end
			+ case when @UserTeacherID = '-1'  then '' else ' and TeacherClass.TeacherID = ' + CAST(@UserTeacherID as varchar)  end
			+' ORDER BY RosterDataSet.Isdefault DESC, RosterDataSet.SchoolYearID DESC, RosterDataSet.RosterDataSetID  DESC 
			   OPTION(RECOMPILE)' -- SC-26408 - Added by JayaPrakash as per manohar suggestions

			--Prasanna : Added below code for SC-16387 task to get SchoolYear based on "ReportSchoolYearID" setting
			
			set @RosterSubQuery = @ResultQuery 
			--SC-26631: Commented the below line as we don't need to apply this while taking roster data. This is already applied at assessment query
			--+ ' and RosterDataset.SchoolYearID =' + cast(@ReportSchoolYearID  as varchar(10)) 
			+ @ResultQuery1
			Print @RosterSubQuery
			EXEC (@RosterSubQuery)

			if not exists(select top 1 1 from #RosterInfo)
			begin
				set @RosterSubQuery = @ResultQuery + case when  @AccessLevel  = 'T' then ' and RosterDataset.SchoolYearID between ' 
				+ cast(case when @AllowAccess = 'Y' then (@RosterYearID - @Pastyear) else (@RosterYearID - 1) end as varchar(10)) 
				+' and '+ cast(@RosterYearID  as varchar(10))   
				else ' and RosterDataset.SchoolYearID between ' + cast((@CurrentYear - @RosterPYear) as varchar(10)) +' and '+ cast(@CurrentYear  as varchar(10)) end 
				+ @ResultQuery1

				Print @RosterSubQuery
				EXEC (@RosterSubQuery)
			end

			if not exists(select top 1 1 from #RosterInfo)
			begin
				insert into #StdList
				select  distinct StudentGroupStudent.StudentID from StudentGroup JOIN StudentGroupStudent  on                   
				StudentGroupStudent.StudentGroupID = StudentGroup.StudentGroupID 
				where InstanceID = @InstanceID AND StudentGroup.PublicRestrictToSIS = 0 
				and (StudentGroup.CreatedBy = @UserAccountID OR (StudentGroup.PrivacyCode = 3 and LevelOwnerID is null) or (StudentGroup.PrivacyCode = 3 and LevelOwnerID = @UserCampusID) ) 
				AND StudentGroup.ActiveCode = 'A' 
				union
				select  distinct StudentGroupStudent.StudentID from StudentGroup JOIN StudentGroupStudent  on                   
				StudentGroupStudent.StudentGroupID = StudentGroup.StudentGroupID 
				LEFT JOIN StudentGroupConsumer on StudentGroup.StudentGroupID = StudentGroupConsumer.StudentGroupID                   
				where InstanceID = @InstanceID AND StudentGroup.PublicRestrictToSIS = 0 and        
				(StudentGroup.privacyCode = 2 AND StudentGroupConsumer.UserAccountID = @UserAccountID  ) AND StudentGroup.ActiveCode = 'A' 
			
				--if Exists (select Top 1 1 From #StdList Inner Join #TestAttempt On #TestAttempt.StudentID = #StdList.StudentID)
				-- SC-18077 - commented the above line and added below line since we are using the original testattempt table
				if Exists (	select Top 1 1 from TestAttempt with (nolock)
				INNER JOIN AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID 
				INNER JOIN #tmpAssessments tmpAssess on AssessmentForm.AssessmentID = tmpAssess.AssessmentID 
				where exists (select top 1 1 from #StdList where StudentID = TestAttempt.StudentID))
				begin
					set @StudentGroup = 1;
				end
			end	
		end

		if exists(select top 1 1 from #RosterInfo) OR @StudentGroup = 1 or @DistictValue = 1
		begin
			if(@DistictValue = 0)
			begin
				declare @Result varchar(max) = ''
				declare @AccessCondition varchar(max)
				select @RosterDataSetID = RosterDataSetID from #RosterInfo	

				if @StudentGroup = 0
				begin
					if @appFnReportUserData = '' 
						and @UserCampusID = -1
						and @AccessLevel = 'D'
						and (select IsDefault from dbo.RosterDataset where RosterDatasetID = @RosterDataSetID) = 1
						and (select COUNT(*) from dbo.UserRoleStudentGroup where UserRoleID = @UserRoleID) = 0
						and @CurrentStudent = 'Y'
			
					set @ResultQuery = ' insert into #StudentClass 
						select distinct StudentID from CurrentStudent ' 
				else
					set @ResultQuery = 'insert into #Studentclass ' 
					+' select DISTINCT StudentClass.StudentID from StudentClass '		
						+' INNER JOIN Class on StudentClass.ClassID = Class.ClassID '
						+(case when (select TOP 1 1 from UserRoleTeacher where UserRoleID = @UserRoleID) = 1  OR @UserTeacherID <> '-1' then 
							' INNER JOIN TeacherClass on Class.ClassID = TeacherClass.ClassID AND TeacherClass.IsCurrent = 1  ' else '' end)
						+(case when (select TOP 1 1 from UserRoleStudentGroup where UserRoleID = @UserRoleID) = 1 then 
							' INNER JOIN StudentGroupStudent on StudentClass.StudentID = StudentGroupStudent.StudentID ' else '' end)
						+ @appFnReportUserData
						+' where  StudentClass.IsCurrent = 1 AND Class.RosterDatasetID = ' +  CAST(@RosterDataSetID  as varchar)
						+ (case when @UserCampusID != -1 then ' AND CLASS.CampusID = ' + CAST(@UserCampusID as varchar) else '' end) 
						+ (case when @UserTeacherID = '-1'  then '' else ' and TeacherClass.TeacherID = ' + CAST(@UserTeacherID as varchar)  end)

					exec (@ResultQuery)
				end
				else				
					insert into #Studentclass
					select * from #StdList
			
				set @ResultQuery = ' insert into #AssessmentFormInfo  ' 
					+' select TOP 1 TestAttempt.AssessmentFormID from TestAttempt with (nolock) ' 
					-- SC-18077 moved the below table to exists
					--+' INNER JOIN #Studentclass TMP on TestAttempt.StudentID = TMP.StudentID  '
					+ ' INNER JOIN AssessmentForm on AssessmentForm.AssessmentFormID = TestAttempt.AssessmentFormID '
					+ 'INNER JOIN #tmpAssessments tmpAssess on AssessmentForm.AssessmentID = tmpAssess.AssessmentID '
					+ ' where exists (select top 1 1 from #Studentclass where StudentID = TestAttempt.StudentID)'
					+' ORDER BY TestAttempt.TestAttemptID DESC ' -- SC-18077 using TestAttemptID instead of TestedDate for better performance after discussing with Kallesh and Dale
			
				PRint @ResultQuery
				EXEC (@ResultQuery)	
				select @AssessmentFormID = AssessmentFormID from #AssessmentFormInfo
			
		end
			else
			begin
				--Sravani balireddy : Setting Default Assessment for user District user
				select @AssessmentFormID = (select top 1 AssessmentForm.AssessmentFormID From AssessmentForm  
				join #tmpAssessments T on T.AssessmentID = AssessmentForm.AssessmentID)

				insert into #RosterInfo
				select distinct top 1 RosterDataSet.SchoolYearID, SchoolYear.LongName, RosterDataSet.RosterDataSetID, RosterDataSet.Name, RosterDataSet.Isdefault 
				from Assessment  
				join AssessmentForm on Assessment.AssessmentID = AssessmentForm.AssessmentID 	
				join RosterDataSet on Assessment.RosterDataSetID = RosterDataSet.RosterDataSetID
				join SchoolYear on RosterDataSet.SchoolYearID = SchoolYear.SchoolYearID 
				where RosterDataSet.IsHidden = 0  AND RosterDataSet.InstanceID = @InstanceID and AssessmentFormID = @AssessmentFormID
			end

			if @bFromLMS = 1 
			delete from @AllTypeValues where RT = 'P'

			if @StudentGroup = 0
			Begin

				insert into @AllTypeValues (RT, RYID, RYN, RDSID, RDSN, SYID, SYN, COLID, COLN, ALID, ALN, TID, TN, CID, CN,NID,NN, SBID, SBN, AID, AN, URCID)
				select @ReportType as RT,  (select SchoolYearID from #RosterInfo ) ,  (select SchoolYearName from #RosterInfo ), (select RosterDataSetID from #RosterInfo ),
				(select Name from #RosterInfo ), SchoolYear.SchoolYearID, SchoolYear.LongName, ISNULL(COLID,-1), ISNULL(COLN, '-1'),
				case when 1 = (select top 1 1 from AssessmentFamily where CategoryList = 'STATE' and AssessmentFamilyID = Assessment.AssessmentFamilyID) then cast(1 as varchar(10)) 
				else case when Assessment.LevelCode = 'D' and Assessment.PLCID is null then cast(2 as varchar(10))--Khushboo: added  Assessment.PLCID is null condition for SC-7100 task 
				else case when Assessment.LevelCode = 'N' then cast(3 as varchar(10))--Khushboo: added Network LevelCode for SC-7100 task and incremented ALID for School and Teacher
				else case when Assessment.LevelCode = 'C' then cast(4 as varchar(10))
				else case when Assessment.LevelCode = 'U' then cast(6 as varchar(10)) 
				else case when Assessment.PLCID in (select PLCID from #PLCIDs) then cast(5 as varchar(10)) end --Khushboo: added this case condition for SC-7100 task
				end end end end end , 
				case when 1 = (select top 1 1 from AssessmentFamily where CategoryList = 'STATE' and AssessmentFamilyID = Assessment.AssessmentFamilyID) then 'State'
				else case when Assessment.LevelCode = 'D' and Assessment.PLCID is null then 'District' --Khushboo: added  Assessment.PLCID is null condition for SC-7100 task
				else case when Assessment.LevelCode = 'N' then 'Network'--Khushboo: added Network LevelCode for SC-7100 task 
				else case when Assessment.LevelCode = 'C' then 'School'
				else case when Assessment.LevelCode = 'U' then 'Teacher' 
				else case when Assessment.PLCID in (select PLCID from #PLCIDs) then 'PLC' end --Khushboo: added this case condition for SC-7100 task
				end end end end end, 
				-1, '-1', -1, '-1',-1,'-1',
				InstanceSubject.SubjectID, InstanceSubject.LongName, Assessment.AssessmentID, replace(replace(Assessment.Name, '>', '&amp;gt;'), '<', '&amp;lt;'),  A.URCID -- Manohar: Modified to fix the ticket #30785 - Converting special characters to xml tags in the assessment names
				from Assessment
				inner join AssessmentForm on Assessment.AssessmentID = AssessmentForm.AssessmentID
				inner join InstanceSubject on AssessmentForm.SubjectID = InstanceSubject.SubjectID
				inner join SchoolYear on Assessment.SchoolYearID = SchoolYear.SchoolYearID
				--inner join #RosterInfo on #RosterInfo.SchoolYearID = Assessment.SchoolYearID 
				left join Campus on Campus.CampusID = Assessment.LevelOwnerID
				left join UserAccount on UserAccount.UserAccountID = Assessment.CreatedBy
				left join @AllTypeValues A on A.RT = @ReportType 
				where AssessmentFormID = @AssessmentFormID AND InstanceSubject.InstanceID = @InstanceID
				--Srinatha : Added below Assessment.IsLinked column for SC-16815 task
				and Assessment.IsLinked = case when @IncLinkedAssess = 0 then 0 else Assessment.IsLinked end
			end			
			else 
			begin

				-- Manohar: Modified to fix the ticket #29864 - Assessment.SchoolYearID
				insert into @AllTypeValues (RT, RYID, RYN, RDSID, RDSN, SYID, SYN, COLID, COLN, ALID, ALN, TID, TN, CID, CN,NID,NN, SBID, SBN, AID, AN, URCID )
				select @ReportType as RT, Assessment.SchoolYearID , SchoolYear.LongName, RDS.RosterDataSetID, --SC-29560:Amrut- Added RDS.RosterDataSetID instead taking from #RosterInfo
				RDS.Name, SchoolYear.SchoolYearID, SchoolYear.LongName, ISNULL(COLID,-1), ISNULL(COLN, '-1'), --SC-29560:Amrut- Added RDS.Name instead taking from #RosterInfo
				case when 1 = (select top 1 1 from AssessmentFamily where CategoryList = 'STATE' and AssessmentFamilyID = Assessment.AssessmentFamilyID) then cast(1 as varchar(10)) 
				else case when Assessment.LevelCode = 'D' and Assessment.PLCID is null then cast(2 as varchar(10)) --Khushboo: added  Assessment.PLCID is null condition for SC-7100 task
				else case when Assessment.LevelCode = 'N' then cast(3 as varchar(10))--Khushboo: added Network LevelCode for SC-7100 task and incremented ALID for School and Teacher
				else case when Assessment.LevelCode = 'C' then cast(4 as varchar(10))
				else case when Assessment.LevelCode = 'U' then cast(6 as varchar(10))
				else case when Assessment.PLCID in (select PLCID from #PLCIDs) then cast(5 as varchar(10)) end --Khushboo: added this case condition for SC-7100 task 
				end end end end end , 
				case when 1 = (select top 1 1 from AssessmentFamily where CategoryList = 'STATE' and AssessmentFamilyID = Assessment.AssessmentFamilyID) then 'State'
				else case when Assessment.LevelCode = 'D' and Assessment.PLCID is null then 'District' --Khushboo: added  Assessment.PLCID is null condition for SC-7100 task
				else case when Assessment.LevelCode = 'N' then 'Network'--Khushboo: added Network LevelCode for SC-7100 task
				else case when Assessment.LevelCode = 'C' then 'School'
				else case when Assessment.LevelCode = 'U' then 'Teacher'
				else case when Assessment.PLCID in (select PLCID from #PLCIDs) then 'PLC' end --Khushboo: added this case condition for SC-7100 task
				end end end end end, 
				-1, '-1', -1, '-1',-1,'-1',
				InstanceSubject.SubjectID, InstanceSubject.LongName, Assessment.AssessmentID, replace(replace(Assessment.Name, '>', '&amp;gt;'), '<', '&amp;lt;'), A.URCID -- Manohar: Modified to fix the ticket #30785 - Converting special characters to xml tags in the assessment names
				from Assessment
				inner join AssessmentForm on Assessment.AssessmentID = AssessmentForm.AssessmentID
				inner join InstanceSubject on AssessmentForm.SubjectID = InstanceSubject.SubjectID
				inner join SchoolYear on Assessment.SchoolYearID = SchoolYear.SchoolYearID
				--inner join #RosterInfo on #RosterInfo.SchoolYearID = Assessment.SchoolYearID
				--SC-29560:Amrut- Added RosterDataSet table (When for logged in user, roster students are not available or doesnt have permision but students from student group present)
				inner join RosterDataSet RDS on RDS.SchoolYearID = Assessment.SchoolYearID and isdefault = 1
				left join Campus on Campus.CampusID = Assessment.LevelOwnerID
				left join UserAccount on UserAccount.UserAccountID = Assessment.CreatedBy
				left join @AllTypeValues A on A.RT = @ReportType 
				where AssessmentFormID = @AssessmentFormID AND InstanceSubject.InstanceID = @InstanceID
				--Srinatha : Added below Assessment.IsLinked column for SC-16815 task
				and Assessment.IsLinked = case when @IncLinkedAssess = 0 then 0 else Assessment.IsLinked end
			end

			-- if Predefined Assessment is not set then the below query we set it DDI AssessmentID to Predefined also.
			if @ReportType = 'DDI' and exists (select top 1 1 from @AllTypeValues where RT = 'P' and AID = 0)
			begin
				delete from @AllTypeValues where RT = 'P'
				-- Manohar: Modified to fix the ticket #29864 - Assessment.SchoolYearID
				insert into @AllTypeValues (RT, RYID, RYN, RDSID, RDSN, SYID, SYN, COLID, COLN, ALID, ALN, TID, TN, CID, CN,NID,NN, SBID, SBN, AID, AN, URCID )
				select 'P' as RT, Assessment.SchoolYearID, (select SchoolYearName from #RosterInfo ), (select RosterDataSetID from #RosterInfo),
				(select Name from #RosterInfo), SchoolYear.SchoolYearID, SchoolYear.LongName,  ISNULL(COLID,-1), ISNULL(COLN, '-1'),
				case when 1 = (select top 1 1 from AssessmentFamily where CategoryList = 'STATE' and AssessmentFamilyID = Assessment.AssessmentFamilyID) then cast(1 as varchar(10)) 
				else case when Assessment.LevelCode = 'D' and Assessment.PLCID is null then cast(2 as varchar(10)) --Khushboo: added  Assessment.PLCID is null condition for SC-7100 task 
				else case when Assessment.LevelCode = 'N' then cast(3 as varchar(10))--Khushboo: added Network LevelCode for SC-7100 task and incremented ALID for School and Teacher
				else case when Assessment.LevelCode = 'C' then cast(4 as varchar(10))
				else case when Assessment.LevelCode = 'U' then cast(6 as varchar(10)) 
				else case when Assessment.PLCID in (select PLCID from #PLCIDs) then cast(5 as varchar(10)) end --Khushboo: added this case condition for SC-7100 task 
				end end end end end , 
				case when 1 = (select top 1 1 from AssessmentFamily where CategoryList = 'STATE' and AssessmentFamilyID = Assessment.AssessmentFamilyID) then 'State'
				else case when Assessment.LevelCode = 'D' and Assessment.PLCID is null then 'District' --Khushboo: added  Assessment.PLCID is null condition for SC-7100 task
				else case when Assessment.LevelCode = 'N' then 'Network'--Khushboo: added Network LevelCode for SC-7100 task'
				else case when Assessment.LevelCode = 'C' then 'School'
				else case when Assessment.LevelCode = 'U' then 'Teacher' 
				else case when Assessment.PLCID in (select PLCID from #PLCIDs) then 'PLC' end --Khushboo: added this case condition for SC-7100 task
				end end end end end, 
				-1, '-1', -1, '-1',-1,'-1',
				InstanceSubject.SubjectID, InstanceSubject.LongName, Assessment.AssessmentID, replace(replace(Assessment.Name, '>', '&amp;gt;'), '<', '&amp;lt;'), A.URCID -- -- Manohar: Modified to fix the ticket #30785 - Converting special characters to xml tags in the assessment names
				from Assessment
				inner join AssessmentForm on Assessment.AssessmentID = AssessmentForm.AssessmentID
				inner join InstanceSubject on AssessmentForm.SubjectID = InstanceSubject.SubjectID
				inner join SchoolYear on Assessment.SchoolYearID = SchoolYear.SchoolYearID
				--inner join #RosterInfo on #RosterInfo.SchoolYearID = Assessment.SchoolYearID 
				left join Campus on Campus.CampusID = Assessment.LevelOwnerID
				left join UserAccount on UserAccount.UserAccountID = Assessment.CreatedBy
				left join @AllTypeValues A on A.RT = @ReportType 
				where AssessmentFormID = @AssessmentFormID AND InstanceSubject.InstanceID = @InstanceID
				--Srinatha : Added below Assessment.IsLinked column for SC-16815 task
				and Assessment.IsLinked = case when @IncLinkedAssess = 0 then 0 else Assessment.IsLinked end
		
			end

			--Abdul:SC-7558-Network User Changes
			if @AccessLevel in ('N')
				update A set NID = UserRoleNetwork.NetworkID, NN = Network.Name 
				from UserRole 
				join UserRoleNetwork on UserRole.UserRoleID = UserRoleNetwork.UserRoleID
				join Network on Network.NetworkID = UserRoleNetwork.NetworkID
				left join @AllTypeValues A on A.RT = @ReportType
				where UserRole.UserRoleID = @UserRoleID

			if @AccessLevel in ('C')
				update A set  CID =  UserRoleCampus.CampusID, CN = Campus.Name
				from UserRole 
				join UserRoleCampus on UserRole.UserRoleID = UserRoleCampus.UserRoleID
				join Campus on campus.CampusID = UserRoleCampus.CampusID
				left join @AllTypeValues A on A.RT = @ReportType
				where UserRole.UserRoleID = @UserRoleID

			if @AccessLevel in ('T')
				Update A set TID = UserRoleTeacher.TeacherID, TN = Teacher.LastName + ', ' + Teacher.FirstName , CID = UserRoleCampus.CampusID, CN = Campus.Name
				from UserRole 
				join UserRoleTeacher on UserRole.UserRoleID = UserRoleTeacher.UserRoleID
				join UserRoleCampus on UserRole.UserRoleID = UserRoleCampus.UserRoleID
				join Teacher on Teacher.TeacherID = UserRoleTeacher.TeacherID
				join Campus on campus.CampusID = UserRoleCampus.CampusID
				left join @AllTypeValues A on A.RT = @ReportType
				where UserRole.UserRoleID = @UserRoleID

			if @bFromLMS = 0
			begin
				set @Result = (select '<Data> ' + replace(replace((select '<Type>' , RT, RYID, RYN, RDSID, RDSN, SYID, SYN, COLID, COLN, ALID, ALN, TID, TN, CID, CN,NID,NN, SBID, SBN, AID, AN , URCID, '</Type>'
				from @AllTypeValues FOR XML PATH ('')),'&lt;','<'),'&gt;','>') + '</Data>' )

				if exists (select top 1 1 from UserSetting where UserAccountID = @UserAccountID and UserRoleID = @UserRoleID and SettingID = 42)
				begin
					update UserSetting set Value = '<Data> ' + replace(replace((select '<Type>' , RT, RYID, RYN, RDSID, RDSN, SYID, SYN, COLID, COLN, ALID, ALN, TID, TN, CID, CN,NID,NN, SBID, SBN, AID, AN , URCID, '</Type>'
					-- 19-Oct-2020: Manohar - Modified to improve the performance -- added SettingID = 42 in where condition
					from @AllTypeValues FOR XML PATH ('')),'&lt;','<'),'&gt;','>') + '</Data>' where UserAccountID = @UserAccountID and UserRoleID = @UserRoleID and SettingID = 42
				end
				else 
				begin
					insert into UserSetting values	(@UserAccountID, 42,
					@Result, 1, @UserRoleID)
				end
			end
		end	
		
		drop table #TestAttempt
		--drop table #Studentclass  --Sai: Commented and added it below. Bec we are using the #StudentClass in below query

		if @ReportType = 'DDI' and exists (select top 1 1 from #AssessmentFormInfo) 
		begin 
			set @bPreDefinedReport = 1
			set @bDDIReport = 1
		end
		else if @ReportType = 'P' and exists (select top 1 1 from #AssessmentFormInfo)
		begin
			set @bPreDefinedReport = 1
			-- SC-25751 at below code Changed from LEFT JOIN to INNER JOIN to improving the performance/blocking issues
			if exists (select top 1 1 from #tmpAssessments t
				join AssessmentForm AF on t.AssessmentID = AF.AssessmentID 
				Join TestAttempt TA with (nolock) on AF.AssessmentFormID  = TA.AssessmentFormID 
				Join #StudentClass SC on TA.StudentID = SC.StudentID
				Join #StdList SL on TA.StudentID = SL.StudentID
				join ScoreTopic ST on AF.AssessmentFormID = ST.AssessmentFormID 
				where ST.TypeCode = 'T' and SC.StudentID is not null and SL.StudentID is not null) 
			set @bDDIReport = 1
		end
	end
	
	drop table #Studentclass

	set @AssessmentID = (select AID from @AllTypeValues where RT = @ReportType)

	   create table #tmpPETable( AssessmentID int )

	declare @RsQuery varchar(max) = ''
	set @RsQuery = ' and ( LevelCode = ''D'' '
	if @AccessLevel = 'N' --Srinatha: added Network assessment code for @8.1 SC-7099/SC-8021 'Networks - Predefined Reports changes' task
			set @ResultQuery += ' OR (LevelCode = ''N'' And LevelOwnerID = ' + cast(@UserNetworkID as varchar(10)) + ')'
	if @AccessLevel = 'C' OR @AccessLevel = 'T'
		set @RsQuery += ' OR (LevelCode = ''C'' And LevelOwnerID = ' + CAST(@UserCampusID as varchar) + ')'
						+ ' OR ( LevelCode = ''N'' And exists (select top 1 1 from NetworkCampus where NetWorkID = LevelOwnerID and CampusID = '+ cast(@UserCampusID as varchar(15)) + '))'
	if @AccessLevel = 'T'
		set @RsQuery += ' OR (LevelCode = ''U'' And LevelOwnerID = ' + CAST(@UserAccountID as varchar) + ')'
	set @RsQuery += ')'
	-- Manohar\Rajesh Modified for SC-18101 added @AccessLevel case condition

	declare @ResultQuery3 varchar(max)
	--set @RsQuery += 
	set @ResultQuery1 = case when  @AccessLevel  = 'T' and @FutureYear = 'N' then ' and Assessment.SchoolYearID <= ' + cast(@RosterYearID as varchar(10))  else '' end 
		+ ' and Assessment.SchoolYearID between ' + cast((@CurrentYear - @RosterPYear) as varchar(10)) + ' and ' +  cast(@CurrentYear as varchar(10))

	set @Query = ' insert into #tmpPETable select Assessment.AssessmentID From Assessment  
	inner join AssessmentForm on Assessment.AssessmentID = AssessmentForm.AssessmentID  
	inner join ScoreTopic ST on AssessmentForm.AssessmentFormID = ST.AssessmentFormID and ST.TypeCode = ''T''
	where Assessment.ActiveCode = ''A'' and HasScores = 1 and Assessment.InstanceID = ' + cast(@InstanceID as varchar(10)) 
	
	--Prasanna : Added below code for SC-16387 task to get SchoolYear based on "ReportSchoolYearID" setting
	set @ResultQuery3 = @Query + @RsQuery + ' and Assessment.SchoolYearID =' + cast(@ReportSchoolYearID  as varchar(10)) + ' group by Assessment.AssessmentID having count(StandardID) = ''5'' '
	print @ResultQuery3
	exec(@ResultQuery3)

	if not exists(select top 1 1 from #tmpPETable)
	begin
		set @ResultQuery3 = @Query + @RsQuery + @ResultQuery1
			+ ' group by Assessment.AssessmentID having count(StandardID) = ''5'' '
		print @ResultQuery3
		exec(@ResultQuery3)
	end

	 if @ReportType = '' AND EXISTS (select top 1 1 from #tmpPETable)
	  Begin
		SET @bPEReport = 1
	  End
	 drop table #tmpPETable

	 --Rajesh commented for SC-19799
	--set @RosterYearID = (select  top 1 SchoolYearID from RosterDataSet where RosterDataSetID = @RosterDataSetID)

	select @OTName = case when TypeCode = 'B' then 'PermPLCAssessmentItemBank' else 'PermPLCAssessmentOtherTypes' end
	from Assessment where AssessmentID = @AssessmentID

	if not exists(select top 1 1 from @PLCpermissions where OTName = @OTName)
		set @IsPLCRolePerm = 0
	else
		set @IsPLCRolePerm = 1

	if (select top 1 SchoolYearID from RosterDataSet where IsDefault = 1 and InstanceID = @InstanceID) = @RosterYearID and @IsPLCRolePerm = 1 -- MS: It is not only for default roster but for current year all rosters
	begin
		select @AssPLCID = PLCID from Assessment where AssessmentID = @AssessmentID
		
		if @AssPLCID is not null -- If assessment is a PLC assessment
			set @HavePLC = 1
			     
		-- MS: below code is not required just check the user is part of any PLC group.   
		else if @AssPLCID is null -- Assessment is not PLC assessment, but teachers are having plc's
		begin	
			if exists(select top 1 1 from PLC
			join PLCUser on PLC.PLCID = PLCUser.PLCID
			where PLC.InstanceID = @InstanceID and PLCUser.UserAccountID = @UserAccountID and PLC.ActiveCode = 'A')
			-- MS: No need of checking CreatedBy, always user should be part of PLCUser
			set @HavePLC = 1
		end
	end

	-- MS: Added @ReportType = '' because when it is called from LaunchPad @ReportType will be passed as blank
	--Madhushree K: Modified for [SC-24018]
	if @From != 'AssessmentManager' --Sravani Balireddy: When Assessments are deactivates/Scores deleted/Embargoed in AssessmentManger page, we should not show any result
	begin
		IF(@From != 'DeleteScores' and @From != 'Assessment')
		Begin
		IF EXISTS (SELECT TOP 1 1 FROM @AllTypeValues WHERE RYID = -1 and RT in ('P', 'PE')) --** Nithin: 01-Nov-2018 - Modified to fix ticket #29561, added RT in (P, PE) condition.
				select cast(0 as bit) as PreDefinedReport, cast(1 as bit) as PEReport --, @bDDIReport as DDIReport
		else if @ReportType = '' and @From = ''
			select cast(@bPreDefinedReport as bit) as PreDefinedReport, cast(@bPEReport as bit) as PEReport, @HReport as HReport , @bDDIReport as DDIReport, @InterimReport as InterimReport  --Rajesh uncommented for SC-20391
		else if @ReportType != '' and @From = ''
			select @bPreDefinedReport as PreDefinedReport, @bDDIReport as DDIReport,  TypeCode + '~' + (CASE WHEN EXISTS (select top 1 1 FROM QuestionGroup QG WHERE QG.AssessmentFormID in (
				Select AssessmentFormID from AssessmentForm where AssessmentID = @AssessmentID)) THEN '1' ELSE '0' END) +'~' + (CASE WHEN EXISTS (select top 1 1 FROM ScoreTopic ST WHERE ST.AssessmentFormID in (Select AssessmentFormID from AssessmentForm where AssessmentID = @AssessmentID) and ST.TypeCode = 'T') THEN '1' ELSE '0' END) + '~' + CAST(IncludeNotes AS Varchar(2)) + '~' + CAST(IsProgressBuild AS Varchar(2))  AS TypeCodeQGStatus ,
				RT, RYID, RYN, isnull(RDSID ,-1) RDSID , isnull(RDSN, -1) RDSN, SYID, SYN, ISNULL(COLID,-1) COLID, ISNULL(COLN,'') COLN, ISNULL(ALID,-1) ALID, ISNULL(ALN,'') ALN, 
				ISNULL(TID,-1) TID, ISNULL(TN,'')  TN, ISNULL(CID,-1) CID, ISNULL(CN,'')  CN, SBID, SBN, AID, AN , ISNULL(URCID,-1) URCID,
				case when RT = 'P' and @HavePLC = 1 then 1
					when RT = 'P' and @HavePLC = 0  then 0 else '' end IsPLC,
				case when RT = 'P' and @HavePLC = 1 and @AssPLCID is not null then @AssPLCID
					when RT = 'P' and @AssPLCID is null then -1 else '' end PLCID,isnull(NID,-1) NID,isnull(NN,'') NN
			FROM Assessment 
			join @AllTypeValues A on RT = @ReportType
			WHERE AssessmentID = @AssessmentID  and HasScores = 1 and ActiveCode = (case when @ReportType = 'INTR' then 'I' else 'A' end)
		end
	end


END TRY
BEGIN CATCH
	declare @Parameters nvarchar(max) = ''
	set @Parameters = 'exec '+object_name(@@procid)+' @UserRoleID = '+Convert(varchar(50),@UserRoleID)+',
	@UserCampusID = '+convert(varchar(50),@UserCampusID)+',
	@UserTeacherID = '+convert(varchar(50),@UserTeacherID)+',
	@ReportType = '''+@ReportType+''',
	@From = '''+@From+''',
	@TemplateID = '''+@TemplateID+''',@AID = '''+@AID+''',@UserNetworkID = '+convert(varchar(50),@UserNetworkID)+''
	/* Exception Handling, If we are getting any error, then required information will be stored into below Error Table */
	insert into ErrorTable(DBName,Query,ErrorMessage,ProcedureName,CreatedDate)
	Values(db_name(),@Parameters,error_message(),object_name(@@procid),getdate());
END CATCH
end
GO
            


            


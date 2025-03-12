
            

-- ------------ Write DROP-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
IF  EXISTS (
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID (N'[dbo].[appReportCheckDefaultAssessment]') AND 
type = N'P')
DROP PROCEDURE [dbo].[appReportCheckDefaultAssessment];
GO
            


            


            

-- ------------ Write CREATE-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
CREATE PROCEDURE [dbo].[appReportCheckDefaultAssessment] 
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
	Author                :		Sravani Balireddy
	Date Of Creation      :	    21/10/2019
	Purpose               :		To set Default Assessment to the users when it is called from Launchpad
	@Since 7.1
	Revision History:  

	Revision History:
	----------------------------------------------------------------------------------------------------
	DATE				CREATED BY				DESCRIPTION/REMARKS
	22-Nov-2019			Sravani Balireddy		Modified to fix ticket SC-4243 ticket
	25-Jan-2020			Srinatha R A			Modified for SC-5285 'Check all the procedures for SQL injections task'		
	14-Sep-2020         Khushboo                Modified for SC-7350 task 8.1 'Networks - Custom Report changes - By Network sub-tab in Summary tab '	
	07-May-2021			Manohar					SC-13858 -- added logic to check Embrago rules
	21-Sep-2021         Rajesh                  SC-16049 Adding Permission for Student Summary Report
	31-Jan-2022         Rajesh                  Modified for SC-18101 Suiteqa-Reports-Horizon Reports is not loading for particular teacher user
    13-May-2022			Manohar/Rajesh			SC-19871 modified queries to fix the issue
    22-Jun-2022         Rajesh					SC-20391 HISD and Common Code comparison Gaspedal
    21-Feb-2023			Dhareppa				SC-21581 HISD IRM: Add "Interim" tab to HISD Report Manager list
	12-Sep-2023			JayaPrakash				SC-26736 Added Truncate #StudentClass to avoid the Error with duplicate data entry
	03-Nov-2023			Amrut/Srinatha			SC-27556: AISD (MS): Problem with reports. ZDT 1032464 : Added PLC logic to solve this customer issue
    08-Nov-2024	        Srikanth CH             SC-32709 : Performance changes verification on appReportCheckDefaultAssessment procedure.
	----------------------------------------------------------------------------------------------------
	Exec [appReportSetDefaultAssessment] 1054863
*/
begin
BEGIN TRY

	--Srinatha Added below codition to handle sql injectios
	if @TemplateID like '%[a-z]%'
	return;

	declare @UserAccountID int
	declare @settingID int
	declare @PreDefinedReport bit =0
	declare @PEReport bit =0
	declare @PEPermission bit = 0
	declare @HPermission bit = 0 --Rajesh  Modified for SC-16049
	declare @HReport bit = 0 --Rajesh  Modified for SC-16049
	declare @InstanceID int
	declare @RosterQuery varchar(max)
	declare @UserRole char(1)
	declare @StudentGrpQuery varchar(max) -- SC-19871: added new variable to use Studentgroup queries
	declare @ITRPermission bit = 0 --Dhareppa Added for SC-21581 task.
	declare @ITRReport bit = 0 --Dhareppa Added for SC-21581 task.
	declare @PLCIsNonRostered char(1) = 'N' -- --SC-27556: to check whether the district default value for PLC users is set to access Non Rostered students
	declare @PLCID int = -1 --SC-27556
	declare @PLCwhereConditions varchar(MAX) = '' --SC-27556
	
	declare @UserCampusID1 int = @UserCampusID --SC-27556
	declare @UserNetworkID1 int = @UserNetworkID --SC-27556
	declare @UserTeacherID1 int = @UserTeacherID --SC-27556
		
	select @UserAccountID = UserRole.UserAccountID, @InstanceID = InstanceID, @UserRole = AccessLevelCode from UserRole 
    Join Role on Role.RoleID = UserRole.RoleID
	where UserRole.UserRoleID = @UserRoleID
	
	select @settingID =  settingID from Setting where Name = 'ReportSelections'

	if exists(select top 1 1 from App A join Instanceapp IA ON A.AppID = IA.AppID 
    where InstanceID = @InstanceID and IA.IsActive = 1 and A.name = 'Principal Exchange')
	set @PEPermission = 1 

	--Rajesh  Modified for SC-16049
	if exists(select top 1 1 from App A join Instanceapp IA ON A.AppID = IA.AppID 
    where InstanceID = @InstanceID and IA.IsActive = 1 and A.Name = 'Horizon')
	set @HPermission = 1 

    --Dhareppa Added for SC-21581 task.
    if exists(select top 1 1 from App A join Instanceapp IA ON A.AppID = IA.AppID 
    where InstanceID = @InstanceID and IA.IsActive = 1 and A.Name = 'Interim')
	    set @ITRPermission = 1 
	
	--SC-27556:-Added below code to read InstanceSetting value for PLCNonRstr
    select @PLCIsNonRostered = value from InstanceSetting join Setting on Setting.SettingID = InstanceSetting.SettingID where Setting.ShortName = 'PLCNonRstr'
	and InstanceID = @InstanceID

	--Collecting the Setting XML for logged in user
	declare @DefaultSetting XML 
	declare @Setting varchar(max)

	select @DefaultSetting = (select Value from UserSetting Where UserAccountID = @UserAccountID  AND UserRoleID = @UserRoleID AND SettingID = @SettingID)

	set @Setting = cast(isnull(@DefaultSetting, '') as varchar(max))

	Create table #AssessID(RT varchar(10), AID int, RDSID int, RYID int)-- SC-19871: added RYID column
	
	if @Setting <> '' 
	begin

		--Collecting the AssessmentID,ReportType from Default Setting for logged in user
		insert into #AssessID
		select
			objNode.value('RT[1]', 'varchar(100)'), -- ReportType
			objNode.value('AID[1]', 'int'), -- AssessmentID	
			objNode.value('RDSID[1]', 'int'), --Rajesh added for SC-18101
			objNode.value('RYID[1]', 'int')  -- SC-19871: added RYID column
		from @DefaultSetting.nodes('/Data/Type') nodeset(objNode)

		----SC-27556: added below PLC code
		select @PLCID=PLCID from Assessment A join #AssessID B on A.AssessmentID=B.AID where B.RT='P' and A.PLCID is not null
		if (@PLCIsNonRostered = 'Y' ) and @PLCID <> -1
		begin
			set @UserRoleID = ''		
			set @UserCampusID = -1
			set @UserTeacherID = -1
			set @UserNetworkID = -1	
			
			-- Manohar: Added "Explicit PLC Support throughout SUITE" feature @ver 7.0
			-- Loading PLC staff data and students into temp tables
			create table #PLCDetails(TeacherID int, RosterCourseID int, primary key(TeacherID, RosterCourseID))
			create table #PLCStudents (StudentID int primary key)
		
			insert into #PLCDetails
			select distinct UserRoleTeacher.TeacherID, PLCRosterCourse.RosterCourseID
			from PLCUser
			join PLCRosterCourse on PLCUser.PLCID = PLCRosterCourse.PLCID
			join UserRole on UserRole.UserAccountID = PLCUser.UserAccountID
			join UserRoleTeacher on UserRoleTeacher.UserRoleID = UserRole.UserRoleID
			where PLCUser.PLCID = @PLCID
			-- load all roster students for the selected PLC group
			insert into #PLCStudents
			select distinct StudentClass.StudentID from StudentClass with (nolock,forceseek)
			inner join Class with (nolock) ON StudentClass.ClassID = Class.ClassID
			join TeacherClass on TeacherClass.ClassID = Class.ClassID
			join #AssessID A on A.RDSID = Class.RosterDataSetID
			where TeacherClass.IsCurrent = 1 and StudentClass.IsCurrent = 1
			and exists (
			select top 1 1 from #PLCDetails where TeacherID = TeacherClass.TeacherID and RosterCourseID = Class.RosterCourseID)
			-- apply above temp tables to where query as it is used in all tabs queries
			set @PLCwhereConditions = ' and exists (select top 1 1 from #PLCStudents where StudentID = StudentClass.StudentID)' +
							   ' and exists (select top 1 1 from #PLCDetails where TeacherID = TeacherClass.TeacherID
								and RosterCourseID = Class.RosterCourseID)'

		end

		--Rajesh  Modified for SC-18101
		create table #StudentClass (StudentID int primary key)
		if @UserRole not in ('D', 'A') -- No need to run for district/admin users
		set @RosterQuery = 'insert into #StudentClass(StudentID) 
		select distinct StudentClass.StudentID from StudentClass with (nolock,forceseek)  
		join Class on StudentClass.ClassID = Class.ClassID   
		join TeacherClass on  Class.ClassID = TeacherClass.ClassID and TeacherClass.IsCurrent = 1
		join #AssessID A on A.RDSID = Class.RosterDataSetID '  
		+' where StudentClass.IsCurrent = 1 ' 
		+ (case when @UserCampusID != -1 then ' and CLASS.CampusID = ' + CAST(@UserCampusID as varchar(10)) else '' end)
		+ (case when @UserTeacherID != -1 then ' and TeacherClass.TeacherID = ' + CAST(@UserTeacherID as varchar(10)) else '' end)  
		+ (case when @UserNetworkID != -1 then ' and exists (select top 1 1 from NetworkCampus where CampusID = Class.CampusID and Networkid = ' + cast (@UserNetworkID as varchar(10)) + ')' else '' end)  
		+ @PLCwhereConditions --SC-27556
			 
		--print (@RosterQuery)
		-- SC-19871: added below student group queries
		create table #UserStudentGroups (StudentGroupID int primary key, PublicRestrictToSIS bit)  
		insert into #UserStudentGroups
		--SC-27556: changed to @UserCampusID1, @UserNetworkID1
		select * from dbo.appfnGetUserStudentGroups(@InstanceID, @UserAccountID, @UserCampusID1, @UserNetworkID1, -1)  

		set @StudentGrpQuery = ' insert into #StudentClass
			SELECT distinct StudentGroupStudent.StudentID FROM dbo.#UserStudentGroups with (nolock) 
			join StudentGroup on StudentGroup.StudentGroupID = #UserStudentGroups.StudentGroupID
			JOIN dbo.StudentGroupStudent with (nolock) ON                     
			StudentGroupStudent.StudentGroupID = StudentGroup.StudentGroupID
			--join #AssessID A on A.RYID = StudentGroup.SchoolYearID  SC-32709 Commented  so default saved predefined RYID is not matching with studentgroup.YearID
			where StudentGroup.PublicRestrictToSIS = 0 '
		 
		--Checking and displaying Default Assessment which is Active
		--Rajesh  Modified for SC-18101 added HasScores condition
		if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'P' and A.HasScores = 1) and
			-- SC-13858 -- added below Embargo function to check whether the assessment is Embargoed
		(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'P'), @UserRoleID, @UserAccountID)) = 0
		begin
	
			if @UserRole in ('D', 'A')
				set @PreDefinedReport = 1
			else
			begin
				truncate table #StudentClass
				declare @PreDefinedQuery varchar(max) = ''
				set @PreDefinedQuery = @RosterQuery + ' and A.RT = ''P'''
			
				print  @PreDefinedQuery
				exec (@PreDefinedQuery)

				-- SC-19871: inserting student group students
				set @PreDefinedQuery = @StudentGrpQuery-- + ' and A.RT = ''P''' SC-32709 
				+ ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)'
				print @PreDefinedQuery				
				exec (@PreDefinedQuery)			

				if exists (select top 1 1 from TestAttempt T with (nolock)  join #StudentClass ST on T.StudentID = ST.StudentID
				join AssessmentForm AF on AF.AssessmentFormID = T.AssessmentFormID 
				where exists (select top 1 1 from #AssessID where AID = AF.AssessmentID and RT = 'P'))
				set @PreDefinedReport = 1
				else -- SC-19871: added else part
					set @PreDefinedReport = 0
			end
		end		
		
		if @PreDefinedReport = 0 -- SC-19871: changed to if
		Begin
			--Setting default Assessment for PreDefinedReport if there is no default Assessment
			--SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1
			exec appReportDefaultFilters @UserRoleID, @UserCampusID1, @UserTeacherID1, 'P', 'AssessmentManager', @TemplateID, @AID, @UserNetworkID1
        End


		--Rajesh  Modified for SC-18101 added HasScores condition
		if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'PE' and A.HasScores = 1) and
			-- SC-13858 -- added below Embargo function to check whether the assessment is Embargoed
		(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'PE'), @UserRoleID, @UserAccountID)) = 0
		begin
	
			if @UserRole in ('D', 'A')
				set @PEReport = 1
			else
			begin

				truncate table #StudentClass
				declare  @PEQuery varchar(max) = ''
				set @PEQuery = @RosterQuery + ' and A.RT = ''PE'''

				exec (@PEQuery)

				-- SC-19871: inserting student group students
				set @PEQuery = @StudentGrpQuery --+ ' and A.RT = ''PE''' SC-32709
				+ ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)'
				
				exec (@PEQuery)

				if exists (select top 1 1 from TestAttempt T with (nolock)  join #StudentClass ST on T.StudentID = ST.StudentID
				join AssessmentForm AF on AF.AssessmentFormID = T.AssessmentFormID 
				where exists (select top 1 1 from #AssessID where AID = AF.AssessmentID and RT = 'PE'))
					set @PEReport = 1
				else -- SC-19871: added else part
					set @PEReport = 0
			end
		end
		if @PEReport = 0 -- SC-19871: changed to if
		begin

			--Setting default Assessment for principalExchange Report if there is no default Assessment
			--SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1
			if(@PEPermission = 1 and @ReportType = 'PE' )
				exec appReportDefaultFilters @UserRoleID, @UserCampusID1, @UserTeacherID1, 'PE', 'AssessmentManager', @TemplateID, @AID, @UserNetworkID1
		end

		 --Rajesh  Modified for SC-16049
		 --Rajesh  Modified for SC-18101 added HasScores condition
		if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'H' and A.HasScores = 1) and 
		(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'H'), @UserRoleID, @UserAccountID)) = 0
		Begin
			if @UserRole in ('D', 'A')
				set @HReport = 1
			else
			begin
				truncate table #StudentClass
				declare @HQuery varchar(max) = ''
				
				set @HQuery = @RosterQuery + ' and A.RT = ''H'''
				
				exec (@HQuery)

				-- SC-19871: inserting student group students
				set @HQuery = @StudentGrpQuery --+ ' and A.RT = ''H''' SC-32709
				+ ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)'
				
				exec (@HQuery)

				if exists (select top 1 1 from TestAttempt T with (nolock) join #StudentClass ST on T.StudentID = ST.StudentID
				join AssessmentForm AF on AF.AssessmentFormID = T.AssessmentFormID 
				where exists (select top 1 1 from #AssessID where AID = AF.AssessmentID and RT = 'H'))
					set @HReport = 1
				else -- SC-19871: added else part
					set @HReport = 0
			end
        End
		if @HReport = 0 -- SC-19871: changed to if
		begin
			--SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1
			if(@HPermission = 1 and (@ReportType = 'H' or @ReportType = ''))
				exec appReportDefaultFilters @UserRoleID, @UserCampusID1, @UserTeacherID1, 'H', 'AssessmentManager', @TemplateID, @AID, @UserNetworkID1
		end
		
		--Dhareppa Added for SC-21581 task.
		if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'I' and RT = 'INTR' and A.HasScores = 1) and 
			(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'I' and RT = 'INTR' and A.HasScores = 1), @UserRoleID, @UserAccountID)) = 0
		Begin
			if @UserRole in ('D', 'A')
			set @ITRReport = 1
			else
			begin
				truncate table #StudentClass
				declare @ITRQuery varchar(max) = ''
				
				set @ITRQuery = @RosterQuery + ' and A.RT = ''INTR'''
			
				exec (@ITRQuery)
				
				set @ITRQuery = @StudentGrpQuery --+ ' and A.RT = ''INTR''' SC-32709
				+ ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)'
				
				exec (@ITRQuery)

				if exists (select top 1 1 from TestAttempt T with (nolock) join #StudentClass ST on T.StudentID = ST.StudentID
				join AssessmentForm AF on AF.AssessmentFormID = T.AssessmentFormID 
				where exists (select top 1 1 from #AssessID where AID = AF.AssessmentID and RT = 'INTR'))
					set @ITRReport = 1
				else 
					set @ITRReport = 0
			end
        End
		if @ITRReport = 0 
		begin
			--SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1
			if(@ITRPermission = 1 and (@ReportType = 'INTR' or @ReportType = ''))
				exec appReportDefaultFilters @UserRoleID, @UserCampusID1, @UserTeacherID1, 'INTR', 'AssessmentManager', @TemplateID, @AID, @UserNetworkID1
		end

		--After setting default Assessment, checking whether Assessment got updated in UserSetting table for P and PE Reports
		--Dhareppa: Added @ITRReport = 0 condition for SC-21581 task.
		if(@PreDefinedReport = 0 or @PEReport = 0 or @HReport = 0 or @ITRReport = 0)
		begin

			select @DefaultSetting = (select Value from UserSetting Where UserAccountID = @UserAccountID  AND UserRoleID = @UserRoleID AND SettingID = @SettingID)

			truncate table #AssessID

			insert into #AssessID
			select
				objNode.value('RT[1]', 'varchar(100)'), -- ReportType
				objNode.value('AID[1]', 'int'), -- AssessmentID	
				objNode.value('RDSID[1]', 'int'),-- Rajesh Modified for SC-18101
				objNode.value('RYID[1]', 'int') -- SC-19871: added RYID column
			from @DefaultSetting.nodes('/Data/Type') nodeset(objNode)


			if(@PreDefinedReport = 0)
			begin
			
				--Rajesh  Modified for SC-18101 added HasScores condition
				if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'P' and A.HasScores = 1) and
					-- SC-13858 -- added below Embargo function to check whether the assessment is Embargoed
				(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'P'), @UserRoleID, @UserAccountID)) = 0
				begin

					if @UserRole in ('D', 'A')
					set @PreDefinedReport = 1

					else
					begin
						truncate table #StudentClass
						declare @PreDefinedQuery1 varchar(max) = ''
				        set @PreDefinedQuery1 = @RosterQuery + ' and A.RT = ''P'''
			
				        print  @PreDefinedQuery1
				        exec (@PreDefinedQuery1)

						-- SC-19871: inserting student group students
						set @PreDefinedQuery1 = @StudentGrpQuery --+ ' and A.RT = ''P''' SC-32709
						+ ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)'
				
						exec (@PreDefinedQuery1)

						if exists (select top 1 1 from TestAttempt T with (nolock) join #StudentClass ST on T.StudentID = ST.StudentID
						join AssessmentForm AF on AF.AssessmentFormID = T.AssessmentFormID 
						where exists (select top 1 1 from #AssessID where AID = AF.AssessmentID and RT = 'P'))
						set @PreDefinedReport = 1
					end
				end	
							
			end
		
		
			if(@PEReport = 0)
			begin
				--Rajesh  Modified for SC-18101 added HasScores condition
				if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'PE' and A.HasScores = 1) and 
					-- SC-13858 -- added below Embargo function to check whether the assessment is Embargoed
					(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'PE'), @UserRoleID, @UserAccountID)) = 0
					begin
						if @UserRole in ('D', 'A')
						set @PEReport = 1

						else
						begin
							truncate table #StudentClass -- SC-26736, added by JayaPrakash to avoid the Error with duplicate data entry
							declare  @PEQuery1 varchar(max) = ''
				            set @PEQuery1 = @RosterQuery + ' and A.RT = ''PE'''
				
				             exec (@PEQuery1)

							 -- SC-19871: inserting student group students
							set @PEQuery1 = @StudentGrpQuery --+ ' and A.RT = ''PE''' SC-32709
							+ ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)'
				
							exec (@PEQuery1)

						if exists (select top 1 1 from TestAttempt T with (nolock)  join #StudentClass ST on T.StudentID = ST.StudentID
						join AssessmentForm AF on AF.AssessmentFormID = T.AssessmentFormID 
						where exists (select top 1 1 from #AssessID where AID = AF.AssessmentID and RT = 'PE'))
						set @PEReport = 1
						end
					end
			end

    
			 --Rajesh  Modified for SC-16049
			if(@HReport = 0)
			begin
				--Rajesh  Modified for SC-18101 added HasScores condition	
				if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'H' and A.HasScores = 1) and 
				(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'H'), @UserRoleID, @UserAccountID)) = 0
				Begin
					if @UserRole in ('D', 'A')
					set @HReport = 1

					else
					begin
						truncate table #StudentClass
						declare @HQuery1 varchar(max) = ''
				
				        set @HQuery1 = @RosterQuery + ' and A.RT = ''H'''
				
				        print @HQuery1
				        exec (@HQuery1)

						-- SC-19871: inserting student group students
						set @HQuery1 = @StudentGrpQuery --+ ' an SC-32709
						+ ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)'
				
						exec (@HQuery1)

					if exists (select top 1 1 from TestAttempt T with (nolock) join #StudentClass ST on T.StudentID = ST.StudentID
					join AssessmentForm AF on AF.AssessmentFormID = T.AssessmentFormID 
					where exists (select top 1 1 from #AssessID where AID = AF.AssessmentID and RT = 'H'))
					set @HReport = 1
					end
				End
			
			end

			--Dhareppa Added for SC-21581
			 if(@ITRReport = 0)
			 begin						
					if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'I' and RT = 'INTR' and A.HasScores = 1) and 
						(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'I' and RT = 'INTR'), @UserRoleID, @UserAccountID)) = 0
					Begin
						if @UserRole in ('D', 'A')
						set @ITRReport = 1

						else
						begin
							truncate table #StudentClass
							declare @ITRQuery1 varchar(max) = ''
				
							set @ITRQuery1 = @RosterQuery + ' and A.RT = ''INTR'''
				
							print @ITRQuery1
							exec (@ITRQuery1)

						-- SC-19871: inserting student group students
						set @ITRQuery1 = @StudentGrpQuery --+ ' and A.RT = ''INTR'''  SC-32709
						+ ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)'
				
						exec (@ITRQuery1)

							if exists (select top 1 1 from TestAttempt T with (nolock) join #StudentClass ST on T.StudentID = ST.StudentID
							join AssessmentForm AF on AF.AssessmentFormID = T.AssessmentFormID 
							where exists (select top 1 1 from #AssessID where AID = AF.AssessmentID and RT = 'INTR'))
							set @ITRReport = 1
						end
					End		
			 end
        end
                        --Rajesh added DDIReport For SC-20391
			select @PreDefinedReport as PreDefinedReport, @PEReport as PEReport, @HReport as HReport, @PreDefinedReport as DDIReport, @ITRReport as InterimReport
	end
	else
	begin
		--SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1
		exec appReportDefaultFilters @UserRoleID, @UserCampusID1, @UserTeacherID1, 'P', 'AssessmentManager', @TemplateID, @AID, @UserNetworkID1
		
		--SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1
		if(@PEPermission = 1 and @ReportType = 'PE' )
			exec appReportDefaultFilters @UserRoleID, @UserCampusID1, @UserTeacherID1, 'PE', 'AssessmentManager', @TemplateID, @AID, @UserNetworkID1

        --Rajesh  Modified for SC-16049
		--SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1
        if(@HPermission = 1 and (@ReportType = 'H' or @ReportType = ''))
			exec appReportDefaultFilters @UserRoleID, @UserCampusID1, @UserTeacherID1, 'H', 'AssessmentManager', @TemplateID, @AID, @UserNetworkID1

        --Dhareppa Added for SC-21581
		--SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1
        if(@ITRPermission = 1 and (@ReportType = 'INTR' or @ReportType = ''))
			exec appReportDefaultFilters @UserRoleID, @UserCampusID1, @UserTeacherID1, 'INTR', 'AssessmentManager', @TemplateID, @AID, @UserNetworkID1

		truncate table #AssessID

		select @DefaultSetting = (select Value from UserSetting Where UserAccountID = @UserAccountID  AND UserRoleID = @UserRoleID AND SettingID = @SettingID)

		insert into #AssessID
		select
			objNode.value('RT[1]', 'varchar(100)'), -- ReportType
			objNode.value('AID[1]', 'int') , -- AssessmentID	
			objNode.value('RDSID[1]', 'int'), --Rajesh added for SC-18101-- AssessmentID
			objNode.value('RYID[1]', 'int') -- SC-19871: added RYID column
		from @DefaultSetting.nodes('/Data/Type') nodeset(objNode)

		--Rajesh  Modified for SC-18101 added HasScores condition
		if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'P' and A.HasScores = 1) and 
			-- SC-13858 -- added below Embargo function to check whether the assessment is Embargoed
			(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'P'), @UserRoleID, @UserAccountID)) = 0
			set @PreDefinedReport = 1 

		--Rajesh  Modified for SC-18101 added HasScores condition
		if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'PE' and  A.HasScores = 1) and 
			-- SC-13858 -- added below Embargo function to check whether the assessment is Embargoed
			(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'PE'), @UserRoleID, @UserAccountID)) = 0
			set @PEReport = 1

	   	--Rajesh  Modified for SC-18101 added HasScores condition
	   if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'H' and A.HasScores = 1) and 
			-- SC-13858 -- added below Embargo function to check whether the assessment is Embargoed
			(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'A' and RT = 'H'), @UserRoleID, @UserAccountID)) = 0
			set @HReport = 1

	   --Dhareppa Added for SC-21581 task.
	   if exists(select top 1 1 from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'I' and RT = 'INTR' and A.HasScores = 1) and 
			-- SC-13858 -- added below Embargo function to check whether the assessment is Embargoed
			(select dbo.[fn_EmbargoGetEmbargoStatus]((select top 1 A.AssessmentID from #AssessID A1 join Assessment A on A.AssessmentID = A1.AID and ActiveCode = 'I' and RT = 'INTR'), @UserRoleID, @UserAccountID)) = 0
			set @ITRReport = 1

                --Rajesh added DDIReport For SC-20391
		select @PreDefinedReport as PreDefinedReport, @PEReport as PEReport,  @HReport as HReport, @PreDefinedReport as DDIReport, @ITRReport as InterimReport
	end
END TRY
BEGIN CATCH
	declare @Parameters nvarchar(max) = ''
	set @Parameters = 'exec '+object_name(@@procid)+' @UserRoleID = '+Convert(varchar(50),@UserRoleID)+',
	@UserCampusID = '+convert(varchar(50),@UserCampusID1)+',
	@UserTeacherID = '+convert(varchar(50),@UserTeacherID1)+',
	@ReportType = '''+@ReportType+''',
	@From = '''+@From+''',
	@TemplateID = '''+@TemplateID+''',@AID = '''+@AID+''',@UserNetworkID = '+convert(varchar(50),@UserNetworkID1)+''
	/* Exception Handling, If we are getting any error, then required information will be stored into below Error Table */
	insert into ErrorTable(DBName,Query,ErrorMessage,ProcedureName,CreatedDate)
	Values(db_name(),@Parameters,error_message(),object_name(@@procid),getdate());
END CATCH


end
GO
            


            


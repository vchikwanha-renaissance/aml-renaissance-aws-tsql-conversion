
            

-- ------------ Write DROP-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
IF  EXISTS (
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID (N'[dbo].[appFnReportUserData]') AND 
type = N'FN')
DROP FUNCTION [dbo].[appFnReportUserData];
GO
            


            


            

-- ------------ Write CREATE-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
CREATE function [dbo].[appFnReportUserData] (@UserRoleID INT, @NetworkID int = -1)
RETURNS  VARCHAR(MAX)
AS 
/*
	------------------------------------------------------------------------------------------------------------------------------
	DATE				CREATED BY			DESCRIPTION/REMARKS
	-----------------------------------------------------------------------------------------------------------------------------	
	06-Aug-2020			Srinatha R A		Modifed to include @NetworkID for @8.1 SC-7099/SC-8021 'Networks - Predefined Reports changes' task
	------------------------------------------------------------------------------------------------------------------------------
*/
BEGIN
	DECLARE @SelectQuery VARCHAR(MAX) = ''
	DECLARE @JoinQuery VARCHAR(MAX) = ''
	DECLARE @SecondJoinQuery VARCHAR(MAX) = ''
	DECLARE @AccessLevelCode VARCHAR(10) = ''
	--DECLARE @InsertQuery VARCHAR(MAX) = ''
	--DECLARE @TABLE TABLE (UserRoleID INT, CampusID INT, TeacherID INT, GradeID INT, StudentGroupID INT )

	select @AccessLevelCode = AccessLevelCode from UserRole
	join Role on UserRole.RoleID = Role.RoleID
	where UserRoleID = @UserRoleID

	IF((SELECT TOP 1 1 FROM UserRoleCampus WHERE UserRoleID = @UserRoleID) = 1 OR 
		(SELECT TOP 1 1 FROM UserRoleTeacher WHERE UserRoleID = @UserRoleID) = 1 OR 
		(SELECT TOP 1 1 FROM UserRoleGrade WHERE UserRoleID = @UserRoleID) = 1 OR 
		(SELECT TOP 1 1 FROM UserRoleStudentGroup WHERE UserRoleID = @UserRoleID) = 1 or
		(SELECT TOP 1 1 FROM UserRoleNetwork WHERE UserRoleID = @UserRoleID) = 1)
	BEGIN
		--SET @InsertQuery  = 'INSERT INTO #UserData (UserRoleID'
		SET @SelectQuery  = ' INNER JOIN ( SELECT UserRole.UserRoleID'
		SET @JoinQuery  = ' FROM UserRole '
		
		IF EXISTS (SELECT TOP 1 1 FROM UserRoleNetwork WHERE UserRoleID = @UserRoleID)
		BEGIN
			SET @SelectQuery += ', CampusID '
			SET @JoinQuery += ' JOIN UserRoleNetwork ON UserRole.UserRoleID = UserRoleNetwork.UserRoleID
								JOIN NetworkCampus ON UserRoleNetwork.NetworkID = NetworkCampus.NetworkID '
			SET @SecondJoinQuery += ' AND UserData.CampusID = Class.CampusID '
		END
		IF EXISTS (SELECT TOP 1 1 FROM UserRoleCampus WHERE UserRoleID = @UserRoleID)
		BEGIN
			--SET @InsertQuery += ', CampusID '
			SET @SelectQuery += ', CampusID '
			SET @JoinQuery += 'LEFT OUTER JOIN UserRoleCampus ON UserRole.UserRoleID = UserRoleCampus.UserRoleID '
			SET @SecondJoinQuery += ' AND UserData.CampusID = CLASS.CampusID '
		END
		IF EXISTS (SELECT TOP 1 1 FROM UserRoleTeacher WHERE UserRoleID = @UserRoleID)
		BEGIN
			--SET @InsertQuery += ', TeacherID '
			SET @SelectQuery += ', TeacherID '
			SET @JoinQuery += 'LEFT OUTER JOIN UserRoleTeacher ON UserRole.UserRoleID = UserRoleTeacher.UserRoleID '
			SET @SecondJoinQuery += ' AND UserData.TeacherID = TeacherClass.TeacherID '
		END
		IF EXISTS (SELECT TOP 1 1 FROM UserRoleGrade WHERE UserRoleID = @UserRoleID)
		BEGIN
			--SET @InsertQuery += ', GradeID '
			SET @SelectQuery += ', GradeID '
			SET @JoinQuery += 'LEFT OUTER JOIN UserRoleGrade ON UserRole.UserRoleID = UserRoleGrade.UserRoleID '
			SET @SecondJoinQuery += ' AND UserData.GradeID = StudentClass.GradeID '
		END
		IF EXISTS (SELECT TOP 1 1 FROM UserRoleStudentGroup WHERE UserRoleID = @UserRoleID)
		BEGIN
			--SET @InsertQuery += ', StudentGroupID '
			SET @SelectQuery += ', StudentGroupID '
			SET @JoinQuery += 'LEFT OUTER JOIN UserRoleStudentGroup ON UserRole.UserRoleID = UserRoleStudentGroup.UserRoleID '
			SET @SecondJoinQuery += ' AND UserData.StudentGroupID = StudentGroupStudent.StudentGroupID '
		END
		
		SET @SelectQuery += @JoinQuery + ' WHERE UserRole.UserRoleID = ' + CAST(@UserRoleID AS VARCHAR) 
		+ case when @NetworkID <> -1 and @AccessLevelCode = 'N' then ' and UserRoleNetwork.NetworkID = ' + CAST(@NetworkID AS VARCHAR) else '' end
		+ ') UserData' + 
		STUFF( @SecondJoinQuery , 1, 4, ' ON')
		
		
	END
	
	RETURN @SelectQuery
	
END
GO
            


            


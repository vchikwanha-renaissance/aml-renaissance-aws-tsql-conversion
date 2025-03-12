-- ------------ Write DROP-FUNCTION-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.appfnreportuserdata(IN INTEGER, IN INTEGER);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-FUNCTION-stage scripts -----------

CREATE OR REPLACE FUNCTION dbo.appfnreportuserdata(IN par_userroleid INTEGER, IN par_networkid INTEGER DEFAULT -1)
RETURNS TEXT
AS
$BODY$
/*
------------------------------------------------------------------------------------------------------------------------------
DATE				CREATED BY			DESCRIPTION/REMARKS
-----------------------------------------------------------------------------------------------------------------------------
06-Aug-2020			Srinatha R A		Modifed to include @NetworkID for @8.1 SC-7099/SC-8021 'Networks - Predefined Reports changes' task
------------------------------------------------------------------------------------------------------------------------------
*/
DECLARE
    var_SelectQuery TEXT DEFAULT '';
    var_JoinQuery TEXT DEFAULT '';
    var_SecondJoinQuery TEXT DEFAULT '';
    var_AccessLevelCode VARCHAR(10) DEFAULT '';
BEGIN
    /* DECLARE @InsertQuery VARCHAR(MAX) = '' */
    /* DECLARE @TABLE TABLE (UserRoleID INT, CampusID INT, TeacherID INT, GradeID INT, StudentGroupID INT ) */
    SELECT
        accesslevelcode
        INTO var_AccessLevelCode
        FROM dbo.userrole
        JOIN dbo.role
            ON userrole.roleid = role.roleid
        WHERE userroleid = par_UserRoleID;

    IF ((SELECT
        1
        FROM dbo.userrolecampus
        WHERE userroleid = par_UserRoleID
        LIMIT 1) = 1 OR (SELECT
        1
        FROM dbo.userroleteacher
        WHERE userroleid = par_UserRoleID
        LIMIT 1) = 1 OR (SELECT
        1
        FROM dbo.userrolegrade
        WHERE userroleid = par_UserRoleID
        LIMIT 1) = 1 OR (SELECT
        1
        FROM dbo.userrolestudentgroup
        WHERE userroleid = par_UserRoleID
        LIMIT 1) = 1 OR (SELECT
        1
        FROM dbo.userrolenetwork
        WHERE userroleid = par_UserRoleID
        LIMIT 1) = 1) THEN
        /* SET @InsertQuery  = 'INSERT INTO #UserData (UserRoleID' */
        var_SelectQuery := ' INNER JOIN ( SELECT UserRole.UserRoleID';
        var_JoinQuery := ' FROM UserRole ';

        IF EXISTS (SELECT
            1
            FROM dbo.userrolenetwork
            WHERE userroleid = par_UserRoleID
            LIMIT 1) THEN
            var_SelectQuery := var_SelectQuery || ', CampusID ';
            var_JoinQuery := var_JoinQuery || ' JOIN UserRoleNetwork ON UserRole.UserRoleID = UserRoleNetwork.UserRoleID
								JOIN NetworkCampus ON UserRoleNetwork.NetworkID = NetworkCampus.NetworkID ';
            var_SecondJoinQuery := var_SecondJoinQuery || ' AND UserData.CampusID = Class.CampusID ';
        END IF;

        IF EXISTS (SELECT
            1
            FROM dbo.userrolecampus
            WHERE userroleid = par_UserRoleID
            LIMIT 1) THEN
            /* SET @InsertQuery += ', CampusID ' */
            var_SelectQuery := var_SelectQuery || ', CampusID ';
            var_JoinQuery := var_JoinQuery || 'LEFT OUTER JOIN UserRoleCampus ON UserRole.UserRoleID = UserRoleCampus.UserRoleID ';
            var_SecondJoinQuery := var_SecondJoinQuery || ' AND UserData.CampusID = CLASS.CampusID ';
        END IF;

        IF EXISTS (SELECT
            1
            FROM dbo.userroleteacher
            WHERE userroleid = par_UserRoleID
            LIMIT 1) THEN
            /* SET @InsertQuery += ', TeacherID ' */
            var_SelectQuery := var_SelectQuery || ', TeacherID ';
            var_JoinQuery := var_JoinQuery || 'LEFT OUTER JOIN UserRoleTeacher ON UserRole.UserRoleID = UserRoleTeacher.UserRoleID ';
            var_SecondJoinQuery := var_SecondJoinQuery || ' AND UserData.TeacherID = TeacherClass.TeacherID ';
        END IF;

        IF EXISTS (SELECT
            1
            FROM dbo.userrolegrade
            WHERE userroleid = par_UserRoleID
            LIMIT 1) THEN
            /* SET @InsertQuery += ', GradeID ' */
            var_SelectQuery := var_SelectQuery || ', GradeID ';
            var_JoinQuery := var_JoinQuery || 'LEFT OUTER JOIN UserRoleGrade ON UserRole.UserRoleID = UserRoleGrade.UserRoleID ';
            var_SecondJoinQuery := var_SecondJoinQuery || ' AND UserData.GradeID = StudentClass.GradeID ';
        END IF;

        IF EXISTS (SELECT
            1
            FROM dbo.userrolestudentgroup
            WHERE userroleid = par_UserRoleID
            LIMIT 1) THEN
            /* SET @InsertQuery += ', StudentGroupID ' */
            var_SelectQuery := var_SelectQuery || ', StudentGroupID ';
            var_JoinQuery := var_JoinQuery || 'LEFT OUTER JOIN UserRoleStudentGroup ON UserRole.UserRoleID = UserRoleStudentGroup.UserRoleID ';
            var_SecondJoinQuery := var_SecondJoinQuery || ' AND UserData.StudentGroupID = StudentGroupStudent.StudentGroupID ';
        END IF;
        var_SelectQuery := var_SelectQuery || var_JoinQuery || ' WHERE UserRole.UserRoleID = ' || CAST (par_UserRoleID AS VARCHAR(30)) ||
        CASE
            WHEN par_NetworkID <> - 1 AND var_AccessLevelCode = 'N' THEN ' and UserRoleNetwork.NetworkID = ' || CAST (par_NetworkID AS VARCHAR(30))
            ELSE ''
        END || ') UserData' || OVERLAY(var_SecondJoinQuery PLACING ' ON' FROM 1 FOR 4);
    END IF;
    RETURN var_SelectQuery;
END;
$BODY$
LANGUAGE  plpgsql;


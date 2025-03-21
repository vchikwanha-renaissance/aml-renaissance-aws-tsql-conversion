-- ------------ Write DROP-PROCEDURE-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.appreportcheckdefaultassessment(IN INTEGER, IN INTEGER, IN INTEGER, IN VARCHAR, IN VARCHAR, IN VARCHAR, IN VARCHAR, IN INTEGER, INOUT refcursor);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-PROCEDURE-stage scripts -----------

CREATE OR REPLACE PROCEDURE dbo.appreportcheckdefaultassessment(IN par_userroleid INTEGER, IN par_usercampusid INTEGER, IN par_userteacherid INTEGER, IN par_reporttype VARCHAR DEFAULT '', IN par_from VARCHAR DEFAULT '', IN par_templateid VARCHAR DEFAULT '', IN par_aid VARCHAR DEFAULT '-1', IN par_usernetworkid INTEGER DEFAULT -1, INOUT p_refcur refcursor DEFAULT NULL)
AS 
$BODY$
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
DECLARE
    var_UserAccountID INTEGER;
    var_settingID INTEGER;
    var_PreDefinedReport NUMERIC(1, 0) DEFAULT 0;
    var_PEReport NUMERIC(1, 0) DEFAULT 0;
    var_PEPermission NUMERIC(1, 0) DEFAULT 0;
    var_HPermission NUMERIC(1, 0) DEFAULT 0;
    var_HReport NUMERIC(1, 0) DEFAULT 0;
    var_InstanceID INTEGER;
    var_RosterQuery TEXT;
    var_UserRole CHAR(1);
    var_StudentGrpQuery TEXT;
    var_ITRPermission NUMERIC(1, 0) DEFAULT 0;
    var_ITRReport NUMERIC(1, 0) DEFAULT 0;
    var_PLCIsNonRostered CHAR(1) DEFAULT 'N';
    var_PLCID INTEGER DEFAULT - 1;
    var_PLCwhereConditions TEXT DEFAULT '';
    var_UserCampusID1 INTEGER DEFAULT par_UserCampusID;
    var_UserNetworkID1 INTEGER DEFAULT par_UserNetworkID;
    var_UserTeacherID1 INTEGER DEFAULT par_UserTeacherID;
    var_DefaultSetting XML;
    var_Setting TEXT;
    var_PreDefinedQuery TEXT DEFAULT '';
    var_PEQuery TEXT DEFAULT '';
    var_HQuery TEXT DEFAULT '';
    var_ITRQuery TEXT DEFAULT '';
    var_PreDefinedQuery1 TEXT DEFAULT '';
    var_PEQuery1 TEXT DEFAULT '';
    var_HQuery1 TEXT DEFAULT '';
    var_ITRQuery1 TEXT DEFAULT '';
    var_Parameters TEXT DEFAULT '';
BEGIN
    BEGIN
        /* Srinatha Added below codition to handle sql injectios */
        IF par_TemplateID SIMILAR TO '%[a-z]%' THEN
            RETURN;
        END IF;
        SELECT
            userrole.useraccountid, instanceid, accesslevelcode
            INTO var_UserAccountID, var_InstanceID, var_UserRole
            FROM dbo.userrole
            JOIN dbo.role
                ON role.roleid = userrole.roleid
            WHERE userrole.userroleid = par_UserRoleID;
        SELECT
            settingid
            INTO var_settingID
            FROM dbo.setting
            WHERE name = 'ReportSelections';

        IF EXISTS (SELECT
            1
            FROM dbo.app AS a
            JOIN dbo.instanceapp AS ia
                ON a.appid = ia.appid
            WHERE instanceid = var_InstanceID AND ia.isactive = 1 AND a.name = 'Principal Exchange'
            LIMIT 1) THEN
            var_PEPermission := 1;
        END IF;
        /* Rajesh  Modified for SC-16049 */

        IF EXISTS (SELECT
            1
            FROM dbo.app AS a
            JOIN dbo.instanceapp AS ia
                ON a.appid = ia.appid
            WHERE instanceid = var_InstanceID AND ia.isactive = 1 AND a.name = 'Horizon'
            LIMIT 1) THEN
            var_HPermission := 1;
        END IF;
        /* Dhareppa Added for SC-21581 task. */

        IF EXISTS (SELECT
            1
            FROM dbo.app AS a
            JOIN dbo.instanceapp AS ia
                ON a.appid = ia.appid
            WHERE instanceid = var_InstanceID AND ia.isactive = 1 AND a.name = 'Interim'
            LIMIT 1) THEN
            var_ITRPermission := 1;
        END IF;
        /* SC-27556:-Added below code to read InstanceSetting value for PLCNonRstr */
        SELECT
            value
            INTO var_PLCIsNonRostered
            FROM dbo.instancesetting
            JOIN dbo.setting
                ON setting.settingid = instancesetting.settingid
            WHERE setting.shortname = 'PLCNonRstr' AND instanceid = var_InstanceID;
        /* Collecting the Setting XML for logged in user */
        SELECT
            (SELECT
                value
                FROM dbo.usersetting
                WHERE useraccountid = var_UserAccountID AND userroleid = par_UserRoleID AND settingid = var_settingID)
            INTO var_DefaultSetting;
        var_Setting := CAST (COALESCE(var_DefaultSetting, '') AS TEXT);
        CREATE TEMPORARY TABLE t$assessid
        (rt VARCHAR(10),
            aid INTEGER,
            rdsid INTEGER,
            ryid INTEGER);
        /* SC-19871: added RYID column */

        IF var_Setting <> '' THEN
            /* Collecting the AssessmentID,ReportType from Default Setting for logged in user */
            
            /*
            [7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.NODES(VARCHAR) data type. Convert your source code manually.]
            insert into #AssessID
            		select
            			objNode.value('RT[1]', 'varchar(100)'), -- ReportType
            			objNode.value('AID[1]', 'int'), -- AssessmentID
            			objNode.value('RDSID[1]', 'int'), --Rajesh added for SC-18101
            			objNode.value('RYID[1]', 'int')  -- SC-19871: added RYID column
            		from @DefaultSetting.nodes('/Data/Type') nodeset(objNode)
            */
            /* --SC-27556: added below PLC code */
            SELECT
                plcid
                INTO var_PLCID
                FROM dbo.assessment AS a
                JOIN t$assessid AS b
                    ON a.assessmentid = b.aid
                WHERE b.rt = 'P' AND a.plcid IS NOT NULL;

            IF (var_PLCIsNonRostered = 'Y') AND var_PLCID <> - 1 THEN
                par_UserRoleID := '';
                par_UserCampusID := - 1;
                par_UserTeacherID := - 1;
                par_UserNetworkID := - 1;
                /* Manohar: Added "Explicit PLC Support throughout SUITE" feature @ver 7.0 */
                /* Loading PLC staff data and students into temp tables */
                CREATE TEMPORARY TABLE t$plcdetails
                (teacherid INTEGER,
                    rostercourseid INTEGER,
                    PRIMARY KEY (teacherid, rostercourseid));
                CREATE TEMPORARY TABLE t$plcstudents
                (studentid INTEGER PRIMARY KEY);
                INSERT INTO t$plcdetails
                SELECT DISTINCT
                    userroleteacher.teacherid, plcrostercourse.rostercourseid
                    FROM dbo.plcuser
                    JOIN dbo.plcrostercourse
                        ON plcuser.plcid = plcrostercourse.plcid
                    JOIN dbo.userrole
                        ON userrole.useraccountid = plcuser.useraccountid
                    JOIN dbo.userroleteacher
                        ON userroleteacher.userroleid = userrole.userroleid
                    WHERE plcuser.plcid = var_PLCID;
                /* load all roster students for the selected PLC group */
                INSERT INTO t$plcstudents
                SELECT DISTINCT
                    studentclass.studentid
                    FROM dbo.studentclass
                    INNER JOIN dbo.class
                        ON studentclass.classid = class.classid
                    JOIN dbo.teacherclass
                        ON teacherclass.classid = class.classid
                    JOIN t$assessid AS a
                        ON a.rdsid = class.rosterdatasetid
                    WHERE teacherclass.iscurrent = 1 AND studentclass.iscurrent = 1 AND EXISTS (SELECT
                        1
                        FROM t$plcdetails
                        WHERE teacherid = teacherclass.teacherid AND rostercourseid = class.rostercourseid
                        LIMIT 1);
                /* apply above temp tables to where query as it is used in all tabs queries */
                var_PLCwhereConditions := ' and exists (select top 1 1 from #PLCStudents where StudentID = StudentClass.StudentID)' || ' and exists (select top 1 1 from #PLCDetails where TeacherID = TeacherClass.TeacherID
								and RosterCourseID = Class.RosterCourseID)';
            END IF;
            /* Rajesh  Modified for SC-18101 */
            CREATE TEMPORARY TABLE t$studentclass
            (studentid INTEGER PRIMARY KEY);

            IF var_UserRole NOT IN ('D', 'A') THEN
                /* No need to run for district/admin users */
                var_RosterQuery := 'insert into #StudentClass(StudentID) 
		select distinct StudentClass.StudentID from StudentClass with (nolock,forceseek)  
		join Class on StudentClass.ClassID = Class.ClassID   
		join TeacherClass on  Class.ClassID = TeacherClass.ClassID and TeacherClass.IsCurrent = 1
		join #AssessID A on A.RDSID = Class.RosterDataSetID ' || ' where StudentClass.IsCurrent = 1 ' || (CASE
                    WHEN par_UserCampusID != - 1 THEN ' and CLASS.CampusID = ' || CAST (par_UserCampusID AS VARCHAR(10))
                    ELSE ''
                END) || (CASE
                    WHEN par_UserTeacherID != - 1 THEN ' and TeacherClass.TeacherID = ' || CAST (par_UserTeacherID AS VARCHAR(10))
                    ELSE ''
                END) || (CASE
                    WHEN par_UserNetworkID != - 1 THEN ' and exists (select top 1 1 from NetworkCampus where CampusID = Class.CampusID and Networkid = ' || CAST (par_UserNetworkID AS VARCHAR(10)) || ')'
                    ELSE ''
                END) || var_PLCwhereConditions;
            END IF;
            /* SC-27556 */
            /* print (@RosterQuery) */
            /* SC-19871: added below student group queries */
            CREATE TEMPORARY TABLE t$userstudentgroups
            (studentgroupid INTEGER PRIMARY KEY,
                publicrestricttosis NUMERIC(1, 0));
            INSERT INTO t$userstudentgroups
            /* SC-27556: changed to @UserCampusID1, @UserNetworkID1 */
            SELECT
                *
                FROM dbo.appfngetuserstudentgroups(var_InstanceID, var_UserAccountID, var_UserCampusID1, var_UserNetworkID1, - 1);
            var_StudentGrpQuery := ' insert into #StudentClass
			SELECT distinct StudentGroupStudent.StudentID FROM dbo.#UserStudentGroups with (nolock) 
			join StudentGroup on StudentGroup.StudentGroupID = #UserStudentGroups.StudentGroupID
			JOIN dbo.StudentGroupStudent with (nolock) ON                     
			StudentGroupStudent.StudentGroupID = StudentGroup.StudentGroupID
			--join #AssessID A on A.RYID = StudentGroup.SchoolYearID  SC-32709 Commented  so default saved predefined RYID is not matching with studentgroup.YearID
			where StudentGroup.PublicRestrictToSIS = 0 ';
            /* Checking and displaying Default Assessment which is Active */
            /* Rajesh  Modified for SC-18101 added HasScores condition */

            IF EXISTS (SELECT
                1
                FROM t$assessid AS a1
                JOIN dbo.assessment AS a
                    ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'P' AND a.hasscores = 1
                LIMIT 1) AND
            /* SC-13858 -- added below Embargo function to check whether the assessment is Embargoed */
            (SELECT
                dbo.fn_embargogetembargostatus((SELECT
                    a.assessmentid
                    FROM t$assessid AS a1
                    JOIN dbo.assessment AS a
                        ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'P'
                    LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                IF var_UserRole IN ('D', 'A') THEN
                    var_PreDefinedReport := 1;
                ELSE
                    TRUNCATE TABLE t$studentclass;
                    var_PreDefinedQuery := var_RosterQuery || ' and A.RT = ''P''';
                    RAISE NOTICE '%', var_PreDefinedQuery;
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec (@PreDefinedQuery)
                    */
                    /* SC-19871: inserting student group students */
                    var_PreDefinedQuery := var_StudentGrpQuery ||
                    /* + ' and A.RT = ''P''' SC-32709 */
                    ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)';
                    RAISE NOTICE '%', var_PreDefinedQuery;
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec (@PreDefinedQuery)
                    */
                    IF EXISTS (SELECT
                        1
                        FROM dbo.testattempt AS t
                        JOIN t$studentclass AS st
                            ON t.studentid = st.studentid
                        JOIN dbo.assessmentform AS af
                            ON af.assessmentformid = t.assessmentformid
                        WHERE EXISTS (SELECT
                            1
                            FROM t$assessid
                            WHERE aid = af.assessmentid AND rt = 'P'
                            LIMIT 1)) THEN
                        var_PreDefinedReport := 1;
                    ELSE
                        /* SC-19871: added else part */
                        var_PreDefinedReport := 0;
                    END IF;
                END IF;
            END IF;

            IF var_PreDefinedReport = 0 THEN
                /* SC-19871: changed to if */
                /* Setting default Assessment for PreDefinedReport if there is no default Assessment */
                /* SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1 */
                CALL dbo.appreportdefaultfilters(par_UserRoleID, var_UserCampusID1, var_UserTeacherID1, 'P', 'AssessmentManager', par_TemplateID, par_AID, var_UserNetworkID1);
            END IF;
            /* Rajesh  Modified for SC-18101 added HasScores condition */

            IF EXISTS (SELECT
                1
                FROM t$assessid AS a1
                JOIN dbo.assessment AS a
                    ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'PE' AND a.hasscores = 1
                LIMIT 1) AND
            /* SC-13858 -- added below Embargo function to check whether the assessment is Embargoed */
            (SELECT
                dbo.fn_embargogetembargostatus((SELECT
                    a.assessmentid
                    FROM t$assessid AS a1
                    JOIN dbo.assessment AS a
                        ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'PE'
                    LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                IF var_UserRole IN ('D', 'A') THEN
                    var_PEReport := 1;
                ELSE
                    TRUNCATE TABLE t$studentclass;
                    var_PEQuery := var_RosterQuery || ' and A.RT = ''PE''';
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec (@PEQuery)
                    */
                    /* SC-19871: inserting student group students */
                    var_PEQuery := var_StudentGrpQuery ||
                    /* + ' and A.RT = ''PE''' SC-32709 */
                    ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)';
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec (@PEQuery)
                    */
                    IF EXISTS (SELECT
                        1
                        FROM dbo.testattempt AS t
                        JOIN t$studentclass AS st
                            ON t.studentid = st.studentid
                        JOIN dbo.assessmentform AS af
                            ON af.assessmentformid = t.assessmentformid
                        WHERE EXISTS (SELECT
                            1
                            FROM t$assessid
                            WHERE aid = af.assessmentid AND rt = 'PE'
                            LIMIT 1)) THEN
                        var_PEReport := 1;
                    ELSE
                        /* SC-19871: added else part */
                        var_PEReport := 0;
                    END IF;
                END IF;
            END IF;

            IF var_PEReport = 0 THEN
                /* SC-19871: changed to if */
                /* Setting default Assessment for principalExchange Report if there is no default Assessment */
                /* SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1 */
                IF (var_PEPermission = 1 AND par_ReportType = 'PE') THEN
                    CALL dbo.appreportdefaultfilters(par_UserRoleID, var_UserCampusID1, var_UserTeacherID1, 'PE', 'AssessmentManager', par_TemplateID, par_AID, var_UserNetworkID1);
                END IF;
            END IF;
            /* Rajesh  Modified for SC-16049 */
            /* Rajesh  Modified for SC-18101 added HasScores condition */

            IF EXISTS (SELECT
                1
                FROM t$assessid AS a1
                JOIN dbo.assessment AS a
                    ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'H' AND a.hasscores = 1
                LIMIT 1) AND (SELECT
                dbo.fn_embargogetembargostatus((SELECT
                    a.assessmentid
                    FROM t$assessid AS a1
                    JOIN dbo.assessment AS a
                        ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'H'
                    LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                IF var_UserRole IN ('D', 'A') THEN
                    var_HReport := 1;
                ELSE
                    TRUNCATE TABLE t$studentclass;
                    var_HQuery := var_RosterQuery || ' and A.RT = ''H''';
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec (@HQuery)
                    */
                    /* SC-19871: inserting student group students */
                    var_HQuery := var_StudentGrpQuery ||
                    /* + ' and A.RT = ''H''' SC-32709 */
                    ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)';
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec (@HQuery)
                    */
                    IF EXISTS (SELECT
                        1
                        FROM dbo.testattempt AS t
                        JOIN t$studentclass AS st
                            ON t.studentid = st.studentid
                        JOIN dbo.assessmentform AS af
                            ON af.assessmentformid = t.assessmentformid
                        WHERE EXISTS (SELECT
                            1
                            FROM t$assessid
                            WHERE aid = af.assessmentid AND rt = 'H'
                            LIMIT 1)) THEN
                        var_HReport := 1;
                    ELSE
                        /* SC-19871: added else part */
                        var_HReport := 0;
                    END IF;
                END IF;
            END IF;

            IF var_HReport = 0 THEN
                /* SC-19871: changed to if */
                /* SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1 */
                IF (var_HPermission = 1 AND (par_ReportType = 'H' OR par_ReportType = '')) THEN
                    CALL dbo.appreportdefaultfilters(par_UserRoleID, var_UserCampusID1, var_UserTeacherID1, 'H', 'AssessmentManager', par_TemplateID, par_AID, var_UserNetworkID1);
                END IF;
            END IF;
            /* Dhareppa Added for SC-21581 task. */

            IF EXISTS (SELECT
                1
                FROM t$assessid AS a1
                JOIN dbo.assessment AS a
                    ON a.assessmentid = a1.aid AND activecode = 'I' AND rt = 'INTR' AND a.hasscores = 1
                LIMIT 1) AND (SELECT
                dbo.fn_embargogetembargostatus((SELECT
                    a.assessmentid
                    FROM t$assessid AS a1
                    JOIN dbo.assessment AS a
                        ON a.assessmentid = a1.aid AND activecode = 'I' AND rt = 'INTR' AND a.hasscores = 1
                    LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                IF var_UserRole IN ('D', 'A') THEN
                    var_ITRReport := 1;
                ELSE
                    TRUNCATE TABLE t$studentclass;
                    var_ITRQuery := var_RosterQuery || ' and A.RT = ''INTR''';
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec (@ITRQuery)
                    */
                    var_ITRQuery := var_StudentGrpQuery ||
                    /* + ' and A.RT = ''INTR''' SC-32709 */
                    ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)';
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec (@ITRQuery)
                    */
                    IF EXISTS (SELECT
                        1
                        FROM dbo.testattempt AS t
                        JOIN t$studentclass AS st
                            ON t.studentid = st.studentid
                        JOIN dbo.assessmentform AS af
                            ON af.assessmentformid = t.assessmentformid
                        WHERE EXISTS (SELECT
                            1
                            FROM t$assessid
                            WHERE aid = af.assessmentid AND rt = 'INTR'
                            LIMIT 1)) THEN
                        var_ITRReport := 1;
                    ELSE
                        var_ITRReport := 0;
                    END IF;
                END IF;
            END IF;

            IF var_ITRReport = 0 THEN
                /* SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1 */
                IF (var_ITRPermission = 1 AND (par_ReportType = 'INTR' OR par_ReportType = '')) THEN
                    CALL dbo.appreportdefaultfilters(par_UserRoleID, var_UserCampusID1, var_UserTeacherID1, 'INTR', 'AssessmentManager', par_TemplateID, par_AID, var_UserNetworkID1);
                END IF;
            END IF;
            /* After setting default Assessment, checking whether Assessment got updated in UserSetting table for P and PE Reports */
            /* Dhareppa: Added @ITRReport = 0 condition for SC-21581 task. */

            IF (var_PreDefinedReport = 0 OR var_PEReport = 0 OR var_HReport = 0 OR var_ITRReport = 0) THEN
                SELECT
                    (SELECT
                        value
                        FROM dbo.usersetting
                        WHERE useraccountid = var_UserAccountID AND userroleid = par_UserRoleID AND settingid = var_settingID)
                    INTO var_DefaultSetting;
                TRUNCATE TABLE t$assessid;
                /*
                [7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.NODES(VARCHAR) data type. Convert your source code manually.]
                insert into #AssessID
                			select
                				objNode.value('RT[1]', 'varchar(100)'), -- ReportType
                				objNode.value('AID[1]', 'int'), -- AssessmentID
                				objNode.value('RDSID[1]', 'int'),-- Rajesh Modified for SC-18101
                				objNode.value('RYID[1]', 'int') -- SC-19871: added RYID column
                			from @DefaultSetting.nodes('/Data/Type') nodeset(objNode)
                */
                IF (var_PreDefinedReport = 0) THEN
                    /* Rajesh  Modified for SC-18101 added HasScores condition */
                    IF EXISTS (SELECT
                        1
                        FROM t$assessid AS a1
                        JOIN dbo.assessment AS a
                            ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'P' AND a.hasscores = 1
                        LIMIT 1) AND
                    /* SC-13858 -- added below Embargo function to check whether the assessment is Embargoed */
                    (SELECT
                        dbo.fn_embargogetembargostatus((SELECT
                            a.assessmentid
                            FROM t$assessid AS a1
                            JOIN dbo.assessment AS a
                                ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'P'
                            LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                        IF var_UserRole IN ('D', 'A') THEN
                            var_PreDefinedReport := 1;
                        ELSE
                            TRUNCATE TABLE t$studentclass;
                            var_PreDefinedQuery1 := var_RosterQuery || ' and A.RT = ''P''';
                            RAISE NOTICE '%', var_PreDefinedQuery1;
                            /*
                            [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                            exec (@PreDefinedQuery1)
                            */
                            /* SC-19871: inserting student group students */
                            var_PreDefinedQuery1 := var_StudentGrpQuery ||
                            /* + ' and A.RT = ''P''' SC-32709 */
                            ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)';
                            /*
                            [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                            exec (@PreDefinedQuery1)
                            */
                            IF EXISTS (SELECT
                                1
                                FROM dbo.testattempt AS t
                                JOIN t$studentclass AS st
                                    ON t.studentid = st.studentid
                                JOIN dbo.assessmentform AS af
                                    ON af.assessmentformid = t.assessmentformid
                                WHERE EXISTS (SELECT
                                    1
                                    FROM t$assessid
                                    WHERE aid = af.assessmentid AND rt = 'P'
                                    LIMIT 1)) THEN
                                var_PreDefinedReport := 1;
                            END IF;
                        END IF;
                    END IF;
                END IF;

                IF (var_PEReport = 0) THEN
                    /* Rajesh  Modified for SC-18101 added HasScores condition */
                    IF EXISTS (SELECT
                        1
                        FROM t$assessid AS a1
                        JOIN dbo.assessment AS a
                            ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'PE' AND a.hasscores = 1
                        LIMIT 1) AND
                    /* SC-13858 -- added below Embargo function to check whether the assessment is Embargoed */
                    (SELECT
                        dbo.fn_embargogetembargostatus((SELECT
                            a.assessmentid
                            FROM t$assessid AS a1
                            JOIN dbo.assessment AS a
                                ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'PE'
                            LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                        IF var_UserRole IN ('D', 'A') THEN
                            var_PEReport := 1;
                        ELSE
                            TRUNCATE TABLE t$studentclass;
                            /* SC-26736, added by JayaPrakash to avoid the Error with duplicate data entry */
                            var_PEQuery1 := var_RosterQuery || ' and A.RT = ''PE''';
                            /*
                            [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                            exec (@PEQuery1)
                            */
                            /* SC-19871: inserting student group students */
                            var_PEQuery1 := var_StudentGrpQuery ||
                            /* + ' and A.RT = ''PE''' SC-32709 */
                            ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)';
                            /*
                            [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                            exec (@PEQuery1)
                            */
                            IF EXISTS (SELECT
                                1
                                FROM dbo.testattempt AS t
                                JOIN t$studentclass AS st
                                    ON t.studentid = st.studentid
                                JOIN dbo.assessmentform AS af
                                    ON af.assessmentformid = t.assessmentformid
                                WHERE EXISTS (SELECT
                                    1
                                    FROM t$assessid
                                    WHERE aid = af.assessmentid AND rt = 'PE'
                                    LIMIT 1)) THEN
                                var_PEReport := 1;
                            END IF;
                        END IF;
                    END IF;
                END IF;
                /* Rajesh  Modified for SC-16049 */

                IF (var_HReport = 0) THEN
                    /* Rajesh  Modified for SC-18101 added HasScores condition */
                    IF EXISTS (SELECT
                        1
                        FROM t$assessid AS a1
                        JOIN dbo.assessment AS a
                            ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'H' AND a.hasscores = 1
                        LIMIT 1) AND (SELECT
                        dbo.fn_embargogetembargostatus((SELECT
                            a.assessmentid
                            FROM t$assessid AS a1
                            JOIN dbo.assessment AS a
                                ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'H'
                            LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                        IF var_UserRole IN ('D', 'A') THEN
                            var_HReport := 1;
                        ELSE
                            TRUNCATE TABLE t$studentclass;
                            var_HQuery1 := var_RosterQuery || ' and A.RT = ''H''';
                            RAISE NOTICE '%', var_HQuery1;
                            /*
                            [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                            exec (@HQuery1)
                            */
                            /* SC-19871: inserting student group students */
                            var_HQuery1 := var_StudentGrpQuery ||
                            /* + ' an SC-32709 */
                            ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)';
                            /*
                            [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                            exec (@HQuery1)
                            */
                            IF EXISTS (SELECT
                                1
                                FROM dbo.testattempt AS t
                                JOIN t$studentclass AS st
                                    ON t.studentid = st.studentid
                                JOIN dbo.assessmentform AS af
                                    ON af.assessmentformid = t.assessmentformid
                                WHERE EXISTS (SELECT
                                    1
                                    FROM t$assessid
                                    WHERE aid = af.assessmentid AND rt = 'H'
                                    LIMIT 1)) THEN
                                var_HReport := 1;
                            END IF;
                        END IF;
                    END IF;
                END IF;
                /* Dhareppa Added for SC-21581 */

                IF (var_ITRReport = 0) THEN
                    IF EXISTS (SELECT
                        1
                        FROM t$assessid AS a1
                        JOIN dbo.assessment AS a
                            ON a.assessmentid = a1.aid AND activecode = 'I' AND rt = 'INTR' AND a.hasscores = 1
                        LIMIT 1) AND (SELECT
                        dbo.fn_embargogetembargostatus((SELECT
                            a.assessmentid
                            FROM t$assessid AS a1
                            JOIN dbo.assessment AS a
                                ON a.assessmentid = a1.aid AND activecode = 'I' AND rt = 'INTR'
                            LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                        IF var_UserRole IN ('D', 'A') THEN
                            var_ITRReport := 1;
                        ELSE
                            TRUNCATE TABLE t$studentclass;
                            var_ITRQuery1 := var_RosterQuery || ' and A.RT = ''INTR''';
                            RAISE NOTICE '%', var_ITRQuery1;
                            /*
                            [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                            exec (@ITRQuery1)
                            */
                            /* SC-19871: inserting student group students */
                            var_ITRQuery1 := var_StudentGrpQuery ||
                            /* + ' and A.RT = ''INTR'''  SC-32709 */
                            ' and not exists (select top 1 1 from #StudentClass where StudentID = StudentGroupStudent.StudentID)';
                            /*
                            [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                            exec (@ITRQuery1)
                            */
                            IF EXISTS (SELECT
                                1
                                FROM dbo.testattempt AS t
                                JOIN t$studentclass AS st
                                    ON t.studentid = st.studentid
                                JOIN dbo.assessmentform AS af
                                    ON af.assessmentformid = t.assessmentformid
                                WHERE EXISTS (SELECT
                                    1
                                    FROM t$assessid
                                    WHERE aid = af.assessmentid AND rt = 'INTR'
                                    LIMIT 1)) THEN
                                var_ITRReport := 1;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;
            /* Rajesh added DDIReport For SC-20391 */
            OPEN p_refcur FOR
            SELECT
                var_PreDefinedReport AS predefinedreport, var_PEReport AS pereport, var_HReport AS hreport, var_PreDefinedReport AS ddireport, var_ITRReport AS interimreport;
        ELSE
            /* SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1 */
            CALL dbo.appreportdefaultfilters(par_UserRoleID, var_UserCampusID1, var_UserTeacherID1, 'P', 'AssessmentManager', par_TemplateID, par_AID, var_UserNetworkID1);
            /* SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1 */

            IF (var_PEPermission = 1 AND par_ReportType = 'PE') THEN
                CALL dbo.appreportdefaultfilters(par_UserRoleID, var_UserCampusID1, var_UserTeacherID1, 'PE', 'AssessmentManager', par_TemplateID, par_AID, var_UserNetworkID1);
            END IF;
            /* Rajesh  Modified for SC-16049 */
            /* SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1 */

            IF (var_HPermission = 1 AND (par_ReportType = 'H' OR par_ReportType = '')) THEN
                CALL dbo.appreportdefaultfilters(par_UserRoleID, var_UserCampusID1, var_UserTeacherID1, 'H', 'AssessmentManager', par_TemplateID, par_AID, var_UserNetworkID1);
            END IF;
            /* Dhareppa Added for SC-21581 */
            /* SC-27556: changed to @UserCampusID1,@UserTeacherID1, @UserNetworkID1 */

            IF (var_ITRPermission = 1 AND (par_ReportType = 'INTR' OR par_ReportType = '')) THEN
                CALL dbo.appreportdefaultfilters(par_UserRoleID, var_UserCampusID1, var_UserTeacherID1, 'INTR', 'AssessmentManager', par_TemplateID, par_AID, var_UserNetworkID1);
            END IF;
            TRUNCATE TABLE t$assessid;
            SELECT
                (SELECT
                    value
                    FROM dbo.usersetting
                    WHERE useraccountid = var_UserAccountID AND userroleid = par_UserRoleID AND settingid = var_settingID)
                INTO var_DefaultSetting;
            /*
            [7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.NODES(VARCHAR) data type. Convert your source code manually.]
            insert into #AssessID
            		select
            			objNode.value('RT[1]', 'varchar(100)'), -- ReportType
            			objNode.value('AID[1]', 'int') , -- AssessmentID
            			objNode.value('RDSID[1]', 'int'), --Rajesh added for SC-18101-- AssessmentID
            			objNode.value('RYID[1]', 'int') -- SC-19871: added RYID column
            		from @DefaultSetting.nodes('/Data/Type') nodeset(objNode)
            */
            /* Rajesh  Modified for SC-18101 added HasScores condition */
            IF EXISTS (SELECT
                1
                FROM t$assessid AS a1
                JOIN dbo.assessment AS a
                    ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'P' AND a.hasscores = 1
                LIMIT 1) AND
            /* SC-13858 -- added below Embargo function to check whether the assessment is Embargoed */
            (SELECT
                dbo.fn_embargogetembargostatus((SELECT
                    a.assessmentid
                    FROM t$assessid AS a1
                    JOIN dbo.assessment AS a
                        ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'P'
                    LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                var_PreDefinedReport := 1;
            END IF;
            /* Rajesh  Modified for SC-18101 added HasScores condition */

            IF EXISTS (SELECT
                1
                FROM t$assessid AS a1
                JOIN dbo.assessment AS a
                    ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'PE' AND a.hasscores = 1
                LIMIT 1) AND
            /* SC-13858 -- added below Embargo function to check whether the assessment is Embargoed */
            (SELECT
                dbo.fn_embargogetembargostatus((SELECT
                    a.assessmentid
                    FROM t$assessid AS a1
                    JOIN dbo.assessment AS a
                        ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'PE'
                    LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                var_PEReport := 1;
            END IF;
            /* Rajesh  Modified for SC-18101 added HasScores condition */

            IF EXISTS (SELECT
                1
                FROM t$assessid AS a1
                JOIN dbo.assessment AS a
                    ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'H' AND a.hasscores = 1
                LIMIT 1) AND
            /* SC-13858 -- added below Embargo function to check whether the assessment is Embargoed */
            (SELECT
                dbo.fn_embargogetembargostatus((SELECT
                    a.assessmentid
                    FROM t$assessid AS a1
                    JOIN dbo.assessment AS a
                        ON a.assessmentid = a1.aid AND activecode = 'A' AND rt = 'H'
                    LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                var_HReport := 1;
            END IF;
            /* Dhareppa Added for SC-21581 task. */

            IF EXISTS (SELECT
                1
                FROM t$assessid AS a1
                JOIN dbo.assessment AS a
                    ON a.assessmentid = a1.aid AND activecode = 'I' AND rt = 'INTR' AND a.hasscores = 1
                LIMIT 1) AND
            /* SC-13858 -- added below Embargo function to check whether the assessment is Embargoed */
            (SELECT
                dbo.fn_embargogetembargostatus((SELECT
                    a.assessmentid
                    FROM t$assessid AS a1
                    JOIN dbo.assessment AS a
                        ON a.assessmentid = a1.aid AND activecode = 'I' AND rt = 'INTR'
                    LIMIT 1), par_UserRoleID, var_UserAccountID)) = 0 THEN
                var_ITRReport := 1;
            END IF;
            /* Rajesh added DDIReport For SC-20391 */
            OPEN p_refcur FOR
            SELECT
                var_PreDefinedReport AS predefinedreport, var_PEReport AS pereport, var_HReport AS hreport, var_PreDefinedReport AS ddireport, var_ITRReport AS interimreport;
        END IF;
        /* Rajesh  Modified for SC-16049 */
        /* Rajesh  Modified for SC-16049 */
        /* SC-19871: added new variable to use Studentgroup queries */
        /* Dhareppa Added for SC-21581 task. */
        /* Dhareppa Added for SC-21581 task. */
        /* --SC-27556: to check whether the district default value for PLC users is set to access Non Rostered students */
        /* SC-27556 */
        /* SC-27556 */
        /* SC-27556 */
        /* SC-27556 */
        /* SC-27556 */
        EXCEPTION
            WHEN OTHERS THEN
                var_Parameters := 'exec ' + 'appreportcheckdefaultassessment' || ' @UserRoleID = ' || CAST (par_UserRoleID AS VARCHAR(50)) || ',
	@UserCampusID = ' || CAST (var_UserCampusID1 AS VARCHAR(50)) || ',
	@UserTeacherID = ' || CAST (var_UserTeacherID1 AS VARCHAR(50)) || ',
	@ReportType = ''' || par_ReportType || ''',
	@From = ''' || par_From || ''',
	@TemplateID = ''' || par_TemplateID || ''',@AID = ''' || par_AID || ''',@UserNetworkID = ' || CAST (var_UserNetworkID1 AS VARCHAR(50)) || '';
                /* Exception Handling, If we are getting any error, then required information will be stored into below Error Table */
                INSERT INTO dbo.errortable (dbname, query, errormessage, procedurename, createddate)
                VALUES (current_database(), var_Parameters, error_catch$ERROR_MESSAGE, 'appreportcheckdefaultassessment', clock_timestamp());
    END;
    /*
    
    DROP TABLE IF EXISTS t$assessid;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$plcdetails;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$plcstudents;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$studentclass;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$userstudentgroups;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;


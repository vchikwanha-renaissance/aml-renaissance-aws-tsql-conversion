-- ------------ Write DROP-PROCEDURE-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.appreportdefaultfilters(IN INTEGER, IN INTEGER, IN INTEGER, IN VARCHAR, IN VARCHAR, IN VARCHAR, IN VARCHAR, IN INTEGER, INOUT refcursor, INOUT refcursor, INOUT refcursor, INOUT refcursor, INOUT refcursor);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-PROCEDURE-stage scripts -----------

CREATE OR REPLACE PROCEDURE dbo.appreportdefaultfilters(IN par_userroleid INTEGER, IN par_usercampusid INTEGER, IN par_userteacherid INTEGER, IN par_reporttype VARCHAR DEFAULT '', IN par_from VARCHAR DEFAULT '', IN par_templateid VARCHAR DEFAULT '', IN par_aid VARCHAR DEFAULT '-1', IN par_usernetworkid INTEGER DEFAULT -1, INOUT p_refcur refcursor DEFAULT NULL, INOUT p_refcur_2 refcursor DEFAULT NULL, INOUT p_refcur_3 refcursor DEFAULT NULL, INOUT p_refcur_4 refcursor DEFAULT NULL, INOUT p_refcur_5 refcursor DEFAULT NULL)
AS 
$BODY$
/* 1058659, 1000003, 1004831 */

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
DECLARE
    var_InstanceID INTEGER;
    var_UserAccountID INTEGER;
    var_DefaultSetting TEXT;
    var_ResultQuery TEXT;
    var_RosterQuery TEXT;
    var_StudentGrpQuery TEXT;
    var_AssessmentFormID INTEGER;
    var_AssessmentID INTEGER DEFAULT - 1;
    var_ReturnValue INTEGER;
    var_AccessLevel CHAR(1);
    var_Query TEXT;
    var_RosterDataSetID INTEGER;
    var_SubjectID INTEGER;
    var_StudentGroup INTEGER DEFAULT 0;
    var_FDsashBoard NUMERIC(1, 0);
    var_PLCIsNonRostered CHAR(1) DEFAULT 'N';
    var_PastRosterVisibility XML;
    var_PastYear INTEGER;
    var_AllowAccess CHAR(1);
    var_FutureYear CHAR(1);
    var_CurrentYear INTEGER;
    var_RosterPYear INTEGER;
    var_RosterSubQuery TEXT;
    var_ResultQuery1 TEXT;
    var_bPreDefinedReport NUMERIC(1, 0) DEFAULT 0;
    var_bDDIReport NUMERIC(1, 0) DEFAULT 0;
    var_bPEReport NUMERIC(1, 0) DEFAULT 0;
    var_bLFReport NUMERIC(1, 0) DEFAULT 0;
    var_bSBACReport NUMERIC(1, 0) DEFAULT 0;
    var_bBRReport NUMERIC(1, 0) DEFAULT 0;
    var_bCIReport NUMERIC(1, 0) DEFAULT 0;
    var_HReport NUMERIC(1, 0) DEFAULT 0;
    var_IncLinkedAssess NUMERIC(1, 0) DEFAULT 0;
    var_InterimReport NUMERIC(1, 0) DEFAULT 0;
    var_bFromLMS NUMERIC(1, 0) DEFAULT
    CASE
        WHEN par_AID <> '-1' THEN 1
        ELSE 0
    END;
    var_CurrentStudent CHAR(1) DEFAULT 'N';
    var_DDITab CHAR(1) DEFAULT 'N';
    var_RosterYearID INTEGER;
    var_ReportSchoolYearID INTEGER;
    var_SettingXML XML;
    var_DistictValue NUMERIC(1, 0) DEFAULT 0;
    var_appFnReportUserData TEXT DEFAULT '';
    var_AssPLCID INTEGER;
    var_HavePLC NUMERIC(1, 0) DEFAULT 0;
    var_IsPLCRolePerm NUMERIC(1, 0) DEFAULT 0;
    var_OTName VARCHAR(200);
    var_L4WMenuXML XML;
    var_Result TEXT DEFAULT '';
    var_AccessCondition TEXT;
    var_RsQuery TEXT DEFAULT '';
    var_ResultQuery3 TEXT;
    var_Parameters TEXT DEFAULT '';
BEGIN
    BEGIN
        /* Srinatha Added below codition to handle sql injectios */
        IF par_TemplateID SIMILAR TO '%[a-z]%' THEN
            RETURN;
        END IF;

        IF par_AID SIMILAR TO '%[a-z]%' THEN
            RETURN;
        END IF;

        IF par_UserRoleID = - 1 THEN
            OPEN p_refcur FOR
            SELECT
                CAST (0 AS INTEGER) AS predefinedreport;
            RETURN;
        END IF;
        /* Rajesh added below block  For SC-20391 */
        /* Mala : Added below lines to fix bug 43491 */

        IF (par_ReportType = 'D') THEN
            par_ReportType := 'P';
            var_FDsashBoard := 1;
        END IF;
        /* Manohar: added the below lines */

        IF par_From = '-1' THEN
            par_From := '';
        END IF;
        /* MS: Align the code properly and folow the coding convensions */
        SELECT
            useraccount.instanceid, userrole.useraccountid, accesslevelcode
            INTO var_InstanceID, var_UserAccountID, var_AccessLevel
            FROM dbo.userrole
            INNER JOIN dbo.useraccount
                ON userrole.useraccountid = useraccount.useraccountid
            INNER JOIN dbo.role
                ON role.roleid = userrole.roleid
            WHERE userrole.userroleid = par_UserRoleID;
        SELECT
            value
            INTO var_ReportSchoolYearID
            FROM dbo.instancesetting
            WHERE instanceid = var_InstanceID AND settingid IN (SELECT
                settingid
                FROM dbo.setting
                WHERE shortname = 'SchYrR');
        /* Manohar\Rajesh Modified for SC-18101 */
        var_PastRosterVisibility := (SELECT
            value
            FROM dbo.instancesetting AS ins
            INNER JOIN dbo.setting AS s
                ON ins.settingid = s.settingid
            WHERE s.name = 'PastRosterVisibility' AND instanceid = var_InstanceID
            LIMIT 1);
        /*
        [7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.NODES(VARCHAR) data type. Convert your source code manually.]
        select @AllowAccess  = isnull(objNode.value('access[1]', 'char(1)'),'Y'),
        			@PastYear     = objNode.value('years[1]', 'int'),
        			@FutureYear   = objNode.value('aaccess[1]', 'char(1)')
        	from
        			@PastRosterVisibility.nodes('/roster') nodeset(objNode)
        */
        IF var_PastYear IS NULL THEN
            var_PastYear := 2;
        /* Default Year */
        ELSE
            var_PastYear := var_PastYear;
        END IF;

        IF par_ReportType = 'C' AND var_AccessLevel != 'T' THEN
            par_UserRoleID := (SELECT
                userroleteacher.userroleid
                FROM dbo.userroleteacher
                JOIN dbo.userrole
                    ON userrole.userroleid = userroleteacher.userroleid
                JOIN dbo.useraccount
                    ON userrole.useraccountid = useraccount.useraccountid
                JOIN dbo.role
                    ON role.roleid = userrole.roleid AND role.activecode = 'A' AND accesslevelcode = 'T'
                WHERE teacherid = par_UserTeacherID AND useraccount.activecode = 'A'
                LIMIT 1);
            SELECT
                useraccount.instanceid, userrole.useraccountid, accesslevelcode
                INTO var_InstanceID, var_UserAccountID, var_AccessLevel
                FROM dbo.userrole
                INNER JOIN dbo.useraccount
                    ON userrole.useraccountid = useraccount.useraccountid
                INNER JOIN dbo.role
                    ON role.roleid = userrole.roleid
                WHERE userrole.userroleid = par_UserRoleID;
            /* select @UserRoleID, @UserAccountID,@ReportType */
        END IF;
        /* Srinatha : Added below changes for SC-16815 task */

        IF EXISTS (SELECT
            1
            FROM dbo.instanceapp AS ia
            JOIN dbo.app AS a
                ON a.appid = ia.appid
            WHERE a.name = 'Linked Assessment' AND ia.instanceid = var_InstanceID
            LIMIT 1) THEN
            var_IncLinkedAssess := 1;
        END IF;
        /* Manohar: Added the below check for if no scored assessments then skip all the queires to improve the procedure performance */

        IF NOT EXISTS (SELECT
            1
            FROM dbo.assessment
            WHERE instanceid = var_InstanceID AND activecode = 'A' AND hasscores = 1
            LIMIT 1) THEN
            IF ('' = par_From) THEN
                OPEN p_refcur_2 FOR
                SELECT
                    CAST (0 AS INTEGER) AS predefinedreport, CAST (0 AS INTEGER) AS hreport;
            END IF;
            /* Rajesh  Modified for SC-15445 */
            /* Prasanna: Added condition to fix loger issue. */
            RETURN;
        END IF;
        SELECT
            CASE
                WHEN var_bFromLMS = 0 THEN (SELECT
                    value
                    FROM dbo.usersetting
                    WHERE useraccountid = var_UserAccountID AND userroleid = par_UserRoleID AND settingid = 42
                    LIMIT 1)
                ELSE ''
            END
            INTO var_SettingXML;
        var_DefaultSetting := CAST (COALESCE(var_SettingXML, '') AS TEXT);
        CREATE TEMPORARY TABLE alltypevalues$appreportdefaultfilters
        (sino BIGINT GENERATED ALWAYS AS IDENTITY,
            rt VARCHAR(10),
            ryid INTEGER,
            ryn VARCHAR(100),
            rdsid INTEGER,
            rdsn VARCHAR(100),
            syid INTEGER,
            syn VARCHAR(100),
            colid VARCHAR(100),
            coln VARCHAR(100),
            alid INTEGER,
            aln VARCHAR(100),
            tid INTEGER,
            tn VARCHAR(100),
            cid INTEGER,
            cn VARCHAR(100),
            nid INTEGER,
            nn VARCHAR(100),
            sbid INTEGER,
            sbn VARCHAR(100),
            aid INTEGER,
            an VARCHAR(200),
            urcid INTEGER);
        /* Khushboo: added NID,NN for SC-8043 task */

        IF var_DefaultSetting <> '' THEN
            /*
            [7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.NODES(VARCHAR) data type. Convert your source code manually.]
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
            */
            /* Manohar: Modified to fix the ticket #29864 - added the below line of code */
            IF EXISTS (SELECT
                1
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'P' AND (ryid = - 1 OR ryid = 0)
                LIMIT 1) THEN
                DELETE FROM alltypevalues$appreportdefaultfilters
                    WHERE rt = 'P';
            END IF;

            IF NOT EXISTS (SELECT
                1
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'P'
                LIMIT 1) THEN
                INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                SELECT
                    'P', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '';
            END IF;

            IF NOT EXISTS (SELECT
                1
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'DDI'
                LIMIT 1) THEN
                INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                SELECT
                    'DDI', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '';
            END IF;

            IF NOT EXISTS (SELECT
                1
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'PE'
                LIMIT 1) THEN
                INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                SELECT
                    'PE', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '';
            END IF;

            IF NOT EXISTS (SELECT
                1
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'S'
                LIMIT 1) THEN
                INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                SELECT
                    'S', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '';
            END IF;

            IF NOT EXISTS (SELECT
                1
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'L'
                LIMIT 1) THEN
                INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                SELECT
                    'L', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '';
            END IF;

            IF NOT EXISTS (SELECT
                1
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'BRR'
                LIMIT 1) THEN
                INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                SELECT
                    'BRR', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '';
            END IF;

            IF NOT EXISTS (SELECT
                1
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'C'
                LIMIT 1) THEN
                INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                SELECT
                    'C', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '';
            END IF;

            IF NOT EXISTS (SELECT
                1
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'H'
                LIMIT 1) THEN
                /* Rajesh  Modified for SC-15445 */
                INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                SELECT
                    'H', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '';
            END IF;
            /* Madhushree K: Modified for [SC-24018] */

            IF NOT EXISTS (SELECT
                1
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'INTR'
                LIMIT 1) THEN
                INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                SELECT
                    'INTR', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '';
            END IF;
        ELSE
            INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
            SELECT
                'P', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
            UNION ALL
            SELECT
                'DDI', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
            UNION ALL
            SELECT
                'PE', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
            UNION ALL
            SELECT
                'S', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
            UNION ALL
            SELECT
                'L', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
            UNION ALL
            SELECT
                'BRR', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
            UNION ALL
            SELECT
                'C', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
            UNION ALL
            SELECT
                'H', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
            /* Rajesh  Modified for SC-15445 */
            UNION ALL
            SELECT
                'INTR', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
            /* Madhushree K: Modified for [SC-24018] */
            ;
        END IF;
        CREATE TEMPORARY TABLE t$hasassessdata
        (value INTEGER PRIMARY KEY);
        CREATE TEMPORARY TABLE t$stdlist
        (studentid INTEGER PRIMARY KEY);
        CREATE TEMPORARY TABLE t$studentclass
        (studentid INTEGER PRIMARY KEY);
        CREATE TEMPORARY TABLE t$rosterstudents
        (studentid INTEGER PRIMARY KEY);
        CREATE TEMPORARY TABLE t$plcids
        (plcid INTEGER PRIMARY KEY);
        /* set the roster data set while will be used inside Roster query */

        IF par_ReportType != '' AND var_bFromLMS = 0 THEN
            SELECT
                COALESCE(rdsid, - 1), aid, sbid
                INTO var_RosterDataSetID, var_AssessmentID, var_SubjectID
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = par_ReportType;
        END IF;
        /* Manohar: Modified to fix getting RosterDataSetID if there is no data in @AllTypeValues table */

        IF var_RosterDataSetID = - 1 OR COALESCE(var_RosterDataSetID, 0) = 0 THEN
            SELECT
                rosterdatasetid
                INTO var_RosterDataSetID
                FROM dbo.rosterdataset
                WHERE isdefault = 1 AND instanceid = var_InstanceID;
        END IF;
        SELECT
            schoolyearid
            INTO var_RosterYearID
            FROM dbo.rosterdataset
            WHERE isdefault = 1 AND instanceid = var_InstanceID;
        /* Manohar/Rajesh added for SC-18101 */
        /* Manohar\Rajesh Modified for SC-18101 */
        SELECT
            schoolyearid
            INTO var_CurrentYear
            FROM dbo.rosterdataset
            WHERE isdefault = 1 AND instanceid = var_InstanceID;
        SELECT
            CASE
                WHEN aws_sqlserver_ext.ISNUMERIC(COALESCE(us.value, cs.value, ns.value, ins.value)) THEN CAST (COALESCE(us.value, cs.value, ns.value, ins.value) AS INTEGER)
                ELSE NULL
            END
            INTO var_RosterPYear
            FROM dbo.setting AS s
            JOIN dbo.instancesetting AS ins
                ON s.settingid = ins.settingid
            LEFT OUTER JOIN dbo.networksetting AS ns
                ON s.settingid = ns.settingid AND ins.sortorder = ns.sortorder AND networkid = par_UserNetworkID
            LEFT OUTER JOIN dbo.campussetting AS cs
                ON s.settingid = cs.settingid AND ins.sortorder = cs.sortorder AND campusid = par_UserCampusID
            LEFT OUTER JOIN dbo.usersetting AS us
                ON s.settingid = us.settingid AND ins.sortorder = us.sortorder AND useraccountid = var_UserAccountID
            WHERE instanceid = var_InstanceID AND s.shortname IN ('RstrVU');
        /* Sravani Balireddy: Modified below to check whether the district user is having any UserRole restrictions or not */
        SELECT
            value
            INTO var_CurrentStudent
            FROM dbo.instancesetting
            JOIN dbo.setting
                ON setting.settingid = instancesetting.settingid
            WHERE setting.shortname = 'CurrStutbl' AND instanceid = var_InstanceID;
        /* SC-25293: Added the below code to check data for DDI from App setting and Campus settings */

        IF EXISTS (SELECT
            1
            FROM dbo.appfncheckcampusapp(var_InstanceID, 'DDI', '-1', par_UserCampusID)
            LIMIT 1) THEN
            var_DDITab := 'Y';
        END IF;
        /* select @DDITab = Value from InstanceSetting join Setting on Setting.SettingID = InstanceSetting.SettingID */
        /* where Setting.ShortName = 'DDITab' and InstanceID = @InstanceID */
        /* Srinatha: Added below code to include NetworkID and to restrict calling of below function for @8.1 SC-7099/SC-8021 'Networks - Predefined Reports changes' task */

        IF var_AccessLevel IN ('A', 'D', 'N') OR (EXISTS (SELECT
            1
            FROM dbo.userrolegrade
            WHERE userroleid = par_UserRoleID
            LIMIT 1)) OR (EXISTS (SELECT
            1
            FROM dbo.userrolestudentgroup
            WHERE userroleid = par_UserRoleID
            LIMIT 1)) THEN
            var_appFnReportUserData := (SELECT
                dbo.appfnreportuserdata(par_UserRoleID, par_UserNetworkID));
        END IF;
        /* Manohar: just uncomment the below query for SC-1645 - Data access: Non-rostered students @7.1 release */
        SELECT
            value
            INTO var_PLCIsNonRostered
            FROM dbo.instancesetting
            JOIN dbo.setting
                ON setting.settingid = instancesetting.settingid
            WHERE setting.shortname = 'PLCNonRstr' AND instanceid = var_InstanceID;

        IF var_appFnReportUserData = '' AND par_UserCampusID = - 1 AND var_AccessLevel = 'D' AND (SELECT
            isdefault
            FROM dbo.rosterdataset
            WHERE rosterdatasetid = var_RosterDataSetID) = 1 AND (SELECT
            COUNT(*)
            FROM dbo.userrolestudentgroup
            WHERE userroleid = par_UserRoleID) = 0 THEN
            IF (var_CurrentStudent = 'Y') THEN
                var_RosterQuery := ' insert into #RosterStudents select distinct StudentID from CurrentStudent ';
            ELSE
                var_DistictValue := 1;
            END IF;
        ELSE
            var_RosterQuery := ' insert into #RosterStudents select distinct StudentClass.StudentID from ' || 'StudentClass Join Class on Class.ClassID = StudentClass.ClassID AND StudentClass.IsCurrent = 1' || ' INNER JOIN TeacherClass on Class.ClassID = TeacherClass.ClassID AND TeacherClass.IsCurrent = 1 ' || (CASE
                WHEN (SELECT
                    1
                    FROM dbo.userrolestudentgroup
                    WHERE userroleid = par_UserRoleID
                    LIMIT 1) = 1 THEN ' INNER JOIN StudentGroupStudent on StudentClass.StudentID = StudentGroupStudent.StudentID '
                ELSE ''
            END) || var_appFnReportUserData || ' where Class.RosterDataSetID = ' || CAST (var_RosterDataSetID AS VARCHAR(30)) ||
            CASE
                WHEN par_UserCampusID = '-1' THEN ''
                ELSE ' and Class.CampusID = ' || CAST (par_UserCampusID AS VARCHAR(30))
            END ||
            CASE
                WHEN par_UserTeacherID = '-1' THEN ''
                ELSE ' and TeacherClass.TeacherID = ' || CAST (par_UserTeacherID AS VARCHAR(30))
            END;
            /*
            set @StudentGrpQuery = ' insert into #RosterStudents
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
            select StudentID from #RosterStudents '
            */
            /* Srinatha : Commented above block and added below code to read correct Student groups to fix SC-22264 customer ticket. */
            CREATE TEMPORARY TABLE t$userstudentgroups
            (studentgroupid INTEGER PRIMARY KEY,
                publicrestricttosis NUMERIC(1, 0));
            INSERT INTO t$userstudentgroups (studentgroupid, publicrestricttosis)
            SELECT
                studentgroupid, publicrestricttosis
                FROM dbo.appfngetuserstudentgroups(var_InstanceID, var_UserAccountID, par_UserCampusID, par_UserNetworkID, var_RosterYearID);
            var_StudentGrpQuery := ' insert into #RosterStudents
			select distinct SGS.StudentID 
			from dbo.#UserStudentGroups SG
			join dbo.StudentGroupStudent  SGS with (nolock) on SGS.StudentGroupID = SG.StudentGroupID
			where SG.PublicRestrictToSIS = 0  
			except
			select StudentID from #RosterStudents ';
        END IF;
        /* Sravani Balireddy :Moved this code here to check PLC permissions */
        /* Srinatha: added below code for 7.0 SC-206 PLC Support for Reports task */
        CREATE TEMPORARY TABLE plcpermissions$appreportdefaultfilters
        (otname VARCHAR(100));
        INSERT INTO plcpermissions$appreportdefaultfilters
        SELECT
            objecttype.name
            FROM dbo.userrole
            JOIN dbo.rolepermission
                ON userrole.roleid = rolepermission.roleid
            JOIN dbo.permission
                ON permission.permissionid = rolepermission.permissionid
            JOIN dbo.objecttype
                ON objecttype.objecttypeid = permission.objecttypeid
            JOIN dbo.operation
                ON operation.operationid = permission.operationid
            WHERE operation.name = 'View' AND userrole.userroleid = par_UserRoleID AND COALESCE(rolepermission.scopecode, 'A') = 'A';
        /* Rajesh/Prasanna Modified for SC-19866 */

        IF EXISTS (SELECT
            1
            FROM plcpermissions$appreportdefaultfilters
            LIMIT 1) THEN
            var_IsPLCRolePerm := 1;
        END IF;
        /* Sravani Balireddy :Collecting all the PLCIDs with PLC permissions */

        IF var_IsPLCRolePerm = 1 THEN
            INSERT INTO t$plcids
            SELECT DISTINCT
                plcid
                FROM dbo.plcuser
                WHERE useraccountid = var_UserAccountID;
        END IF;

        IF var_DDITab = 'Y' AND (par_ReportType = '' OR par_ReportType = 'DDI') THEN
            /* DDI tab check\Start */
            var_AssessmentID := - 1;
            /* set the roster data set while will be used inside Roster query */
            SELECT
                aid, sbid
                INTO var_AssessmentID, var_SubjectID
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'DDI';
            /* Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup */
            /* and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1 */

            IF EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND plcid IN (SELECT
                    plcid
                    FROM t$plcids)
                LIMIT 1) AND var_PLCIsNonRostered = 'Y' THEN
                var_DistictValue := 1;
            END IF;
            /* Sravani Balireddy : these queries should not run for District user without Userrole restrictions */

            IF (var_DistictValue = 0) THEN
                RAISE NOTICE '%', var_RosterQuery;
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec(@RosterQuery)
                */
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec (@StudentGrpQuery)
                */
                /* Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test. */
                /* Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942 */
                /* 19-Oct-2020: Manohar - Modified to improve the performance -- added with (nolock) on testattempt table */
                IF NOT EXISTS (SELECT
                    1
                    FROM t$rosterstudents
                    WHERE EXISTS (SELECT
                        1
                        FROM dbo.testattempt
                        WHERE studentid = t$rosterstudents.studentid
                        LIMIT 1)) THEN
                    TRUNCATE TABLE t$rosterstudents;
                END IF;
                /* if there are no students from the default roster for the user then check in all other rosters */

                IF par_ReportType = '' AND NOT EXISTS (SELECT
                    1
                    FROM t$rosterstudents
                    LIMIT 1) THEN
                    var_RosterQuery := ' insert into #RosterStudents select distinct StudentClass.StudentID from ' || 'StudentClass Join Class on Class.ClassID = StudentClass.ClassID AND StudentClass.IsCurrent = 1' || ' INNER JOIN TeacherClass on Class.ClassID = TeacherClass.ClassID AND TeacherClass.IsCurrent = 1 ' || (CASE
                        WHEN (SELECT
                            1
                            FROM dbo.userrolestudentgroup
                            WHERE userroleid = par_UserRoleID
                            LIMIT 1) = 1 THEN ' INNER JOIN StudentGroupStudent on StudentClass.StudentID = StudentGroupStudent.StudentID '
                        ELSE ''
                    END) || var_appFnReportUserData || ' where 1 = 1 ' ||
                    CASE
                        WHEN par_UserCampusID = '-1' THEN ''
                        ELSE ' and Class.CampusID = ' || CAST (par_UserCampusID AS VARCHAR(30))
                    END ||
                    CASE
                        WHEN par_UserTeacherID = '-1' THEN ''
                        ELSE ' and TeacherClass.TeacherID = ' || CAST (par_UserTeacherID AS VARCHAR(30))
                    END;
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec(@RosterQuery)
                    */
                    /* Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942 */
                    IF NOT EXISTS (SELECT
                        1
                        FROM t$rosterstudents
                        WHERE EXISTS (SELECT
                            1
                            FROM dbo.testattempt
                            WHERE studentid = t$rosterstudents.studentid
                            LIMIT 1)) THEN
                        TRUNCATE TABLE t$rosterstudents;
                    END IF;
                END IF;
                /* Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue. */
                /* insert student group students (if any) */
                /* if not exists (select top 1 1 from #RosterStudents) */
                /* exec(@StudentGrpQuery) */
            END IF;
            /* check the current assessment has valid scores for the user */

            IF (EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND hasscores = 1 AND activecode = 'A'
                LIMIT 1) AND (SELECT
                dbo.fn_embargogetembargostatus(var_AssessmentID, par_UserRoleID, var_UserAccountID)) = 0) THEN
                /* Sravani Balireddy : Considering Assessment without checking Rosterstudents for District user without Userrole restrictions */
                IF (var_DistictValue = 1) THEN
                    TRUNCATE TABLE t$hasassessdata;
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                ELSE
                    TRUNCATE TABLE t$hasassessdata;
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN t$rosterstudents AS rs
                            ON testattempt.studentid = rs.studentid
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                END IF;
            END IF;
            /* run the below only when it is called from Launchpad page */
            /* if the current assessment is not exists then check for other assessment for the user */

            IF par_ReportType = '' AND NOT EXISTS (SELECT
                1
                FROM t$hasassessdata
                LIMIT 1) THEN
                /* 19-Oct-2020: Manohar - Modified to improve the performance -- added IsEmbargoed column to avoid assessments that are not embargoed passing to the embargo functions */
                CREATE TEMPORARY TABLE t$tmpddiassessment
                (assessmentid INTEGER PRIMARY KEY,
                    isembargoed NUMERIC(1, 0) DEFAULT 0);
                /* Sravani Balireddy :Modified to add the PLC Assessments */
                var_ResultQuery := ' insert into #tmpDDIAssessment (AssessmentID, IsEmbargoed)   
			select Distinct Assessment.AssessmentID, Assessment.IsEmbargoed From Assessment where Assessment.ActiveCode = ''A'' and Assessment.InstanceID = ' || CAST (var_InstanceID AS VARCHAR(30)) || ' AND Assessment.IsAFL = 0 AND Assessment.CIStatusCode != ''C'' ';

                IF var_AccessLevel = 'D' OR var_AccessLevel = 'A' OR var_AccessLevel = 'C' OR var_AccessLevel = 'T' OR var_AccessLevel = 'N' THEN
                    var_ResultQuery := var_ResultQuery || ' AND ( LevelCode = ''D''';
                END IF;

                IF var_AccessLevel = 'N' THEN
                    /* Srinatha: added Network assessment code for @8.1 SC-7099/SC-8021 'Networks - Predefined Reports changes' task */
                    var_ResultQuery := var_ResultQuery || ' OR (LevelCode = ''N'' And LevelOwnerID = ' || CAST (par_UserNetworkID AS VARCHAR(10)) || ')';
                END IF;

                IF var_AccessLevel = 'C' OR var_AccessLevel = 'T' THEN
                    var_ResultQuery := var_ResultQuery || ' OR (LevelCode = ''C'' And LevelOwnerID = ' || CAST (par_UserCampusID AS VARCHAR(30)) || ')' || ' OR ( LevelCode = ''N'' And exists (select top 1 1 from NetworkCampus where NetWorkID = LevelOwnerID and CampusID = ' || CAST (par_UserCampusID AS VARCHAR(15)) || '))';
                END IF;

                IF var_AccessLevel = 'T' THEN
                    var_ResultQuery := var_ResultQuery || ' OR (LevelCode = ''U'' And LevelOwnerID = ' || CAST (var_UserAccountID AS VARCHAR(30)) || ')';
                END IF;

                IF var_AccessLevel IN ('D', 'A', 'C', 'T', 'N') THEN
                    var_ResultQuery := var_ResultQuery || ')';
                END IF;
                var_ResultQuery := var_ResultQuery || ' and (PLCID is null or PLCID in (select PLCID from #PLCIDs))';
                /* Sravani Balireddy :Collecting all Non PLC Assessments */
                RAISE NOTICE '%', var_ResultQuery;
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec (@ResultQuery)
                */
                UPDATE t$tmpddiassessment AS tmpa
                SET isembargoed = isemb
                FROM (SELECT
                    assessmentid, dbo.fn_embargogetembargostatus(assessmentid, par_UserRoleID, var_UserAccountID) AS isemb
                    FROM t$tmpddiassessment) AS tmpb
                    WHERE tmpa.assessmentid = tmpb.assessmentid AND isembargoed = 1;
                /* 19-Oct-2020: Manohar - Modified to improve the performance -- added Embargo condition */
                DELETE FROM t$tmpddiassessment
                    WHERE isembargoed = 1;
                /* Sravani Balireddy : Considering Assessment without checking Rosterstudents for District user without Userrole restrictions */

                IF (var_DistictValue = 1) THEN
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        assessmentform.assessmentformid
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN t$tmpddiassessment AS tass
                            ON tass.assessmentid = assessmentform.assessmentid;
                ELSE
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        assessmentform.assessmentformid
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN t$tmpddiassessment AS tass
                            ON tass.assessmentid = assessmentform.assessmentid
                        /* Join #RosterStudents on TestAttempt.StudentID = #RosterStudents.StudentID */
                        /* 19-Oct-2020: Manohar - Modified to improve the performance -- changed to exists */
                        WHERE EXISTS (SELECT
                            1
                            FROM t$rosterstudents
                            WHERE studentid = testattempt.studentid
                            LIMIT 1);
                END IF;
                /* if none of the assessments statisfies the DDI assessment condition then delete the record from #HasAssessData */

                IF NOT EXISTS ((SELECT
                    1
                    FROM t$hasassessdata AS af
                    JOIN dbo.scoretopic AS st
                        ON af.value = st.assessmentformid
                    WHERE st.typecode = 'T'
                LIMIT 1)
                UNION
                (SELECT
                    1
                    FROM t$hasassessdata AS t
                    JOIN dbo.assessmentitem AS ai
                        ON t.value = ai.assessmentformid
                LIMIT 1)) THEN
                    /* delete data from #HasAssessData if not exists */
                    TRUNCATE TABLE t$hasassessdata;
                END IF;
            END IF;

            IF EXISTS (SELECT
                1
                FROM t$hasassessdata
                LIMIT 1) THEN
                /* if exists */
                var_bDDIReport := 1;
                var_bPreDefinedReport := 1;
            ELSE
                /* if not any assessment exists */
                TRUNCATE TABLE t$hasassessdata;
                DELETE FROM alltypevalues$appreportdefaultfilters
                    WHERE rt = 'DDI';
                var_bPreDefinedReport := 0;
                var_bDDIReport := 0;
            END IF;
        END IF;
        /* DDI tab check\end */
        /* if it is called from Launchpad and already @bPreDefinedReport is set to 1 then no need to run the below code */

        IF (par_ReportType = '' AND var_bPreDefinedReport = 0) OR (par_ReportType = 'P' AND var_bFromLMS = 0) THEN
            /* Predefined tab check\Start */
            TRUNCATE TABLE t$hasassessdata;
            TRUNCATE TABLE t$rosterstudents;
            var_AssessmentID := - 1;
            /* set the roster data set while will be used inside Roster query */
            SELECT
                aid, sbid
                INTO var_AssessmentID, var_SubjectID
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'P';
            /* Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup */
            /* and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1 */

            IF EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND plcid IN (SELECT
                    plcid
                    FROM t$plcids)
                LIMIT 1) AND var_PLCIsNonRostered = 'Y' THEN
                var_DistictValue := 1;
            END IF;
            /* Sravani Balireddy : these queries should not run for District user without Userrole restrictions */

            IF (var_DistictValue = 0) THEN
                RAISE NOTICE '%', var_RosterQuery;
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec(@RosterQuery)
                */
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec (@StudentGrpQuery)
                */
                /* Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test. */
                /* Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942 */
                IF NOT EXISTS (SELECT
                    1
                    FROM t$rosterstudents
                    WHERE EXISTS (SELECT
                        1
                        FROM dbo.testattempt
                        WHERE studentid = t$rosterstudents.studentid
                        LIMIT 1)) THEN
                    TRUNCATE TABLE t$rosterstudents;
                END IF;
                /* if there are no students from the default roster for the user then check in all other rosters */

                IF par_ReportType = '' AND NOT EXISTS (SELECT
                    1
                    FROM t$rosterstudents
                    LIMIT 1) THEN
                    var_RosterQuery := ' insert into #RosterStudents select distinct StudentClass.StudentID from ' || 'StudentClass Join Class on Class.ClassID = StudentClass.ClassID AND StudentClass.IsCurrent = 1' || ' INNER JOIN TeacherClass on Class.ClassID = TeacherClass.ClassID AND TeacherClass.IsCurrent = 1 ' || (CASE
                        WHEN (SELECT
                            1
                            FROM dbo.userrolestudentgroup
                            WHERE userroleid = par_UserRoleID
                            LIMIT 1) = 1 THEN ' INNER JOIN StudentGroupStudent on StudentClass.StudentID = StudentGroupStudent.StudentID '
                        ELSE ''
                    END) || var_appFnReportUserData || ' where 1 = 1 ' ||
                    CASE
                        WHEN par_UserCampusID = '-1' THEN ''
                        ELSE ' and Class.CampusID = ' || CAST (par_UserCampusID AS VARCHAR(30))
                    END ||
                    CASE
                        WHEN par_UserTeacherID = '-1' THEN ''
                        ELSE ' and TeacherClass.TeacherID = ' || CAST (par_UserTeacherID AS VARCHAR(30))
                    END;
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec(@RosterQuery)
                    */
                    /* Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942 */
                    IF NOT EXISTS (SELECT
                        1
                        FROM t$rosterstudents
                        WHERE EXISTS (SELECT
                            1
                            FROM dbo.testattempt
                            WHERE studentid = t$rosterstudents.studentid
                            LIMIT 1)) THEN
                        TRUNCATE TABLE t$rosterstudents;
                    END IF;
                END IF;
                /* Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue. */
                /* -- insert student group students (if any) */
                /* if not exists (select top 1 1 from #RosterStudents) */
                /* exec(@StudentGrpQuery) */
            END IF;
            /* check the current assessment has valid scores for the user */

            IF (EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND hasscores = 1 AND activecode = 'A'
                LIMIT 1) AND (SELECT
                dbo.fn_embargogetembargostatus(var_AssessmentID, par_UserRoleID, var_UserAccountID)) = 0) THEN
                /* Sravani Balireddy : Considering Assessment without checking Rosterstudents for District user without Userrole restrictions */
                IF (var_DistictValue = 1) THEN
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                ELSE
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN t$rosterstudents AS rs
                            ON testattempt.studentid = rs.studentid
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                END IF;
            END IF;
            /* run the below only when it is called from Launchpad page */
            /* if the current assessment is not exists then check for other assessment for the user */

            IF par_ReportType = '' AND NOT EXISTS (SELECT
                1
                FROM t$hasassessdata
                LIMIT 1) AND var_AccessLevel <> 'T' THEN
                /* Manohar\Rajesh Modified for SC-18101 */
                INSERT INTO t$hasassessdata
                SELECT
                    1
                    FROM dbo.testattempt
                    JOIN t$rosterstudents
                        ON testattempt.studentid = t$rosterstudents.studentid
                    LIMIT 1;
            END IF;

            IF EXISTS (SELECT
                1
                FROM t$hasassessdata
                LIMIT 1) THEN
                var_bPreDefinedReport := 1;
            ELSE
                TRUNCATE TABLE t$hasassessdata;
                DELETE FROM alltypevalues$appreportdefaultfilters
                    WHERE rt = 'P';
                var_bPreDefinedReport := 0;
            END IF;
        END IF;
        /* Predefined tab check\End */
        /* it is called from the report tab */

        IF par_ReportType = 'PE' THEN
            /* Principal Exch tab check\Start */
            TRUNCATE TABLE t$hasassessdata;
            TRUNCATE TABLE t$rosterstudents;
            var_AssessmentID := - 1;
            /* set the roster data set while will be used inside Roster query */
            SELECT
                aid, sbid
                INTO var_AssessmentID, var_SubjectID
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'PE';
            /* Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup */
            /* and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1 */

            IF EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND plcid IN (SELECT
                    plcid
                    FROM t$plcids)
                LIMIT 1) AND var_PLCIsNonRostered = 'Y' THEN
                var_DistictValue := 1;
            END IF;
            /* Sravani Balireddy : these queries should not run for District user without Userrole restrictions */

            IF (var_DistictValue = 0) THEN
                RAISE NOTICE '%', var_RosterQuery;
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec(@RosterQuery)
                */
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec (@StudentGrpQuery)
                */
                /* Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test. */
                /* Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942 */
                IF NOT EXISTS (SELECT
                    1
                    FROM t$rosterstudents
                    WHERE EXISTS (SELECT
                        1
                        FROM dbo.testattempt
                        WHERE studentid = t$rosterstudents.studentid
                        LIMIT 1)) THEN
                    TRUNCATE TABLE t$rosterstudents;
                END IF;
                /* Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue. */
                /* insert student group students (if any) */
                /* if not exists (select top 1 1 from #RosterStudents) */
                /* exec(@StudentGrpQuery) */
            END IF;
            /* check the current assessment has valid scores for the user */

            IF (EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND hasscores = 1 AND activecode = 'A'
                LIMIT 1) AND (SELECT
                dbo.fn_embargogetembargostatus(var_AssessmentID, par_UserRoleID, var_UserAccountID)) = 0) THEN
                /* Sravani Balireddy : Considering Assessment without checking Rosterstudents for District user without Userrole restrictions */
                IF (var_DistictValue = 1) THEN
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN dbo.scoretopic
                            ON assessmentform.assessmentformid = scoretopic.assessmentformid
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID AND scoretopic.typecode = 'T'
                        GROUP BY assessmentform.assessmentid
                        HAVING COUNT(DISTINCT scoretopic.standardid) = '5'
                        LIMIT 1;
                ELSE
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN t$rosterstudents AS rs
                            ON testattempt.studentid = rs.studentid
                        JOIN dbo.scoretopic
                            ON assessmentform.assessmentformid = scoretopic.assessmentformid
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID AND scoretopic.typecode = 'T'
                        GROUP BY assessmentform.assessmentid
                        HAVING COUNT(DISTINCT scoretopic.standardid) = '5'
                        LIMIT 1;
                END IF;
            END IF;

            IF EXISTS (SELECT
                1
                FROM t$hasassessdata
                LIMIT 1) THEN
                var_bPEReport := 1;
            ELSE
                TRUNCATE TABLE t$hasassessdata;
                DELETE FROM alltypevalues$appreportdefaultfilters
                    WHERE rt = 'PE';
                var_bPEReport := 0;
            END IF;
        END IF;
        /* Principal Exch tab check\End */
        /* it is called from the SBAC report tab */

        IF par_ReportType = 'S' THEN
            /* SBAC tab check\Start */
            TRUNCATE TABLE t$hasassessdata;
            TRUNCATE TABLE t$rosterstudents;
            var_AssessmentID := - 1;
            /* set the roster data set while will be used inside Roster query */
            SELECT
                aid, sbid
                INTO var_AssessmentID, var_SubjectID
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'S';
            /* Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup */
            /* and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1 */

            IF EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND plcid IN (SELECT
                    plcid
                    FROM t$plcids)
                LIMIT 1) AND var_PLCIsNonRostered = 'Y' THEN
                var_DistictValue := 1;
            END IF;

            IF (var_DistictValue = 0) THEN
                RAISE NOTICE '%', var_RosterQuery;
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec(@RosterQuery)
                */
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec (@StudentGrpQuery)
                */
                /* Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test. */
                /* Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942 */
                IF NOT EXISTS (SELECT
                    1
                    FROM t$rosterstudents
                    WHERE EXISTS (SELECT
                        1
                        FROM dbo.testattempt
                        WHERE studentid = t$rosterstudents.studentid
                        LIMIT 1)) THEN
                    TRUNCATE TABLE t$rosterstudents;
                END IF;
                /* Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue. */
                /* insert student group students (if any) */
                /* if not exists (select top 1 1 from #RosterStudents) */
                /* exec(@StudentGrpQuery) */
            END IF;
            /* check the current assessment has valid scores for the user */

            IF (EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND hasscores = 1 AND activecode = 'A'
                LIMIT 1) AND (SELECT
                dbo.fn_embargogetembargostatus(var_AssessmentID, par_UserRoleID, var_UserAccountID)) = 0) THEN
                IF (var_DistictValue = 1) THEN
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN dbo.assessment
                            ON assessment.assessmentid = assessmentform.assessmentid AND assessment.publisherextid = 'SC-SBAC-SUMMATIVE'
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                ELSE
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN t$rosterstudents AS rs
                            ON testattempt.studentid = rs.studentid
                        JOIN dbo.assessment
                            ON assessment.assessmentid = assessmentform.assessmentid AND assessment.publisherextid = 'SC-SBAC-SUMMATIVE'
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                END IF;
            END IF;

            IF EXISTS (SELECT
                1
                FROM t$hasassessdata
                LIMIT 1) THEN
                var_bSBACReport := 1;
            ELSE
                TRUNCATE TABLE t$hasassessdata;
                DELETE FROM alltypevalues$appreportdefaultfilters
                    WHERE rt = 'S';
                var_bSBACReport := 0;
            END IF;
        END IF;
        /* SBAC tab check\End */
        /* Rajesh  Modified for SC-15445 Horizon ACT Student Summary Report for Staff Users */
        /* it is called from the Horizon report tab */
        /* Horizon Report tab check\Start */

        IF par_ReportType = 'H' THEN
            TRUNCATE TABLE t$hasassessdata;
            TRUNCATE TABLE t$rosterstudents;
            var_AssessmentID := - 1;
            /* set the roster data set while will be used inside Roster query */
            SELECT
                aid, sbid
                INTO var_AssessmentID, var_SubjectID
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'H';

            IF EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND plcid IN (SELECT
                    plcid
                    FROM t$plcids)
                LIMIT 1) AND var_PLCIsNonRostered = 'Y' THEN
                var_DistictValue := 1;
            END IF;

            IF (var_DistictValue = 0) THEN
                RAISE NOTICE '%', var_RosterQuery;
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec(@RosterQuery)
                */
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec (@StudentGrpQuery)
                */
                IF NOT EXISTS (SELECT
                    1
                    FROM t$rosterstudents
                    WHERE EXISTS (SELECT
                        1
                        FROM dbo.testattempt
                        WHERE studentid = t$rosterstudents.studentid
                        LIMIT 1)) THEN
                    TRUNCATE TABLE t$rosterstudents;
                END IF;
            END IF;
            /* check the current assessment has valid scores for the user */

            IF (EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND hasscores = 1 AND activecode = 'A'
                LIMIT 1) AND (SELECT
                dbo.fn_embargogetembargostatus(var_AssessmentID, par_UserRoleID, var_UserAccountID)) = 0) THEN
                IF (var_DistictValue = 1) THEN
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN dbo.assessment
                            ON assessment.assessmentid = assessmentform.assessmentid AND assessment.specialassessmenttabid = 16 AND assessment.typecode = 'P' AND assessment.activecode = 'A'
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                ELSE
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN t$rosterstudents AS rs
                            ON testattempt.studentid = rs.studentid
                        JOIN dbo.assessment
                            ON assessment.assessmentid = assessmentform.assessmentid AND assessment.specialassessmenttabid = 16 AND assessment.typecode = 'P' AND assessment.activecode = 'A'
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                END IF;
            END IF;

            IF EXISTS (SELECT
                1
                FROM t$hasassessdata
                LIMIT 1) THEN
                var_HReport := 1;
            ELSE
                TRUNCATE TABLE t$hasassessdata;
                DELETE FROM alltypevalues$appreportdefaultfilters
                    WHERE rt = 'H';
                var_HReport := 0;
            END IF;
        END IF;
        /* Horizon Report tab check\End */
        /* it is called from the Lead4Ward report tab */

        IF par_ReportType = 'L' THEN
            /* Lead4Ward tab check\Start */
            TRUNCATE TABLE t$hasassessdata;
            TRUNCATE TABLE t$rosterstudents;
            var_AssessmentID := - 1;
            CREATE TEMPORARY TABLE t$tmpassessmentids
            (assessmentid INTEGER PRIMARY KEY);
            /* START Done the changes Revise Academic Growth Template UI : ChinnaReddy */
            SELECT
                value
                INTO var_L4WMenuXML
                FROM dbo.instancesetting
                WHERE settingid = (SELECT
                    settingid
                    FROM dbo.setting
                    WHERE name = 'L4WMenuPGM') AND instanceid = var_InstanceID;
            CREATE TEMPORARY TABLE t$l4wtemplatetable
            (templateid INTEGER PRIMARY KEY);
            /*
            [7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.VALUE(VARCHAR,VARCHAR) data type. Convert your source code manually., 7708 - Severity CRITICAL - DMS SC can't convert the usage of the unsupported XML.NODES(VARCHAR) data type. Convert your source code manually.]
            insert into #l4wTemplateTable
            		select distinct item newTemplateID from
            		(
            			select
            			   objNode.value('@ID', 'varchar(max)') TemplateID
            			from
            			 @L4WMenuXML.nodes('/L4WMenuPGM/L4WSubject/Template') nodeset(objNode)
            
            		) A cross apply dbo.fn_split(TemplateID,',')
            		order by newTemplateID asc
            */
            /* SC-3077-Run Academic Growth Template and load filter values */
            /* if @TemplateID <> '' and @TemplateID <> '-1' */
            /* begin */
            /* END Done the changes Revise Academic Growth Template UI : ChinnaReddy */
            var_Query := '
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
			A.InstanceID = ' || CAST (var_InstanceID AS VARCHAR(30)) || ' and A.ActiveCode = ''A'' and AFF.Name = ''STAAR'' and AFF.CategoryList = ''STATE''  ';
            RAISE NOTICE '%', var_Query;
            /*
            [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
            exec(@Query)
            */
            /* end */
            /* set the roster data set while will be used inside Roster query */
            SELECT
                aid, sbid
                INTO var_AssessmentID, var_SubjectID
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'L';
            /* Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup */
            /* and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1 */

            IF EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND plcid IN (SELECT
                    plcid
                    FROM t$plcids)
                LIMIT 1) AND var_PLCIsNonRostered = 'Y' THEN
                var_DistictValue := 1;
            END IF;
            /* SC-3077-Run Academic Growth Template and load filter values */

            IF NOT EXISTS (SELECT
                1
                FROM t$tmpassessmentids
                WHERE assessmentid = var_AssessmentID
                LIMIT 1) THEN
                DELETE FROM alltypevalues$appreportdefaultfilters
                    WHERE rt = 'L';
                var_bLFReport := 0;
            ELSE
                IF (var_DistictValue = 0) THEN
                    RAISE NOTICE '%', var_RosterQuery;
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec(@RosterQuery)
                    */
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    exec (@StudentGrpQuery)
                    */
                    /* Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test. */
                    /* Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942 */
                    IF NOT EXISTS (SELECT
                        1
                        FROM t$rosterstudents
                        WHERE EXISTS (SELECT
                            1
                            FROM dbo.testattempt
                            WHERE studentid = t$rosterstudents.studentid
                            LIMIT 1)) THEN
                        TRUNCATE TABLE t$rosterstudents;
                    END IF;
                    /* Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue. */
                    /* insert student group students (if any) */
                    /* if not exists (select top 1 1 from #RosterStudents) */
                    /* exec(@StudentGrpQuery) */
                END IF;
                /* check the current assessment has valid scores for the user */

                IF (EXISTS (SELECT
                    1
                    FROM dbo.assessment
                    WHERE assessmentid = var_AssessmentID AND hasscores = 1 AND activecode = 'A'
                    LIMIT 1) AND (SELECT
                    dbo.fn_embargogetembargostatus(var_AssessmentID, par_UserRoleID, var_UserAccountID)) = 0) THEN
                    IF (var_DistictValue = 1) THEN
                        INSERT INTO t$hasassessdata
                        SELECT DISTINCT
                            1
                            FROM dbo.testattempt
                            JOIN dbo.assessmentform
                                ON testattempt.assessmentformid = assessmentform.assessmentformid
                            JOIN dbo.assessment AS a
                                ON a.assessmentid = assessmentform.assessmentid AND a.assessmentfamilyid = 123
                            WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                            LIMIT 1;
                    ELSE
                        INSERT INTO t$hasassessdata
                        SELECT DISTINCT
                            1
                            FROM dbo.testattempt
                            JOIN dbo.assessmentform
                                ON testattempt.assessmentformid = assessmentform.assessmentformid
                            JOIN t$rosterstudents AS rs
                                ON testattempt.studentid = rs.studentid
                            JOIN dbo.assessment AS a
                                ON a.assessmentid = assessmentform.assessmentid AND a.assessmentfamilyid = 123
                            WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                            LIMIT 1;
                    END IF;
                END IF;

                IF EXISTS (SELECT
                    1
                    FROM t$hasassessdata
                    LIMIT 1) THEN
                    var_bLFReport := 1;
                ELSE
                    TRUNCATE TABLE t$hasassessdata;
                    DELETE FROM alltypevalues$appreportdefaultfilters
                        WHERE rt = 'L';
                    var_bLFReport := 0;
                END IF;
            END IF;
        END IF;
        /* Lead4Ward tab check\End */
        /* it is called from the BRR report tab */

        IF par_ReportType = 'BRR' THEN
            /* BRR tab check\Start */
            TRUNCATE TABLE t$hasassessdata;
            TRUNCATE TABLE t$rosterstudents;
            var_AssessmentID := - 1;
            /* set the roster data set while will be used inside Roster query */
            SELECT
                aid, sbid
                INTO var_AssessmentID, var_SubjectID
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'BRR';
            /* Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup */
            /* and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1 */

            IF EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND plcid IN (SELECT
                    plcid
                    FROM t$plcids)
                LIMIT 1) AND var_PLCIsNonRostered = 'Y' THEN
                var_DistictValue := 1;
            END IF;

            IF (var_DistictValue = 0) THEN
                RAISE NOTICE '%', var_RosterQuery;
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec(@RosterQuery)
                */
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec (@StudentGrpQuery)
                */
                /* Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test. */
                /* Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942 */
                IF NOT EXISTS (SELECT
                    1
                    FROM t$rosterstudents
                    WHERE EXISTS (SELECT
                        1
                        FROM dbo.testattempt
                        WHERE studentid = t$rosterstudents.studentid
                        LIMIT 1)) THEN
                    TRUNCATE TABLE t$rosterstudents;
                END IF;
                /* Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue. */
                /* insert student group students (if any) */
                /* if not exists (select top 1 1 from #RosterStudents) */
                /* exec(@StudentGrpQuery) */
            END IF;
            /* check the current assessment has valid scores for the user */

            IF (EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND hasscores = 1 AND activecode = 'A'
                LIMIT 1) AND (SELECT
                dbo.fn_embargogetembargostatus(var_AssessmentID, par_UserRoleID, var_UserAccountID)) = 0) THEN
                IF (var_DistictValue = 1) THEN
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN dbo.assessment
                            ON assessment.assessmentid = assessmentform.assessmentid
                        JOIN dbo.taglink
                            ON assessment.assessmentid = taglink.objectid
                        JOIN dbo.tag
                            ON tag.tagid = taglink.tagid AND (tag.name IN ('FountasAndPinnellT1', 'FountasAndPinnellT2', 'FountasAndPinnellT3') OR tag.name LIKE '%BRR%')
                        JOIN dbo.objecttype
                            ON taglink.objecttypeid = objecttype.objecttypeid AND objecttype.name = 'Assessment'
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                ELSE
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN t$rosterstudents AS rs
                            ON testattempt.studentid = rs.studentid
                        JOIN dbo.assessment
                            ON assessment.assessmentid = assessmentform.assessmentid
                        JOIN dbo.taglink
                            ON assessment.assessmentid = taglink.objectid
                        JOIN dbo.tag
                            ON tag.tagid = taglink.tagid AND (tag.name IN ('FountasAndPinnellT1', 'FountasAndPinnellT2', 'FountasAndPinnellT3') OR tag.name LIKE '%BRR%')
                        JOIN dbo.objecttype
                            ON taglink.objecttypeid = objecttype.objecttypeid AND objecttype.name = 'Assessment'
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                END IF;
            END IF;

            IF EXISTS (SELECT
                1
                FROM t$hasassessdata
                LIMIT 1) THEN
                var_bBRReport := 1;
            ELSE
                TRUNCATE TABLE t$hasassessdata;
                DELETE FROM alltypevalues$appreportdefaultfilters
                    WHERE rt = 'BRR';
                var_bBRReport := 0;
            END IF;
        END IF;
        /* BRR tab check\End */
        /* it is called from the C&I report tab */

        IF par_ReportType = 'C' THEN
            /* C&I tab check\Start */
            TRUNCATE TABLE t$hasassessdata;
            TRUNCATE TABLE t$rosterstudents;
            var_AssessmentID := - 1;
            /* set the roster data set while will be used inside Roster query */
            SELECT
                aid, sbid
                INTO var_AssessmentID, var_SubjectID
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'C';
            /* Manohar: Modified to fix the ticket SC-6030 - Added the below code to check if the Assessment is PLC and the user is part of the selected PLCGroup */
            /* and NonRoster is enabled then no need of checking roster students so setting @DistictValue to 1 */

            IF EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND plcid IN (SELECT
                    plcid
                    FROM t$plcids)
                LIMIT 1) AND var_PLCIsNonRostered = 'Y' THEN
                var_DistictValue := 1;
            END IF;

            IF (var_DistictValue = 0) THEN
                RAISE NOTICE '%', var_RosterQuery;
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec(@RosterQuery)
                */
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec (@StudentGrpQuery)
                */
                /* Khushboo: added this line to fix sc-10070 issue to include RosterStudents along with student group students taken the test. */
                /* Athar/Sravani:considering Students from StudentGroup if Roster Students have not taken any test to fix ticket  ZDT 30942 */
                IF NOT EXISTS (SELECT
                    1
                    FROM t$rosterstudents
                    WHERE EXISTS (SELECT
                        1
                        FROM dbo.testattempt
                        WHERE studentid = t$rosterstudents.studentid
                        LIMIT 1)) THEN
                    TRUNCATE TABLE t$rosterstudents;
                END IF;
                /* Khushboo: commented the below code as #RosterStudents should always include both roster and studentGroup students - to fix sc-10070 issue. */
                /* insert student group students (if any) */
                /* if not exists (select top 1 1 from #RosterStudents) */
                /* exec(@StudentGrpQuery) */
            END IF;
            /* check the current assessment has valid scores for the user */

            IF (EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND hasscores = 1 AND activecode = 'A'
                LIMIT 1) AND (SELECT
                dbo.fn_embargogetembargostatus(var_AssessmentID, par_UserRoleID, var_UserAccountID)) = 0) THEN
                IF (var_DistictValue = 1) THEN
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN dbo.assessment
                            ON assessment.assessmentid = assessmentform.assessmentid
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND (assessment.cistatuscode IN ('C') OR assessment.isafl = 1) AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                ELSE
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN t$rosterstudents AS rs
                            ON testattempt.studentid = rs.studentid
                        JOIN dbo.assessment
                            ON assessment.assessmentid = assessmentform.assessmentid
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND (assessment.cistatuscode IN ('C') OR assessment.isafl = 1) AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                END IF;
            END IF;

            IF EXISTS (SELECT
                1
                FROM t$hasassessdata
                LIMIT 1) THEN
                var_bCIReport := 1;
            ELSE
                TRUNCATE TABLE t$hasassessdata;
                DELETE FROM alltypevalues$appreportdefaultfilters
                    WHERE rt = 'C';
                var_bCIReport := 0;
            END IF;
        END IF;
        /* C&I tab check\End */
        /* two cases: The below block will run */
        /* 1. when it is called from Launchpad and no assessments establsihed for DDI or PreDefined ) */
        /* 2. when it is called from the report tab and existing Assessment doesn't satisfy the report rules */
        /* Madhushree K: Added for [SC-24018] */
        /* Interim Report check START */

        IF par_ReportType = 'INTR' THEN
            TRUNCATE TABLE t$hasassessdata;
            TRUNCATE TABLE t$rosterstudents;
            var_AssessmentID := - 1;
            SELECT
                aid, sbid
                INTO var_AssessmentID, var_SubjectID
                FROM alltypevalues$appreportdefaultfilters
                WHERE rt = 'INTR';

            IF EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND plcid IN (SELECT
                    plcid
                    FROM t$plcids)
                LIMIT 1) AND var_PLCIsNonRostered = 'Y' THEN
                var_DistictValue := 1;
            END IF;

            IF (var_DistictValue = 0) THEN
                RAISE NOTICE '%', var_RosterQuery;
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec(@RosterQuery)
                */
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec (@StudentGrpQuery)
                */
                IF NOT EXISTS (SELECT
                    1
                    FROM t$rosterstudents
                    WHERE EXISTS (SELECT
                        1
                        FROM dbo.testattempt
                        WHERE studentid = t$rosterstudents.studentid
                        LIMIT 1)) THEN
                    TRUNCATE TABLE t$rosterstudents;
                END IF;
            END IF;
            /* check the current assessment has valid scores for the user */

            IF (EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID AND hasscores = 1 AND activecode = 'I'
                LIMIT 1) AND (SELECT
                dbo.fn_embargogetembargostatus(var_AssessmentID, par_UserRoleID, var_UserAccountID)) = 0) THEN
                IF (var_DistictValue = 1) THEN
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN dbo.assessment
                            ON assessment.assessmentid = assessmentform.assessmentid
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                ELSE
                    INSERT INTO t$hasassessdata
                    SELECT DISTINCT
                        1
                        FROM dbo.testattempt
                        JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        JOIN t$rosterstudents AS rs
                            ON testattempt.studentid = rs.studentid
                        JOIN dbo.assessment
                            ON assessment.assessmentid = assessmentform.assessmentid
                        WHERE testattempt.isvalid = 1 AND assessmentform.assessmentid = var_AssessmentID AND assessmentform.subjectid = var_SubjectID
                        LIMIT 1;
                END IF;
            END IF;

            IF EXISTS (SELECT
                1
                FROM t$hasassessdata
                LIMIT 1) THEN
                var_InterimReport := 1;
            ELSE
                TRUNCATE TABLE t$hasassessdata;
                DELETE FROM alltypevalues$appreportdefaultfilters
                    WHERE rt = 'INTR';
                var_InterimReport := 0;
            END IF;
        END IF;
        /* Interim Report check END */
        /* Madhushree K: Modified for [SC-24018] */

        IF (par_ReportType != '' AND var_bPreDefinedReport = 0 AND var_bDDIReport = 0 AND var_bLFReport = 0 AND var_bSBACReport = 0 AND var_HReport = 0 AND var_bPEReport = 0 AND var_bBRReport = 0 AND var_bCIReport = 0 AND var_InterimReport = 0) THEN
            CREATE TEMPORARY TABLE t$rosterinfo
            (schoolyearid INTEGER,
                schoolyearname VARCHAR(200),
                rosterdatasetid INTEGER,
                name VARCHAR(200),
                isdefault NUMERIC(1, 0));
            CREATE TEMPORARY TABLE t$assessmentforminfo
            (assessmentformid INTEGER PRIMARY KEY);
            CREATE TEMPORARY TABLE t$testattempt
            (studentid INTEGER PRIMARY KEY);
            CREATE TEMPORARY TABLE t$tmpassessments
            (assessmentid INTEGER PRIMARY KEY,
                isembargoed NUMERIC(1, 0));

            IF EXISTS (SELECT
                1
                FROM dbo.assessment
                WHERE assessmentid = par_AID::INTEGER AND plcid IN (SELECT
                    plcid
                    FROM t$plcids)
                LIMIT 1) AND var_PLCIsNonRostered = 'Y' THEN
                /* Madhushree K : Added for [SC-10389] */
                var_DistictValue := 1;
            END IF;

            IF par_ReportType = 'L' THEN
                CREATE TEMPORARY TABLE t$tmpafids
                (assessmentformid INTEGER PRIMARY KEY);
                var_Query := '
			INSERT INTO t$tmpafids SELECT DISTINCT assessmentformid FROM dbo.scoretopic JOIN (SELECT DISTINCT ltrs.standardid FROM dbo.l4wtemplaterow AS ltr JOIN dbo.l4wtemplaterowstandard AS ltrs ON ltr.l4wtemplaterowid = ltrs.l4wtemplaterowid WHERE ltr.l4wtemplateid IN (SELECT templateid FROM t$l4wtemplatetable)) AS sd ON sd.standardid = scoretopic.standardid ';
                RAISE NOTICE '%', var_Query;
                EXECUTE var_Query;
            END IF;
            /* Sravani Balireddy : Modified to add the PLC Assessments */

            IF (var_DistictValue = 1) THEN
                /* 19-Oct-2020: Manohar - Modified to improve the performance -- added Embargo column */
                /* -- Manohar\Rajesh Modified for SC-18101 added @AccessLevel case condition */
                var_ResultQuery := ' Insert into #tmpAssessments (AssessmentID, IsEmbargoed)
			select top 1  AssessmentID, IsEmbargoed from(  
			select Distinct Assessment.AssessmentID, Assessment.IsEmbargoed, TestAttempt.TestAttemptID From Assessment  
			inner join AssessmentForm on Assessment.AssessmentID = AssessmentForm.AssessmentID 
			join TestAttempt with (nolock) on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID ' ||
                CASE
                    WHEN par_ReportType = 'L' THEN ' join #tmpAFIDs tAF on tAF.AssessmentformID = Assessmentform.AssessmentformID '
                    ELSE ''
                END || (CASE
                    WHEN par_ReportType IN ('DDI', 'PE') THEN ' inner join ScoreTopic ST on AssessmentForm.AssessmentFormID = ST.AssessmentFormID and ST.TypeCode = ''T'''
                    ELSE ''
                END) || (CASE
                    WHEN par_ReportType = 'BRR' THEN ' join TagLink on Assessment.AssessmentID = TagLink.ObjectID
			join Tag on Tag.TagID = TagLink.TagID and (Tag.Name in (''FountasAndPinnellT1'', ''FountasAndPinnellT2'', ''FountasAndPinnellT3'') or Tag.Name like ''%BRR%'')
			join ObjectType on TagLink.ObjectTypeID = ObjectType.ObjectTypeID and ObjectType.Name = ''Assessment'' '
                    ELSE ''
                END) || '
			where ' ||
                CASE
                    WHEN par_ReportType = 'INTR' THEN 'Assessment.ActiveCode = ''I'''
                    ELSE 'Assessment.ActiveCode = ''A'''
                END || ' and HasScores = 1 and Assessment.InstanceID = ' || CAST (var_InstanceID AS VARCHAR(30)) || ' and (Assessment.PLCID is null or Assessment.PLCID in (select PLCID from #PLCIDs))' ||
                /* Prasanna : Modified below lines to inlcude "ReportSchoolYearID" setting year assessments also for SC-16387 task */
                ' and ((' ||
                CASE
                    WHEN var_AccessLevel = 'T' AND var_FutureYear = 'N' THEN ' Assessment.SchoolYearID <= ' || CAST (var_RosterYearID AS VARCHAR(10))
                    ELSE ''
                END ||
                CASE
                    WHEN var_AccessLevel = 'T' AND var_FutureYear = 'N' THEN ' and '
                    ELSE ''
                END || ' Assessment.SchoolYearID between ' || CAST ((var_CurrentYear - var_RosterPYear) AS VARCHAR(10)) || ' and ' || CAST (var_CurrentYear AS VARCHAR(10)) || ') or Assessment.SchoolYearID =' || CAST (var_ReportSchoolYearID AS VARCHAR(10)) || ')';
                /* Rajesh replaced  and ( LevelCode = ''D'' )' with Case Condition for SC-20391 */
                var_ResultQuery := var_ResultQuery || ' and RosterDataSetID is not null ' ||
                CASE
                    WHEN par_AID <> '-1' AND var_FDsashBoard = 1 THEN ''
                    ELSE ' and ( LevelCode = ''D'' )'
                END ||
                CASE
                    WHEN par_ReportType = 'C' THEN ' and ( Assessment.IsAFL = 1 or Assessment.CIStatusCode = ''C'' ) '
                    ELSE ''
                END ||
                CASE
                    WHEN par_ReportType = 'PE' THEN 'group by Assessment.AssessmentID , Assessment.IsEmbargoed, TestAttempt.TestAttemptID having count(distinct StandardID) = ''5'' '
                    ELSE ''
                END ||
                /* Madhushree K : Added Assessment.IsEmbargoed for [SC-10481] */
                CASE
                    WHEN par_ReportType = 'S' THEN 'and Assessment.PublisherExtID = ''SC-SBAC-SUMMATIVE'' '
                    ELSE ''
                END ||
                CASE
                    WHEN par_ReportType = 'H' THEN 'and SpecialAssessmentTabID = 16 and Assessment.TypeCode = ''P'' '
                    ELSE ''
                END ||
                /* Rajesh  Modified for SC-15445 */
                CASE
                    WHEN par_ReportType = 'L' THEN 'and Assessment.AssessmentFamilyID = 123 '
                    ELSE ''
                END ||
                CASE
                    WHEN var_bFromLMS = 1 THEN ' and Assessment.AssessmentID = ' || CAST (par_AID AS VARCHAR(30))
                    ELSE ''
                END || ' ) tmpA
			cross apply (select dbo.[fn_EmbargoGetEmbargoStatus] (tmpA.AssessmentID,' || CAST (par_UserRoleID AS VARCHAR(100)) || ',' || CAST (var_UserAccountID AS VARCHAR(100)) || ') 
						as Embargoed ) X  where Embargoed = 0  
                        order by TestAttemptID desc';
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec (@ResultQuery)
                */
            ELSE
                /* SC-13858 -- added IsEmbargo column in the temp table, this was missed */
                /* -- Manohar\Rajesh Modified for SC-18101 added @AccessLevel case condition */
                /* Rajesh for SC-20766 added LevelCode = ''D'' */
                var_ResultQuery := ' Insert into #tmpAssessments (AssessmentID, IsEmbargoed)   
			select Distinct Assessment.AssessmentID, Assessment.IsEmbargoed From Assessment  
			inner join AssessmentForm on Assessment.AssessmentID = AssessmentForm.AssessmentID ' ||
                CASE
                    WHEN par_ReportType = 'L' THEN ' join #tmpAFIDs tAF on tAF.AssessmentformID = Assessmentform.AssessmentformID '
                    ELSE ''
                END || (CASE
                    WHEN par_ReportType IN ('DDI', 'PE') THEN ' inner join ScoreTopic ST on AssessmentForm.AssessmentFormID = ST.AssessmentFormID and ST.TypeCode = ''T'''
                    ELSE ''
                END) || (CASE
                    WHEN par_ReportType = 'BRR' THEN ' join TagLink on Assessment.AssessmentID = TagLink.ObjectID
			join Tag on Tag.TagID = TagLink.TagID and (Tag.Name in (''FountasAndPinnellT1'', ''FountasAndPinnellT2'', ''FountasAndPinnellT3'') or Tag.Name like ''%BRR%'')
			join ObjectType on TagLink.ObjectTypeID = ObjectType.ObjectTypeID and ObjectType.Name = ''Assessment'' '
                    ELSE ''
                END) || '
			where ' ||
                CASE
                    WHEN par_ReportType = 'INTR' THEN 'Assessment.ActiveCode = ''I'''
                    ELSE 'Assessment.ActiveCode = ''A'''
                END || ' and HasScores = 1 and Assessment.InstanceID = ' || CAST (var_InstanceID AS VARCHAR(30)) || ' and (Assessment.PLCID is null or Assessment.PLCID in (select PLCID from #PLCIDs))' ||
                /* Prasanna : Modified below lines to inlcude "ReportSchoolYearID" setting year assessments also for SC-16387 task */
                ' and ((' ||
                CASE
                    WHEN var_AccessLevel = 'T' AND var_FutureYear = 'N' THEN ' Assessment.SchoolYearID <= ' || CAST (var_RosterYearID AS VARCHAR(10))
                    ELSE ''
                END ||
                CASE
                    WHEN var_AccessLevel = 'T' AND var_FutureYear = 'N' THEN ' and '
                    ELSE ''
                END || ' Assessment.SchoolYearID between ' || CAST ((var_CurrentYear - var_RosterPYear) AS VARCHAR(10)) || ' and ' || CAST (var_CurrentYear AS VARCHAR(10)) || ') or Assessment.SchoolYearID =' || CAST (var_ReportSchoolYearID AS VARCHAR(10)) || ')' ||
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
                /* Rajesh Commented Above and Merged bleow blocks from HisD SC-20391 */
                /* Rakshith H S  Modified for SC-17752 Incorrect syntax near  ')' added 'or @AccessLevel = 'A'' */
                CASE
                    WHEN par_AID <> '-1' AND var_FDsashBoard = 1 THEN ''
                    ELSE +
                    CASE
                        WHEN var_AccessLevel = 'D' OR var_AccessLevel = 'A' THEN ' and ( LevelCode = ''D'' '
                        ELSE ''
                    END ||
                    CASE
                        WHEN var_AccessLevel = 'N' THEN ' and (LevelCode = ''D'' or ( LevelCode = ''N'' And LevelOwnerID = ' || CAST (par_UserNetworkID AS VARCHAR(10)) || ')'
                        ELSE ''
                    END ||
                    CASE
                        WHEN var_AccessLevel = 'C' OR var_AccessLevel = 'T' THEN ' and ( LevelCode = ''D'' OR (LevelCode = ''C'' And LevelOwnerID = ' || CAST (par_UserCampusID AS VARCHAR(30)) || ') OR ( LevelCode = ''N'' And exists (select top 1 1 from NetworkCampus where NetWorkID = LevelOwnerID and CampusID = ' || CAST (par_UserCampusID AS VARCHAR(15)) || ' )) '
                        ELSE ''
                    END ||
                    CASE
                        WHEN var_AccessLevel = 'T' THEN ' OR (LevelCode = ''U'' And LevelOwnerID = ' || CAST (var_UserAccountID AS VARCHAR(30)) || ')'
                        ELSE ''
                    END || ')'
                END ||
                CASE
                    WHEN par_ReportType = 'C' THEN ' and ( Assessment.IsAFL = 1 or Assessment.CIStatusCode = ''C'' ) '
                    ELSE ''
                END ||
                CASE
                    WHEN par_ReportType = 'PE' THEN 'group by Assessment.AssessmentID, Assessment.IsEmbargoed having count(distinct StandardID) = ''5'' '
                    ELSE ''
                END ||
                /* Madhushree K: Modified for [SC-14203] */
                CASE
                    WHEN par_ReportType = 'S' THEN 'and Assessment.PublisherExtID = ''SC-SBAC-SUMMATIVE'' '
                    ELSE ''
                END ||
                CASE
                    WHEN par_ReportType = 'H' THEN 'and SpecialAssessmentTabID = 16 and Assessment.TypeCode = ''P''  '
                    ELSE ''
                END ||
                /* Rajesh  Modified for SC-15445 */
                CASE
                    WHEN par_ReportType = 'L' THEN 'and Assessment.AssessmentFamilyID = 123 '
                    ELSE ''
                END ||
                CASE
                    WHEN var_bFromLMS = 1 THEN ' and Assessment.AssessmentID = ' || CAST (par_AID AS VARCHAR(30))
                    ELSE ''
                END;
                RAISE NOTICE '%', (var_ResultQuery);
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                exec (@ResultQuery)
                */
                UPDATE t$tmpassessments AS tmpa
                SET isembargoed = isemb
                FROM (SELECT
                    assessmentid, dbo.fn_embargogetembargostatus(assessmentid, par_UserRoleID, var_UserAccountID) AS isemb
                    FROM t$tmpassessments) AS tmpb
                    WHERE tmpa.assessmentid = tmpb.assessmentid AND isembargoed = 1;
                /* 19-Oct-2020: Manohar - Modified to improve the performance -- added Embargo condition */
                DELETE FROM t$tmpassessments
                    WHERE isembargoed = 1;
                /* Srinatha : Added below insert while doing performance tuning SC-27148 */

                IF var_AccessLevel <> 'D' OR (var_AccessLevel = 'D' AND var_appFnReportUserData <> '') THEN
                    INSERT INTO t$testattempt (studentid)
                    SELECT
                        tmp.studentid
                        FROM t$tmpassessments AS t
                        INNER JOIN dbo.assessmentform AS af
                            ON t.assessmentid = af.assessmentid
                        INNER JOIN dbo.testattempt AS tmp
                            ON tmp.assessmentformid = af.assessmentformid
                        GROUP BY tmp.studentid;
                END IF;
                /* SC-18077 -- commented the below code instead using this whole query in the below joins */
                /* insert into #TestAttempt */
                /* select studentid from TestAttempt with (nolock) */
                /* INNER JOIN AssessmentForm on TestAttempt.AssessmentFormID = AssessmentForm.AssessmentFormID */
                /* --INNER JOIN #tmpAssessments tmpAssess on AssessmentForm.AssessmentID = tmpAssess.AssessmentID */
                /* where exists (select top 1 1 from #tmpAssessments where AssessmentID = AssessmentForm.AssessmentID) */
                /* group by studentid */
                /* -- Manohar\Rajesh Modified for SC-18101 added @AccessLevel case condition */
                var_ResultQuery := 'insert into #RosterInfo ' || ' select DISTINCT TOP 1 RosterDataSet.SchoolYearID, SchoolYear.LongName, RosterDataSet.RosterDataSetID, RosterDataSet.Name, RosterDataSet.Isdefault from RosterDataSet' || ' INNER JOIN Class on RosterDataSet.RosterDataSetID = Class.RosterDataSetID ' || ' INNER JOIN StudentClass with(nolock, forceseek) on Class.ClassID = StudentClass.ClassID AND StudentClass.IsCurrent = 1 ' ||
                CASE
                    WHEN var_AccessLevel = 'D' AND var_appFnReportUserData = '' THEN ''
                    ELSE ' join #TestAttempt T on T.StudentID = StudentClass.StudentID '
                END || (CASE
                    WHEN (SELECT
                        1
                        FROM dbo.userroleteacher
                        WHERE userroleid = par_UserRoleID
                        LIMIT 1) = 1 OR par_UserTeacherID <> '-1' THEN ' INNER JOIN TeacherClass on Class.ClassID = TeacherClass.ClassID AND TeacherClass.IsCurrent = 1 '
                    ELSE ''
                END) || (CASE
                    WHEN (SELECT
                        1
                        FROM dbo.userrolestudentgroup
                        WHERE userroleid = par_UserRoleID
                        LIMIT 1) = 1 THEN ' INNER JOIN StudentGroupStudent on StudentClass.StudentID = StudentGroupStudent.StudentID '
                    ELSE ''
                END) || var_appFnReportUserData || ' INNER JOIN SchoolYear on RosterDataSet.SchoolYearID = SchoolYear.SchoolYearID ' ||
                /* SC-18077 - changed it to original table */
                /* Manohar /Rajesh SC-18200 added Testattempt in Exists Condition */
                /* +' INNER JOIN TestAttempt TMP  with (nolock) on StudentClass.StudentID = TMP.StudentID ' */
                /* +' INNER JOIN AssessmentForm AF on TMP.AssessmentFormID = AF.AssessmentFormID ' */
                ' where RosterDataSet.IsHidden = 0  AND RosterDataSet.InstanceID = ' || CAST (var_InstanceID AS VARCHAR(30));
                /* + case when  @AccessLevel  = 'T' then ' and RosterDataset.SchoolYearID between ' */
                /* + cast(case when @AllowAccess = 'Y' then (@RosterYearID - @Pastyear) else (@RosterYearID - 1) end as varchar(10)) */
                /* +' and '+ cast(@RosterYearID  as varchar(10)) */
                /* else ' and RosterDataset.SchoolYearID between ' + cast((@CurrentYear - @RosterPYear) as varchar(10)) +' and '+ cast(@CurrentYear  as varchar(10)) end */
                var_ResultQuery1 :=
                /* Srinatha : Commented below block and moved this to #TestAttempt table and used it in JOIN for SC-27148 ticket */
                /* ' and exists (select top 1 1 from #tmpAssessments t ' */
                /* +' INNER JOIN AssessmentForm AF on t.AssessmentID = AF.AssessmentID ' */
                /* +' INNER JOIN TestAttempt TMP  with (nolock) on TMP.AssessmentFormID = AF.AssessmentFormID where  TMP.StudentID = StudentClass.StudentID ) ' */
                CASE
                    WHEN par_UserCampusID = '-1' THEN ''
                    ELSE ' and Class.CampusID = ' || CAST (par_UserCampusID AS VARCHAR(30))
                END ||
                CASE
                    WHEN par_UserTeacherID = '-1' THEN ''
                    ELSE ' and TeacherClass.TeacherID = ' || CAST (par_UserTeacherID AS VARCHAR(30))
                END || ' ORDER BY RosterDataSet.Isdefault DESC, RosterDataSet.SchoolYearID DESC, RosterDataSet.RosterDataSetID  DESC 
			   OPTION(RECOMPILE)';
                /* SC-26408 - Added by JayaPrakash as per manohar suggestions */
                /* Prasanna : Added below code for SC-16387 task to get SchoolYear based on "ReportSchoolYearID" setting */
                var_RosterSubQuery := var_ResultQuery ||
                /* SC-26631: Commented the below line as we don't need to apply this while taking roster data. This is already applied at assessment query */
                /* + ' and RosterDataset.SchoolYearID =' + cast(@ReportSchoolYearID  as varchar(10)) */
                var_ResultQuery1;
                RAISE NOTICE '%', var_RosterSubQuery;
                /*
                [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                EXEC (@RosterSubQuery)
                */
                IF NOT EXISTS (SELECT
                    1
                    FROM t$rosterinfo
                    LIMIT 1) THEN
                    var_RosterSubQuery := var_ResultQuery ||
                    CASE
                        WHEN var_AccessLevel = 'T' THEN ' and RosterDataset.SchoolYearID between ' || CAST (CASE
                            WHEN var_AllowAccess = 'Y' THEN (var_RosterYearID - var_PastYear)
                            ELSE (var_RosterYearID - 1)
                        END AS VARCHAR(10)) || ' and ' || CAST (var_RosterYearID AS VARCHAR(10))
                        ELSE ' and RosterDataset.SchoolYearID between ' || CAST ((var_CurrentYear - var_RosterPYear) AS VARCHAR(10)) || ' and ' || CAST (var_CurrentYear AS VARCHAR(10))
                    END || var_ResultQuery1;
                    RAISE NOTICE '%', var_RosterSubQuery;
                    /*
                    [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                    EXEC (@RosterSubQuery)
                    */
                END IF;

                IF NOT EXISTS (SELECT
                    1
                    FROM t$rosterinfo
                    LIMIT 1) THEN
                    INSERT INTO t$stdlist
                    SELECT DISTINCT
                        studentgroupstudent.studentid
                        FROM dbo.studentgroup
                        JOIN dbo.studentgroupstudent
                            ON studentgroupstudent.studentgroupid = studentgroup.studentgroupid
                        WHERE instanceid = var_InstanceID AND studentgroup.publicrestricttosis = 0 AND (studentgroup.createdby = var_UserAccountID OR (studentgroup.privacycode = 3 AND levelownerid IS NULL) OR (studentgroup.privacycode = 3 AND levelownerid = par_UserCampusID)) AND studentgroup.activecode = 'A'
                    UNION
                    SELECT DISTINCT
                        studentgroupstudent.studentid
                        FROM dbo.studentgroup
                        JOIN dbo.studentgroupstudent
                            ON studentgroupstudent.studentgroupid = studentgroup.studentgroupid
                        LEFT OUTER JOIN dbo.studentgroupconsumer
                            ON studentgroup.studentgroupid = studentgroupconsumer.studentgroupid
                        WHERE instanceid = var_InstanceID AND studentgroup.publicrestricttosis = 0 AND (studentgroup.privacycode = 2 AND studentgroupconsumer.useraccountid = var_UserAccountID) AND studentgroup.activecode = 'A';
                    /* if Exists (select Top 1 1 From #StdList Inner Join #TestAttempt On #TestAttempt.StudentID = #StdList.StudentID) */
                    /* SC-18077 - commented the above line and added below line since we are using the original testattempt table */

                    IF EXISTS (SELECT
                        1
                        FROM dbo.testattempt
                        INNER JOIN dbo.assessmentform
                            ON testattempt.assessmentformid = assessmentform.assessmentformid
                        INNER JOIN t$tmpassessments AS tmpassess
                            ON assessmentform.assessmentid = tmpassess.assessmentid
                        WHERE EXISTS (SELECT
                            1
                            FROM t$stdlist
                            WHERE studentid = testattempt.studentid
                            LIMIT 1)) THEN
                        var_StudentGroup := 1;
                    END IF;
                END IF;
            END IF;

            IF EXISTS (SELECT
                1
                FROM t$rosterinfo
                LIMIT 1) OR var_StudentGroup = 1 OR var_DistictValue = 1 THEN
                IF (var_DistictValue = 0) THEN
                    SELECT
                        rosterdatasetid
                        INTO var_RosterDataSetID
                        FROM t$rosterinfo;

                    IF var_StudentGroup = 0 THEN
                        IF var_appFnReportUserData = '' AND par_UserCampusID = - 1 AND var_AccessLevel = 'D' AND (SELECT
                            isdefault
                            FROM dbo.rosterdataset
                            WHERE rosterdatasetid = var_RosterDataSetID) = 1 AND (SELECT
                            COUNT(*)
                            FROM dbo.userrolestudentgroup
                            WHERE userroleid = par_UserRoleID) = 0 AND var_CurrentStudent = 'Y' THEN
                            var_ResultQuery := ' insert into #StudentClass 
						select distinct StudentID from CurrentStudent ';
                        ELSE
                            var_ResultQuery := 'insert into #Studentclass ' || ' select DISTINCT StudentClass.StudentID from StudentClass ' || ' INNER JOIN Class on StudentClass.ClassID = Class.ClassID ' || (CASE
                                WHEN (SELECT
                                    1
                                    FROM dbo.userroleteacher
                                    WHERE userroleid = par_UserRoleID
                                    LIMIT 1) = 1 OR par_UserTeacherID <> '-1' THEN ' INNER JOIN TeacherClass on Class.ClassID = TeacherClass.ClassID AND TeacherClass.IsCurrent = 1  '
                                ELSE ''
                            END) || (CASE
                                WHEN (SELECT
                                    1
                                    FROM dbo.userrolestudentgroup
                                    WHERE userroleid = par_UserRoleID
                                    LIMIT 1) = 1 THEN ' INNER JOIN StudentGroupStudent on StudentClass.StudentID = StudentGroupStudent.StudentID '
                                ELSE ''
                            END) || var_appFnReportUserData || ' where  StudentClass.IsCurrent = 1 AND Class.RosterDatasetID = ' || CAST (var_RosterDataSetID AS VARCHAR(30)) || (CASE
                                WHEN par_UserCampusID != - 1 THEN ' AND CLASS.CampusID = ' || CAST (par_UserCampusID AS VARCHAR(30))
                                ELSE ''
                            END) || (CASE
                                WHEN par_UserTeacherID = '-1' THEN ''
                                ELSE ' and TeacherClass.TeacherID = ' || CAST (par_UserTeacherID AS VARCHAR(30))
                            END);
                        END IF;
                        /*
                        [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
                        exec (@ResultQuery)
                        */
                    ELSE
                        INSERT INTO t$studentclass
                        SELECT
                            *
                            FROM t$stdlist;
                    END IF;
                    var_ResultQuery := ' INSERT INTO t$assessmentforminfo  ' || ' SELECT testattempt.assessmentformid FROM dbo.testattempt ' ||
                    /* SC-18077 moved the below table to exists */
                    /* +' INNER JOIN #Studentclass TMP on TestAttempt.StudentID = TMP.StudentID  ' */
                    ' INNER JOIN dbo.assessmentform ON assessmentform.assessmentformid = testattempt.assessmentformid ' || 'INNER JOIN t$tmpassessments AS tmpassess ON assessmentform.assessmentid = tmpassess.assessmentid ' || ' WHERE EXISTS (SELECT 1 FROM t$studentclass WHERE studentid = testattempt.studentid LIMIT 1)' || ' ORDER BY testattempt.testattemptid DESC NULLS LAST ';
                    /* SC-18077 using TestAttemptID instead of TestedDate for better performance after discussing with Kallesh and Dale */
                    RAISE NOTICE '%', var_ResultQuery;
                    EXECUTE var_ResultQuery;
                    SELECT
                        assessmentformid
                        INTO var_AssessmentFormID
                        FROM t$assessmentforminfo;
                ELSE
                    /* Sravani balireddy : Setting Default Assessment for user District user */
                    SELECT
                        (SELECT
                            assessmentform.assessmentformid
                            FROM dbo.assessmentform
                            JOIN t$tmpassessments AS t
                                ON t.assessmentid = assessmentform.assessmentid
                            LIMIT 1)
                        INTO var_AssessmentFormID;
                    INSERT INTO t$rosterinfo
                    SELECT DISTINCT
                        rosterdataset.schoolyearid, schoolyear.longname, rosterdataset.rosterdatasetid, rosterdataset.name, rosterdataset.isdefault
                        FROM dbo.assessment
                        JOIN dbo.assessmentform
                            ON assessment.assessmentid = assessmentform.assessmentid
                        JOIN dbo.rosterdataset
                            ON assessment.rosterdatasetid = rosterdataset.rosterdatasetid
                        JOIN dbo.schoolyear
                            ON rosterdataset.schoolyearid = schoolyear.schoolyearid
                        WHERE rosterdataset.ishidden = 0 AND rosterdataset.instanceid = var_InstanceID AND assessmentformid = var_AssessmentFormID
                        LIMIT 1;
                END IF;

                IF var_bFromLMS = 1 THEN
                    DELETE FROM alltypevalues$appreportdefaultfilters
                        WHERE rt = 'P';
                END IF;

                IF var_StudentGroup = 0 THEN
                    INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                    SELECT
                        par_ReportType AS rt, (SELECT
                            schoolyearid
                            FROM t$rosterinfo), (SELECT
                            schoolyearname
                            FROM t$rosterinfo), (SELECT
                            rosterdatasetid
                            FROM t$rosterinfo), (SELECT
                            name
                            FROM t$rosterinfo), schoolyear.schoolyearid, schoolyear.longname, COALESCE(colid, - 1), COALESCE(coln, '-1'),
                        CASE
                            WHEN 1 = (SELECT
                                1
                                FROM dbo.assessmentfamily
                                WHERE categorylist = 'STATE' AND assessmentfamilyid = assessment.assessmentfamilyid
                                LIMIT 1) THEN CAST (1 AS VARCHAR(10))
                            ELSE
                            CASE
                                WHEN assessment.levelcode = 'D' AND assessment.plcid IS NULL THEN CAST (2 AS VARCHAR(10))
                            /* Khushboo: added  Assessment.PLCID is null condition for SC-7100 task */
                                ELSE
                                CASE
                                    WHEN assessment.levelcode = 'N' THEN CAST (3 AS VARCHAR(10))
                                /* Khushboo: added Network LevelCode for SC-7100 task and incremented ALID for School and Teacher */
                                    ELSE
                                    CASE
                                        WHEN assessment.levelcode = 'C' THEN CAST (4 AS VARCHAR(10))
                                        ELSE
                                        CASE
                                            WHEN assessment.levelcode = 'U' THEN CAST (6 AS VARCHAR(10))
                                            ELSE
                                            CASE
                                                WHEN assessment.plcid IN (SELECT
                                                    plcid
                                                    FROM t$plcids) THEN CAST (5 AS VARCHAR(10))
                                            END
                                            /* Khushboo: added this case condition for SC-7100 task */
                                        END
                                    END
                                END
                            END
                        END,
                        CASE
                            WHEN 1 = (SELECT
                                1
                                FROM dbo.assessmentfamily
                                WHERE categorylist = 'STATE' AND assessmentfamilyid = assessment.assessmentfamilyid
                                LIMIT 1) THEN 'State'
                            ELSE
                            CASE
                                WHEN assessment.levelcode = 'D' AND assessment.plcid IS NULL THEN 'District'
                            /* Khushboo: added  Assessment.PLCID is null condition for SC-7100 task */
                                ELSE
                                CASE
                                    WHEN assessment.levelcode = 'N' THEN 'Network'
                                /* Khushboo: added Network LevelCode for SC-7100 task */
                                    ELSE
                                    CASE
                                        WHEN assessment.levelcode = 'C' THEN 'School'
                                        ELSE
                                        CASE
                                            WHEN assessment.levelcode = 'U' THEN 'Teacher'
                                            ELSE
                                            CASE
                                                WHEN assessment.plcid IN (SELECT
                                                    plcid
                                                    FROM t$plcids) THEN 'PLC'
                                            END
                                            /* Khushboo: added this case condition for SC-7100 task */
                                        END
                                    END
                                END
                            END
                        END, - 1, '-1', - 1, '-1', - 1, '-1', instancesubject.subjectid, instancesubject.longname, assessment.assessmentid, regexp_replace(regexp_replace(assessment.name, '>', '&amp;gt;', 'gi'), '<', '&amp;lt;', 'gi'), a.urcid
                        /* Manohar: Modified to fix the ticket #30785 - Converting special characters to xml tags in the assessment names */
                        FROM dbo.assessment
                        INNER JOIN dbo.assessmentform
                            ON assessment.assessmentid = assessmentform.assessmentid
                        INNER JOIN dbo.instancesubject
                            ON assessmentform.subjectid = instancesubject.subjectid
                        INNER JOIN dbo.schoolyear
                            ON assessment.schoolyearid = schoolyear.schoolyearid
                        LEFT OUTER JOIN
                        /* inner join #RosterInfo on #RosterInfo.SchoolYearID = Assessment.SchoolYearID */
                        dbo.campus
                            ON campus.campusid = assessment.levelownerid
                        LEFT OUTER JOIN dbo.useraccount
                            ON useraccount.useraccountid = assessment.createdby
                        LEFT OUTER JOIN alltypevalues$appreportdefaultfilters AS a
                            ON a.rt = par_ReportType
                        WHERE assessmentformid = var_AssessmentFormID AND instancesubject.instanceid = var_InstanceID AND
                        /* Srinatha : Added below Assessment.IsLinked column for SC-16815 task */
                        assessment.islinked =
                        CASE
                            WHEN var_IncLinkedAssess = 0 THEN 0
                            ELSE assessment.islinked
                        END;
                ELSE
                    /* Manohar: Modified to fix the ticket #29864 - Assessment.SchoolYearID */
                    INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                    SELECT
                        par_ReportType AS rt, assessment.schoolyearid, schoolyear.longname, rds.rosterdatasetid,
                        /* SC-29560:Amrut- Added RDS.RosterDataSetID instead taking from #RosterInfo */
                        rds.name, schoolyear.schoolyearid, schoolyear.longname, COALESCE(colid, - 1), COALESCE(coln, '-1'),
                        /* SC-29560:Amrut- Added RDS.Name instead taking from #RosterInfo */
                        CASE
                            WHEN 1 = (SELECT
                                1
                                FROM dbo.assessmentfamily
                                WHERE categorylist = 'STATE' AND assessmentfamilyid = assessment.assessmentfamilyid
                                LIMIT 1) THEN CAST (1 AS VARCHAR(10))
                            ELSE
                            CASE
                                WHEN assessment.levelcode = 'D' AND assessment.plcid IS NULL THEN CAST (2 AS VARCHAR(10))
                            /* Khushboo: added  Assessment.PLCID is null condition for SC-7100 task */
                                ELSE
                                CASE
                                    WHEN assessment.levelcode = 'N' THEN CAST (3 AS VARCHAR(10))
                                /* Khushboo: added Network LevelCode for SC-7100 task and incremented ALID for School and Teacher */
                                    ELSE
                                    CASE
                                        WHEN assessment.levelcode = 'C' THEN CAST (4 AS VARCHAR(10))
                                        ELSE
                                        CASE
                                            WHEN assessment.levelcode = 'U' THEN CAST (6 AS VARCHAR(10))
                                            ELSE
                                            CASE
                                                WHEN assessment.plcid IN (SELECT
                                                    plcid
                                                    FROM t$plcids) THEN CAST (5 AS VARCHAR(10))
                                            END
                                            /* Khushboo: added this case condition for SC-7100 task */
                                        END
                                    END
                                END
                            END
                        END,
                        CASE
                            WHEN 1 = (SELECT
                                1
                                FROM dbo.assessmentfamily
                                WHERE categorylist = 'STATE' AND assessmentfamilyid = assessment.assessmentfamilyid
                                LIMIT 1) THEN 'State'
                            ELSE
                            CASE
                                WHEN assessment.levelcode = 'D' AND assessment.plcid IS NULL THEN 'District'
                            /* Khushboo: added  Assessment.PLCID is null condition for SC-7100 task */
                                ELSE
                                CASE
                                    WHEN assessment.levelcode = 'N' THEN 'Network'
                                /* Khushboo: added Network LevelCode for SC-7100 task */
                                    ELSE
                                    CASE
                                        WHEN assessment.levelcode = 'C' THEN 'School'
                                        ELSE
                                        CASE
                                            WHEN assessment.levelcode = 'U' THEN 'Teacher'
                                            ELSE
                                            CASE
                                                WHEN assessment.plcid IN (SELECT
                                                    plcid
                                                    FROM t$plcids) THEN 'PLC'
                                            END
                                            /* Khushboo: added this case condition for SC-7100 task */
                                        END
                                    END
                                END
                            END
                        END, - 1, '-1', - 1, '-1', - 1, '-1', instancesubject.subjectid, instancesubject.longname, assessment.assessmentid, regexp_replace(regexp_replace(assessment.name, '>', '&amp;gt;', 'gi'), '<', '&amp;lt;', 'gi'), a.urcid
                        /* Manohar: Modified to fix the ticket #30785 - Converting special characters to xml tags in the assessment names */
                        FROM dbo.assessment
                        INNER JOIN dbo.assessmentform
                            ON assessment.assessmentid = assessmentform.assessmentid
                        INNER JOIN dbo.instancesubject
                            ON assessmentform.subjectid = instancesubject.subjectid
                        INNER JOIN dbo.schoolyear
                            ON assessment.schoolyearid = schoolyear.schoolyearid
                        INNER JOIN
                        /* inner join #RosterInfo on #RosterInfo.SchoolYearID = Assessment.SchoolYearID */
                        /* SC-29560:Amrut- Added RosterDataSet table (When for logged in user, roster students are not available or doesnt have permision but students from student group present) */
                        dbo.rosterdataset AS rds
                            ON rds.schoolyearid = assessment.schoolyearid AND isdefault = 1
                        LEFT OUTER JOIN dbo.campus
                            ON campus.campusid = assessment.levelownerid
                        LEFT OUTER JOIN dbo.useraccount
                            ON useraccount.useraccountid = assessment.createdby
                        LEFT OUTER JOIN alltypevalues$appreportdefaultfilters AS a
                            ON a.rt = par_ReportType
                        WHERE assessmentformid = var_AssessmentFormID AND instancesubject.instanceid = var_InstanceID AND
                        /* Srinatha : Added below Assessment.IsLinked column for SC-16815 task */
                        assessment.islinked =
                        CASE
                            WHEN var_IncLinkedAssess = 0 THEN 0
                            ELSE assessment.islinked
                        END;
                END IF;
                /* if Predefined Assessment is not set then the below query we set it DDI AssessmentID to Predefined also. */

                IF par_ReportType = 'DDI' AND EXISTS (SELECT
                    1
                    FROM alltypevalues$appreportdefaultfilters
                    WHERE rt = 'P' AND aid = 0
                    LIMIT 1) THEN
                    DELETE FROM alltypevalues$appreportdefaultfilters
                        WHERE rt = 'P';
                    /* Manohar: Modified to fix the ticket #29864 - Assessment.SchoolYearID */
                    INSERT INTO alltypevalues$appreportdefaultfilters (rt, ryid, ryn, rdsid, rdsn, syid, syn, colid, coln, alid, aln, tid, tn, cid, cn, nid, nn, sbid, sbn, aid, an, urcid)
                    SELECT
                        'P' AS rt, assessment.schoolyearid, (SELECT
                            schoolyearname
                            FROM t$rosterinfo), (SELECT
                            rosterdatasetid
                            FROM t$rosterinfo), (SELECT
                            name
                            FROM t$rosterinfo), schoolyear.schoolyearid, schoolyear.longname, COALESCE(colid, - 1), COALESCE(coln, '-1'),
                        CASE
                            WHEN 1 = (SELECT
                                1
                                FROM dbo.assessmentfamily
                                WHERE categorylist = 'STATE' AND assessmentfamilyid = assessment.assessmentfamilyid
                                LIMIT 1) THEN CAST (1 AS VARCHAR(10))
                            ELSE
                            CASE
                                WHEN assessment.levelcode = 'D' AND assessment.plcid IS NULL THEN CAST (2 AS VARCHAR(10))
                            /* Khushboo: added  Assessment.PLCID is null condition for SC-7100 task */
                                ELSE
                                CASE
                                    WHEN assessment.levelcode = 'N' THEN CAST (3 AS VARCHAR(10))
                                /* Khushboo: added Network LevelCode for SC-7100 task and incremented ALID for School and Teacher */
                                    ELSE
                                    CASE
                                        WHEN assessment.levelcode = 'C' THEN CAST (4 AS VARCHAR(10))
                                        ELSE
                                        CASE
                                            WHEN assessment.levelcode = 'U' THEN CAST (6 AS VARCHAR(10))
                                            ELSE
                                            CASE
                                                WHEN assessment.plcid IN (SELECT
                                                    plcid
                                                    FROM t$plcids) THEN CAST (5 AS VARCHAR(10))
                                            END
                                            /* Khushboo: added this case condition for SC-7100 task */
                                        END
                                    END
                                END
                            END
                        END,
                        CASE
                            WHEN 1 = (SELECT
                                1
                                FROM dbo.assessmentfamily
                                WHERE categorylist = 'STATE' AND assessmentfamilyid = assessment.assessmentfamilyid
                                LIMIT 1) THEN 'State'
                            ELSE
                            CASE
                                WHEN assessment.levelcode = 'D' AND assessment.plcid IS NULL THEN 'District'
                            /* Khushboo: added  Assessment.PLCID is null condition for SC-7100 task */
                                ELSE
                                CASE
                                    WHEN assessment.levelcode = 'N' THEN 'Network'
                                /* Khushboo: added Network LevelCode for SC-7100 task' */
                                    ELSE
                                    CASE
                                        WHEN assessment.levelcode = 'C' THEN 'School'
                                        ELSE
                                        CASE
                                            WHEN assessment.levelcode = 'U' THEN 'Teacher'
                                            ELSE
                                            CASE
                                                WHEN assessment.plcid IN (SELECT
                                                    plcid
                                                    FROM t$plcids) THEN 'PLC'
                                            END
                                            /* Khushboo: added this case condition for SC-7100 task */
                                        END
                                    END
                                END
                            END
                        END, - 1, '-1', - 1, '-1', - 1, '-1', instancesubject.subjectid, instancesubject.longname, assessment.assessmentid, regexp_replace(regexp_replace(assessment.name, '>', '&amp;gt;', 'gi'), '<', '&amp;lt;', 'gi'), a.urcid
                        /* -- Manohar: Modified to fix the ticket #30785 - Converting special characters to xml tags in the assessment names */
                        FROM dbo.assessment
                        INNER JOIN dbo.assessmentform
                            ON assessment.assessmentid = assessmentform.assessmentid
                        INNER JOIN dbo.instancesubject
                            ON assessmentform.subjectid = instancesubject.subjectid
                        INNER JOIN dbo.schoolyear
                            ON assessment.schoolyearid = schoolyear.schoolyearid
                        LEFT OUTER JOIN
                        /* inner join #RosterInfo on #RosterInfo.SchoolYearID = Assessment.SchoolYearID */
                        dbo.campus
                            ON campus.campusid = assessment.levelownerid
                        LEFT OUTER JOIN dbo.useraccount
                            ON useraccount.useraccountid = assessment.createdby
                        LEFT OUTER JOIN alltypevalues$appreportdefaultfilters AS a
                            ON a.rt = par_ReportType
                        WHERE assessmentformid = var_AssessmentFormID AND instancesubject.instanceid = var_InstanceID AND
                        /* Srinatha : Added below Assessment.IsLinked column for SC-16815 task */
                        assessment.islinked =
                        CASE
                            WHEN var_IncLinkedAssess = 0 THEN 0
                            ELSE assessment.islinked
                        END;
                END IF;
                /* Abdul:SC-7558-Network User Changes */

                IF var_AccessLevel IN ('N') THEN
                    /*
                    [7927 - Severity CRITICAL - PostgreSQL doesn't support OUTER joins for self-referenced tables without a primary key. Convert your source code manually.]
                    update A set NID = UserRoleNetwork.NetworkID, NN = Network.Name
                    				from UserRole
                    				join UserRoleNetwork on UserRole.UserRoleID = UserRoleNetwork.UserRoleID
                    				join Network on Network.NetworkID = UserRoleNetwork.NetworkID
                    				left join @AllTypeValues A on A.RT = @ReportType
                    				where UserRole.UserRoleID = @UserRoleID
                    */
                    BEGIN
                    END;
                END IF;

                IF var_AccessLevel IN ('C') THEN
                    /*
                    [7927 - Severity CRITICAL - PostgreSQL doesn't support OUTER joins for self-referenced tables without a primary key. Convert your source code manually.]
                    update A set  CID =  UserRoleCampus.CampusID, CN = Campus.Name
                    				from UserRole
                    				join UserRoleCampus on UserRole.UserRoleID = UserRoleCampus.UserRoleID
                    				join Campus on campus.CampusID = UserRoleCampus.CampusID
                    				left join @AllTypeValues A on A.RT = @ReportType
                    				where UserRole.UserRoleID = @UserRoleID
                    */
                    BEGIN
                    END;
                END IF;

                IF var_AccessLevel IN ('T') THEN
                    /*
                    [7927 - Severity CRITICAL - PostgreSQL doesn't support OUTER joins for self-referenced tables without a primary key. Convert your source code manually.]
                    Update A set TID = UserRoleTeacher.TeacherID, TN = Teacher.LastName + ', ' + Teacher.FirstName , CID = UserRoleCampus.CampusID, CN = Campus.Name
                    				from UserRole
                    				join UserRoleTeacher on UserRole.UserRoleID = UserRoleTeacher.UserRoleID
                    				join UserRoleCampus on UserRole.UserRoleID = UserRoleCampus.UserRoleID
                    				join Teacher on Teacher.TeacherID = UserRoleTeacher.TeacherID
                    				join Campus on campus.CampusID = UserRoleCampus.CampusID
                    				left join @AllTypeValues A on A.RT = @ReportType
                    				where UserRole.UserRoleID = @UserRoleID
                    */
                    BEGIN
                    END;
                END IF;

                IF var_bFromLMS = 0 THEN
                    /*
                    [9996 - Severity CRITICAL - Transformer error occurred in statement. Please submit report to developers.]
                    set @Result = (select '<Data> ' + replace(replace((select '<Type>' , RT, RYID, RYN, RDSID, RDSN, SYID, SYN, COLID, COLN, ALID, ALN, TID, TN, CID, CN,NID,NN, SBID, SBN, AID, AN , URCID, '</Type>'
                    				from @AllTypeValues FOR XML PATH ('')),'&lt;','<'),'&gt;','>') + '</Data>' )
                    */
                    IF EXISTS (SELECT
                        1
                        FROM dbo.usersetting
                        WHERE useraccountid = var_UserAccountID AND userroleid = par_UserRoleID AND settingid = 42
                        LIMIT 1) THEN
                        /*
                        [9996 - Severity CRITICAL - Transformer error occurred in statement. Please submit report to developers.]
                        update UserSetting set Value = '<Data> ' + replace(replace((select '<Type>' , RT, RYID, RYN, RDSID, RDSN, SYID, SYN, COLID, COLN, ALID, ALN, TID, TN, CID, CN,NID,NN, SBID, SBN, AID, AN , URCID, '</Type>'
                        					-- 19-Oct-2020: Manohar - Modified to improve the performance -- added SettingID = 42 in where condition
                        					from @AllTypeValues FOR XML PATH ('')),'&lt;','<'),'&gt;','>') + '</Data>' where UserAccountID = @UserAccountID and UserRoleID = @UserRoleID and SettingID = 42
                        */
                        BEGIN
                        END;
                    ELSE
                        INSERT INTO dbo.usersetting (useraccountid, settingid, value, sortorder, userroleid)
                        VALUES (var_UserAccountID, 42, var_Result, 1, par_UserRoleID);
                    END IF;
                END IF;
            END IF;
            DROP TABLE t$testattempt;
            /* drop table #Studentclass  --Sai: Commented and added it below. Bec we are using the #StudentClass in below query */

            IF par_ReportType = 'DDI' AND EXISTS (SELECT
                1
                FROM t$assessmentforminfo
                LIMIT 1) THEN
                var_bPreDefinedReport := 1;
                var_bDDIReport := 1;
            ELSE
                IF par_ReportType = 'P' AND EXISTS (SELECT
                    1
                    FROM t$assessmentforminfo
                    LIMIT 1) THEN
                    var_bPreDefinedReport := 1;
                    /* SC-25751 at below code Changed from LEFT JOIN to INNER JOIN to improving the performance/blocking issues */

                    IF EXISTS (SELECT
                        1
                        FROM t$tmpassessments AS t
                        JOIN dbo.assessmentform AS af
                            ON t.assessmentid = af.assessmentid
                        JOIN dbo.testattempt AS ta
                            ON af.assessmentformid = ta.assessmentformid
                        JOIN t$studentclass AS sc
                            ON ta.studentid = sc.studentid
                        JOIN t$stdlist AS sl
                            ON ta.studentid = sl.studentid
                        JOIN dbo.scoretopic AS st
                            ON af.assessmentformid = st.assessmentformid
                        WHERE st.typecode = 'T' AND sc.studentid IS NOT NULL AND sl.studentid IS NOT NULL
                        LIMIT 1) THEN
                        var_bDDIReport := 1;
                    END IF;
                END IF;
            END IF;
        END IF;
        DROP TABLE t$studentclass;
        var_AssessmentID := (SELECT
            aid
            FROM alltypevalues$appreportdefaultfilters
            WHERE rt = par_ReportType);
        CREATE TEMPORARY TABLE t$tmppetable
        (assessmentid INTEGER);
        var_RsQuery := ' and ( LevelCode = ''D'' ';

        IF var_AccessLevel = 'N' THEN
            /* Srinatha: added Network assessment code for @8.1 SC-7099/SC-8021 'Networks - Predefined Reports changes' task */
            var_ResultQuery := var_ResultQuery || ' OR (LevelCode = ''N'' And LevelOwnerID = ' || CAST (par_UserNetworkID AS VARCHAR(10)) || ')';
        END IF;

        IF var_AccessLevel = 'C' OR var_AccessLevel = 'T' THEN
            var_RsQuery := var_RsQuery || ' OR (LevelCode = ''C'' And LevelOwnerID = ' || CAST (par_UserCampusID AS VARCHAR(30)) || ')' || ' OR ( LevelCode = ''N'' And exists (select top 1 1 from NetworkCampus where NetWorkID = LevelOwnerID and CampusID = ' || CAST (par_UserCampusID AS VARCHAR(15)) || '))';
        END IF;

        IF var_AccessLevel = 'T' THEN
            var_RsQuery := var_RsQuery || ' OR (LevelCode = ''U'' And LevelOwnerID = ' || CAST (var_UserAccountID AS VARCHAR(30)) || ')';
        END IF;
        var_RsQuery := var_RsQuery || ')';
        /* Manohar\Rajesh Modified for SC-18101 added @AccessLevel case condition */
        var_ResultQuery1 :=
        CASE
            WHEN var_AccessLevel = 'T' AND var_FutureYear = 'N' THEN ' and Assessment.SchoolYearID <= ' || CAST (var_RosterYearID AS VARCHAR(10))
            ELSE ''
        END || ' and Assessment.SchoolYearID between ' || CAST ((var_CurrentYear - var_RosterPYear) AS VARCHAR(10)) || ' and ' || CAST (var_CurrentYear AS VARCHAR(10));
        var_Query := ' insert into #tmpPETable select Assessment.AssessmentID From Assessment  
	inner join AssessmentForm on Assessment.AssessmentID = AssessmentForm.AssessmentID  
	inner join ScoreTopic ST on AssessmentForm.AssessmentFormID = ST.AssessmentFormID and ST.TypeCode = ''T''
	where Assessment.ActiveCode = ''A'' and HasScores = 1 and Assessment.InstanceID = ' || CAST (var_InstanceID AS VARCHAR(10));
        /* Prasanna : Added below code for SC-16387 task to get SchoolYear based on "ReportSchoolYearID" setting */
        var_ResultQuery3 := var_Query || var_RsQuery || ' and Assessment.SchoolYearID =' || CAST (var_ReportSchoolYearID AS VARCHAR(10)) || ' group by Assessment.AssessmentID having count(StandardID) = ''5'' ';
        RAISE NOTICE '%', var_ResultQuery3;
        /*
        [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
        exec(@ResultQuery3)
        */
        IF NOT EXISTS (SELECT
            1
            FROM t$tmppetable
            LIMIT 1) THEN
            var_ResultQuery3 := var_Query || var_RsQuery || var_ResultQuery1 || ' group by Assessment.AssessmentID having count(StandardID) = ''5'' ';
            RAISE NOTICE '%', var_ResultQuery3;
            /*
            [7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
            exec(@ResultQuery3)
            */
        END IF;

        IF par_ReportType = '' AND EXISTS (SELECT
            1
            FROM t$tmppetable
            LIMIT 1) THEN
            var_bPEReport := 1;
        END IF;
        DROP TABLE t$tmppetable;
        /* Rajesh commented for SC-19799 */
        /* set @RosterYearID = (select  top 1 SchoolYearID from RosterDataSet where RosterDataSetID = @RosterDataSetID) */
        SELECT
            CASE
                WHEN typecode = 'B' THEN 'PermPLCAssessmentItemBank'
                ELSE 'PermPLCAssessmentOtherTypes'
            END
            INTO var_OTName
            FROM dbo.assessment
            WHERE assessmentid = var_AssessmentID;

        IF NOT EXISTS (SELECT
            1
            FROM plcpermissions$appreportdefaultfilters
            WHERE otname = var_OTName
            LIMIT 1) THEN
            var_IsPLCRolePerm := 0;
        ELSE
            var_IsPLCRolePerm := 1;
        END IF;

        IF (SELECT
            schoolyearid
            FROM dbo.rosterdataset
            WHERE isdefault = 1 AND instanceid = var_InstanceID
            LIMIT 1) = var_RosterYearID AND var_IsPLCRolePerm = 1 THEN
            /* MS: It is not only for default roster but for current year all rosters */
            SELECT
                plcid
                INTO var_AssPLCID
                FROM dbo.assessment
                WHERE assessmentid = var_AssessmentID;

            IF var_AssPLCID IS NOT NULL THEN
                /* If assessment is a PLC assessment */
                var_HavePLC := 1;
            /* MS: below code is not required just check the user is part of any PLC group. */
            ELSE
                IF var_AssPLCID IS NULL THEN
                    /* Assessment is not PLC assessment, but teachers are having plc's */
                    IF EXISTS (SELECT
                        1
                        FROM dbo.plc
                        JOIN dbo.plcuser
                            ON plc.plcid = plcuser.plcid
                        WHERE plc.instanceid = var_InstanceID AND plcuser.useraccountid = var_UserAccountID AND plc.activecode = 'A'
                        LIMIT 1) THEN
                        /* MS: No need of checking CreatedBy, always user should be part of PLCUser */
                        var_HavePLC := 1;
                    END IF;
                END IF;
            END IF;
        END IF;
        /* MS: Added @ReportType = '' because when it is called from LaunchPad @ReportType will be passed as blank */
        /* Madhushree K: Modified for [SC-24018] */

        IF par_From != 'AssessmentManager' THEN
            /* Sravani Balireddy: When Assessments are deactivates/Scores deleted/Embargoed in AssessmentManger page, we should not show any result */
            IF (par_From != 'DeleteScores' AND par_From != 'Assessment') THEN
                IF EXISTS (SELECT
                    1
                    FROM alltypevalues$appreportdefaultfilters
                    WHERE ryid = - 1 AND rt IN ('P', 'PE')
                    LIMIT 1) THEN
                    /* ** Nithin: 01-Nov-2018 - Modified to fix ticket #29561, added RT in (P, PE) condition. */
                    OPEN p_refcur_3 FOR
                    SELECT
                        aws_sqlserver_ext.tomsbit(0) AS predefinedreport, aws_sqlserver_ext.tomsbit(1) AS pereport;
                /* , @bDDIReport as DDIReport */
                ELSE
                    IF par_ReportType = '' AND par_From = '' THEN
                        OPEN p_refcur_4 FOR
                        SELECT
                            aws_sqlserver_ext.tomsbit(var_bPreDefinedReport) AS predefinedreport, aws_sqlserver_ext.tomsbit(var_bPEReport) AS pereport, var_HReport AS hreport, var_bDDIReport AS ddireport, var_InterimReport AS interimreport;
                    /* Rajesh uncommented for SC-20391 */
                    ELSE
                        IF par_ReportType != '' AND par_From = '' THEN
                            OPEN p_refcur_5 FOR
                            SELECT
                                var_bPreDefinedReport AS predefinedreport, var_bDDIReport AS ddireport, typecode || '~' || (CASE
                                    WHEN EXISTS (SELECT
                                        1
                                        FROM dbo.questiongroup AS qg
                                        WHERE qg.assessmentformid IN (SELECT
                                            assessmentformid
                                            FROM dbo.assessmentform
                                            WHERE assessmentid = var_AssessmentID)
                                        LIMIT 1) THEN '1'
                                    ELSE '0'
                                END) || '~' || (CASE
                                    WHEN EXISTS (SELECT
                                        1
                                        FROM dbo.scoretopic AS st
                                        WHERE st.assessmentformid IN (SELECT
                                            assessmentformid
                                            FROM dbo.assessmentform
                                            WHERE assessmentid = var_AssessmentID) AND st.typecode = 'T'
                                        LIMIT 1) THEN '1'
                                    ELSE '0'
                                END) || '~' || CAST (includenotes AS VARCHAR(2)) || '~' || CAST (isprogressbuild AS VARCHAR(2)) AS typecodeqgstatus, rt, ryid, ryn, COALESCE(rdsid, - 1) AS rdsid, COALESCE(rdsn, - 1) AS rdsn, syid, syn, COALESCE(colid, - 1) AS colid, COALESCE(coln, '') AS coln, COALESCE(alid, - 1) AS alid, COALESCE(aln, '') AS aln, COALESCE(tid, - 1) AS tid, COALESCE(tn, '') AS tn, COALESCE(cid, - 1) AS cid, COALESCE(cn, '') AS cn, sbid, sbn, aid, an, COALESCE(urcid, - 1) AS urcid,
                                CASE
                                    WHEN rt = 'P' AND var_HavePLC = 1 THEN 1
                                    WHEN rt = 'P' AND var_HavePLC = 0 THEN 0
                                    ELSE ''
                                END AS isplc,
                                CASE
                                    WHEN rt = 'P' AND var_HavePLC = 1 AND var_AssPLCID IS NOT NULL THEN var_AssPLCID
                                    WHEN rt = 'P' AND var_AssPLCID IS NULL THEN - 1
                                    ELSE ''
                                END AS plcid, COALESCE(nid, - 1) AS nid, COALESCE(nn, '') AS nn
                                FROM dbo.assessment
                                JOIN alltypevalues$appreportdefaultfilters AS a
                                    ON rt = par_ReportType
                                WHERE assessmentid = var_AssessmentID AND hasscores = 1 AND activecode = (CASE
                                    WHEN par_ReportType = 'INTR' THEN 'I'
                                    ELSE 'A'
                                END);
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
        /* Rajesh added For SC-20391 */
        /* to check whether the district default value for PLC users is set to access Non Rostered students */
        /* Manohar\Rajesh Modified for SC-18101 */
        /* Teacher Access for past Roster Data */
        /* Reading from setting(Teacher Access) */
        /* Assessment Data Access in Current Year Associated with Past Roster(Teacher Access) */
        /* Below are the report types that we are handling currently: */
        /* P: PreDefinedReport */
        /* DDI: DDI */
        /* L: Lead4Ward */
        /* PE: Principal Exchange */
        /* C: Curriculam & Instruction */
        /* BRR: BRR */
        /* S: SBAC */
        /* H: Horizon Report */
        /* INTR: Interim Report */
        /* This will contain 1 if Assessment exists for Predefined reports else 0. @since v4.1 */
        /* This will contain 1 if Assessment exists for DDI report else 0. @since v4.1 */
        /* This will contain 1 if Assessment exists for Principal's exchange Standard analysis report else 0. @since v4.2 */
        /* This will contain 1 if Assessment exists for Lead4Ward report */
        /* This will contain 1 if Assessment exists for SBAC report */
        /* This will contain 1 if Assessment exists for BRR report */
        /* This will contain 1 if Assessment exists for C&I report */
        /* Rajesh  Modified for SC-15445 */
        /* Srinath Added for SC-16815 task */
        /* Madhushree K: Modified for [SC-24018] */
        /* declare @bCheckForOtherAssessments		bit = 0 -- This will contains 1 if Assessment saved in UserSetting does not meet DDI criteria (Standards) and need to check if any other Assessments meets or not. */
        /* Sushmitha : SC-2549 - Include  CurrentStudent Table */
        /* Manohar: added to check whether the DDITab is enabled then only the DDI report queries should run else it will skip */
        /* Manohar\Rajesh Modified for SC-18101 */
        /* Manohar: Added the below code as in SDHC instance all parameters was coming as -1 and this proc was taking more than a minute */
        /* set the roster query and this will be used while checking every report type */
        /* Sushmitha : SC-2549 - Include CurrentStudent Table */
        /* set @RsQuery += */
        EXCEPTION
            WHEN OTHERS THEN
                var_Parameters := 'exec ' + 'appreportdefaultfilters' || ' @UserRoleID = ' || CAST (par_UserRoleID AS VARCHAR(50)) || ',
	@UserCampusID = ' || CAST (par_UserCampusID AS VARCHAR(50)) || ',
	@UserTeacherID = ' || CAST (par_UserTeacherID AS VARCHAR(50)) || ',
	@ReportType = ''' || par_ReportType || ''',
	@From = ''' || par_From || ''',
	@TemplateID = ''' || par_TemplateID || ''',@AID = ''' || par_AID || ''',@UserNetworkID = ' || CAST (par_UserNetworkID AS VARCHAR(50)) || '';
                /* Exception Handling, If we are getting any error, then required information will be stored into below Error Table */
                INSERT INTO dbo.errortable (dbname, query, errormessage, procedurename, createddate)
                VALUES (current_database(), var_Parameters, error_catch$ERROR_MESSAGE, 'appreportdefaultfilters', clock_timestamp());
                DROP TABLE IF EXISTS alltypevalues$appreportdefaultfilters;
                DROP TABLE IF EXISTS plcpermissions$appreportdefaultfilters;
    END;
    /*
    
    DROP TABLE IF EXISTS t$hasassessdata;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$stdlist;
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
    
    DROP TABLE IF EXISTS t$rosterstudents;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$plcids;
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
    /*
    
    DROP TABLE IF EXISTS t$tmpddiassessment;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$tmpassessmentids;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$l4wtemplatetable;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$rosterinfo;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$assessmentforminfo;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$testattempt;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$tmpassessments;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$tmpafids;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$tmppetable;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;


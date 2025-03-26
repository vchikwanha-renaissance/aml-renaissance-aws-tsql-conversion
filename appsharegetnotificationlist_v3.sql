-- ------------ Write DROP-PROCEDURE-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.appsharegetnotificationlist(IN XML, INOUT refcursor);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-PROCEDURE-stage scripts -----------

CREATE OR REPLACE PROCEDURE dbo.appsharegetnotificationlist(IN par_notificationxml XML, INOUT p_refcur refcursor)
AS 
$BODY$
/*
Revision History:
-------------------------------------------------------------------------------------------------------------------
DATE				CREATED BY						DESCRIPTION/REMARKS
-------------------------------------------------------------------------------------------------------------------
28-Aug-14			Anandan/Athar 					Get the Notification list.
08-Jul-15			Suresh V						Included Time Zone Functionality.
19-Nov-15           Anandan R						Added the condition for permanently delete notification.
18-Jan-16           Thoufic M						Added Audit report notification.
03-May-16           Ashish                          Returned AdditionalData column To Results.
13-May-16			Shruthi/Athar Baba				Updated the query to get the Notification in the Date desc order. Fix for customer ticket:15229
20-May-16			Rahini J						Modified this procedure as per Bug 24768.
17-OCT-16			Sandeep				            Added the forceSeek for Setting table
02-dec-16           sowjanya                        Removed forceSeek() function and added try_cast() function for @RequiredTZ variables
18-Oct-17           SUDHIR KRISHNA CH				Modified the procedure to handle the Support Plan in the Notifciation @V5.1.0
09-Jan-18			Sai Krishna						Modified the procedure to handle the ScoringEvent
09-Jan-18           Lokeshwari                      Modified to fix bug #39841
12-Feb-18			Manohar							Modified to return the result sorting on NotificationID desc
05-Jun-18			Kapil                           Modified to get the count and notification related to Dashboard
26-Sep-18           Ayesha Khanam                   Modified to get the count and notification relates to Survey
28-Sep-18			Sravani Balireddy				Added code @6.1 - RubricTemplate Notification conditions
17-Oct-18           Khushboo                        Modified for 'Allow teachers to share Assessments directly to specific school and district users' task 6.1
03-Jan-19			Srinatha R A					Modified for 6.2 Notification Enhancement task.
22-Feb-19			ChinnaReddy						Modified for 7.0 Survey Notifications will display an active survey link.
16-Oct-18			Ayesha Khanam					Modified for 7.0.0 [SC-72] Allow students and staff to take surveys in semi-anonymous mode task.
27-May-19			Venkatesh						Added Survey bulk print notification for [SC - 785] Survey - Print - Bulk Print Manager for Survey task v7.0.0
16-Oct-19			Venkatesh						Modified to fix SC-3383 issue that taking only Active survey & RubricTemplate when getting the notification count
30-Dec-19           Ayesha Khanam                   Modified to read Method of Delivery in Additional Data column for Survey to fix SC-4811
04-Mar-20			Abdul Rahiman					Modified for SC-3462-7.2 -QTI Notifications
09-Jul-20			Srinatha						Modified to fix SC-7730 'No notifications displying at notification center' issue.
26-Nov-21           Madhushree K                    Modified for [SC-15450] Notifications for Bulk Download of Student Summary Report
20-May-22			JayaPrakash						Modified to avoid SQL Injections SC-19606
24-Apr-23			JayaPrakash						Modified for SC-24869-HISD and Suite version Merging Preparation task.
23-jun-23           Rakshith H S                    Modified for SC-25801 Prodqa02 | Dashbaord |User's are not getting notifications for shared dashboard.
20-Sep-24           Srikanth CH                     Modified for SC-32565 HISD DB Performance Issue: Save Online Administration Procedure
-------------------------------------------------------------------------------------------------------------------
*/
/*
EXEC [dbo].[appShareGetNotificationList]'<Notification><CT>0</CT><UID>1052031</UID><URID></URID><NT>n</NT><FD>-1</FD><TD>-1</TD><SS></SS></Notification>'
EXEC [dbo].[ZappShareGetNotificationListKK]'<Notification><CT>0</CT><IID>2700001</IID><UID>1042614</UID><UCID>1100047</UCID><NT>o</NT><URID>1141347</URID><FD>-1</FD><TD>-1</TD><SS>-1</SS></Notification>'
*/
DECLARE
    var_Count INTEGER;
    var_TotalNotificationCount INTEGER;
    var_UserAccountID INTEGER;
    var_UserRoleID INTEGER;
    var_Type VARCHAR(2);
    var_FromDate VARCHAR(20);
    var_ToDate VARCHAR(20);
    var_SearchString TEXT;
    var_Query TEXT;
    var_RequiredTZ INTEGER;
    var_AccessLevelCode CHAR(1);
    var_InstanceID INTEGER;
    var_UserCampusID INTEGER;
    var_Ishisd NUMERIC(1, 0) DEFAULT 0;
    var_Parameters TEXT DEFAULT '';
BEGIN
    BEGIN

        /* GENERATIVE AI CODE BELOW: agent-analyze-sct-action-items */ 
        SELECT
            (xpath('//CT/text()', x.objNode))[1]::text::integer AS var_Count,
            (xpath('//IID/text()', x.objNode))[1]::text::integer AS var_InstanceID,
            (xpath('//UID/text()', x.objNode))[1]::text::integer AS var_UserAccountID,
            (xpath('//URID/text()', x.objNode))[1]::text::integer AS var_UserRoleID,
            (xpath('//UCID/text()', x.objNode))[1]::text::integer AS var_UserCampusID,
            (xpath('//NT/text()', x.objNode))[1]::text::varchar(2) AS var_Type,
            (xpath('//FD/text()', x.objNode))[1]::text::varchar(20) AS var_FromDate,
            (xpath('//TD/text()', x.objNode))[1]::text::varchar(20) AS var_ToDate,
            (xpath('//SS/text()', x.objNode))[1]::text AS var_SearchString
        INTO
            var_Count, var_InstanceID, var_UserAccountID, var_UserRoleID, var_UserCampusID,
            var_Type, var_FromDate, var_ToDate, var_SearchString
        FROM
            unnest(xpath('/Notification', par_NotificationXML)) AS x(objNode);

        /* SC-19606, Below Function added by JayaPrakash to avoid SQL Injections attacks, START */
        /* Here 1-to check the issue in Parameters, 2 - check issue at comma seperated values, 3 - check Sortcolumn */
        IF (SELECT
            dbo.appfngetinjectionids(var_SearchString, 1)) = - 1 THEN
            RETURN;
        END IF;
        /* Added for SC-24869-HISD and Suite version Merging Preparation task. */

        IF EXISTS (SELECT
            1
            FROM dbo.applicationsetting
            WHERE settingid IN (SELECT
                settingid
                FROM dbo.setting
                WHERE shortname = 'CodeBase') AND value = 'hisd'
            LIMIT 1) THEN
            var_Ishisd := 1;
        END IF;
        SELECT
            (CASE
                WHEN accesslevelcode = 'T' THEN 'U'
                ELSE accesslevelcode
            END)
            INTO var_AccessLevelCode
            FROM dbo.role
            JOIN dbo.userrole
                ON role.roleid = userrole.roleid
            WHERE userroleid = var_UserRoleID AND userrole.useraccountid = var_UserAccountID;
        SELECT
            CASE
                WHEN aws_sqlserver_ext.ISNUMERIC(instancesetting.value) THEN CAST (instancesetting.value AS INTEGER)
                ELSE NULL
            END
            INTO var_RequiredTZ
            FROM dbo.instancesetting
            JOIN dbo.setting
                ON setting.settingid = instancesetting.settingid
            WHERE name = 'TimezoneOffset' AND instanceid = (SELECT
                instanceid
                FROM dbo.useraccount
                WHERE useraccountid = var_UserAccountID);
        /* Venkatesh : Added condition to get only Active and Non/Semi Anonymous surveys while returning the notification count */

        IF (var_Count = 1) THEN

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'select count(distinct NotificationID) from (
                                            select NotificationID from Notification N 
                                            join ObjectType OT on OT.ObjectTypeID = N.ObjectTypeID
                                            join Survey S on N.ObjectId = S.SurveyID 
                                            where N.ToUserAccountID = ' || var_UserAccountID::text || ' and N.ActionCode IS NULL and S.ActiveCode = ''A'' 
                                            and Mode != 1 and N.TypeCode = ''SUR'' and OT.Name = ''Survey''
                                            union all
                                            select NotificationID from Notification N 
                                            join ObjectType OT on OT.ObjectTypeID = N.ObjectTypeID
                                            join RubricTemplate RT on RT.RubricTemplateId = N.ObjectID 
                                            where N.ToUserAccountID = ' || var_UserAccountID::text || ' and N.ActionCode IS NULL and OT.Name = ''RubricTemplate''
                                            union all
                                            (Select Notification.notificationId from notification
                                            inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID
                                            --left outer join Assessment ON Assessment.assessmentID = Notification.ObjectID and ObjectType.Name = ''Assessment''
                                            --left outer join Report ON Report.reportID = Notification.ObjectID and  ObjectType.Name = ''Report''
                                            --left outer join DashboardPage ON DashboardPage.DashboardPageID = Notification.ObjectID and  ObjectType.Name = ''DashboardPage''
                                            Where Notification.ToUserAccountID = ' || var_UserAccountID::text || ' and Notification.ActionCode IS NULL
                                            and notification.TypeCode != ''SAL'' and Notification.Typecode != ''SUR'' 
                                            and Notification.ObjectTypeID not in (select ObjectTypeID from objectType where Name in(''RubricTemplate'', ''QTIExport'') )) 
                                            union all
                                            select NotificationID from Notification N 
                                            join ObjectType OT on OT.ObjectTypeID = N.ObjectTypeID
                                            join PrintJob P on P.PrintJobID = N.ObjectID 
                                                and P.ObjectTypeID in (select ObjectTypeID from ObjectType where ObjectType.Name in (''Bank'',''Assessment'')) 
                                            where N.ToUserAccountID = ' || var_UserAccountID::text || ' and N.ActionCode IS NULL and OT.Name = ''QTIExport'' and N.TypeCode = ''BLKR''
                                            and P.StatusCode in (''3'', ''D'')
                                            ) Count';


            /* GENERATIVE AI CODE BELOW: agent-analyze-sct-action-items */ 
            EXECUTE format('%s', var_Query);

        ELSE
            /* Khushboo : Added below table to check LevelCode for Assessment that is accepted by other user ' */
            /* for 'Allow teachers to share Assessments directly to specific school and district users' task 6.1 */
            CREATE TEMPORARY TABLE t$permission
            (roleid INTEGER,
                accesslevelcode CHAR(1),
                objecttype VARCHAR(100));
            INSERT INTO t$permission
            SELECT DISTINCT
                r.roleid, r.accesslevelcode, ot.name
                FROM dbo.operation AS o
                JOIN dbo.permission AS p
                    ON o.operationid = p.operationid
                JOIN dbo.objecttype AS ot
                    ON ot.objecttypeid = p.objecttypeid
                JOIN dbo.rolepermission AS rp
                    ON rp.permissionid = p.permissionid
                JOIN dbo.userrole AS ur
                    ON ur.roleid = rp.roleid
                JOIN dbo.role AS r
                    ON r.roleid = ur.roleid
                WHERE ur.userroleid = var_UserRoleID AND r.instanceid = var_InstanceID AND o.name = 'View' AND r.activecode = 'A' AND COALESCE(rp.scopecode, 'A') <> 'N' AND ot.name IN ('TOtherTypes', 'COtherTypes', 'DOtherTypes', 'TItemBank', 'CItemBank', 'DItemBank');
            CREATE TEMPORARY TABLE t$assesslevel
            (notificationid INTEGER,
                objectid INTEGER,
                actionobjectid INTEGER,
                levelcode CHAR(1),
                levelownerid INTEGER,
                typecode CHAR(1));

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'INSERT INTO tmp_AssessLevel
                          SELECT N2.NotificationID, N2.ObjectID, N2.ActionObjectID, A.LevelCode, A.LevelOwnerID, A.TypeCode 
                          FROM (SELECT ObjectID FROM Notification N1
                                JOIN ObjectType OT ON OT.ObjectTypeID = N1.ObjectTypeID AND OT.Name = ''Assessment'' 
                                JOIN UserAccount UA ON UA.UserAccountID = N1.CreatedBy
                                JOIN Assessment A ON A.AssessmentID = N1.ObjectID 
                                WHERE N1.ToUserAccountID = ' || var_UserAccountID::text || ' AND N1.ActionCode IS NULL AND N1.TypeCode <> ''SOCRWP'') Z
                          JOIN Notification N2 ON Z.ObjectID = N2.ObjectID
                          JOIN Assessment A ON N2.ActionObjectID = A.AssessmentID
                          JOIN tmp_Permission P ON A.LevelCode = P.AccessLevelCode
                          WHERE N2.ActionCode = ''A'' AND A.ActiveCode = ''A'' AND N2.ActionObjectID IS NOT NULL AND N2.TypeCode <> ''SOCRWP''
                          AND (' || 
                          COALESCE(NULLIF(CONCAT(
                            CASE WHEN EXISTS (SELECT 1 FROM t$permission WHERE objecttype = ''DOtherTypes'' LIMIT 1) 
                                 THEN 'A.LevelCode = ''D'' AND A.TypeCode <> ''B''' ELSE NULL END,
                            CASE WHEN EXISTS (SELECT 1 FROM t$permission WHERE objecttype = ''DItemBank'' LIMIT 1) 
                                 THEN ' OR A.LevelCode = ''D'' AND A.TypeCode = ''B''' ELSE NULL END,
                            CASE WHEN EXISTS (SELECT 1 FROM t$permission WHERE objecttype = ''COtherTypes'' LIMIT 1) AND var_AccessLevelCode IN (''C'', ''T'') 
                                 THEN ' OR A.LevelCode = ''C'' AND A.LevelOwnerID = ' || var_UserCampusID::text || ' AND A.TypeCode <> ''B''' ELSE NULL END,
                            CASE WHEN EXISTS (SELECT 1 FROM t$permission WHERE objecttype = ''CItemBank'' LIMIT 1) AND var_AccessLevelCode IN (''C'', ''T'') 
                                 THEN ' OR A.LevelCode = ''C'' AND A.LevelOwnerID = ' || var_UserCampusID::text || ' AND A.TypeCode = ''B''' ELSE NULL END
                          ), ''), 'FALSE') || ')';

            RAISE NOTICE '%', var_Query;

            /* GENERATIVE AI CODE BELOW: agent-analyze-sct-action-items */ 
            EXECUTE format('INSERT INTO t$assesslevel %s', var_Query);

            /* SC-32565 : Created temp table to Improve performance */
            CREATE TEMPORARY TABLE t$notification
            (objectid INTEGER,
                objecttypeid SMALLINT,
                createddate VARCHAR(10),
                name VARCHAR(200),
                displayname VARCHAR(200),
                fn VARCHAR(100),
                ln VARCHAR(100),
                description TEXT,
                notificationid INTEGER,
                actioncode VARCHAR(10),
                actiondate VARCHAR(10),
                hasdocuments NUMERIC(1, 0),
                additionaldata TEXT,
                accepted SMALLINT);

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT  Notification.ObjectID, Notification.ObjectTypeID, 
                                            TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') as CreatedDate, 
                                            ObjectType.Name, Assessment.name as displayname, 
                                            UserAccount.FirstName::text AS Fn, UserAccount.LastName::text as Ln, 
                                            notification.Description::text as Description, Notification.NotificationID, 
                                            (CASE WHEN Notification.ActionCode = ''A'' AND Notification.ActionObjectID IS NULL THEN ''O'' ELSE Notification.ActionCode END) ActionCode, 
                                            TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') as ActionDate,
                                            Assessment.HasDocuments, Notification.AdditionalData,
                                            (CASE WHEN AL.LevelCode = ''D'' THEN 1
                                                  WHEN AL.LevelCode = ''C'' THEN 2
                                                  ELSE 0 END) as Accepted 
                            FROM Notification
                            INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''Assessment'' 
                            INNER JOIN UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
                            INNER JOIN Assessment ON Assessment.assessmentID = Notification.ObjectID 
                            LEFT OUTER JOIN tmp_AssessLevel AL ON AL.ObjectID = Notification.ObjectID 
                            WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text || ' AND Notification.TypeCode <> ''SOCRWP'' ';

            /* Khushboo : commented below code and added above code for 'Allow teachers to share Assessments directly to specific school and district users' task 6.1 */
            /* set @Query = 'select ObjectID, ObjectTypeID, CreatedDate, Name, displayname, Fn, Ln, Description, NotificationID, ActionCode, ActionDate, HasDocuments, AdditionalData from (' */
            /* set @Query += 'SELECT  Notification.ObjectID, Notification.ObjectTypeID, */
            /* Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, ObjectType.Name, Assessment.name as displayname, */
            /* cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, */
            /* cast(notification.Description  as varchar(max)) [Description], Notification.NotificationID, Notification.ActionCode, Convert(varchar(10), Notification.ActionDate, 101) as ActionDate, */
            /* Assessment.HasDocuments, Notification.AdditionalData */
            /* FROM Notification */
            /* inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and ObjectType.Name = ''Assessment'' */
            /* inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy */
            /* inner join Assessment ON Assessment.assessmentID = Notification.ObjectID */
            /* Where Notification.ToUserAccountID = ' + cast(@UserAccountID as varchar) */

            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' and Notification.ActionCode is null ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' AND Assessment.name like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                ObjectType.Name, Report.Name::text AS displayname, UserAccount.FirstName::text AS Fn,
                UserAccount.LastName::text AS Ln, notification.Description::text AS Description,
                Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate, '''', Notification.AdditionalData, '''' 
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''Report''
                INNER JOIN UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
                INNER JOIN Report ON Report.ReportID = Notification.ObjectID 
            WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text || ' AND Notification.TypeCode <> ''BLKR''';


            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' and Report.name like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                ObjectType.Name, CDData.Label::text AS displayname, 
                UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate, '''', Notification.AdditionalData, ''''
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''AsyncReport''
                INNER JOIN UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
                INNER JOIN (
                    SELECT CDF.Code, CDF.Label 
                    FROM CodeDomain CD 
                    JOIN CodeDefinition CDF ON CD.CodeDomainID = CDF.CodeDomainID 
                    WHERE CD.Name = ''AsyncReport''
                ) CDData ON Notification.TypeCode = CDData.Code
            WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text;


            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                var_Query := var_Query || ' AND Notification.ActionCode <> ''D''';
                /* Added for SC-24869-HISD and Suite version Merging Preparation task. */

                IF var_Ishisd = 0 THEN
                    IF (var_SearchString != '-1') THEN
                        var_Query := var_Query || ' and CAST(CDData.Label AS varchar(max)) like  ''%' || var_SearchString || '%''';
                    END IF;
                END IF;
            END IF;
            /* Shruthi has commented below code since we are not using SAL */
            /* set @Query += ' union ' */
            /* set @Query += ' select  Notification.ObjectID, Notification.ObjectTypeID, */
            /* Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, */
            /* ObjectType.Name, CAST(SALPLan.Name AS varchar(max)) as displayname, cast(UserAccount.FirstName AS varchar(max)) AS Fn, */
            /* cast(UserAccount.LastName AS varchar(max)) as Ln, cast(notification.Description  as varchar(max)) as [Description], */
            /* Notification.NotificationID, Notification.ActionCode, Convert(varchar(10), Notification.ActionDate, 101) as ActionDate, */
            /* '''', Notification.AdditionalData, '''' */
            /* from Notification */
            /* inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''SALPlan'' */
            /* inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy */
            /* inner join SALPlan ON SALPLan.SALPlanID = Notification.ObjectID */
            /* Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar) */
            /* if(@Type = 'n') */
            /* begin */
            /* set @Query+= ' AND Notification.ActionCode IS NULL ' */
            /* end */
            /* else */
            /* begin */
            /* if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1' */
            /* if(@SearchString != '-1')  set @Query+= ' and SALPLan.Name like  ''%' + @SearchString + '%''' */
            /* set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''' */
            /* end */
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                ObjectType.Name, ScoringEvent.Name::text AS displayname, 
                UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate, '''', Notification.AdditionalData, '''' 
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''ScoringEvent''
                INNER JOIN ScoringEvent ON ScoringEvent.ScoringEventID = Notification.ObjectID 
                INNER JOIN UserAccount ON UserAccount.UserAccountID = ScoringEvent.CreatedBy
            WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text;


            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' and ScoringEvent.name like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            /* Added Dashboard Notification conditions */
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                ObjectType.Name, DashboardPage.Name::text AS displayname, 
                UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate, '''', Notification.AdditionalData, '''' 
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''DashboardPage''
                INNER JOIN DashboardPage ON DashboardPage.DashboardPageID = Notification.ObjectID 
                INNER JOIN UserAccount ON UserAccount.UserAccountID = DashboardPage.UserAccountID
            WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text;


            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' and DashboardPage.name like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            /* Added Survey Notification -- ChinnaReddy : Modified for @v7.0 (SC-70 Survey Notifications will display an active survey link) */
            /* In Additional column added Survey Start date, End date, AllowResubmission, IsSurveySubmit values as a JSON object. */
            /* Added  Survey.ActiveCode = 'A' and Mode = 0 also. */
            /* Ayesha : Modified to read Method Of Delivery also */
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                ObjectType.Name, Survey.Name::text AS displayname, 
                UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate,
                '''', 
                json_build_object(
                    ''StartDate'', TO_CHAR(Survey.StartDate, ''MM/DD/YYYY''),
                    ''EndDate'', TO_CHAR(Survey.EndDate, ''MM/DD/YYYY''),
                    ''WindowStart'', Survey.WindowStart::text,
                    ''WindowEnd'', Survey.WindowEnd::text,
                    ''WindowDays'', Survey.WindowDays::text,
                    ''AllowResubmission'', Survey.AllowResubmission::text,
                    ''IsSurveySubmit'', (CASE WHEN EXISTS (SELECT 1 FROM SurveyAttempt WHERE SurveyID = Survey.SurveyID AND UserAccountID = ' || var_UserAccountID::text || ' LIMIT 1) THEN ''1'' ELSE ''0'' END),
                    ''MethodOfDelivery'', Survey.MethodOfDelivery::text
                )::text AS AdditionalData,
                ''''
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''Survey''
                INNER JOIN Survey ON Survey.SurveyID = Notification.ObjectID 
                INNER JOIN UserAccount ON UserAccount.UserAccountID = Survey.CreatedBy
            WHERE Survey.ActiveCode = ''A'' AND Mode != 1 AND Notification.ToUserAccountID = ' || var_UserAccountID::text || ' AND Notification.TypeCode = ''SUR''';


            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' and Survey.name like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            RAISE NOTICE '%', var_Query;
            /* Sravani Balireddy : Added below code @6.1 - RubricTemplate Notification conditions */
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;
            /* ** Nithin: 07-11-2019 - Modified to support Notification featue - [SC-79] - HISD Notification Enhancements. @since v7.0.0. Modified query to join Notification table with AssessmentForm table. */

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                ObjectType.Name, RubricTemplate.Name::text AS displayname, 
                UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate,
                '''', Notification.AdditionalData, ''''
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''RubricTemplate''
                INNER JOIN RubricTemplate ON RubricTemplate.RubricTemplateID = Notification.ObjectID 
                INNER JOIN UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
            WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text;


            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' and RubricTemplate.name like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            /* Srinatha R A : Added below code @6.2 - Notification Enhancement task */
            /* To Show Score CR/WP Items Notification */
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                ''Assessment Scoring'' AS ObjectTypeName, Assessment.Name::text AS displayname, 
                UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate, '''',
                Notification.AdditionalData AS AdditionalData, ''''
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID ';

            /* Added for SC-24869-HISD and Suite version Merging Preparation task. */

            IF var_Ishisd = 0 THEN
                var_Query := var_Query || ' and  ObjectType.Name = ''Assessment'' ';
            ELSE
                var_Query := var_Query || ' and  ObjectType.Name = ''AssessmentForm'' ';
            END IF;
            /* Rakshith modified below query and added AssessmentForm table join for SC-25801. */

            IF var_Ishisd = 0 THEN
                var_Query := var_Query || ' inner join Assessment ON Assessment.AssessmentID = Notification.ObjectID ';
            ELSE
                var_Query := var_Query || ' inner join AssessmentForm on Notification.ObjectID = AssessmentForm.AssessmentFormID
										inner join Assessment ON Assessment.AssessmentID = AssessmentForm.AssessmentID ';
            END IF;
            var_Query := var_Query || ' inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
								Where Notification.ToUserAccountID = ' || CAST (var_UserAccountID AS VARCHAR(30)) || ' and Notification.TypeCode = ''SOCRWP'' ';

            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' and Assessment.name like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            /* To Show Bulk Answer sheet Notification */
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                ''Answer Sheets'' AS ObjectTypeName, Assessment.Name::text AS displayname, 
                UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate, '''',
                Notification.AdditionalData || ''", "Grade" : "'' || 
                CASE WHEN Grade.ShortName IS NOT NULL THEN Grade.ShortName || ''"''
                     ELSE ''"'' END || ''}'' AS AdditionalData, 
                CASE WHEN EXISTS (
                    SELECT 1 FROM PrintJob
                    WHERE PrintJob.ObjectID = Notification.ObjectID 
                    AND Notification.ObjectTypeID = PrintJob.ObjectTypeID
                    AND SUBSTRING(Notification.AdditionalData, 17, 
                        POSITION(''"'' IN SUBSTRING(Notification.AdditionalData, 17)) - 1)::bigint = PrintJob.PrintJobID
                ) THEN 1 ELSE 0 END AS HasPrintJob
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''AssessmentForm''
                INNER JOIN AssessmentForm ON AssessmentForm.AssessmentFormID = Notification.ObjectID 
                INNER JOIN Assessment ON Assessment.AssessmentID = AssessmentForm.AssessmentID 
                INNER JOIN Subject ON Subject.SubjectID = AssessmentForm.SubjectID
                LEFT JOIN Grade ON Grade.GradeID = AssessmentForm.GradeID 
                INNER JOIN UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
            WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text || ' AND Notification.TypeCode = ''BLKR''';


            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' and Assessment.name like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            /* To Show PDF Score online CR/WP items Notification */
            /* Madhushree K: Modified for [SC-15450] Notifications for Bulk Download of Student Summary Report */
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                CASE WHEN ObjectType.Name = ''HorizonBulkDownload'' THEN ''Horizon Report'' ELSE ''PDF of CR/WP Items'' END AS ReportType,
                Assessment.Name::text AS displayname, 
                UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate,
                '''', Notification.AdditionalData || ''"}'' AS AdditionalData, 
                CASE WHEN EXISTS (
                    SELECT 1 FROM PrintJob
                    WHERE PrintJob.ObjectID = Notification.ObjectID 
                    AND Notification.ObjectTypeID = PrintJob.ObjectTypeID
                    AND SUBSTRING(Notification.AdditionalData, 17, 
                        POSITION(''"'' IN SUBSTRING(Notification.AdditionalData, 17)) - 1)::bigint = PrintJob.PrintJobID
                ) THEN 1 ELSE 0 END AS HasPrintJob
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID 
                AND ObjectType.Name IN (''BulkPrintCR'', ''HorizonBulkDownload'')
                INNER JOIN Assessment ON Assessment.AssessmentID = Notification.ObjectID 
                INNER JOIN UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
            WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text || ' AND Notification.TypeCode = ''BLKR''';


            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' and Assessment.name like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            /* To Show Standards Progression Notification */
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                ''Standards Progression Report'' AS ReportType, Report.Name::text AS displayname, 
                UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate,
                '''', Notification.AdditionalData || ''"}'' AS AdditionalData, 
                CASE WHEN EXISTS (
                    SELECT 1 FROM PrintJob
                    WHERE PrintJob.ObjectID = Notification.ObjectID 
                    AND Notification.ObjectTypeID = PrintJob.ObjectTypeID
                    AND SUBSTRING(Notification.AdditionalData, 17, 
                        POSITION(''"'' IN SUBSTRING(Notification.AdditionalData, 17)) - 1)::bigint = PrintJob.PrintJobID
                ) THEN 1 ELSE 0 END AS HasPrintJob
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''Standards Progression''
                INNER JOIN Report ON Report.ReportID = Notification.ObjectID 
                INNER JOIN UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
            WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text || ' AND Notification.TypeCode = ''BLKR''';


            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' and Report.name like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            /* To Show Student History Notification */

            IF (var_SearchString = '-1') THEN
                EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
                /* SC-32565 insert into Temptable */
                ;

                /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                    TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                    ''Student History Report'' AS ReportType, '''' AS displayname, 
                    UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                    notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                    TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate,
                    '''', Notification.AdditionalData || ''"}'' AS AdditionalData, 
                    CASE WHEN EXISTS (
                        SELECT 1 FROM PrintJob
                        WHERE Notification.ObjectTypeID = PrintJob.ObjectTypeID
                        AND SUBSTRING(Notification.AdditionalData, 17, 
                            POSITION(''"'' IN SUBSTRING(Notification.AdditionalData, 17)) - 1)::bigint = PrintJob.PrintJobID
                    ) THEN 1 ELSE 0 END AS HasPrintJob
                FROM Notification
                    INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''Report''
                    INNER JOIN UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
                WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text || ' AND Notification.TypeCode = ''BLKR''';


                IF (var_Type = 'n') THEN
                    var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
                ELSE
                    IF (var_FromDate != '-1') THEN

                        /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                        var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                            DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                            AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                    END IF;
                    /* if(@SearchString != '-1')  set @Query+= ' and Report.name like  ''%' + @SearchString + '%''' */
                    var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
                END IF;
            END IF;
            /* To get Survey Sheets Notifications */
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                ''Survey Sheets'' AS ReportType, Survey.Name::text AS displayname, 
                UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate,
                '''', Notification.AdditionalData || ''"}'' AS AdditionalData, 
                CASE WHEN EXISTS (
                    SELECT 1 FROM PrintJob
                    WHERE PrintJob.ObjectID = Notification.ObjectID 
                    AND Notification.ObjectTypeID = PrintJob.ObjectTypeID
                    AND SUBSTRING(Notification.AdditionalData, 17, 
                        POSITION(''"'' IN SUBSTRING(Notification.AdditionalData, 17)) - 1)::bigint = PrintJob.PrintJobID
                ) THEN 1 ELSE 0 END AS HasPrintJob
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''Survey''
                INNER JOIN Survey ON Survey.SurveyID = Notification.ObjectID 
                INNER JOIN UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
            WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text || ' AND Notification.TypeCode = ''BLKR''';


            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' and Survey.name like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            /* set @Query+= 'order by CreatedDate desc' */
            /* Abdul:  SC-3462: To Show QTIExport Notification */
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;

            /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
            var_Query := 'SELECT Notification.ObjectID, Notification.ObjectTypeID, 
                TO_CHAR(GetDateTimeByTimezone(Notification.CreatedDate, ' || var_RequiredTZ::text || '), ''MM/DD/YYYY'') AS CreatedDate, 
                ''QTIExport'' AS ReportType, AttachedFile.OriginalName::text AS DisplayName, 
                UserAccount.FirstName::text AS Fn, UserAccount.LastName::text AS Ln, 
                notification.Description::text AS Description, Notification.NotificationID, Notification.ActionCode, 
                TO_CHAR(Notification.ActionDate, ''MM/DD/YYYY'') AS ActionDate, '''',
                json_build_object(
                    ''PrintJobID'', AttachedFile.ObjectID::text,
                    ''QTIFileName'', AttachedFile.OriginalName,
                    ''DateRequested'', TO_CHAR(P.CreatedDate, ''MM-DD-YYYY HH24:MI:SS'')
                )::text AS AdditionalData,
                NULL
            FROM Notification
                INNER JOIN ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID AND ObjectType.Name = ''QTIExport''
                INNER JOIN PrintJob P ON P.PrintJobID = Notification.ObjectID 
                    AND P.ObjectTypeID IN (SELECT ObjectTypeID FROM ObjectType WHERE ObjectType.Name IN (''Bank'', ''Assessment''))
                INNER JOIN AttachedFile ON AttachedFile.ObjectID = P.PrintJobID 
                    AND AttachedFile.ObjectTypeID = (SELECT ObjectTypeID FROM ObjectType WHERE ObjectType.Name = ''PrintJob'')
                INNER JOIN UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
            WHERE Notification.ToUserAccountID = ' || var_UserAccountID::text || ' AND Notification.TypeCode = ''BLKR''';


            IF (var_Type = 'n') THEN
                var_Query := var_Query || ' AND Notification.ActionCode IS NULL ';
            ELSE
                IF (var_FromDate != '-1') THEN

                    /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                    var_Query := var_Query || ' AND Notification.CreatedDate BETWEEN 
                        DATE_TRUNC(''day'', ' || quote_literal(var_FromDate::date) || '::date) 
                        AND (DATE_TRUNC(''day'', ' || quote_literal(TRIM(var_ToDate)::date) || '::date) + INTERVAL ''1 day'')';

                END IF;

                IF (var_SearchString != '-1') THEN
                    var_Query := var_Query || ' and AttachedFile.OriginalName like  ''%' || var_SearchString || '%''';
                END IF;
                var_Query := var_Query || ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D''';
            END IF;
            EXECUTE CONCAT('INSERT INTO t$notification', ' ', var_Query)
            /* SC-32565 insert into Temptable */
            ;
            OPEN p_refcur_0 FOR
            SELECT
                *
                FROM t$notification
                ORDER BY CAST (createddate AS DATE) DESC NULLS LAST, notificationid DESC NULLS LAST;
        END IF;
        /* Khushboo : added the parameter for 'Allow teachers to share Assessments directly to specific school and district users' task 6.1 */
        /* Khushboo : added the parameter for 'Allow teachers to share Assessments directly to specific school and district users' task 6.1 */
        EXCEPTION
            WHEN OTHERS THEN

                /* GENERATIVE AI CODE BELOW: agent-analyze-dynamic-sql-v2 */ 
                var_Parameters := 'SELECT appsharegetnotificationlist(' || quote_literal(par_NotificationXML::text) || ')';

                /* Exception Handling, If we are getting any error, then required information will be stored into below Error Table */
                INSERT INTO dbo.errortable (dbname, query, errormessage, procedurename, createddate)
                VALUES (current_database(), var_Parameters, error_catch$ERROR_MESSAGE, 'appsharegetnotificationlist', clock_timestamp());
                OPEN p_refcur FOR
                SELECT
                    - 1;
    END;
    /*
    
    DROP TABLE IF EXISTS t$permission;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$assesslevel;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$notification;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;



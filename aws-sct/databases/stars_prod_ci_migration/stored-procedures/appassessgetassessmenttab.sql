-- ------------ Write DROP-PROCEDURE-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.appassessgetassessmenttab(IN NUMERIC, IN NUMERIC, IN NUMERIC, IN INTEGER, INOUT refcursor);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-PROCEDURE-stage scripts -----------

CREATE OR REPLACE PROCEDURE dbo.appassessgetassessmenttab(IN par_instanceid NUMERIC, IN par_useraccountid NUMERIC, IN par_userroleid NUMERIC, IN par_campusid INTEGER DEFAULT -1, INOUT p_refcur refcursor DEFAULT NULL)
AS 
$BODY$
/* Madhushree K : Added for Bug [SC-5702]. */

/*
Revision History:
       ---------------------------------------------------------------------------------------------------------------------------------------------
       DATE                             CREATED/VERIFIED BY                        DESCRIPTION/REMARKS
       ---------------------------------------------------------------------------------------------------------------------------------------------
       02-Jan-14                        Athar/Rizwan                                Orginated.
	   17-Nov-16						Shruthi/Rahini.J							showing bulk activaion tab v3.2.0
	   13-Dec-16						Rahini.J								    Modified to fix Bug 29050
	   09-Mar-17                        Kapil                                       Added the premade coloumn and changed the selection of the order.
       27-Mar-17						Suresh vagalla								Increased size of NAME in #TABTABLE column.
	   03-Apr-17                        Kapil                                       Added Settings columns
	   23-May-17						Shruthi/ Mahananda							Added REPLACE (SAT.Name , '&' , '' ) for CI tab as per Bug 33252 since V5.0.0
	   28-Jun-17						Suresh Vagalla\Subhashish					Added "Bulk Publish Assessments" Tab based on the permissions.
	   11-Jul-17						Suresh Vagalla\Subhashish					Added "Bulk Publish Assessments" bug fix code
	   31-Aug-17						Shruthi Shetty								Modified to fix ZDT 21986
	   28-May-19						Nithin										Modified to support PLC Groups - SC-127. @since v7.0.0
	   14-Feb-20                        Madhushree K                                Modified for Bug [SC-5702] 7.2 - Premade assessment - Based on the campus(scadmin) permission premade assessments rows are not showing in campus user.
	   16-Jun-20						Sushmitha									SC-7328 - Campus App permission Setting
	   29-Jul-20                        Gayithri N                                  Modified for ticket SC-7208 - Assessment Manager -> Network tab
	   24-Aug-20                        Gayithri N                                  Changed Setting.name from Network Access Name to SingularFormNetworkLabel for task SC-7208
       27-Aug-20                        Gayithri N                                  Added query to read role id for network role for SC-7208
	   21-Sep-20                        Shivakumar MG	                            Modified for SC-6766 Send to eduCLIMBER tab and button in Manage Assessments task @since v8.1.0
	   23-Nov-20						Sushmitha									Modified for SC-10005 - Display Linked assessments - Linked tab
	   07-Jan-22						Srinatha									Modified to read PLC assessments permissions for SC-17871 task.
       ---------------------------------------------------------------------------------------------------------------------------------------------------------------
*/
DECLARE
    var_USERLEVEL VARCHAR(1);
    var_NetworkID INTEGER DEFAULT - 1;
    var_NetworkTabName VARCHAR(100) DEFAULT 'Network';
    var_bulkActivate INTEGER DEFAULT 0;
    var_RoleID NUMERIC(18, 0);
    var_bulkPublish INTEGER DEFAULT 0;
    var_Parameters TEXT DEFAULT '';
BEGIN
    BEGIN
        CREATE TEMPORARY TABLE t$tabtable
        (sortorder NUMERIC(18, 0),
            name VARCHAR(50),
            premade NUMERIC(1, 0),
            settings TEXT);
        SELECT
            accesslevelcode
            INTO var_USERLEVEL
            FROM dbo.role
            INNER JOIN dbo.userrole
                ON role.roleid = userrole.roleid
            WHERE role.instanceid = par_InstanceID AND userrole.userroleid = par_UserRoleID;

        IF EXISTS (SELECT
            1
            FROM dbo.instanceapp AS ia
            WHERE EXISTS (SELECT
                appid
                FROM dbo.app
                WHERE appid = ia.appid AND name = 'Network')
            LIMIT 1) THEN
            IF (var_USERLEVEL = 'T' OR var_USERLEVEL = 'C') THEN
                var_NetworkID := (SELECT
                    networkid
                    FROM dbo.networkcampus
                    WHERE campusid = par_CampusID
                    LIMIT 1);
            /* Gayithri added for SC-7208 */
            ELSE
                IF (var_USERLEVEL = 'N') THEN
                    var_NetworkID := (SELECT
                        networkid
                        FROM dbo.userrolenetwork
                        WHERE userroleid = par_UserRoleID
                        LIMIT 1);
                END IF;
            END IF;
        END IF;

        IF (var_NetworkID <> - 1) THEN
            SELECT
                value
                INTO var_NetworkTabName
                FROM dbo.instancesetting
                JOIN dbo.setting
                    ON instancesetting.settingid = setting.settingid
                WHERE instanceid = par_InstanceID AND setting.shortname = 'SFNtLbl';
        END IF;
        INSERT INTO t$tabtable
        VALUES (1, 'Recent', 0, NULL);

        IF (var_USERLEVEL = 'T') THEN
            INSERT INTO t$tabtable
            VALUES (2, 'My Assessments', 0, NULL);
            INSERT INTO t$tabtable
            VALUES (3, 'School', 0, NULL);

            IF (var_NetworkID <> - 1) THEN
                INSERT INTO t$tabtable
                VALUES (4, var_NetworkTabName, 0, NULL);
            END IF;
        END IF;

        IF (var_USERLEVEL = 'C') THEN
            INSERT INTO t$tabtable
            VALUES (5, 'School', 0, NULL);

            IF (var_NetworkID <> - 1) THEN
                INSERT INTO t$tabtable
                VALUES (6, var_NetworkTabName, 0, NULL);
            END IF;
        END IF;

        IF (var_USERLEVEL = 'N') THEN
            INSERT INTO t$tabtable
            VALUES (7, var_NetworkTabName, 0, NULL);
        END IF;
        INSERT INTO t$tabtable
        VALUES (8, 'District', 0, NULL);
        /* ** Nithin: 05/28/2019 - Added to support PLC Groups - SC-127. @since v7.0.0 */

        IF EXISTS (SELECT
            1
            FROM dbo.appfncheckcampusapp(par_InstanceID::INTEGER, 'PLCs', '-1', par_CampusID)
            LIMIT 1) AND EXISTS (SELECT
            1
            FROM dbo.rolepermission AS rp
            JOIN dbo.permission AS p
                ON rp.permissionid = p.permissionid
            JOIN dbo.objecttype AS ot
                ON p.objecttypeid = ot.objecttypeid
            WHERE rp.roleid = (SELECT
                roleid
                FROM dbo.userrole
                WHERE userroleid = par_UserRoleID) AND ot.name IN ('PermPLCAssessmentItemBank', 'PermPLCAssessmentOtherTypes') AND p.operationid IN (SELECT
                operationid
                FROM dbo.operation
                WHERE name IN ('View')) AND COALESCE(rp.scopecode, 'A') = 'A'
            LIMIT 1) AND EXISTS (SELECT DISTINCT
            p.plcid, p.name AS wsname
            FROM dbo.plc AS p
            JOIN dbo.plcuser AS pu
                ON p.plcid = pu.plcid
            WHERE p.activecode = 'A' AND pu.useraccountid = par_UserAccountID) THEN
            INSERT INTO t$tabtable
            VALUES ((SELECT
                MAX(sortorder) + 1
                FROM t$tabtable), 'PLC', 0, NULL);
        END IF;
        /* INSERT INTO #TABTABLE VALUES('State', 6) */
        /* INSERT INTO #TABTABLE VALUES('Shared', 7) */
        /* Shruthi: fix for ZDT 21986, Removed the Row_number order for the Sortorder column. */
        /* if(@CampusID <> -1 and exists(select top 1 1 from App A JOIN CampusApp CA ON CA.AppID = A.AppID AND CA.CampusID = @CampusID where CA.IsActive  = 1)) -- Madhushree K : Modified for Bug [SC-5702] */
        /* begin */
        INSERT INTO t$tabtable
        SELECT
            sat.sortorder + 10, regexp_replace(sat.name, '&', '', 'gi') AS name, 1, sat.settings
            FROM dbo.specialassessmenttab AS sat
            INNER JOIN dbo.instanceapp AS ia
                ON sat.appid = ia.appid AND ia.instanceid = par_InstanceID AND ia.isactive = 1 AND sat.name != 'Curriculum & Instruction'
        UNION
        SELECT
            sat.sortorder + 10, regexp_replace(sat.name, '&', '', 'gi') AS name, 1, sat.settings
            FROM dbo.specialassessmenttab AS sat
            INNER JOIN dbo.campusapp AS ca
                ON sat.appid = ca.appid AND ca.campusid = par_CampusID AND ca.isactive = 1 AND sat.name != 'Curriculum & Instruction';
        /* end */

        IF (var_USERLEVEL IN ('D', 'A')) THEN
            INSERT INTO t$tabtable
            VALUES ((SELECT
                MAX(sortorder) + 1
                FROM t$tabtable), 'Imported', 0, NULL);
        END IF;
        var_RoleID := (SELECT DISTINCT
            roleid
            FROM dbo.userrole
            WHERE userroleid = par_UserRoleID);
        var_bulkActivate := (SELECT
            1
            FROM dbo.permission
            INNER JOIN dbo.objecttype
                ON permission.objecttypeid = objecttype.objecttypeid
            INNER JOIN dbo.operation
                ON permission.operationid = operation.operationid
            INNER JOIN dbo.rolepermission
                ON permission.permissionid = rolepermission.permissionid
            WHERE operation.name = 'Bulk Activate Online Testing' AND rolepermission.roleid = var_RoleID AND objecttype.name IN ('Assessment', 'CItemBank', 'COtherTypes', 'NItemBank', 'NOtherTypes', 'DItemBank', 'DOtherTypes') AND rolepermission.scopecode IN ('A', 'M')
            LIMIT 1);

        IF (COALESCE(var_bulkActivate, 0) != 1) THEN
            var_bulkActivate := (SELECT
                1
                FROM dbo.permission
                INNER JOIN dbo.objecttype
                    ON permission.objecttypeid = objecttype.objecttypeid
                INNER JOIN dbo.operation
                    ON permission.operationid = operation.operationid
                INNER JOIN dbo.rolepermission
                    ON permission.permissionid = rolepermission.permissionid
                WHERE operation.name = 'Bulk Activate Online Testing' AND rolepermission.roleid = var_RoleID AND objecttype.name IN ('Inspect', 'Synced', 'RapidResponse', 'EngageNY', 'Measured Progress', 'PermPLCassessmentItemBank', 'PermPLCassessmentOtherTypes')
                LIMIT 1)
            /* Srinatha: Included PLC assessments object names for SC-17871 task */
            ;
        END IF;
        /* Sushmitha : SC-9205 - Added Linked Tab */
        INSERT INTO t$tabtable
        VALUES ((SELECT
            MAX(sortorder) + 1
            FROM t$tabtable), 'Linked', 0, NULL);
        /* Shivakumar MG : Added for SC-6766 Send to eduCLIMBER tab and button in Manage Assessments task @since v8.1.0 */

        IF (EXISTS (SELECT
            1
            FROM dbo.permission
            INNER JOIN dbo.objecttype
                ON permission.objecttypeid = objecttype.objecttypeid
            INNER JOIN dbo.operation
                ON permission.operationid = operation.operationid
            INNER JOIN dbo.rolepermission
                ON permission.permissionid = rolepermission.permissionid
            INNER JOIN dbo.app
                ON permission.appid = app.appid
            INNER JOIN dbo.instanceapp
                ON instanceapp.appid = app.appid
            WHERE instanceapp.instanceid = par_InstanceID AND rolepermission.roleid = var_RoleID AND app.name = 'eduCLIMBER' AND instanceapp.isactive = 1 AND objecttype.name = 'eduCLIMBER' AND operation.name = 'Send Data'
            LIMIT 1)) THEN
            INSERT INTO t$tabtable
            VALUES ((SELECT
                MAX(sortorder) + 1
                FROM t$tabtable), 'eduCLIMBER', 0, NULL);
        END IF;

        IF ((var_USERLEVEL = 'T') OR (COALESCE(var_bulkActivate, 0) = 1)) THEN
            INSERT INTO t$tabtable
            VALUES ((SELECT
                MAX(sortorder) + 1
                FROM t$tabtable), 'Bulk Activations', 0, NULL);
        END IF;
        /* -Bulk Publish Assessments */
        var_bulkPublish := (SELECT
            1
            FROM dbo.permission
            INNER JOIN dbo.objecttype
                ON permission.objecttypeid = objecttype.objecttypeid
            INNER JOIN dbo.operation
                ON permission.operationid = operation.operationid
            INNER JOIN dbo.rolepermission
                ON permission.permissionid = rolepermission.permissionid
            WHERE operation.name = 'Bulk Publish Assessments' AND rolepermission.roleid = var_RoleID AND objecttype.name IN ('Assessment', 'CItemBank', 'COtherTypes', 'NItemBank', 'NOtherTypes', 'DItemBank', 'DOtherTypes') AND rolepermission.scopecode IN ('A', 'M')
            LIMIT 1);

        IF (COALESCE(var_bulkPublish, 0) != 1) THEN
            var_bulkPublish := (SELECT
                1
                FROM dbo.permission
                INNER JOIN dbo.objecttype
                    ON permission.objecttypeid = objecttype.objecttypeid
                INNER JOIN dbo.operation
                    ON permission.operationid = operation.operationid
                INNER JOIN dbo.rolepermission
                    ON permission.permissionid = rolepermission.permissionid
                WHERE operation.name = 'Bulk Publish Assessments' AND rolepermission.roleid = var_RoleID AND objecttype.name IN ('Inspect', 'Synced', 'RapidResponse', 'EngageNY', 'Measured Progress')
                LIMIT 1);
        END IF;

        IF COALESCE(var_bulkPublish, 0) = 1 THEN
            INSERT INTO t$tabtable
            VALUES ((SELECT
                MAX(sortorder) + 1
                FROM t$tabtable), 'Bulk Published Assessments', 0, NULL);
        END IF;
        OPEN p_refcur FOR
        SELECT
            *
            FROM t$tabtable;
        /* DROP TABLE #TABTABLE */
        EXCEPTION
            WHEN OTHERS THEN
                var_Parameters := 'exec ' + 'appassessgetassessmenttab' || ' @InstanceID = ' || CAST (par_InstanceID AS VARCHAR(50)) || ', @UserAccountID = ' || CAST (par_UserAccountID AS VARCHAR(50)) || ', @UserRoleID = ' || CAST (par_UserRoleID AS VARCHAR(50)) || ', @CampusID = ' || CAST (par_CampusID AS VARCHAR(50));
                /* Exception Handling, If we are getting any error, then required information will be stored into below Error Table */
                INSERT INTO dbo.errortable (dbname, query, errormessage, procedurename, createddate)
                VALUES (current_database(), var_Parameters, error_catch$ERROR_MESSAGE, 'appassessgetassessmenttab', clock_timestamp());
    END;
    /*
    
    DROP TABLE IF EXISTS t$tabtable;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;


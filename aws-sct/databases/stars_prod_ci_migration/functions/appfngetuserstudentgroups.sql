-- ------------ Write DROP-FUNCTION-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.appfngetuserstudentgroups(OUT INTEGER, IN INTEGER, OUT NUMERIC, IN INTEGER, IN INTEGER, IN INTEGER, IN VARCHAR);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-FUNCTION-stage scripts -----------

CREATE OR REPLACE FUNCTION dbo.appfngetuserstudentgroups(IN par_instanceid INTEGER, IN par_useraccountid INTEGER, IN par_campusid INTEGER, IN par_networkid INTEGER, IN par_years VARCHAR)
RETURNS TABLE (studentgroupid INTEGER, publicrestricttosis NUMERIC)
AS
$BODY$
# variable_conflict use_column
DECLARE
    var_Scope CHAR(1);
    var_UserAccess CHAR(1);
BEGIN
    DROP TABLE IF EXISTS appfngetuserstudentgroups$tmptbl;
    CREATE TEMPORARY TABLE appfngetuserstudentgroups$tmptbl
    (studentgroupid INTEGER,
        publicrestricttosis NUMERIC(1, 0));
    /*
    Revision History:
     -----------------------------------------------------------------------------------------------
     DATE    CREATED BY   DESCRIPTION/REMARKS
     -----------------------------------------------------------------------------------------------
     26-Feb-21   Manohar 		Created - SC-12426. This is to use in all the places whereever we need to pull user studentgroups.
    							Included Network created studentgroups login also.
     13-Mar-2023 Sanket			Modified for SC-16639 - Student Group - District default Sharing visibility Apply
     -----------------------------------------------------------------------------------------------
    */
    /* Sanket : Modified for SC-16639 - Student Group - District default Sharing visibility Apply */
    var_UserAccess := (SELECT
        accesslevelcode
        FROM dbo.userrole AS ur
        JOIN dbo.role AS r
            ON ur.roleid = r.roleid
        WHERE useraccountid = par_UserAccountID AND isprimary = 1
        LIMIT 1);
    SELECT
        value
        INTO var_Scope
        FROM dbo.instancesetting AS ins
        JOIN dbo.setting AS s
            ON ins.settingid = s.settingid
        WHERE ins.instanceid = par_InstanceID AND s.shortname = 'ShrScp' AND ins.sortorder = 6;
    /* Sanket : Modified for SC-16639 - Student Group - District default Sharing visibility Apply */
    INSERT INTO appfngetuserstudentgroups$tmptbl
    SELECT DISTINCT
        studentgroup.studentgroupid, publicrestricttosis
        FROM dbo.studentgroup
        WHERE instanceid = par_InstanceID AND (studentgroup.createdby = par_UserAccountID OR (var_Scope = 'D' AND var_UserAccess = 'D' AND studentgroup.privacycode = 3) OR ((studentgroup.privacycode = 3 AND studentgroup.levelownerid IS NULL) OR (studentgroup.privacycode = 3 AND studentgroup.levelownerid = par_CampusID) OR (studentgroup.privacycode = 3 AND studentgroup.levelownerid = par_NetworkID))) AND studentgroup.activecode = 'A' AND (studentgroup.schoolyearid = par_Years::INTEGER OR '-1' = par_Years)
    UNION
    SELECT DISTINCT
        studentgroup.studentgroupid, publicrestricttosis
        FROM dbo.studentgroup
        JOIN dbo.studentgroupconsumer
            ON studentgroup.studentgroupid = studentgroupconsumer.studentgroupid
        WHERE instanceid = par_InstanceID AND (studentgroup.privacycode = 2 AND studentgroupconsumer.useraccountid = par_UserAccountID) AND studentgroup.activecode = 'A' AND (studentgroup.schoolyearid = par_Years::INTEGER OR '-1' = par_Years);
    RETURN QUERY
    SELECT
        *
        FROM appfngetuserstudentgroups$tmptbl;
    DROP TABLE IF EXISTS appfngetuserstudentgroups$tmptbl;
    RETURN;
END;
$BODY$
LANGUAGE  plpgsql;


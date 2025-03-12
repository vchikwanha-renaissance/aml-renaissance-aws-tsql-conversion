-- ------------ Write DROP-FUNCTION-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.appfncheckcampusapp(OUT INTEGER, IN INTEGER, OUT VARCHAR, IN VARCHAR, OUT NUMERIC, IN VARCHAR, IN INTEGER);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-FUNCTION-stage scripts -----------

CREATE OR REPLACE FUNCTION dbo.appfncheckcampusapp(IN par_instanceid INTEGER, IN par_appname VARCHAR, IN par_isfrommodule VARCHAR, IN par_usercampusid INTEGER)
RETURNS TABLE (appid INTEGER, name VARCHAR, isactive NUMERIC)
AS
$BODY$
/* select [dbo].[ZappfnCheckCampusApp_SR](2700001, 'Assessment',1140032) */

/*
Revision History:
-------------------------------------------------------------------------------------------------------------------
DATE    			CREATED BY   	DESCRIPTION/REMARKS
-------------------------------------------------------------------------------------------------------------------
16-Jun-2020		Sushmitha		SC-7328 - Campus App permission Setting
12-Jan-2021		Srinatha R A	Commented Return statement to read Campus Apps when App is disabled in Instance to fix SC-18008 issue.
--------------------------------------------------------------------------------------------------------------------
*/
# variable_conflict use_column
DECLARE
    var_ParentID INTEGER DEFAULT - 1;
BEGIN
    DROP TABLE IF EXISTS appfncheckcampusapp$tmptbl;
    CREATE TEMPORARY TABLE appfncheckcampusapp$tmptbl
    (appid INTEGER,
        name VARCHAR(200),
        isactive NUMERIC(1, 0));

    IF par_IsFromModule <> '-1' THEN
        SELECT
            appid
            INTO var_ParentID
            FROM dbo.app
            WHERE name = par_IsFromModule;
    END IF;

    IF var_ParentID <> - 1 THEN
        /* for module based Apps like Assessment\Item Bank */
        /* check if app is on in instance level else check campus level */
        IF par_AppName <> '' THEN
            INSERT INTO appfncheckcampusapp$tmptbl
            SELECT
                a.appid, par_AppName, isactive
                FROM dbo.app AS a
                JOIN dbo.instanceapp AS ia
                    ON a.appid = ia.appid
                WHERE a.name = par_AppName AND ia.instanceid = par_InstanceID AND isactive = 1 AND parentid = var_ParentID;
            /* return */
        END IF;

        IF NOT EXISTS (SELECT
            1
            FROM appfncheckcampusapp$tmptbl
            LIMIT 1) AND (par_UserCampusID <> '' OR par_UserCampusID <> - 1) THEN
            INSERT INTO appfncheckcampusapp$tmptbl
            SELECT
                a.appid, par_AppName, isactive
                FROM dbo.app AS a
                JOIN dbo.campusapp AS ca
                    ON a.appid = ca.appid
                WHERE a.name = par_AppName AND ca.campusid = par_UserCampusID AND isactive = 1 AND parentid = var_ParentID;
            /* return */
        END IF;
    ELSE
        /* for all other apps */
        IF par_AppName <> '' THEN
            INSERT INTO appfncheckcampusapp$tmptbl
            SELECT
                a.appid, par_AppName, isactive
                FROM dbo.app AS a
                JOIN dbo.instanceapp AS ia
                    ON a.appid = ia.appid
                WHERE a.name = par_AppName AND ia.instanceid = par_InstanceID AND isactive = 1;
            /* return */
        END IF;

        IF NOT EXISTS (SELECT
            1
            FROM appfncheckcampusapp$tmptbl
            LIMIT 1) AND (par_UserCampusID <> '' OR par_UserCampusID <> - 1) THEN
            INSERT INTO appfncheckcampusapp$tmptbl
            SELECT
                a.appid, par_AppName, isactive
                FROM dbo.app AS a
                JOIN dbo.campusapp AS ca
                    ON a.appid = ca.appid
                WHERE a.name = par_AppName AND ca.campusid = par_UserCampusID AND isactive = 1;
            /* return */
        END IF;
    END IF;
    RETURN QUERY
    SELECT
        *
        FROM appfncheckcampusapp$tmptbl;
    DROP TABLE IF EXISTS appfncheckcampusapp$tmptbl;
    RETURN;
END;
$BODY$
LANGUAGE  plpgsql;


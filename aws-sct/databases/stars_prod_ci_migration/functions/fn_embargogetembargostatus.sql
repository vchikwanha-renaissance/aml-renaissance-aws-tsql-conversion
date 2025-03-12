-- ------------ Write DROP-FUNCTION-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.fn_embargogetembargostatus(IN INTEGER, IN INTEGER, IN INTEGER);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-FUNCTION-stage scripts -----------

CREATE OR REPLACE FUNCTION dbo.fn_embargogetembargostatus(IN par_aid INTEGER, IN par_userroleid INTEGER, IN par_useraccountid INTEGER)
RETURNS NUMERIC
AS
$BODY$
DECLARE
    var_ObjectTypeID INTEGER;
    var_isEmbargoed NUMERIC(1, 0) DEFAULT 0;
    var_isEmbargoRole INTEGER;
    var_isEmbargoUser INTEGER;
    var_OID INTEGER;
    var_InstanceID INTEGER;
    var_RoleID INTEGER;
    var_StartDate DATE;
    var_EndDate DATE;
    var_isAssessmentEmbargoed NUMERIC(1, 0);
BEGIN
    /*
    Revision History:
    -----------------------------------------------------------------------------------------------
    DATE				CREATED by						DESCRIPTION/REMARKS
    -----------------------------------------------------------------------------------------------
    24-Jul-15			Shruthi Shetty	Originated	    Created to get the Embargoed status for selected user, selected assessment.
    -----------------------------------------------------------------------------------------------
    */
    SELECT
        aws_sqlserver_ext.tomsbit(isembargoed)
        INTO var_isAssessmentEmbargoed
        FROM dbo.assessment
        WHERE assessmentid = par_AID;

    IF (var_isAssessmentEmbargoed = 1) THEN
        SELECT
            useraccount.instanceid, role.roleid
            INTO var_InstanceID, var_RoleID
            FROM dbo.userrole
            JOIN dbo.useraccount
                ON userrole.useraccountid = useraccount.useraccountid
            JOIN dbo.role
                ON role.roleid = userrole.roleid
            WHERE userroleid = par_UserRoleID AND useraccount.useraccountid = par_UserAccountID;
        SELECT
            COALESCE(assessment.embargostartdate, ''), COALESCE(assessment.embargoenddate, '')
            INTO var_StartDate, var_EndDate
            FROM dbo.assessment
            WHERE assessmentid = par_AID AND instanceid = var_InstanceID;

        IF ('' = var_EndDate OR (aws_sqlserver_ext.conv_string_to_date(clock_timestamp(), 101) BETWEEN CAST (var_StartDate AS DATE) AND CAST (var_EndDate AS DATE))) THEN
            SELECT
                objecttypeid
                INTO var_ObjectTypeID
                FROM dbo.objecttype
                WHERE name = 'Assessment';
            SELECT
                COUNT(*)
                INTO var_isEmbargoRole
                FROM dbo.embargorole
                WHERE objectid = par_AID AND objecttypeid = var_ObjectTypeID;
            /* and RoleID = @RoleID */
            SELECT
                COUNT(*)
                INTO var_isEmbargoUser
                FROM dbo.embargouser
                WHERE objectid = par_AID AND objecttypeid = var_ObjectTypeID;
            /* and UserAccountID = @UserAccountID and IsRemove = 0 */

            IF (var_isEmbargoRole = 0 AND var_isEmbargoUser = 0) THEN
                SELECT
                    COALESCE(collectionid, - 1)
                    INTO var_OID
                    FROM dbo.assessment
                    WHERE assessmentid = par_AID AND instanceid = var_InstanceID;
                SELECT
                    objecttypeid
                    INTO var_ObjectTypeID
                    FROM dbo.objecttype
                    WHERE name = 'Collection';
            ELSE
                var_OID := par_AID;
            END IF;

            IF (- 1 != var_OID) THEN
                IF (EXISTS (SELECT
                    1
                    FROM dbo.embargorole
                    WHERE objectid = var_OID AND objecttypeid = var_ObjectTypeID AND roleid = var_RoleID
                    LIMIT 1)) THEN
                    IF (EXISTS (SELECT
                        1
                        FROM dbo.embargouser
                        WHERE objectid = var_OID AND objecttypeid = var_ObjectTypeID AND useraccountid = par_UserAccountID AND isremove = 0
                        LIMIT 1)) THEN
                        var_isEmbargoed := 0;
                    ELSE
                        var_isEmbargoed := 1;
                    END IF;
                ELSE
                    IF (EXISTS (SELECT
                        1
                        FROM dbo.embargouser
                        WHERE objectid = var_OID AND objecttypeid = var_ObjectTypeID AND useraccountid = par_UserAccountID AND isremove = 0
                        LIMIT 1)) THEN
                        IF (EXISTS (SELECT
                            1
                            FROM dbo.embargorole
                            WHERE objectid = var_OID AND objecttypeid = var_ObjectTypeID AND roleid IN (SELECT
                                roleid
                                FROM dbo.userrole
                                WHERE userrole.useraccountid = par_UserAccountID AND roleid != var_RoleID)
                            LIMIT 1)) THEN
                            var_isEmbargoed := 1;
                        ELSE
                            var_isEmbargoed := 0;
                        END IF;
                    ELSE
                        var_isEmbargoed := 1;
                    END IF;
                END IF;
            ELSE
                var_isEmbargoed := 1;
            END IF;
        ELSE
            var_isEmbargoed := 0;
        END IF;
    END IF;
    RETURN var_isEmbargoed;
END;
$BODY$
LANGUAGE  plpgsql;


-- ------------ Write DROP-FUNCTION-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.getdatetimebytimezone(IN TIMESTAMP WITHOUT TIME ZONE, IN INTEGER);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-FUNCTION-stage scripts -----------

CREATE OR REPLACE FUNCTION dbo.getdatetimebytimezone(IN par_pstdatetime TIMESTAMP WITHOUT TIME ZONE, IN par_requiredtz INTEGER)
RETURNS TIMESTAMP WITHOUT TIME ZONE
AS
$BODY$
DECLARE
    var_DateandTime TIMESTAMP WITHOUT TIME ZONE;
    var_2ndSunMar DATE;
    var_1stSunNov DATE;
BEGIN
    /*
    Revision History:
    --------------------------------------------------------------------
    DATE         CREATED/VERIFEED BY         DESCRIPTION/REMARKS
    --------------------------------------------------------------------
    30-Jun-15   Venugopal/Suresh V          Get Different Time Zones
    --------------------------------------------------------------------
    */
    IF par_RequiredTZ = 1 THEN
        /* Eastern Time Zone */
        par_PSTDateTime := par_PSTDateTime + (+ 3::NUMERIC || ' HOUR')::INTERVAL;
    ELSE
        IF par_RequiredTZ = 2 THEN
            /* Central Time Zone */
            par_PSTDateTime := par_PSTDateTime + (+ 2::NUMERIC || ' HOUR')::INTERVAL;
        ELSE
            IF par_RequiredTZ = 3 THEN
                /* Mountain Standard Time */
                par_PSTDateTime := par_PSTDateTime + (+ 1::NUMERIC || ' HOUR')::INTERVAL;
            ELSE
                IF par_RequiredTZ = 4 THEN
                    /* Mountain Standard Time (No DST) */
                    var_2ndSunMar := (SELECT
                        (0 + ((date_part('year', clock_timestamp()) - 1900) * 12 + 2::NUMERIC || ' MONTH')::INTERVAL)::TIMESTAMP + (7 + (6 - (aws_sqlserver_ext.datediff('day', 0::TIMESTAMP, 0 + ((date_part('year', clock_timestamp()) - 1900) * 12 + 2::NUMERIC || ' MONTH')::INTERVAL::TIMESTAMP) % 7))::NUMERIC || ' DAY')::INTERVAL AS "2ndSunMar");
                    var_1stSunNov := (SELECT
                        (0 + ((date_part('year', clock_timestamp()) - 1900) * 12 + 10::NUMERIC || ' MONTH')::INTERVAL)::TIMESTAMP + ((6 - (aws_sqlserver_ext.datediff('day', 0::TIMESTAMP, 0 + ((date_part('year', clock_timestamp()) - 1900) * 12 + 10::NUMERIC || ' MONTH')::INTERVAL::TIMESTAMP) % 7))::NUMERIC || ' DAY')::INTERVAL AS "1stSunNov");

                    IF par_PSTDateTime NOT BETWEEN var_2ndSunMar AND var_1stSunNov THEN
                        par_PSTDateTime := par_PSTDateTime + (+ 1::NUMERIC || ' HOUR')::INTERVAL;
                    END IF;
                ELSE
                    par_PSTDateTime := par_PSTDateTime;
                END IF;
            END IF;
        END IF;
    END IF;
    RETURN par_PSTDateTime;
END;
$BODY$
LANGUAGE  plpgsql;


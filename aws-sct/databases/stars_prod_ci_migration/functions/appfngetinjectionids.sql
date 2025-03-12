-- ------------ Write DROP-FUNCTION-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.appfngetinjectionids(IN TEXT, IN INTEGER);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-FUNCTION-stage scripts -----------

CREATE OR REPLACE FUNCTION dbo.appfngetinjectionids(IN par_data TEXT, IN par_type INTEGER)
RETURNS INTEGER
AS
$BODY$
DECLARE
    var_status INTEGER;
    var_Sort_len_Total INTEGER;
    var_Sort_Len_special_Start INTEGER;
    var_Sort_Len_special_end INTEGER;
    var_Sort_Len_space INTEGER;
BEGIN
    /*
    Revision History:
    -----------------------------------------------------------------------------------------------------------
    DATE				MODIFIED BY			DESCRIPTION/REMARKS
    -----------------------------------------------------------------------------------------------------------
    03-May-2023			Srinatha			Modified to fix SC-25029 KH - Putnam County - missing report customer ticket
    08-Dec-2023         Rakshith            Modified for SC-28070 JDBC exception in the log for appOnlineGetStudentsForAdmin
    -----------------------------------------------------------------------------------------------------------
    */
    IF par_Type = 1 THEN
        /* Tocheck 1st level main parameters */
        IF ((CAST (par_Data AS TEXT) SIMILAR TO '%DECLARE %') OR (CAST (par_Data AS TEXT) LIKE '%--%') OR (CAST (par_Data AS TEXT) SIMILAR TO '%EXEC %') OR (CAST (par_Data AS TEXT) SIMILAR TO E'%EXEC\\[%') OR
        /* Shruthi added for SC-22701 ticket. */
        (CAST (par_Data AS TEXT) LIKE '%VARCHAR%') OR (CAST (par_Data AS TEXT) SIMILAR TO '%[%]%') OR (CAST (par_Data AS TEXT) LIKE '%=%')) THEN
            var_status := - 1;
        END IF;
    ELSE
        IF par_Type = 2 THEN
            /* Tocheck 2nd level comma seperated ID values */
            IF par_Data SIMILAR TO '%[a-z]%' THEN
                var_status := - 1;
            ELSE
                IF aws_sqlserver_ext.patindex(E'%[~!@#$%^&*()_+=-\\|}{;:''"/?.></]%', par_Data) > 0 THEN
                    var_status := - 1;
                /* Rakshith added beow  '-' and added  @Data <>'-1' to avoid '-' in comma separated ids for SC-24457 */
                /* and changes @Data <>'-1'  to @Data not like '-1' for SC-28070 */
                ELSE
                    IF par_Data LIKE '%-%' AND par_Data NOT LIKE '%-1%' THEN
                        var_status := - 1;
                    END IF;
                END IF;
            END IF;
        ELSE
            IF par_Type = 3 THEN
                /* Tocheck 3rd level Sortcolumn issues */
                SELECT
                    LENGTH(par_Data), STRPOS(par_Data, '['), STRPOS(par_Data, ']'), (LENGTH(par_Data) - LENGTH(regexp_replace(par_Data, ' ', '', 'gi')))
                    INTO var_Sort_len_Total, var_Sort_Len_special_Start, var_Sort_Len_special_end, var_Sort_Len_space;

                IF var_Sort_Len_special_Start = 1 THEN
                    SELECT
                        (LENGTH(OVERLAY(par_Data PLACING '' FROM var_Sort_Len_special_Start FOR var_Sort_Len_special_end)) - LENGTH(regexp_replace(OVERLAY(par_Data PLACING '' FROM var_Sort_Len_special_Start FOR var_Sort_Len_special_end), ' ', '', 'gi')))
                        INTO var_Sort_Len_space;
                END IF;

                IF (par_Data LIKE '%--%' OR par_Data LIKE '%''%') THEN
                    var_status := - 1;
                ELSE
                    IF par_Data SIMILAR TO '% ASC' AND var_Sort_Len_special_Start != 1 AND var_Sort_Len_space = 1 THEN
                        IF RIGHT(par_Data, 4) = ' ASC' THEN
                            var_status := 1;
                        ELSE
                            var_status := - 1;
                        END IF;
                    ELSE
                        IF par_Data SIMILAR TO '% DESC' AND var_Sort_Len_special_Start != 1 AND var_Sort_Len_space = 1 THEN
                            IF RIGHT(par_Data, 5) = ' DESC' THEN
                                var_status := 1;
                            ELSE
                                var_status := - 1;
                            END IF;
                        ELSE
                            IF var_Sort_Len_special_Start = 1 THEN
                                IF par_Data SIMILAR TO '% ASC' THEN
                                    IF RIGHT(par_Data, 4) = ' ASC' AND var_Sort_Len_space = 1 THEN
                                        var_status := 1;
                                    ELSE
                                        var_status := - 1;
                                    END IF;
                                ELSE
                                    IF par_Data SIMILAR TO '% DESC' THEN
                                        IF RIGHT(par_Data, 5) = ' DESC' AND var_Sort_Len_space = 1 THEN
                                            var_status := 1;
                                        ELSE
                                            var_status := - 1;
                                        END IF;
                                    ELSE
                                        IF var_Sort_Len_space = 0 THEN
                                            var_status := 1;
                                        ELSE
                                            var_status := - 1;
                                        END IF;
                                    END IF;
                                END IF;
                            ELSE
                                IF var_Sort_Len_space = 0 OR
                                /* Srinatha : Added below "OR" condition to handle morethan 1 sort column without [](brockets) symbols in it to fix SC-25029 customer ticket */
                                (var_Sort_Len_special_Start = 0 AND var_Sort_Len_space > 1) THEN
                                    var_status := 1;
                                ELSE
                                    var_status := - 1;
                                END IF;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            ELSE
                var_status := 1;
            END IF;
        END IF;
    END IF;
    RETURN var_status;
END;
$BODY$
LANGUAGE  plpgsql;


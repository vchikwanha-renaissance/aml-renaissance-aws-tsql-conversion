-- ------------ Write DROP-FUNCTION-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.fn_split(OUT VARCHAR, IN VARCHAR, IN VARCHAR);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-FUNCTION-stage scripts -----------

CREATE OR REPLACE FUNCTION dbo.fn_split(IN par_sinputlist VARCHAR, IN par_sdelimiter VARCHAR DEFAULT ',')
RETURNS TABLE (item VARCHAR)
AS
$BODY$
/* List of delimited items */
/* delimiter that separates items */
# variable_conflict use_column
DECLARE
    var_sItem VARCHAR(8000);
BEGIN
    DROP TABLE IF EXISTS fn_split$tmptbl;
    CREATE TEMPORARY TABLE fn_split$tmptbl
    (item VARCHAR(8000));

    WHILE aws_sqlserver_ext.STRPOS3(par_sDelimiter, par_sInputList, 0) <> 0 LOOP
        SELECT
            RTRIM(LTRIM(SUBSTR(par_sInputList, 1, aws_sqlserver_ext.STRPOS3(par_sDelimiter, par_sInputList, 0) - 1))), RTRIM(LTRIM(SUBSTR(par_sInputList, aws_sqlserver_ext.STRPOS3(par_sDelimiter, par_sInputList, 0) + LENGTH(par_sDelimiter), LENGTH(par_sInputList))))
            INTO var_sItem, par_sInputList;

        IF LENGTH(var_sItem) > 0 THEN
            INSERT INTO fn_split$tmptbl
            SELECT
                var_sItem;
        END IF;
    END LOOP;

    IF LENGTH(par_sInputList) > 0 THEN
        INSERT INTO fn_split$tmptbl
        SELECT
            par_sInputList;
    END IF;
    /* Put the last item in */
    RETURN QUERY
    SELECT
        *
        FROM fn_split$tmptbl;
    DROP TABLE IF EXISTS fn_split$tmptbl;
    RETURN;
END;
/* select [dbo].[Fn_Split]('a,b') as retrn */
$BODY$
LANGUAGE  plpgsql;


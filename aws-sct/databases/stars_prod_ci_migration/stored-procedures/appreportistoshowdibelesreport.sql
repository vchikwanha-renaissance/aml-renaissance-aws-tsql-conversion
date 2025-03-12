-- ------------ Write DROP-PROCEDURE-stage scripts -----------

DROP ROUTINE IF EXISTS dbo.appreportistoshowdibelesreport(IN INTEGER, IN TEXT, INOUT refcursor, INOUT refcursor);

-- ------------ Write CREATE-DATABASE-stage scripts -----------

CREATE SCHEMA IF NOT EXISTS dbo;

-- ------------ Write CREATE-PROCEDURE-stage scripts -----------

CREATE OR REPLACE PROCEDURE dbo.appreportistoshowdibelesreport(IN par_instanceid INTEGER, IN par_tabname TEXT, INOUT p_refcur refcursor, INOUT p_refcur_2 refcursor)
AS 
$BODY$
/* EXEC [dbo].[ZappReportIsToShowDibelesReport24_March2016] '1300001', 'FANDP' */
DECLARE
    var_Parameters TEXT DEFAULT '';
BEGIN
    BEGIN
        /*
        Procedure Name        :                appReportIsToShowDibelesReport
            Author                :
            Date Of Creation      :
            Purpose               :                To check if Dibels/F&P Assessments exists or not.
        
        	Revision History:
        	--------------------------------------------------------------------------------------------------------------
        	DATE			VERSION			CREATED BY			DESCRIPTION/REMARKS
        	--------------------------------------------------------------------------------------------------------------
        	09-Jan-2017						Nithin				Improved performance of the queries
        	29-Mar-2020						Manohar				Modified to improve the performance - Commented the roster queries
        	--------------------------------------------------------------------------------------------------------------
        */
        /* Manohar: Modified to improve the performance - Commented the roster queries */
        /* create table #Students(StudentID int primary key) */
        /* insert into #Students */
        /* select distinct SC.StudentID from Class C with (nolock) */
        /* join StudentClass SC with (nolock) on C.ClassID = SC.ClassID */
        /* join TeacherClass TC with (nolock) on C.ClassID = TC.ClassID */
        /* where C.RosterDatasetID = (Select RosterDatasetID from RosterDataset */
        /* where InstanceID = @InstanceID and IsDefault = 1) */
        /* and SC.IsCurrent = 1 and TC.IsCurrent = 1 */
        IF par_TabName = 'DIBELS' THEN
            CREATE TEMPORARY TABLE t$dibels
            (objectid INTEGER PRIMARY KEY);
            INSERT INTO t$dibels
            SELECT DISTINCT
                taglink.objectid
                FROM dbo.tag
                JOIN dbo.taglink
                    ON tag.tagid = taglink.tagid AND tag.name IN ('DIBELS BEG', 'DIBELS MID', 'DIBELS EOY')
                JOIN dbo.objecttype
                    ON taglink.objecttypeid = objecttype.objecttypeid AND objecttype.name = 'Assessment' AND taglink.instanceid = par_InstanceID;
            OPEN p_refcur FOR
            SELECT DISTINCT
                1
                FROM dbo.assessment
                JOIN t$dibels AS tl
                    ON assessment.assessmentid = tl.objectid
                JOIN dbo.assessmentform
                    ON assessmentform.assessmentid = assessment.assessmentid
                JOIN dbo.testattempt
                    ON assessmentform.assessmentformid = testattempt.assessmentformid AND assessment.activecode = 'A' AND
                    /* join #Students SCD on TestAttempt.StudentID = SCD.StudentID */
                    testattempt.isvalid = 1
                LIMIT 1;
        ELSE
            IF par_TabName = 'FANDP' THEN
                CREATE TEMPORARY TABLE t$fandp
                (objectid INTEGER PRIMARY KEY);
                INSERT INTO t$fandp
                SELECT DISTINCT
                    taglink.objectid
                    FROM dbo.tag
                    JOIN dbo.taglink
                        ON tag.tagid = taglink.tagid AND tag.name IN ('FountasAndPinnellT1', 'FountasAndPinnellT2', 'FountasAndPinnellT3')
                    JOIN dbo.objecttype
                        ON taglink.objecttypeid = objecttype.objecttypeid AND objecttype.name = 'Assessment' AND taglink.instanceid = par_InstanceID;
                OPEN p_refcur_2 FOR
                SELECT DISTINCT
                    1
                    FROM dbo.assessment
                    JOIN t$fandp AS tl
                        ON assessment.assessmentid = tl.objectid
                    JOIN dbo.assessmentform
                        ON assessmentform.assessmentid = assessment.assessmentid
                    JOIN dbo.testattempt
                        ON assessmentform.assessmentformid = testattempt.assessmentformid AND assessment.activecode = 'A' AND
                        /* join #Students SCD on TestAttempt.StudentID = SCD.StudentID */
                        testattempt.isvalid = 1
                    LIMIT 1;
            END IF;
        END IF;
        EXCEPTION
            WHEN OTHERS THEN
                var_Parameters := 'exec ' + 'appreportistoshowdibelesreport' || ' @InstanceID = ' || CAST (par_InstanceID AS VARCHAR(50)) || ' , @TabName = ''' || par_TabName || ''' ';
                /* Exception Handling, If we are getting any error, then required information will be stored into below Error Table */
                INSERT INTO dbo.errortable (dbname, query, errormessage, procedurename, createddate)
                VALUES (current_database(), var_Parameters, error_catch$ERROR_MESSAGE, 'appreportistoshowdibelesreport', clock_timestamp());
    END;
    /*
    
    DROP TABLE IF EXISTS t$dibels;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
    /*
    
    DROP TABLE IF EXISTS t$fandp;
    */
    /*
    
    Temporary table must be removed before end of the function.
    */
END;
$BODY$
LANGUAGE plpgsql;


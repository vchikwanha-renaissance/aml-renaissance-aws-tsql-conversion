
            

-- ------------ Write DROP-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
IF  EXISTS (
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID (N'[dbo].[appReportIsToShowDibelesReport]') AND 
type = N'P')
DROP PROCEDURE [dbo].[appReportIsToShowDibelesReport];
GO
            


            


            

-- ------------ Write CREATE-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
create   procedure  [appReportIsToShowDibelesReport]  --EXEC [dbo].[ZappReportIsToShowDibelesReport24_March2016] '1300001', 'FANDP' 
@InstanceID INT,
@TabName varchar(max)
as
SET NOCOUNT on
Begin
BEGIN TRY
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
	-- Manohar: Modified to improve the performance - Commented the roster queries
	--create table #Students(StudentID int primary key)
	--insert into #Students
	--select distinct SC.StudentID from Class C with (nolock) 
	--join StudentClass SC with (nolock) on C.ClassID = SC.ClassID
	--join TeacherClass TC with (nolock) on C.ClassID = TC.ClassID
	--where C.RosterDatasetID = (Select RosterDatasetID from RosterDataset 
	--where InstanceID = @InstanceID and IsDefault = 1)
	--and SC.IsCurrent = 1 and TC.IsCurrent = 1

	IF @TabName = 'DIBELS'
	BEGIN
		create table #DIBELS(ObjectID int primary key) 
		insert into #DIBELS
		select distinct TagLink.ObjectID from Tag join TagLink on Tag.TagID = TagLink.TagID and Tag.Name in ('DIBELS BEG', 'DIBELS MID', 'DIBELS EOY')
		join ObjectType on TagLink.ObjectTypeID = ObjectType.ObjectTypeID and ObjectType.Name = 'Assessment'
		and TagLink.InstanceID = @InstanceID

		Select DISTINCT top 1 1 from Assessment 
		join #DIBELS TL on Assessment.AssessmentID = TL.ObjectID
		join AssessmentForm on AssessmentForm.AssessmentID = Assessment.AssessmentID 
		join TestAttempt on AssessmentForm.AssessmentFormID = TestAttempt.AssessmentFormID and Assessment.ActiveCode = 'A'
		--join #Students SCD on TestAttempt.StudentID = SCD.StudentID 
		and TestAttempt.IsValid = 1
	END
	ELSE IF @TabName = 'FANDP'
	BEGIN
		create table #FANDP(ObjectID int primary key) 
		insert into #FANDP
		select distinct TagLink.ObjectID from Tag join TagLink on Tag.TagID = TagLink.TagID and Tag.Name in ('FountasAndPinnellT1', 'FountasAndPinnellT2', 'FountasAndPinnellT3')
		join ObjectType on TagLink.ObjectTypeID = ObjectType.ObjectTypeID and ObjectType.Name = 'Assessment'
		and TagLink.InstanceID = @InstanceID

		Select DISTINCT top 1 1 from Assessment 
		join #FANDP TL on Assessment.AssessmentID = TL.ObjectID
		join AssessmentForm on AssessmentForm.AssessmentID = Assessment.AssessmentID 
		join TestAttempt on AssessmentForm.AssessmentFormID = TestAttempt.AssessmentFormID and Assessment.ActiveCode = 'A'
		--join #Students SCD on TestAttempt.StudentID = SCD.StudentID 
		and TestAttempt.IsValid = 1
	END
	end try
	begin catch
		declare @Parameters nvarchar(max) = ''
		set @Parameters = 'exec ' + object_name(@@procid) + ' @InstanceID = ' + Convert(varchar(50),@InstanceID) + ' , @TabName = ''' + @TabName + ''' '

		/* Exception Handling, If we are getting any error, then required information will be stored into below Error Table */
		insert into ErrorTable(DBName,Query,ErrorMessage,ProcedureName,CreatedDate)
		Values(db_name(),@Parameters,error_message(),object_name(@@procid),getdate());
	end catch
End
GO
            


            


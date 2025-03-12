
            

-- ------------ Write DROP-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
IF  EXISTS (
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID (N'[dbo].[fn_EmbargoGetEmbargoStatus]') AND 
type = N'FN')
DROP FUNCTION [dbo].[fn_EmbargoGetEmbargoStatus];
GO
            


            


            

-- ------------ Write CREATE-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
CREATE function   [dbo].[fn_EmbargoGetEmbargoStatus]
(
	@AID int,
	@UserRoleID int,
	@UserAccountID int
)
Returns BIT
as
begin

/*
	Revision History:
	-----------------------------------------------------------------------------------------------
	DATE				CREATED by						DESCRIPTION/REMARKS
	-----------------------------------------------------------------------------------------------
	24-Jul-15			Shruthi Shetty	Originated	    Created to get the Embargoed status for selected user, selected assessment.
	-----------------------------------------------------------------------------------------------
*/
	Declare @ObjectTypeID int
	Declare @isEmbargoed bit = 0
	Declare @isEmbargoRole int
	Declare @isEmbargoUser int
	Declare @OID int
	Declare @InstanceID int
	Declare @RoleID int
	Declare @StartDate Date
	Declare @EndDate Date
	Declare @isAssessmentEmbargoed bit

	SELECT @isAssessmentEmbargoed = IsEmbargoed from Assessment where AssessmentID = @AID
	
	IF(@isAssessmentEmbargoed = 1)
		Begin
			SELECT @InstanceID = UserAccount.InstanceID, @RoleID = Role.RoleID 
			FROM UserRole 
			JOIN UserAccount ON UserRole.UserAccountID = UserAccount.UserAccountID 
			Join Role on Role.RoleID = UserRole.RoleID
			WHERE UserRoleID = @UserRoleID And UserAccount.UserAccountID = @UserAccountID

			Select @StartDate = ISNULL(Assessment.EmbargoStartDate, ''), @EndDate = ISNULL(Assessment.EmbargoEndDate, '')  From Assessment where AssessmentID = @AID  and InstanceID = @InstanceID
			
			
		If('' = @EndDate OR (CONVERT(DATE, GETDATE(), 101) Between CONVERT(DATE, @StartDate, 101) AND CONVERT(DATE, @EndDate, 101)))
			Begin
					Select @ObjectTypeID =  ObjectTypeID From ObjectType where Name = 'Assessment'
					
					select @isEmbargoRole = Count(*) from EmbargoRole where ObjectId = @AID and ObjectTypeID = @ObjectTypeID --and RoleID = @RoleID
					select @isEmbargoUser = count(*) from EmbargoUser where ObjectId = @AID and ObjectTypeID = @ObjectTypeID --and UserAccountID = @UserAccountID and IsRemove = 0
					
					If(@isEmbargoRole = 0 AND @isEmbargoUser = 0)
						Begin
							Select @OID = ISNULL(CollectionID, -1) from Assessment where AssessmentID = @AID and InstanceID = @InstanceID
							Select @ObjectTypeID =  ObjectTypeID From ObjectType where Name = 'Collection'
			End
					Else 
						Set @OID = @AID
					If(-1 != @OID)
						Begin
							If(Exists(Select top 1 1 from EmbargoRole where ObjectId = @OID and ObjectTypeID = @ObjectTypeID and RoleID = @RoleID))
								Begin
									If(Exists(Select top 1 1 from EmbargoUser  where ObjectId = @OID and ObjectTypeID = @ObjectTypeID and UserAccountID = @UserAccountID and IsRemove = 0))
										Set @isEmbargoed = 0
									Else 
										Set @isEmbargoed = 1
								End
							Else IF(Exists(Select top 1 1 from EmbargoUser  where ObjectId = @OID and ObjectTypeID = @ObjectTypeID and UserAccountID = @UserAccountID and IsRemove = 0))
								Begin
									If(Exists(Select top 1 1 from EmbargoRole where ObjectId = @OID and ObjectTypeID = @ObjectTypeID and RoleID in (Select RoleID from UserRole Where UserRole.UserAccountID = @UserAccountID And RoleID != @RoleID)))
										Set @isEmbargoed = 1
									Else 
										Set @isEmbargoed = 0
								End
							Else
								Set @isEmbargoed = 1
						End
					Else
						Set @isEmbargoed = 1
				End
			Else Set @isEmbargoed = 0
		End
		Return @isEmbargoed
end
GO
            


            


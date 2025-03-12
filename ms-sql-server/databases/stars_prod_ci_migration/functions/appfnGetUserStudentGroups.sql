
            

-- ------------ Write DROP-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
IF  EXISTS (
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID (N'[dbo].[appfnGetUserStudentGroups]') AND 
type = N'TF')
DROP FUNCTION [dbo].[appfnGetUserStudentGroups];
GO
            


            


            

-- ------------ Write CREATE-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
CREATE function [dbo].[appfnGetUserStudentGroups] (@InstanceID int, @UserAccountID int, @CampusID int, @NetworkID int, @Years varchar(500))
returns @ResultList table (StudentGroupid int, PublicRestrictToSIS bit)
begin
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
	declare @Scope char(1)
	declare @UserAccess char(1)

	-- Sanket : Modified for SC-16639 - Student Group - District default Sharing visibility Apply
	set @UserAccess = (select top 1 AccessLevelCode from UserRole UR
						  join Role R on UR.RoleID = R.RoleID
						  where UserAccountID = @UserAccountID and IsPrimary = 1)
	
	select @Scope = Value from InstanceSetting Ins
	join Setting S on Ins.SettingID = S.SettingID
	where Ins.InstanceID = @InstanceID and S.ShortName = 'ShrScp' and Ins.SortOrder = 6

	-- Sanket : Modified for SC-16639 - Student Group - District default Sharing visibility Apply
	insert into @ResultList
	select distinct studentgroup.studentgroupid, PublicRestrictToSIS from dbo.studentgroup       
	where instanceid = @InstanceID 
	and (studentgroup.createdby = @UserAccountID
	or (@Scope = 'D' AND @UserAccess = 'D' AND studentgroup.privacycode = 3)
	or ((studentgroup.privacycode = 3 and studentgroup.levelownerid is null) 
	or (studentgroup.privacycode = 3 and studentgroup.levelownerid = @CampusID )
	or (studentgroup.privacycode = 3 and studentgroup.levelownerid = @NetworkID )) ) 
	and studentgroup.activecode = 'A' 
	and (studentgroup.schoolyearid = @Years or '-1' = @Years)
	union
	select distinct studentgroup.studentgroupid, PublicRestrictToSIS from dbo.studentgroup 
	join dbo.studentgroupconsumer on studentgroup.studentgroupid = studentgroupconsumer.studentgroupid
	where instanceid = @InstanceID 
	and (studentgroup.privacycode = 2 and studentgroupconsumer.useraccountid = @UserAccountID)
	and studentgroup.activecode = 'A'
	and (studentgroup.schoolyearid = @Years or '-1' = @Years) 

	return
end
GO
            


            


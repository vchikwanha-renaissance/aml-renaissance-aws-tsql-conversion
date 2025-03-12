
            

-- ------------ Write DROP-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
IF  EXISTS (
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID (N'[dbo].[appAssessGetAssessmentTab]') AND 
type = N'P')
DROP PROCEDURE [dbo].[appAssessGetAssessmentTab];
GO
            


            


            

-- ------------ Write CREATE-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
CREATE procedure [dbo].[appAssessGetAssessmentTab]
@InstanceID NUMERIC,
@UserAccountID NUMERIC,
@UserRoleID NUMERIC,
@CampusID INT = -1 -- Madhushree K : Added for Bug [SC-5702].
AS
/*
       Revision History:
       ---------------------------------------------------------------------------------------------------------------------------------------------
       DATE                             CREATED/VERIFIED BY                        DESCRIPTION/REMARKS
       ---------------------------------------------------------------------------------------------------------------------------------------------
       02-Jan-14                        Athar/Rizwan                                Orginated.
	   17-Nov-16						Shruthi/Rahini.J							showing bulk activaion tab v3.2.0
	   13-Dec-16						Rahini.J								    Modified to fix Bug 29050
	   09-Mar-17                        Kapil                                       Added the premade coloumn and changed the selection of the order.
       27-Mar-17						Suresh vagalla								Increased size of NAME in #TABTABLE column.
	   03-Apr-17                        Kapil                                       Added Settings columns
	   23-May-17						Shruthi/ Mahananda							Added REPLACE (SAT.Name , '&' , '' ) for CI tab as per Bug 33252 since V5.0.0
	   28-Jun-17						Suresh Vagalla\Subhashish					Added "Bulk Publish Assessments" Tab based on the permissions.
	   11-Jul-17						Suresh Vagalla\Subhashish					Added "Bulk Publish Assessments" bug fix code
	   31-Aug-17						Shruthi Shetty								Modified to fix ZDT 21986
	   28-May-19						Nithin										Modified to support PLC Groups - SC-127. @since v7.0.0
	   14-Feb-20                        Madhushree K                                Modified for Bug [SC-5702] 7.2 - Premade assessment - Based on the campus(scadmin) permission premade assessments rows are not showing in campus user.
	   16-Jun-20						Sushmitha									SC-7328 - Campus App permission Setting
	   29-Jul-20                        Gayithri N                                  Modified for ticket SC-7208 - Assessment Manager -> Network tab
	   24-Aug-20                        Gayithri N                                  Changed Setting.name from Network Access Name to SingularFormNetworkLabel for task SC-7208	   
       27-Aug-20                        Gayithri N                                  Added query to read role id for network role for SC-7208
	   21-Sep-20                        Shivakumar MG	                            Modified for SC-6766 Send to eduCLIMBER tab and button in Manage Assessments task @since v8.1.0
	   23-Nov-20						Sushmitha									Modified for SC-10005 - Display Linked assessments - Linked tab
	   07-Jan-22						Srinatha									Modified to read PLC assessments permissions for SC-17871 task.
       ---------------------------------------------------------------------------------------------------------------------------------------------------------------
*/
SET NOCOUNT ON
BEGIN
	begin try
       DECLARE @USERLEVEL VARCHAR
	   DECLARE @NetworkID INT = -1
	   DECLARE @NetworkTabName varchar(100) = 'Network'

       CREATE TABLE #TABTABLE (SORTORDER NUMERIC, NAME VARCHAR(50), Premade Bit, Settings varchar(max))
       
       SELECT @USERLEVEL = AccessLevelCode FROM Role 
       INNER JOIN UserRole ON Role.RoleID = UserRole.RoleID
       WHERE Role.InstanceID = @InstanceID AND UserRole.UserRoleID = @UserRoleID

	   if exists (select top 1 1 from InstanceAPP IA where exists (select AppID from  APP where AppID = IA.AppID and Name ='Network'))
	   begin
	    IF (@USERLEVEL = 'T' OR @USERLEVEL = 'C')
		 	set @NetworkID = (select top 1 NetworkID from NetworkCampus where CampusID = @CampusID)
                --Gayithri added for SC-7208
		Else if (@USERLEVEL = 'N')
		  	set @NetworkID = (select top 1 NetworkID from UserRoleNetwork where UserRoleID = @UserRoleID)
		end

        if(@NetworkID <> -1) 
		select @NetworkTabName = Value from InstanceSetting
        join Setting on InstanceSetting.SettingID = Setting.SettingID
        where InstanceID = @InstanceID and Setting.ShortName = 'SFNtLbl'


       INSERT INTO #TABTABLE VALUES(1, 'Recent', 0, null)
       
       IF (@USERLEVEL = 'T')
       BEGIN
               INSERT INTO #TABTABLE VALUES(2, 'My Assessments', 0, null)
               INSERT INTO #TABTABLE VALUES(3, 'School', 0, null)
			  if(@NetworkID <> -1) 
			   INSERT INTO #TABTABLE VALUES(4, @NetworkTabName, 0, null)
       END

       IF (@USERLEVEL = 'C')
       BEGIN
               INSERT INTO #TABTABLE VALUES(5, 'School', 0, null)
			   if(@NetworkID <> -1) 
			      INSERT INTO #TABTABLE VALUES(6, @NetworkTabName, 0, null)
       END
       IF (@USERLEVEL = 'N')
       BEGIN
			   INSERT INTO #TABTABLE VALUES(7, @NetworkTabName, 0, null)
       END
    
       INSERT INTO #TABTABLE VALUES(8, 'District', 0, null)

	   --** Nithin: 05/28/2019 - Added to support PLC Groups - SC-127. @since v7.0.0
	   if exists (select top 1 1 from [appfnCheckCampusApp](@InstanceID , 'PLCs' , '-1', @CampusID ))
		and 
		exists (select Top 1 1 from RolePermission RP join Permission P on RP.PermissionID = P.PermissionID
			join ObjectType OT on P.ObjectTypeID = OT.ObjectTypeID
			where RP.RoleID = (select RoleID from UserRole where UserRoleID = @UserRoleID) 
			and OT.Name in ('PermPLCAssessmentItemBank', 'PermPLCAssessmentOtherTypes')
			and P.OperationID in (Select OperationID from Operation where Name in ('View')) and isnull(RP.ScopeCode, 'A') = 'A')
			and exists (select distinct P.PLCID, P.Name as WSName from PLC P join PLCUser PU on P.PLCID = PU.PLCID
				where P.ActiveCode = 'A' and PU.UserAccountID = @UserAccountID)
		begin
			INSERT INTO #TABTABLE VALUES((select Max(SortOrder)+1 from #TABTABLE), 'PLC', 0, null)
		end

       --INSERT INTO #TABTABLE VALUES('State', 6)
       --INSERT INTO #TABTABLE VALUES('Shared', 7)
	   -- Shruthi: fix for ZDT 21986, Removed the Row_number order for the Sortorder column.
	   --if(@CampusID <> -1 and exists(select top 1 1 from App A JOIN CampusApp CA ON CA.AppID = A.AppID AND CA.CampusID = @CampusID where CA.IsActive  = 1)) -- Madhushree K : Modified for Bug [SC-5702]
	  -- begin
			INSERT INTO #TABTABLE
			SELECT SAT.SortOrder + 10, REPLACE (SAT.Name , '&' , '' ) as Name, 1, SAT.Settings from SpecialAssessmentTab SAT 
               INNER JOIN InstanceApp IA ON SAT.AppID = IA.AppID
               AND IA.InstanceID = @InstanceID AND IA.IsActive = 1 AND SAT.Name != 'Curriculum & Instruction'
			   union
				SELECT SAT.SortOrder + 10, REPLACE (SAT.Name , '&' , '' ) as Name, 1, SAT.Settings from SpecialAssessmentTab SAT 
			        INNER JOIN CampusApp CA ON SAT.AppID = CA.AppID
			        AND CA.CampusID = @CampusID AND CA.IsActive = 1 AND SAT.Name != 'Curriculum & Instruction'
		--end

		IF (@USERLEVEL in('D', 'A'))
		INSERT INTO #TABTABLE VALUES((select Max(SORTORDER)+1 from #TABTABLE), 'Imported', 0, null)
       
	   Declare @bulkActivate int = 0
	   Declare @RoleID NUMERIC
	   
		set @RoleID = (select distinct RoleId from userrole where UserRoleId = @UserRoleID)

		Set @bulkActivate  = ( select top 1 1 from Permission
		inner join ObjectType on Permission.ObjectTypeID = ObjectType.ObjectTypeID
		inner join Operation on Permission.OperationID = Operation.OperationID
		inner join RolePermission on Permission.PermissionId = RolePermission.PermissionID
		where Operation.name = 'Bulk Activate Online Testing' and RolePermission.RoleID = @RoleID
		and ObjectType.name in ('Assessment', 'CItemBank', 'COtherTypes', 'NItemBank', 'NOtherTypes', 'DItemBank', 'DOtherTypes') and RolePermission.ScopeCode in ('A', 'M'))

		if (ISNULL(@bulkActivate, 0) != 1)
		begin
				Set @bulkActivate  = (select top 1 1 from Permission
				inner join ObjectType on Permission.ObjectTypeID = ObjectType.ObjectTypeID
				inner join Operation on Permission.OperationID = Operation.OperationID
				inner join RolePermission on Permission.PermissionId = RolePermission.PermissionID
				where Operation.name = 'Bulk Activate Online Testing' and RolePermission.RoleID = @RoleID
				and ObjectType.name in ('Inspect','Synced','RapidResponse','EngageNY', 'Measured Progress'
				, 'PermPLCassessmentItemBank', 'PermPLCassessmentOtherTypes') ) --Srinatha: Included PLC assessments object names for SC-17871 task
		End
		
		-- Sushmitha : SC-9205 - Added Linked Tab 
		INSERT INTO #TABTABLE VALUES((select Max(SORTORDER)+1 from #TABTABLE), 'Linked', 0, null)

		--Shivakumar MG : Added for SC-6766 Send to eduCLIMBER tab and button in Manage Assessments task @since v8.1.0
		if(exists(select top 1 1 from Permission
		inner join ObjectType on Permission.ObjectTypeID = ObjectType.ObjectTypeID
		inner join Operation on Permission.OperationID = Operation.OperationID
		inner join RolePermission on Permission.PermissionId = RolePermission.PermissionID
		inner join App on Permission.Appid = App.appId
		inner join InstanceApp on InstanceApp.appid = App.appId
		where InstanceApp.InstanceID = @InstanceID and RolePermission.RoleID = @RoleID
		and app.name = 'eduCLIMBER' and InstanceApp.IsActive = 1
		and ObjectType.name = 'eduCLIMBER' and  Operation.name = 'Send Data'))

		insert into #TABTABLE values((select Max(SORTORDER)+1 from #TABTABLE), 'eduCLIMBER', 0, null)

		IF ((@USERLEVEL = 'T') OR (ISNULL(@bulkActivate, 0) = 1)) 
			INSERT INTO #TABTABLE VALUES((select Max(SORTORDER)+1 from #TABTABLE), 'Bulk Activations', 0, null)
           
		---Bulk Publish Assessments
		declare @bulkPublish int = 0
		Set @bulkPublish  = ( select top 1 1 from Permission
		inner join ObjectType on Permission.ObjectTypeID = ObjectType.ObjectTypeID
		inner join Operation on Permission.OperationID = Operation.OperationID
		inner join RolePermission on Permission.PermissionId = RolePermission.PermissionID
		where Operation.name = 'Bulk Publish Assessments' and RolePermission.RoleID = @RoleID
		and ObjectType.name in ('Assessment', 'CItemBank', 'COtherTypes', 'NItemBank', 'NOtherTypes', 'DItemBank', 'DOtherTypes') and RolePermission.ScopeCode in ('A', 'M'))

		if (ISNULL(@bulkPublish, 0) != 1)
		begin
				Set @bulkPublish  = (select top 1 1 from Permission
				inner join ObjectType on Permission.ObjectTypeID = ObjectType.ObjectTypeID
				inner join Operation on Permission.OperationID = Operation.OperationID
				inner join RolePermission on Permission.PermissionId = RolePermission.PermissionID
				where Operation.name = 'Bulk Publish Assessments' and RolePermission.RoleID = @RoleID
				and ObjectType.name in ('Inspect','Synced','RapidResponse','EngageNY', 'Measured Progress') )
		End
		
		if ISNULL(@bulkPublish, 0) = 1 
		INSERT INTO #TABTABLE VALUES((select Max(SORTORDER)+1 from #TABTABLE),'Bulk Published Assessments', 0, null)

      SELECT * FROM #TABTABLE                              
      --DROP TABLE #TABTABLE

	end try
	begin catch
		declare @Parameters nvarchar(max) = ''
		set @Parameters = 'exec ' + object_name(@@procid) 
		+' @InstanceID = ' + Convert(varchar(50), @InstanceID)
		+', @UserAccountID = ' + convert(varchar(50), @UserAccountID)
		+', @UserRoleID = ' + convert(varchar(50), @UserRoleID)
		+', @CampusID = ' + convert(varchar(50), @CampusID)

		/* Exception Handling, If we are getting any error, then required information will be stored into below Error Table */
		insert into ErrorTable(DBName,Query,ErrorMessage,ProcedureName,CreatedDate)
		Values(db_name(),@Parameters,error_message(),object_name(@@procid),getdate());
	end catch

END
GO
            


            



            

-- ------------ Write DROP-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
IF  EXISTS (
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID (N'[dbo].[appfnCheckCampusApp]') AND 
type = N'TF')
DROP FUNCTION [dbo].[appfnCheckCampusApp];
GO
            


            


            

-- ------------ Write CREATE-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
-- select [dbo].[ZappfnCheckCampusApp_SR](2700001, 'Assessment',1140032)
 
CREATE function [dbo].[appfnCheckCampusApp](@InstanceID int, @AppName varchar(100), @IsFromModule varchar(100), @UserCampusID int)
returns @AppInfo table (AppID int,Name varchar(200), IsActive bit)
as 

/*    
 Revision History:    
 -------------------------------------------------------------------------------------------------------------------    
 DATE    			CREATED BY   	DESCRIPTION/REMARKS    
 -------------------------------------------------------------------------------------------------------------------    
 16-Jun-2020		Sushmitha		SC-7328 - Campus App permission Setting 
 12-Jan-2021		Srinatha R A	Commented Return statement to read Campus Apps when App is disabled in Instance to fix SC-18008 issue.
 --------------------------------------------------------------------------------------------------------------------    
*/   
begin
	declare @ParentID Int = -1
	if @IsFromModule <> '-1'
		select @ParentID = AppID from App where Name = @IsFromModule
				
	if @ParentID <> -1 -- for module based Apps like Assessment\Item Bank
	begin
		-- check if app is on in instance level else check campus level
		if @AppName <> '' 
		begin
			insert @AppInfo
			select A.AppID, @AppName, IsActive 
			from App A join InstanceApp IA on A.AppID = IA.AppID
			where A.Name = @AppName and IA.InstanceID = @InstanceID and IsActive = 1 and ParentID = @ParentID
			--return
		end

		if not exists(select top 1 1 from @AppInfo) and (@UserCampusID <> '' or @UserCampusID <> -1)
		begin
			insert @AppInfo
			select A.AppID, @AppName, IsActive 
			from App A join CampusApp CA on A.AppID = CA.AppID
			where A.Name = @AppName and CA.CampusID = @UserCampusID and IsActive = 1 and ParentID = @ParentID
			--return
		end 
	end
	else -- for all other apps
	begin
		if @AppName <> '' 
		begin
			insert @AppInfo
			select A.AppID, @AppName, IsActive 
			from App A join InstanceApp IA on A.AppID = IA.AppID
			where A.Name = @AppName and IA.InstanceID = @InstanceID and IsActive = 1
			--return
		end

		if not exists(select top 1 1 from @AppInfo) and (@UserCampusID <> '' or @UserCampusID <> -1)
		begin
			insert @AppInfo
			select A.AppID, @AppName, IsActive 
			from App A join CampusApp CA on A.AppID = CA.AppID
			where A.Name = @AppName and CA.CampusID = @UserCampusID and IsActive = 1
			--return
		end 
	end
return     
end
GO
            


            


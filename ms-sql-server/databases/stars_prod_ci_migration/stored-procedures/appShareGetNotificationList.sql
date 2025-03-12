
            

-- ------------ Write DROP-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
IF  EXISTS (
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID (N'[dbo].[appShareGetNotificationList]') AND 
type = N'P')
DROP PROCEDURE [dbo].[appShareGetNotificationList];
GO
            


            


            

-- ------------ Write CREATE-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
CREATE PROCEDURE  [dbo].[appShareGetNotificationList] 
	@NotificationXML xml
AS
	/*
		Revision History:
		-------------------------------------------------------------------------------------------------------------------
		DATE				CREATED BY						DESCRIPTION/REMARKS
		-------------------------------------------------------------------------------------------------------------------
		28-Aug-14			Anandan/Athar 					Get the Notification list.
		08-Jul-15			Suresh V						Included Time Zone Functionality.
		19-Nov-15           Anandan R						Added the condition for permanently delete notification.
		18-Jan-16           Thoufic M						Added Audit report notification.
		03-May-16           Ashish                          Returned AdditionalData column To Results.
		13-May-16			Shruthi/Athar Baba				Updated the query to get the Notification in the Date desc order. Fix for customer ticket:15229 
		20-May-16			Rahini J						Modified this procedure as per Bug 24768.
		17-OCT-16			Sandeep				            Added the forceSeek for Setting table
		02-dec-16           sowjanya                        Removed forceSeek() function and added try_cast() function for @RequiredTZ variables
		18-Oct-17           SUDHIR KRISHNA CH				Modified the procedure to handle the Support Plan in the Notifciation @V5.1.0
		09-Jan-18			Sai Krishna						Modified the procedure to handle the ScoringEvent
		09-Jan-18           Lokeshwari                      Modified to fix bug #39841
		12-Feb-18			Manohar							Modified to return the result sorting on NotificationID desc
		05-Jun-18			Kapil                           Modified to get the count and notification related to Dashboard
		26-Sep-18           Ayesha Khanam                   Modified to get the count and notification relates to Survey
		28-Sep-18			Sravani Balireddy				Added code @6.1 - RubricTemplate Notification conditions
		17-Oct-18           Khushboo                        Modified for 'Allow teachers to share Assessments directly to specific school and district users' task 6.1
		03-Jan-19			Srinatha R A					Modified for 6.2 Notification Enhancement task.
		22-Feb-19			ChinnaReddy						Modified for 7.0 Survey Notifications will display an active survey link.
		16-Oct-18			Ayesha Khanam					Modified for 7.0.0 [SC-72] Allow students and staff to take surveys in semi-anonymous mode task.
		27-May-19			Venkatesh						Added Survey bulk print notification for [SC - 785] Survey - Print - Bulk Print Manager for Survey task v7.0.0
		16-Oct-19			Venkatesh						Modified to fix SC-3383 issue that taking only Active survey & RubricTemplate when getting the notification count
		30-Dec-19           Ayesha Khanam                   Modified to read Method of Delivery in Additional Data column for Survey to fix SC-4811
		04-Mar-20			Abdul Rahiman					Modified for SC-3462-7.2 -QTI Notifications
		09-Jul-20			Srinatha						Modified to fix SC-7730 'No notifications displying at notification center' issue.
		26-Nov-21           Madhushree K                    Modified for [SC-15450] Notifications for Bulk Download of Student Summary Report
		20-May-22			JayaPrakash						Modified to avoid SQL Injections SC-19606
		24-Apr-23			JayaPrakash						Modified for SC-24869-HISD and Suite version Merging Preparation task.
		23-jun-23           Rakshith H S                    Modified for SC-25801 Prodqa02 | Dashbaord |User's are not getting notifications for shared dashboard.
		20-Sep-24           Srikanth CH                     Modified for SC-32565 HISD DB Performance Issue: Save Online Administration Procedure
		-------------------------------------------------------------------------------------------------------------------
	*/
	/*
	 EXEC [dbo].[appShareGetNotificationList]'<Notification><CT>0</CT><UID>1052031</UID><URID></URID><NT>n</NT><FD>-1</FD><TD>-1</TD><SS></SS></Notification>'		
	 EXEC [dbo].[ZappShareGetNotificationListKK]'<Notification><CT>0</CT><IID>2700001</IID><UID>1042614</UID><UCID>1100047</UCID><NT>o</NT><URID>1141347</URID><FD>-1</FD><TD>-1</TD><SS>-1</SS></Notification>'

	*/
Begin
Set Nocount on
	Begin Try
	
		declare @Count int
		declare @TotalNotificationCount int
		declare @UserAccountID int
		declare @UserRoleID int
		declare @Type varchar(2)
		declare @FromDate varchar(20)
		declare @ToDate varchar(20)
		declare @SearchString varchar(max)
		declare @Query varchar(max)
		declare @RequiredTZ int
		declare @AccessLevelCode char
		declare @InstanceID int  --Khushboo : added the parameter for 'Allow teachers to share Assessments directly to specific school and district users' task 6.1 
		declare @UserCampusID int --Khushboo : added the parameter for 'Allow teachers to share Assessments directly to specific school and district users' task 6.1 

		select 
			@Count = objNode.value('CT[1]', 'INT'),
			@InstanceID = objNode.value('IID[1]', 'INT'),
			@UserAccountID = objNode.value('UID[1]', 'INT'),
			@UserRoleID = objNode.value('URID[1]', 'INT'),
			@UserCampusID = objNode.value('UCID[1]', 'INT'),
			@Type = objNode.value('NT[1]', 'VARCHAR(2)'),
			@FromDate = objNode.value('FD[1]', 'VARCHAR(20)'),
			@ToDate = objNode.value('TD[1]', 'VARCHAR(20)'),
			@SearchString = objNode.value('SS[1]', 'VARCHAR(MAX)')
		from
			@NotificationXML.nodes('/Notification') nodeset(objNode)

			/* SC-19606, Below Function added by JayaPrakash to avoid SQL Injections attacks, START*/
		-- Here 1-to check the issue in Parameters, 2 - check issue at comma seperated values, 3 - check Sortcolumn
		IF (select dbo.[appfnGetInjectionIds](@SearchString,1)) = -1
			Return;

		--Added for SC-24869-HISD and Suite version Merging Preparation task.
		declare @Ishisd bit = 0
		if exists(select top 1 1 from ApplicationSetting where SettingID in(Select SettingID from setting where ShortName = 'CodeBase') and Value = 'hisd')
			set @Ishisd = 1

		select @AccessLevelCode = (CASE WHEN  AccessLevelCode = 'T' then 'U' else AccessLevelCode end)
		from Role JOIN UserRole on Role.RoleID = UserROle.RoleID where UserRoleID = @UserRoleID and UserRole.UserAccountID = @UserAccountID

		select @RequiredTZ = try_cast(instanceSetting.Value AS INT) 
		from instanceSetting 
			join Setting  on setting.settingID = instanceSetting.settingID 
		where Name = 'TimezoneOffset' 
			and InstanceID = (select InstanceID from UserAccount where UserAccountID = @UserAccountID)

		--Venkatesh : Added condition to get only Active and Non/Semi Anonymous surveys while returning the notification count
		if(@Count = 1)
		begin
			set @Query = 'select count(distinct NotificationID) from (
								select NotificationID from Notification N 
								join ObjectType OT on OT.ObjectTypeID = N.ObjectTypeID
								join Survey S on N.ObjectId = S.SurveyID 
								where N.ToUserAccountID = ' + CAST(@UserAccountID as varchar) + ' and N.ActionCode IS NULL and S.ActiveCode = ''A'' 
								and Mode != 1 and N.TypeCode = ''SUR'' and OT.Name = ''Survey''
								union all  -- SC-32565 : Converted union to union all
								select NotificationID from Notification N 
								join ObjectType OT on OT.ObjectTypeID = N.ObjectTypeID
								join RubricTemplate RT on RT.RubricTemplateId = N.ObjectID 
								where N.ToUserAccountID = ' + CAST(@UserAccountID as varchar) + ' and N.ActionCode IS NULL and OT.Name = ''RubricTemplate''
								union all  -- SC-32565 : Converted union to union all
								(Select Notification.notificationId from notification
								inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID
								--left outer join Assessment ON Assessment.assessmentID = Notification.ObjectID and ObjectType.Name = ''Assessment''
								--left outer join Report ON Report.reportID = Notification.ObjectID and  ObjectType.Name = ''Report''
								--left outer join DashboardPage ON DashboardPage.DashboardPageID = Notification.ObjectID and  ObjectType.Name = ''DashboardPage''
								Where Notification.ToUserAccountID = ' + CAST(@UserAccountID as varchar) + ' and Notification.ActionCode IS NULL
								and notification.TypeCode != ''SAL'' and Notification.Typecode != ''SUR'' 
								and Notification.ObjectTypeID not in (select ObjectTypeID from objectType where Name in(''RubricTemplate'', ''QTIExport'') )) '
								--Srinatha: Added below code to get 'QTIExport' notifications count to fix SC-7730 issue
								+ 'union all -- SC-32565 : Converted union to union all
								select NotificationID from Notification N 
								join ObjectType OT on OT.ObjectTypeID = N.ObjectTypeID
								join PrintJob P on P.PrintJobID = N.ObjectID 
									and P.ObjectTypeID in (select ObjectTypeID from ObjectType where ObjectType.Name in (''Bank'',''Assessment'')) '							
								+ ' where N.ToUserAccountID = ' + CAST(@UserAccountID as varchar) + ' and N.ActionCode IS NULL and OT.Name = ''QTIExport'' and N.TypeCode = ''BLKR''
								and P.StatusCode in (''3'', ''D'')
								) Count'
								 exec(@Query) 
		end

		else 
		begin
		 
		 --Khushboo : Added below table to check LevelCode for Assessment that is accepted by other user '
		--for 'Allow teachers to share Assessments directly to specific school and district users' task 6.1 
		create table #Permission(RoleID int, AccessLevelCode char, ObjectType varchar(100))
		insert into #Permission
		select distinct R.RoleID, R.AccessLevelCode, OT.Name from Operation O 
								 join Permission P on O.OperationID = P.OperationID
								 join ObjectType OT on OT.ObjectTypeID = P.ObjectTypeID
								 join RolePermission RP on RP.PermissionID = P.PermissionID
								 join UserRole UR  on UR.RoleID = RP.RoleID
								 join Role R on R.RoleID = UR.RoleID
								 where  UR.UserRoleID = @UserRoleID  and R.InstanceID = @InstanceID and O.Name = 'View' and R.ActiveCode = 'A'
								 and  isnull(RP.ScopeCode, 'A') <> 'N' and OT.Name in ( 'TOtherTypes' ,'COtherTypes', 'DOtherTypes', 'TItemBank', 'CItemBank','DItemBank')


		create table #AssessLevel(NotificationID int, ObjectID int, ActionObjectID int, LevelCode char, LevelOwnerID int, TypeCode char)

		set @Query = 'insert into #AssessLevel
		              select N2.NotificationID, N2.ObjectID, N2.ActionObjectID, A.LevelCode, A.LevelOwnerID, A.TypeCode 
					  from(select ObjectID from  Notification N1
					  join ObjectType OT on OT.ObjectTypeID = N1.ObjectTypeID and OT.Name = ''Assessment'' 
					  join UserAccount UA on UA.UserAccountID = N1.CreatedBy
					  join Assessment A on A.AssessmentID = N1.ObjectID 
					   where N1.ToUserAccountID = ' + cast(@UserAccountID as varchar) +
					  ' and N1.ActionCode is null and N1.TypeCode <> ''SOCRWP'')Z
					  join Notification N2 on Z.ObjectID = N2.ObjectID
					  join Assessment A on N2.ActionObjectID = A.AssessmentID
					  join #Permission P on A.LevelCode = P.AccessLevelCode
					  where N2.ActionCode = ''A'' and A.ActiveCode = ''A'' and N2.ActionObjectID is not null and N2.TypeCode <> ''SOCRWP''
					  and ('
					   + stuff((case when exists(select top 1 1 from #Permission where ObjectType = 'DOtherTypes') 
					          then 'or ( A.LevelCode = ''D'' and A.TypeCode <> ''B'')' else '' end)
							 + (case when exists(select top 1 1 from #Permission where ObjectType = 'DItemBank') 
							  then ' or ( A.LevelCode = ''D'' and A.TypeCode = ''B'')' else '' end)
							  + (case when exists(select top 1 1 from #Permission where ObjectType = 'COtherTypes') and @AccessLevelCode in ('C', 'T') 
							  then 'or ( A.LevelCode = ''C'' and A.LevelOwnerID = ' + cast(@UserCampusID as varchar) +' and A.TypeCode <> ''B'')' else '' end)
							  + (case when exists(select top 1 1 from #Permission where ObjectType = 'CItemBank') and @AccessLevelCode in ('C', 'T')
							  then 'or  (A.LevelCode = ''C'' and A.LevelOwnerID = ' + cast(@UserCampusID as varchar) +' and A.TypeCode = ''B'')' else '' end),1,3,'') + ')'
		print @Query
		exec (@Query)					   

		--SC-32565 : Created temp table to Improve performance
        Create Table #Notification (ObjectID int, ObjectTypeID smallint, CreatedDate varchar(10), Name varchar(200), displayname varchar(200), Fn varchar(100), Ln varchar(100), Description varchar(max),
		NotificationID int, ActionCode varchar(10), ActionDate varchar(10), HasDocuments Bit,AdditionalData  varchar(max) ,Accepted  smallint)
			set @Query = 'SELECT  Notification.ObjectID, Notification.ObjectTypeID, 
								Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, ObjectType.Name, Assessment.name as displayname, 
								cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
					   cast(notification.Description  as varchar(max)) [Description], Notification.NotificationID, 
					   (case when Notification.ActionCode = ''A'' and Notification.ActionObjectID is null then ''O'' else Notification.ActionCode end) ActionCode, Convert(varchar(10), Notification.ActionDate, 101) as ActionDate,
					   Assessment.HasDocuments, Notification.AdditionalData ,
					   (case when AL.LevelCode = ''D'' then 1
					        when AL.LevelCode  = ''C'' then 2
							else 0 end) as Accepted 
							FROM Notification
								inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and ObjectType.Name = ''Assessment'' 
								inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
								inner join Assessment ON Assessment.assessmentID = Notification.ObjectID 
					   left outer join #AssessLevel AL on AL.ObjectID = Notification.ObjectID 
							Where Notification.ToUserAccountID = ' + cast(@UserAccountID as varchar) + ' and Notification.TypeCode <> ''SOCRWP'' '

		--Khushboo : commented below code and added above code for 'Allow teachers to share Assessments directly to specific school and district users' task 6.1 

	  --set @Query = 'select ObjectID, ObjectTypeID, CreatedDate, Name, displayname, Fn, Ln, Description, NotificationID, ActionCode, ActionDate, HasDocuments, AdditionalData from ('
	  --set @Query += 'SELECT  Notification.ObjectID, Notification.ObjectTypeID, 
	  --			   Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, ObjectType.Name, Assessment.name as displayname, 
	  --			   cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
	  --			   cast(notification.Description  as varchar(max)) [Description], Notification.NotificationID, Notification.ActionCode, Convert(varchar(10), Notification.ActionDate, 101) as ActionDate,
	  --			   Assessment.HasDocuments, Notification.AdditionalData 
	  --			   FROM Notification
	  --			   inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and ObjectType.Name = ''Assessment'' 
	  --			   inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
	  --			   inner join Assessment ON Assessment.assessmentID = Notification.ObjectID 
	  --			   Where Notification.ToUserAccountID = ' + cast(@UserAccountID as varchar)

				if(@Type = 'n')
				begin
					set @Query+= ' and Notification.ActionCode is null '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' AND Assessment.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end
				insert into #Notification --SC-32565 insert into Temptable   
				exec(@Query) 

				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
								ObjectType.Name, CAST(Report.Name AS varchar(max)) as displayname, cast(UserAccount.FirstName AS varchar(max)) AS Fn,
								cast(UserAccount.LastName AS varchar(max)) as Ln, cast(notification.Description  as varchar(max)) as [Description],
								Notification.NotificationID, Notification.ActionCode, 
								Convert(varchar(10), Notification.ActionDate, 101) as ActionDate, '''', Notification.AdditionalData, '''' 
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''Report''
									inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
									inner join Report ON Report.ReportID = Notification.ObjectID 
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar) + ' and Notification.TypeCode <> ''BLKR'' '

				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' and Report.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end
				
				insert into #Notification --SC-32565 insert into Temptable 
				exec(@Query) 


				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									ObjectType.Name, CAST(CDData.Label AS varchar(max)) as displayname , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
								Convert(varchar(10), Notification.ActionDate, 101) as ActionDate, '''' , Notification.AdditionalData, ''''
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''AsyncReport''
									inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
									inner join (select CDF.Code, CDF.Label from CodeDomain CD join CodeDefinition CDF on CD.CodeDomainID = CDF.CodeDomainID where CD.Name = ''AsyncReport'') CDData
									on Notification.TypeCode = CDData.Code
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar)
					
				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
					set @Query+= ' AND Notification.ActionCode <> ''D'''
					--Added for SC-24869-HISD and Suite version Merging Preparation task.
					IF @Ishisd = 0
					BEGIN
						if(@SearchString != '-1')  
						set @Query+= ' and CAST(CDData.Label AS varchar(max)) like  ''%' + @SearchString + '%'''	
					END
				end

				--Shruthi has commented below code since we are not using SAL
				--set @Query += ' union '

				--set @Query += ' select  Notification.ObjectID, Notification.ObjectTypeID, 
				--					Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
				--					ObjectType.Name, CAST(SALPLan.Name AS varchar(max)) as displayname, cast(UserAccount.FirstName AS varchar(max)) AS Fn, 
				--					cast(UserAccount.LastName AS varchar(max)) as Ln, cast(notification.Description  as varchar(max)) as [Description], 
				--					Notification.NotificationID, Notification.ActionCode, Convert(varchar(10), Notification.ActionDate, 101) as ActionDate, 
	   --                         '''', Notification.AdditionalData, ''''
				--				from Notification
				--					inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''SALPlan''
				--					inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
				--					inner join SALPlan ON SALPLan.SALPlanID = Notification.ObjectID 
				--				Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar)

				--if(@Type = 'n')
				--begin
				--	set @Query+= ' AND Notification.ActionCode IS NULL '
				--end
				--else
				--begin
    --                if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
				--	if(@SearchString != '-1')  set @Query+= ' and SALPLan.Name like  ''%' + @SearchString + '%'''
				--	set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				--end

				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 

				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									ObjectType.Name, CAST(ScoringEvent.Name AS varchar(max)) as displayname , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
								Convert(varchar(10), Notification.ActionDate, 101) as ActionDate, '''', Notification.AdditionalData, '''' 
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''ScoringEvent''
									inner join ScoringEvent ON ScoringEvent.ScoringEventID = Notification.ObjectID 
									inner join UserAccount ON UserAccount.UserAccountID = ScoringEvent.CreatedBy
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar)

				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' and ScoringEvent.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end

				-- Added Dashboard Notification conditions
				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 


				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									ObjectType.Name, CAST(DashboardPage.Name AS varchar(max)) as displayname , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
								Convert(varchar(10), Notification.ActionDate, 101) as ActionDate, '''', Notification.AdditionalData, '''' 
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''DashboardPage''
									inner join DashboardPage ON DashboardPage.DashboardPageID = Notification.ObjectID 
									inner join UserAccount ON UserAccount.UserAccountID = DashboardPage.UserAccountID
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar)

				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' and DashboardPage.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end

				--Added Survey Notification -- ChinnaReddy : Modified for @v7.0 (SC-70 Survey Notifications will display an active survey link) 
				                            -- In Additional column added Survey Start date, End date, AllowResubmission, IsSurveySubmit values as a JSON object.
											-- Added  Survey.ActiveCode = 'A' and Mode = 0 also.
											-- Ayesha : Modified to read Method Of Delivery also

				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 

				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									ObjectType.Name, CAST(Survey.Name AS varchar(max)) as displayname , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
									Convert(varchar(10), Notification.ActionDate, 101) as ActionDate,
						'''', ''{"StartDate" : "''+ Convert(varchar(10), Survey.StartDate, 101)  
						+''", "EndDate" : "''+ Convert(varchar(10), Survey.EndDate, 101)
						+''", "WindowStart" : "''+ cast(Survey.WindowStart as varchar(20)) 
						+''", "WindowEnd" : "''+ cast(Survey.WindowEnd as varchar(20)) 
						+''", "WindowDays" : "''+ cast(Survey.WindowDays as varchar(30)) 
						+''", "AllowResubmission": "''+ cast(Survey.AllowResubmission as varchar(10)) 
						+''", "IsSurveySubmit" : "''+ cast((case when exists (select top 1 1 from SurveyAttempt where SurveyID = Survey.SurveyID and UserAccountID = '+ cast(@UserAccountID AS varchar)+') then 1 else 0 end) as varchar(10))
						+''", "MethodOfDelivery" : "''+ cast(Survey.MethodOfDelivery as varchar(20))  +''"}'' as AdditionalData, '''' 
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''Survey''
									inner join Survey ON Survey.SurveyID = Notification.ObjectID 
									inner join UserAccount ON UserAccount.UserAccountID = Survey.CreatedBy
								Where Survey.ActiveCode=''A'' and Mode != 1 and Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar) + ' and Notification.TypeCode = ''SUR'' '
                
				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' and Survey.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end
				print @Query
				--Sravani Balireddy : Added below code @6.1 - RubricTemplate Notification conditions
				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 

				--** Nithin: 07-11-2019 - Modified to support Notification featue - [SC-79] - HISD Notification Enhancements. @since v7.0.0. Modified query to join Notification table with AssessmentForm table.
				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									ObjectType.Name, CAST(RubricTemplate.Name AS varchar(max)) as displayname , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
									Convert(varchar(10), Notification.ActionDate, 101) as ActionDate,
						'''', Notification.AdditionalData, ''''
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''RubricTemplate''
									inner join RubricTemplate ON RubricTemplate.RubricTemplateID = Notification.ObjectID 
									inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar)
				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' and RubricTemplate.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end

				--Srinatha R A : Added below code @6.2 - Notification Enhancement task
				--To Show Score CR/WP Items Notification
				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 


				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									''Assessment Scoring'', CAST(Assessment.Name AS varchar(max)) as displayname , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
									Convert(varchar(10), Notification.ActionDate, 101) as ActionDate,'''',
									Notification.AdditionalData as AdditionalData, ''''
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID '
									--Added for SC-24869-HISD and Suite version Merging Preparation task.
									IF @Ishisd = 0 
										set @Query += ' and  ObjectType.Name = ''Assessment'' '
									Else 
										set @Query += ' and  ObjectType.Name = ''AssessmentForm'' ' 
									--Rakshith modified below query and added AssessmentForm table join for SC-25801.
									IF @Ishisd = 0 
									    set @Query += ' inner join Assessment ON Assessment.AssessmentID = Notification.ObjectID '
									Else 
										set @Query += ' inner join AssessmentForm on Notification.ObjectID = AssessmentForm.AssessmentFormID
										inner join Assessment ON Assessment.AssessmentID = AssessmentForm.AssessmentID '
									set @Query += ' inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar) + ' and Notification.TypeCode = ''SOCRWP'' '
				
				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' and Assessment.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end

				--To Show Bulk Answer sheet Notification
				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 


				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									''Answer Sheets'', CAST(Assessment.Name AS varchar(max)) as displayname , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
									Convert(varchar(10), Notification.ActionDate, 101) as ActionDate,'''',
									Notification.AdditionalData + ''", "Grade" : "'' + 
								   case when Grade.ShortName is not null then Grade.ShortName + ''"''
								   else ''"'' end +''}'' as AdditionalData, 
								    case when (select PrintJob.PrintJobID from PrintJob
									where PrintJob.ObjectID = Notification.ObjectID and Notification.ObjectTypeID = PrintJob.ObjectTypeID
									and substring(Notification.AdditionalData, 17, charindex(''"'', Notification.AdditionalData, 17) - charindex(''"'', Notification.AdditionalData, 16)-1) = PrintJob.PrintJobID)>0 then 1 else 0 end
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''AssessmentForm''
									inner join AssessmentForm ON AssessmentForm.AssessmentFormID = Notification.ObjectID 
									inner join Assessment ON Assessment.AssessmentID = AssessmentForm.AssessmentID 
									inner join Subject ON Subject.SubjectID = AssessmentForm.SubjectID
									left join Grade ON Grade.GradeID = AssessmentForm.GradeID 
									inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar) + ' and Notification.TypeCode = ''BLKR'' '
				
				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' and Assessment.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end

				--To Show PDF Score online CR/WP items Notification
				-- Madhushree K: Modified for [SC-15450] Notifications for Bulk Download of Student Summary Report
				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 


				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									case when ObjectType.Name = ''HorizonBulkDownload'' then ''Horizon Report'' else ''PDF of CR/WP Items'' end, CAST(Assessment.Name AS varchar(max)) as displayname , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
									Convert(varchar(10), Notification.ActionDate, 101) as ActionDate,
									'''', Notification.AdditionalData +''"}'', 
									case when (select PrintJob.PrintJobID from PrintJob
									where PrintJob.ObjectID = Notification.ObjectID and Notification.ObjectTypeID = PrintJob.ObjectTypeID
									and substring(Notification.AdditionalData, 17, charindex(''"'', Notification.AdditionalData, 17) - charindex(''"'', Notification.AdditionalData, 16)-1) = PrintJob.PrintJobID)>0 then 1 else 0 end
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and ObjectType.Name in(''BulkPrintCR'',''HorizonBulkDownload'')
									inner join Assessment ON Assessment.AssessmentID = Notification.ObjectID 
									inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar) + ' and Notification.TypeCode = ''BLKR'' '
				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' and Assessment.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end

				--To Show Standards Progression Notification
				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 


				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									''Standards Progression Report'', CAST(Report.Name AS varchar(max)) as displayname , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
									Convert(varchar(10), Notification.ActionDate, 101) as ActionDate,
						'''', Notification.AdditionalData +''"}'', 
									case when (select PrintJob.PrintJobID from PrintJob
									where PrintJob.ObjectID = Notification.ObjectID and Notification.ObjectTypeID = PrintJob.ObjectTypeID
									and substring(Notification.AdditionalData, 17, charindex(''"'', Notification.AdditionalData, 17) - charindex(''"'', Notification.AdditionalData, 16)-1) = PrintJob.PrintJobID)>0 then 1 else 0 end
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''Standards Progression''
									inner join Report ON Report.ReportID = Notification.ObjectID 
									inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar) + ' and Notification.TypeCode = ''BLKR'' '
				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' and Report.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end

				--To Show Student History Notification
				if(@SearchString = '-1')
				begin
				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 


				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									''Student History Report'', '''' as displayname , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
									Convert(varchar(10), Notification.ActionDate, 101) as ActionDate,
						'''', Notification.AdditionalData +''"}'', 
									case when (select PrintJob.PrintJobID from PrintJob
									where Notification.ObjectTypeID = PrintJob.ObjectTypeID
									and substring(Notification.AdditionalData, 17, charindex(''"'', Notification.AdditionalData, 17) - charindex(''"'', Notification.AdditionalData, 16)-1) = PrintJob.PrintJobID)>0 then 1 else 0 end
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''Report''
									inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar) + ' and Notification.TypeCode = ''BLKR'' '
				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					--if(@SearchString != '-1')  set @Query+= ' and Report.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end
				end

				--To get Survey Sheets Notifications
				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 


				set @Query = ' select  Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									''Survey Sheets'', CAST(Survey.Name AS varchar(max)) as displayname , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
									Convert(varchar(10), Notification.ActionDate, 101) as ActionDate,
									'''',Notification.AdditionalData +''"}'',
									case when (select PrintJob.PrintJobID from PrintJob
									where PrintJob.ObjectID = Notification.ObjectID and Notification.ObjectTypeID = PrintJob.ObjectTypeID
									and substring(Notification.AdditionalData, 17, charindex(''"'', Notification.AdditionalData, 17) - charindex(''"'', Notification.AdditionalData, 16)-1) = PrintJob.PrintJobID)>0 then 1 else 0 end
								from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and  ObjectType.Name = ''Survey''
									inner join Survey ON Survey.SurveyID = Notification.ObjectID 
									inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar) + ' and Notification.TypeCode = ''BLKR'' '
				
				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' and Survey.name like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end
					--set @Query+= 'order by CreatedDate desc'

				--Abdul:  SC-3462: To Show QTIExport Notification
				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 


				set @Query = ' select Notification.ObjectID, Notification.ObjectTypeID, 
									Convert(varchar(10), [dbo].[GetDateTimeByTimezone](Notification.CreatedDate, '+ cast(@RequiredTZ as varchar(10)) +'), 101) as CreatedDate, 
									''QTIExport'', CAST(AttachedFile.OriginalName AS varchar(max)) as DisplayName , 
									cast(UserAccount.FirstName AS varchar(max)) AS Fn, cast(UserAccount.LastName AS varchar(max)) as Ln, 
									cast(notification.Description  as varchar(max)) as [Description], Notification.NotificationID, Notification.ActionCode, 
									Convert(varchar(10), Notification.ActionDate, 101) as ActionDate,'''',
									cast(''{"PrintJobID": "''+ cast(AttachedFile.ObjectID as varchar(max)) +''", "QTIFileName":"''+AttachedFile.OriginalName+''", "DateRequested":"''+ cast(format (P.CreatedDate, ''MM-dd-yyyy HH:mm:ss'') as varchar(max))+''"}'' as varchar(max)) ,null	
									from Notification
									inner join ObjectType ON ObjectType.ObjectTypeID = Notification.ObjectTypeID and ObjectType.Name = ''QTIExport''
									inner join PrintJob P on P.PrintJobID = Notification.ObjectID and P.ObjectTypeID in (select ObjectTypeID from ObjectType where ObjectType.Name in (''Bank'',''Assessment''))
									inner join AttachedFile ON AttachedFile.ObjectID = P.PrintJobID and AttachedFile.ObjectTypeID = (select ObjectTypeID from ObjectType where ObjectType.Name = ''PrintJob'')								
									inner join UserAccount ON UserAccount.UserAccountID = Notification.CreatedBy
								Where Notification.ToUserAccountID = ' + cast(@UserAccountID AS varchar) + ' and Notification.TypeCode = ''BLKR'' '
				if(@Type = 'n')
				begin
					set @Query+= ' AND Notification.ActionCode IS NULL '
				end
				else
				begin
                    if(@FromDate != '-1') set @Query+= ' AND Notification.CreatedDate between DATEADD(D, 0, DATEDIFF(D, 0, '+char(39)+cast(@FromDate as varchar(50))+char(39)++')) and DATEADD(D, 0, DATEDIFF(D, 0, ltrim(rtrim('+char(39)+cast(@ToDate as varchar(50))+char(39)+')))) + 1'
					if(@SearchString != '-1')  set @Query+= ' and AttachedFile.OriginalName like  ''%' + @SearchString + '%'''
					set @Query+= ' and  Notification.ActionCode is not null and Notification.ActionCode <> ''D'''
				end

				insert into #Notification --SC-32565 insert into Temptable
				exec(@Query) 			
			
				select * from  #Notification order by cast(CreatedDate as Date) desc, NotificationID desc
		end
		
	end try
	begin catch
		declare @Parameters nvarchar(max) = ''
		set @Parameters = 'exec '+object_name(@@procid)+'
		@NotificationXML = '''+Convert(nvarchar(max), @NotificationXML)+''' '

		/* Exception Handling, If we are getting any error, then required information will be stored into below Error Table */
		insert into ErrorTable(DBName,Query,ErrorMessage,ProcedureName,CreatedDate)
		Values(db_name(),@Parameters,error_message(),object_name(@@procid),getdate());
		select -1
	end catch
End
GO
            


            


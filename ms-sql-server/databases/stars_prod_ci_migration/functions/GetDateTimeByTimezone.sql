
            

-- ------------ Write DROP-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
IF  EXISTS (
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID (N'[dbo].[GetDateTimeByTimezone]') AND 
type = N'FN')
DROP FUNCTION [dbo].[GetDateTimeByTimezone];
GO
            


            


            

-- ------------ Write CREATE-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
CREATE function  [dbo].[GetDateTimeByTimezone](
@PSTDateTime	datetime,
@RequiredTZ		int
) 
returns datetime
as
begin
/*    
 Revision History:    
 --------------------------------------------------------------------
 DATE         CREATED/VERIFEED BY         DESCRIPTION/REMARKS    
 --------------------------------------------------------------------
 30-Jun-15   Venugopal/Suresh V          Get Different Time Zones  
 --------------------------------------------------------------------
*/  
	
	declare @DateandTime	datetime
	declare @2ndSunMar		date
	declare @1stSunNov		date
	
	If @RequiredTZ = 1 --Eastern Time Zone
		set @PSTDateTime =  dateadd(HH, +3, @PSTDateTime) 		
	else If @RequiredTZ = 2 -- Central Time Zone
		set @PSTDateTime = dateadd(HH, +2, @PSTDateTime) 
    else If @RequiredTZ = 3  --Mountain Standard Time
		set @PSTDateTime = dateadd(HH, +1, @PSTDateTime) 
	else If @RequiredTZ = 4 -- Mountain Standard Time (No DST)
		begin
			
			set @2ndSunMar = ( select dateadd( dd,7 + ( 6-( datediff( dd,0,dateadd (mm,( Year( getdate() )-1900 ) * 12 + 2,0 ) ) %7 ) ),
								dateadd(mm,(Year(getdate())-1900) * 12 + 2,0)) as [2ndSunMar] )
			set @1stSunNov = ( select dateadd( dd, ( 6-( datediff( dd,0,dateadd( mm,( Year( getdate() )-1900 ) * 12 + 10,0) ) %7 ) ),
								dateadd( mm,( Year( getdate())-1900 ) * 12 + 10,0 ) ) as [1stSunNov] ) 

			If @PSTDateTime not between @2ndSunMar and @1stSunNov 
				set @PSTDateTime = dateadd(HH, +1 ,@PSTDateTime) 

		end 
	else set @PSTDateTime = @PSTDateTime 

	return @PSTDateTime
end
GO
            


            


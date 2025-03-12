
            

-- ------------ Write DROP-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
IF  EXISTS (
SELECT * FROM sys.objects WHERE object_id = OBJECT_ID (N'[dbo].[appfnGetInjectionIds]') AND 
type = N'FN')
DROP FUNCTION [dbo].[appfnGetInjectionIds];
GO
            


            


            

-- ------------ Write CREATE-ROUTINE-stage scripts -----------

USE [Stars_PROD_CI_Migration]
GO
            
CREATE function [dbo].[appfnGetInjectionIds](@Data varchar(max),@Type int)  
 returns int
as begin  
/*
	Revision History:
	-----------------------------------------------------------------------------------------------------------
	DATE				MODIFIED BY			DESCRIPTION/REMARKS
	-----------------------------------------------------------------------------------------------------------
	03-May-2023			Srinatha			Modified to fix SC-25029 KH - Putnam County - missing report customer ticket
	08-Dec-2023         Rakshith            Modified for SC-28070 JDBC exception in the log for appOnlineGetStudentsForAdmin
	-----------------------------------------------------------------------------------------------------------
*/
	DECLARE @status int
	IF @Type = 1 -- Tocheck 1st level main parameters
	BEGIN
		IF ((CAST(@Data as varchar(Max)) like '%DECLARE %') 
		OR (CAST(@Data as varchar(Max)) like '%--%')
		OR (CAST(@Data as varchar(Max)) like '%EXEC %')
		OR (CAST(@Data as varchar(Max)) like '%EXEC\[%' ESCAPE '\') --Shruthi added for SC-22701 ticket.
		OR (CAST(@Data as varchar(Max)) like '%VARCHAR%')
		OR (CAST(@Data as varchar(Max)) like '%[%]%')
		OR (CAST(@Data as varchar(Max)) like '%=%')
		)
			Set @status = -1 
	END
	ELSE IF @Type = 2 -- Tocheck 2nd level comma seperated ID values
	BEGIN
		IF @Data like '%[a-z]%'    
			Set @status = -1

		ELSE IF PATINDEX( '%[~!@#$%^&*()_+=-\|}{;:''"/?.></]%', @Data ) > 0  
			Set @status = -1

		--Rakshith added beow  '-' and added  @Data <>'-1' to avoid '-' in comma separated ids for SC-24457
		-- and changes @Data <>'-1'  to @Data not like '-1' for SC-28070
		ELSE IF @Data like '%-%' and @Data not like '%-1%'
			Set @status = -1

	END
	ELSE IF @Type = 3 -- Tocheck 3rd level Sortcolumn issues
	begin
			Declare @Sort_len_Total int, @Sort_Len_special_Start int,@Sort_Len_special_end int, @Sort_Len_space int

			select  @Sort_len_Total = len(@Data),@Sort_Len_special_Start = CHARINDEX('[',@Data), 
			@Sort_Len_special_end = CHARINDEX(']',@Data),@Sort_Len_space = (len(@Data) - LEN(REPLACE(@Data,' ','')));

			IF @Sort_Len_special_Start = 1
			BEGIN
				select @Sort_Len_space = (len(STUFF(@Data,@Sort_Len_special_Start,@Sort_Len_special_end,'')) - 
				LEN(REPLACE(STUFF(@Data,@Sort_Len_special_Start,@Sort_Len_special_end,''),' ','')))
			END

			IF (@Data like '%--%' OR @Data like '%''%')  
			BEGIN 
				SET @status = -1
			END
			ELSE IF @Data like '% ASC' AND @Sort_Len_special_Start != 1 AND @Sort_Len_space = 1 
			BEGIN
				IF RIGHT(@Data,4) = ' ASC'
					SET @status = 1
				ELSE
					SET @status = -1
			END
			ELSE IF @Data like '% DESC' AND @Sort_Len_special_Start != 1 AND @Sort_Len_space = 1
			BEGIN
				IF RIGHT(@Data,5) = ' DESC'
					SET @status = 1
				ELSE
					SET @status = -1
			END
			ELSE 
			BEGIN
				IF @Sort_Len_special_Start = 1
				begin
					IF @Data like '% ASC' 
					BEGIN
						IF RIGHT(@Data,4) = ' ASC' AND @Sort_Len_space = 1
							SET @status = 1
						ELSE
							SET @status = -1
					END
					ELSE IF @Data like '% DESC' 
					BEGIN
						IF RIGHT(@Data,5) = ' DESC' AND @Sort_Len_space = 1
							SET @status = 1
						ELSE
							SET @status = -1
					END
					ELSE IF @Sort_Len_space = 0
						SET @status = 1
					ELSE
						SET @status = -1
				END
				ELSE
				BEGIN
					IF @Sort_Len_space = 0
						--Srinatha : Added below "OR" condition to handle morethan 1 sort column without [](brockets) symbols in it to fix SC-25029 customer ticket
						or (@Sort_Len_special_Start = 0 and @Sort_Len_space > 1)
						SET @status = 1
					ELSE
						SET @status = -1
				END
			END
	END
	ELSE
			Set @status = 1

RETURN @status;
end
GO
            


            


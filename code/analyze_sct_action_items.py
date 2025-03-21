import boto3
import utils
import logging

from botocore.exceptions import ClientError


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


bucket_name = "aml-renaissance-aws-tsql-conversion"
file_key = "aws-sct/databases/stars_prod_ci_migration/stored-procedures/appsharegetnotificationlist.sql"
file_name = "appsharegetnotificationlist.sql"
agent_name = "agent-analyze-sct-action-items"
agent_id = "XQSDB40KCL"
agent_alias_id = "UBD6ABRSJF"

new_file_key = file_key.replace("aws-sct", agent_name)


s3_client = boto3.client('s3')


# Get bedrock agent runtime and create a session
bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')
response = bedrock_agent_runtime.create_session()
session_id = response['sessionId']


# Get SCT code from s3
sct_code = utils.read_s3_file(s3_client, bucket_name, file_key)

# Initialize new code variable
new_code = sct_code


# Parse SCT code and get all DMS SC comment blocks that contain code that SCT was not able to convert
comment_blocks = utils.extract_dms_comments(sct_code)


for comment in comment_blocks:
    action_item = comment_blocks[comment]

    # Generate prompt values
    prompt = f"""
            The following is SQL code that you must convert to PostgreSQL compatible code. The code contains comment blocks that contain T-SQL code:
            {sct_code}


            The following is an action item that identifies which comment block in the code above you must focus on and provide PostgreSQL 16 compatible code:
            {action_item}


            Your task is to provide PostgreSQL 16 equivalent code for the T-SQL code in each action item that will later be used to replace the T-SQL comment block in the code. 

            Your response must adhere to the following rules:
            1. Be very deligent and ensure that you thoroughly analyze the code to understand the intent, logic and flow
            2. All code that is dynamically executed with an EXECUTE statement must use a FORMAT function. Do not refactor the code. An example of how to convert T-SQL EXEC statements is below:
                
                T-SQL Code: 
                EXEC (@PreDefinedQuery)

                PostgreSQL Code:
                EXECUTE format('%s', var_PreDefinedQuery);

                YOU MUST ONLY USE THIS FORMAT ABOVE FOR T-SQL EXEC STATEMENTS!
            3. The code you provide should be functional
            4. Do not return DDL in the <sql> values
            5. Only use temporary table names and variable names that have already been mapped to PostgreSQL compatible names already
            6. The PostgreSQL you provide must ONLY be a equivalent PostgreSQL translation of the T-SQL code. DO NOT REFACTOR THE CODE!
            7. Examples of how to convert T-SQL statements that are processing XML is below:

                Example 1. 
                T-SQL Code:
                select
                    objNode.value('RT[1]', 'varchar(100)'), 
                    objNode.value('AID[1]', 'int'), 	
                    objNode.value('RDSID[1]', 'int'), 
                    objNode.value('RYID[1]', 'int') 
                from @DefaultSetting.nodes('/Data/Type') nodeset(objNode)

                PostgreSQL Code:
                    SELECT 
                        (xpath('//RT/text()', x.objNode))[1]::text::varchar(100), 
                        CAST((xpath('//AID/text()', x.objNode))[1]::text AS integer), 
                        CAST((xpath('//RDSID/text()', x.objNode))[1]::text AS integer), 
                        CAST((xpath('//RYID/text()', x.objNode))[1]::text AS integer)
                    FROM 
                        unnest(xpath('//Data/Type', var_DefaultSetting)) AS x(objNode);

                Example 2.
                T-SQL Code:
                select @AllowAccess  = isnull(objNode.value('access[1]', 'char(1)'),'Y'),
                        @PastYear    = objNode.value('years[1]', 'int'),
                        @FutureYear  = objNode.value('aaccess[1]', 'char(1)')
                from
                        @PastRosterVisibility.nodes('/roster') nodeset(objNode)

                PostgreSQL Code:
                SELECT 
                    COALESCE((xpath('//roster/access/text()', var_PastRosterVisibility))[1]::text, 'Y'),
                    (xpath('//roster/years/text()', var_PastRosterVisibility))[1]::text::integer,
                    (xpath('//roster/aaccess/text()', var_PastRosterVisibility))[1]::text
                    INTO var_AllowAccess, var_PastYear, var_FutureYear;

            
        """


    # Get Agent Response
    llm_response = utils.prompt_llm(bedrock_agent_runtime, agent_id, agent_alias_id, session_id, prompt)

    # Extract XML tags from LLM response
    llm_response = utils.extract_xml_tags(llm_response, action_item)

    # Replace SCT comments with SQL from LLM
    new_code = utils.replace_sct_code(new_code, llm_response, agent_name)

    # Write new code to file
    utils.write_updated_code(new_code, file_name, agent_name)

# Upload new code to s3
utils.write_s3_file(s3_client, bucket_name, new_file_key, file_name)



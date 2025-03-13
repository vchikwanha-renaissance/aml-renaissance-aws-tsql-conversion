import boto3
import utils
import logging

from botocore.exceptions import ClientError


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


s3_client = boto3.client('s3')


# Get bedrock agent runtime and create a session
bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')
response = bedrock_agent_runtime.create_session()
session_id = response['sessionId']


bucket_name = "aml-renaissance-aws-tsql-conversion"
sct_file = "aws-sct/databases/stars_prod_ci_migration/stored-procedures/appreportdefaultfilters.sql"
action_items_file = "aws-sct/databases/stars_prod_ci_migration/stored-procedures/action-items/appreportdefaultfilters_action_items.txt"
agent_id = "8ZAGLZA8WW"
agent_alias_id = "XKU53JJYZH"


# Get files from s3
sct_code = utils.read_s3_file(s3_client, bucket_name, sct_file)
action_items = utils.read_s3_file(s3_client, bucket_name, action_items_file)

action_item = """
Action Item: 4 of 37
-------------------------
<sctComment>
	/*
	[7672 - Severity CRITICAL - PostgreSQL doesn't support EXECUTE statements that run a character string. Convert your source code manually.]
	exec (@StudentGrpQuery)
	*/
</sctComment>

	<sql>
-- PostgreSQL equivalent for executing dynamic student group query
EXECUTE FORMAT('INSERT INTO t$rosterstudents
    SELECT DISTINCT SGS.StudentID 
    FROM dbo.#UserStudentGroups SG
    JOIN dbo.StudentGroupStudent SGS ON SGS.StudentGroupID = SG.StudentGroupID
    WHERE SG.PublicRestrictToSIS = 0  
    EXCEPT
    SELECT StudentID FROM t$rosterstudents'
);
</sql>
<notes>
1. Uses PostgreSQL's EXECUTE with FORMAT function to safely handle dynamic SQL
2. Preserves the original logic of inserting student group students
3. Uses the existing temporary tables from the original procedure
4. Matches the original query's structure and conditions
5. Uses EXCEPT clause to remove duplicates, equivalent to the original T-SQL logic
6. Handles the student group insertion with the same join and filtering conditions
</notes>
"""


# Generate prompt values
prompt = f"""
        The following is the AWS SCT converted code:
        {sct_code}


        The following is the action item list:
        {action_item}
        
        
        Provide step by step instructions on how to integrate the SQL in the action item into the AWS SCT code
    """


# Get Agent Response
llm_response = utils.prompt_llm(bedrock_agent_runtime, agent_id, agent_alias_id, session_id, prompt)

#with open("steps_appreportdefaultfilters.txt", "a") as f:
#    f.write("\n\t")
#    f.write(llm_response)
#    f.writelines("\n\r\n\r")

print(llm_response)




    

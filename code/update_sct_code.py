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
agent_id = "T30M8JBJSY"
agent_alias_id = "AI5GLRGGCH"


# Get files from s3
sct_code = utils.read_s3_file(s3_client, bucket_name, sct_file)
action_items = utils.read_s3_file(s3_client, bucket_name, action_items_file)


# Generate prompt values
prompt = f"""
        The following is the AWS SCT converted code:
        {sct_code}


        The following is the action item list:
        {action_items}
        
        
        1. Complete the AWS SCT code conversion from T-SQL to PostgreSQL 16. 
        2. Implement EVERY action item listed in the action items list and apply the changes to the AWS SCT code. 
        3. Respond with the correct and complete PostgreSQL code
    """


# Get Agent Response
llm_response = utils.prompt_llm(bedrock_agent_runtime, agent_id, agent_alias_id, session_id, prompt)

with open("converted_appreportdefaultfilters.txt", "a") as f:
    f.write("\n\t")
    f.write(llm_response)
    f.writelines("\n\r\n\r")




    

import boto3
import utils
import logging

from botocore.exceptions import ClientError


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


bucket_name = "aml-renaissance-aws-tsql-conversion"
file_key = "aws-sct/databases/stars_prod_ci_migration/stored-procedures/appreportdefaultfilters.sql"
agent_id = "YEZTAMGSYI"
agent_alias_id = "KTSYISDRJX"


s3_client = boto3.client('s3')


# Get bedrock agent runtime and create a session
bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')
response = bedrock_agent_runtime.create_session()
session_id = response['sessionId']


# Get SCT code from s3
sct_code = utils.read_s3_file(s3_client, bucket_name, file_key)


# Parse SCT code and get all DMS SC comment blocks that contain code that SCT was not able to convert
comment_blocks = utils.extract_dms_comments(sct_code)
number_of_comments = len(comment_blocks)

i = 1
for comment in comment_blocks:
    action_item = comment_blocks[comment]

    # Generate prompt values
    prompt = f"""
            The following is SQL code that you must convert to PostgreSQL compatible code. The code contains comment blocks that contain T-SQL code:
            {sct_code}


            The following is an action item that identifies which comment block in the code above you must focus on and provide PostgreSQL 16 compatible code:
            {action_item}


            You must be very deligent and ensure that you thoroughly analyze the code to understand the intent, logic and flow. Use the ERROR_DESCRIPTION in the action item as a hint for what the code you provide should handle.

            Your task is to provide PostgreSQL 16 equivalent code for the T-SQL code in each action item that will later be used to replace the T-SQL comment block in the code.  
        """

    
    utils.write_action_items(action_item, i,  number_of_comments)    
    i += 1


    # Get Agent Response
    llm_response = utils.prompt_llm(bedrock_agent_runtime, agent_id, agent_alias_id, session_id, prompt)
    
    with open("action_items.txt", "a") as f:
        f.write("\n\t")
        f.write(llm_response)
        f.writelines("\n\r\n\r")

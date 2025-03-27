import boto3
import utils
import logging

from botocore.exceptions import ClientError


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


bucket_name = "aml-renaissance-aws-tsql-conversion"
file_key = "agent-analyze-sct-action-items/databases/stars_prod_ci_migration/stored-procedures/appsharegetnotificationlist.sql"
file_name = "appsharegetnotificationlist.sql"
agent_name = "agent-analyze-dynamic-sql-v2"
agent_id = "R8ZNIYI1EF"
agent_alias_id = "CJHDM6H7DA"


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
var_assignments = utils.extract_dynamic_expressions(sct_code)


for assignment in var_assignments:
    action_item = var_assignments[assignment]

    # Generate prompt values
    prompt_1 = f"""
The following code snippet is from the {file_name} stored procedure. Give me PostgreSQL 16 equivalent code for the following code snippet:
{action_item}

Return the corrected PostgreSQL 16 version of the code snippet enclosed in <sql></sql> tags

Thoroughly analyze the stored procedure, think it through, step by step. 
"""


    # Get Agent Response
    llm_response = utils.prompt_llm(bedrock_agent_runtime, agent_id, agent_alias_id, session_id, prompt_1)

    # Extract XML tags from LLM response
    llm_response = utils.extract_xml_tags(llm_response, action_item)

    # Replace SCT comments with SQL from LLM
    new_code = utils.replace_sct_code(new_code, llm_response, agent_name)

    # Write new code to file
    utils.write_updated_code2(new_code, file_name, agent_name)


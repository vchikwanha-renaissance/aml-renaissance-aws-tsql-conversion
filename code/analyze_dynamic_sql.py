import boto3
import utils
import logging

from botocore.exceptions import ClientError


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


bucket_name = "aml-renaissance-aws-tsql-conversion"
file_key = "agent-analyze-sct-action-items/databases/stars_prod_ci_migration/stored-procedures/appsharegetnotificationlist.sql"
file_name = "appsharegetnotificationlist.sql"
agent_name = "agent-analyze-dynamic-sql"
agent_id = "28BNG5JPPG"
agent_alias_id = "FG8CS8WVHB"


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
    prompt = f"""
The following is a variable assignment that was partially converted to PostgreSQL 16 compatible code:
{action_item}

The variable assignment above is a snippet of the following code. Use the following code to understand the full context in which the code you provide must comply. 
{sct_code}


Your task is to provide a full and complete PostgreSQL 16 equivalent statement for the variable assignment you have received. 

RETURN A COMPLETE AND EQUIVALENT POSTGRESQL COMPATIBLE VARIABLE ASSIGNMENT STATEMENT
        """


    # Get Agent Response
    llm_response = utils.prompt_llm(bedrock_agent_runtime, agent_id, agent_alias_id, session_id, prompt)

    # Extract XML tags from LLM response
    llm_response = utils.extract_xml_tags(llm_response, action_item)

    # Replace SCT comments with SQL from LLM
    new_code = utils.replace_sct_code(new_code, llm_response, agent_name)

    # Write new code to file
    utils.write_updated_code2(new_code, file_name, agent_name)


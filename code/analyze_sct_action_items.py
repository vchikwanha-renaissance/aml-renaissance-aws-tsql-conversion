import boto3
import utils
import logging

from botocore.exceptions import ClientError


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


bucket_name = "aml-renaissance-aws-tsql-conversion"
file_key = "aws-sct/databases/stars_prod_ci_migration/stored-procedures/appreportcheckdefaultassessment.sql"
file_name = "appreportcheckdefaultassessment.sql"

# Convert SCT code agent
agent_name = "agent-convert-sct-action-items"
agent_id = "QEKGKPJV5J"
agent_alias_id = "U6QIDYS0QV"

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

    # Generate prompt to get PostgreSQL code
    prompt_1 = f"""
        The following comment block is a snippet of code that is in {file_name}. Step by step, you must analyze {file_name}, identify input and output parameters, declared variables, temporary table names and logic flow. Use what you have learned to convert and adapt the following comment block to PostgreSQL:

        {action_item}
        
        Your task is to convert the T-SQL code embedded in the comment block above to PostgreSQL and adapt the variable names, parameter names, or temporary table names to the objects already defined in {file_name}

        The code you generate MUST:
        - Be well formed and optimized for perfomance
        - Follow PostgreSQL 16 best practices
        - Not include any declarations in the <sql> tag
        - Provide the updated code in <sql> tags and any other information in <notes> tag            
        """

    # Get Agent Response
    llm_response = utils.prompt_llm(bedrock_agent_runtime, 
                                    agent_id, 
                                    agent_alias_id, 
                                    session_id, 
                                    prompt_1)
    
    
    # Extract XML tags from LLM response
    llm_response = utils.extract_xml_tags(llm_response, action_item)
   

    # Update sct code with LLM generated SQL
    try:
        # Replace SCT comments with SQL from LLM
        new_code = utils.replace_sct_code(new_code, llm_response, agent_name)

        # Write new code to file
        utils.write_updated_code(new_code, file_name, agent_name)

    except Exception as e:
        logger.info(f"Agent response did not include sql for {action_item}: {e}")
        
        continue  
    

# Upload new code to s3
utils.write_s3_file(s3_client, bucket_name, new_file_key, file_name)



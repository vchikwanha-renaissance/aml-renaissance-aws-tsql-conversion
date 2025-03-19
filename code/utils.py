import sys
import re
import boto3
import logging

from botocore.exceptions import ClientError
from lxml import objectify

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__) 


# Function to list objects in s3 bucket
def list_s3_objects(s3_client, bucket_name):

    try:
        response = s3_client.list_objects_v2(Bucket=bucket_name)

        # Extract object keys from the response
        object_keys = [obj['Key'] for obj in response.get('Contents', [])]

        logger.info(f"Successfully listed objects in {bucket_name}")

        return object_keys
    except ClientError as e:
        logger.error(f"Error listing objects in {bucket_name}: {e}")
        raise
    

# Function to get SCT code from s3
def read_s3_file(s3_client, bucket_name, file_key):

    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
        sct_code = response['Body'].read().decode('utf-8')

        logger.info(f"Successfully read SCT Code from S3: {bucket_name}/{file_key}")
        
        return sct_code
    except ClientError as e:
        logger.error(f"Error reading {bucket_name}/{file_key} from S3: {e}")
        raise


# Function to parse SCT code and get all DMS SC comment blocks that contain code that SCT was not able to convert
def extract_dms_comments(sct_code):
    try:
        # Regular expression to match DMS SC comment blocks
        pattern = r'/\*\s*\[\d+\s*-\s*Severity\s+\w+\s*-\s*[^\]]+\].*?\*/'

        # Find all matches in the SQL content
        matches = re.finditer(pattern, sct_code, re.DOTALL)

        # Dictionary to store extracted comments
        comment_blocks = {}
       
        i = 1
        # Iterate through matches and extract comment blocks
        for match in matches:
            block = match.group(0).strip()
            comment_blocks[f"action_item_{i}"] = block
            i += 1

        logger.info(f"Successfully extracted DMS SC comment blocks")

    except ClientError as e:
        logger.error(f"Failed to extract DMS SC comment blocks: {e}")

    return comment_blocks


# Function to prompt LLM model to analyze T-SQL code and recommend PostgreSQL equivalent code
def prompt_llm(bedrock_agent_runtime, agent_id, agent_alias_id, session_id, prompt):
    
    try:
        response = bedrock_agent_runtime.invoke_agent(
            agentId=agent_id,
            agentAliasId=agent_alias_id,
            sessionId=session_id,
            endSession=False,
            inputText=prompt,
            streamingConfigurations={"streamFinalResponse":True}
        )

        completion = ""

        for event in response.get("completion"):
            completion += event["chunk"]["bytes"].decode("utf8")

        logger.info("Successfully invoked Bedrock Agent Runtime")

    except ClientError as e:
        logger.error(f"Error invoking Bedrock Agent Runtime: {e}")
        raise

    return completion



# Function to parse XML tags from the LLM response and return a dictionary
def extract_xml_tags(content):
    # Compile a regular expression to match xml tags
    pattern = re.compile(r'<([^>]+)>([^<]+)</\1>')

    # Find all matches in the content
    matches = pattern.findall(content)

    # Create a dictionary to store the extracted tags and their values
    tags = {}
    for match in matches:
        tag_name = match[0]
        tag_value = match[1]
        tags[tag_name] = tag_value

    return tags


# Function to clean up blank spaces from each line
def remove_blank_spaces(action_items): 
    items = {}

    for i in action_items.keys():
        block = action_items[i]

        # cleanup blank spaces from each line
        for line in block.split('\n'):
            line = line.lstrip(' ')
            items[i] = line


    return items
        

# Function to search and replace SCT comments
def replace_sct_comments(sct_code, action_items):
    for i in action_items.keys():
        sct_comment = action_items[i]["sct"]
        pg_sql = action_items[i]["sql"]

        # Replace SCT comment with PostgreSQL comment
        new_code = sct_code.replace(sct_comment, pg_sql)

    return new_code


# Function to write updated code to file
def write_updated_code(new_code):
    with open("updated_code.sql", "w") as f:
        for line in new_code.split('\n'):
            #line = line.lstrip(' ')
            f.writelines(line)
           






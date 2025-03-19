import sys
import re
import boto3
import logging
import sqlparse

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

        return comment_blocks

    except ClientError as e:
        logger.error(f"Failed to extract DMS SC comment blocks: {e}")


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

        return completion

    except ClientError as e:
        logger.error(f"Error invoking Bedrock Agent Runtime: {e}")
        raise


# Function to parse XML tags from the LLM response and return a dictionary
def extract_xml_tags(content, action_item):
    try:
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

        tags["sct"] = action_item

        return tags
    
    except Exception as e:
        logger.error(f"Error extracting xml tags from LLM response {content}: {e}")
        raise
        

# Function to search and replace SCT comments
def replace_sct_comments(sct_code, llm_response):
    try:
        sct_comment = llm_response["sct"]
        pg_sql = llm_response["sql"]

        # Handle new line characters so that the replacement SQL is not all on one line
        #pg_sql = pg_sql.replace("\n", "\n\r")

        pg_sql = f"""/* Gen AI converted code below */ {pg_sql}"""

        # Replace SCT comment with PostgreSQL comment
        sct_code = sct_code.replace(sct_comment, pg_sql)

        return sct_code
    
    except Exception as e:
        logger.error(f"Error replacing SCT comments with Gen AI code {llm_response}: {e}")
        raise


# Function to write updated code to file
def write_updated_code(new_code, file_name):
    try:
        with open(f"updated_{file_name}", "w") as f:
            # Use previous line to format generated code
            previous_line = ""
            comment_spaces = -1
            gen_ai_block = False

            for line in new_code.split('\n'):
                # Check if the previous line is a Gen AI comment block and get indentation spaces
                number_of_spaces = previous_line.find("/* Gen AI converted code below */")
                end_of_block = line.find(";")

                if gen_ai_block == True:
                    spaces = " " * comment_spaces
                    line = f"""{spaces}{line}"""
                    f.writelines(line)
                    f.writelines("\n")

                    if end_of_block != -1:
                        gen_ai_block = False

                elif number_of_spaces != -1:
                    gen_ai_block = True
                    comment_spaces = number_of_spaces
                    spaces = " " * comment_spaces
                    line = f"""{spaces}{line}"""
                    f.writelines("\n")
                    f.writelines(line)
                    f.writelines("\n")
                    print(line)

                    if end_of_block != -1:
                        gen_ai_block = False
                else:
                    if line.find("/* Gen AI converted code below */") != -1:
                        f.writelines("\n")
                        
                    f.writelines(line)

                previous_line = line

    except Exception as e:
        logger.error(f"Error writing updates to updated_{file_name}: {e}")
           






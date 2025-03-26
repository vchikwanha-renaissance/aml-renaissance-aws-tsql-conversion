import re
import time
import logging

from botocore.exceptions import ClientError

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

        # Replace SQL Server ERROR_MESSAGE with SQLERRM
        sct_code = sct_code.replace("error_catch$ERROR_MESSAGE", "SQLERRM")
        
        return sct_code
    
    except ClientError as e:
        logger.error(f"Error reading {bucket_name}/{file_key} from S3: {e}")
        raise


# Function to write updated code to s3
def write_s3_file(s3_client, bucket_name, file_key, file_name):

    try:
        with open(file_name, "r") as f:
            content = f.read().encode('utf-8')

            s3_client.put_object(Bucket=bucket_name, Key=file_key, Body=content)

            logger.info(f"Successfully wrote file to S3: {bucket_name}/{file_key}")

    except ClientError as e:
        logger.error(f"Error writing {bucket_name}/{file_key} to S3: {e}")
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


# Function to extract dynamic SQL expressions code
def extract_dynamic_expressions(sct_code):
    try:
        # Pattern to identify all expressions that begin with var_xxx :=
        pattern = r"var_[A-Za-z]+\s*:=\s[^;]*;"

        matches = re.finditer(pattern, sct_code, re.DOTALL)

        # Dictionary to store extracted dynamic SQL expressions
        dynamic_expressions = {}

        # List of SQL Server DML and keywords
        sql_keywords = ['select', 'insert', 'update', 'delete', 'dateadd', 'datediff', 'convert', 'isnumeric', '+', '#', 'error_message', 'varchar(max)']

        i = 1
        # Iterate through all expressions
        for match in matches:
            block = match.group(0).strip()
            for keyword in sql_keywords:
                if block.lower().find(keyword) != -1:
                    dynamic_expressions[f"action_item_{i}"] = block.strip()
                    i += 1
                    break
                else:
                    continue

        logger.info(f"Successfully extracted dynamic SQL expressions")

        return dynamic_expressions
    
    except ClientError as e:
        logger.error(f"Failed to extract dynamic SQL expressions: {e}")


# Function to prompt LLM model to analyze T-SQL code and recommend PostgreSQL equivalent code
def prompt_llm(bedrock_agent_runtime, agent_id, agent_alias_id, session_id, prompt):

    attempts = 0
    
    while attempts < 3:
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
            attempts += 1
            logger.error(f"Error invoking Bedrock Agent Runtime: {e}")
            logger.info(f"Error submitting the following prompt: {prompt}")
            logger.info(f"Retrying... (Attempt {attempts})")
            time.sleep(5)
    


# Function to parse XML tags from the LLM response and return a dictionary
def extract_xml_tags(content, action_item):
    try:
        # Compile a regular expression to match xml tags
        pattern = r'(?:<([^/][^>]*?)>)(.*?)(?:</\1>)'

        # Find all matches in the content
        matches = re.finditer(pattern, content, re.DOTALL)

        # Create a dictionary to store the extracted tags and their values
        tags = {}
        for match in matches:
            tag_name = match.group(1)
            tag_value = match.group(2)
            tags[tag_name] = tag_value

        tags["sct"] = action_item

        return tags
    
    except Exception as e:
        logger.error(f"Error extracting xml tags from LLM response {content}: {e}")
        raise
        

# Function to search and replace SCT comments
def replace_sct_code(sct_code, llm_response, agent_name):
    # Check if LLM response contains SQL item
    if "sql" in llm_response:
        try:
            sct_comment = llm_response["sct"]
            pg_sql = llm_response["sql"]

            pg_sql = f"""/* GENERATIVE AI CODE BELOW: {agent_name} */ {pg_sql}"""

            # Replace SCT code with PostgreSQL comment
            sct_code = sct_code.replace(sct_comment, pg_sql)

            return sct_code
        
        except Exception as e:
            logger.error(f"Error replacing SCT code with Gen AI code {llm_response}: {e}")
            raise
    else:
        logger.info(f"LLM response does not contain SQL item: {llm_response}")
        return sct_code


# Function to write updated code to file
def write_updated_code(new_code, file_name, agent_name):
    try:
        with open(f"{file_name}", "w") as f:     
            gen_ai_block = False
            number_of_spaces = 1

            for line in new_code.split('\n'):
                # Check if line contains GEN AI comment and get indentation spaces
                gen_ai_comment = line.find(f"/* GENERATIVE AI CODE BELOW: {agent_name} */")

                # Check if line contains semicolon to identify end of block
                end_of_block = line.find(";")
                
                if  gen_ai_comment != -1:
                    # Set start of code block to true
                    gen_ai_block = True
                    # Set the number of spaces to indent
                    number_of_spaces = gen_ai_comment

                    f.writelines("\n")    
                    f.writelines(line)
                    f.writelines("\n")
                elif gen_ai_block == True and gen_ai_comment == -1:
                    # Set the number of spaces to indent
                    spaces = " " * number_of_spaces
                    # Add spaces to line
                    line = f"""{spaces}{line}"""

                    f.writelines(line)
                    f.writelines("\n")

                    # Check if it is the end of the code block
                    if end_of_block != -1:
                        gen_ai_block = False
                else:
                    f.writelines(line)
                    
    except Exception as e:
        logger.error(f"Error writing updates to updated_{file_name}: {e}")


# Function to write updated code to file. Difference with other function is \r\n split
def write_updated_code2(new_code, file_name, agent_name):
    try:
        with open(f"{file_name}", "w") as f:     
            gen_ai_block = False
            number_of_spaces = 1

            new_code = new_code.replace("\n", "\r\n")

            for line in new_code.split('\r\n'):
                # Check if line contains GEN AI comment and get indentation spaces
                gen_ai_comment = line.find(f"/* GENERATIVE AI CODE BELOW: {agent_name} */")

                # Check if line contains semicolon to identify end of block
                end_of_block = line.find(";")
                
                if  gen_ai_comment != -1:
                    # Set start of code block to true
                    gen_ai_block = True
                    # Set the number of spaces to indent
                    number_of_spaces = gen_ai_comment

                    f.writelines("\n")    
                    f.writelines(line)
                    f.writelines("\n")
                elif gen_ai_block == True and gen_ai_comment == -1:
                    # Set the number of spaces to indent
                    spaces = " " * number_of_spaces
                    # Add spaces to line
                    line = f"""{spaces}{line}"""

                    f.writelines(line)
                    f.writelines("\n")

                    # Check if it is the end of the code block
                    if end_of_block != -1:
                        gen_ai_block = False
                else:
                    f.writelines(line)
                    f.writelines("\n")
                    
    except Exception as e:
        logger.error(f"Error writing updates to updated_{file_name}: {e}")

           






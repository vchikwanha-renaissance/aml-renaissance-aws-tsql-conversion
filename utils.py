import re
import time
import logging

from pathlib import Path
from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__) 


# Function to list objects in s3 bucket
def list_s3_objects(s3_client, bucket_name, prefix):

    try:
        response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=prefix)

        # Extract object keys from the response
        object_keys = [obj['Key'] for obj in response.get('Contents', [])]

        logger.info(f"Successfully listed objects in {bucket_name}/{prefix}")

        return object_keys
    
    except ClientError as e:
        logger.error(f"Error listing objects in {bucket_name}/{prefix}: {e}")
        raise
    

# Function to get SCT code from s3
def read_s3_file(s3_client, bucket_name, file_key):

    try:
        response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
        sql = response['Body'].read().decode('utf-8')

        logger.info(f"Successfully read SCT Code from S3: {bucket_name}/{file_key}")

        # Replace SQL Server ERROR_MESSAGE with SQLERRM
        sql = sql.replace("error_catch$ERROR_MESSAGE", "SQLERRM")
        sql = sql.replace("dbo", "public")
        
        return sql
    
    except ClientError as e:
        logger.error(f"Error reading {bucket_name}/{file_key} from S3: {e}")
        raise


# Function to get the structural definition of stored procedure or function
def get_structural_definition(sql_content):
    
    # Define search pattern for input parameter block
    input_param_pattern = r'''
                        create\s+ 
                        (?:procedure|function)
                        \s+[\w[\].]+
                        (.*?)
                        (?:WITH|AS|RETURNS|BEGIN)
                    '''
    
    # Define search pattern for individual input parameters
    param_pattern = r'''
                        @(\w+)
                        \s+
                        ([\w\[\]\(\)\s,]+?)
                        \s*[,\s]
                    '''
    
    create_blocks = re.findall(input_param_pattern, sql_content, re.DOTALL | re.IGNORECASE | re.VERBOSE)

    input_params = []
    for block in create_blocks:
        params = re.finditer(param_pattern, block, re.IGNORECASE | re.VERBOSE)
        for param in params:
            if not re.search(r's\+(OUTPUT|OUT)\s*[,\)]', param.group(0), re.IGNORECASE):
                input_params.append((param.group(1), param.group(2).strip()))
    
    # Define search pattern for variables and temp tables
    variable_pattern = r'declare\s+@(\w+)\s+([\w(\)^table]+)'
    temp_table_pattern = r'create\s+table\s+#([\w]+)'
    temp_table_pattern_2 = r'declare\s+@(\w+)\s+table\s'

    # Find all variables in the SQL file
    variables = re.findall(variable_pattern, sql_content)

    # Find all temp tables in the SQL file
    temp_tables = re.findall(temp_table_pattern, sql_content)
    temp_tables_2 = re.findall(temp_table_pattern_2, sql_content)

    temp_tables_w_prefix = []
    for table in temp_tables:
        temp_tables_w_prefix.append((table, '#'))

    if len(temp_tables_2) >= 1:
        for table in temp_tables_2:
            temp_tables_w_prefix.append((table, '@'))
        

    schema = {
        'Parameters': input_params,
        'Variables': variables,
        'Temp Tables': temp_tables_w_prefix
    }

    return schema


# Function to map SQL Server object names to PostgreSQL object names
def map_object_names(schema, file_name):
    parameters = {}
    variables = {}
    temp_tables = {}

    for key in schema.keys():
        if key == 'Parameters':
            for param in schema[key]:
                name = '@' + param[0]
                parameters[name] = 'par_' + param[0].lower()
        elif key == 'Variables':
            for var in schema[key]:
                name = '@' + var[0]
                variables[name] = 'var_' + var[0]
        elif key == 'Temp Tables':
            for temp in schema[key]:
                if temp[1] == '#':
                    name = '#' + temp[0]
                    temp_tables[name] = 't$' + temp[0].lower()
                elif temp[1] == '@':
                    name = '@' + temp[0]
                    temp_tables[name] = temp[0].lower() + '$' + file_name.split(".")[0].lower()
                
    mapping = {}
    mapping['DB Schema'] = {'dbo': 'public'}
    mapping['Parameters'] = parameters
    mapping['Variables'] = variables
    mapping['Temp Tables'] = temp_tables

    return mapping


# Function to replace MSSQL parameters, variables and temp tables
def replace_variables(sql_content, schema, file_name):

    # Replace input parameters
    for param in schema['Parameters']:
        # replace SQL Server parameters that were not converted by SCT
        sql_content = sql_content.replace('@' + param[0], 'par_' + param[0].lower())
    
    # Replace SQL Server variables
    for var in schema['Variables']:
        var_name = 'var_' + var[0]
        
        # replace SQL Server variables that were not converted by SCT
        if var[1].lower() != 'table':
            sql_content = sql_content.replace('@' + var[0], var_name)

        if var[1].lower() == 'bit':
            # Change parameter data type
            sql_content = sql_content.replace(var_name + ' NUMERIC(1, 0)', var_name + ' BOOLEAN')

            # Change default value for parameter
            sql_content = sql_content.replace(var_name + ' BOOLEAN DEFAULT 0', var_name + ' BOOLEAN DEFAULT FALSE')
            sql_content = sql_content.replace(var_name + ' BOOLEAN DEFAULT 1', var_name + ' BOOLEAN DEFAULT TRUE')

            # Change variable assignments to true or false
            sql_content = sql_content.replace(var_name + ' := 1', var_name + ' := true')
            sql_content = sql_content.replace(var_name + ' := 0', var_name + ' := false')

            sql_content = sql_content.replace(var_name + ' = 1', var_name + ' = true')
            sql_content = sql_content.replace(var_name + ' = 0', var_name + ' = false')

    name_part = file_name.split(".")
    # Replace SQL Server temp table names
    for temp_table in schema['Temp Tables']:
        if temp_table[1] == '#':
            sql_content = sql_content.replace('#' + temp_table[0], 't$' + temp_table[0].lower())
        else:
            sql_content = sql_content.replace('@' + temp_table[0], temp_table[0].lower() + '$' + name_part[0])

    return sql_content


# Function to upload updated code to s3
def upload_s3_file(s3_client, bucket_name, file_key, file_name, content):

    # Define processed file location
    file_dir = Path().cwd().joinpath('processed-files')
    full_file_name = file_dir.joinpath(file_name)

    file_key = file_key + file_name

    try:
        with open(full_file_name, "r") as f:
            content = f.read().encode('utf-8')

            s3_client.put_object(Bucket=bucket_name, Key=file_key, Body=content)

            logger.info(f"Successfully uploaded file to S3: {bucket_name}/{file_key}")

    except FileNotFoundError as e:
        s3_client.put_object(Bucket=bucket_name, Key=file_key, Body=content)

        # If the SQL file doesn't have SCT comments, there would not be a file to read in the local directory
        logger.info(f"SCT comments not found: {e}")

    except ClientError as e:
        logger.error(f"Error uploading {bucket_name}/{file_key} to S3: {e}")
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
            comment_blocks[f"action_item_{i}"] = block.strip()
            i += 1

        logger.info(f"Successfully extracted DMS SC comment blocks")

        return comment_blocks

    except ClientError as e:
        logger.error(f"Failed to extract DMS SC comment blocks: {e}")


# Function to extract T-SQL from SCT comments
def extract_tsql_from_comment(comment_text: str) -> str:
   pattern =  r'/\*\s*\[(\d+)\s*-\s*Severity\s+(\w+)\s*-\s*([^\]]+)\](.*?)\*/'

   matches = re.findall(pattern, comment_text, re.DOTALL)

   for match in matches:   
       tsql = match[3].strip()
    
   return tsql


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
def prompt_llm(bedrock_agent_runtime, agent_name, agent_id, agent_alias_id, session_id, prompt):

    attempts = 0
    
    # Because LLM may time out, attempt to invoke the agent up to 3 times
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

            logger.info(f"Successfully invoked Bedrock agent: {agent_name}")

            return completion

        except ClientError as e:
            attempts += 1
            logger.error(f"Error invoking Bedrock agent {agent_name}: {e}")
            logger.info(f"Error submitting the following prompt: {prompt}")
            logger.info(f"Retrying... (Attempt {attempts})")
            time.sleep(5 * attempts)
    


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
def replace_sct_code(sct_code, llm_response, agent_name, action_item):
    # Check if LLM response contains SQL item
    if "sql" in llm_response:
        try:
            sct_comment = action_item
            pg_sql = llm_response["sql"]

            pg_sql = f"""/* BEGIN GENERATIVE AI CODE BLOCK: {agent_name} */ {pg_sql}/* END GENERATIVE AI CODE BLOCK */"""

            # Replace SCT code with PostgreSQL comment
            sct_code = sct_code.replace(sct_comment, pg_sql)

            return sct_code
        
        except Exception as e:
            logger.error(f"Error replacing SCT code with Gen AI code {llm_response}: {e}")
            raise
    else:
        logger.info(f"Agent response does not contain SQL for: {llm_response}")
        return sct_code


# Function to write updated code to file
def write_updated_code(new_code, file_name, agent_name):
    
    # Create directory for migrated code
    file_dir = Path().cwd().joinpath('processed-files')
    Path.mkdir(file_dir, exist_ok=True)

    full_file_name = file_dir.joinpath(file_name)
    
    try:
        with open(f"{full_file_name}", "w") as f:     
            gen_ai_block = False
            number_of_spaces = 1

            for line in new_code.split('\n'):
                # Check if line contains GEN AI comment and get indentation spaces
                gen_ai_comment = line.find(f"/* BEGIN GENERATIVE AI CODE BLOCK:")

                # Check if line contains semicolon to identify end of block
                end_of_block = line.find("/* END GENERATIVE AI CODE BLOCK */")
                
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


           






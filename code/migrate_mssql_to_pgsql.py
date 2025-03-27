import boto3
import utils
import logging

from botocore.exceptions import ClientError


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# Get bedrock agent runtime and create a session
bedrock_agent_runtime = boto3.client('bedrock-agent-runtime')
response = bedrock_agent_runtime.create_session()
session_id = response['sessionId']


# Get s3 client and get files from bucket
s3_client = boto3.client('s3')

bucket_name = "aml-renaissance-aws-tsql-conversion"
sct_files_prefix = "aws-sct/databases/stars_prod_ci_migration/stored-procedures/"
sct_file_keys = utils.list_s3_objects(s3_client, bucket_name, sct_files_prefix)


for file_key in sct_file_keys:

    if file_key.endswith(".sql"):
        
        # Get file name
        file_name = file_key.split("/")[-1]
        
        # Get SCT code from s3
        sct_code = utils.read_s3_file(s3_client, bucket_name, file_key)

        # Initialize new code variable
        new_sct_code = sct_code

        # Parse SCT code and get all DMS SC comment blocks that contain code that SCT was not able to convert
        comment_blocks = utils.extract_dms_comments(sct_code)

        # Process SCT code agent 
        process_sct_comments_agent_name = "agent-convert-sct-action-items"
        process_sct_comments_agent_id = "QEKGKPJV5J"
        process_sct_comments_agent_alias_id = "U6QIDYS0QV"

        # Define s3 prefix for processed files
        processed_sct_file_key = file_key.replace("aws-sct", process_sct_comments_agent_name)

        # Process SCT comment blocks
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
                                            process_sct_comments_agent_name,
                                            process_sct_comments_agent_id, 
                                            process_sct_comments_agent_alias_id, 
                                            session_id, 
                                            prompt_1)
            
            
            # Extract XML tags from LLM response
            llm_response = utils.extract_xml_tags(llm_response, action_item)
        

            # Update sct code with LLM generated SQL
            try:
                # Replace SCT comments with SQL from LLM
                new_sct_code = utils.replace_sct_code(new_sct_code, 
                                                      llm_response, 
                                                      process_sct_comments_agent_name)

                # Write new code to file
                utils.write_updated_code(new_sct_code, 
                                        file_name, 
                                        process_sct_comments_agent_name)

            except Exception as e:
                logger.info(f"Agent response did not include sql for {action_item}: {e}")
                
                continue  
            

        # Upload processed SCT code to s3
        utils.write_s3_file(s3_client, 
                            bucket_name, 
                            processed_sct_file_key, 
                            file_name,
                            new_sct_code)


        # Parse SCT code and get all DMS SC comment blocks that contain code that SCT was not able to convert
        var_assignments = utils.extract_dynamic_expressions(new_sct_code)


        # Process dynamic SQL agent
        process_dynamic_sql_agent_name = "agent-analyze-dynamic-sql-v2"
        process_dynamic_sql_agent_id = "R8ZNIYI1EF"
        process_dynamic_sql_agent_alias_id = "CJHDM6H7DA"

        # Define s3 prefix for processed files
        processed_dynamic_sql_file_key = file_key.replace("aws-sct", process_dynamic_sql_agent_name)

        for assignment in var_assignments:
            action_item = var_assignments[assignment]

            # Generate prompt values
            prompt_2 = f"""
                The following code snippet is from the {file_name} stored procedure. Give me PostgreSQL 16 equivalent code for the following code snippet:
                {action_item}

                Return the corrected PostgreSQL 16 version of the code snippet enclosed in <sql></sql> tags

                Thoroughly analyze the stored procedure, think it through, step by step. 
                """


            # Get Agent Response
            llm_response = utils.prompt_llm(bedrock_agent_runtime,
                                            process_dynamic_sql_agent_name, 
                                            process_dynamic_sql_agent_id, 
                                            process_dynamic_sql_agent_alias_id, 
                                            session_id, 
                                            prompt_2)

            # Extract XML tags from LLM response
            llm_response = utils.extract_xml_tags(llm_response, action_item)

            # Replace dynamic SQL with LLM SQL
            new_sct_code = utils.replace_sct_code(new_sct_code,
                                                llm_response, 
                                                process_dynamic_sql_agent_name)

            # Write new code to file
            utils.write_updated_code(new_sct_code, 
                                    file_name, 
                                    process_dynamic_sql_agent_name)


        # Upload processed dynamic SQL code to s3
        utils.write_s3_file(s3_client, 
                            bucket_name, 
                            processed_dynamic_sql_file_key, 
                            file_name,
                            new_sct_code)




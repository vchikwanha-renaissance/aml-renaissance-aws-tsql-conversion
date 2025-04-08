import boto3
import utils
import time
import logging

from argparse import ArgumentParser

def main():

    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)

    parser = ArgumentParser(description="Migrate MSSQL to PostgreSQL")
    parser.add_argument("--profile", "-p", help="AWS profile name", default="default")
    parser.add_argument("--bucket", "-b", help="Bucket name", default="aml-renaissance-aws-tsql-conversion")
    parser.add_argument("--source", "-s", help="Source files prefix", default="aws-sct/databases/stars_prod_ci_migration/stored-procedures/")
    parser.add_argument("--destination", "-d", help="Destination files prefix", default="gen-ai/databases/stars_prod_ci_migration/stored-procedures/")
    parser.add_argument("--file", "-f", help="File to migrate", default=".sql")
    
    args = parser.parse_args()
    
    profile = args.profile
    bucket_name = args.bucket
    source_files_prefix = args.source
    destination_files_prefix = args.destination
    sql_file = args.file

    session = boto3.Session(profile_name=profile)

    # Get bedrock agent runtime and create a session
    bedrock_agent_runtime = session.client('bedrock-agent-runtime')
    response = bedrock_agent_runtime.create_session()
    session_id = response['sessionId']


    # Get s3 client and get files from bucket
    s3_client = session.client('s3')

    
    source_file_keys = utils.list_s3_objects(s3_client, bucket_name, source_files_prefix)


    for file_key in source_file_keys:

        if file_key.endswith(f"{sql_file}"):
            
            # Get file name
            file_name = file_key.split("/")[-1]
            
            # Get SCT code from s3
            sct_code = utils.read_s3_file(s3_client, bucket_name, file_key)

            # Set MSSQL code file key
            mssql_file_key = file_key.replace("aws-sct", "ms-sql-server")
            
            # Get MSSQL code from s3
            mssql_code = utils.read_s3_file(s3_client, bucket_name, mssql_file_key)

            # Get structual definition from source SQL Server code i.e, input params, variables and temp tables
            structural_definition = utils.get_structural_definition(mssql_code)

            # Get mapping of SQL Server object names to PostgreSQL object names
            mapping = utils.map_object_names(structural_definition, file_name)

            # Analyze MSSQL code agent
            analyze_mssql_code_agent_name = "agent-analyze-sql-server-code"
            analyze_mssql_code_agent_id = "KZOGIITLJJ"
            analyze_mssql_code_agent_alias_id = "GDMGUMATJY"
            
            # Update SCT variables and BIT data type
            sct_code = utils.replace_variables(sct_code, structural_definition, file_name)

            # Initialize new code variable
            new_sct_code = sct_code

            # Parse SCT code and get all DMS SC comment blocks that contain code that SCT was not able to convert
            comment_blocks = utils.extract_dms_comments(sct_code)

            # Process SCT code agent 
            process_sct_comments_agent_name = "agent-convert-sct-action-items"
            process_sct_comments_agent_id = "QEKGKPJV5J"
            process_sct_comments_agent_alias_id = "OC840SQHQ5"


            # Process SCT comment blocks
            for comment in comment_blocks:
                action_item = comment_blocks[comment]

                # Get T-SQL without comments
                action_item_tsql = utils.extract_tsql_from_comment(action_item)

                prompt_0 = f"""describe what the following code is doing: {action_item_tsql}"""
                
                code_description = utils.prompt_llm(bedrock_agent_runtime, 
                                                    analyze_mssql_code_agent_name,
                                                    analyze_mssql_code_agent_id, 
                                                    analyze_mssql_code_agent_alias_id, 
                                                    session_id, 
                                                    prompt_0)
            

                # Generate prompt for SCT comment block conversion
                prompt_1 = f"""
                    for context, the following is a snippet of code that is in the {file_name} stored procedure:
                    {action_item_tsql}
                    
                    Return the PostgreSQL version of the code snippet enclosed in <sql></sql> tags

                    To guide you, the following is a description of what the T-SQL code is doing and what the PostgreSQL code must do as well: {code_description}

                    Map SQL Server parameters, variables and temp tables to the PostgreSQL object names provided: {mapping}
                    """

                # Prompt the LLM up to 3 times if it does not provide SQL in the response
                attempts = 0
                while attempts < 3:
                    # Get Agent Response
                    llm_response = utils.prompt_llm(bedrock_agent_runtime, 
                                                    process_sct_comments_agent_name,
                                                    process_sct_comments_agent_id, 
                                                    process_sct_comments_agent_alias_id, 
                                                    session_id, 
                                                    prompt_1)
                            
                    
                    # Extract XML tags from LLM response
                    llm_response = utils.extract_xml_tags(llm_response, action_item_tsql)

                    try:
                        sql = llm_response["sql"]
                        break
                    except KeyError as e:
                        attempts += 1
                        logger.info(f"LLM did not provide SQL for the following : {action_item_tsql}")
                        logger.info(f"Retrying... (Attempt {attempts})")
                        time.sleep(5)
            

                # Update sct code with LLM generated SQL
                try:
                    # Replace SCT comments with SQL from LLM
                    new_sct_code = utils.replace_sct_code(new_sct_code,
                                                          llm_response, 
                                                          process_sct_comments_agent_name,
                                                          action_item)

                    # Write new code to file
                    utils.write_updated_code(new_sct_code, 
                                            file_name, 
                                            process_sct_comments_agent_name)

                except Exception as e:
                    logger.info(f"Agent response did not include sql for {action_item_tsql}: {e}")
                    
                    continue  
                

            # Upload processed SCT code to s3
            utils.upload_s3_file(s3_client, 
                                bucket_name, 
                                destination_files_prefix, 
                                file_name,
                                new_sct_code)


            # Parse SCT code and get all variable assignments and search for dynamic sql
            var_assignments = utils.extract_dynamic_expressions(new_sct_code)


            # Process dynamic SQL agent
            process_dynamic_sql_agent_name = "agent-analyze-dynamic-sql-v2"
            process_dynamic_sql_agent_id = "R8ZNIYI1EF"
            process_dynamic_sql_agent_alias_id = "LGITFGYAQR"


            for assignment in var_assignments:
                action_item = var_assignments[assignment]

                # Generate prompt values
                prompt_2 = f"""
                    The following code snippet is from the {file_name} stored procedure. Give me PostgreSQL 16 equivalent code for the following code snippet:
                    {action_item}

                    Evaluate the code snippet and return whether it is a valid PostgreSQL expression or not in <valid></valid>. Use true or false to specify if it is valid or not.
                    Return the corrected PostgreSQL 16 version of the code snippet enclosed in <sql></sql> tags

                    Map SQL Server parameters, variables and temp tables to the PostgreSQL object names provided: {mapping}

                    Thoroughly analyze the code snippet, think it through, step by step. 
                    Provide your feedback in XML tags!!!!
                    """

                dynamic_sql_attempts = 0
                while dynamic_sql_attempts < 3:
                    
                    # Get Agent Response
                    llm_response = utils.prompt_llm(bedrock_agent_runtime,
                                                    process_dynamic_sql_agent_name,
                                                    process_dynamic_sql_agent_id,
                                                    process_dynamic_sql_agent_alias_id,
                                                    session_id,
                                                    prompt_2)
                        
                    # Extract XML tags from LLM response
                    llm_response = utils.extract_xml_tags(llm_response, action_item)

                    if "valid" in llm_response:
                        if llm_response["valid"] == "false":
                            try:
                                # Replace dynamic SQL with LLM SQL
                                new_sct_code = utils.replace_sct_code(new_sct_code,
                                                        llm_response, 
                                                        process_dynamic_sql_agent_name,
                                                        action_item)
                                
                                # Write new code to file
                                utils.write_updated_code(new_sct_code, 
                                            file_name, 
                                            process_dynamic_sql_agent_name)
                                
                                break

                            except KeyError as e:
                                dynamic_sql_attempts += 1
                                logger.info(f"LLM did not provide SQL for the following : {action_item}")
                                logger.info(f"Retrying... (Attempt {dynamic_sql_attempts})")
                                time.sleep(5 * dynamic_sql_attempts)


            # Upload processed dynamic SQL code to s3
            utils.upload_s3_file(s3_client, 
                                bucket_name, 
                                destination_files_prefix, 
                                file_name,
                                new_sct_code)

if __name__ == "__main__":
    main()


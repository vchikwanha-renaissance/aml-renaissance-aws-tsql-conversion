import boto3
import utils
import logging

from argparse import ArgumentParser

def main():

    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)

    parser = ArgumentParser(description="Migrate MSSQL to PostgreSQL")
    parser.add_argument("--profile", "-p", help="AWS profile name", default="default")
    parser.add_argument("--bucket", "-b", help="Bucket name", default="aml-renaissance-aws-tsql-conversion")
    parser.add_argument("--source", "-s", help="Source prefix", default="aws-sct/databases/stars_prod_ci_migration/stored-procedures/")
    parser.add_argument("--destination", "-d", help="Destination prefix", default="aws-sct/databases/stars_prod_ci_migration/stored-procedures/")
    parser.add_argument("--file", "-f", help="File to migrate", default=".sql")
    args = parser.parse_args()
    
    profile = args.profile
    sql_file = args.file
    bucket_name = args.bucket
    sct_files_prefix = args.source

    session = boto3.Session(profile_name=profile)

    # Get bedrock agent runtime and create a session
    bedrock_agent_runtime = session.client('bedrock-agent-runtime')
    response = bedrock_agent_runtime.create_session()
    session_id = response['sessionId']


    # Get s3 client and get files from bucket
    s3_client = session.client('s3')

    
    sct_file_keys = utils.list_s3_objects(s3_client, bucket_name, sct_files_prefix)


    for file_key in sct_file_keys:

        if file_key.endswith(f"{sql_file}"):
            
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
            process_sct_comments_agent_alias_id = "NUTF4DRGCK"

            # Define s3 prefix for processed files
            processed_sct_file_key = file_key.replace("aws-sct", process_sct_comments_agent_name)

            # Process SCT comment blocks
            for comment in comment_blocks:
                action_item = comment_blocks[comment]

                # Generate prompt to get PostgreSQL code
                prompt_1 = f"""
                    The following comment block is a snippet of code that is in the {file_name} stored procedure. Give me PostgreSQL 16 equivalent code for the T-SQL code in the following code snippet:
                    {action_item}

                    Return the corrected PostgreSQL 16 version of the code snippet enclosed in <sql></sql> tags

                    Thoroughly analyze the stored procedure, think it through, step by step. 
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

if __name__ == "__main__":
    main()


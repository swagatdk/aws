# Importing the libraries
import os
import datetime
import csv
import json
import random
import math
import logging
import boto3
import uuid
import faker 
import dicttoxml
from botocore.exceptions import ClientError

# Importing custom modules
from defaults import *

# Setting print level and other varidables
verbose = False
status_code = status_code_success

# Initialising the boto3 client for S3 
s3_client = boto3.client('s3')
 
def write_data(output_rows, output_format, output_folder_location, column_names, called_from = called_from_lambda):
    '''
    Function to write output rows to destination
    '''
    if verbose:
        print("Entry into write_data()")

    try:
        # Create the output file name dynamically to ensure uniqueness within the output_folder_location
        output_file_name = str(uuid.uuid4()) + '.' + output_format        

        # set the path appropirately for local vs lambda execution
        if called_from == called_from_lambda:
            write_path = '/tmp/' + output_file_name
        else:
            write_path = output_file_name

        if verbose:
            print("temporary write_path = " + write_path)     

        # Write the output data into a temp location based on the output format
        if output_format.upper() == "JSON":
            with open(write_path, 'w') as jsonfile:
                json.dump(output_rows, jsonfile)
        elif output_format.upper() == "CSV":
            with open(write_path, 'w', newline='') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames = column_names)
                writer.writeheader()
                for data in output_rows:
                    writer.writerow(data)
        elif output_format.upper() == "XML":            
            xml_bytes = dicttoxml.dicttoxml(output_rows)            
            xml_string = xml_bytes.decode("utf-8")            
            with open(write_path, "w") as xmlfile:
                 xmlfile.write(xml_string)
        else:
            print("Invalid format")
            status_code = status_code_failure 

        if verbose:
            print("Finished writing in temporary location.") 

        # Check if the in output_folder_location is on S3 or not
        # If output location is on S3, use s3 client to move there else move normally
        if output_folder_location.startswith("s3://" or "S3://"):             

            split_path = output_folder_location.replace('s3://', '').split('/', 1)
            bucket_name = split_path[0]
            file_key = split_path[1] + "/" + output_file_name       
            if verbose:
                print("bucket_name = " + bucket_name)  
                print("file_key = " + file_key)     
            s3_client.upload_file(write_path, bucket_name, file_key)            
            os.remove(write_path)
            if verbose:
                print("Finished uploading to s3.")
        else:
            os.rename(write_path, output_folder_location + "/" + output_file_name)
            if verbose:
                print("Finished moving temporary file to destination.")

        return status_code_success
    except Exception as e:
        print(e)
        return status_code_failure    
 
def faker_wrapper(num_rows, locale, output_format, column_names, faker_methods, faker_method_params, null_percent, output_folder_location, called_from = called_from_lambda):
    '''
    Function to take the inputs as variables and generate the output as list of dict
    Each dict is one row
    '''
    if verbose:
        print("Entry into faker_wrapper()")

    output_rows = []
    num_cols = len(column_names)
    fake = faker.Faker(locale)

    if num_rows > 100000:
        print_every = 10000
    elif num_rows > 10000:
        print_every = 5000
    else:
        print_every = 1000

    try: 
        # In a loop generate all rows
        for i in range(num_rows):

            if i > 0 and i % print_every == 0: 
                print (f"Total row = {num_rows}, generated = {i}")

            # For each row, in a loop, generate data for all columns
            output_rows.append({})
            for j in range(num_cols):
                method_to_call = getattr(fake, faker_methods[j])       
                if verbose:
                    print(method_to_call)
                '''if faker_method_params[j]:                    
                    kwargs = eval("{"+faker_method_params[j]+"}")                    
                    result = method_to_call(**kwargs)
                else:  
                    result = method_to_call()'''                
                result = method_to_call()                 
                output_rows[i].update({column_names[j]: result.replace('\n', ' ').replace('\r', '')})    

        if verbose:
            print("First output row = " + str(output_rows[0]))

        # Call write_data with output and destination
        status_code = write_data(output_rows, output_format, output_folder_location, column_names, called_from)
    except Exception as e:
        print(e)
        status_code = status_code_failure  

    return status_code

def data_gen(config_file_location, output_folder_location, called_from = called_from_lambda):
    '''
    Function to take the locations and get the config parameters to call faker_wrapper
    '''
    if verbose:
        print("Entry into data_gen()")

    column_names = []
    faker_methods = []
    faker_method_params = []
    null_percents = []

    # Check if the in config_file_location is on S3 or not
    # If config file is on S3, use s3 client to read the same, else read normally
    if config_file_location.startswith("s3://" or "S3://"):  
        if verbose:
            print("Reading from s3")        

        split_path = config_file_location.replace('s3://', '').split('/', 1)
        bucket_name = split_path[0]
        file_key = split_path[1]        

        if verbose:
            print("bucket_name = " + bucket_name)  
            print("file_key = " + file_key)            

        config_file = s3_client.get_object(Bucket=bucket_name, Key=file_key) 
        if verbose:
            print("Received Config... ")
        config_data = config_file["Body"].read().decode()        
        config_data = json.loads(config_data) 

    else:
        if verbose:
            print("Reading from local")     

        with open(config_file_location, 'r') as config_file:
            config_data = json.load(config_file)            

    # Parse the json to get various config params
    if verbose:
        print("config_data = " + str(config_data))

    num_rows = config_data["num_rows"]    
    try:
        locale = config_data["locale"]
    except Exception:
        locale = default_locale

    try:
        output_format = config_data["output_format"] 
    except Exception:
        output_format = default_output_format  

    for column in config_data["columns"]:        
        column_names.append(column["column_name"])
        faker_methods.append(column["faker_method"])   
        try:
            faker_method_params.append(column["faker_method_param"]) 
        except Exception:
            faker_method_params.append("")
        try:
            null_percents.append(column["null_percent"]) 
        except Exception:
            null_percents.append("")

    if len(column_names) * num_rows > max_cell_limit:
        num_rows = round(max_cell_limit/(len(column_names) + 1))
        print("Reduced the num_rows to " + str(num_rows))

    if num_rows > 0 and output_format.upper() in ['CSV', 'JSON', 'XML'] and len(column_names) > 0 and len(column_names) == len(faker_methods) \
            and len(faker_methods) == len(faker_method_params) and len(column_names) == len(null_percents):
        status_code = faker_wrapper(num_rows, locale, output_format, column_names, faker_methods, faker_method_params, null_percents, output_folder_location, called_from)
    else:
        print("Invalid config parameters")
        print("num_rows = " + str(num_rows))
        print("locale = " + locale)
        print("output_format = " + output_format)
        print("column_names = " + column_names)
        print("faker_methods = " + faker_methods)
        print("faker_method_params = " + faker_method_params)
        print("null_percents = " + str(null_percents))       
        status_code = status_code_failure
    
    return status_code

def lambda_handler(event, context):
    '''
    The lambda handler function to generate bulk data using faker package of python
    Within it's event parameter, it takes two input
        Input 1 : path of the config_file 
        Input 2 : location where the output file would be generated
    Both the locations must follow S3://bucketname/prefix/filename format
    The config file must be in json 
    The generated output can be in json, csv or xml.
    '''
    if verbose:
        print("Entry into lambda_handler()")
        print("Boto3 version = " + boto3.__version__)
        print("Faker version = " + faker.VERSION) 

    # Set the calling point
    called_from = called_from_lambda  

    try:
        # Get the config and output file locations from event
        # Verify both locations are on S3 else throw error message
        config_file_location = event.get("config_file")
        output_folder_location = event.get("output_loc") 

        if verbose:
            print(f"event = {event}")
            print(f"config_file_location = {config_file_location}")
            print(f"output_folder_location = {output_folder_location}")

        if not config_file_location or not config_file_location.upper().endswith('.JSON'):
            print("Invalid config file!")
            raise Exception("Invalid config file!") 

        # Verify both locations are on S3 else return error
        if (config_file_location.startswith("s3://" or "S3://") and output_folder_location.startswith("s3://" or "S3://")):        
            status_code = data_gen(config_file_location, output_folder_location, called_from)                 
        else:
            print("Invalid input; please provide locations on AWS s3")
            status_code = status_code_failure
    except Exception as e:
        print(e)
        status_code = status_code_failure

    if status_code == status_code_success:
        return status_msg_success
    else:
        return status_msg_failure

def main():
    '''
    The main function to generate bulk data locally using faker package of python
    It takes two input
        Input 1 : path of the config_file 
        Input 2 : location where the output file would be generated
    Both the input can be local or in S3. If in S3, both 
    the locations must follow S3://bucketname/prefix/filename format.
    The config file must be in json.
    The generated output can be in json, csv or xml. 
    '''
    if verbose:
        print("Entry into main()")
        print("Boto3 version = " + boto3.__version__)
        print("Faker version = " + faker.VERSION)

    # Set the calling point    
    called_from = called_from_main

    print("Please enter the locations of config file and output folder.")
    print("If locations are on S3, please provide the locations in S3://bucketname/prefix/file_name_with_extn format")

    try:
        config_file_location = input("Enter config file location : ")
        output_folder_location = input("Enter output folder location : ")        

        if not output_folder_location:
            output_folder_location = '.'

        if verbose:
            print(f"config_file_location = {config_file_location}")
            print(f"output_folder_location = {output_folder_location}")

        if not config_file_location or not config_file_location.upper().endswith('.JSON'):
            print("Invalid config file!")
            raise ValueError("Invalid config file!")

        # Call data_gen function with the locations    
        status_code = data_gen(config_file_location, output_folder_location, called_from)
    except Exception as e:
        print(e)
        status_code = status_code_failure

    if status_code == status_code_success:
        print(status_msg_success)
    else:
        print(status_msg_failure)

if __name__ == "__main__":
    main()

# Getting Started

### Build the CodePipeline and Lambda with initial code 

1. Go to Cloudformation 
2. Create stack using template from s3. 
3. Select https://sdk-poc-cf-scripts.s3.ap-south-1.amazonaws.com/codepipeline-for-lambda-deployment/sdk-poc-cp-lambda-cf.yml as the location for template
4. Input sdk-poc-mum-cp-artifacts as s3bucket4artifact 
5. Input sdk-poc-mum-cp-artifacts/codebuild_cache as s3path4cache
6. Input sdk-poc-cf-scripts as s3bucket4initcode
7. Input codepipeline-for-lambda-deployment/sdk-poc-codepipeline-lambda-cf.zip as s3path4initcode
8. Provide the sns topic for notification and 15 minutes for timeout

### Modify the settings for Lambda to run

1. Input codepipeline-for-lambda-deployment/python-bulk-data-gen.zip as s3path4initcode
2. In buildspace.yml modify the bucketname in POST_BUILD as needed
3. In template.yml modify the handler, function name, role arn (account id and role name). security group, subnets as needed
4. Modify the lambda execution role to include other access e.g. s3 full access for this lambda
5. Create a VPC endpoint for s3 and similar as needed 
	

### Run the Lambda

1. Add necessary input in the test event as below
	
		{
		    "config_file": "s3://sdk-poc-all-logs/test.json",
		    "output_loc": "s3://sdk-poc-all-logs/output/lambda"
		}


### Troubleshoot the Lambda 

1. Run the code from desktop as it includes a main method, test both for local config file/output location and s3 config file/ouput location after setting verbose flag to True
2. After fixing the functionality issue, push the code to CodeCommit Repository
3. If access issue on AWS Lambda environment, check cloudwatch log for details after setting verbose flag to True

Local git configuration:
------------------------

1. Install git on windows
2. Configure git with the below global parameters with user.name and user.email suitably modified by using the command --> git config --global <key> <value> 

		credential.helper=!aws.cmd codecommit credential-helper $@
		credential.usehttppath=true
		user.name=Swagata De Khan
		user.email=swagata.dekhan@wipro.com
		push.default=simple
		color.ui=auto

3. Verify git global configuration by using the command --> git config --global --list

Local git commands:
-------------------

1. Initial git command to setup local repo from AWS CodeCommit --> git clone https://git-codecommit.ap-south-1.amazonaws.com/v1/repos/pubnub_tweet_2k
2. Updating the local repo with the latest version in AWS CodeCommit --> git pull origin master
3. Adding all local changes to local repo --> git add -A
4. Committing all changes to local repo --> git commit -m "<description message>"	
5. Pushing local repo changes to AWS CodeCommit --> git push origin master


Note:
-----

This AWS CodeCommit repository is to be accessed with the username <sdk_code_commit-at-982723818678> from local system git clients. 
AWS CodeCommit uses a separate HTTPS Git credentials. The username for the creadentails follow the format <iam login id>-at-<aws account id>
However if there is any special character other than hyphen or underscore in the username, https login to code commit from local system git client does not work.
Hence we can not use any iam login which is an email id with '@' symbal in it. 
Furthermore, do not use the AWS Credential Helper due to version compatibility issues as shown in the above git global configuration.
Use the credential manager provided by windows instead. Those credentials can be managed from 'credentails manager' section of 'windows control panel'.

Build using AWS CodeBuild:
--------------------------

1. Create a build project using Ubuntu/standard/1.0 with the buildspec.yml in the codebase
2. Use S3 cache for dependency caching to speed up the build phase
3. Use appropriate service role with access to S3 cache location
4. Do not use any output artifact since the final target is to push the docker image to ECR
2. Run the build project from AWS Console 	
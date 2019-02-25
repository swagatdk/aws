@echo off
::******************************************************************************
::    AWS VPC Creation DOS Batch Script using AWS CLI
::******************************************************************************
::
:: SYNOPSIS
::    Automates the creation of a custom IPv4 VPC, having in each availability 
::    zone a public jump subnet, a public app subnet and a private data subnet.
::
:: DESCRIPTION
::    This batch script leverages the AWS Command Line Interface (AWS CLI) to
::    automatically create a custom VPC with multiple subnets.  
::    The script assumes the AWS CLI is installed and configured with the 
::    necessary security credentials.
::    Security details are mentioned in the "PreConfig" section below
::
::==============================================================================
::
:: NOTES
::   VERSION:   0.1.0
::   LASTEDIT:  02/25/2019
::   AUTHOR:    Swagata De Khan
::   EMAIL:     swagata.dekhan@yahoo.com
::   REVISIONS:
::       0.1.0  02/25/2019 - first release
::
::==============================================================================
::   PreConfig : Setting up the security details before creating VPC
::==============================================================================
::
:: This should be done in AWS console using root user to save time and effort.
:: If already done, move to next section.
::
:: Set up a new group [awsAdmin] of admin users with AdministratorAccess access 
:: policy attached to it. 
::
:: Create a new user [admin01] belonging to the above group with password and 
:: programmatic access.
::
:: Save the password, access key and secret key for future reference
:: 
:: Configure AWS CLI to use this user with profile name 'admin01' as below 
:: aws configure --profile admin01
:: 	save only the access and secret key, output as json, leave others blank.
::
::==============================================================================
::   MODIFY THE SETTINGS BELOW
::==============================================================================
::
:: AWS Profile to be used in the script
set "AWS_PROFILE=admin01"
::
:: AWS Region in which VPC to be created
set "AWS_REGION=ap-south-1"
::
:: Name of the VPC
set "VPC_NAME=Template VPC"
::
:: Initial 16 bit of CIDR Block reserved for the VPC
set "VPC_CIDR_INIT=10.0"
::
:: Initial Counter for Subnets in CIDR block
set "SUBNET_CIDR_INIT=0"
::
:: Public Jump Subnet Name prefix
set "SUBNET_PUBLIC_JUMP_NAME_PREFIX=pub_jump"
::
:: Public App Subnet Name prefix
set "SUBNET_PUBLIC_APP_NAME_PREFIX=pub_app"
::
:: Private Jump Subnet Name prefix
set "SUBNET_PRIVATE_DATA_NAME_PREFIX=pri_data"
::
::==============================================================================
::   DO NOT MODIFY CODE BELOW
::==============================================================================
::
:: Create CIDR Block for the VPC
SET "VPC_CIDR=%VPC_CIDR_INIT%.0.0/16"
::
:: Create VPC
echo "Creating VPC in preferred region..."
for /f "usebackq tokens=*" %%i in (`aws ec2 create-vpc 
 --cidr-block %VPC_CIDR% --query Vpc.{VpcId:VpcId}
 --output text --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do set VPC_ID=%%i
echo "  VPC ID '%VPC_ID%' created in '%AWS_REGION%' region."
::
:: Add Name tag to VPC
for /f "usebackq tokens=*" %%i in (`aws ec2 create-tags
 --resources %VPC_ID%
 --tags "Key=Name,Value=%VPC_NAME%"
 --region %AWS_REGION% 
 --profile %AWS_PROFILE%`) do echo %%i
echo "  VPC ID '%VPC_ID%' tagged as '%VPC_NAME%'."
::
::==============================================================================
::
:: Create Internet gateway
echo "Creating Internet Gateway..."
for /f "usebackq tokens=*" %%i in (`aws ec2 create-internet-gateway
 --query InternetGateway.{InternetGatewayId:InternetGatewayId} 
 --output text 
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do set IGW_ID=%%i
echo "  Internet Gateway ID '%IGW_ID%' created."
::
:: Attach Internet gateway to your VPC
for /f "usebackq tokens=*" %%i in (`aws ec2 attach-internet-gateway 
 --vpc-id %VPC_ID% --internet-gateway-id %IGW_ID%
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do echo %%i
echo "  Internet Gateway ID '%IGW_ID%' attached to VPC ID '%VPC_ID%'."
::
::==============================================================================
::
:: Create Route Table
echo "Creating Route Table..."
for /f "usebackq tokens=*" %%i in (`aws ec2 create-route-table
 --vpc-id %VPC_ID%
 --query RouteTable.{RouteTableId:RouteTableId}
 --output text 
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do set ROUTE_TABLE_ID=%%i
echo "  Route Table ID '%ROUTE_TABLE_ID%' created."
::
:: Create route to Internet Gateway
for /f "usebackq tokens=*" %%i in (`aws ec2 create-route
 --route-table-id %ROUTE_TABLE_ID%
 --destination-cidr-block 0.0.0.0/0 
 --gateway-id %IGW_ID%
 --output text
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do set RESULT=%%i
echo "  Route to '0.0.0.0/0' via Internet Gateway ID '%IGW_ID%' added to Route Table ID '%ROUTE_TABLE_ID%'."
::
::==============================================================================
::
:: Get all availability zones in the region
for /f "usebackq tokens=*" %%i in (`aws ec2 describe-availability-zones
 --query AvailabilityZones[*].ZoneName --output text
 --region %AWS_REGION% --profile %AWS_PROFILE%`) do set AZ_LIST=%%i
:: echo " List of Availability Zones [%AZ_LIST%]"
::
for %%i in (%AZ_LIST%) do (call:setUpAZ %%i)
goto:eof
::
::==============================================================================
::
:: Configuring subnets in each Availability Zone
::
:setUpAZ
::
set "AZ=%~1"
echo "Configuring Availablity Zone '%AZ%'."
::
:: Set counter appropriately for CIDR blocks
if not defined CTR set "CTR=%SUBNET_CIDR_INIT%"
set /a "CTR=(%CTR%+1)"
echo "CTR = %CTR%"
::
:: Create CIDR subnet qualifier for the JUMP subnet
set /a CIDR_JUMP_SUBNET_QUALIFIER=(%CTR%-1)*3+1
::
:: Create CIDR Block for the JUMP subnet
SET "JUMP_CIDR=%VPC_CIDR_INIT%.%CIDR_JUMP_SUBNET_QUALIFIER%.0/24"
::
:: Create Name for the JUMP subnet
SET "SUBNET_PUBLIC_JUMP_NAME=%SUBNET_PUBLIC_JUMP_NAME_PREFIX%_%AZ%"
::
:: Create Public JUMP Subnet
echo "Creating Public Jump Subnet..."
for /f "usebackq tokens=*" %%i in (`aws ec2 create-subnet
 --vpc-id %VPC_ID% --cidr-block %JUMP_CIDR% 
 --availability-zone %AZ% 
 --query Subnet.{SubnetId:SubnetId} 
 --output text 
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do set SUBNET_PUBLIC_JUMP_ID=%%i
echo "  Subnet ID '%SUBNET_PUBLIC_JUMP_ID%' created in '%AZ%' Availability Zone."
::
:: Add Name tag to Public JUMP Subnet
for /f "usebackq tokens=*" %%i in (`aws ec2 create-tags
 --resources %SUBNET_PUBLIC_JUMP_ID% 
 --tags "Key=Name,Value=%SUBNET_PUBLIC_JUMP_NAME%"
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do echo %%i
echo "  Subnet ID '%SUBNET_PUBLIC_JUMP_ID%' tagged as'%SUBNET_PUBLIC_JUMP_NAME%'."
::
::==============================================================================
::
:: Create CIDR subnet qualifier for the APP subnet
set /a CIDR_APP_SUBNET_QUALIFIER=(%CTR%-1)*3+2
::
:: Create CIDR Block for the APP subnet
SET "APP_CIDR=%VPC_CIDR_INIT%.%CIDR_APP_SUBNET_QUALIFIER%.0/24"
::
:: Create Name for the APP subnet
SET "SUBNET_PUBLIC_APP_NAME=%SUBNET_PUBLIC_APP_NAME_PREFIX%_%AZ%"
::
:: Create Public APP Subnet
echo "Creating Public App Subnet..."
for /f "usebackq tokens=*" %%i in (`aws ec2 create-subnet
 --vpc-id %VPC_ID% --cidr-block %APP_CIDR% 
 --availability-zone %AZ% 
 --query Subnet.{SubnetId:SubnetId} 
 --output text 
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do set SUBNET_PUBLIC_APP_ID=%%i
echo "  Subnet ID '%SUBNET_PUBLIC_APP_ID%' created in '%AZ%' Availability Zone."
::
:: Add Name tag to Public APP Subnet
for /f "usebackq tokens=*" %%i in (`aws ec2 create-tags
 --resources %SUBNET_PUBLIC_APP_ID% 
 --tags "Key=Name,Value=%SUBNET_PUBLIC_APP_NAME%"
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do echo %%i
echo "  Subnet ID '%SUBNET_PUBLIC_APP_ID%' tagged as'%SUBNET_PUBLIC_APP_NAME%'."
::
::==============================================================================
::
:: Create CIDR subnet qualifier for the DATA subnet
set /a CIDR_DATA_SUBNET_QUALIFIER=(%CTR%-1)*3+3
::
:: Create CIDR Block for the DATA subnet
SET "DATA_CIDR=%VPC_CIDR_INIT%.%CIDR_DATA_SUBNET_QUALIFIER%.0/24"
::
:: Create Name for the DATA subnet
SET "SUBNET_PRIVATE_DATA_NAME=%SUBNET_PRIVATE_DATA_NAME_PREFIX%_%AZ%"
::
:: Create Private DATA Subnet
echo "Creating Private Data Subnet..."
for /f "usebackq tokens=*" %%i in (`aws ec2 create-subnet
 --vpc-id %VPC_ID% --cidr-block %DATA_CIDR% 
 --availability-zone %AZ% 
 --query Subnet.{SubnetId:SubnetId} 
 --output text 
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do set SUBNET_PRIVATE_DATA_ID=%%i
echo "  Subnet ID '%SUBNET_PRIVATE_DATA_ID%' created in '%AZ%' Availability Zone."
::
:: Add Name tag to Private DATA Subnet
for /f "usebackq tokens=*" %%i in (`aws ec2 create-tags
 --resources %SUBNET_PRIVATE_DATA_ID% 
 --tags "Key=Name,Value=%SUBNET_PRIVATE_DATA_NAME%"
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do echo %%i
echo "  Subnet ID '%SUBNET_PRIVATE_DATA_ID%' tagged as'%SUBNET_PRIVATE_DATA_NAME%'."
::
::==============================================================================
::
echo "Associating Public Subnets to custom route table ..."
::
:: Associate Public Jump Subnet with Route Table
for /f "usebackq tokens=*" %%i in (`aws ec2 associate-route-table
 --subnet-id %SUBNET_PUBLIC_JUMP_ID%
 --route-table-id %ROUTE_TABLE_ID%
 --query AssociationId
 --output text
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do set RESULT=%%i
echo "  Public Subnet ID '%SUBNET_PUBLIC_JUMP_ID%' associated with Route Table ID '%ROUTE_TABLE_ID%'."
::
:: Associate Public App Subnet with Route Table
for /f "usebackq tokens=*" %%i in (`aws ec2 associate-route-table
 --subnet-id %SUBNET_PUBLIC_APP_ID%
 --route-table-id %ROUTE_TABLE_ID%
 --query AssociationId
 --output text
 --region %AWS_REGION%
 --profile %AWS_PROFILE%`) do set RESULT=%%i
echo "  Public Subnet ID '%SUBNET_PUBLIC_APP_ID%' associated with Route Table ID '%ROUTE_TABLE_ID%'."
::
::==============================================================================
::
goto:eof
::
:dummy
::
echo %~1
::
goto:eof
::
:eof
#!/bin/bash
# Load variables
source ./variables.conf
# Make a Redshift IAM role (Unless default is fine?)

# Make security group for redshift?
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name "glue-redshift-sg" \
    --description "created by script to enable S3 to Redshift pipeline" \
    --vpc-id $VPC_ID \
    --query "GroupId" \
    --output text)

REDSHIFT_IAM_ARN=$(aws iam create-role \
    --role-name RedshiftETLRole \
    --assume-role-policy-document file://redshift-trust-policy.json \
    --query 'Role.Arn' \
    --output text) 

aws iam attach-role-policy \
  --role-name RedshiftETLRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonRedshiftAllCommandsFullAccess

aws iam attach-role-policy \
  --role-name RedshiftETLRole \
  --policy-arn arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess

aws iam attach-role-policy \
  --role-name RedshiftETLRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Create 2 subnets in different AZs, make these user promptable
SUBNET_A_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --availability-zone us-west-1a \
    --cidr-block 10.0.1.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=redshift-subnet-a}]' \
    --query 'Subnet.SubnetId' \
    --output text)

SUBNET_B_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --availability-zone us-west-1b \
    --cidr-block 10.0.2.0/24 \
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=redshift-subnet-b}]' \
    --query 'Subnet.SubnetId' \
    --output text)
        
RTB_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=redshift-rtb}]' \
    --query 'RouteTable.RouteTableId' \
    --output text)

# Might need to create a gateway endpoint here as well and put it in the route table
VPCE_ID=$(aws ec2 create-vpc-endpoint \
    --vpc-id $VPC_ID \
    --vpc-endpoint-type Gateway \
    --service-name com.amazonaws.us-west-1.s3 \
    --route-table-ids $RTB_ID \
    --tag-specifications \
        'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=redshift-s3-gateway-endpoint}]'
    --query 'VpcEndpoint.VpcEndpointId' \
    --output text)

aws ec2 associate-route-table \
    --subnet-id $SUBNET_A_ID \
    --route-table-id $RTB_ID 

aws ec2 associate-route-table \
    --subnet-id $SUBNET_B_ID \
    --route-table-id $RTB_ID 

# Create the serverless redshift namespace and workgroup
aws redshift-serverless create-namespace \
    --namespace-name serverless-ns \
    --db-name dev \
    --admin-username "$REDSHIFT_USER" \
    --admin-user-password "$REDSHIFT_PASS" \
    --iam-roles "$REDSHIFT_IAM_ARN" \
    --default-iam-role-arn "$REDSHIFT_IAM_ARN"

aws redshift-serverless create-workgroup \
    --workgroup-name serverless-wg \
    --namespace-name serverless-ns \
    --base-capacity 32 \
    --subnet-ids $SUBNET_A_ID $SUBNET_B_ID \
    --security-group-ids $SECURITY_GROUP_ID \
    --no-publicly-accessible \
    --no-enhanced-vpc-routing

# The data pipeline script needs these
echo "SUBNET_A_ID=\"$SUBNET_A_ID\"" > ./subnet_sg.conf
echo "SUBNET_B_ID=\"$SUBNET_B_ID\"" >> ./subnet_sg.conf
echo "SECURITY_GROUP_ID=\"$SECURITY_GROUP_ID\"" >> ./subnet_sg.conf

# These are for cleaning up Redshift
echo "REDSHIFT_IAM_ARN=\"$REDSHIFT_IAM_ARN\"" > clean_redshift.conf
echo "REDSHIFT_IAM_NAME=\"${REDSHIFT_IAM_ARN##*/}\"" >> clean_redshift.conf
echo "RTB_ID=\"$RTB_ID\"" >> clean_redshift.conf
echo "VPCE_ID=\"$VPCE_ID\"" >> clean_redshift.conf

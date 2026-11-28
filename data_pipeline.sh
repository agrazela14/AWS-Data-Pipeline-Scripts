#!/bin/bash
source ./variables.conf
source ./subnet_sg.conf

# Create IAM role that can access S3 and Glue
aws iam create-role \
    --role-name Temp-RedshiftTransfer \

aws iam attach-role-policy \
    --role-name Temp-RedshiftTranfser \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy \
    --role-name RedshiftTransfer \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole

# Create temporary S3 Bucket
aws s3 mb s3://temp-bucket --region us-west-1

aws s3api put-object \
    --bucket s3://temp-bucket \
    --key data/ \
    --content-length 0

aws s3api put-object \
    --bucket s3://temp-bucket \
    --key data/uploaded \
    --content-length 0

aws s3api put-object \
    --bucket s3://temp-bucket \
    --key data/crawled \
    --content-length 0

aws s3api put-object \
    --bucket s3://temp-bucket \
    --key temp/ \
    --content-length 0

aws s3api put-object \
    --bucket s3://temp-bucket \
    --key scripts/ \
    --content-length 0

aws s3api put-object \
    --bucket s3://temp-bucket \
    --key /redshift-temp \
    --content-length 0

# Upload stuff to S3
aws s3 cp \
    s3-glue-transfer.py \
    s3://temp-bucket/scripts/

aws s3 cp \
    s3-redshift-transfer.py \
    s3://temp-bucket/scripts/

# The databases you wanna put on there
aws s3 cp \
    s3-glue-data.csv \
    s3://temp-bucket/data/uploaded

### GLUE PART TEST AFTER S3 WORKS ###
## Create Glue DB
#aws glue create-database \
#    --database-input '{
#        "Name": "temp-db"
#    }'
#
## Create crawler from S3 to the database
#aws glue create-crawler \
#    --name s3-temp-crawler
#    --role Temp-RedshiftTransfer 
#    --database-name temp-glue-db
#    --targets '{"S3Targets": [{"Path": "s3://temp-bucket/data/uploaded"}]}'
#
## Run above Crawler
## await the crawler run
#echo "Starting Crawler"
#while true; do
#    STATE=$(aws glue start-crawler
#        --name s3-temp-crawler
#        )
#
#    if ["$STATE" == "READY"]; then
#        break
#    fi
#
#    sleep 5
#done
#echo "Crawler finished"
#
## Create redshift glue connection
#WG_NAME=$(aws redshift-serverless get-workgroup \
#  --workgroup-name <WORKGROUP_NAME> \
#  --query "workgroup.endpoint.address" \
#  --output text)
#
#aws glue create-connection --connection-input "{
#  "Name": "temp-redshift-vpc-conn",
#  "ConnectionType": "JDBC",
#  "ConnectionProperties": {
#      "JDBC_CONNECTION_URL": "jdbc:redshift://$WG_NAME:5439/dev",
#      "USERNAME": "$REDSHIFT_USER"
#      "PASSWORD": "$REDSHIFT_PASS"
#  },
#  "PhysicalConnectionRequirements": {
#    "SubnetId": "${SUBNET_A_ID}",
#    "SecurityGroupIdList": ["${SECURITY_GROUP_ID}"],
#    "AvailabilityZone": "us-west-1a"
#  }
#}"
#
## Create a job to put the table data back into S3 in a different format
#aws glue create-job \
#    --name "glue-to-s3"
#    --role 
#    --command '{
#        "Name": "glueetl"
#        "ScriptLocation": "s3://temp-bucket/data/scripts
#        "PythonVersion:" "3"
#    }' \
#    --default-arguments '{
#        "--job-language": "python",
#        "--db_name": "temp-glue-db"
#        "--table_name": "temp-table"
#        "--s3_output": "s3://temp-bucket/data/crawled"
#    }' \
#    --glue-version "6.0" \
#    --worker-type "G.1X" \
#    --number-of-workers 1
#
## Create a job that triggers off the previous job to put the data from S3 to Redshift
#aws glue create-job \
#    --name "s3-to-redshift" \
#    --role "arn:aws:iam::123456789012:role/AWSGlueServiceRole-ETL" \
#    --connections '{"Connections": ["temp-redshift-connection"]}' \
#    --command '{
#        "Name": "glueetl",
#        "ScriptLocation": "s3://temp-bucket/data/scripts
#        "PythonVersion": "3"
#    }' \
#    --default-arguments '{
#        "--job-language": "python",
#        "--TempDir": "s3://temp-bucket/redshift-temp/",
#        "--temp_dir": "s3://temp-bucket/redshift-temp/",
#        "--s3_input": "s3://temp-bucet/data/crawled/",
#        "--redshift_conn": "temp-redshift-connection",
#        "--redshift_db": "dev",
#        "--redshift_table": "public.target_table"
#    }' \
#    --glue-version "6.0" \
#    --worker-type "G.1X" \
#    --number-of-workers 1
#
#aws glue create-trigger \
#    --name "trigger-s3-to-redshift-on-success" \
#    --type "CONDITIONAL" \
#    --start-on-creation \
#    --predicate '{
#        "Logical": "AND",
#        "Conditions": [
#            {
#                "LogicalOperator": "EQUALS",
#                "JobName": "glue-to-s3",
#                "State": "SUCCEEDED"
#            }
#        ]
#    }' \
#    --actions '[
#      {
#        "JobName": "s3-to-redshift"
#      }
#    ]'
#
#aws glue start-job-run \
#    --job-name "glue-to-s3"
### END GLUE PART ###

# Clean Up

# Delete the IAM Role used by glue
# The Glue Database
# The S3 Bucket
# The Redshift Connection
# The glue jobs
# The glue trigger

# Leave
# The Redshift namespace / workgroup
# The Redshift Security Group
# The Subnets it's on
# The Redshift IAM Role

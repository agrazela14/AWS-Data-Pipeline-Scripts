#!/bin/bash
source subnet_sg.conf
source clean_redshift.conf

# Delete: Subnet A, Subnet B, RTB, VPCE, IAM Role, Redshift ns, Redshift WG
aws ec2 delete-subnet \
    --subnet-id $SUBNET_A_ID

aws ec2 delete-subnet \
    --subnet-id $SUBNET_B_ID

aws ec2 delete-route-table \
    --route-table-id $RTB_ID

aws ec2 delete-vpc-endpoints \
    --vpc-endpoint-ids $VPCE_ID

aws redshift-serverless delete-workgroup \
    --workgroup-name serverless-wg

aws redshift-serverless delete-namespace \
    --namespace-name serverless-ns

aws iam delete-role \
    --role-name $REDSHIFT_IAM_NAME

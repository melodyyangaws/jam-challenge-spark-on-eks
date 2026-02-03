#!/bin/bash -e
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION="${1:-us-east-1}"
aws configure set default.region ${AWS_REGION}
aws configure get default.region
# Deploy CFN via CDK
aws iam create-service-linked-role --aws-service-name eks-nodegroup.amazonaws.com
aws cloudformation deploy \
--stack-name SparkOnEKS \
--template-file /tmp/SparkOnEKS.template \
--s3-bucket sparklab-$ACCOUNT_ID-$AWS_REGION \
--region $AWS_REGION \
--capabilities CAPABILITY_NAMED_IAM

echo "Done"
#!/bin/bash -e


# installing prerequisites
yum update -y
yum install -y jq
mkdir -p /tmp/


rm -vf ${HOME}/.aws/credentials
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region

# Deploy CFN
export BUCKET_NAME=sparklab-$ACCOUNT_ID-$AWS_REGION
STACKID=$(aws cloudformation deploy \
--stack-name SparkOnEKS \
--template-file /tmp/sparkoneks.yaml \
--s3-bucket $BUCKET_NAME \
--region $AWS_REGION \
--capabilities CAPABILITY_NAMED_IAM \
--output text --query StackId)
aws cloudformation wait stack-create-complete --stack-name "${STACKID}"

# Spin up a Cloud9 environment
lab_role=$(aws iam list-roles --query 'Roles[?starts_with(RoleName,`AWSLabsUser-`)==`true`].RoleName' --output text)
echo "role name is ${user_name}"
jam_pubsubnet=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="jam Public Subnet (AZ2)" --query "Subnets[*].SubnetId" --output text)

result=$(aws cloud9 create-environment-ec2 \
--name 'sparklab' \
--description 'command tool to connect to EKS' \
--instance-type t3.small \
--automatic-stop-time-minutes 120 \
--subnet-id ${jam_pubsubnet} \
--image-id amazonlinux-2-x86_64 \
--owner-arn arn:aws:sts::${ACCOUNT_ID}:assumed-role/${lab_role}/team-console --output text)
echo "cloud9 env $result is created"

# Set the output S3 bucket in Athena
app_code_bucket=$(aws s3api list-buckets  --query 'Buckets[?starts_with(Name,`sparkoneks-appcode`)==`true`].Name' --output text)
echo "athena result S3 bucket is ${app_code_bucket}"
aws athena update-work-group \
--region ${AWS_REGION} \
--work-group primary \
--configuration-updates "EnforceWorkGroupConfiguration=true,ResultConfigurationUpdates={OutputLocation=s3://"${app_code_bucket}"/athena-query-result/}"

echo "Done"
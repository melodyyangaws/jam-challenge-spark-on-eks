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
aws cloudformation deploy \
--stack-name SparkOnEKS \
--template-file /tmp/sparkoneks.yaml \
--s3-bucket $BUCKET_NAME \
--region $AWS_REGION \
--capabilities CAPABILITY_NAMED_IAM

# Spin up a Cloud9 environment
user_name=$(aws iam list-roles --query 'Roles[?starts_with(RoleName,`AWSLabsUser-`)==`true`].RoleName' --output text)
echo "role name is ${user_name}"
jam_pubsubnet=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="jam Public Subnet (AZ2)" --query "Subnets[*].SubnetId" --output text)

result=$(aws cloud9 create-environment-ec2 \
--name 'sparklab' \
--description 'command tool to connect to EKS' \
--instance-type t3.small \
--automatic-stop-time-minutes 120 \
--subnet-id ${jam_pubsubnet} \
--image-id amazonlinux-2-x86_64 \
--owner-arn arn:aws:sts::${ACCOUNT_ID}:assumed-role/${user_name}/team-console --output text)
echo "cloud9 env $result is created"

# Set the output S3 bucket in Athena
app_code_bucket=$(aws s3api list-buckets  --query 'Buckets[?starts_with(Name,`sparkoneks-appcode`)==`true`].Name' --output text)
echo "athena result S3 bucket is ${app_code_bucket}"
aws athena update-work-group \
--region ${AWS_REGION} \
--work-group primary \
--configuration-updates "EnforceWorkGroupConfiguration=true,ResultConfigurationUpdates={OutputLocation=s3://"${app_code_bucket}"/athena-query-result/}"

# EMR container IAM execution role
cat <<EoF > emr-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticmapreduce.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EoF

cat <<EoF > EMRContainers-JobExecutionRole.json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::amazon-reviews-pds",
                "arn:aws:s3:::${app_code_bucket}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject"
            ],
            "Resource": [
         "arn:aws:s3:::amazon-reviews-pds/parquet/*",
         "arn:aws:s3:::${app_code_bucket}/*"]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${app_code_bucket}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:PutLogEvents",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*"
            ]
        }
    ]
}  
EoF

aws iam create-role --role-name EMRContainers-JobExecutionRole --assume-role-policy-document file:///emr-trust-policy.json
aws iam put-role-policy --role-name EMRContainers-JobExecutionRole --policy-name EMR-Containers-Job-Execution --policy-document file:///EMRContainers-JobExecutionRole.json
aws emr-containers update-role-trust-policy --cluster-name spark-on-eks --namespace spark --role-name EMRContainers-JobExecutionRole
echo "EMRContainers-JobExecutionRole is created"

# Setup EMR on EKS
echo `aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].Outputs[?starts_with(OutputKey,'eksclusterEKSConfig')].OutputValue" --output text` | bash
echo -e "\nConnect EKS connection..."
kubectl get svc
echo "kubectl create namespace emr"
kubectl create namespace emr 
echo "kubectl create iamidentitymapping"
eksctl create iamidentitymapping --cluster spark-on-eks  --namespace emr --service-name "emr-containers"
echo "aws emr-containers create-virtual-cluster"
aws emr-containers create-virtual-cluster --name emr-demo \
        --container-provider '{
            "id": "spark-on-eks",
            "type": "EKS",
            "info": {
                "eksInfo": {
                    "namespace": "emr"
                }
            }
        }' 
echo "Done"
# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0
#!/bin/bash

export stack_name="${1:-SparkOnEKS}"

# 1. install command line tools 
sudo yum -y -q install jq

echo -e "\nInstall kubectl tool on Linux ..."
# Install kubectl
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.24.16/2023-08-16/bin/linux/amd64/kubectl
chmod +x kubectl
mkdir -p $HOME/bin && mv kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin

# 2. connect to the EKS newly created
echo `aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].Outputs[?starts_with(OutputKey,'eksclusterEKSConfig')].OutputValue" --output text` | bash
echo -e "\nTest EKS connection..."
kubectl get svc

# 3. patch Argo
argo_cm=$(kubectl get cm -n argo | grep controller-configmap | awk '{print $1}')
kubectl patch configmap/$argo_cm -n argo -p '{ "data": { "config": "containerRuntimeExecutor: pns\n" }}'

# 4. Install Jupyter hub in EKS cluster
curl https://raw.githubusercontent.com/helm/helm/HEAD/scripts/get-helm-3 | bash
helm version


# 5. Set the output S3 bucket path to Athena workgroup
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
app_code_bucket=$(aws s3api list-buckets  --query 'Buckets[?starts_with(Name,`sparkoneks-appcode`)==`true`].Name' --output text)
echo "athena result S3 bucket is ${app_code_bucket}"
aws athena update-work-group \
--region ${AWS_REGION} \
--work-group primary \
--configuration-updates "EnforceWorkGroupConfiguration=true,ResultConfigurationUpdates={OutputLocation=s3://"${app_code_bucket}"/athena-query-result/}"


# 6. get Jupyter Hub login
SEC_ID=$(aws secretsmanager list-secrets --query "SecretList[?not_null(Tags[?Value=='$stack_name'])].Name" --output text)
URI=$(kubectl get ingress -n jupyter  -o json | jq '.items[0].status.loadBalancer.ingress[0].hostname')
LOGIN=$(aws secretsmanager get-secret-value --secret-id $SEC_ID --query SecretString --output text)
echo -e "\n=============================== Jupyter Notebook Login =============================================="
echo -e "\nGo to your web browser and type in the Jupyter notebook URL: $URI"
echo "LOGIN: $LOGIN" 
echo "================================================================================================"

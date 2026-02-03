# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0
#!/bin/bash

export stack_name="${1:-SparkOnEKS}"
export AWS_REGION="${2:-us-east-1}"
cd "${HOME}" || exit 1

# 1. install command line tools 
sudo yum -y -q install jq git

echo -e "\nInstall kubectl tool on Linux ..."
# Install kubectl
sudo curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo chmod +x kubectl
sudo mkdir -p /usr/local/bin && sudo mv kubectl /usr/local/bin/kubectl && export PATH=$PATH:/usr/local/bin/
echo "Installed kubectl version: "
kubectl version --client

# 2. connect to the EKS newly created
echo `aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].Outputs[?starts_with(OutputKey,'eksclusterEKSConfig')].OutputValue" --output text` | bash
echo -e "\nTest EKS connection..."
kubectl get svc

# 3. patch Argo
argo_cm=$(kubectl get cm -n argo | grep controller-configmap | awk '{print $1}')
kubectl patch configmap/$argo_cm -n argo -p '{ "data": { "config": "containerRuntimeExecutor: pns\n" }}'

# 4. Install helm
sudo curl https://raw.githubusercontent.com/helm/helm/HEAD/scripts/get-helm-3 | bash
helm version


# 5. Set the output S3 bucket path to Athena workgroup
app_code_bucket=$(aws s3api list-buckets  --query 'Buckets[?starts_with(Name,`sparkoneks-appcode`)==`true`].Name' --output text)
echo "athena result S3 bucket is ${app_code_bucket}"
aws athena update-work-group \
--region ${AWS_REGION} \
--work-group primary \
--configuration-updates "EnforceWorkGroupConfiguration=true,ResultConfigurationUpdates={OutputLocation=s3://"${app_code_bucket}"/athena-query-result/}"

# 6. upload sample data to S3 bucket
mkdir -p data
for month in {01..12}; do
    filename="yellow_tripdata_2021-${month}.parquet"
    echo "Downloading data $filename"
    wget -q -P data/ https://aws-jam-challenge-resources.s3.amazonaws.com/spark-on-eks-made-easy/data/$filename
done
aws s3 sync data s3://$app_code_bucket/data

# 7. get Jupyter Hub login
SEC_ID=$(aws secretsmanager list-secrets --query "SecretList[?not_null(Tags[?Value=='$stack_name'])].Name" --output text)
URI=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `k8s-jupyter`) == `true`].DNSName' --output text)
LOGIN=$(aws secretsmanager get-secret-value --secret-id $SEC_ID --query SecretString --output text)
echo -e "\n=============================== Jupyter Notebook Login =============================================="
echo -e "\nGo to your web browser and type in the Jupyter notebook URL: "
echo -e "\n$URI"
echo -e "\nLOGIN: $LOGIN" 
echo "================================================================================================"

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

# 3. Install Jupyter hub in EKS cluster
curl https://raw.githubusercontent.com/helm/helm/HEAD/scripts/get-helm-3 | bash
helm version

helm repo add jupyterhub https://jupyterhub.github.io/helm-chart
helm repo update

# download config files from JAM
wget https://aws-jam-challenge-resources.s3.amazonaws.com/spark-on-eks-made-easy/jupyter-values.yaml

# replace variables
export AWS_REGION=$(aws configure get region)
export app_code_bucket=$(aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].Outputs[?OutputKey=='CODEBUCKET'].OutputValue" --output text)
sed -i '' -e 's|{{codeBucket}}|"'$app_code_bucket'"|g' jupyter-values.yaml
sed -i '' -e 's|{{region}}|"'$AWS_REGION'"|g' jupyter-values.yaml

# install
helm install jhub jupyterhub/jupyterhub --values jupyter-values.yaml --version 2.0.0 -n jupyter  --create-namespace=False --debug

# 4. get Jupyter Hub login
SEC_ID=$(aws secretsmanager list-secrets --query "SecretList[?not_null(Tags[?Value=='$stack_name'])].Name" --output text)
URI=$(kubectl get ingress -n jupyter  -o json | jq '.items[0].status.loadBalancer.ingress[0].hostname')
LOGIN=$(aws secretsmanager get-secret-value --secret-id $SEC_ID --query SecretString --output text)
echo -e "\n=============================== Jupyter Notebook Login =============================================="
echo -e "\nGo to your web browser and type in the Jupyter notebook URL: $URI"
echo "LOGIN: $LOGIN" 
echo "================================================================================================"

# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0
#!/bin/bash

#!/bin/bash

export stack_name="${1:-SparkOnEKS}"

# 1. install command line tools 
sudo yum -y -q install jq

echo -e "\nInstall kubectl tool on Linux ..."
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.26.4/2023-05-11/bin/darwin/amd64/kubectl

chmod +x kubectl
mkdir -p $HOME/bin && mv kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin

echo -e "\nInstalling eksctl tool on Linux ..."
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version

# 2. connect to the EKS newly created
echo `aws cloudformation describe-stacks --stack-name $stack_name --query "Stacks[0].Outputs[?starts_with(OutputKey,'eksclusterEKSConfig')].OutputValue" --output text` | bash
echo -e "\nTest EKS connection..."
kubectl get svc

# 3. get Jupyter Hub login
LOGIN_URI=$(aws cloudformation describe-stacks --stack-name $stack_name \
--query "Stacks[0].Outputs[?OutputKey=='JUPYTERURL'].OutputValue" --output text)
SEC_ID=$(aws secretsmanager list-secrets --query "SecretList[?not_null(Tags[?Value=='$stack_name'])].Name" --output text)
LOGIN=$(aws secretsmanager get-secret-value --secret-id $SEC_ID --query SecretString --output text)
echo -e "\n=============================== Jupyter Notebook Login =============================================="
echo -e "\nJUPYTER_URL: $LOGIN_URI"
echo "LOGIN: $LOGIN" 
echo "================================================================================================"

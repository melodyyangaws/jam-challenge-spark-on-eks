# AWS Jam Spark on EKS Made Easy
A python CDK v2 project for AWS JAM - Spark on EKS made easy.

## Generate the CFN
```bash
# go to the project directory
git clone git@github.com:melodyyangaws/jam-challenge-spark-on-eks.git
cd jam-challenge-spark-on-eks

# generate a set of CFN templates and lambda functions based on CDK source code
export BUCKET_NAME_PREFIX=aws-jam-challenge-resources
export SOLUTION_NAME=spark-on-eks-made-easy
./deployment/build-s3-dist.sh $BUCKET_NAME_PREFIX $SOLUTION_NAME
# search all of output templates if any memorySize of lambda function is over 512, reduce it to 512. In the same Lambda function, change the pytho3.13 to 3.12.
########################################################
# copy CFN templates to the jam's s3 bucket
cd deployment/global-s3-assets/
aws s3 ls s3://aws-jam-challenge-resources/spark-on-eks-made-easy/
aws s3 sync . s3://aws-jam-challenge-resources/spark-on-eks-made-easy
########################################################
# sync lambda functions to jam. They are regional so above CFN templates map to these files dynamically based on ${AWS_REGION}.
cd ../regional-s3-assets
aws s3 sync . s3://aws-jam-challenge-resources/spark-on-eks-made-easy

# Sync the rest of JAM assets
cd ../../jam_asset
aws s3 sync . s3://aws-jam-challenge-resources/spark-on-eks-made-easy
# Sync other application code to the JAM asset
aws s3 cp ../source/app_resources/jupyter-values.yaml s3://aws-jam-challenge-resources/spark-on-eks-made-easy/jupyter-values.yaml
aws s3 cp ../deployment/post-deployment.sh s3://aws-jam-challenge-resources/spark-on-eks-made-easy/post-deployment.sh
aws s3 cp ../deployment/app_code/job/NYCTaxiCount.py s3://aws-jam-challenge-resources/spark-on-eks-made-easy/NYCTaxiCount.py
```

## Clean up
Run the clean-up script with your CloudFormation stack name.The default name is SparkOnEKS. 
```bash
cd aws-jam-spark-on-eks-made-easy
./deployment/delete_all.sh
```
Go to [CloudFormation console](https://console.aws.amazon.com/cloudformation/home?region=us-east-1), manually delete the remaining resources if needed.

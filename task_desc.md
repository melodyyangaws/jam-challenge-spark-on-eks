### Background

After successfully delivered the new feature earlier than expected, you realised that it is easy to implement Spark on EKS. Importantly, it enables you to unify analytics workload with other business applications, and significantly simplifies your infrastructure management.Therefore, you decide to consolidate other Spark workloads in EMR with the ones created in the EKS cluster. 

Without any Spark application changes, you will use EMR on EKS to redeploy jobs, in order to take the advantage of the faster Spark runtime in EMR than the open source Spark on EKS.
### Task
1. Add your current AWSLabsUser role to the EKS cluster: 
```
kubectl edit -n kube-system configmap/aws-auth
# append it to mapRoles
{"rolearn": "[YOUR_AWSLabsUser_ROLE_ARN]","username":"labuser", "groups":["system:masters"]}
```
2. Register the EKS cluster with EMR:
```
eksctl create iamidentitymapping --cluster spark-on-eks  --namespace spark --service-name "emr-containers"
aws emr-containers create-virtual-cluster \
        --name emr-demo \
		--container-provider '{
            "id": "spark-on-eks",
            "type": "EKS",
            "info": {
                "eksInfo": {
                    "namespace": "spark"
                }
            }
        }' 
```        
3. Submit the exsiting PySpark job stored in `s3://[delta_lake_bucket]/app_code/job/word-count.py` with EMR on EKS.
```
export VIRTUAL_CLUSTER_ID=$(aws emr-containers list-virtual-clusters --query "virtualClusters[?state=='RUNNING'].id" --output text)
export EMR_ROLE_ARN=$(aws iam get-role --role-name EMRContainers-JobExecutionRole --query Role.Arn --output text)
export s3Bucket=$(aws s3api list-buckets  --query 'Buckets[?starts_with(Name,`sparkoneks-appcode`)==`true`].Name' --output text)
aws emr-containers start-job-run \
  --virtual-cluster-id $VIRTUAL_CLUSTER_ID \
  --name word_count \
  --execution-role-arn $EMR_ROLE_ARN \
  --release-label emr-6.2.0-latest \
  --job-driver '{
    "sparkSubmitJobDriver": {
      "entryPoint": "s3://'${s3Bucket}'/app_code/job/wordcount.py","entryPointArguments":["s3://amazon-reviews-pds/parquet/","s3://'${s3Bucket}'/output/"], 
      "sparkSubmitParameters": "--conf spark.executor.instances=20 --conf spark.executor.memory=3G --conf spark.executor.cores=1"}}' \
  --configuration-overrides '{"monitoringConfiguration": {"s3MonitoringConfiguration": {"logUri": "s3://'${s3Bucket}'/emr-eks-logs/"}}}'
 ```
 4. Check the autoscaling status on EKS nodes.
```
kubectl get node
```

### Task Validation
Write down the job exeution time in minutes to answer field. The format is a digit number.
### Background

After successfully delivered the new feature earlier than expected, you realised that it is easy to implement Spark on EKS. Importantly, it enables you to unify analytics workload with other business applications, and significantly simplifies your infrastructure management.Therefore, you decide to consolidate other Spark workloads in EMR with the ones created in the EKS cluster. 

Without any application code changes, you will use the EMR on EKS deployment option to run your EMR jobs on EKS, in order to take advantage of the faster start-up time and responsive autoscaling. 

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
export EMR_EXECUTION_ROLE_ARN=$(aws iam list-roles --query 'Roles[?contains(RoleName,`EMRJobExecRole`)==`true`].Arn' --output text)
export s3Bucket=$(aws s3api list-buckets  --query 'Buckets[?starts_with(Name,`sparkoneks-appcode`)==`true`].Name' --output text)

aws emr-containers start-job-run \
  --virtual-cluster-id $VIRTUAL_CLUSTER_ID \
  --name word_count \
  --execution-role-arn $EMR_EXECUTION_ROLE_ARN \
  --release-label emr-6.5.0-latest \
  --job-driver '{
    "sparkSubmitJobDriver": {
      "entryPoint": "s3://'${s3Bucket}'/app_code/job/wordcount.py","entryPointArguments":["s3://amazon-reviews-pds/parquet/","s3://'${s3Bucket}'/output/"], 
      "sparkSubmitParameters": "--conf spark.executor.instances=20 --conf spark.executor.memory=4G --conf spark.executor.cores=1"}}' \
  --configuration-overrides='{
  	"applicationConfiguration": [
      {
        "classification": "spark-defaults", 
        "properties": {
          "spark.dynamicAllocation.enabled":"true",
          "spark.dynamicAllocation.shuffleTracking.enabled":"true",
          "spark.dynamicAllocation.maxExecutors":"30",
          "spark.dynamicAllocation.executorIdleTimeout": "5s",
          "spark.kubernetes.allocation.batch.size": "15"
         }
      }
    ]
  }'
 ```
 4. Check how quickly EMR on EKS can automatically scale out.
```
kubectl get pod --namespace emr
```

### Task Validation
Write down the App ID to answer field. The ID can be found in 'View logs' from EMR console.
export VIRTUAL_CLUSTER_ID=$(aws emr-containers list-virtual-clusters --query "virtualClusters[?state=='RUNNING'].id" --output text)
export EMR_EXECUTION_ROLE_ARN=$(aws iam list-roles --query 'Roles[?contains(RoleName,`EMRJobExecRole`)==`true`].Arn' --output text)
export s3Bucket=$(aws s3api list-buckets  --query 'Buckets[?starts_with(Name,`sparkoneks-appcode`)==`true`].Name' --output text)

aws emr-containers start-job-run \
  --virtual-cluster-id $VIRTUAL_CLUSTER_ID \
  --name nyc-taxi-vendor-count \
  --execution-role-arn $EMR_EXECUTION_ROLE_ARN \
  --release-label emr-6.10.0-latest \
  --job-driver '{
    "sparkSubmitJobDriver": {
      "entryPoint": "s3://'${s3Bucket}'/NYCTaxiCount.py","entryPointArguments":["s3://dask-data/nyc-taxi/2015/*.csv"], 
      "sparkSubmitParameters": "--conf spark.driver.memory=1G --conf spark.driver.cores=1 --conf spark.executor.memory=8G --conf spark.executor.cores=1"}}' \
  --configuration-overrides='{
  	"applicationConfiguration": [
      {
        "classification": "spark-defaults", 
        "properties": {
          "spark.dynamicAllocation.enabled":"true",
          "spark.dynamicAllocation.shuffleTracking.enabled":"true",
          "spark.dynamicAllocation.maxExecutors":"20",
          "spark.kubernetes.allocation.batch.size": "10",
          "spark.kubernetes.container.image.pullPolicy": "IfNotPresent",
          "spark.kubernetes.driver.label.lifecycle": "OnDemand"
        }
      }
    ]
  }'
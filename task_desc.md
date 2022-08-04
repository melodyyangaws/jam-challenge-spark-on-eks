### Background

You have successfully completed the project tasked by your manager:
* Task #1: Build a Spark ETL in a Jupyter Notebook.
* Task #2: Deploy the notebook-based ETL pipeline to your EKS cluster.

While developing the new data feature, you have grown confident with Spark on EKS. Importantly, you have realized that it enables your organization to consolidate analytics workloads with other business applications, which significantly simplifies infrastructure management and reduces your operational overhead. Your manager is happy with the outcome and would now like you to migrate on-premises Spark workloads to Amazon EKS.

### Your Task

The end goal is to run your job with EMR on EKS, in order to take advantages of:
 1. easy migration with zero Spark code change
 2. fast cluster spin-up time
 3. responsive autoscaling  

To be able to start, you will:
- lift & shift a Spark job to AWS. 
- Test the job by running a native Spark on EKS.
- Finally deploy with EMR on EKS.

### Prerequisites
* Use one of your existing PySpark jobs, or create a sample called `wordcount.py` with the code snippet below, then upload to your appcode S3 bucket.
```
import sys
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName('Amazon reviews word count').getOrCreate()
df = spark.read.parquet(sys.argv[1])
df.selectExpr("explode(split(lower(review_body), ' ')) as words").groupBy("words").count().write.mode("overwrite").parquet(sys.argv[2])
exit()
```
This job counts number of words from Amazon customer review data (50GB) that is stored in a public S3 bucket.

* Get a sample scheduler file for a test run. 
```
wget -q https://aws-jam-challenge-resources.s3.amazonaws.com/spark-on-eks-made-easy/native-spark-job-scheduler.yaml
```
* Download the EMR on EKS job submission script. Change your PySpark file path in S3 accordingly.
```
wget -q https://aws-jam-challenge-resources.s3.amazonaws.com/spark-on-eks-made-easy/submit_emr_on_eks.sh && chmod 744 submit_emr_on_eks.sh
```
### Hints
1. The scheduler template takes S3 bucket name as a parameter set by a Kubernetes object called [configmap](https://kubernetes.io/docs/concepts/configuration/configmap/). Checkout the `kubectl` command below.
2. Test the PySpark job on EKS by [kubectl apply](https://jamesdefabia.github.io/docs/user-guide/kubectl/kubectl_apply/) the scheduler template. 
3. Observe how fast can the Spark cluster scale from 0 to 30 executors. Check out  the `kubectl` commands below.
4. Once the test is up running, deploy the same job to EMR on EKS, with equivalent Spark settings.

### Useful kubectl command
- dynamic variable mapping - `kubectl create configmap special-config -n spark --from-literal=appcodeBucket=[YOUR_S3BUCKET]`
- Monitor Spark on EKS job - `kubectl get pod --namespace spark`
- Observe EMR on EKS job - `kubectl get pod --namespace emr`

### AWS Services You Use
- [AWS Cloud9](https://console.aws.amazon.com/cloud9)
- [Amazon EKS](https://console.aws.amazon.com/eks)
- [Amazon S3](https://console.aws.amazon.com/s3)
- [Amazon EMR](https://console.aws.amazon.com/elasticmapreduce)

### Task Validation
Write down your EMR on EKS App ID to answer field. The ID can be found from 'View logs' on [EMR's Virtual clusters console](https://console.aws.amazon.com/elasticmapreduce).


#clue3:
##Find the label name
- Go to [EMR console](https://console.aws.amazon.com/elasticmapreduce)
- Click the `emr-on-eks-demo` Virtual Clusters
- Click on `View Logs`
- The App ID is displayed on the application page of the Spark webUI
#clue 4:
##if still can't find the App ID, here is a short cut:
run the command:
```
export VIRTUAL_CLUSTER_ID=$(aws emr-containers list-virtual-clusters --query "virtualClusters[?state=='RUNNING'].id" --output text)
export JOB_ID=$(aws emr-containers list-job-runs --max-items 1 --virtual-cluster-id $VIRTUAL_CLUSTER_ID --query "jobRuns[].id" --output yaml)
echo "The App ID is the $JOB_ID" | sed -e "s/- /spark-/"
```
#validation function

```python3
import boto3

def preprocess_input(text):
  text = text.strip() # remove surrounding spaces
  return ''.join(i for i in text if ord(i)<128 and ord(i)>31) # remove all non-ascii and non-printable characters

def get_job_id():
  emr = boto3.client('emr-containers')
  response = emr.list_virtual_clusters(
    containerProviderId='spark-on-eks',
    containerProviderType='EKS',
    states=['RUNNING']
  )
  job_list = list()
  for virtual_cluster in response['virtualClusters']:
    print(f"the virtual cluster id is:{virtual_cluster['id']}")
    res = emr.list_job_runs(virtualClusterId=virtual_cluster['id'])
    for job in res['jobRuns']:
    	job_list.append(job['id'])
        
    print(f"the job id list is:{job_list}")
    return(job_list)
  
def lambda_handler(event, context):

  # Available data provided in the event
  eventTitle = event.get("eventTitle", None)
  challengeTitle = event.get("challengeTitle", None)
  taskTitle = event.get("taskTitle", None)
  teamDisplayName = event.get("teamDisplayName", None)
  userInput = preprocess_input(event.get("userInput", ""))
  if len(userInput) > 100: # oversized input
    return {
      "completed": False, # required: whether this task is completed
      "message": 'Your response seems to have too many characters, please try again', # required: a message to display to the team indicating progress or next steps
      "progressPercent": 0, # optional: any whole number between 0 and 100
      "metadata": {}, # optional: a map of key:value attributes to display to the team
    }
  job_id_list=get_job_id()
  print(f"input:{userInput}")
  for id in job_id_list:
    if userInput.lower() == "spark-"+id.lower():
      print(f"the answer is:{id}")
      message = f"Good Job! The answer is correct"
      return {
        "completed": True, # required: whether this task is completed
        "message": message, # required: a message to display to the team indicating progress or next steps
        "progressPercent": 0, # optional: any whole number between 0 and 100
        "metadata": {}, # optional: a map of key:value attributes to display to the team
      }

  message = f"{userInput} is not correct, try again"
  return {
    "completed": False, # required: whether this task is completed
    "message": message, # required: a message to display to the team indicating progress or next steps
    "progressPercent": 0, # optional: any whole number between 0 and 100
    "metadata": {}, # optional: a map of key:value attributes to display to the team
  }
  ```
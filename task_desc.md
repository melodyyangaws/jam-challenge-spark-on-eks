### Background

After successfully delivered the new feature earlier than expected, you realised that it is easy to implement Spark on EKS. Importantly, it enables you to unify analytics workload with other business applications, and significantly simplifies your infrastructure management.Therefore, you decide to consolidate other Spark workloads in EMR with the ones created in the EKS cluster. 

Without any application code changes, you will use the EMR on EKS deployment option to run your EMR jobs on EKS, in order to take advantage of the faster start-up time and responsive autoscaling. 

### Task
1. Download the EMR on EKS submission file and correct the S3 file path by pointing to your wordcount.py script.
```
wget -q https://aws-jam-challenge-resources.s3.amazonaws.com/spark-on-eks-made-easy/submit_emr_on_eks.sh
```
3. Without any code change, submit your wordcount job to EMR on EKS.
```
./submit_emr_on_eks.sh
 ```
 4. Check how quickly EMR on EKS can autoscale.
```
kubectl get pod --namespace emr
```

### Task Validation
Write down the App ID to answer field. The ID can be found from 'View logs' on EMR console.
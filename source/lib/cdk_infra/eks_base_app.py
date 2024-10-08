# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0
from aws_cdk import Aws
from constructs import Construct
from aws_cdk.aws_eks import ICluster
from lib.util.manifest_reader import *
import os

class EksBaseAppConst(Construct):
    @property
    def alb_created(self):
        return self._alb

    def __init__(self,scope: Construct, id: str, eks_cluster: ICluster, **kwargs,) -> None:
        super().__init__(scope, id, **kwargs)

        source_dir=os.path.split(os.environ['VIRTUAL_ENV'])[0]+'/source'
        
        # Add ALB ingress controller to EKS
        self._alb = eks_cluster.add_helm_chart('ALBChart',
            chart='aws-load-balancer-controller',
            repository='https://aws.github.io/eks-charts',
            release='alb',
            version='1.4.8',
            create_namespace=False,
            namespace='kube-system',
            values=load_yaml_replace_var_local(source_dir+'/app_resources/alb-values.yaml',
                fields={
                    "{{region_name}}": Aws.REGION, 
                    "{{cluster_name}}": eks_cluster.cluster_name, 
                    "{{vpc_id}}": eks_cluster.vpc.vpc_id
                }
            )
        )
        # Add Cluster Autoscaler to EKS
        _var_mapping = {
            "{{region_name}}": Aws.REGION, 
            "{{cluster_name}}": eks_cluster.cluster_name, 
        }
        eks_cluster.add_helm_chart('ClusterAutoScaler',
            chart='cluster-autoscaler',
            repository='https://kubernetes.github.io/autoscaler',
            release='nodescaler',
            create_namespace=False,
            namespace='kube-system',
            values=load_yaml_replace_var_local(source_dir+'/app_resources/autoscaler-values.yaml',_var_mapping)
        )

        # Add external secrets controller to EKS
        eks_cluster.add_helm_chart('SecretContrChart',
            chart='kubernetes-external-secrets',
            repository='https://external-secrets.github.io/kubernetes-external-secrets/',
            release='external-secrets',
            create_namespace=False,
            namespace='kube-system',
            values=load_yaml_replace_var_local(source_dir+'/app_resources/ex-secret-values.yaml',
                fields={
                    '{{region_name}}': Aws.REGION
                }
            )
        )
        # Add Spark Operator to EKS
        eks_cluster.add_helm_chart('SparkOperatorChart',
            chart='spark-operator',
            repository='https://kubeflow.github.io/spark-operator',
            release='spark-operator',
            version='1.1.27',
            create_namespace=True,
            values=load_yaml_replace_var_local(source_dir+'/app_resources/spark-operator-values.yaml',fields={'':''})
        )
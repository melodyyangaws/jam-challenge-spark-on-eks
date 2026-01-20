# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0

from aws_cdk import aws_iam as iam
from constructs import Construct
from aws_cdk.aws_secretsmanager import ISecret
from aws_cdk.aws_eks import ICluster
from lib.util.manifest_reader import *
import os

class EksSAConst(Construct):

    def __init__(self,scope: Construct, id:str, eks_cluster: ICluster, secret: ISecret, **kwargs,) -> None:
        super().__init__(scope, id, **kwargs)

# //************************************v*************************************************************//
# //***************************** SERVICE ACCOUNT, RBAC and IAM ROLES *******************************//
# //****** Associating IAM role to K8s Service Account to provide fine-grain security control ******//
# //***********************************************************************************************//
        source_dir=os.path.split(os.environ['VIRTUAL_ENV'])[0]+'/source'
         
        # ALB Ingress - Create first since other components depend on it
        self._alb_sa = eks_cluster.add_service_account('ALBServiceAcct',
            name='alb-aws-load-balancer-controller',
            namespace='kube-system'
        )
        _alb_role = load_yaml_local(source_dir+'/app_resources/alb-iam-role.yaml')
        for statmt in _alb_role:
            self._alb_sa.add_to_principal_policy(iam.PolicyStatement.from_json(statmt))

        # Cluster Auto-scaler - Create after ALB to serialize operations
        self._scaler_sa = eks_cluster.add_service_account('AutoScalerSa', 
            name='cluster-autoscaler', 
            namespace='kube-system'
        )  
        self._scaler_sa.node.add_dependency(self._alb_sa)
        _scaler_role = load_yaml_local(source_dir+'/app_resources/autoscaler-iam-role.yaml')
        for statmt in _scaler_role:
            self._scaler_sa.add_to_principal_policy(iam.PolicyStatement.from_json(statmt))

        # External secret controller - Create last to serialize operations
        self._secrets_sa = eks_cluster.add_service_account('ExSecretController',
            name='external-secrets-controller',
            namespace="kube-system"
        )
        self._secrets_sa.node.add_dependency(self._scaler_sa)
        _secrets_role = load_yaml_replace_var_local(source_dir+'/app_resources/ex-secret-iam-role.yaml',
                        fields={"{{secretsmanager}}": secret.secret_arn+"*"}
                    )
        for statmt in _secrets_role:
            self._secrets_sa.add_to_principal_policy(iam.PolicyStatement.from_json(statmt))

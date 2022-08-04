# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0

from aws_cdk import (CfnJson, Aws, aws_iam as iam,aws_emrcontainers as emrc)
from constructs import Construct
from aws_cdk.aws_eks import ICluster, KubernetesManifest
from lib.util.manifest_reader import load_yaml_replace_var_local
import os

class SparkOnEksSAConst(Construct):

    @property
    def jupyter_sa(self):
        return self._jupyter_sa.service_account_name

    def __init__(self,scope: Construct, id: str, 
        eks_cluster: ICluster, 
        login_name: str, 
        code_bucket: str,
        **kwargs,) -> None:
        super().__init__(scope, id, **kwargs)

# //******************************************************************************************//
# //************************ SETUP PERMISSION FOR ARC SPARK JOBS ****************************//
# //******* create k8s namespace, service account, and IAM role for service account ********//
# //***************************************************************************************//
        source_dir=os.path.split(os.environ['VIRTUAL_ENV'])[0]+'/source'

        # create k8s namespace
        etl_ns = eks_cluster.add_manifest('SparkNamespace',{
                "apiVersion": "v1",
                "kind": "Namespace",
                "metadata": { 
                    "name": "spark",
                    "labels": {"name":"spark"}
                }
            }
        )
        jupyter_ns = eks_cluster.add_manifest('jhubNamespace',{
                "apiVersion": "v1",
                "kind": "Namespace",
                "metadata": { 
                    "name": "jupyter",
                    "labels": {"name":"spark"}
                }
            }
        )    
    
        # create k8s service account
        self._etl_sa = eks_cluster.add_service_account('ETLSa', 
            name='arcjob', 
            namespace='spark'
        )
        self._etl_sa.node.add_dependency(etl_ns)

        _etl_rb = KubernetesManifest(self,'ETLRoleBinding',
            cluster=eks_cluster,
            manifest=load_yaml_replace_var_local(source_dir+'/app_resources/etl-rbac.yaml', 
            fields= {
                "{{MY_SA}}": self._etl_sa.service_account_name
            }, 
            multi_resource=True)
        )
        _etl_rb.node.add_dependency(self._etl_sa)

        self._jupyter_sa = eks_cluster.add_service_account('jhubServiceAcct', 
            name=login_name,
            namespace='jupyter'
        )
        self._jupyter_sa.node.add_dependency(jupyter_ns)

        # Associate AWS IAM role to K8s Service Account
        _bucket_setting={
                "{{codeBucket}}": code_bucket
        }
        _etl_iam = load_yaml_replace_var_local(source_dir+'/app_resources/etl-iam-role.yaml',fields=_bucket_setting)
        for statmnt in _etl_iam:
            self._etl_sa.add_to_principal_policy(iam.PolicyStatement.from_json(statmnt))
            self._jupyter_sa.add_to_principal_policy(iam.PolicyStatement.from_json(statmnt))

# # //*************************************************************************************//
# # //******************** SETUP PERMISSION FOR NATIVE SPARK JOBS   **********************//
# # //***********************************************************************************//
        self._spark_sa = eks_cluster.add_service_account('NativeSparkSa',
            name='nativejob',
            namespace='spark'
        )
        self._spark_sa.node.add_dependency(etl_ns)

        _spark_rb = eks_cluster.add_manifest('sparkRoleBinding',
            load_yaml_replace_var_local(source_dir+'/app_resources/native-spark-rbac.yaml',
                fields= {
                    "{{MY_SA}}": self._spark_sa.service_account_name
                })
        )
        _spark_rb.node.add_dependency(self._spark_sa)

        _native_spark_iam = load_yaml_replace_var_local(source_dir+'/app_resources/native-spark-iam-role.yaml',fields=_bucket_setting)
        for statmnt in _native_spark_iam:
            self._spark_sa.add_to_principal_policy(iam.PolicyStatement.from_json(statmnt))

        # ########################################
        # #######                          #######
        # #######     EMR on EKS Assets    #######
        # #######                          #######
        # ########################################
        # _emr_01_name = "emr"
        # emr_ns = eks_cluster.add_manifest('EMRNamespace',{
        #         "apiVersion": "v1",
        #         "kind": "Namespace",
        #         "metadata": { 
        #             "name":  _emr_01_name,
        #             "labels": {"name": _emr_01_name}
        #         }
        #     }
        # ) 
        # # k8s rbac for EMR on EKS
        # _emr_rb = KubernetesManifest(self,'EMRRoleBinding',
        #     cluster=eks_cluster,
        #     manifest=load_yaml_replace_var_local(source_dir+'/app_resources/emr-rbac.yaml', 
        #     fields= {
        #         "{{NAMESPACE}}": _emr_01_name,
        #     }, 
        #     multi_resource=True)
        # )
        # _emr_rb.node.add_dependency(emr_ns)
        
        # # EMR on EKS Execution Role 
        # self._emr_exec_role = iam.Role(self, "EMRJobExecRole", assumed_by=iam.ServicePrincipal("eks.amazonaws.com"))
        
        # # trust policy
        # _eks_oidc_provider=eks_cluster.open_id_connect_provider 
        # _eks_oidc_issuer=_eks_oidc_provider.open_id_connect_provider_issuer 
         
        # sub_str_like = CfnJson(self, "ConditionJsonIssuer",
        #     value={
        #         f"{_eks_oidc_issuer}:sub": f"system:serviceaccount:{_emr_01_name}:emr-containers-sa-*-*-{Aws.ACCOUNT_ID}-*"
        #     }
        # )
        # self._emr_exec_role.assume_role_policy.add_statements(
        #     iam.PolicyStatement(
        #         effect=iam.Effect.ALLOW,
        #         actions=["sts:AssumeRoleWithWebIdentity"],
        #         principals=[iam.OpenIdConnectPrincipal(_eks_oidc_provider, conditions={"StringLike": sub_str_like})])
        # )

        # aud_str_like = CfnJson(self,"ConditionJsonAudEMR",
        #     value={
        #         f"{_eks_oidc_issuer}:aud": "sts.amazon.com"
        #     }
        # )
        # self._emr_exec_role.assume_role_policy.add_statements(
        #     iam.PolicyStatement(
        #         effect=iam.Effect.ALLOW,
        #         actions=["sts:AssumeRoleWithWebIdentity"],
        #         principals=[iam.OpenIdConnectPrincipal(_eks_oidc_provider, conditions={"StringEquals": aud_str_like})]
        #     )
        # )

        # # associate IAM Roles to EMR on EKS Service Accounts 
        # for statmnt in _etl_iam:
        #     self._emr_exec_role.add_to_policy(iam.PolicyStatement.from_json(statmnt))

        # # create EMR virtual Cluster Server
        # self.emr_vc = emrc.CfnVirtualCluster(self,"EMRVC",
        #     container_provider=emrc.CfnVirtualCluster.ContainerProviderProperty(
        #         id=eks_cluster.cluster_name,
        #         info=emrc.CfnVirtualCluster.ContainerInfoProperty(eks_info=emrc.CfnVirtualCluster.EksInfoProperty(namespace=_emr_01_name)),
        #         type="EKS"
        #     ),
        #     name="emr-on-eks-demo"
        # )
        # self.emr_vc.node.add_dependency(self._emr_exec_role)
        # self.emr_vc.node.add_dependency(_emr_rb)     
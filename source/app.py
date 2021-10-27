# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0

#!/usr/bin/env python3
from aws_cdk import core
from lib.spark_on_eks_stack import SparkOnEksStack
from lib.cloud_front_stack import NestedStack

app = core.App()
eks_name = app.node.try_get_context('cluster_name')
eks_stack = SparkOnEksStack(app, 'SparkOnEKS', eks_name)
# The CloudFront offers a default domain name to enable HTTPS.
# Recommend to issue a TLS certificate with your own domain, delete the CF nested stack 
cf_nested_stack = NestedStack(eks_stack,'CreateCloudFront', eks_stack.code_bucket, eks_stack.jhub_url)

core.Tags.of(eks_stack).add('project', 'sqlbasedetl')
core.Tags.of(cf_nested_stack).add('project', 'sqlbasedetl')

# Deployment Output
core.CfnOutput(eks_stack,'CODE_BUCKET', value=eks_stack.code_bucket)
core.CfnOutput(eks_stack,'JUPYTER_URL', value='https://'+ cf_nested_stack.jhub_cf)

app.synth()

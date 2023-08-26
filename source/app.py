# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0

#!/usr/bin/env python3
from aws_cdk import (App,Tags,CfnOutput)
from lib.spark_on_eks_stack import SparkOnEksStack

app = App()
eks_name = app.node.try_get_context('cluster_name')
eks_stack = SparkOnEksStack(app, 'SparkOnEKS', eks_name)

Tags.of(eks_stack).add('project', 'sqlbasedetl')

# Deployment Output
CfnOutput(eks_stack,'CODE_BUCKET', value=eks_stack.code_bucket)
#CfnOutput(eks_stack,'JUPYTER_URL', value='https://'+ cf_nested_stack.jhub_cf)

app.synth()

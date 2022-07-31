# // Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# // SPDX-License-Identifier: MIT-0

from aws_cdk import (Tags, aws_ec2 as ec2)
from constructs import Construct

class NetworkSgConst(Construct):

    @property
    def vpc(self):
        return self._vpc

    def __init__(self,scope: Construct, id:str, eksname:str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)
        
        # //*************************************************//
        # //******************* NETWORK ********************//
        # //************************************************//
        # create VPC
        self._vpc = ec2.Vpc(self, 'eksVpc',max_azs=2,nat_gateways=1)
        Tags.of(self._vpc).add('Name', eksname + 'EksVpc')
#
# Cookbook Name:: netapp_ontap_cloud
# Attributes:: ontap_cloud
#
# Copyright (c) 2017 Exosphere Data LLC, All Rights Reserved.

# ONTAP Options
default['ontap_cloud']['ontap']['standalone']['name'] = nil
default['ontap_cloud']['ontap']['standalone']['ebs_type'] = 'gp2'
default['ontap_cloud']['ontap']['standalone']['size'] = '1TB'
default['ontap_cloud']['ontap']['standalone']['instance_type'] = 'm4.xlarge'
default['ontap_cloud']['ontap']['standalone']['license_type'] = 'cot-explore-paygo'
default['ontap_cloud']['ontap']['standalone']['write_speed'] = nil

default['ontap_cloud']['ontap']['standalone']['aggregate']['name'] = nil
default['ontap_cloud']['ontap']['standalone']['aggregate']['disk_count'] = nil
default['ontap_cloud']['ontap']['standalone']['aggregate']['size'] = node['ontap_cloud']['ontap']['standalone']['size']
default['ontap_cloud']['ontap']['standalone']['aggregate']['ebs_type'] = node['ontap_cloud']['ontap']['standalone']['ebs_type']

# AWS Options
default['ontap_cloud']['aws']['vpc_id'] = nil
default['ontap_cloud']['aws']['region'] = nil
default['ontap_cloud']['aws']['subnet_id'] = nil

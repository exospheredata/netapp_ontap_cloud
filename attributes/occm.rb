#
# Cookbook Name:: netapp_ontap_cloud
# Attributes:: occm
#
# Copyright (c) 2017 Exosphere Data LLC, All Rights Reserved.

default['occm']['server'] = 'localhost'
default['occm']['company_name'] = nil
default['occm']['tenant_name'] = 'Default Tenant'

default['occm']['installer'] = nil # HTTP path to download OCCM Installer
default['occm']['install_pkg'] = false

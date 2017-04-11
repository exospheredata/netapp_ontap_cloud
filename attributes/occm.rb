#
# Cookbook Name:: netapp_ontap_cloud
# Attributes:: occm
#
# Copyright (c) 2017 Exosphere Data LLC, All Rights Reserved.

default['occm']['server'] = 'localhost'
default['occm']['user']['email_address'] = nil
default['occm']['user']['password'] = nil
default['occm']['company_name'] = nil

default['occm']['installer'] = nil # HTTP path to download OCCM Installer

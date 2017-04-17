#
# Cookbook:: netapp_ontap_cloud
# Recipe:: ontap_cloud_aws_standalone_delete
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

netapp_ontap_cloud_ontap_aws 'Remove ONTAP Cloud' do
  server node['occm']['server']
  occm_user node['occm']['user']['email_address']
  occm_password node['occm']['user']['password']
  ontap_name node['ontap_cloud']['ontap']['standalone']['name']
  wait_execution true
  action :delete
end

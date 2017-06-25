#
# Cookbook:: netapp_ontap_cloud_test
# Recipe:: ontap_cloud
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

netapp_ontap_cloud_ontap_aws 'Setup ONTAP Cloud' do
  server 'localhost'
  occm_user 'test@lab.test'
  occm_password 'netapp123'
  ontap_name node['ontap_cloud_test']['ontap']['standalone']['name']
  tenant_name 'Default Tenant'
  svm_password 'netapp123'
  region node['ontap_cloud_test']['aws']['region']
  vpc_id node['ontap_cloud_test']['aws']['vpc_id']
  subnet_id node['ontap_cloud_test']['aws']['subnet_id']
  bypass_snapshot true
  write_speed node['ontap_cloud_test']['ontap']['standalone']['write_speed']
  action :create
end

netapp_ontap_cloud_ontap_aws 'Update Write Speed' do
  server 'localhost'
  occm_user 'test@lab.test'
  occm_password 'netapp123'
  ontap_name node['ontap_cloud_test']['ontap']['standalone']['name']
  write_speed 'high'
  action :set_write_speed
end

netapp_ontap_cloud_ontap_aws 'Remove ONTAP Cloud' do
  server 'localhost'
  occm_user 'test@lab.test'
  occm_password 'netapp123'
  ontap_name 'old_demolab'
  action :delete
end

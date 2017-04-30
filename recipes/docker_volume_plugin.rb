#
# Cookbook:: netapp_ontap_cloud
# Recipe:: docker_volume_plugin
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

begin
  occm_admin = data_bag_item('occm', 'admin_credentials')
rescue StandardError
  raise "('The DataBagItem(\'occm\', \'admin_credentials\') was not found.  Unable to set the admin credentials"
end

begin
  ontap_admin = data_bag_item('occm', node['ontap_cloud']['ontap']['standalone']['name'])
rescue StandardError
  raise "The DataBagItem(\'occm\', \'#{node['ontap_cloud']['ontap']['standalone']['name']}\') was not found.  Unable to set the ONTAP credentials"
end

netapp_ontap_cloud_ndvp node['ontap_cloud']['ontap']['standalone']['name'] do
  server node['occm']['server']
  occm_user occm_admin['email_address']
  occm_password occm_admin['password']
  tenant_name 'Default Tenant'
  svm_password ontap_admin['svm_password']
  action [:config, :install]
end

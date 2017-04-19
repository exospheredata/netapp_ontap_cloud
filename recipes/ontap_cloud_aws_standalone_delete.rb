#
# Cookbook:: netapp_ontap_cloud
# Recipe:: ontap_cloud_aws_standalone_delete
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

begin
  occm_admin = data_bag_item('occm', 'admin_credentials')
rescue StandardError
  raise 'The DataBagItem(\'occm\', \'admin_credentials\') was not found.  Unable to set the admin credentials'
end

netapp_ontap_cloud_ontap_aws 'Remove ONTAP Cloud' do
  server node['occm']['server']
  occm_user occm_admin['email_address']
  occm_password occm_admin['password']
  ontap_name node['ontap_cloud']['ontap']['standalone']['name']
  wait_execution true
  action :delete
end

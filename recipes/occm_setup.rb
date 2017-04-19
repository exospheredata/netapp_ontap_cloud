#
# Cookbook:: netapp_ontap_cloud
# Recipe:: occm_setup
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

begin
  occm_keys = data_bag_item('occm', 'aws')
rescue StandardError
  Chef::Log.info('The DataBagItem(\'occm\', \'aws\') was not found.  Unable to set the AWS Credentials')
  occm_keys = {}
end

begin
  occm_admin = data_bag_item('occm', 'admin_credentials')
rescue StandardError
  raise "('The DataBagItem(\'occm\', \'admin_credentials\') was not found.  Unable to set the admin credentials"
end

# Calling the OCCM install recipe in this cookbook.  We are using the cookbook_name
# variable in the event this cookbook_name is changed later.
include_recipe "#{cookbook_name}::occm_install" if node['occm']['install_pkg']

netapp_ontap_cloud_occm 'Setup Cloud Manager' do
  server node['occm']['server']
  email_address occm_admin['email_address']
  password occm_admin['password']
  company node['occm']['company_name']
  tenant_name node['occm']['tenant_name']
  aws_key occm_keys['aws_access_key'] || nil
  aws_secret occm_keys['aws_secret_key'] || nil
  action :setup
end

#
# Cookbook:: netapp_ontap_cloud
# Recipe:: ontap_cloud_aws_standalone
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
  raise 'The DataBagItem(\'occm\', \'admin_credentials\') was not found.  Unable to set the admin credentials'
end

begin
  ontap_admin = data_bag_item('occm', node['ontap_cloud']['ontap']['standalone']['name'])
rescue StandardError
  raise "The DataBagItem(\'occm\', \'#{node['ontap_cloud']['ontap']['standalone']['name']}\') was not found.  Unable to set the ONTAP credentials"
end

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

netapp_ontap_cloud_ontap_aws 'Setup ONTAP Cloud' do
  server node['occm']['server']
  occm_user occm_admin['email_address']
  occm_password occm_admin['password']
  tenant_name 'Default Tenant'
  ontap_name node['ontap_cloud']['ontap']['standalone']['name']
  svm_password ontap_admin['svm_password']
  region node['ontap_cloud']['aws']['region']
  vpc_id node['ontap_cloud']['aws']['vpc_id']
  subnet_id node['ontap_cloud']['aws']['subnet_id']
  ebs_volume_type node['ontap_cloud']['ontap']['standalone']['ebs_type']
  ebs_volume_size node['ontap_cloud']['ontap']['standalone']['size']
  instance_type node['ontap_cloud']['ontap']['standalone']['instance_type']
  license_type node['ontap_cloud']['ontap']['standalone']['license_type']
  write_speed node['ontap_cloud']['ontap']['standalone']['write_speed']
  bypass_snapshot true
  wait_execution true
  action :create
end

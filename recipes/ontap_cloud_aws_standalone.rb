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

netapp_ontap_cloud_occm 'Setup Cloud Manager' do
  server node['occm']['server']
  email_address node['occm']['user']['email_address']
  password node['occm']['user']['password']
  company node['occm']['company_name']
  aws_key occm_keys['aws_access_key'] || nil
  aws_secret occm_keys['aws_secret_key'] || nil
  action :setup
end

netapp_ontap_cloud_ontap_aws 'Setup ONTAP Cloud' do
  server node['occm']['server']
  occm_user node['occm']['user']['email_address']
  occm_password node['occm']['user']['password']
  tenant_name 'Default Tenant'
  ontap_name node['ontap_cloud']['ontap']['standalone']['name']
  svm_password 'Netapp123'
  region node['ontap_cloud']['aws']['region']
  vpc_id node['ontap_cloud']['aws']['vpc_id']
  subnet_id node['ontap_cloud']['aws']['subnet_id']
  ebs_volume_size '100GB'
  bypass_snapshot true
  wait_execution true
  action :create
end

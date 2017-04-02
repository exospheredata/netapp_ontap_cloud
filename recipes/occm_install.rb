#
# Cookbook:: netapp_ontap_cloud
# Recipe:: occm_install
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

begin
  occm_keys = data_bag_item('occm', 'aws')
rescue StandardError
  Chef::Log.info('The DataBagItem(\'occm\', \'aws\') was not found.  Unable to set the AWS Credentials')
  occm_keys = {}
end

occm_installer = ::File.join(Chef::Config[:file_cache_path], 'OnCommandCloudManager-V3.2.0.sh')

cookbook_file occm_installer do
  source 'OnCommandCloudManager-V3.2.0.sh'
  mode '0755'
end

execute "sh #{occm_installer} silent" do
  action :run
  not_if { ::File.exist?('/usr/lib/systemd/scripts/occm') }
end

# Ensure that OnCommand Cloud Manager service is enabled and running.
service 'occm' do
  action [:enable, :start]
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

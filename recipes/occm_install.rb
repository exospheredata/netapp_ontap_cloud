#
# Cookbook:: netapp_ontap_cloud
# Recipe:: occm_install
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

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
  server 'localhost'
  email_address 'test@lab.test'
  password 'netapp123'
  company 'mycompany'
  action :setup
end

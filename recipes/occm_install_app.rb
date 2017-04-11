#
# Cookbook:: netapp_ontap_cloud
# Recipe:: occm_install
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

occm_installer = ::File.join(Chef::Config[:file_cache_path], 'OnCommandCloudManager-V3.2.0.sh')

# If the custom install URL was provided, then download the file.  Otherwise, use the local cookbook_file if
# the file exists.
#
# Due to EULA and license restrictions, we are unable to directly download this software so it needs to be
# included in the cookbook or stored on a local HTTP server.
if node['occm']['installer'].nil?
  cookbook_file occm_installer do
    source 'OnCommandCloudManager-V3.2.0.sh'
    mode '0755'
  end
else
  remote_file occm_installer do
    source node['occm']['installer']
    mode '0755'
  end
end

execute "sh #{occm_installer} silent" do
  action :run
  not_if { ::File.exist?('/usr/lib/systemd/scripts/occm') }
end

# Ensure that OnCommand Cloud Manager service is enabled and running.
service 'occm' do
  action [:enable, :start]
end

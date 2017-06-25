#
# Cookbook:: netapp_ontap_cloud
# Recipe:: ontap_cloud_aggregate
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

begin
  occm_admin = data_bag_item('occm', 'admin_credentials')
rescue StandardError
  raise 'The DataBagItem(\'occm\', \'admin_credentials\') was not found.  Unable to set the admin credentials'
end

netapp_ontap_cloud_aggregate node['ontap_cloud']['ontap']['standalone']['aggregate']['name'] do
  server node['occm']['server']
  occm_user occm_admin['email_address']
  occm_password occm_admin['password']
  ontap_name node['ontap_cloud']['ontap']['standalone']['name']
  disk_count node['ontap_cloud']['ontap']['standalone']['aggregate']['disk_count']
  ebs_volume_type node['ontap_cloud']['ontap']['standalone']['aggregate']['ebs_type']
  ebs_volume_size node['ontap_cloud']['ontap']['standalone']['aggregate']['size']
  action :create
end

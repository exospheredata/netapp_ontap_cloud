#
# Cookbook:: netapp_ontap_cloud_test
# Recipe:: aggregate
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

netapp_ontap_cloud_aggregate node['ontap_cloud_test']['ontap']['standalone']['aggregate']['name'] do
  server 'localhost'
  occm_user 'test@lab.test'
  occm_password 'netapp123'
  ontap_name 'demolab'
  disk_count 1
  ebs_volume_size '100GB'
  ebs_volume_type 'gp2'
  action :create
end

netapp_ontap_cloud_aggregate 'add disk to aggr1' do
  aggregate 'aggr1'
  server 'localhost'
  occm_user 'test@lab.test'
  occm_password 'netapp123'
  ontap_name 'demolab'
  disk_count 1
  action :add
end

netapp_ontap_cloud_aggregate 'Delete aggr1' do
  aggregate 'aggr1'
  server 'localhost'
  occm_user 'test@lab.test'
  occm_password 'netapp123'
  ontap_name 'demolab'
  action :delete
end

#
# Cookbook:: netapp_ontap_cloud_test
# Recipe:: default
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

include_recipe 'netapp_ontap_cloud_test::occm'
include_recipe 'netapp_ontap_cloud_test::ontap_aws'
include_recipe 'netapp_ontap_cloud_test::aggregate'

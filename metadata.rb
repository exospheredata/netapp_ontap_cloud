name 'netapp_ontap_cloud'
maintainer 'Exosphere Data, LLC'
maintainer_email 'chef@exospheredata.com'
license 'all_rights'
description 'Manages NetApp OnCommand Cloud Manager and ONTAP Cloud'
long_description 'Manages NetApp OnCommand Cloud Manager and ONTAP Cloud'
version '1.0.0'

%w(debian ubuntu centos redhat amazon).each do |os|
  supports os
end

# The `issues_url` points to the location where issues for this cookbook are
# tracked.  A `View Issues` link will be displayed on this cookbook's page when
# uploaded to a Supermarket.
#
issues_url 'https://github.com/exospheredata/netapp_ontap_cloud/issues' if respond_to?(:issues_url)

# The `source_url` points to the development reposiory for this cookbook.  A
# `View Source` link will be displayed on this cookbook's page when uploaded to
# a Supermarket.
#
source_url 'https://github.com/exospheredata/netapp_ontap_cloud' if respond_to?(:source_url)

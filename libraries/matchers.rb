if defined?(ChefSpec)
  # DefineMatcher allow us to expose the concept of the method to chef_run during testing.
  ChefSpec.define_matcher(:netapp_ontap_cloud_occm)
  ChefSpec.define_matcher(:netapp_ontap_cloud_ontap_aws)
  ChefSpec.define_matcher(:netapp_ontap_cloud_ndvp)

  def setup_netapp_ontap_cloud_occm(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:netapp_ontap_cloud_occm, :setup, resource_name)
  end

  def create_netapp_ontap_cloud_ontap_aws(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:netapp_ontap_cloud_ontap_aws, :create, resource_name)
  end

  def delete_netapp_ontap_cloud_ontap_aws(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:netapp_ontap_cloud_ontap_aws, :delete, resource_name)
  end
end

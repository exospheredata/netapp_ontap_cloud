if defined?(ChefSpec)
  # DefineMatcher allow us to expose the concept of the method to chef_run during testing.
  ChefSpec.define_matcher(:netapp_ontap_cloud_occm)

  def setup_netapp_ontap_cloud_occm(resource_name)
    ChefSpec::Matchers::ResourceMatcher.new(:netapp_ontap_cloud_occm, :setup, resource_name)
  end

end

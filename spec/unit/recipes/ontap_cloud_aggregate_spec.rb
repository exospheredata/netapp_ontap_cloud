#
# Cookbook:: netapp_ontap_cloud
# Spec:: ontap_cloud_aggregate_spec
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'netapp_ontap_cloud::ontap_cloud_aggregate' do
  before do
    stub_data_bag_item('occm', 'aws').and_return(id: 'aws', aws_access_key: 'testkey', aws_secret_key: 'nopass')
    stub_data_bag_item('occm', 'admin_credentials').and_return(id: 'admin_credentials', email_address: 'test@lab.test', password: 'Netapp1')
    stub_data_bag_item('occm', 'demolab').and_return(id: 'demolab', svm_password: 'Netapp123')
  end
  context 'When all attributes are default' do
    platforms = {
      'centos' => {
        'versions' => %w(7.1.1503 7.2.1511)
      }
    }

    platforms.each do |platform, components|
      components['versions'].each do |version|
        context "On #{platform} #{version}" do
          before do
            Fauxhai.mock(platform: platform, version: version)
          end
          let(:chef_run) do
            ChefSpec::SoloRunner.new(platform: platform, version: version, file_cache_path: '/tmp/cache') do |node|
              node.normal['ontap_cloud']['ontap']['standalone']['name'] = 'demolab'
              node.normal['ontap_cloud']['ontap']['standalone']['aggregate']['name'] = 'aggr2'
              node.normal['ontap_cloud']['ontap']['standalone']['aggregate']['disk_count'] = 1
            end.converge(described_recipe)
          end

          it 'converges successfully' do
            expect { chef_run }.to_not raise_error
            expect(chef_run).to create_netapp_ontap_cloud_aggregate('aggr2')
          end
        end
      end
    end
  end
end

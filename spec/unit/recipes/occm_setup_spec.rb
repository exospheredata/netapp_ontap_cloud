#
# Cookbook:: netapp_ontap_cloud
# Spec:: occm_install_spec
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'netapp_ontap_cloud::occm_setup' do
  before do
    stub_data_bag_item('occm', 'aws').and_return(id: 'aws', aws_access_key: 'testkey', aws_secret_key: 'nopass')
    stub_data_bag_item('occm', 'admin_credentials').and_return(id: 'admin_credentials', email_address: 'test@lab.test', password: 'Netapp1')
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
            allow_any_instance_of(Chef::Provider).to receive(:server_configured?).with('localhost').and_return(false)
            node.normal['occm']['company_name'] = 'company_test'
            node.normal['ontap_cloud']['aws']['region'] = 'us-east-1'
            node.normal['ontap_cloud']['aws']['vpc_id'] = 'vpc-12345678'
            node.normal['ontap_cloud']['aws']['subnet_id'] = 'subnet-1a2b3c4d'
            node.normal['occm']['install_pkg'] = true
          end
          let(:runner) do
            ChefSpec::SoloRunner.new(platform: platform, version: version, file_cache_path: '/tmp/cache')
          end
          let(:node) { runner.node }
          let(:chef_run) { runner.converge(described_recipe) }
          let(:occm_installer) { ::File.join(Chef::Config[:file_cache_path], 'OnCommandCloudManager-V3.2.0.sh') }

          it 'converges successfully' do
            expect { chef_run }.to_not raise_error
            # By default, we will look for this installer in the cookbook_file path
            expect(chef_run).to create_cookbook_file(occm_installer)
            expect(chef_run).to include_recipe('netapp_ontap_cloud::occm_install')
            expect(chef_run).to setup_netapp_ontap_cloud_occm('Setup Cloud Manager')
          end
          it 'downloads installer from URL' do
            node.normal['occm']['installer'] = 'http://download/occm'
            expect { chef_run }.to_not raise_error
            # This should only run if the web url is provided to the installer path
            expect(chef_run).to create_remote_file(occm_installer)
          end
          it 'does not install package' do
            node.normal['occm']['install_pkg'] = false
            expect { chef_run }.to_not raise_error
            expect(chef_run).to_not include_recipe('netapp_ontap_cloud::occm_install')
          end
        end
      end
    end
  end
end

#
# Cookbook:: netapp_ontap_cloud
# Spec:: occm_install_spec
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'netapp_ontap_cloud::occm_install' do
  before do
    stub_data_bag_item('occm', 'aws').and_return(id: 'aws', aws_access_key: 'testkey', aws_secret_key: 'nopass')
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
            node.normal['occm']['user']['email_address'] = 'test@lab.test'
            node.normal['occm']['user']['password'] = 'password'
            node.normal['occm']['company_name'] = 'company_test'
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
            expect(chef_run).to enable_service('occm')
            expect(chef_run).to start_service('occm')
            expect(chef_run).to run_execute("sh #{occm_installer} silent")
            expect(chef_run).to setup_netapp_ontap_cloud_occm('Setup Cloud Manager')
          end
          it 'downloads installer from URL' do
            node.normal['occm']['installer'] = 'http://download/occm'
            expect { chef_run }.to_not raise_error
            # This should only run if the web url is provided to the installer path
            expect(chef_run).to create_remote_file(occm_installer)
          end
        end
      end
    end
  end
end

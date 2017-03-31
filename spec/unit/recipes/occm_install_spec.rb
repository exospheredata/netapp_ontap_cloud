#
# Cookbook:: netapp_ontap_cloud
# Spec:: default
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'netapp_ontap_cloud::occm_install' do
  context 'When all attributes are default, on an unspecified platform' do
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
          end
          let(:runner) do
            ChefSpec::ServerRunner.new(platform: platform, version: version, file_cache_path: '/tmp/cache')
          end
          let(:node) { runner.node }
          let(:chef_run) { runner.converge(described_recipe) }
          let(:occm_installer) { ::File.join(Chef::Config[:file_cache_path], 'OnCommandCloudManager-V3.2.0.sh') }

          it 'converges successfully' do
            expect { chef_run }.to_not raise_error
            expect(chef_run).to create_cookbook_file(occm_installer)
            expect(chef_run).to enable_service('occm')
            expect(chef_run).to start_service('occm')
            expect(chef_run).to run_execute("sh #{occm_installer} silent")
            expect(chef_run).to setup_netapp_ontap_cloud_occm('Setup Cloud Manager')
          end
        end
      end
    end
  end
end

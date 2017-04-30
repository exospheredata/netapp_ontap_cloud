#
# Cookbook:: netapp_ontap_cloud
# Spec:: ndvp_install_spec
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'netapp_ontap_cloud::docker_volume_plugin' do
  before do
    stub_data_bag_item('occm', 'admin_credentials').and_return(id: 'admin_credentials', email_address: 'test@lab.test', password: 'Netapp1')
    stub_data_bag_item('occm', 'demolab').and_return(id: 'demolab', svm_password: 'Netapp123')
    # we are using the WebMock gem to create our Net::Http stubs
    stub_request(:get, 'https://localhost/occm/api/occm/system/about')
    stub_request(:post, 'https://localhost/occm/api/auth/login')
      .to_return(status: 204, headers: { 'Content-Type' => 'application/json', 'set-cookie' => 1 })
    stub_request(:get, 'https://localhost/occm/api/vsa/working-environments')
      .to_return(status: 200, body: JSON.generate([{ 'publicId' => 'VsaWorkingEnvironment-AtWLuhmG', 'name' => 'demolab' }]),
                 headers: { 'Content-Type' => 'application/json' })
    stub_request(:get, 'https://localhost/occm/api/vsa/working-environments/VsaWorkingEnvironment-AtWLuhmG?fields=ontapClusterProperties,svms,capacityFeatures')
      .to_return(status: 200, body: ::IO.read('spec/fixtures/files/get-vsa-details.json'),
                 headers: { 'Content-Type' => 'application/json' })
    stub_command('docker plugin list | grep netapp:latest').and_return(nil)
    stub_command('docker plugin list | grep netapp:latest | grep false').and_return('disabled')
  end
  context 'When all attributes are default' do
    platforms = {
      'ubuntu' => {
        'versions' => ['14.04', '16.04']
      },
      'debian' => {
        'versions' => ['6.0.5']
      },
      'centos' => {
        'versions' => %w(7.1.1503 7.2.1511)
      },
      'redhat' => {
        'versions' => %w(7.1 7.2)
      }
    }

    platforms.each do |platform, components|
      components['versions'].each do |version|
        context "On #{platform} #{version}" do
          before do
            Fauxhai.mock(platform: platform, version: version)
            # Set test suite node attributes
            node.normal['occm']['company_name'] = 'company_test'
            node.normal['ontap_cloud']['ontap']['standalone']['name'] = 'demolab'
          end
          let(:runner) do
            ChefSpec::SoloRunner.new(platform: platform, version: version, file_cache_path: '/tmp/cache', step_into: ['netapp_ontap_cloud_ndvp'])
          end
          let(:node) { runner.node }
          let(:chef_run) { runner.converge(described_recipe) }

          context 'Success Tests' do
            it 'converges successfully' do
              stub_request(:get, 'https://localhost/occm/api/vsa/working-environments/VsaWorkingEnvironment-AtWLuhmG?fields=ontapClusterProperties,svms,capacityFeatures')
                .to_return(status: 200, body: ::IO.read('spec/fixtures/files/get-vsa-details.json'),
                           headers: { 'Content-Type' => 'application/json' })
              expect { chef_run }.to_not raise_error
              expect(chef_run).to config_netapp_ontap_cloud_ndvp('demolab')
              expect(chef_run).to install_netapp_ontap_cloud_ndvp('demolab')
              expect(chef_run).to create_directory('/etc/netappdvp')
              expect(chef_run).to create_template('/etc/netappdvp/config.json')
              case platform
              when 'redhat', 'centos'
                expect(chef_run).to install_package('nfs-utils')
              when 'ubuntu', 'debian'
                expect(chef_run).to install_package('nfs-common')
              end
              expect(chef_run).to run_execute('Install NetApp Docker Volume Plugin')
              expect(chef_run).to run_execute('Enable NetApp Docker Volume Plugin')
              create_resource = chef_run.netapp_ontap_cloud_ndvp('demolab')
              expect(create_resource.updated_by_last_action?).to be true
            end
          end

          context 'Failure Tests' do
            it 'fails with invalid credentials' do
              stub_request(:post, 'https://localhost/occm/api/auth/login')
                .to_return(status: 401, body: JSON.generate('message' => 'Authentication Failure', 'causeMessage' => 'Invalid credentials'),
                           headers: { 'Content-Type' => 'application/json' })
              expect { chef_run }.to raise_error(ArgumentError, /Authentication Failed due to invalid credentials/)
            end
            it 'fails when ontap_name not found' do
              stub_request(:get, 'https://localhost/occm/api/vsa/working-environments')
                .to_return(status: 200, body: JSON.generate([]),
                           headers: { 'Content-Type' => 'application/json' })
              expect { chef_run }.to raise_error(ArgumentError, /The ONTAP Cloud System demolab was not found/)
            end
          end
        end
      end
    end
  end
end

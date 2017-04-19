#
# Cookbook:: netapp_ontap_cloud
# Spec:: occm_setup_resource
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
            # we are using the WebMock gem to create our Net::Http stubs
            stub_request(:get, 'https://localhost/occm/api/occm/system/about')
            stub_request(:get, 'https://localhost/occm/api/occm/config')
              .to_return(status: 200, body: JSON.generate('message' => 'OCCM must be setup before performing this operation.'),
                         headers: { 'Content-Type' => 'application/json' })
            stub_request(:post, 'https://localhost/occm/api/occm/setup/init')
              .to_return(status: 200, body: JSON.generate('upgradeExecuted' => 'true'),
                         headers: { 'Content-Type' => 'application/json' })
          end
          let(:chef_run) do
            ChefSpec::SoloRunner.new(platform: platform, version: version, file_cache_path: '/tmp/cache', step_into: ['netapp_ontap_cloud_occm']) do |node|
              node.normal['occm']['user']['email_address'] = 'test@lab.test'
              node.normal['occm']['user']['password'] = 'password'
              node.normal['occm']['company_name'] = 'My Company'
            end.converge(described_recipe)
          end
          let(:occm_installer) { ::File.join(Chef::Config[:file_cache_path], 'OnCommandCloudManager-V3.2.0.sh') }

          it 'converges successfully' do
            expect { chef_run }.to_not raise_error
            # Verify that the process was complete and update == True
            resource = chef_run.netapp_ontap_cloud_occm('Setup Cloud Manager')
            expect(resource.updated_by_last_action?).to be true
          end
          it 'should skip setup if server_configured' do
            stub_request(:get, 'https://localhost/occm/api/occm/config')
              .to_return(status: 200, body: JSON.generate('message' => 'OnCloudAuthenticationException: Authentication required'),
                         headers: { 'Content-Type' => 'application/json' })
            expect { chef_run }.to_not raise_error
            # Verify that the process was skipped and update == False
            resource = chef_run.netapp_ontap_cloud_occm('Setup Cloud Manager')
            expect(resource.updated_by_last_action?).to be false
          end
          it 'should gracefully handle situation where setup already performed' do
            stub_request(:post, 'https://localhost/occm/api/occm/setup/init')
              .to_return(status: 200, body: JSON.generate('message' => 'Initial setup already performed'),
                         headers: { 'Content-Type' => 'application/json' })
            expect { chef_run }.to_not raise_error
            # Verify that the process was skipped and update == False
            resource = chef_run.netapp_ontap_cloud_occm('Setup Cloud Manager')
            expect(resource.updated_by_last_action?).to be false
          end
          it 'should raise an ArgumentError if setup fails' do
            stub_request(:post, 'https://localhost/occm/api/occm/setup/init')
              .to_return(status: 400, body: JSON.generate('message' => 'bad data', 'violations' => 'everything'),
                         headers: { 'Content-Type' => 'application/json' })
            expect { chef_run }.to raise_error(ArgumentError, /OCCM Setup command returned an http error 400/)
          end
          it 'should raise an RuntimeError if setup returns HTTPClientError or HTTPInternalServerError' do
            stub_request(:post, 'https://localhost/occm/api/occm/setup/init')
              .to_return(status: 500, body: JSON.generate('message' => 'bad data', 'violations' => 'everything'),
                         headers: { 'Content-Type' => 'application/json' })
            expect { chef_run }.to raise_error(RuntimeError, /Unknown OCCM Server error/)
          end
          it 'should raise an RuntimeError if HTTP service not responding' do
            stub_request(:get, 'https://localhost/occm/api/occm/system/about')
              .to_raise(Errno::ENETUNREACH)
            expect { chef_run }.to raise_error(RuntimeError, /The Service never returned despite waiting patiently/)
          end
          it 'should raise an ArgumentError if no AwsAccessKey sent but an AwsSecretKey exists' do
            stub_data_bag_item('occm', 'aws').and_return(id: 'aws', aws_access_key: '', aws_secret_key: 'nopass')
            expect { chef_run }.to raise_error(ArgumentError, /AWS Secret Key set with no valid aws_key/)
          end
          it 'should raise an ArgumentError if no AwsSecretKey sent but an AwsAccessKey exists' do
            stub_data_bag_item('occm', 'aws').and_return(id: 'aws', aws_access_key: 'testkey', aws_secret_key: nil)
            expect { chef_run }.to raise_error(ArgumentError, /AWS Access Key set with no valid aws_secret/)
          end
        end
      end
    end
  end
end

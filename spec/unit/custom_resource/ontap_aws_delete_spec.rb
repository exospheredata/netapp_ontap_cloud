#
# Cookbook:: netapp_ontap_cloud
# Spec:: ontap_aws_create_spec
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'netapp_ontap_cloud::ontap_cloud_aws_standalone_delete' do
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
            # Set test suite node attributes
            node.normal['occm']['user']['email_address'] = 'test@lab.test'
            node.normal['occm']['user']['password'] = 'password'
            node.normal['occm']['company_name'] = 'company_test'
            node.normal['ontap_cloud']['ontap']['standalone']['name'] = 'demolab'

            # we are using the WebMock gem to create our Net::Http stubs
            stub_request(:get, 'https://localhost/occm/api/occm/system/about')
            stub_request(:post, 'https://localhost/occm/api/auth/login')
              .to_return(status: 204, headers: { 'Content-Type' => 'application/json', 'set-cookie' => 1 })
            stub_request(:get, 'https://localhost/occm/api/vsa/working-environments')
              .to_return(status: 200, body: JSON.generate([{ 'publicId' => 'VsaWorkingEnvironment-AtWLuhmG', 'name' => 'demolab' }]),
                         headers: { 'Content-Type' => 'application/json' })
            stub_request(:delete, 'https://localhost/occm/api/vsa/working-environments/VsaWorkingEnvironment-AtWLuhmG')
              .to_return(status: 204, headers: { 'Content-Type' => 'application/json' })
            stub_request(:get, 'https://localhost/occm/api/audit?workingEnvironmentId=VsaWorkingEnvironment-AtWLuhmG')
              .to_return(status: 200, body: JSON.generate([{ 'actionName' => 'Delete Vsa Working Environment', 'status' => 'Success' }]),
                         headers: { 'Content-Type' => 'application/json' })
          end
          let(:runner) do
            ChefSpec::SoloRunner.new(platform: platform, version: version, file_cache_path: '/tmp/cache', step_into: ['netapp_ontap_cloud_ontap_aws'])
          end
          let(:node) { runner.node }
          let(:chef_run) { runner.converge(described_recipe) }

          context 'Success Tests' do
            it 'converges successfully' do
              expect { chef_run }.to_not raise_error
              create_resource = chef_run.netapp_ontap_cloud_ontap_aws('Remove ONTAP Cloud')
              expect(create_resource.updated_by_last_action?).to be true
            end
            it 'skips delete if the ONTAP environment does not exists' do
              stub_request(:get, 'https://localhost/occm/api/vsa/working-environments')
                .to_return(status: 200, body: JSON.generate([]),
                           headers: { 'Content-Type' => 'application/json' })
              expect { chef_run }.to_not raise_error
              # Verify that the process was skipped and update == False
              resource = chef_run.netapp_ontap_cloud_ontap_aws('Remove ONTAP Cloud')
              expect(resource.updated_by_last_action?).to be false
            end
          end

          context 'Failure Tests' do
            it 'fails with invalid credentials' do
              stub_request(:post, 'https://localhost/occm/api/auth/login')
                .to_return(status: 401, body: JSON.generate('message' => 'Authentication Failure', 'causeMessage' => 'Invalid credentials'),
                           headers: { 'Content-Type' => 'application/json' })
              expect { chef_run }.to raise_error(ArgumentError, /Authentication Failed due to invalid credentials/)
            end
          end

          # Property Regex Validations
          context 'Regex Evaluations' do
            it 'fails regex when invalid option sent for ontap_name' do
              node.normal['ontap_cloud']['ontap']['standalone']['name'] = '1cot' # Format should enforce regex pattern - [/^[A-Za-z][A-Za-z0-9_]{2,39}$/]
              expect { chef_run }.to raise_error(ArgumentError, /Option ontap_name's value 1cot does not match regular expression/)
            end
          end
        end
      end
    end
  end
end

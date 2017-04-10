#
# Cookbook:: netapp_ontap_cloud
# Spec:: ontap_aws_create_spec
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'netapp_ontap_cloud::ontap_cloud_aws_standalone' do
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
            node.normal['ontap_cloud']['aws']['region'] = 'us-east-1'
            node.normal['ontap_cloud']['aws']['vpc_id'] = 'vpc-12345678'
            node.normal['ontap_cloud']['aws']['subnet_id'] = 'subnet-1a2b3c4d'
            node.normal['ontap_cloud']['ontap']['standalone']['name'] = 'demolab'

            # we are using the WebMock gem to create our Net::Http stubs
            stub_request(:get, 'https://localhost/occm/api/occm/system/about')
            stub_request(:post, 'https://localhost/occm/api/auth/login')
              .to_return(status: 204, headers: { 'Content-Type' => 'application/json', 'set-cookie' => 1 })
            stub_request(:get, 'https://localhost/occm/api/tenants')
              .to_return(status: 200, body: JSON.generate([{ 'publicId' => 'tenantID', 'name' => 'Default Tenant' }]),
                         headers: { 'Content-Type' => 'application/json' })
            stub_request(:post, 'https://localhost/occm/api/vsa/working-environments')
              .to_return(status: 200, body: JSON.generate('VsaWorkingEnvironmentResponse' => { 'name' => 'demolab' }),
                         headers: { 'Content-Type' => 'application/json' })
            stub_request(:get, 'https://localhost/occm/api/vsa/metadata/vpcs?region=us-east-1')
              .to_return(status: 200, body: JSON.generate([{ 'vpcId' => 'vpc-12345678', 'cidrBlock' => '172.31.0.0/16',
                                                             'subnets' => [{ 'subnetId' => 'subnet-1a2b3c4d' }] }]),
                         headers: { 'Content-Type' => 'application/json' })
            stub_request(:get, 'https://localhost/occm/api/vsa/working-environments')
              .to_return(status: 200, body: JSON.generate([]),
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
              resource = chef_run.netapp_ontap_cloud_ontap_aws('Setup ONTAP Cloud')
              expect(resource.updated_by_last_action?).to be true
            end
            it 'does nothing if the ONTAP environment exists' do
              stub_request(:get, 'https://localhost/occm/api/vsa/working-environments')
                .to_return(status: 200, body: JSON.generate([{ 'publicId' => 'VsaWorkingEnvironment-4nc7ttNy', 'name' => 'demolab' }]),
                           headers: { 'Content-Type' => 'application/json' })
              expect { chef_run }.to_not raise_error
              # Verify that the process was skipped and update == False
              resource = chef_run.netapp_ontap_cloud_ontap_aws('Setup ONTAP Cloud')
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
            it 'fails when Tenant name not found' do
              stub_request(:get, 'https://localhost/occm/api/tenants')
                .to_return(status: 200, body: JSON.generate([{ 'publicId' => 'tenantID', 'name' => 'Not my Tenant' }]),
                           headers: { 'Content-Type' => 'application/json' })
              expect { chef_run }.to raise_error(ArgumentError, /Tenant was not found on this server/)
            end
            it 'fails when Vpc not found' do
              stub_request(:get, 'https://localhost/occm/api/vsa/metadata/vpcs?region=us-east-1')
                .to_return(status: 200, body: JSON.generate([{ 'vpcId' => 'vpc-ID', 'cidrBlock' => '172.31.0.0/16' }]),
                           headers: { 'Content-Type' => 'application/json' })
              expect { chef_run }.to raise_error(ArgumentError, /VPC vpc-12345678 was not found in the list of available VPCs for this user/)
            end
          end

          # Property Regex Validations
          context 'Regex Evaluations' do
            it 'fails regex when invalid option sent for ontap_name' do
              node.normal['ontap_cloud']['ontap']['standalone']['name'] = '1cot' # Format should enforce regex pattern - [/^[A-Za-z][A-Za-z0-9_]{2,39}$/]
              expect { chef_run }.to raise_error(ArgumentError, /Option ontap_name's value 1cot does not match regular expression/)
            end
            it 'fails regex when invalid option sent for region' do
              node.normal['ontap_cloud']['aws']['region'] = 'my-region' # Format should enforce regex pattern - [/^{a-z]{2}-[a-z]+-\d/]
              expect { chef_run }.to raise_error(ArgumentError, /Option region's value my-region does not match regular expression/)
            end
            it 'fails regex when invalid option sent for vpc_id' do
              node.normal['ontap_cloud']['aws']['vpc_id'] = 'my-vpc' # Format should enforce regex pattern - [/^vpc-[a-zA-Z0-9]{8}$/]
              expect { chef_run }.to raise_error(ArgumentError, /Option vpc_id's value my-vpc does not match regular expression/)
            end
            it 'fails regex when invalid option sent for subnet_id' do
              node.normal['ontap_cloud']['aws']['subnet_id'] = 'my-subnet' # Format should enforce regex pattern - [/^subnet-[a-zA-Z0-9]{8}$/]
              expect { chef_run }.to raise_error(ArgumentError, /Option subnet_id's value my-subnet does not match regular expression/)
            end
          end
        end
      end
    end
  end
end

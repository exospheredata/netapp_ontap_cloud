#
# Cookbook:: netapp_ontap_cloud
# Spec:: ontap_aggregate_create_spec
#
# maintainer:: Exosphere Data, LLC
# maintainer_email:: chef@exospheredata.com
#
# Copyright:: 2017, Exosphere Data, LLC, All Rights Reserved.

require 'spec_helper'

describe 'netapp_ontap_cloud_test::aggregate' do
  before do
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
            node.normal['ontap_cloud_test']['ontap']['standalone']['aggregate']['name'] = 'aggr2'
            # we are using the WebMock gem to create our Net::Http stubs
            stub_request(:get, 'https://localhost/occm/api/occm/system/about')
            stub_request(:post, 'https://localhost/occm/api/auth/login')
              .to_return(status: 204, headers: { 'Content-Type' => 'application/json', 'set-cookie' => 1 })

            stub_request(:get, 'https://localhost/occm/api/vsa/working-environments')
              .to_return(status: 200, body: JSON.generate([{ 'publicId' => 'VsaWorkingEnvironment-AtWLuhmG', 'name' => 'demolab' }]),
                         headers: { 'Content-Type' => 'application/json' })

            stub_request(:get, 'https://localhost/occm/api/vsa/aggregates?workingEnvironmentId=VsaWorkingEnvironment-AtWLuhmG')
              .to_return(status: 200, body: ::File.read('spec/fixtures/files/get-aggr-details.json'),
                         headers: { 'Content-Type' => 'application/json' })

            stub_request(:get, 'https://localhost/occm/api/vsa/working-environments/VsaWorkingEnvironment-AtWLuhmG?fields=ontapClusterProperties')
              .to_return(status: 200, body: ::File.read('spec/fixtures/files/get-vsa-aws-details.json'),
                         headers: { 'Content-Type' => 'application/json' })

            stub_request(:post, 'https://localhost/occm/api/vsa/aggregates')
              .to_return(status: 202, body: '',
                         headers: { 'Content-Type' => 'application/json', 'Oncloud-Request-Id' => 'Cod33Rmu' })

            stub_request(:post, 'https://localhost/occm/api/vsa/aggregates/VsaWorkingEnvironment-AtWLuhmG/aggr1/disks')
              .to_return(status: 202, body: '',
                         headers: { 'Content-Type' => 'application/json', 'Oncloud-Request-Id' => 'Cod33Rmu' })

            stub_request(:delete, 'https://localhost/occm/api/vsa/aggregates/VsaWorkingEnvironment-AtWLuhmG/aggr1')
              .to_return(status: 202, body: '',
                         headers: { 'Content-Type' => 'application/json', 'Oncloud-Request-Id' => 'Cod33Rmu' })

            stub_request(:get, 'https://localhost/occm/api/audit/Cod33Rmu')
              .to_return(status: 200, body: ::File.read('spec/fixtures/files/get-audit-aggr-log.json'),
                         headers: { 'Content-Type' => 'application/json' })
          end
          let(:runner) do
            ChefSpec::SoloRunner.new(platform: platform, version: version, file_cache_path: '/tmp/cache', step_into: ['netapp_ontap_cloud_aggregate'])
          end
          let(:node) { runner.node }
          let(:chef_run) { runner.converge(described_recipe) }

          it 'it converges successfully' do
            expect { chef_run }.to_not raise_error
            expect(chef_run).to create_netapp_ontap_cloud_aggregate('aggr2')
            expect(chef_run).to add_netapp_ontap_cloud_aggregate('add disk to aggr1')
            expect(chef_run).to delete_netapp_ontap_cloud_aggregate('Delete aggr1')
          end
          it 'it does nothing if aggregate exists' do
            node.normal['ontap_cloud_test']['ontap']['standalone']['aggregate']['name'] = 'aggr1'
            expect { chef_run }.to_not raise_error
            expect(chef_run).to create_netapp_ontap_cloud_aggregate('aggr1')
            resource = chef_run.netapp_ontap_cloud_aggregate('aggr1')
            expect(resource.updated_by_last_action?).to be false
          end
          it 'it raises an error if the ontap system is not found' do
            stub_request(:get, 'https://localhost/occm/api/vsa/working-environments')
              .to_return(status: 200, body: JSON.generate([]),
                         headers: { 'Content-Type' => 'application/json' })
            expect { chef_run }.to raise_error(RuntimeError, /ONTAP Cloud system demolab does not exist/)
          end
        end
      end
    end
  end
end

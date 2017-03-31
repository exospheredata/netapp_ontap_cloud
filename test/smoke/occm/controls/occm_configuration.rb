# encoding: utf-8
# copyright: 2017, Exosphere Data, Inc
# license: All rights reserved

title 'OnCommand Cloud Manager Configuration'

control 'occm-1.0' do
  impact 1.0
  title 'Install Package - occm '
  desc 'Verify that the OnCommand Cloud Manager application package is installed'

  describe package('occm') do
    it { should be_installed }
  end
end

control 'occm-1.1' do
  impact 1.0
  title 'OnCommand Cloud Manager is running and listening'
  desc 'Verify that the OnCommand Cloud Manager application package is installed'

  describe service('occm') do
    it { should be_running }
    it { should be_enabled }
  end
  describe port(443) do
    it { should be_listening }
  end
end

control 'occm-1.2' do
  impact 1.0
  title 'Initial configuration and setup is complete'
  desc 'Verify that the OnCommand Cloud Manager configuration and setup has been completed'

  describe command('curl -k https://localhost/occm/api/occm/config') do
    its(:stdout) { should include 'OnCloudAuthenticationException: Authentication required' }
  end
end

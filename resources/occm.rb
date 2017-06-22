# Cookbook Name:: netapp_ontap_cloud
# Resource:: occm
#
# Author:: Jeremy Goodrum
# Email:: chef@exospheredata.com
#
# Version:: 0.1.0
# Date:: 2017-03-27
#
# Copyright (c) 2017 Exosphere Data LLC, All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

Chef::Resource.send(:include, Occm::Helper)

require 'net/http'
require 'net/https'
require 'uri'
require 'json'

default_action :setup

# Server configuration
property :server, String, required: true
property :email_address, String, required: true
property :password, String, required: true, sensitive: true

property :company, String, required: true
property :site, String, default: 'ONTAP Cloud Lab'

# User Management properties
property :first_name, String, default: 'occm'
property :last_name, String, default: 'admin'
property :role_name, String, equal_to: ['Cloud Manager Admin', 'Tenant Admin', 'Working Environment Admin'] # Role-1 equals 'Cloud Manager Admin'
property :aws_key, String, sensitive: true
property :aws_secret, String, sensitive: true

# Tenant properties
property :tenant_name, String, required: true
property :description, String
property :cost_center, String

action :setup do
  # Ensure that this host has OnCommand Cloud Manager up and running.  If recently started then
  # we need to wait for the service to respond.
  server_responding?(new_resource.server, 1)
  return new_resource.updated_by_last_action(false) if server_configured?(new_resource.server)
  raise ArgumentError, 'AWS Secret Key set with no valid aws_key' if new_resource.aws_secret && (new_resource.aws_key.nil? || new_resource.aws_key == '')
  raise ArgumentError, 'AWS Access Key set with no valid aws_secret' if new_resource.aws_key && (new_resource.aws_secret.nil? || new_resource.aws_secret == '')
  Chef::Log.info('Starting OnCommand Cloud Manager setup')
  payload = {}
  user_request = {}
  user_request['email'] = new_resource.email_address
  user_request['lastName'] = new_resource.last_name
  user_request['firstName'] = new_resource.first_name
  user_request['password'] = new_resource.password
  user_request['roleId'] = 'Role-1' # Role-1 equals 'Cloud Manager Admin'
  user_request['accessKey'] = new_resource.aws_key || nil
  user_request['secretKey'] = new_resource.aws_secret || nil
  unless new_resource.aws_key
    Chef::Log.info('No AWS Credentials sent.  You will not be able to deploy ONTAP Cloud for AWS until this is modified.')
  end
  tenant_request = {}
  tenant_request['name'] = new_resource.tenant_name
  tenant_request['description'] = new_resource.description || ''
  tenant_request['costCenter'] = new_resource.cost_center || ''
  payload['userRequest'] = user_request
  payload['tenantRequest'] = tenant_request
  payload['site'] = new_resource.site
  payload['company'] = new_resource.company
  payload['proxyUrl'] = { 'uri' => '' }

  response = setup_server(new_resource.server, payload)

  output = JSON.parse(response.body)
  return new_resource.updated_by_last_action(false) if output['message'] == 'Initial setup already performed'
  case response
  when Net::HTTPOK
    Chef::Log.info('OnCommand Cloud Manager setup complete')
  when Net::HTTPBadRequest
    raise ArgumentError, "OCCM Setup command returned an http error 400: #{output['message']} - #{output['violations']}"
  when Net::HTTPClientError,
        Net::HTTPInternalServerError
    raise "Unknown OCCM Server error: #{response.body.inspect}"
  else
    raise response.inspect
  end

  # After configuring the OnCommand Cloud Manager setup and first-run, we need to wait for the service
  # to restart.  We are injecting a sleep function to capture a pause and ensure that we don't have a
  # race condition and check the status too early.
  sleep(5)
  server_responding?(new_resource.server, 5)
  new_resource.updated_by_last_action(true)
end

action_class do
  def whyrun_supported?
    true
  end
end

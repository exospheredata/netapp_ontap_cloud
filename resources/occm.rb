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

require 'net/http'
require 'net/https'
require 'uri'
require 'json'

default_action :setup

# Server configuration
property :server, String, required: true
property :email_address, String, required: true
property :password, String, required: true

property :company, String, required: true
property :site, String

# User Management properties
property :first_name, String
property :last_name, String
property :role_id, String # Role-1 equals 'Cloud Manager Admin'
property :aws_key, String
property :aws_secret, String

# Tenant properties
property :tenant_name, String
property :description, String
property :cost_center, String

action :setup do
  # Ensure that this host has OnCommand Cloud Manager up and running.  If recently started then
  # we need to wait for the service to respond.
  server_responding?(new_resource.server, 5)
  return new_resource.updated_by_last_action(false) if server_configured?(new_resource.server)
  Chef::Log.info('Starting OnCommand Cloud Manager setup')
  payload = {}
  user_request = {}
  user_request['email'] = new_resource.email_address || 'admin@localhost.lab'
  user_request['lastName'] = new_resource.last_name || 'admin'
  user_request['firstName'] = new_resource.first_name || 'occm'
  user_request['password'] = new_resource.password
  user_request['roleId'] = 'Role-1' # Role-1 equals 'Cloud Manager Admin'
  user_request['accessKey'] = new_resource.aws_key || nil
  user_request['secretKey'] = new_resource.aws_secret || nil
  unless new_resource.aws_key
    Chef::Log.info('No AWS Credentials sent.  You will not be able to deploy ONTAP Cloud for AWS until this is modified.')
  end
  tenant_request = {}
  tenant_request['name'] = new_resource.tenant_name || 'Default Tenant'
  tenant_request['description'] = ''
  tenant_request['costCenter'] = ''
  payload['userRequest'] = user_request
  payload['tenantRequest'] = tenant_request
  payload['site'] = new_resource.site || 'ONTAP Cloud Lab'
  payload['company'] = new_resource.company
  payload['proxyUrl'] = { 'uri' => '' }

  begin
    response = setup_server(new_resource.server, payload)
  rescue Timeout::Error => e
    Chef::Log.info(e.message)
    raise "Here: #{e.message}"
  else
    output = JSON.parse(response.body)
    return new_resource.updated_by_last_action(false) if output['message'] == 'Initial setup already performed'
    case response
    when Net::HTTPOK
      Chef::Log.info(response.body)
    when Net::HTTPBadRequest
      raise ArgumentError, "OCCM Setup command returned an http error 400: #{output['message']} - #{output['violations']}"
    when Net::HTTPClientError,
          Net::HTTPInternalServerError
      Chef::Log.warn(response.inspect)
      raise response.body.inspect
    else
      raise response.inspect
    end
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

  def connect_server(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http
  end

  def server_responding?(host, wait = nil)
    proceed = false
    step_count = 0
    url = URI.parse("https://#{host}/occm/api/occm/about")
    connection = connect_server(url)
    until proceed
      begin
        http_get(connection, nil, url)
        return true
      rescue Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Errno::ENETUNREACH
        Chef::Log.info('OnCommand Cloud manager service not reachable')
        return false if wait.nil?
        if step_count < wait
          Chef::Log.info('Pausing for 5 seconds to retry the connection.')
          sleep(5)
          step_count += 1
        else
          Chef::Log.fatal('The Service never returned despite waiting patiently')
          return false
        end
      else
        # In theory, we should only hit this point if the OnCommand Cloud Manager service
        # is not running or the server is unreachable.
        raise Exception.inspect
      end
    end
  end

  def server_configured?(host)
    url = URI.parse("https://#{host}/occm/api/occm/config")
    connection = connect_server(url)
    response = http_get(connection, nil, url)
    return false if JSON.parse(response.body)['message'] == 'OCCM must be setup before performing this operation.'
    true
  end

  def setup_server(host, body)
    url = URI.parse("https://#{host}/occm/api/occm/setup/init")
    connection = connect_server(url)
    http_post(connection, url, body)
  end

  def http_get(conn, _headers, url)
    request = Net::HTTP::Get.new(url)
    request.content_type = 'application/json'
    request['Referrer'] = 'CHEF'

    begin
      response = conn.start { |http| http.request(request) }
    rescue Timeout::Error => e
      Chef::Log.info(e.message)
      raise "Timeout::Error: #{e.message}"
    end
    response
  end

  def http_post(conn, url, body)
    request = Net::HTTP::Post.new(url)
    request.content_type = 'application/json'
    request['Referrer'] = 'CHEF'
    body = body.to_json if body.is_a?(Hash)
    request.body = body

    begin
      response = conn.start { |http| http.request(request) }
    rescue Timeout::Error => e
      Chef::Log.info(e.message)
      raise "Timeout::Error: #{e.message}"
    end
    response
  end
end

# Cookbook Name:: netapp_ontap_cloud
# Resource:: ontap_aws
#
# Author:: Jeremy Goodrum
# Email:: chef@exospheredata.com
#
# Version:: 0.1.0
# Date:: 2017-04-02
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

default_action :create

# OCCM Required Properties
property :server, String, required: true
property :occm_user, String, required: true
property :occm_password, String, required: true, identity: false, sensitive: true
property :ontap_name, String, required: true, name_property: true # Regex is evaluated in the action
property :tenant_name, String, required: true

# AWS Configuration
#
# TODO: Move the required aspect of these into an actual method to be called.  These properties are not
# required for every action.
property :region, String, required: true, regex: [/^[a-z]{2}-[a-z]+-\d$/]
property :vpc_id, String, required: true, regex: [/^vpc-[a-zA-Z0-9]{8}$/]
property :subnet_id, String, required: true, regex: [/^subnet-[a-zA-Z0-9]{8}$/]
property :aws_tags, String # Future property

# VsaMetadata
property :instance_type, String, required: true, default: 'm4.xlarge' # TODO: Create a list of supported Instance Types and a method to validate

# Future licenseType = 'cot-premium-byol'
property :license_type, String, equal_to: ['cot-explore-paygo', 'cot-standard-paygo', 'cot-premium-paygo'], default: 'cot-explore-paygo', required: true
property :ontap_version, String, default: 'latest'
property :use_latest, [TrueClass, FalseClass], default: true
property :platform_license, String # Future property

# EBS Volume Types and details
# Supported versions found at https://<occm-host>/occm/api/vsa/metadata/ebs-volume-types
# TODO:  Create a method to match approved sizes to disk types.
#
property :ebs_volume_type, String, equal_to: %w(gp2 st1 sc1), default: 'gp2'
property :ebs_volume_size, String, equal_to: %w(100GB 500GB 1TB 2TB 4TB 8TB), default: '1TB'

property :clusterKeyPairName, String # Future property
property :svm_password, String, required: true, identity: false, sensitive: true

# Maps to skipSnapshots to override if an EBS snapshot should be taken on first deploy
property :bypass_snapshot, [TrueClass, FalseClass], default: false
property :data_encryption_type, String, equal_to: ['NONE', ' AWS', ' ONTAP'], default: 'NONE'

# This can be used with resource actions like :create to force the process to wait until after the exeuction
# of the job before moving on.
property :wait_execution, [TrueClass, FalseClass], default: false

# TODO:  Add custom method to verify that account has access to Subscription:
# https://<occm-host>/occm/api/vsa/metadata/validate-subscribed-to-ontap-cloud

action :create do
  # Ensure that this host has OnCommand Cloud Manager up and running.  If recently started then
  # we need to wait for the service to respond.
  server_responding?(new_resource.server, 1)

  # For some reason, the regex on the property name only works when the parameter is sent as ontap_name and not as the name property.
  # This ensures that the validation is set correctly.
  raise ArgumentError, "Option ontap_name's value #{new_resource.ontap_name} does not match regular expression [/^[A-Za-z][A-Za-z0-9_]{2,39}$/]" unless new_resource.ontap_name =~ /^[A-Za-z][A-Za-z0-9_]{2,39}$/

  # Need to store the authentication credentials in a cookie object to be leveraged later.  Setting as a
  # global variable since we need it in so many places.
  @auth_cookie = authenticate_server(new_resource.server, new_resource.occm_user, new_resource.occm_password)

  # Check to see if the instance already exists
  validate_system = get_ontap_env(new_resource.server, new_resource.ontap_name)
  if validate_system
    Chef::Log.info("ONTAP Cloud system #{new_resource.ontap_name} exists")
    return new_resource.updated_by_last_action(false)
  end

  Chef::Log.info("Creating a new ONTAP Cloud system - #{new_resource.ontap_name}")
  payload = {}
  payload['name'] = new_resource.ontap_name
  payload['tenantId'] = get_tenant_id(new_resource.server, new_resource.tenant_name)
  payload['region'] = new_resource.region
  payload['vpcId'] = validate_vpc_id(new_resource.server, new_resource.region, new_resource.vpc_id)['vpcId']
  payload['subnetId'] = validate_subnet_id(new_resource.server, new_resource.region, new_resource.vpc_id, new_resource.subnet_id)
  payload['ebsVolumeType'] = new_resource.ebs_volume_type

  ebs_volume_metadata = {}
  # Split the provided size into an array to have the number and letters split out.
  ebs_volume_metadata['size'] = (ebs_volume_size.split.map { |x| x[/\d+/] }).join
  ebs_volume_metadata['unit'] = (ebs_volume_size.split.map { |x| x[/[a-zA-Z]+/] }).join

  payload['ebsVolumeSize'] = ebs_volume_metadata
  payload['skipSnapshots'] = new_resource.bypass_snapshot
  payload['dataEncryptionType'] = new_resource.data_encryption_type

  vsa_metadata = {}
  vsa_metadata['platformLicense'] = new_resource.platform_license if new_resource.platform_license
  vsa_metadata['ontapVersion'] = new_resource.ontap_version
  vsa_metadata['useLatestVersion'] = new_resource.use_latest
  vsa_metadata['licenseType'] = new_resource.license_type
  vsa_metadata['instanceType'] = new_resource.instance_type

  payload['vsaMetadata'] = vsa_metadata
  payload['svmPassword'] = new_resource.svm_password

  response = new_ontap(new_resource.server, payload)

  output = JSON.parse(response.body)
  Chef::Log.info("ONTAP Cloud System deployment has started - #{output['publicId']}")
  return new_resource.updated_by_last_action(true) unless new_resource.wait_execution
  Chef::Log.info("Waiting on the new ONTAP Cloud system - #{new_resource.ontap_name}")
  wait_ontap(new_resource.server, output['publicId'])
  return new_resource.updated_by_last_action(true)
end

action :wait do
  # Ensure that this host has OnCommand Cloud Manager up and running.  If recently started then
  # we need to wait for the service to respond.
  server_responding?(new_resource.server, 1)

  # For some reason, the regex on the property name only works when the parameter is sent as ontap_name and not as the name property.
  # This ensures that the validation is set correctly.
  raise ArgumentError, "Option ontap_name's value #{new_resource.ontap_name} does not match regular expression [/^[A-Za-z][A-Za-z0-9_]{2,39}$/]" unless new_resource.ontap_name =~ /^[A-Za-z][A-Za-z0-9_]{2,39}$/

  # Need to store the authentication credentials in a cookie object to be leveraged later.  Setting as a
  # global variable since we need it in so many places.
  @auth_cookie = authenticate_server(new_resource.server, new_resource.occm_user, new_resource.occm_password)

  # Check to see if the instance already exists
  validate_system = get_ontap_env(new_resource.server, new_resource.ontap_name)
  raise ArgumentError, "The ONTAP Cloud System #{new_resource.ontap_name} was not found" unless validate_system

  Chef::Log.info("Waiting on the new ONTAP Cloud system - #{new_resource.ontap_name}")

  puts wait_ontap(new_resource.server, validate_system['publicId'])
  puts 'Win'
  return new_resource.updated_by_last_action(true)
end

action_class do
  def whyrun_supported?
    true
  end

  def connect_server(url)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 600
    http
  end

  def authenticate_server(host, user, password)
    url = URI.parse("https://#{host}/occm/api/auth/login")
    connection = connect_server(url)
    body = {}
    body['email'] = user
    body['password'] = password
    response = http_post(connection, url, body)
    # Return the actual Cookie object
    response.response['set-cookie'].split('; ')[0]
  end

  def server_responding?(host, wait = nil)
    proceed = false
    step_count = 0
    url = URI.parse("https://#{host}/occm/api/occm/system/about")
    connection = connect_server(url)
    until proceed
      begin
        http_get(connection, url)
        return true
      rescue Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Errno::ENETUNREACH
        Chef::Log.info('OnCommand Cloud manager service not reachable')
        return false if wait.nil?
        if step_count < wait
          Chef::Log.info('Pausing for 5 seconds to retry the connection.')
          sleep(5)
          step_count += 1
        else
          Chef::Log.debug('Failed to wait for the server connection')
          raise 'The Service never returned despite waiting patiently'
        end
      else
        # In theory, we should only hit this point if the OnCommand Cloud Manager service
        # is not running or the server is unreachable.
        raise Exception.inspect
      end
    end
  end

  def new_ontap(host, body)
    url = URI.parse("https://#{host}/occm/api/vsa/working-environments")
    begin
      connection = connect_server(url)
    rescue
      raise connection.inspect
    end
    response = http_post(connection, url, body)
    http_response_check(response)
  end

  def get_ontap_env(host, ontap_name)
    url = URI.parse("https://#{host}/occm/api/vsa/working-environments")
    connection = connect_server(url)
    response = http_get(connection, url)
    we_environments = JSON.parse(response.body)
    we_environments.each do |we_environment|
      # We will return the entire VSA object if the unique name matches.  This is dependent on OCCM
      # maintaining that the name must be unique within the environment.
      return we_environment if we_environment['name'] == ontap_name
    end
    false
  end

  def wait_ontap(host, public_id)
    url = URI.parse("https://#{host}/occm/api/audit?workingEnvironmentId=#{public_id}")
    connection = connect_server(url)
    counter = 0
    while counter < 40
      response = http_get(connection, url)
      we_env = JSON.parse(response.body)
      we_env.each do |log|
        next unless log['actionName'] == 'Create Vsa Working Environment'
        case log['status']
        when 'Success'
          return true
        when 'Failed'
          raise log['errorMessage']
        else
          Chef::Log.info('Waiting for completion of ONTAP Cloud build')
          puts JSON.pretty_generate(log['records'].first)
          sleep(30)
          counter += 1
        end
      end
    end
    raise 'Failed to wait for ONTAP Cloud system'
  end

  def get_tenant_id(host, tenant_name)
    url = URI.parse("https://#{host}/occm/api/tenants")
    connection = connect_server(url)
    response = http_get(connection, url)
    tenants = JSON.parse(response.body)
    tenants.each do |tenant|
      return tenant['publicId'] if tenant['name'] == tenant_name
    end
    raise ArgumentError, "Tenant #{tenant_name} was not found on this server #{host} or is not accessible to this user #{new_resource.occm_user}"
  end

  def validate_vpc_id(host, region, vpc_id)
    url = URI.parse("https://#{host}/occm/api/vsa/metadata/vpcs?region=#{region}")
    connection = connect_server(url)
    response = http_get(connection, url)
    vpcs = JSON.parse(response.body)
    vpcs.each do |vpc|
      return vpc if vpc['vpcId'] == vpc_id
    end
    raise ArgumentError, "VPC #{vpc_id} was not found in the list of available VPCs for this user"
  end

  def validate_subnet_id(host, region, vpc_id, subnet_id)
    vpc = validate_vpc_id(host, region, vpc_id)
    vpc['subnets'].each do |subnet|
      return subnet['subnetId'] if subnet['subnetId'] == subnet_id
    end
    raise ArgumentError, "Subnet #{subnet_id} was not found in the list of available subnets for the VPC #{vpc_id}"
  end

  def http_get(conn, url)
    request = Net::HTTP::Get.new(url)
    request.content_type = 'application/json'
    request['Referrer'] = 'CHEF'
    request['Cookie'] = @auth_cookie if @auth_cookie

    begin
      response = conn.start { |http| http.request(request) }
    rescue Timeout::Error => e
      Chef::Log.info(e.message)
      raise "Timeout::Error: #{e.message}"
    end
    http_response_check(response)
  end

  def http_post(conn, url, body)
    request = Net::HTTP::Post.new(url)
    request.content_type = 'application/json'
    request['Referrer'] = 'CHEF'
    request['Cookie'] = @auth_cookie if @auth_cookie
    body = body.to_json if body.is_a?(Hash)
    request.body = body

    begin
      response = conn.start { |http| http.request(request) }
    rescue Timeout::Error => e
      Chef::Log.info(e.message)
      raise "Timeout::Error: #{e.message}"
    end
    http_response_check(response)
  end

  def http_response_check(rsp)
    case rsp
    when Net::HTTPOK, Net::HTTPNoContent, Net::HTTPAccepted
      rsp
    when Net::HTTPUnauthorized
      raise ArgumentError, "Authentication Failed due to invalid credentials: #{JSON.pretty_generate(rsp.body)}"
    when Net::HTTPBadRequest
      output = JSON.parse(rsp.body)
      raise ArgumentError, "OnCommand Cloud Manager - Bad HTTP request error 400: #{output['message']}#{' - ' + output['violations'] if output['violations']}"
    when Net::HTTPClientError,
          Net::HTTPInternalServerError
      raise "Unknown OCCM Server error: #{rsp.body.inspect}"
    else
      raise rsp.inspect
    end
  end
end
